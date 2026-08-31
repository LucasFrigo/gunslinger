"""Thin client for the Blender MCP addon socket (localhost:9876)."""
from __future__ import annotations

import argparse
import json
import socket
import sys


def send(cmd_type: str, params: dict | None = None, timeout: float = 120.0) -> dict:
    payload = json.dumps({"type": cmd_type, "params": params or {}}).encode("utf-8")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    sock.connect(("127.0.0.1", 9876))
    sock.sendall(payload)
    buf = b""
    try:
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            buf += chunk
            try:
                return json.loads(buf.decode("utf-8"))
            except (json.JSONDecodeError, UnicodeDecodeError):
                continue
    finally:
        sock.close()
    if not buf:
        raise RuntimeError("empty response from Blender MCP")
    return json.loads(buf.decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("type", help="command type, e.g. ping / get_scene_info / execute_code")
    parser.add_argument("--code-file", help="Python file to send as execute_code")
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("params_json", nargs="?", default="{}")
    args = parser.parse_args()
    params = json.loads(args.params_json)
    if args.code_file:
        params["code"] = open(args.code_file, encoding="utf-8").read()
        args.type = "execute_code"
    result = send(args.type, params, timeout=args.timeout)
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0 if result.get("status") == "success" else 1


if __name__ == "__main__":
    raise SystemExit(main())
