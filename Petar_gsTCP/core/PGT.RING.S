*=================================================
* Petar_gsTCP power-of-two receive ring primitives
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

* Return used bytes in A.

PGTRingUsed     ent
                rep   #$30
                lda   PGTringHead
                sec
                sbc   PGTringTail
                and   PGTringMask
                clc
                rtl

* Return free bytes in A.  One byte remains reserved.

PGTRingFree     ent
                rep   #$30
                lda   PGTringHead
                sec
                sbc   PGTringTail
                and   PGTringMask
                eor   PGTringMask
                clc
                rtl

* Copy and commit PGTu2Remain bytes requested by PGTringNeed from the current
* W5100 frame directly into the ring.  TCP uses PGTRingStageRX followed by
* checksum validation and PGTRingCommitRX so invalid data never becomes visible
* to the consumer.  Carry set leaves the producer head unchanged.

PGTRingCopyRX   ent
                jsl   PGTRingStageRX
                bcs   PGTRingCopyFail
                jsl   PGTRingCommitRX
                rtl

* Copy into the free producer spans without publishing a new head.  On success
* PGTringSaved is the staged length.  The caller must either commit it or leave
* PGTringHead unchanged and discard the staged bytes.

PGTRingStageRX  ent
                rep   #$30

                lda   PGTringNeed
                beq   PGTRingStageEmpty

* Never read beyond the current MACRAW frame.

                cmp   PGTu2Remain
                bcc   PGTRingFrameOK
                beq   PGTRingFrameOK
                sec
                rtl

PGTRingFrameOK  sta   PGTringSaved

* Verify actual ring capacity here.  Do not depend upon condition codes
* left behind by the frame-length comparison above.

                jsl   PGTRingFree
                cmp   PGTringSaved
                bcs   PGTRingSpaceOK

                stz   PGTringSaved
                stz   PGTringFirst
                sec
                rtl

* Determine the first contiguous destination span.

PGTRingSpaceOK  lda   PGTringMask
                inc
                sec
                sbc   PGTringHead
                sta   PGTringFirst

                cmp   PGTringSaved
                bcc   PGTRingFirstOK

                lda   PGTringSaved
                sta   PGTringFirst

PGTRingFirstOK  lda   PGTringBase
                clc
                adc   PGTringHead
                sta   PGTu2BulkPtr

                lda   PGTringBase+2
                adc   #0
                sta   PGTu2BulkPtr+2

                lda   PGTringFirst
                sta   PGTu2BulkLen

                jsl   PGTU2CopyRXSpan
                bcs   PGTRingStageCopyFail

* If the ring wrapped, copy the second span at ring base.

                lda   PGTringSaved
                sec
                sbc   PGTringFirst
                beq   PGTRingStageDone

                sta   PGTu2BulkLen

                lda   PGTringBase
                sta   PGTu2BulkPtr
                lda   PGTringBase+2
                sta   PGTu2BulkPtr+2

                jsl   PGTU2CopyRXSpan
                bcs   PGTRingStageCopyFail

PGTRingStageDone
                clc
                rtl

PGTRingStageCopyFail
* Bytes may have reached unpublished ring storage, but PGTringHead has
* not moved, so the consumer cannot observe them.

                stz   PGTringSaved
                stz   PGTringFirst
                sec
                rtl

PGTRingStageEmpty
                stz   PGTringSaved
                stz   PGTringFirst
                clc
                rtl
PGTRingCommitRX ent
                rep   #$30
                lda   PGTringHead
                clc
                adc   PGTringSaved
                and   PGTringMask
                sta   PGTringHead
                stz   PGTringSaved
                clc
                rtl
PGTRingCopyFail sec
                rtl
