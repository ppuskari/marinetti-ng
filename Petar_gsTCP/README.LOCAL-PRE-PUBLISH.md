# Petar_gsTCP

`Petar_gsTCP` is a new, CPU-thin IPv4 networking stack for the Apple IIgs. Its
first hardware target is the Uthernet II card and its WIZnet W5100 controller.

The production implementation is 65C816 assembly. Host-side Python code is a
test oracle for packet formats and arithmetic; it is not shipped on the IIgs.

## First release target

- foreground polling with a bounded amount of work per call;
- Uthernet II socket 0 in MACRAW mode;
- Ethernet II, ARP, IPv4, ICMP echo, UDP and one high-throughput TCP client;
- DHCP configuration of address, mask, router and DNS servers;
- DNS A-record lookup;
- fixed-size control blocks and receive rings with no packet-time allocation;
- a compatibility shim for the Marinetti Tool Set `$36` calls used by
  U2BenchGS and the current streaming applications.

The new stack does not load beneath Marinetti. It can either be built as a
standalone API or installed as the implementation of Tool Set `$36`. The
compatibility layer and the native API both call the same core.

## Layout

- `include/` - direct-page, wire-format and public ABI equates.
- `core/` - protocol-independent hot primitives and protocol engines.
- `link/uthernet2/` - clean Uthernet II/W5100 implementation.
- `compat/tool36/` - Marinetti-compatible selectors and adapters.
- `tests/` - host-side behavioral tests and later packet fixtures.
- `docs/` - architecture, memory model and implementation milestones.

The stock-2.8-MHz streaming budgets and native-versus-Tool-`$36` copy policy are
defined in [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md).

## Local validation

Run:

```powershell
py -3 -m unittest discover Petar_gsTCP/tests -v
Petar_gsTCP/scripts/Build-Primitives.ps1
Petar_gsTCP/scripts/Build-LinkTest.ps1
Petar_gsTCP/scripts/Build-PingTest.ps1
Petar_gsTCP/scripts/Build-DHCPTest.ps1
Petar_gsTCP/scripts/Build-DNSTest.ps1
Petar_gsTCP/scripts/Build-TCPTest.ps1
Petar_gsTCP/scripts/Build-StreamTest.ps1
Petar_gsTCP/scripts/Build-DOCStreamTest.ps1
```

The build script looks for the official Merlin 32 package in
`C:\AppleIIgsDev_02\_tools\Merlin32_v1.2` and writes generated files only to
the ignored `build-local/` directory.

The first real-hardware procedure is in
[`apps/linktest/TESTING.md`](apps/linktest/TESTING.md). `PGTLinkTest` is a
receive-only GS/OS diagnostic; it does not replace Tool Set `$36`.

After the receive test passes, use
[`apps/pingtest/TESTING.md`](apps/pingtest/TESTING.md). `PGTPingTest` sends a
bounded ARP request to the saved gateway, then one checksum-validated ICMP echo
request. It is also a standalone diagnostic and does not install Tool `$36`.

The P2 automatic-configuration test is documented in
[`apps/dhcptest/TESTING.md`](apps/dhcptest/TESTING.md). `PGTDHCPTest` performs a
raw DHCP Discover/Offer/Request/ACK exchange and applies the validated lease to
the W5100 common address registers. It does not yet persist or renew the lease.

[`apps/dnstest/TESTING.md`](apps/dnstest/TESTING.md) describes the end-to-end
DHCP plus DNS diagnostic. It uses the DNS server returned in the ACK, resolves
the correct local/router next hop, and safely scans compressed DNS answers for
an IPv4 A record.

[`apps/streamtest/TESTING.md`](apps/streamtest/TESTING.md) exercises the
production bulk-copy loop and 16 KiB ring against a paced 22.05 kHz consumer.

[`apps/streamtest/DOC-TESTING.md`](apps/streamtest/DOC-TESTING.md) advances the
same path to a 64 KiB source ring and real double-buffered Ensoniq DOC output.
It uses the hardware-proven Tool 225 P0.9G-M2-R12A engine as the temporary DOC
backend so network/TCP work does not duplicate its delicate interrupt logic.

[`apps/tcptest/TESTING.md`](apps/tcptest/TESTING.md) is the first native TCP
hardware gate. It combines DHCP and subnet-aware ARP with a checksum- and
sequence-validated active open to a small host listener, then sends ACK and
FIN+ACK from the native connection record.

## License

Unless a file says otherwise, this directory is licensed under the repository's
GNU Lesser General Public License 2.1-or-later. The Uthernet II code is a clean
implementation based on public Uthernet II and W5100 programming information;
it does not incorporate the separately distributed freeware link-layer binary.
