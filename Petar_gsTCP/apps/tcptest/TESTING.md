# PGTTCPTest hardware test

`PGTTCPTest` is the first P3 native TCP wire/state diagnostic. It obtains a
fresh DHCP lease, selects the local or router next hop for `192.168.5.235`,
resolves that hop with ARP, and actively opens TCP port `6502` from local port
`49152`.

The IIgs accepts only an unfragmented IPv4 response with matching addresses and
ports, valid IPv4 and TCP pseudo-header checksums, a bounded TCP header/options
layout, exact SYN+ACK flags, and an ACK number matching its initial sequence.
It then sends the final ACK and a FIN+ACK. The host confirms that its kernel
accepted the connection and received the IIgs FIN.

This gate intentionally stages the small SYN+ACK in the DHCP diagnostic buffer.
Once it passes, established payload moves to the transactional direct-to-ring
path used by the DOC streaming build.

## Build

From `C:\AppleIIgsDev_02\marinetti-ng`:

```powershell
.\Petar_gsTCP\scripts\Build-TCPTest.ps1
```

This creates:

- `build-local\PGTTCPTEST` - GS/OS S16 application;
- `build-local\PGTTCPTest.po` - 32 MiB ProDOS test volume.

## Run

The current diagnostic target is `192.168.5.235:6502`. On that Windows PC,
allow inbound TCP port 6502 on the private LAN if Windows Firewall asks, then
start the one-shot listener:

```powershell
py -3 .\Petar_gsTCP\tools\tcp_test_server.py
```

Leave that window running. It waits up to five minutes by default; use
`--timeout 600` if more setup time is needed. On the IIgs:

1. Disconnect Marinetti and leave Ethernet connected.
2. Mount `build-local\PGTTCPTest.po` and launch `PGTTCPTEST`.
3. Enter `4` for the Uthernet II slot.
4. Photograph the complete IIgs screen and copy the two PASS lines from the PC.

The IIgs should report:

```text
PASS: DHCP ACK validated and applied.
P3 native TCP active open; Marinetti off.
TCP target: $C0.A8.05.EB
ARP for TCP next hop; waiting...
TCP next-hop MAC: $...
TCP SYN sent; waiting for checked SYN+ACK...
PASS: native TCP active open established.
Peer SEQ=$........ window=$.... MSS=$....
FIN+ACK sent; active close handoff complete.
```

The PC should report that it accepted the connection and received the IIgs FIN.
On the ideal no-retry path the final IIgs transmit count is six: DHCP Discover,
DHCP Request, ARP, SYN, ACK and FIN+ACK. Extra RX frames are normal in MACRAW
mode. Additional TX frames mean a bounded DHCP, ARP or SYN retry occurred.

If the listener PC is not `192.168.5.235`, change the four bytes at
`TCPRemoteIP` in `apps/tcptest/PGT.TCPTEST.CODE.S` and rebuild. Escape safely
aborts any receive wait.

## Confirmed hardware result

The diagnostic passed on a stock-speed IIgs with Uthernet II in slot 4. DHCP
assigned `192.168.7.54/22`; direct next-hop ARP resolved the listener MAC; and
the checksum- and sequence-validated SYN+ACK established the connection on the
first attempt. The peer advertised MSS `$05B4` (1460 bytes). Final counters
were `TX=$0006 RX=$0007 RXwrap=$0000`, exactly the ideal six-frame transmit
path. The host accepted `192.168.7.54:49152` and confirmed receipt of the IIgs
FIN and completion of the close handshake.
