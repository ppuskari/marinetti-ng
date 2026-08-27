#!/usr/bin/env python3
"""One-shot listener for the PGTTCPTest native active-open diagnostic."""

from __future__ import annotations

import argparse
import socket


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Accept one Petar_gsTCP connection and verify its clean FIN."
    )
    parser.add_argument("--bind", default="0.0.0.0", help="local address")
    parser.add_argument("--port", type=int, default=6502, help="TCP port")
    parser.add_argument(
        "--timeout", type=float, default=300.0,
        help="seconds to wait for the IIgs connection and FIN (default: 300)",
    )
    args = parser.parse_args()

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind((args.bind, args.port))
        listener.listen(1)
        listener.settimeout(args.timeout)
        print(f"Listening on {args.bind}:{args.port}; start PGTTCPTEST on the IIgs.")
        connection, peer = listener.accept()
        with connection:
            connection.settimeout(args.timeout)
            print(f"PASS: accepted native TCP connection from {peer[0]}:{peer[1]}")
            data = connection.recv(1)
            if data:
                raise RuntimeError(f"unexpected client payload: {data.hex()}")
            print("PASS: received the IIgs FIN and completed the close handshake.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
