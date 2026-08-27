# Architecture

## Design goal

Optimize for sustained network streaming on a 2.8 MHz Apple IIgs while keeping
desktop applications responsive. Throughput is important, but the primary
metric is IIgs CPU time per delivered payload byte.

The core rules are:

1. No Memory Manager calls while processing a frame.
2. No linked lists in the receive or timer hot paths.
3. No complete-frame copy into an intermediate IIgs buffer.
4. No interrupt-time protocol processing in the first implementation.
5. All polling work is bounded by a frame and byte budget.
6. Common established, in-order TCP traffic gets a dedicated fast path.

## Layers

```text
Tool Set $36 shim      Native Petar_gsTCP API
          \             /
           connection API
                  |
        TCP / UDP / DHCP / DNS
                  |
          IPv4 / ICMP / ARP
                  |
       Ethernet frame dispatcher
                  |
       Uthernet II W5100 MACRAW
```

The native API may later expose receive-ring spans to new applications. The
Tool `$36` adapter retains Marinetti's copy-oriented calls and structures for
existing applications.

## W5100 ownership and transfer path

Socket 0 is opened in MACRAW mode. RX and TX memory use the established `$06`
layout: 4 KiB for socket 0, 2 KiB for socket 1, and 1 KiB each for sockets 2
and 3. This is compatible with the public Uthernet II shared-access convention
and gives socket 0 room for at least two Ethernet frames.

Diagnostic code may read individual bytes through callable routines. Production
payload transfer instead points a direct-page long pointer at `$E0/C0n7` and
uses a 19-base-instruction-cycle byte loop. Slot-I/O wait states are measured by
the hardware benchmark. W5100 and IIgs ring boundaries are split into spans
outside that loop.

The receive fast path performs these operations:

1. Read the two-byte W5100 MACRAW record length.
2. Inspect Ethernet, IPv4 and TCP headers directly through the auto-increment
   data register.
3. Select a connection from a small fixed hash/table.
4. For an exact-next-sequence segment, copy payload directly to the connection
   receive ring while accumulating its checksum.
5. Commit the ring head only after validation; otherwise roll back and ACK or
   discard as required.
6. Advance `S0_RX_RD` and issue `RECV` once for the whole record.

This removes the allocate-handle, W5100-to-packet, packet-to-TCP, and
TCP-to-application queue chain that would otherwise dominate CPU use.

`PGTRingStageRX` and `PGTRingCommitRX` implement the publication boundary:
staged W5100 bytes occupy reserved producer spans but remain invisible to the
consumer until the IPv4/TCP validation path commits them. UDP diagnostics may
use the combined `PGTRingCopyRX` entry.

The first real-DOC integration build uses the already hardware-proven Tool 225
P0.9G-M2-R12A selector `$19` as a temporary audio backend. A 64 KiB native
source ring covers its blocking 32 KiB initial DOC preload and retains almost
32 KiB for upcoming refills. Its monotonic 256-byte block counter is joined to the ring;
Tool 225 does not own the network or TCP state. This isolates DOC interrupt
safety from the new protocol engine and provides a known-good audio reference
before any later consolidation.

## Memory model

All working storage is allocated at startup and locked:

| Object | Initial policy |
|---|---|
| Direct-page state | one 256-byte page |
| Connection records | 8 fixed records |
| Streaming RX ring | configurable 16 or 32 KiB |
| Other TCP RX rings | 2 or 4 KiB each |
| TX retransmit data | fixed per-connection window |
| ARP cache | 8 fixed entries |
| UDP endpoints | 8 fixed records |
| DHCP packet | one reusable 576-byte buffer |
| DNS packet | one reusable 512-byte buffer |

Ring sizes are powers of two so used/free arithmetic is a mask operation. A
single byte remains unused to distinguish full from empty.

## Polling and timers

`PGTPoll` receives both a maximum-frame count and maximum-byte count. It checks
the W5100, advances coarse protocol timers, emits pending ACKs, and returns as
soon as either budget is consumed. Toolbox `TCPIPPoll` uses conservative
defaults; streaming applications can request a larger native budget.

Timers use the IIgs tick counter and unsigned deadline comparisons. TCP keeps
one retransmission deadline per connection rather than a timer queue.

## Protocol scope

The first TCP implementation supports active opens, orderly and abortive
close, retransmission, advertised MSS, window updates, duplicate ACK handling,
and a conservative congestion window. It initially accepts only IPv4 packets
without IP options and does not reassemble IP fragments. Future packets are
dropped and duplicate-ACKed rather than stored out of order in the first
streaming build.

TCP behavior is based on [RFC 9293](https://www.rfc-editor.org/rfc/rfc9293),
with retransmission timing from
[RFC 6298](https://www.rfc-editor.org/rfc/rfc6298) and congestion behavior from
[RFC 5681](https://www.rfc-editor.org/rfc/rfc5681).

The DHCP client follows [RFC 2131](https://www.rfc-editor.org/rfc/rfc2131) and
parses the minimum useful options: message type, requested/server address,
lease, subnet mask, router, DNS servers, renewal/rebinding time, hostname and
client identifier. DNS begins with UDP A-record queries, compressed-name
parsing, transaction validation, bounded retries and a small fixed cache as
specified by [RFC 1035](https://www.rfc-editor.org/rfc/rfc1035).

## Tool Set `$36` compatibility

The compatibility module installs the public Marinetti selector numbers and
preserves parameter/result layouts. Phase one implements the calls exercised
by U2BenchGS:

- startup, shutdown and status;
- connect status and address conversion/validation;
- asynchronous name-to-address lookup and cancellation;
- poll, login and logout;
- open, read, status, close and abort TCP.

Selectors outside the implemented subset return a documented unsupported-call
error until their adapters are added. The existing Marinetti tool stub and
programmer guide are ABI references; protocol behavior remains in the new core.

## Performance instrumentation

Counters are always available but cheap: frames, bytes, polls, RX ring full,
checksum failure, retransmit, duplicate/out-of-order segment, dropped frame and
maximum frames per poll. Cycle-timed instrumentation is a separate build flag
so release builds do not pay for it.
