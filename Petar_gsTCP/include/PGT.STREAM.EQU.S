*=================================================
* Petar_gsTCP native streaming and ring ABI
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

* Direct-page ring workspace.  Production connection records keep persistent
* values; the dispatcher loads one selected ring here before entering the hot
* copy routine.

PGTringBase     equ   $40             ; 24-bit ring base (4-byte slot)
PGTringMask     equ   $44             ; size minus one
PGTringHead     equ   $46             ; producer position
PGTringTail     equ   $48             ; consumer position snapshot
PGTringNeed     equ   $4A             ; incoming payload bytes
PGTringFirst    equ   $4C             ; first contiguous span
PGTringSaved    equ   $4E             ; saved requested length

* Persistent ring descriptor offsets.  Rings are power-of-two sized and leave
* one byte empty so head == tail means empty without another flag.

PGTRBase        equ   0               ; long pointer
PGTRMask        equ   4
PGTRHead        equ   6
PGTRTail        equ   8
PGTRHighWater   equ   10
PGTRDrops       equ   12
PGTRSize        equ   16

* Native connection record.  Hot fields occupy the first cache-friendly block;
* compatibility handles index this fixed table rather than owning protocol
* state or allocating packet objects.

PGTCState       equ   0
PGTCFlags       equ   2
PGTCLocalPort   equ   4
PGTCRemotePort  equ   6
PGTCRemoteIP    equ   8
PGTCSendNext    equ   12
PGTCSendUnacked equ   16
PGTCRecvNext    equ   20
PGTCRecvWindow  equ   24
PGTCRingIndex   equ   26
PGTCRTODeadline equ   28
PGTCRetries     equ   32
PGTCAckPending  equ   34
PGTCSendWindow  equ   36             ; peer-advertised usable TX window
PGTCSize        equ   64

PGTMaxConnections equ 8
PGTMaxUDP       equ   8
PGTStreamRing16K equ  $3FFF
PGTStreamRing32K equ  $7FFF
PGTDefaultMSS   equ   1460
PGTNativePollFrames equ 2
PGTNativePollBytes equ  3072
