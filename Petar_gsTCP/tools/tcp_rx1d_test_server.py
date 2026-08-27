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
print("RX1-D: send one 1460-byte MSS; IIgs suppresses first ACK.")
print("Windows retransmission is the duplicate test stimulus.")

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(1)

    conn, addr = server.accept()

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

        print("PASS: submitted exactly 1460 payload bytes.")
        print(
            "Waiting 5 seconds for TCP retransmission "
            "caused by suppressed first ACK..."
        )

        time.sleep(5.0)

        print(
            "RX1-D host stimulus complete; "
            "IIgs screen is the duplicate-reject oracle."
        )