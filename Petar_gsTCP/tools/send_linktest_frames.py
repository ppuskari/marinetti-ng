"""Send bounded UDP broadcasts for the PGTLinkTest receive diagnostic."""

from __future__ import annotations

import argparse
import socket
import time


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send test broadcasts to an active PGTLinkTest IIgs"
    )
    parser.add_argument(
        "--broadcast",
        required=True,
        help="LAN broadcast address, for example 192.168.1.255",
    )
    parser.add_argument("--port", type=int, default=6502)
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--payload-size", type=int, default=1200)
    parser.add_argument("--interval", type=float, default=0.05)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("--port must be 1..65535")
    if not 1 <= args.count <= 10000:
        parser.error("--count must be 1..10000")
    if not 16 <= args.payload_size <= 1400:
        parser.error("--payload-size must be 16..1400")
    if not 0 <= args.interval <= 10:
        parser.error("--interval must be 0..10 seconds")
    return args


def main() -> None:
    args = parse_args()
    destination = (args.broadcast, args.port)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sender:
        sender.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        for sequence in range(args.count):
            header = b"PGTLINK1" + sequence.to_bytes(4, "big")
            payload = header + bytes([sequence & 0xFF]) * (
                args.payload_size - len(header)
            )
            sender.sendto(payload, destination)
            if args.interval:
                time.sleep(args.interval)
    print(
        f"sent {args.count} UDP broadcasts of {args.payload_size} bytes "
        f"to {args.broadcast}:{args.port}"
    )


if __name__ == "__main__":
    main()
