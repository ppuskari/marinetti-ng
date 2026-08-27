*=================================================
* Petar_gsTCP wire-format constants
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

PGTEthDst       equ   0
PGTEthSrc       equ   6
PGTEthType      equ   12
PGTEthHdrLen    equ   14

PGTEthIPv4      equ   $0800
PGTEthARP       equ   $0806

PGTIPVerIHL     equ   0
PGTIPTOS        equ   1
PGTIPTotalLen   equ   2
PGTIPID         equ   4
PGTIPFrag       equ   6
PGTIPTTL        equ   8
PGTIPProto      equ   9
PGTIPChecksum   equ   10
PGTIPSource     equ   12
PGTIPDest       equ   16
PGTIPMinHdrLen  equ   20

PGTIPICMP       equ   1
PGTIPTCP        equ   6
PGTIPUDP        equ   17

PGTTCPSource    equ   0
PGTTCPDest      equ   2
PGTTCPSeq       equ   4
PGTTCPAck       equ   8
PGTTCPDataOff   equ   12
PGTTCPFlags     equ   13
PGTTCPWindow    equ   14
PGTTCPChecksum  equ   16
PGTTCPUrgent    equ   18
PGTTCPMinHdrLen equ   20

PGTTCPF_FIN     equ   $01
PGTTCPF_SYN     equ   $02
PGTTCPF_RST     equ   $04
PGTTCPF_PSH     equ   $08
PGTTCPF_ACK     equ   $10

PGTUDPSource    equ   0
PGTUDPDest      equ   2
PGTUDPLength    equ   4
PGTUDPChecksum  equ   6
PGTUDPHdrLen    equ   8

PGTDHCPClient   equ   68
PGTDHCPServer   equ   67
PGTDNSPort      equ   53

PGTEtherMTU     equ   1500
PGTTCPMSS       equ   1460
