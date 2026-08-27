# Implementation milestones

## P0 - foundations

- Assemble the production checksum and W5100 indirect-bus primitives.
- Validate checksum, byte order, ring arithmetic, DHCP options and DNS names on
  the host.
- Detect a configured Uthernet II slot without resetting the card.

Exit: clean builds and deterministic host tests.

## P1 - raw link

- Initialize socket 0 MACRAW with the `$06` memory layout.
- Receive and release frames, including W5100 ring wrap.
- Transmit Ethernet frames and wait for bounded completion.
- Add counters and a IIgs link diagnostic program.

Exit: ARP and ICMP echo work on real hardware and AppleWin.

Hardware result: P1 passed on Uthernet II in slot 4. `PGTLinkTest` received 194
frames and crossed the socket 0 RX boundary twice. `PGTPingTest` then resolved
the saved gateway with one ARP request and received a checksum-valid ICMP echo
reply (`TX=$0002`, `RX=$0002`).

## P2 - automatic configuration

- ARP cache and request/reply handling.
- IPv4 and UDP validation/transmit.
- DHCP discover, offer, request, ACK, renewal and fallback to saved static data.
- DNS A query, compressed response parsing and retry.

Exit: cold boot obtains address/router/DNS and resolves a test host without
manual configuration.

Hardware result: the bounded `PGTDHCPTest` completed Discover, Offer, Request
and ACK on Uthernet II in slot 4 with two transmitted frames. It acquired
`192.168.7.54/22`, router and DNS `192.168.4.1`, and a 14,400-second lease, then
applied the address, mask and router to the W5100. Lease persistence/renewal and
DNS lookup remain open.

Hardware result: `PGTDNSTest` completed DHCP, subnet-aware next-hop ARP and a
checked `example.com` A query on Uthernet II in slot 4. It resolved the DNS
next-hop MAC as `$84:D9:E0:78:91:92` and accepted A address `172.66.147.243`.
Final counters were `TX=$0004 RX=$0009`, confirming the ideal no-retry path.
The P2 wire protocols are hardware-validated; reusable state integration,
lease renewal/persistence and DNS caching remain open.

## P3 - streaming TCP

- Active open and close state machine.
- In-order receive fast path into a power-of-two ring.
- ACK/window generation and retransmission.
- Send path with a fixed retransmission window.
- U2BenchGS native test client.

Exit: sustained audio stream with no underruns under controlled LAN loss tests.

Hardware result: the native 16 KiB ring and W5100-to-ring bulk primitive passed
`PGTStreamTest` on Uthernet II in slot 4. The stock-speed IIgs accepted all 374
sender frames and 448,800 payload bytes while the simulated consumer removed
22,050 bytes/second. Drops and underruns were zero, high-water was `$3291`, and
the maximum foreground gap was two ticks.

Hardware result: `PGTDocStreamTest` joins the direct W5100 receive path to a
64 KiB source ring and the proven Tool 225 true-22-kHz mono DOC engine. Tool
225's monotonic refill counter authorizes each native ring-tail advance, so the
test detects actual audio-consumer underruns instead of estimating consumption
from the 60 Hz clock. The stock-speed IIgs accepted 601 frames and 656,292
payload bytes, consumed 589,824 bytes, crossed the W5100 RX boundary 167 times,
and passed with zero drops or underruns. Maximum foreground tick gap was four.

The assembly TCP foundation now includes active-open initialization, checked
SYN+ACK transition, exact-next-sequence payload/FIN commit, and transactional
ring staging so payload is published only after checksum validation. The host
oracle builds and validates TCP SYN/SYN+ACK frames, MSS options, checksums,
in-order receive, full-ring rejection and duplicate-ACK policy.

Current build: `PGTTCPTest` is the first DHCP-backed native active-open hardware
gate. It performs subnet-aware ARP, sends SYN with an MSS option, validates the
complete IPv4/TCP SYN+ACK identity and checksums, commits the native state
transition, and emits ACK plus FIN+ACK with a three-second RTO and three bounded
attempts. After this wire/state gate passes, established TCP payload will
replace the UDP selector in the already-proven direct DOC ring path.

Hardware result: `PGTTCPTest` passed on the first attempt. The IIgs acquired
`192.168.7.54/22`, resolved the listener's local MAC, accepted a checked
SYN+ACK with peer MSS 1460, sent ACK and FIN+ACK, and finished at `TX=$0006
RX=$0007 RXwrap=$0000`. The host accepted source port 49152 and confirmed the
IIgs FIN and completed close handshake. The native TCP wire/state gate is now
closed; direct established payload and ACK/window flow are next.

## P4 - Tool `$36`

- Install/uninstall lifecycle for tool number `$36`.
- Implement the U2BenchGS selector subset.
- Run existing Marinetti applications unchanged.
- Add remaining TCP, UDP and preference calls according to observed demand.

Exit: U2BenchGS and selected existing IP applications run without Marinetti's
protocol engine loaded.

## P5 - system integration

- Configuration CDev for DHCP/static address, Uthernet slot and buffer policy.
- Optional NDA for live state and performance counters.
- Passive opens, IP fragments, additional ICMP and extended compatibility.
