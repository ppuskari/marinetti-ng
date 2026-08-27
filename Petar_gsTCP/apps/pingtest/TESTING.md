# PGTPingTest hardware test

`PGTPingTest` is the bounded P1 transmit, ARP and ICMP hardware diagnostic. It
reads the MAC address, IPv4 address and gateway already saved in the W5100,
sends at most three ARP requests, and sends one ICMP echo request after the
gateway MAC is resolved. The received IPv4 and ICMP checksums, addresses,
identifier and sequence number must all match before the program prints
`PASS`.

It temporarily closes W5100 socket 0 and selects the `$06` shared RX/TX memory
layout. Disconnect Marinetti before running it. Reconnect Marinetti or reboot
after the test.

## Build

From `C:\AppleIIgsDev_02\marinetti-ng`:

```powershell
.\Petar_gsTCP\scripts\Build-PingTest.ps1
```

This creates:

- `build-local\PGTPINGTEST` - GS/OS S16 application;
- `build-local\PGTPingTest.po` - 32 MiB ProDOS test volume.

## Run on the IIgs

1. Use the Marinetti control panel to connect once and save valid settings.
   Confirm that its IP address and gateway are correct.
2. Disconnect Marinetti. Do not run another network program during this test.
3. Mount `PGTPingTest.po`, or copy `PGTPINGTEST` to a ProDOS volume.
4. Launch `PGTPINGTEST` and enter the Uthernet II slot. For the card already
   tested in slot 4, enter `4`.
5. Capture the complete result screen.

A successful run ends with lines resembling:

```text
ARP reply received. Gateway MAC: $00:11:22:33:44:55
ICMP echo request sent; waiting...
PASS: valid ICMP echo reply received.
TX=$0002 RX=$.... RXwrap=$....
```

`TX=$0002` represents one ARP request and one ICMP request. `RX` can vary
because unrelated LAN broadcasts are released while the program waits.

## Interpreting failures

- `Saved IP or gateway is zero` means the W5100 has no usable saved static
  configuration. Reconnect and configure Marinetti, then retry.
- `W5100 transmit failed or timed out` means SEND did not complete. Check the
  Ethernet cable/link LEDs and capture the screen before rebooting.
- `ARP timed out` usually means the saved gateway is stale or unreachable on
  the current LAN.
- `ICMP echo reply timed out` means ARP and Ethernet transmit already passed,
  but the gateway did not return the matching echo. Some routers suppress ICMP;
  capture the result so a second LAN target can be added if needed.

Press Escape to stop either receive wait safely. Always send the displayed MAC,
IP, gateway, ARP result, echo result and final TX/RX counters with the report.

## Confirmed hardware result

P1 passed on an Uthernet II in slot 4 using MAC `$00:08:DC:11:11:11`, saved IP
`192.168.7.54`, and gateway `192.168.4.1`. The gateway resolved to
`$84:D9:E0:78:91:92`; the matching ICMP echo reply passed IPv4 and ICMP checksum
validation. Final counters were `TX=$0002 RX=$0002 RXwrap=$0000`. A zero wrap
count is expected for this two-frame test; RX wrapping was validated separately
by `PGTLinkTest`.
