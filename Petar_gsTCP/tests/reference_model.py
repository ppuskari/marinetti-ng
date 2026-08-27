"""Executable wire-format oracle for Petar_gsTCP host tests.

This module favors clarity over speed. Production code lives in 65C816 source.
"""

from __future__ import annotations

from dataclasses import dataclass


ETHERNET_MIN_FRAME = 60


def internet_checksum(data: bytes, initial: int = 0) -> int:
    """Return the RFC 1071 one's-complement checksum."""
    total = initial
    end = len(data) & ~1
    for offset in range(0, end, 2):
        total += (data[offset] << 8) | data[offset + 1]
    if end != len(data):
        total += data[end] << 8
    while total >> 16:
        total = (total & 0xFFFF) + (total >> 16)
    return (~total) & 0xFFFF


def build_arp_request(local_mac: bytes, local_ip: bytes, target_ip: bytes) -> bytes:
    """Build a minimum-size Ethernet/IPv4 ARP request."""
    if len(local_mac) != 6 or len(local_ip) != 4 or len(target_ip) != 4:
        raise ValueError("ARP addresses must be 6/4/4 bytes")
    frame = bytearray(ETHERNET_MIN_FRAME)
    frame[0:6] = b"\xff" * 6
    frame[6:12] = local_mac
    frame[12:14] = b"\x08\x06"
    frame[14:22] = bytes.fromhex("0001080006040001")
    frame[22:28] = local_mac
    frame[28:32] = local_ip
    frame[38:42] = target_ip
    return bytes(frame)


def build_icmp_echo_request(
    local_mac: bytes,
    remote_mac: bytes,
    local_ip: bytes,
    remote_ip: bytes,
    *,
    identifier: int = 0x5047,
    sequence: int = 1,
    payload: bytes = b"Petar_gsTCP/IIgs ping payload!!!",
) -> bytes:
    """Build an Ethernet II IPv4 ICMP echo request with no IP options."""
    if len(local_mac) != 6 or len(remote_mac) != 6:
        raise ValueError("Ethernet addresses must be 6 bytes")
    if len(local_ip) != 4 or len(remote_ip) != 4:
        raise ValueError("IPv4 addresses must be 4 bytes")
    if len(payload) > 1472:
        raise ValueError("ICMP payload exceeds Ethernet MTU")
    icmp = bytearray(8 + len(payload))
    icmp[0] = 8
    icmp[4:6] = identifier.to_bytes(2, "big")
    icmp[6:8] = sequence.to_bytes(2, "big")
    icmp[8:] = payload
    icmp[2:4] = internet_checksum(icmp).to_bytes(2, "big")

    ip = bytearray(20)
    ip[0] = 0x45
    ip[2:4] = (20 + len(icmp)).to_bytes(2, "big")
    ip[4:6] = sequence.to_bytes(2, "big")
    ip[6:8] = b"\x40\x00"
    ip[8] = 64
    ip[9] = 1
    ip[12:16] = local_ip
    ip[16:20] = remote_ip
    ip[10:12] = internet_checksum(ip).to_bytes(2, "big")
    return remote_mac + local_mac + b"\x08\x00" + bytes(ip) + bytes(icmp)


def is_icmp_echo_reply(
    frame: bytes,
    local_ip: bytes,
    remote_ip: bytes,
    *,
    identifier: int = 0x5047,
    sequence: int = 1,
) -> bool:
    """Validate the fixed-header echo reply subset used by PGTPingTest."""
    if len(frame) < 42 or frame[12:14] != b"\x08\x00":
        return False
    ip = frame[14:]
    if ip[0] != 0x45 or ip[9] != 1 or ip[12:16] != remote_ip or ip[16:20] != local_ip:
        return False
    total_length = int.from_bytes(ip[2:4], "big")
    if total_length < 28 or 14 + total_length > len(frame):
        return False
    if internet_checksum(ip[:20]) != 0:
        return False
    icmp = ip[20:total_length]
    return (
        len(icmp) >= 8
        and icmp[0:2] == b"\x00\x00"
        and int.from_bytes(icmp[4:6], "big") == identifier
        and int.from_bytes(icmp[6:8], "big") == sequence
        and internet_checksum(icmp) == 0
    )


