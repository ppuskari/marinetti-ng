# PGTDHCPTest hardware test

`PGTDHCPTest` is the first P2 automatic-configuration diagnostic. It uses only
the MAC address already stored in the W5100 and does not depend on its saved IP
address, subnet mask, gateway or DNS configuration.

The program sends at most three DHCP Discover packets, accepts a checked Offer,
sends at most three Requests, and accepts only a matching ACK. It checks the
Ethernet/IPv4/UDP/BOOTP structure, IPv4 checksum, any nonzero UDP checksum,
transaction ID, client MAC, DHCP cookie and bounded options. A valid ACK must
provide an address, subnet mask and router. DNS and lease-time options are
displayed when present.

After a pass, the address, mask and router are applied to the W5100 common
registers. This test does not yet save or renew the lease, and Marinetti may
replace those registers when it reconnects.

## Build

From `C:\AppleIIgsDev_02\marinetti-ng`:

```powershell
.\Petar_gsTCP\scripts\Build-DHCPTest.ps1
```

This creates:

- `build-local\PGTDHCPTEST` - GS/OS S16 application;
- `build-local\PGTDHCPTest.po` - 32 MiB ProDOS test volume.

## Run on the IIgs

1. Disconnect Marinetti. Do not run another networking application at the same
   time.
2. Keep the Ethernet cable connected to the same LAN used for `PGTPingTest`.
3. Mount `PGTDHCPTest.po`, or copy `PGTDHCPTEST` to a ProDOS volume.
4. Launch `PGTDHCPTEST` and enter `4` for the validated Uthernet II slot.
5. Capture the complete screen before pressing Return.

A successful first-attempt exchange ends with output resembling:

```text
DHCP DISCOVER sent; waiting for OFFER...
OFFER address: $C0.A8.07.36
DHCP server: $C0.A8.04.01
DHCP REQUEST sent; waiting for ACK...
PASS: DHCP ACK validated and applied.
Address: $C0.A8.07.36
Subnet mask: $FF.FF.FC.00
Router: $C0.A8.04.01
DNS 1: $...
DNS 2: $...
Lease seconds (hex): $...
TX=$0002 RX=$.... RXwrap=$....
```

Extra received frames are normal because MACRAW sees unrelated LAN broadcasts.
More than two transmitted frames indicates a bounded retry.

## Interpreting failures

- `MAC is zero or multicast` means the W5100 does not contain a usable client
  MAC address.
- `No valid OFFER` means no reply passed all identity and packet checks. Confirm
  the LAN has a DHCP server and that DHCP broadcasts are not isolated.
- `No valid ACK` means the Offer passed, but the requested lease was not
  acknowledged before the retry limit.
- `DHCP server returned NAK` means the server explicitly rejected the request.
- `ACK omitted required address, mask, or router` identifies an incomplete
  configuration that the stack intentionally refuses to apply.

Press Escape to abort either bounded receive wait safely. Reconnect Marinetti or
reboot after capturing the result.

If an older test image fills the screen with a repeating two-digit value after
slot entry, replace it with the current image. That was an output-only loop bug
in the transaction-ID display and occurred before any DHCP packet was sent.

## Confirmed hardware result

The corrected diagnostic passed on Uthernet II in slot 4. It received an Offer
and ACK for `192.168.7.54` with subnet mask `255.255.252.0`, router and primary
DNS `192.168.4.1`, no secondary DNS, and lease `$00003840` (14,400 seconds, or
four hours). Final counters were `TX=$0002 RX=$000F RXwrap=$0000`; the additional
received frames were unrelated MACRAW LAN traffic released during the exchange.
