#!/usr/bin/env python3

import socket
import sys
import time

HOST = "0.0.0.0"
PORT = 6502
SIZE = 512

payload = bytes(
    ((i % 255) + 1)
    for i in range(SIZE)
)

print(f"Listening on {HOST}:{PORT}; start PGTTCPRXTEST on the IIgs.")
print("RX2-C: exactly 512 bytes.")
print("IIgs ring has only 511 bytes free after handshake.")

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

        print("PASS: submitted exactly 512 payload bytes.")
        print(
            "Waiting while IIgs proves ring-full "
            "transactional rejection..."
        )

        time.sleep(3.0)

print(
    "RX2-C stimulus complete; "
    "IIgs screen is the correctness oracle."
)