def udp_ipv4_checksum(source_ip: bytes, dest_ip: bytes, datagram: bytes) -> int:
    """Return an IPv4 UDP checksum, mapping the computed zero value to 0xffff."""
    if len(source_ip) != 4 or len(dest_ip) != 4 or len(datagram) > 0xFFFF:
        raise ValueError("invalid IPv4 UDP checksum input")
    pseudo = source_ip + dest_ip + b"\x00\x11" + len(datagram).to_bytes(2, "big")
    checksum = internet_checksum(pseudo + datagram)
    return 0xFFFF if checksum == 0 else checksum


def tcp_ipv4_checksum(source_ip: bytes, dest_ip: bytes, segment: bytes) -> int:
    """Return the IPv4 TCP checksum for one complete TCP segment."""
    if len(source_ip) != 4 or len(dest_ip) != 4 or len(segment) > 0xFFFF:
        raise ValueError("invalid IPv4 TCP checksum input")
    pseudo = source_ip + dest_ip + b"\x00\x06" + len(segment).to_bytes(2, "big")
    return internet_checksum(pseudo + segment)


def build_tcp_frame(
    local_mac: bytes,
    remote_mac: bytes,
    local_ip: bytes,
    remote_ip: bytes,
    local_port: int,
    remote_port: int,
    sequence: int,
    acknowledgment: int,
    flags: int,
    *,
    window: int,
    payload: bytes = b"",
    options: bytes = b"",
    ip_id: int = 0,
) -> bytes:
    """Build a no-fragment Ethernet/IPv4 TCP frame for the native subset."""
    if len(local_mac) != 6 or len(remote_mac) != 6:
        raise ValueError("Ethernet addresses must be 6 bytes")
    if len(local_ip) != 4 or len(remote_ip) != 4:
        raise ValueError("IPv4 addresses must be 4 bytes")
    if len(options) > 40 or len(options) % 4:
        raise ValueError("TCP options must be padded to a 32-bit boundary")
    if len(payload) + 20 + len(options) > 1500:
        raise ValueError("TCP segment exceeds the initial Ethernet subset")
    tcp = bytearray(20 + len(options) + len(payload))
    tcp[0:2] = local_port.to_bytes(2, "big")
    tcp[2:4] = remote_port.to_bytes(2, "big")
    tcp[4:8] = sequence.to_bytes(4, "big")
    tcp[8:12] = acknowledgment.to_bytes(4, "big")
    tcp[12] = ((20 + len(options)) // 4) << 4
    tcp[13] = flags
    tcp[14:16] = window.to_bytes(2, "big")
    tcp[20 : 20 + len(options)] = options
    tcp[20 + len(options) :] = payload
    tcp[16:18] = tcp_ipv4_checksum(local_ip, remote_ip, tcp).to_bytes(2, "big")

    ip = bytearray(20)
    ip[0] = 0x45
    ip[2:4] = (20 + len(tcp)).to_bytes(2, "big")
    ip[4:6] = ip_id.to_bytes(2, "big")
    ip[6:8] = b"\x40\x00"
    ip[8] = 64
    ip[9] = 6
    ip[12:16] = local_ip
    ip[16:20] = remote_ip
    ip[10:12] = internet_checksum(ip).to_bytes(2, "big")
    return remote_mac + local_mac + b"\x08\x00" + bytes(ip) + bytes(tcp)


def build_tcp_syn_frame(
    local_mac: bytes,
    remote_mac: bytes,
    local_ip: bytes,
    remote_ip: bytes,
    local_port: int,
    remote_port: int,
    iss: int,
    *,
    window: int = 16_383,
    mss: int = 1460,
) -> bytes:
    """Build the active-open SYN used by the first native client."""
    if not 536 <= mss <= 1460:
        raise ValueError("initial MSS must be 536..1460")
    return build_tcp_frame(
        local_mac,
        remote_mac,
        local_ip,
        remote_ip,
        local_port,
        remote_port,
        iss,
        0,
        0x02,
        window=window,
        options=b"\x02\x04" + mss.to_bytes(2, "big"),
        ip_id=iss & 0xFFFF,
    )


@dataclass(frozen=True)
class SynAck:
    sequence: int
    acknowledgment: int
    window: int
    mss: int


def parse_tcp_syn_ack(
    frame: bytes,
    local_ip: bytes,
    remote_ip: bytes,
    local_port: int,
    remote_port: int,
    send_next: int,
) -> SynAck:
    """Validate the fixed IPv4 active-open SYN+ACK subset."""
    if len(frame) < 54 or frame[12:14] != b"\x08\x00":
        raise ValueError("not an IPv4 TCP frame")
    ip = frame[14:]
    if ip[0] != 0x45 or ip[9] != 6 or internet_checksum(ip[:20]) != 0:
        raise ValueError("invalid IPv4 TCP header")
    if int.from_bytes(ip[6:8], "big") & 0x3FFF:
        raise ValueError("fragmented SYN+ACK")
    if ip[12:16] != remote_ip or ip[16:20] != local_ip:
        raise ValueError("SYN+ACK addresses do not match")
    total_length = int.from_bytes(ip[2:4], "big")
    if total_length < 40 or 14 + total_length > len(frame):
        raise ValueError("invalid SYN+ACK length")
    tcp = ip[20:total_length]
    if int.from_bytes(tcp[0:2], "big") != remote_port or int.from_bytes(tcp[2:4], "big") != local_port:
        raise ValueError("SYN+ACK ports do not match")
    if tcp_ipv4_checksum(remote_ip, local_ip, tcp) != 0:
        raise ValueError("invalid SYN+ACK checksum")
    header_length = (tcp[12] >> 4) * 4
    if header_length < 20 or header_length > len(tcp) or tcp[13] & 0x16 != 0x12:
        raise ValueError("invalid SYN+ACK flags or data offset")
    acknowledgment = int.from_bytes(tcp[8:12], "big")
    if acknowledgment != send_next:
        raise ValueError("SYN+ACK does not acknowledge our SYN")
    mss = 536
    offset = 20
    while offset < header_length:
        kind = tcp[offset]
        if kind == 0:
            break
        if kind == 1:
            offset += 1
            continue
        if offset + 1 >= header_length:
            raise ValueError("truncated TCP option")
        length = tcp[offset + 1]
        if length < 2 or offset + length > header_length:
            raise ValueError("invalid TCP option length")
        if kind == 2 and length == 4:
            mss = min(1460, int.from_bytes(tcp[offset + 2 : offset + 4], "big"))
        offset += length
    return SynAck(
        sequence=int.from_bytes(tcp[4:8], "big"),
        acknowledgment=acknowledgment,
        window=int.from_bytes(tcp[14:16], "big"),
        mss=mss,
    )


@dataclass(frozen=True)
class TcpReceiveDecision:
    accepted: bool
    recv_next: int
    acknowledge_now: bool
    peer_finished: bool = False


def accept_in_order_tcp_segment(
    expected_sequence: int,
    sequence: int,
    payload_length: int,
    ring_free_bytes: int,
    *,
    fin: bool = False,
) -> TcpReceiveDecision:
    """Model the allocation-free established receive decision."""
    if payload_length < 0 or ring_free_bytes < 0:
        raise ValueError("negative TCP length or ring space")
    if sequence != expected_sequence or payload_length > ring_free_bytes:
        return TcpReceiveDecision(False, expected_sequence, True)
    recv_next = (expected_sequence + payload_length + int(fin)) & 0xFFFFFFFF
    return TcpReceiveDecision(True, recv_next, payload_length > 0 or fin, fin)


def _build_ipv4_udp_frame(
    local_mac: bytes,
    source_ip: bytes,
    dest_ip: bytes,
    source_port: int,
    dest_port: int,
    payload: bytes,
    *,
    dest_mac: bytes = b"\xff" * 6,
    ip_id: int = 0,
    with_udp_checksum: bool = False,
) -> bytes:
    udp = bytearray(8 + len(payload))
    udp[0:2] = source_port.to_bytes(2, "big")
    udp[2:4] = dest_port.to_bytes(2, "big")
    udp[4:6] = len(udp).to_bytes(2, "big")
    udp[8:] = payload
    if with_udp_checksum:
        udp[6:8] = udp_ipv4_checksum(source_ip, dest_ip, udp).to_bytes(2, "big")

    ip = bytearray(20)
    ip[0] = 0x45
    ip[2:4] = (20 + len(udp)).to_bytes(2, "big")
    ip[4:6] = ip_id.to_bytes(2, "big")
    ip[6:8] = b"\x40\x00"
    ip[8] = 64
    ip[9] = 17
    ip[12:16] = source_ip
    ip[16:20] = dest_ip
    ip[10:12] = internet_checksum(ip).to_bytes(2, "big")
    return dest_mac + local_mac + b"\x08\x00" + bytes(ip) + bytes(udp)


def build_dhcp_client_frame(
    local_mac: bytes,
    xid: int,
    message_type: int,
    *,
    requested_ip: bytes | None = None,
    server_id: bytes | None = None,
) -> bytes:
    """Build a broadcast DHCPDISCOVER or DHCPREQUEST Ethernet frame."""
    if len(local_mac) != 6 or not 0 <= xid <= 0xFFFFFFFF:
        raise ValueError("invalid DHCP client identity")
    if message_type not in (1, 3):
        raise ValueError("client message must be DISCOVER or REQUEST")
    if message_type == 3 and (requested_ip is None or server_id is None):
        raise ValueError("DHCPREQUEST requires requested IP and server ID")

    bootp = bytearray(240)
    bootp[0:4] = b"\x01\x01\x06\x00"
    bootp[4:8] = xid.to_bytes(4, "big")
    bootp[10:12] = b"\x80\x00"
    bootp[28:34] = local_mac
    bootp[236:240] = bytes.fromhex("63825363")
    options = bytearray((53, 1, message_type, 61, 7, 1))
    options.extend(local_mac)
    if message_type == 3:
        assert requested_ip is not None and server_id is not None
        if len(requested_ip) != 4 or len(server_id) != 4:
            raise ValueError("DHCP request addresses must be 4 bytes")
        options.extend((50, 4))
        options.extend(requested_ip)
        options.extend((54, 4))
        options.extend(server_id)
    options.extend((55, 7, 1, 3, 6, 51, 54, 58, 59, 255))
    return _build_ipv4_udp_frame(
        local_mac,
        b"\x00" * 4,
        b"\xff" * 4,
        68,
        67,
        bytes(bootp + options),
        ip_id=xid & 0xFFFF,
    )


@dataclass(frozen=True)
class DhcpReply:
    message_type: int
    offered_ip: bytes
    options: "DhcpOptions"


def parse_dhcp_reply_frame(frame: bytes, local_mac: bytes, xid: int) -> DhcpReply:
    """Validate and parse one unfragmented Ethernet/IPv4/UDP DHCP reply."""
    if len(frame) < 282 or frame[12:14] != b"\x08\x00":
        raise ValueError("not an IPv4 DHCP frame")
    ip = frame[14:]
    if ip[0] != 0x45 or ip[9] != 17 or internet_checksum(ip[:20]) != 0:
        raise ValueError("invalid IPv4 header")
    if int.from_bytes(ip[6:8], "big") & 0x3FFF:
        raise ValueError("fragmented DHCP reply")
    total_length = int.from_bytes(ip[2:4], "big")
    if total_length < 268 or 14 + total_length > len(frame):
        raise ValueError("invalid IPv4 total length")
    udp = ip[20:total_length]
    if udp[0:4] != bytes.fromhex("00430044"):
        raise ValueError("not DHCP server-to-client UDP")
    udp_length = int.from_bytes(udp[4:6], "big")
    if udp_length < 248 or udp_length > len(udp):
        raise ValueError("invalid UDP length")
    udp = udp[:udp_length]
    if udp[6:8] != b"\x00\x00" and internet_checksum(
        ip[12:20] + b"\x00\x11" + udp_length.to_bytes(2, "big") + udp
    ) != 0:
        raise ValueError("invalid UDP checksum")
    bootp = udp[8:]
    if bootp[0:4] != b"\x02\x01\x06\x00":
        raise ValueError("invalid BOOTP reply header")
    if int.from_bytes(bootp[4:8], "big") != xid or bootp[28:34] != local_mac:
        raise ValueError("DHCP reply is for another client")
    if bootp[236:240] != bytes.fromhex("63825363"):
        raise ValueError("missing DHCP magic cookie")
    options = parse_dhcp_options(bootp[240:])
    if options.message_type is None:
        raise ValueError("missing DHCP message type")
    return DhcpReply(options.message_type, bootp[16:20], options)


def build_dhcp_reply_frame(
    server_mac: bytes,
    local_mac: bytes,
    server_ip: bytes,
    offered_ip: bytes,
    xid: int,
    message_type: int,
    *,
    subnet_mask: bytes = bytes.fromhex("ffffff00"),
    router: bytes | None = None,
    dns_servers: tuple[bytes, ...] = (),
    lease_seconds: int = 3600,
) -> bytes:
    """Build a checked DHCP server fixture for host-side parser tests."""
    if router is None:
        router = server_ip
    bootp = bytearray(240)
    bootp[0:4] = b"\x02\x01\x06\x00"
    bootp[4:8] = xid.to_bytes(4, "big")
    bootp[16:20] = offered_ip
    bootp[20:24] = server_ip
    bootp[28:34] = local_mac
    bootp[236:240] = bytes.fromhex("63825363")
    options = bytearray((53, 1, message_type, 54, 4))
    options.extend(server_ip)
    options.extend((1, 4))
    options.extend(subnet_mask)
    options.extend((3, 4))
    options.extend(router)
    if dns_servers:
        options.extend((6, 4 * len(dns_servers)))
        for address in dns_servers:
            options.extend(address)
    options.extend((51, 4))
    options.extend(lease_seconds.to_bytes(4, "big"))
    options.append(255)
    return _build_ipv4_udp_frame(
        server_mac,
        server_ip,
        b"\xff" * 4,
        67,
        68,
        bytes(bootp + options),
        dest_mac=local_mac,
        ip_id=xid & 0xFFFF,
        with_udp_checksum=True,
    )


def build_dns_query_frame(
    local_mac: bytes,
    next_hop_mac: bytes,
    local_ip: bytes,
    dns_ip: bytes,
    transaction_id: int,
    name: str,
    *,
    source_port: int = 6502,
) -> bytes:
    """Build one recursive DNS A query in an Ethernet/IPv4/UDP frame."""
    dns = bytearray(12)
    dns[0:2] = transaction_id.to_bytes(2, "big")
    dns[2:4] = b"\x01\x00"
    dns[4:6] = b"\x00\x01"
    dns.extend(encode_dns_name(name))
    dns.extend(bytes.fromhex("00010001"))
    return _build_ipv4_udp_frame(
        local_mac,
        local_ip,
        dns_ip,
        source_port,
        53,
        bytes(dns),
        dest_mac=next_hop_mac,
        ip_id=transaction_id,
    )


def parse_dns_a_response_frame(
    frame: bytes,
    local_ip: bytes,
    dns_ip: bytes,
    transaction_id: int,
    *,
    source_port: int = 6502,
) -> bytes:
    """Validate a DNS response and return the first bounded IN A answer."""
    if len(frame) < 58 or frame[12:14] != b"\x08\x00":
        raise ValueError("not an IPv4 DNS frame")
    ip = frame[14:]
    if ip[0] != 0x45 or ip[9] != 17 or internet_checksum(ip[:20]) != 0:
        raise ValueError("invalid DNS IPv4 header")
    if int.from_bytes(ip[6:8], "big") & 0x3FFF:
        raise ValueError("fragmented DNS response")
    if ip[12:16] != dns_ip or ip[16:20] != local_ip:
        raise ValueError("DNS response addresses do not match")
    total_length = int.from_bytes(ip[2:4], "big")
    if total_length < 40 or 14 + total_length > len(frame):
        raise ValueError("invalid DNS IPv4 length")
    udp = ip[20:total_length]
    if int.from_bytes(udp[0:2], "big") != 53 or int.from_bytes(udp[2:4], "big") != source_port:
        raise ValueError("DNS response ports do not match")
    udp_length = int.from_bytes(udp[4:6], "big")
    if udp_length < 20 or udp_length > len(udp):
        raise ValueError("invalid DNS UDP length")
    udp = udp[:udp_length]
    if udp[6:8] != b"\x00\x00" and internet_checksum(
        ip[12:20] + b"\x00\x11" + udp_length.to_bytes(2, "big") + udp
    ) != 0:
        raise ValueError("invalid DNS UDP checksum")
    dns = udp[8:]
    if int.from_bytes(dns[0:2], "big") != transaction_id:
        raise ValueError("DNS transaction ID does not match")
    flags = int.from_bytes(dns[2:4], "big")
    if not flags & 0x8000 or flags & 0x000F:
        raise ValueError("DNS response flag or RCODE failure")
    if flags & 0x0200:
        raise ValueError("truncated DNS response requires TCP")
    questions = int.from_bytes(dns[4:6], "big")
    answers = int.from_bytes(dns[6:8], "big")
    if questions != 1 or not 1 <= answers <= 16:
        raise ValueError("unsupported DNS section counts")
    _, offset = decode_dns_name(dns, 12)
    if offset + 4 > len(dns):
        raise ValueError("truncated DNS question")
    offset += 4
    for _ in range(answers):
        _, offset = decode_dns_name(dns, offset)
        if offset + 10 > len(dns):
            raise ValueError("truncated DNS answer")
        record_type = int.from_bytes(dns[offset : offset + 2], "big")
        record_class = int.from_bytes(dns[offset + 2 : offset + 4], "big")
        rdlength = int.from_bytes(dns[offset + 8 : offset + 10], "big")
        offset += 10
        if offset + rdlength > len(dns):
            raise ValueError("truncated DNS RDATA")
        if record_type == 1 and record_class == 1 and rdlength == 4:
            return dns[offset : offset + 4]
        offset += rdlength
    raise ValueError("DNS response contains no IN A answer")


def build_dns_a_response_frame(
    dns_mac: bytes,
    local_mac: bytes,
    dns_ip: bytes,
    local_ip: bytes,
    transaction_id: int,
    name: str,
    address: bytes,
    *,
    dest_port: int = 6502,
) -> bytes:
    """Build a compressed DNS A-response fixture for host tests."""
    question = encode_dns_name(name) + bytes.fromhex("00010001")
    dns = bytearray(12)
    dns[0:2] = transaction_id.to_bytes(2, "big")
    dns[2:4] = b"\x81\x80"
    dns[4:6] = b"\x00\x01"
    dns[6:8] = b"\x00\x01"
    dns.extend(question)
    dns.extend(bytes.fromhex("c00c000100010000003c0004"))
    dns.extend(address)
    return _build_ipv4_udp_frame(
        dns_mac,
        dns_ip,
        local_ip,
        53,
        dest_port,
        bytes(dns),
        dest_mac=local_mac,
        ip_id=transaction_id,
        with_udp_checksum=True,
    )


def ring_used(head: int, tail: int, mask: int) -> int:
    return (head - tail) & mask


def ring_free(head: int, tail: int, mask: int) -> int:
    return mask - ring_used(head, tail, mask)


def ring_write_spans(head: int, tail: int, mask: int, length: int) -> tuple[int, int, int]:
    """Return contiguous write spans and new head for a reserved-byte ring."""
    if length < 0 or length > ring_free(head, tail, mask):
        raise ValueError("insufficient ring space")
    first = min(length, (mask + 1) - head)
    second = length - first
    return first, second, (head + length) & mask


def encode_dns_name(name: str) -> bytes:
    """Encode a presentation-format host name without compression."""
    if name.endswith("."):
        name = name[:-1]
    if not name:
        return b"\x00"
    result = bytearray()
    for label in name.split("."):
        encoded = label.encode("ascii")
        if not encoded or len(encoded) > 63:
            raise ValueError("DNS label length must be 1..63")
        result.append(len(encoded))
        result.extend(encoded)
    if len(result) + 1 > 255:
        raise ValueError("encoded DNS name exceeds 255 bytes")
    result.append(0)
    return bytes(result)


def decode_dns_name(packet: bytes, offset: int) -> tuple[str, int]:
    """Decode a possibly compressed DNS name with loop and bounds checks."""
    labels: list[str] = []
    resume: int | None = None
    visited: set[int] = set()
    while True:
        if offset >= len(packet):
            raise ValueError("DNS name exceeds packet")
        if offset in visited:
            raise ValueError("DNS compression loop")
        visited.add(offset)
        length = packet[offset]
        if length & 0xC0 == 0xC0:
            if offset + 1 >= len(packet):
                raise ValueError("truncated DNS compression pointer")
            pointer = ((length & 0x3F) << 8) | packet[offset + 1]
            if pointer >= len(packet):
                raise ValueError("DNS compression pointer exceeds packet")
            if resume is None:
                resume = offset + 2
            offset = pointer
            continue
        if length & 0xC0:
            raise ValueError("reserved DNS label form")
        offset += 1
        if length == 0:
            return ".".join(labels), resume if resume is not None else offset
        if length > 63 or offset + length > len(packet):
            raise ValueError("invalid DNS label")
        labels.append(packet[offset : offset + length].decode("ascii"))
        offset += length


@dataclass(frozen=True)
class DhcpOptions:
    message_type: int | None = None
    subnet_mask: bytes | None = None
    router: bytes | None = None
    dns_servers: tuple[bytes, ...] = ()
    server_id: bytes | None = None
    lease_seconds: int | None = None


def parse_dhcp_options(data: bytes) -> DhcpOptions:
    """Parse the bounded option subset needed by the IIgs DHCP client."""
    message_type = None
    subnet_mask = None
    router = None
    dns_servers: tuple[bytes, ...] = ()
    server_id = None
    lease_seconds = None
    offset = 0
    while offset < len(data):
        code = data[offset]
        offset += 1
        if code == 0:
            continue
        if code == 255:
            break
        if offset >= len(data):
            raise ValueError("truncated DHCP option length")
        length = data[offset]
        offset += 1
        if offset + length > len(data):
            raise ValueError("truncated DHCP option value")
        value = data[offset : offset + length]
        offset += length
        if code == 53 and length == 1:
            message_type = value[0]
        elif code == 1 and length == 4:
            subnet_mask = value
        elif code == 3 and length >= 4:
            router = value[:4]
        elif code == 6 and length >= 4 and length % 4 == 0:
            dns_servers = tuple(value[i : i + 4] for i in range(0, length, 4))
        elif code == 54 and length == 4:
            server_id = value
        elif code == 51 and length == 4:
            lease_seconds = int.from_bytes(value, "big")
    return DhcpOptions(
        message_type=message_type,
        subnet_mask=subnet_mask,
        router=router,
        dns_servers=dns_servers,
        server_id=server_id,
        lease_seconds=lease_seconds,
    )
