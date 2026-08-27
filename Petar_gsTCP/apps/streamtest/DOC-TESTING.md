# PGTDocStreamTest hardware test

`PGTDocStreamTest` is the P3 DOC integration test for the proven Uthernet II bulk
receive path, a 64 KiB native source ring, and real Ensoniq DOC playback. It remains
UDP so an audio failure can be separated from the upcoming TCP state machine.

The diagnostic requires the proven Tool 225 P0.9G-M2-R12A tool set `$E1` to be
installed. Selector `$19` preloads two 16 KiB DOC halves and plays the same
unsigned 8-bit mono stream through the left and right outputs. The network
producer then reuses the source ring while Tool 225's exported block counter
authorizes each 16 KiB consumer advance. The first 32 KiB is copied into DOC
while the next nearly 32 KiB remains queued in the source ring, isolating the
blocking preload from sender timing.

## Build and run

From `C:\AppleIIgsDev_02\marinetti-ng`:

```powershell
.\Petar_gsTCP\scripts\Build-DOCStreamTest.ps1
```

This creates `build-local\PGTDOCSTREAM` and
`build-local\PGTDOCStreamTest.po`.

1. Verify Tool 225 P0.9G-M2-R12A is installed as tool set `$E1`.
2. Disconnect Marinetti, leave Ethernet and speakers connected, mount the
   image, launch `PGTDOCSTREAM`, and enter Uthernet II slot `4`.
3. After the UDP message appears, run:

```powershell
py -3 .\Petar_gsTCP\tools\send_docstreamtest.py `
  --broadcast 192.168.7.255 --rate 22400 --seconds 30 --tone-hz 440
```

Use the actual broadcast address on another network. The sender deliberately
avoids sample `$00`, which the DOC treats as a waveform terminator, and pauses
once after the exact 65,520-byte prebuffer while the IIgs starts playback.
The default 1,092-byte payload makes this exactly 60 datagrams. Only the first
32 KiB enters DOC immediately; the remaining 32,752 bytes cover the first two
refill periods while the sender completes its startup pause.
The default pause is 0.75 seconds; `--startup-pause` can tune it if a different
Tool 225 build has materially different preload timing.

Expected behavior is a steady 440 Hz tone followed by a summary with identical
sender/IIgs frame and byte counts, `drops=$0000`, `underruns=$0000`, and a
`high` value below `$FFFF`. `maxTickGap` of one or two ticks is acceptable.
Any audible repeat, click, pitch change, counter jump, drop, or underrun is a
failure worth photographing before pressing Return.

## Confirmed hardware result

The stock-speed IIgs passed the 30-second real-DOC gate on Uthernet II in slot
4. It accepted 601 datagrams and 656,292 payload bytes, consumed 589,824 bytes
through the DOC refill path, crossed the W5100 receive boundary 167 times, and
reported `drops=$0000`, `underruns=$0000`, `maxTickGap=$0004`. Ring high-water
reached `$FFF0`, exactly the intended 65,520-byte prebuffer watermark. The
sender end marker was received and the diagnostic printed PASS.
