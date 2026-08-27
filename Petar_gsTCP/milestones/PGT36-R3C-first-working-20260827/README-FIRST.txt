PGT36 R3C HARDEN-R1K1 KEYFIX PLAYER
2026-08-27

PURPOSE
-------
R3C preserves the hardware-stable R3B native audio path and restores the
HARDEN-R1K1 safe producer-boundary keyboard controls.

PROVEN TRANSPORT LEFT UNCHANGED
-------------------------------
- Petar_gsTCP native Uthernet II MACRAW
- advertised TCP payload window $0B68 = 2920 bytes = two 1460-byte MSS
- private 16 KiB socket RX ring
- full TCP checksum and exact RCV.NXT validation
- exact 16 KiB HARDEN producer contract
- individual application drains <=8 KiB
- MVN socket-ring -> playback-ring copy
- ACK/window behavior unchanged from R3B/R3A/R2B

R3B HARDWARE RESULT
-------------------
R3B played continuously for a long run at about 175.9-176.0 kbit/s with
provider blockpct essentially zero and maxblock about 78 ms, but ESC/C/R/D
were unresponsive.

ROOT CAUSE
----------
The actual HARDEN latch routines were present, but R3B accidentally retained
an older FULL-PADDLE branch that skipped CheckNetworkControlKey whenever
PumpRescueActive was set.  Always-Paddle therefore bypassed the safe control
boundary almost continuously.

R3C FIX
-------
R3C removes only that bypass and restores the HARDEN-R1K1 control boundary:

    jsr ReadRingCounters
    jsr UpdateProducerLead
    jsr CheckNetworkControlKey

This happens only after the completed producer batch, outside the exact TCP
read hot path.  No per-packet keyboard/event polling was added.

EXPECTED CONTROLS
-----------------
ESC  stop/exit
C    current native endpoint reconnect path in this first native player line
R    reset/rebuffer
D    diagnostics snapshot

NOTE: full editable endpoint selection is still a later control-plane step;
R3C deliberately does not change the proven native transport to add it.

VALIDATED OMF
-------------
PGT36R3C
57930 bytes
SHA256 b51aba537ce45e374ff99fefe03f6e1f9d8e2c6b9b6d6a3e072d010f663c4948

Two clean Merlin32 v1.2 beta 2 builds were byte-identical.
