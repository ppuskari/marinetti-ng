#!/usr/bin/env python3

import socket
import sys

HOST = "0.0.0.0"
PORT = 6502
SIZE = 1000

payload = bytes(
    ((i % 255) + 1)
    for i in range(SIZE)
)

print(f"Listening on {HOST}:{PORT}; start PGTTCPRXTEST on the IIgs.")
print("RX2-A: exactly 1000 bytes, pattern 01..FF repeated.")
print("IIgs ring starts at FE01: expected staged split 511 + 489.")

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(1)
    server.settimeout(20.0)

    try:
        conn, addr = server.accept()
    except socket.timeout:
        print("FAIL: timeout waiting for IIgs TCP connection.")
        sys.exit(1)

    with conn:
        conn.settimeout(15.0)

        conn.setsockopt(
            socket.IPPROTO_TCP,
            socket.TCP_NODELAY,
            1
        )

        print(
            "PASS: accepted native TCP connection from "
            f"{addr[0]}:{addr[1]}"
        )

        conn.sendall(payload)

        print("PASS: submitted exactly 1000 payload bytes.")

        conn.shutdown(socket.SHUT_WR)

        print(
            "PASS: host FIN sent; waiting for IIgs FIN."
        )

        while True:
            try:
                data = conn.recv(4096)
            except socket.timeout:
                print("FAIL: timeout waiting for IIgs FIN.")
                sys.exit(1)

            if not data:
                print(
                    "PASS: received IIgs FIN; "
                    "RX2-A close complete."
                )
                sys.exit(0)