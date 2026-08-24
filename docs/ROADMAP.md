# Roadmap

## Phase 0: provenance and baselines

- Inventory and hash the user's Marinetti, TCPIP, and Uthernet II binaries.
- Extract IIgs file type, auxiliary type, resource forks, and version resources.
- Match each binary to upstream release notes and recovered source revisions.
- Obtain explicit Uthernet II source licensing or plan a clean, independent implementation around public specifications and suitably licensed references.
- Convert the archived CVS/RCS history to Git and verify its final tree against this import.

Exit criterion: every test artifact has a known hash and origin, and every committed source file has a known redistribution basis.

## Phase 1: reproducible build

- Document a known-good GS/OS, Merlin 16+/ORCA, and macro/tool setup.
- Identify all missing intermediate modules and decide whether to recover, replace, or cleanly reimplement each one.
- Produce deterministic build outputs where the tools permit it.
- Compare build outputs and behavior to the reference binaries.

Exit criterion: a clean checkout can produce an installable, behaviorally equivalent baseline from distributable inputs.

## Phase 2: correctness harness

- Add packet-trace fixtures for connection setup/teardown, retransmission, reassembly, fragmentation, ICMP, UDP, and DNS.
- Exercise small/large writes, delayed acknowledgements, zero-window behavior, out-of-order input, and checksum failures.
- Run the same cases against real Uthernet II hardware and emulation where practical.

Exit criterion: optimization candidates can be changed without relying only on interactive application testing.

## Phase 3: measurement

- Use [U2BenchGS](https://github.com/ppuskari/U2BenchGS) as the initial throughput and stress workload.
- Add cycle or time attribution around stack entry points and link-layer calls.
- Measure memory copies, checksum cost, bank crossings, queueing, W5100 register/data access, packet size, and interrupt/event overhead.
- Record CPU model/speed, accelerator/cache state, GS/OS configuration, card slot, link-layer version, peer system, MTU, and network topology with every result.

Exit criterion: a ranked profile identifies bottlenecks rather than assuming them.

## Phase 4: optimization

Likely investigation areas, subject to profiling:

- avoidable copies and handle locking in TCP send/receive paths;
- checksum loops and 16-bit/24-bit addressing choices;
- queue scans and TCP control-block lookup;
- packet sizing and batching across the link-layer boundary;
- redundant W5100 register transactions;
- bank-local hot data and direct-page placement;
- common-case TCP state-machine branches;
- retransmission timer and event scheduling overhead.

Each change should include correctness evidence and before/after benchmark data.

