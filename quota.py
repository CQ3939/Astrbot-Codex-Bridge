"""Refresh the account window without starting a Codex model turn."""

import json
import logging
import os
import queue
import subprocess
import threading
import time
from datetime import datetime, timedelta, timezone


def read_snapshot(executable):
    messages = queue.Queue()
    env = os.environ.copy()
    env.pop("CODEX_BRIDGE_KEY", None)
    with subprocess.Popen([executable, "app-server", "--listen", "stdio://"], env=env,
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                          text=True, encoding="utf-8") as proc:
        def collect():
            for line in proc.stdout:
                messages.put(line)
            messages.put(None)

        threading.Thread(target=collect, daemon=True).start()

        def send(data):
            proc.stdin.write(json.dumps(data) + "\n")
            proc.stdin.flush()

        def result(ident):
            deadline = time.monotonic() + 25
            while True:
                line = messages.get(timeout=max(0, deadline - time.monotonic()))
                if line is None:
                    raise EOFError("quota RPC closed")
                message = json.loads(line)
                if message.get("id") == ident:
                    return message["result"]

        try:
            send({"id": 1, "method": "initialize", "params": {"clientInfo":
                  {"name": "qq_bot_usage", "version": "1"}, "capabilities": {"explicitGatewayOauth": True}}})
            result(1)
            send({"method": "initialized"})
            send({"id": 2, "method": "account/rateLimits/read"})
            limits = result(2)["rateLimits"]
            if not any(w and w.get("windowDurationMins") == 10080 for w in
                       (limits.get("primary"), limits.get("secondary"))):
                raise ValueError("missing seven-day window")
            return {"observed_at": datetime.now(timezone(timedelta(hours=9))).isoformat(),
                    **{name: limits.get(name) for name in ("primary", "secondary")}}
        finally:
            if proc.poll() is None:
                proc.kill()
            proc.wait()


def monitor(executable, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    while True:
        try:
            snapshot = read_snapshot(executable)
            pending = path.with_suffix(".tmp")
            pending.write_text(json.dumps(snapshot), encoding="utf-8")
            pending.replace(path)
        except (OSError, EOFError, KeyError, ValueError, queue.Empty) as exc:
            logging.warning("账户额度暂未刷新 (%s)", type(exc).__name__)
        time.sleep(300)
