# 22.05 kHz streaming performance contract

## Budget

A stock 2.8 MHz Apple IIgs has approximately 127 CPU cycles available per
22,050 Hz audio sample. The network stack must leave enough time for application
logic, DOC buffer service, GS/OS and foreground responsiveness.

The initial release uses these measurable targets:

| Item | Design target |
|---|---:|
| Sustained application payload | 22,050 bytes/second |
| Ethernet payload per full TCP segment | 1,460 bytes |
| Full segments per second | about 15.1 |
| W5100-to-IIgs bulk-copy loop | 19 base instruction cycles/byte |
| Packet-level fast-path allowance | under 2,000 cycles/segment |
| Established receive-path CPU | under 25% average |
| Streaming ring | 16 KiB default, 32 KiB optional |
| 16 KiB buffering at 22.05 kHz | about 743 ms |
| Prebuffer watermark | 4 KiB, about 186 ms |
| Foreground native poll budget | 2 frames or 3,072 bytes |

The 19-cycle inner loop is the base 65C816 instruction cost of direct-page-long
W5100 data read, direct-page-long-indexed ring write, index increments and the
taken loop branch. Slot-I/O wait states add wall time and must be measured on
the real IIgs. Boundary handling and pointer commits occur once per span rather
than once per byte.

## Copy policy

The native streaming receive path copies each accepted TCP payload exactly once
from the W5100 to its fixed power-of-two ring. Native applications may borrow
one or two contiguous read spans and then advance the tail, avoiding another
stack copy. A Marinetti-compatible `TCPIPReadTCP` adapter copies from that same
ring into the legacy caller buffer because the public ABI requires it.

No packet-time allocation, handle locking, linked-list insertion, full-frame
staging buffer or protocol callback is permitted on the established in-order
path.

## Polling and audio safety

The stack runs in bounded foreground polls. A streaming client prebuffers at
least 4 KiB before starting playback and calls the native poll entry at least
once per 60 Hz tick. Delayed ACK policy initially acknowledges every second
full segment or at a two-tick deadline, whichever comes first.

An established TCP segment that is fragmented, has IP options, is out of order,
fails validation or cannot fit the ring leaves the fast path. The first release
drops future data and emits a duplicate ACK instead of allocating an out-of-
order queue.

## Compatibility boundary

Tool Set `$36` selectors are adapters, not a second protocol engine. Legacy
connection handles map to fixed native connection records. Poll, status, DNS,
open/close and read calls translate parameters and results while all packets,
timers and rings remain owned by the native core.

Performance acceptance requires both the native streaming benchmark and an
existing Marinetti application through the adapter. Compatibility overhead is
reported separately from core receive cost.

## Real DOC gate

The first hardware audio gate uses a 64 KiB source ring around Tool 225's proven
32 KiB DOC preload at frequency `$0058` (approximately 21,972.65 samples per
second). The source ring is released in 16 KiB increments only when Tool 225's
exported refill counter advances. The test sender uses 22,400 bytes/second,
leaving roughly 427 bytes/second of steady-state producer margin while still
remaining close enough to expose foreground stalls and W5100 loss.

That gate passed on the stock 2.8 MHz IIgs with 656,292 received bytes, 589,824
DOC-consumed bytes, 167 W5100 RX wraps, zero drops, zero underruns and a maximum
four-tick foreground gap. `$FFF0` high-water confirms that the 65,520-byte
prebuffer filled exactly without violating the ring's reserved byte.
