#!/usr/bin/env python3
import base64
import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen

CREDENTIALS_DIRECTORY = Path(os.environ["CREDENTIALS_DIRECTORY"])
NTFY_PASSWORD = (CREDENTIALS_DIRECTORY / "ntfy-password").read_text().strip()
NTFY_BASE_URL = os.environ["NTFY_BASE_URL"].rstrip("/")
NTFY_USERNAME = os.environ["NTFY_USERNAME"]
NTFY_TOPICS = json.loads(os.environ["NTFY_TOPICS_JSON"])
GRAFANA_URL = os.environ["GRAFANA_URL"]
AUTHORIZATION = "Basic " + base64.b64encode(
    f"{NTFY_USERNAME}:{NTFY_PASSWORD}".encode()
).decode()
METRICS = {
    "notifications_total": 0,
    "notification_failures_total": 0,
    "last_success_timestamp_seconds": 0,
    "last_canary_success_timestamp_seconds": 0,
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/-/healthy":
            self.send_response(204)
            self.end_headers()
            return

        if self.path != "/metrics":
            self.send_response(404)
            self.end_headers()
            return

        body = "\n".join(
            [
                "# HELP infra_alertmanager_ntfy_notifications_total Notifications received from Alertmanager.",
                "# TYPE infra_alertmanager_ntfy_notifications_total counter",
                f"infra_alertmanager_ntfy_notifications_total {METRICS['notifications_total']}",
                "# HELP infra_alertmanager_ntfy_notification_failures_total Failed ntfy publish attempts.",
                "# TYPE infra_alertmanager_ntfy_notification_failures_total counter",
                f"infra_alertmanager_ntfy_notification_failures_total {METRICS['notification_failures_total']}",
                "# HELP infra_alertmanager_ntfy_last_success_timestamp_seconds Last successful ntfy publish timestamp.",
                "# TYPE infra_alertmanager_ntfy_last_success_timestamp_seconds gauge",
                f"infra_alertmanager_ntfy_last_success_timestamp_seconds {METRICS['last_success_timestamp_seconds']}",
                "# HELP infra_alertmanager_ntfy_last_canary_success_timestamp_seconds Last successful scheduled canary ntfy publish timestamp.",
                "# TYPE infra_alertmanager_ntfy_last_canary_success_timestamp_seconds gauge",
                f"infra_alertmanager_ntfy_last_canary_success_timestamp_seconds {METRICS['last_canary_success_timestamp_seconds']}",
                "",
            ]
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.end_headers()
        self.wfile.write(body.encode())

    def do_POST(self) -> None:
        METRICS["notifications_total"] += 1
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length))
        alerts = payload.get("alerts", [])
        status = payload.get("status", "firing")
        severity = payload.get("commonLabels", {}).get("severity", "info")
        summaries = [
            alert.get("annotations", {}).get(
                "summary", alert.get("labels", {}).get("alertname", "Alert")
            )
            for alert in alerts
        ]
        title = f"Icarus {severity}: {status}"
        message = "\n".join(f"• {summary}" for summary in summaries) or "Alertmanager notification"
        priority = {"critical": "urgent", "warning": "high", "info": "low"}.get(
            severity, "default"
        )
        tags = {
            "critical": "rotating_light",
            "warning": "warning",
            "info": "information_source",
        }.get(severity, "bell")
        if status == "resolved":
            priority = "default"
            tags = "white_check_mark"

        requested_topic = payload.get("commonLabels", {}).get("ntfy_topic")
        allowed_topics = set(NTFY_TOPICS.values())
        topic = (
            requested_topic
            if requested_topic in allowed_topics
            else NTFY_TOPICS.get(severity, NTFY_TOPICS["info"])
        )
        request = Request(
            f"{NTFY_BASE_URL}/{topic}",
            data=message.encode(),
            method="POST",
            headers={
                "Authorization": AUTHORIZATION,
                "Title": title,
                "Priority": priority,
                "Tags": tags,
                "Click": GRAFANA_URL,
            },
        )
        try:
            with urlopen(request, timeout=15) as response:
                response.read()
        except Exception:
            METRICS["notification_failures_total"] += 1
            raise

        now = int(time.time())
        METRICS["last_success_timestamp_seconds"] = now
        if payload.get("commonLabels", {}).get("category") == "notification-canary":
            METRICS["last_canary_success_timestamp_seconds"] = now
        self.send_response(204)
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:
        print(format % args, flush=True)


server = ThreadingHTTPServer(("127.0.0.1", int(os.environ["LISTEN_PORT"])), Handler)
server.serve_forever()
