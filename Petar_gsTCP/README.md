# Petar_gsTCP — first hardware-working streamer milestone

**Milestone:** PGT36 R3C HARDEN-R1K1 native player  
**Date:** 2026-08-27  
**Target:** Apple IIgs ROM 3, stock 2.8 MHz, Uthernet II / W5100 MACRAW socket 0  
**Application:** Tool225 22 kHz mono / 512 KiB ring streamer

This directory records the first Petar_gsTCP integration that sustained real Tool225 audio playback on stock 2.8 MHz Apple IIgs hardware at the provider's natural 22 kHz mono payload rate.

## Hardware result

The R3B data path ran for a long hardware test at approximately **175.9-176.0 kbit/s** with provider `blockpct` essentially zero and `maxblock` about 78 ms. R3C preserves that data path and restores the HARDEN-R1K1 safe-boundary keyboard controls (`ESC`, `C`, `R`, `D`).

## Critical transport invariant

The W5100 socket-0 MACRAW RX allocation is 4 KiB, but the TCP advertised window describes TCP payload bytes while the hardware ring stores complete MACRAW Ethernet records. Advertising 4096 payload bytes caused repeated missing segments and future-sequence rejects.

The hardware-good window is:

```text
2920 bytes = 2 x 1460-byte MSS
```

Two maximum-size Ethernet/TCP MACRAW records consume about 3032 bytes including the W5100 two-byte record prefixes, which fits in the 4096-byte socket RX allocation. With this window, future-sequence rejects collapsed and provider backpressure fell to essentially zero.

Do not change this window back to 4096 without reworking the W5100 RX allocation/service model.

## Working architecture

```text
W5100 MACRAW
  -> Petar_gsTCP full TCP validation/checksum/ACK
  -> private 16 KiB socket RX ring
  -> HARDEN-R1K1 exact 16 KiB producer contract
  -> individual drains <= 8 KiB
  -> 65816 MVN copy into 512 KiB playback ring
  -> Tool225
```

TCP receive state is independent of Tool225's 16 KiB producer quantum. The application drains already-accepted socket data; it does not define the TCP receive window.

## R3C controls

R3C restores the HARDEN-R1K1 safe producer-boundary control check. Keyboard/event work remains outside the exact TCP read hot path.

- `ESC` — stop/exit
- `C` — current native endpoint reconnect path
- `R` — reset/rebuffer
- `D` — diagnostics snapshot

Full editable endpoint selection remains a later control-plane step.

## Validated binary

```text
PGT36R3C
57930 bytes
SHA256 b51aba537ce45e374ff99fefe03f6e1f9d8e2c6b9b6d6a3e072d010f663c4948
```

Two clean Merlin32 v1.2 beta 2 builds were byte-identical.

Deployment/source package:

```text
PGT36-R3C-HARDEN-KEYFIX-DEPLOY-20260827.zip
SHA256 ea6bc0878aeac4b88cf5fad370de2d76c6668930e9ce0784b5b0a4c0b3fea770
```

## Proven lineage

This milestone combines the separately hardware-validated Petar_gsTCP TCP receive work with the HARDEN-R1K1/M3R36A streamer application contract. Earlier N-series integration experiments are not part of this working baseline.
