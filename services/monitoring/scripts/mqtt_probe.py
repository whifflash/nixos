#!/usr/bin/env python3
import json
import os
import secrets
import time
from datetime import datetime
from pathlib import Path

import paho.mqtt.client as mqtt


INVERTER_STATUS_VALUES = {
    "off": 1,
    "sleeping": 2,
    "starting": 3,
    "producing": 4,
    "throttled": 5,
    "shutting_down": 6,
    "fault": 7,
    "standby": 8,
}


def metric_label(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def metric_number(value: object, default: float = 0.0) -> float:
    if value is None:
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def parse_timestamp(timestamp: object) -> int:
    if not isinstance(timestamp, str):
        return 0
    try:
        return int(datetime.fromisoformat(timestamp.replace("Z", "+00:00")).timestamp())
    except ValueError:
        return 0


def main() -> None:
    password = Path(os.environ["CREDENTIALS_DIRECTORY"], "mqtt-password").read_text().strip()
    state_path = Path(os.environ["STATE_DIRECTORY"], "mqtt-state.json")
    output_path = Path(os.environ["MQTT_METRICS_FILE"])
    topics = json.loads(os.environ["MQTT_TOPICS_JSON"])
    roundtrip_topic = os.environ["MQTT_ROUNDTRIP_TOPIC"]
    timeout = float(os.environ["MQTT_TIMEOUT_SECONDS"])
    now = time.time()

    try:
        state = json.loads(state_path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        state = {"topics": {}, "last_roundtrip_success": 0}

    token = secrets.token_hex(16)
    roundtrip_started = time.monotonic()
    roundtrip_duration = 0.0
    roundtrip_success = False
    connected = False
    received_topics: dict[str, str] = {}

    def on_connect(client: mqtt.Client, _userdata: object, _flags: object, reason_code: object, _properties: object = None) -> None:
        nonlocal connected
        if int(reason_code) != 0:
            return
        connected = True
        client.subscribe(roundtrip_topic, qos=1)
        for topic in topics:
            client.subscribe(topic["topic"], qos=1)
        client.publish(roundtrip_topic, token, qos=1, retain=False)

    def on_message(_client: mqtt.Client, _userdata: object, message: mqtt.MQTTMessage) -> None:
        nonlocal roundtrip_duration, roundtrip_success
        payload = message.payload.decode("utf-8", errors="replace")
        if message.topic == roundtrip_topic and payload == token:
            roundtrip_success = True
            roundtrip_duration = time.monotonic() - roundtrip_started
        if message.topic in {topic["topic"] for topic in topics}:
            received_topics[message.topic] = payload

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f"infra-monitoring-{token[:8]}")
    client.username_pw_set(os.environ["MQTT_USERNAME"], password)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(os.environ["MQTT_HOST"], int(os.environ["MQTT_PORT"]), keepalive=30)
    client.loop_start()

    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if roundtrip_success and all(topic["topic"] in received_topics for topic in topics):
            break
        time.sleep(0.1)

    client.disconnect()
    client.loop_stop()

    if roundtrip_success:
        state["last_roundtrip_success"] = int(now)

    topic_state = state.setdefault("topics", {})
    lines = [
        f"infra_mqtt_connected {1 if connected else 0}",
        f"infra_mqtt_roundtrip_success {1 if roundtrip_success else 0}",
        f"infra_mqtt_roundtrip_duration_seconds {roundtrip_duration}",
        f"infra_mqtt_last_success_timestamp_seconds {state.get('last_roundtrip_success', 0)}",
    ]

    for topic in topics:
        name = topic["name"]
        mqtt_topic = topic["topic"]
        expected = topic.get("expectedPayload")
        if mqtt_topic in received_topics:
            topic_state[mqtt_topic] = {
                "last_seen": int(now),
                "payload": received_topics[mqtt_topic],
            }
        saved = topic_state.get(mqtt_topic, {})
        last_seen = int(saved.get("last_seen", 0))
        payload = str(saved.get("payload", ""))
        healthy = last_seen > 0 and (expected is None or payload == expected)
        labels = f'name="{metric_label(name)}",topic="{metric_label(mqtt_topic)}"'
        lines.extend(
            [
                f"infra_mqtt_topic_present{{{labels}}} {1 if last_seen > 0 else 0}",
                f"infra_mqtt_topic_last_message_timestamp_seconds{{{labels}}} {last_seen}",
                f"infra_mqtt_topic_healthy{{{labels}}} {1 if healthy else 0}",
            ]
        )

        if name == "inverter-state" and payload:
            try:
                inverter_state = json.loads(payload)
            except json.JSONDecodeError:
                lines.append("infra_pv_inverter_payload_valid 0")
                continue

            status_text = str(inverter_state.get("status_text", "unknown"))
            status_code = metric_number(
                inverter_state.get("status"),
                INVERTER_STATUS_VALUES.get(status_text, 0),
            )
            status_labels = f'status="{metric_label(status_text)}"'
            lines.extend(
                [
                    "infra_pv_inverter_payload_valid 1",
                    f"infra_pv_inverter_status{{{status_labels}}} 1",
                    f"infra_pv_inverter_status_code {status_code}",
                    f"infra_pv_inverter_fault {1 if status_text == 'fault' else 0}",
                    f"infra_pv_ac_power_w {metric_number(inverter_state.get('ac_power_w'))}",
                    f"infra_pv_dc_power_w {metric_number(inverter_state.get('dc_power_w'))}",
                    f"infra_pv_ac_energy_total_wh {metric_number(inverter_state.get('ac_energy_total_wh'))}",
                    f"infra_pv_event_bitmask {metric_number(inverter_state.get('events'))}",
                    f"infra_pv_payload_timestamp_seconds {parse_timestamp(inverter_state.get('ts'))}",
                ]
            )

    state_path.write_text(json.dumps(state, sort_keys=True))
    temporary_path = output_path.with_suffix(output_path.suffix + ".tmp")
    temporary_path.write_text("\n".join(lines) + "\n")
    temporary_path.chmod(0o644)
    temporary_path.replace(output_path)


if __name__ == "__main__":
    main()
