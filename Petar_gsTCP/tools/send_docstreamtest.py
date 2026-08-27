"""Send zero-free 22.05 kHz mono PCM to PGTDocStreamTest over UDP."""

from __future__ import annotations

import argparse
import math
import socket
import time


SAMPLE_RATE = 22_050
DEFAULT_PREFILL_BYTES = 65_520


def tone_payload(first_sample: int, length: int, frequency: float) -> bytes:
    """Generate unsigned 8-bit PCM without DOC's reserved zero byte."""
    scale = 2.0 * math.pi * frequency / SAMPLE_RATE
    return bytes(
        max(1, min(255, round(128 + 120 * math.sin((first_sample + i) * scale))))
        for i in range(length)
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--broadcast", required=True, help="LAN broadcast address")
    parser.add_argument("--port", type=int, default=6502)
    parser.add_argument("--rate", type=int, default=22_400)
    parser.add_argument("--seconds", type=float, default=30.0)
    parser.add_argument("--payload-size", type=int, default=1092)
    parser.add_argument("--tone-hz", type=float, default=440.0)
    parser.add_argument(
        "--prefill-bytes",
        type=int,
        default=DEFAULT_PREFILL_BYTES,
        help="pause after this many bytes so the IIgs can start Tool 225",
    )
    parser.add_argument("--startup-pause", type=float, default=0.75)
    args = parser.parse_args()
    if not 1 <= args.payload_size <= 1472:
        parser.error("payload-size must be 1..1472")
    if args.rate < args.payload_size or args.seconds <= 0 or args.tone_hz <= 0:
        parser.error("invalid rate, duration, or tone frequency")
    if args.prefill_bytes < args.payload_size or args.startup_pause < 0:
        parser.error("invalid prefill or startup pause")

    target = (args.broadcast, args.port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    interval = args.payload_size / args.rate
    started = time.perf_counter()
    deadline = started
    frames = 0
    payload_bytes = 0
    paused = False

    while deadline - started < args.seconds:
        now = time.perf_counter()
        if now < deadline:
            time.sleep(deadline - now)
        payload = tone_payload(payload_bytes, args.payload_size, args.tone_hz)
        sock.sendto(payload, target)
        frames += 1
        payload_bytes += len(payload)
        deadline += interval
        if not paused and payload_bytes >= args.prefill_bytes:
            time.sleep(args.startup_pause)
            deadline += args.startup_pause
            paused = True

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
