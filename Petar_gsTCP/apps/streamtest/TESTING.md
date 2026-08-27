# PGTStreamTest hardware test

`PGTStreamTest` is the first P3 streaming-path diagnostic. It is intentionally
UDP rather than TCP so this test isolates the production W5100 bulk-copy loop,
16 KiB power-of-two receive ring and 22.05 kHz consumer from retransmission and
congestion-control work.

The IIgs prebuffers 4 KiB, then advances the consumer by alternating 367 and
368 bytes per 60 Hz tick, exactly 22,050 bytes/second. Accepted UDP payload goes
directly from the W5100 data port into the ring without a frame staging buffer.
An empty UDP datagram is the sender's end marker.

## Build and run

From `C:\AppleIIgsDev_02\marinetti-ng`:

```powershell
.\Petar_gsTCP\scripts\Build-StreamTest.ps1
```

This creates `build-local\PGTSTREAMTEST` and the bootable
`build-local\PGTStreamTest.po` volume.

1. Disconnect Marinetti and leave Ethernet connected.
2. Mount `PGTStreamTest.po`, launch `PGTSTREAMTEST`, and enter slot `4`.
3. When the IIgs says it is waiting for UDP port 6502, run this on a computer
   on the same wired LAN:

```powershell
py -3 .\Petar_gsTCP\tools\send_streamtest.py `
  --broadcast 192.168.7.255 --rate 22400 --seconds 20
```

The `/22` DHCP result confirms `192.168.7.255` as the broadcast address for the
validated network. Use the actual broadcast address if testing elsewhere.

The sender reports its frame and payload counts. The IIgs should receive the
same number of nonempty frames and end automatically. A successful summary has:

```text
drops=$0000 underruns=$0000 maxTickGap=$0001
PASS: 22.05kHz consumer had no drops or underruns.
```

`maxTickGap=$0002` can occur if a frame copy overlaps a tick boundary; larger
values warrant investigation. `high` must remain below `$4000`. Compare the
IIgs accepted/payload totals with the sender totals to detect link-level loss.

This test simulates consumption but does not yet program the Ensoniq DOC. After
it passes, the same ring contract will feed the DOC double-buffer service and
then the in-order TCP fast path.

## Confirmed hardware result

The paced 20-second test passed on a stock-speed IIgs with Uthernet II in slot
4. The sender delivered 374 frames and 448,800 bytes; the IIgs reported
`accepted=$0176 payload=$0006D920`, an exact match. The simulated audio consumer
removed `$0006A7FF` bytes, ring high-water was `$3291` of `$4000`, drops and
underruns were zero, `maxTickGap=$0002`, and the W5100 receive path crossed its
socket boundary `$0071` times. This closes the P3 link/ring hardware gate.
