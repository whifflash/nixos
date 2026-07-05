#!/usr/bin/env python3
import base64
import json
import os
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


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
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

        topic = NTFY_TOPICS.get(severity, NTFY_TOPICS["info"])
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
        with urlopen(request, timeout=15) as response:
            response.read()
        self.send_response(204)
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:
        print(format % args, flush=True)


server = ThreadingHTTPServer(("127.0.0.1", int(os.environ["LISTEN_PORT"])), Handler)
server.serve_forever()
