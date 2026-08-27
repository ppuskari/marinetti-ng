#!/usr/bin/env python3

import socket
import sys
import time

HOST = "0.0.0.0"
PORT = 6502

RATE = 22400
SECONDS = 15
TOTAL = RATE * SECONDS
CHUNK = 1460

def make_pattern(offset, count):
    return bytes(
        (((offset + i) % 255) + 1)
        for i in range(count)
    )

print(
    f"Listening on {HOST}:{PORT}; "
    "start PGTTCPRXTEST on the IIgs."
)
print("RX3-B: paced 22,400 byte/sec stream.")
print("IIgs prebuffers 8192 bytes before consumer starts.")
print(f"Duration: {SECONDS} seconds.")
print(f"Exact payload total: {TOTAL} bytes.")

with socket.socket(
    socket.AF_INET,
    socket.SOCK_STREAM
) as server:

    server.setsockopt(
        socket.SOL_SOCKET,
        socket.SO_REUSEADDR,
        1
    )

    server.bind((HOST, PORT))
    server.listen(1)
    server.settimeout(20.0)

    try:
        conn, addr = server.accept()
    except socket.timeout:
        print("FAIL: timeout waiting for IIgs TCP connection.")
        sys.exit(1)

    with conn:
        conn.settimeout(20.0)

        conn.setsockopt(
            socket.IPPROTO_TCP,
            socket.TCP_NODELAY,
            1
        )

        print(
            "PASS: accepted native TCP connection from "
            f"{addr[0]}:{addr[1]}"
        )

        sent = 0
        start = time.perf_counter()
        deadline = start

        while sent < TOTAL:
            count = min(CHUNK, TOTAL - sent)

            payload = make_pattern(
                sent,
                count
            )

            try:
                conn.sendall(payload)
            except (BrokenPipeError, ConnectionResetError) as exc:
                print(
                    "FAIL: connection closed while streaming: "
                    f"{exc}"
                )
                sys.exit(1)

            sent += count

            deadline += count / RATE

            now = time.perf_counter()
            delay = deadline - now

            if delay > 0:
                time.sleep(delay)
            else:
                # Never make up lost time with a burst.
                deadline = now

            if sent % 22400 < CHUNK:
                elapsed = time.perf_counter() - start
                print(
                    f"streamed {sent}/{TOTAL} bytes "
                    f"in {elapsed:.2f}s"
                )

        elapsed = time.perf_counter() - start

        print(
            "PASS: submitted exactly "
            f"{sent} payload bytes."
        )

        print(
            "Source elapsed "
            f"{elapsed:.3f}s; "
            f"average {sent / elapsed:.1f} B/s."
        )

        try:
            conn.shutdown(socket.SHUT_WR)
        except OSError:
            pass

        print(
            "PASS: host FIN sent; "
            "waiting for IIgs FIN."
        )

        while True:
            try:
                data = conn.recv(4096)
            except socket.timeout:
                print(
                    "FAIL: timeout waiting for IIgs FIN."
                )
                sys.exit(1)

            if not data:
                print(
                    "PASS: received IIgs FIN; "
                    "RX3-B close complete."
                )
                sys.exit(0)