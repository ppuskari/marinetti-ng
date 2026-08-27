from __future__ import annotations

import unittest

from reference_model import (
    build_arp_request,
    build_dhcp_client_frame,
    build_dhcp_reply_frame,
    build_dns_a_response_frame,
    build_dns_query_frame,
    build_icmp_echo_request,
    build_tcp_frame,
    build_tcp_syn_frame,
    decode_dns_name,
    encode_dns_name,
    internet_checksum,
    is_icmp_echo_reply,
    parse_dhcp_options,
    parse_dhcp_reply_frame,
    parse_dns_a_response_frame,
    parse_tcp_syn_ack,
    accept_in_order_tcp_segment,
    ring_free,
    ring_write_spans,
    ring_used,
)
from Petar_gsTCP.tools.send_docstreamtest import tone_payload


class ChecksumTests(unittest.TestCase):
    def test_empty(self) -> None:
        self.assertEqual(internet_checksum(b""), 0xFFFF)

    def test_even_and_odd_lengths(self) -> None:
        self.assertEqual(internet_checksum(bytes.fromhex("0001f203f4f5f6f7")), 0x220D)
        self.assertEqual(internet_checksum(b"123456789"), 0xF62A)

    def test_valid_header_rechecks_to_zero(self) -> None:
        header = bytes.fromhex("450000730000400040110000c0a80001c0a800c7")
        checksum = internet_checksum(header)
        completed = header[:10] + checksum.to_bytes(2, "big") + header[12:]
        self.assertEqual(internet_checksum(completed), 0)


class RingTests(unittest.TestCase):
    def test_wrap_and_reserved_byte(self) -> None:
        self.assertEqual(ring_used(2, 0xFFFE, 0xFFFF), 4)
        self.assertEqual(ring_free(2, 0xFFFE, 0xFFFF), 0xFFFB)
        self.assertEqual(ring_free(0xFFFF, 0, 0xFFFF), 0)

    def test_contiguous_and_wrapped_write_spans(self) -> None:
        self.assertEqual(ring_write_spans(100, 0, 0x3FFF, 1460), (1460, 0, 1560))
        self.assertEqual(ring_write_spans(0x3F00, 0x2000, 0x3FFF, 1460), (256, 1204, 1204))
        self.assertEqual(ring_write_spans(0xFFF0, 0x8000, 0xFFFF, 1092), (16, 1076, 1076))

    def test_ring_write_rejects_overcommit(self) -> None:
        with self.assertRaises(ValueError):
            ring_write_spans(0x3F00, 0x3F01, 0x3FFF, 1)


class PacketBuildTests(unittest.TestCase):
    def setUp(self) -> None:
        self.local_mac = bytes.fromhex("0008dc111111")
        self.remote_mac = bytes.fromhex("001122334455")
        self.local_ip = bytes([192, 168, 7, 54])
        self.remote_ip = bytes([192, 168, 4, 1])

    def test_arp_request_layout_and_padding(self) -> None:
        frame = build_arp_request(self.local_mac, self.local_ip, self.remote_ip)
        self.assertEqual(len(frame), 60)
        self.assertEqual(frame[:6], b"\xff" * 6)
        self.assertEqual(frame[6:14], self.local_mac + b"\x08\x06")
        self.assertEqual(frame[14:22], bytes.fromhex("0001080006040001"))
        self.assertEqual(frame[22:32], self.local_mac + self.local_ip)
        self.assertEqual(frame[32:38], b"\x00" * 6)
        self.assertEqual(frame[38:42], self.remote_ip)
        self.assertEqual(frame[42:], b"\x00" * 18)

    def test_icmp_request_checksums(self) -> None:
        frame = build_icmp_echo_request(
            self.local_mac, self.remote_mac, self.local_ip, self.remote_ip
        )
        self.assertEqual(frame[12:14], b"\x08\x00")
        total_length = int.from_bytes(frame[16:18], "big")
        self.assertEqual(total_length, len(frame) - 14)
        self.assertEqual(internet_checksum(frame[14:34]), 0)
        self.assertEqual(internet_checksum(frame[34:]), 0)

    def test_echo_reply_validation(self) -> None:
        request = bytearray(build_icmp_echo_request(
            self.local_mac, self.remote_mac, self.local_ip, self.remote_ip
        ))
        request[0:6], request[6:12] = request[6:12], request[0:6]
        request[26:30], request[30:34] = request[30:34], request[26:30]
        request[24:26] = b"\x00\x00"
        request[24:26] = internet_checksum(request[14:34]).to_bytes(2, "big")
        request[34] = 0
        request[36:38] = b"\x00\x00"
        request[36:38] = internet_checksum(request[34:]).to_bytes(2, "big")
        self.assertTrue(is_icmp_echo_reply(
            bytes(request), self.local_ip, self.remote_ip
        ))
        request[41] ^= 1
        self.assertFalse(is_icmp_echo_reply(
            bytes(request), self.local_ip, self.remote_ip
        ))


