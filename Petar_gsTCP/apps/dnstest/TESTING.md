# PGTDNSTest hardware test

`PGTDNSTest` is the end-to-end P2 DHCP and DNS diagnostic. It first performs the
same checked Discover/Offer/Request/ACK exchange as `PGTDHCPTest`. It then uses
the DNS server from that ACK, determines whether the server is on the local
subnet, resolves the appropriate direct or router MAC address, and sends an A
query for `example.com` from UDP port 6502.

The response must match the server address, client address, ports and DNS
transaction ID. The program rejects fragmented or truncated replies, validates
the IPv4 checksum and any nonzero UDP checksum, bounds the question and answer
sections, safely skips labels and compression pointers, and returns the first
IN-class IPv4 A answer.

## Build

From `C:\AppleIIgsDev_02\marinetti-ng`:

```powershell
.\Petar_gsTCP\scripts\Build-DNSTest.ps1
```

This creates:

- `build-local\PGTDNSTEST` - GS/OS S16 application;
- `build-local\PGTDNSTest.po` - 32 MiB ProDOS test volume.

## Run on the IIgs

1. Disconnect Marinetti while leaving Ethernet connected.
2. Mount `PGTDNSTest.po`, or copy `PGTDNSTEST` to a ProDOS volume.
3. Launch `PGTDNSTEST` and enter `4` for the validated Uthernet II slot.
4. Capture the complete screen before pressing Return.

After the already-validated DHCP lines, a successful DNS phase resembles:

```text
ARP for DNS next hop; waiting...
DNS next-hop MAC: $84:D9:E0:78:91:92
DNS A query for example.com sent; waiting...
PASS: example.com A address: $...
TX=$0004 RX=$.... RXwrap=$....
```

The resolved address can vary because `example.com` may return different valid
addresses. `TX=$0004` is the ideal no-retry path: DHCP Discover, DHCP Request,
ARP request and DNS query. Extra received MACRAW frames are normal.

## Interpreting failures

- `DNS phase skipped` means the DHCP ACK did not include option 6.
- `DNS next-hop ARP timed out` means the chosen direct DNS host or router did
  not answer ARP.
- `No valid DNS response` means no packet passed all address, checksum, DNS
  identity and bounded-section checks before the retry limit.
- A router that sets DNS truncation (`TC`) requires TCP fallback, which this
  diagnostic intentionally rejects and the production resolver will add later.

Press Escape to abort a bounded wait. Reconnect Marinetti or reboot after the
test and send the entire result screen.

## Confirmed hardware result

The end-to-end diagnostic passed on Uthernet II in slot 4. DHCP supplied
`192.168.7.54/22`, router and DNS `192.168.4.1`, and lease `$000031F5`. The DNS
next hop resolved to `$84:D9:E0:78:91:92`, and the checked compressed response
returned `example.com` A address `172.66.147.243` (`$AC.42.93.F3`). Final
counters were `TX=$0004 RX=$0009 RXwrap=$0000`, the ideal no-retry transmit
path. The resolved address and lease duration can legitimately vary on later
runs.
