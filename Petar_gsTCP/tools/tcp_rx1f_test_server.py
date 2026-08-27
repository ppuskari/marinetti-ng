#!/usr/bin/env python3

import socket
import time

HOST = "0.0.0.0"
PORT = 6502

print(f"Listening on {HOST}:{PORT}; start PGTTCPRXTEST on the IIgs.")
print("RX1-F: host sends no application payload.")
print("IIgs sends SND.NXT-1 ACK probe; Windows should answer with pure ACK.")

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

        print(
            "PASS: no application payload sent; "
            "waiting for IIgs probe / Windows ACK exchange."
        )

        time.sleep(5.0)

print(
    "RX1-F host interval complete; "
    "IIgs screen is the pure-ACK oracle."
)