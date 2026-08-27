# Marinetti NG

An unofficial research and optimization fork of the Marinetti TCP/IP stack for the Apple IIgs.

This repository begins with the latest recoverable `MOSP` working tree from the archived [Marinetti SourceForge CVS repository](https://sourceforge.net/projects/marinetti/). Its immediate purpose is to establish provenance, recover a reproducible baseline, measure real IIgs/Uthernet II performance, and then make evidence-driven changes to Marinetti's TCP/IP implementation and link-layer interface.

## Current state

- The recovered Marinetti source is licensed under the GNU Lesser General Public License 2.1 or later; see [LICENCE](LICENCE).
- The tree includes the 65816 source for the TCP, UDP, IP, ICMP, resolver, dispatch, preferences, and shared-library portions of the stack.
- This is not yet a complete build. Upstream's `PrepareDevEnv` and `HowToBuild` documents state that some modules were never released as source and historically had to be supplied as intermediate object files.
- The recovered changelog reaches Marinetti 3.0b5. The later TCPIP 3.0b11 binary must be reconciled against this source before optimization work can claim a matching baseline.
- Uthernet II link-layer source has not been found in the upstream tree. The currently published Uthernet II link layer is distributed as freeware binary version 2.0.5, while the public source download on the author's page is for a generic emulator link layer. It is therefore intentionally not represented here as open source yet.

See [docs/PROVENANCE.md](docs/PROVENANCE.md) for the source and licensing audit, [docs/REFERENCE_ARTIFACTS.md](docs/REFERENCE_ARTIFACTS.md) for the binary inventory and hashes, and [docs/ROADMAP.md](docs/ROADMAP.md) for the proposed work sequence.

## Petar_gsTCP experimental native stack

The first hardware-working Petar_gsTCP streamer milestone is documented in [Petar_gsTCP](Petar_gsTCP/README.md). The R3B/R3C lineage sustained Tool225 22 kHz mono playback on a stock 2.8 MHz Apple IIgs at about 175.9-176.0 kbit/s with provider backpressure essentially zero.

The critical hardware result is a **2920-byte advertised TCP payload window (two 1460-byte MSS)** for the W5100 socket-0 4 KiB MACRAW RX allocation. Advertising 4096 payload bytes caused repeated missing segments and future-sequence rejects.

This native Uthernet II/W5100 implementation is kept separate from the recovered upstream Marinetti provenance boundary.

## Supplying reference binaries

Place original archives or binaries in `incoming/`. That directory is ignored by Git so nothing is redistributed accidentally. For each file, please record where it came from and any known version information in a short text note beside it.

The first intake pass will:

1. preserve the original file unchanged;
2. calculate SHA-256 hashes;
3. identify archive/container formats and IIgs file metadata;
4. map binary versions to the recovered source;
5. determine whether redistribution is permitted before anything is committed.

## Optimization principles

- Establish byte-for-byte or behaviorally equivalent baselines before changing code.
- Benchmark on both real IIgs hardware and an emulator with controlled network conditions.
- Separate stack costs from Uthernet II/W5100 link-layer costs.
- Keep correctness tests for TCP state transitions, retransmission, fragmentation, checksums, and memory ownership alongside throughput measurements.
- Make small, reviewable changes with before/after measurements.

## Upstream preservation

The original recovered files are initially committed without line-ending normalization. Modernization, build-system work, and optimization changes should be made in separate commits so the provenance boundary remains clear.
