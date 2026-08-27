#!/usr/bin/env python3

import socket
import sys
import time

HOST = "0.0.0.0"
PORT = 6502

MSS = 1460
SEGMENTS = 8
TOTAL = MSS * SEGMENTS

pattern = bytes(
    ((i % 255) + 1)
    for i in range(TOTAL)
)

print(f"Listening on {HOST}:{PORT}; start PGTTCPRXTEST on the IIgs.")
print("RX3-A: 8 consecutive full 1460-byte MSS segments.")
print(f"Total application payload: {TOTAL} bytes.")

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

        for n in range(SEGMENTS):
            start = n * MSS
            end = start + MSS

            conn.sendall(pattern[start:end])

        print(
            "PASS: submitted 8 x 1460 = "
            f"{TOTAL} payload bytes."
        )

        # Give the IIgs time to ACK all eight data segments
        # before causing a separate pure FIN.
        time.sleep(1.0)

        conn.shutdown(socket.SHUT_WR)

        print("PASS: host FIN sent; waiting for IIgs FIN.")

        while True:
            try:
                data = conn.recv(4096)
            except socket.timeout:
                print("FAIL: timeout waiting for IIgs FIN.")
                sys.exit(1)

            if not data:
                print(
                    "PASS: received IIgs FIN; "
                    "RX3-A close complete."
                )
                sys.exit(0)