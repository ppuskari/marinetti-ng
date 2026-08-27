*=================================================
* Petar_gsTCP TCP state and parsed-segment workspace
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

PGTTClosed      equ   0
PGTTListen      equ   1
PGTTSynSent     equ   2
PGTTSynReceived equ   3
PGTTEstablished equ   4
PGTTFinWait1    equ   5
PGTTFinWait2    equ   6
PGTTCloseWait   equ   7
PGTTClosing     equ   8
PGTTLastAck     equ   9
PGTTTimeWait    equ   10

PGTCFActive     equ   $0001
PGTCFPeerFIN    equ   $0002
PGTCFReset      equ   $0004

* The frame parser converts wire-order sequence numbers to native 32-bit
* values before calling the state core.  This workspace deliberately starts
* after the ring primitive workspace.

PGTtcpConn      equ   $50             ; 24-bit connection pointer
PGTtcpSeq       equ   $54             ; parsed SEG.SEQ
PGTtcpAck       equ   $58             ; parsed SEG.ACK
PGTtcpLength    equ   $5C             ; accepted payload length
PGTtcpWindow    equ   $5E             ; parsed peer window
PGTtcpFlags     equ   $60             ; parsed TCP flags
PGTtcpISS       equ   $62             ; initial send sequence

