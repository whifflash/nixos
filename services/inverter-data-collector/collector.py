#!/usr/bin/env python3
"""Read one SMA SunSpec inverter and publish its measurements over MQTT."""

from __future__ import annotations

import json
import logging
import os
import signal
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import paho.mqtt.client as mqtt
import sunspec2.modbus.client as sunspec_client

LOGGER = logging.getLogger("inverter-data-collector")
STOP_EVENT = threading.Event()

STATUS_MAP = {
    1: "off",
    2: "sleeping",
    3: "starting",
    4: "producing",
    5: "throttled",
    6: "shutting_down",
    7: "fault",
    8: "standby",
}


def env_int(name: str, default: int) -> int:
    return int(os.environ.get(name, str(default)))


def read_credential(name: str) -> str:
    credentials_directory = os.environ.get("CREDENTIALS_DIRECTORY")
    if credentials_directory is None:
        raise RuntimeError("systemd did not provide CREDENTIALS_DIRECTORY")

    path = Path(credentials_directory) / name
    value = path.read_text(encoding="utf-8").strip()
    if not value:
        raise RuntimeError(f"credential {name!r} is empty")
    return value


def iso_utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def safe_cvalue(model: Any, point_name: str) -> Any:
    point = model.points.get(point_name)
    if point is None:
        return None
    return getattr(point, "cvalue", None)


def discovery_sensor(
    client: mqtt.Client,
    *,
    discovery_prefix: str,
    state_topic: str,
    availability_topic: str,
    device_id: str,
    serial: str,
    manufacturer: str,
    model: str,
    firmware: str,
    name: str,
    unique_suffix: str,
    value_template: str,
    unit: str | None = None,
    device_class: str | None = None,
    state_class: str | None = None,
    icon: str | None = None,
) -> None:
    unique_id = f"{device_id}_{unique_suffix}"
    payload: dict[str, Any] = {
        "name": name,
        "unique_id": unique_id,
        "state_topic": state_topic,
        "value_template": value_template,
        "availability_topic": availability_topic,
        "payload_available": "online",
        "payload_not_available": "offline",
        "qos": 0,
        "device": {
            "identifiers": [serial],
            "manufacturer": manufacturer,
            "model": model,
            "name": f"SMA {model} ({serial})",
            "sw_version": firmware,
        },
    }

    optional_values = {
        "unit_of_measurement": unit,
        "device_class": device_class,
        "state_class": state_class,
        "icon": icon,
    }
    payload.update({key: value for key, value in optional_values.items() if value is not None})

    topic = f"{discovery_prefix}/sensor/{unique_id}/config"
    client.publish(topic, json.dumps(payload), qos=1, retain=True)


def publish_discovery(
    client: mqtt.Client,
    *,
    discovery_prefix: str,
    state_topic: str,
    availability_topic: str,
    manufacturer: str,
    model: str,
    serial: str,
    firmware: str,
) -> None:
    device_id = f"sma_{serial}"
    common = {
        "client": client,
        "discovery_prefix": discovery_prefix,
        "state_topic": state_topic,
        "availability_topic": availability_topic,
        "device_id": device_id,
        "serial": serial,
        "manufacturer": manufacturer,
        "model": model,
        "firmware": firmware,
    }

    sensors = [
        {
            "name": "PV Power",
            "unique_suffix": "ac_power_w",
            "value_template": "{{ value_json.ac_power_w }}",
            "unit": "W",
            "device_class": "power",
            "state_class": "measurement",
        },
        {
            "name": "PV Energy Total",
            "unique_suffix": "energy_total_kwh",
            "value_template": "{{ (value_json.ac_energy_total_wh | float / 1000) | round(3) }}",
            "unit": "kWh",
            "device_class": "energy",
            "state_class": "total_increasing",
        },
        {
            "name": "PV Operating State",
            "unique_suffix": "status_text",
            "value_template": "{{ value_json.status_text }}",
            "icon": "mdi:state-machine",
        },
        {
            "name": "Grid Frequency",
            "unique_suffix": "grid_hz",
            "value_template": "{{ value_json.grid_hz }}",
            "unit": "Hz",
            "device_class": "frequency",
            "state_class": "measurement",
        },
        {
            "name": "L1 Voltage",
            "unique_suffix": "vac_l1_v",
            "value_template": "{{ value_json.vac_l1_v }}",
            "unit": "V",
            "device_class": "voltage",
            "state_class": "measurement",
        },
        {
            "name": "L2 Voltage",
            "unique_suffix": "vac_l2_v",
            "value_template": "{{ value_json.vac_l2_v }}",
            "unit": "V",
            "device_class": "voltage",
            "state_class": "measurement",
        },
        {
            "name": "L3 Voltage",
            "unique_suffix": "vac_l3_v",
            "value_template": "{{ value_json.vac_l3_v }}",
            "unit": "V",
            "device_class": "voltage",
            "state_class": "measurement",
        },
        {
            "name": "PV Cabinet Temperature",
            "unique_suffix": "temp_cab_c",
            "value_template": "{{ value_json.temp_cab_c }}",
            "unit": "°C",
            "device_class": "temperature",
            "state_class": "measurement",
        },
    ]

    for sensor in sensors:
        discovery_sensor(**common, **sensor)


def signal_handler(signum: int, _frame: Any) -> None:
    LOGGER.info("received signal %s; shutting down", signum)
    STOP_EVENT.set()


