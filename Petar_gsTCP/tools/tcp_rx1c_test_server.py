#!/usr/bin/env python3

import socket
import time

HOST = "0.0.0.0"
PORT = 6502
SIZE = 1460

payload = bytes(
    ((i % 255) + 1)
    for i in range(SIZE)
)

print(f"Listening on {HOST}:{PORT}; start PGTTCPRXTEST on the IIgs.")
print("RX1-C: 1460-byte payload; IIgs injects one staged-byte fault.")

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(1)

    conn, addr = server.accept()

    with conn:
        print(
            "PASS: accepted native TCP connection from "
            f"{addr[0]}:{addr[1]}"
        )

        conn.sendall(payload)

        print("PASS: submitted 1460-byte RX1-C test payload.")
        print(
            "Waiting briefly while IIgs proves checksum "
            "rejection/no-publish."
        )

        time.sleep(4.0)

print(
    "RX1-C host stimulus complete; "
    "IIgs screen is the correctness oracle."
)