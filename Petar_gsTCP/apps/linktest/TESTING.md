# PGTLinkTest hardware test

`PGTLinkTest` is a receive-only GS/OS diagnostic. It does not install a tool,
alter Marinetti files, send packets, or reset the W5100. It temporarily closes
W5100 socket 0 and changes the W5100 RX/TX allocation to the `$06` shared
layout, so Marinetti must be disconnected before it runs.

## Build

From `C:\AppleIIgsDev_02\marinetti-ng`:

```powershell
.\Petar_gsTCP\scripts\Build-LinkTest.ps1
```

This creates:

- `build-local\PGTLINKTEST` - GS/OS S16 application;
- `build-local\PGTLinkTest.po` - 32 MiB ProDOS test volume.

## Run on the IIgs

1. In the Marinetti TCP/IP control panel, disconnect the active connection.
2. Mount `PGTLinkTest.po` as a secondary hard drive in an emulator, or copy
   `PGTLINKTEST` to a ProDOS volume for the real IIgs.
3. From the GS/OS Finder, open the `PGTLINK` volume and launch `PGTLINKTEST`.
4. Enter the Uthernet II slot, or press Return for slot 3.
5. Confirm that the program reports `W5100 found`, a MAC address, and
   `Receiving`.
6. Generate test broadcasts from another computer on the same LAN.
7. Press Escape on the IIgs to stop and record the final counters.

Do not run Marinetti networking applications at the same time. Reconnect
Marinetti after `PGTLinkTest` exits, or reboot before resuming normal use.

## Generate controlled traffic

Find the LAN's broadcast address, such as `192.168.1.255`, and run this from a
computer on the same wired network:

```powershell
py -3 .\Petar_gsTCP\tools\send_linktest_frames.py `
  --broadcast 192.168.1.255 --count 20 --payload-size 1200
```

The script sends bounded UDP broadcasts to port 6502. With 1200-byte payloads,
only a few frames are needed to cross the W5100 socket 0 4 KiB RX boundary.

## Expected display

Typical frame lines resemble:

```text
frame=$0001 len=$04DA type=$0800
frame=$0002 len=$003C type=$0806
```

- `$0800` is IPv4.
- `$0806` is ARP.
- `RXwrap` must become nonzero during the 20-frame large-payload test.
- `frames` should match or nearly match the sender count. Extra ARP/broadcast
  traffic is normal.
- There must be no `receive/release command failed` message.

Please capture the displayed MAC/IP/gateway lines, the first several frame
lines, and the final summary. Those results determine whether P0.2 should move
directly to transmit/ARP or first adjust W5100 timing and wrap handling.