def run_collector() -> None:
    sma_host = os.environ["SMA_HOST"]
    sma_port = env_int("SMA_MODBUS_PORT", 502)
    sma_slave_id = env_int("SMA_SLAVE_ID", 126)
    poll_seconds = env_int("POLL_SECONDS", 5)

    mqtt_host = os.environ.get("MQTT_HOST", "127.0.0.1")
    mqtt_port = env_int("MQTT_PORT", 1883)
    mqtt_username = os.environ.get("MQTT_USERNAME", "inverter-data-collector")
    mqtt_password = read_credential("mqtt-password")
    state_topic = os.environ["MQTT_STATE_TOPIC"]
    availability_topic = os.environ["MQTT_AVAIL_TOPIC"]
    discovery_prefix = os.environ.get("HA_DISCOVERY_PREFIX", "homeassistant")

    device = sunspec_client.SunSpecModbusClientDeviceTCP(
        slave_id=sma_slave_id,
        ipaddr=sma_host,
        ipport=sma_port,
        timeout=3,
    )
    device.scan()

    identification = device.models.get(1, [None])[0]
    if identification is None:
        raise RuntimeError("SunSpec model 1 was not found")
    identification.read()

    manufacturer = safe_cvalue(identification, "Mn") or "SMA"
    model = safe_cvalue(identification, "Md") or "Inverter"
    serial = str(safe_cvalue(identification, "SN") or "unknown")
    firmware = safe_cvalue(identification, "Vr") or "unknown"

    measurements = device.models.get(103, [None])[0]
    if measurements is None:
        raise RuntimeError("SunSpec model 103 was not found")

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.username_pw_set(mqtt_username, mqtt_password)
    client.will_set(availability_topic, payload="offline", qos=1, retain=True)

    def on_connect(
        connected_client: mqtt.Client,
        _userdata: Any,
        _flags: mqtt.ConnectFlags,
        reason_code: mqtt.ReasonCode,
        _properties: mqtt.Properties | None,
    ) -> None:
        if reason_code.is_failure:
            LOGGER.error("MQTT connection failed: %s", reason_code)
            return

        LOGGER.info("connected to MQTT broker %s:%s", mqtt_host, mqtt_port)
        publish_discovery(
            connected_client,
            discovery_prefix=discovery_prefix,
            state_topic=state_topic,
            availability_topic=availability_topic,
            manufacturer=manufacturer,
            model=model,
            serial=serial,
            firmware=firmware,
        )
        connected_client.publish(availability_topic, payload="online", qos=1, retain=True)

    def on_disconnect(
        _client: mqtt.Client,
        _userdata: Any,
        _disconnect_flags: mqtt.DisconnectFlags,
        reason_code: mqtt.ReasonCode,
        _properties: mqtt.Properties | None,
    ) -> None:
        if not STOP_EVENT.is_set():
            LOGGER.warning("disconnected from MQTT broker: %s", reason_code)

    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.reconnect_delay_set(min_delay=1, max_delay=30)
    client.connect(mqtt_host, mqtt_port, keepalive=60)
    client.loop_start()

    LOGGER.info(
        "connected to inverter %s:%s unit=%s manufacturer=%s model=%s serial=%s firmware=%s",
        sma_host,
        sma_port,
        sma_slave_id,
        manufacturer,
        model,
        serial,
        firmware,
    )

    try:
        while not STOP_EVENT.wait(poll_seconds):
            measurements.read()

            ac_power = safe_cvalue(measurements, "W")
            if ac_power is None:
                ac_power = 0.0

            status = safe_cvalue(measurements, "St")
            if status is None:
                status_text = "sleeping" if ac_power == 0.0 else "unknown"
            else:
                try:
                    status_text = STATUS_MAP.get(int(status), f"unknown_{status}")
                except (TypeError, ValueError):
                    status_text = f"unknown_{status}"

            payload = {
                "ts": iso_utc(),
                "manufacturer": manufacturer,
                "model": model,
                "serial": serial,
                "fw": firmware,
                "ac_power_w": ac_power,
                "ac_energy_total_wh": safe_cvalue(measurements, "WH"),
                "grid_hz": safe_cvalue(measurements, "Hz"),
                "vac_l1_v": safe_cvalue(measurements, "PhVphA"),
                "vac_l2_v": safe_cvalue(measurements, "PhVphB"),
                "vac_l3_v": safe_cvalue(measurements, "PhVphC"),
                "iac_total_a": safe_cvalue(measurements, "A"),
                "iac_l1_a": safe_cvalue(measurements, "AphA"),
                "iac_l2_a": safe_cvalue(measurements, "AphB"),
                "iac_l3_a": safe_cvalue(measurements, "AphC"),
                "va": safe_cvalue(measurements, "VA"),
                "var": safe_cvalue(measurements, "VAr"),
                "pf": safe_cvalue(measurements, "PF"),
                "dc_power_w": safe_cvalue(measurements, "DCW"),
                "temp_cab_c": safe_cvalue(measurements, "TmpCab"),
                "status": status,
                "status_text": status_text,
                "events": safe_cvalue(measurements, "Evt1"),
            }

            result = client.publish(state_topic, json.dumps(payload, ensure_ascii=False), qos=0)
            if result.rc != mqtt.MQTT_ERR_SUCCESS:
                LOGGER.warning("failed to queue MQTT state publication: %s", result.rc)
    finally:
        client.publish(availability_topic, payload="offline", qos=1, retain=True).wait_for_publish()
        client.disconnect()
        client.loop_stop()


def main() -> None:
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    retry_seconds = env_int("RETRY_SECONDS", 15)
    while not STOP_EVENT.is_set():
        try:
            run_collector()
        except Exception:
            LOGGER.exception("collector cycle failed; retrying in %s seconds", retry_seconds)
            STOP_EVENT.wait(retry_seconds)


if __name__ == "__main__":
    main()
