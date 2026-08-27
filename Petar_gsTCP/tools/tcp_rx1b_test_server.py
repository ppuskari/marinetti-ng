#!/usr/bin/env python3

import socket
import sys
import time

HOST = "0.0.0.0"
PORT = 6502
SIZE = 1460

payload = bytes(
    ((i % 255) + 1)
    for i in range(SIZE)
)

print(f"Listening on {HOST}:{PORT}; start PGTTCPRXTEST on the IIgs.")
print("RX1-B: exactly 1460 bytes, pattern 01..FF repeated.")

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(1)

    conn, addr = server.accept()

    with conn:
        conn.settimeout(15.0)
        conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

        print(
            "PASS: accepted native TCP connection from "
            f"{addr[0]}:{addr[1]}"
        )

        conn.sendall(payload)

        print("PASS: submitted exactly 1460 payload bytes.")

        conn.shutdown(socket.SHUT_WR)

        print(
            "PASS: host FIN sent; waiting for IIgs FIN."
        )

        deadline = time.monotonic() + 15.0

        while time.monotonic() < deadline:
            try:
                data = conn.recv(4096)
            except socket.timeout:
                continue

            if not data:
                print(
                    "PASS: received IIgs FIN; "
                    "RX1-B close complete."
                )
                sys.exit(0)

        print("FAIL: timeout waiting for IIgs FIN.")
        sys.exit(1)