class TcpTests(unittest.TestCase):
    def setUp(self) -> None:
        self.local_mac = bytes.fromhex("0008dc111111")
        self.remote_mac = bytes.fromhex("84d9e0789192")
        self.local_ip = bytes([192, 168, 7, 54])
        self.remote_ip = bytes([192, 168, 5, 235])
        self.local_port = 49152
        self.remote_port = 6502
        self.iss = 0x50471111

    def test_active_open_syn_and_syn_ack(self) -> None:
        syn = build_tcp_syn_frame(
            self.local_mac, self.remote_mac, self.local_ip, self.remote_ip,
            self.local_port, self.remote_port, self.iss
        )
        self.assertEqual(syn[34 + 13], 0x02)
        self.assertEqual(syn[34 + 20 : 34 + 24], bytes.fromhex("020405b4"))
        self.assertEqual(internet_checksum(syn[14:34]), 0)

        peer_sequence = 0x12345678
        syn_ack = build_tcp_frame(
            self.remote_mac, self.local_mac, self.remote_ip, self.local_ip,
            self.remote_port, self.local_port, peer_sequence, self.iss + 1,
            0x12, window=32768, options=bytes.fromhex("020404b0")
        )
        parsed = parse_tcp_syn_ack(
            syn_ack, self.local_ip, self.remote_ip, self.local_port,
            self.remote_port, self.iss + 1
        )
        self.assertEqual(parsed.sequence, peer_sequence)
        self.assertEqual(parsed.window, 32768)
        self.assertEqual(parsed.mss, 1200)

    def test_bad_syn_ack_is_rejected(self) -> None:
        frame = build_tcp_frame(
            self.remote_mac, self.local_mac, self.remote_ip, self.local_ip,
            self.remote_port, self.local_port, 1, self.iss + 2, 0x12,
            window=4096
        )
        with self.assertRaises(ValueError):
            parse_tcp_syn_ack(
                frame, self.local_ip, self.remote_ip, self.local_port,
                self.remote_port, self.iss + 1
            )

    def test_in_order_receive_and_duplicate_ack_policy(self) -> None:
        accepted = accept_in_order_tcp_segment(1000, 1000, 1200, 4096)
        self.assertTrue(accepted.accepted)
        self.assertEqual(accepted.recv_next, 2200)
        future = accept_in_order_tcp_segment(2200, 3400, 1200, 4096)
        self.assertFalse(future.accepted)
        self.assertTrue(future.acknowledge_now)
        full = accept_in_order_tcp_segment(2200, 2200, 1200, 1000)
        self.assertFalse(full.accepted)
        fin = accept_in_order_tcp_segment(2200, 2200, 0, 0, fin=True)
        self.assertTrue(fin.accepted)
        self.assertEqual(fin.recv_next, 2201)
        self.assertTrue(fin.peer_finished)


class DocSenderTests(unittest.TestCase):
    def test_tone_is_continuous_and_never_contains_doc_terminator(self) -> None:
        first = tone_payload(0, 1092, 440.0)
        second = tone_payload(1092, 1092, 440.0)
        combined = tone_payload(0, 2184, 440.0)
        self.assertEqual(first + second, combined)
        self.assertNotIn(0, combined)


class DhcpFrameTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client_mac = bytes.fromhex("0008dc111111")
        self.server_mac = bytes.fromhex("84d9e0789192")
        self.server_ip = bytes([192, 168, 4, 1])
        self.offered_ip = bytes([192, 168, 7, 54])
        self.xid = 0x50471111

    def test_discover_and_request_layout(self) -> None:
        discover = build_dhcp_client_frame(self.client_mac, self.xid, 1)
        self.assertEqual(discover[:6], b"\xff" * 6)
        self.assertEqual(discover[12:14], b"\x08\x00")
        self.assertEqual(discover[26:34], b"\x00" * 4 + b"\xff" * 4)
        self.assertEqual(discover[34:42], bytes.fromhex("00440043") + (len(discover) - 34).to_bytes(2, "big") + b"\x00\x00")
        self.assertIn(bytes.fromhex("350101"), discover[282:])

        request = build_dhcp_client_frame(
            self.client_mac,
            self.xid,
            3,
            requested_ip=self.offered_ip,
            server_id=self.server_ip,
        )
        self.assertIn(b"\x32\x04" + self.offered_ip, request[282:])
        self.assertIn(b"\x36\x04" + self.server_ip, request[282:])
        self.assertEqual(internet_checksum(request[14:34]), 0)

    def test_offer_and_ack_parse_with_udp_checksum(self) -> None:
        for message_type in (2, 5):
            frame = build_dhcp_reply_frame(
                self.server_mac,
                self.client_mac,
                self.server_ip,
                self.offered_ip,
                self.xid,
                message_type,
                dns_servers=(self.server_ip, bytes([1, 1, 1, 1])),
            )
            reply = parse_dhcp_reply_frame(frame, self.client_mac, self.xid)
            self.assertEqual(reply.message_type, message_type)
            self.assertEqual(reply.offered_ip, self.offered_ip)
            self.assertEqual(reply.options.router, self.server_ip)
            self.assertEqual(len(reply.options.dns_servers), 2)

    def test_reply_identity_and_checksum_rejected(self) -> None:
        frame = bytearray(build_dhcp_reply_frame(
            self.server_mac,
            self.client_mac,
            self.server_ip,
            self.offered_ip,
            self.xid,
            2,
        ))
        with self.assertRaises(ValueError):
            parse_dhcp_reply_frame(frame, self.client_mac, self.xid + 1)
        frame[-2] ^= 1
        with self.assertRaises(ValueError):
            parse_dhcp_reply_frame(frame, self.client_mac, self.xid)


class DnsTests(unittest.TestCase):
    def test_name_round_trip(self) -> None:
        wire = encode_dns_name("stream.example.com")
        self.assertEqual(decode_dns_name(wire, 0), ("stream.example.com", len(wire)))

    def test_compressed_name(self) -> None:
        packet = encode_dns_name("example.com") + b"\x06stream\xc0\x00"
        self.assertEqual(decode_dns_name(packet, 13), ("stream.example.com", 22))

    def test_compression_loop_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            decode_dns_name(b"\xc0\x00", 0)

    def test_dns_query_and_compressed_a_response(self) -> None:
        local_mac = bytes.fromhex("0008dc111111")
        dns_mac = bytes.fromhex("84d9e0789192")
        local_ip = bytes([192, 168, 7, 54])
        dns_ip = bytes([192, 168, 4, 1])
        transaction_id = 0x5047
        query = build_dns_query_frame(
            local_mac, dns_mac, local_ip, dns_ip, transaction_id, "example.com"
        )
        self.assertEqual(len(query), 71)
        self.assertEqual(query[34:38], bytes.fromhex("19660035"))
        self.assertEqual(query[42:48], bytes.fromhex("504701000001"))
        self.assertEqual(internet_checksum(query[14:34]), 0)

        response = build_dns_a_response_frame(
            dns_mac,
            local_mac,
            dns_ip,
            local_ip,
            transaction_id,
            "example.com",
            bytes([93, 184, 216, 34]),
        )
        self.assertEqual(
            parse_dns_a_response_frame(
                response, local_ip, dns_ip, transaction_id
            ),
            bytes([93, 184, 216, 34]),
        )

    def test_dns_response_corruption_is_rejected(self) -> None:
        local_mac = bytes.fromhex("0008dc111111")
        dns_mac = bytes.fromhex("84d9e0789192")
        local_ip = bytes([192, 168, 7, 54])
        dns_ip = bytes([192, 168, 4, 1])
        response = bytearray(build_dns_a_response_frame(
            dns_mac, local_mac, dns_ip, local_ip, 0x5047,
            "example.com", bytes([93, 184, 216, 34])
        ))
        response[-1] ^= 1
        with self.assertRaises(ValueError):
            parse_dns_a_response_frame(response, local_ip, dns_ip, 0x5047)


class DhcpTests(unittest.TestCase):
    def test_minimum_ack_options(self) -> None:
        options = bytes.fromhex(
            "350105"              # DHCP ACK
            "0104ffffff00"        # subnet mask
            "0304c0a80101"        # router
            "0608c0a8010101010101"# two DNS servers
            "3604c0a80101"        # server identifier
            "330400000e10"        # one-hour lease
            "ff"
        )
        parsed = parse_dhcp_options(options)
        self.assertEqual(parsed.message_type, 5)
        self.assertEqual(parsed.subnet_mask, bytes.fromhex("ffffff00"))
        self.assertEqual(parsed.router, bytes.fromhex("c0a80101"))
        self.assertEqual(parsed.dns_servers, (bytes.fromhex("c0a80101"), bytes.fromhex("01010101")))
        self.assertEqual(parsed.lease_seconds, 3600)

    def test_truncation_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            parse_dhcp_options(bytes.fromhex("0608c0a8"))


if __name__ == "__main__":
    unittest.main()
