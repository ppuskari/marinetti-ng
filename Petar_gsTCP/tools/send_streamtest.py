"""Send a paced UDP stream to the PGTStreamTest hardware diagnostic."""

from __future__ import annotations

import argparse
import socket
import time


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--broadcast", required=True, help="LAN broadcast address")
    parser.add_argument("--port", type=int, default=6502)
    parser.add_argument("--rate", type=int, default=22400, help="UDP payload bytes/second")
    parser.add_argument("--seconds", type=float, default=20.0)
    parser.add_argument("--payload-size", type=int, default=1200)
    args = parser.parse_args()
    if not 1 <= args.payload_size <= 1472:
        parser.error("payload-size must be 1..1472")
    if args.rate < args.payload_size or args.seconds <= 0:
        parser.error("rate must cover at least one packet/second and seconds must be positive")

    payload = bytes(index & 0xFF for index in range(args.payload_size))
    target = (args.broadcast, args.port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    interval = args.payload_size / args.rate
    started = time.perf_counter()
    deadline = started
    frames = 0
    payload_bytes = 0
    while deadline - started < args.seconds:
        now = time.perf_counter()
        if now < deadline:
            time.sleep(deadline - now)
        sock.sendto(payload, target)
        frames += 1
        payload_bytes += len(payload)
        deadline += interval

    for _ in range(3):
        sock.sendto(b"", target)
        time.sleep(0.05)
    elapsed = time.perf_counter() - started
    print(
        f"sent frames={frames} payload={payload_bytes} bytes "
        f"elapsed={elapsed:.3f}s average={payload_bytes / elapsed:.1f} B/s"
    )


if __name__ == "__main__":
    main()
