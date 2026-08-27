*=================================================
*
* Petar_gsTCP Internet checksum
*
* SPDX-License-Identifier: LGPL-2.1-or-later
*
* Input (current direct page):
*   PGTcsPtr = 24-bit pointer to bytes
*   PGTcsLen = byte count
*
* Output:
*   A = one's-complement checksum in network numeric order
*   carry clear
*
* Clobbers A, X and Y.  Entry and return are native 16-bit A/X/Y.
*
* The 65816 reads each pair little-endian, so XBA converts it to the network
* word before accumulation.  A separate carry word permits one fold after the
* hot loop instead of an end-around-carry branch for every input word.
*
*=================================================

PGTChecksum     ent
                rep   #$30
                stz   PGTcsSumLo
                stz   PGTcsSumHi
                ldy   #0
                lda   PGTcsLen
                lsr
                tax
                beq   PGTCSOdd

PGTCSPairLoop   lda   [PGTcsPtr],y
                xba
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   PGTCSPairNoCy
                inc   PGTcsSumHi
PGTCSPairNoCy   iny
                iny
                dex
                bne   PGTCSPairLoop

PGTCSOdd        lda   PGTcsLen
                and   #$0001
                beq   PGTCSFold
                sep   #$20
                lda   [PGTcsPtr],y
                rep   #$20
                and   #$00FF
                xba
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   PGTCSFold
                inc   PGTcsSumHi

PGTCSFold       lda   PGTcsSumHi
                beq   PGTCSDone
                stz   PGTcsSumHi
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   PGTCSFold
                inc   PGTcsSumHi
                bra   PGTCSFold

PGTCSDone       lda   PGTcsSumLo
                eor   #$FFFF
                clc
                rtl

*=================================================
*
* Incremental Internet checksum
*
* PGTChecksum remains the original contiguous API.
* Odd-byte phase survives across Add calls.
*
*=================================================

PGTChecksumInit ent
                rep   #$30
                stz   PGTcsSumLo
                stz   PGTcsSumHi
                stz   PGTcsOddByte
                clc
                rtl

* Hardware fix: Merlin must track accumulator width.
* Without MX %10, LDA #1 is emitted as A9 01 00.
* With M=8 the trailing 00 executes as BRK.

PGTChecksumAdd  ent
                rep   #$30
                mx    %00
                lda   PGTcsLen
                tax
                beq   PGTCSAddDone
                ldy   #0

PGTCSAddLoop
                sep   #$20
                mx    %10
                lda   PGTcsOddValid
                beq   PGTCSAddSave

* Pending byte is network high byte.
* Current byte completes the word.

                lda   [PGTcsPtr],y
                sta   PGTcsOddValid
                rep   #$20
                mx    %00
                lda   PGTcsOddByte
                xba
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   PGTCSAddNoCy
                inc   PGTcsSumHi

PGTCSAddNoCy
                stz   PGTcsOddByte
                bra   PGTCSAddNext

PGTCSAddSave
* Runtime M is still 8-bit on this branch.
* Tell Merlin explicitly before LDA immediate.
                mx    %10
                lda   [PGTcsPtr],y
                sta   PGTcsOddByte
                lda   #1
                sta   PGTcsOddValid
                rep   #$20
                mx    %00

PGTCSAddNext
                iny
                dex
                bne   PGTCSAddLoop

PGTCSAddDone
                rep   #$30
                mx    %00
                clc
                rtl

PGTChecksumFinal ent
                rep   #$30
                lda   PGTcsOddValid
                and   #$00FF
                beq   PGTCSIncFold

* Final odd byte is network high byte.
* Low byte is implicitly zero.

                lda   PGTcsOddByte
                and   #$00FF
                xba
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   PGTCSIncOddOK
                inc   PGTcsSumHi

PGTCSIncOddOK
                stz   PGTcsOddByte

PGTCSIncFold
                lda   PGTcsSumHi
                beq   PGTCSIncDone
                stz   PGTcsSumHi
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   PGTCSIncFold
                inc   PGTcsSumHi
                bra   PGTCSIncFold

PGTCSIncDone
                lda   PGTcsSumLo
                eor   #$FFFF
                clc
                rtl
