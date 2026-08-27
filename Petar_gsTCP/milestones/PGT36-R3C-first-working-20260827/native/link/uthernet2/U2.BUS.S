*=================================================
*
* Clean Uthernet II W5100 indirect-bus primitives
*
* SPDX-License-Identifier: LGPL-2.1-or-later
*
* These routines intentionally do not reset the W5100.  Configuration and
* ownership policy belong to the link startup module.  All routines require
* native mode with 16-bit A/X/Y and use the current Petar_gsTCP direct page.
*
*=================================================

* A = slot number.  Returns carry set for an invalid slot, otherwise PGTu2IO
* points to $E0/C0n4 and carry is clear.

PGTU2SelectSlot ent
                rep   #$30
                and   #$00FF
                cmp   #U2SlotMin
                bcc   PGTU2BadSlot
                cmp   #U2SlotMax+1
                bcs   PGTU2BadSlot
                asl
                asl
                asl
                asl
                clc
                adc   #U2SlotIO
                sta   PGTu2IO
                lda   #$00E0
                sta   PGTu2IO+2
                lda   PGTu2IO
                clc
                adc   #U2IDMData
                sta   PGTu2Data
                lda   PGTu2IO+2
                sta   PGTu2Data+2
                clc
                rtl
PGTU2BadSlot    sec
                rtl

* Enable the W5100 indirect interface and its auto-increment data register.

PGTU2EnableAI   ent
                rep   #$30
                ldy   #U2IDMMode
                sep   #$20
                lda   [PGTu2IO],y
                ora   #W5MRIndirect+W5MRAutoInc
                sta   [PGTu2IO],y
                rep   #$20
                clc
                rtl

* X = W5100 internal address.

PGTU2SetAddress ent
                rep   #$30
                stx   PGTu2Reg
                sep   #$20
                ldy   #U2IDMAddrHi
                lda   PGTu2Reg+1
                sta   [PGTu2IO],y
                iny
                lda   PGTu2Reg
                sta   [PGTu2IO],y
                rep   #$20
                clc
                rtl

* X = address, A low byte = value.

PGTU2Write8     ent
                rep   #$30
                sta   PGTu2Value
                jsl   PGTU2SetAddress
                sep   #$20
                ldy   #U2IDMData
                lda   PGTu2Value
                sta   [PGTu2IO],y
                rep   #$20
                clc
                rtl

* X = address.  Returns zero-extended value in A.

PGTU2Read8      ent
                rep   #$30
                jsl   PGTU2SetAddress
                sep   #$20
                ldy   #U2IDMData
                lda   [PGTu2IO],y
                rep   #$20
                and   #$00FF
                clc
                rtl

* X = address, A = big-endian 16-bit register value.

PGTU2Write16    ent
                rep   #$30
                sta   PGTu2Value
                jsl   PGTU2SetAddress
                sep   #$20
                ldy   #U2IDMData
                lda   PGTu2Value+1
                sta   [PGTu2IO],y
                lda   PGTu2Value
                sta   [PGTu2IO],y
                rep   #$20
                clc
                rtl

* X = big-endian 16-bit register address.  Values such as RX received size can
* change between byte reads, so repeat until two complete reads agree.

PGTU2Read16     ent
                rep   #$30
                stx   PGTu2Reg
PGTU2Read16Try  ldx   PGTu2Reg
                jsl   PGTU2SetAddress
                sep   #$20
                ldy   #U2IDMData
                lda   [PGTu2IO],y
                xba
                lda   [PGTu2IO],y
                rep   #$20
                sta   PGTu2Value
                ldx   PGTu2Reg
                jsl   PGTU2SetAddress
                sep   #$20
                ldy   #U2IDMData
                lda   [PGTu2IO],y
                xba
                lda   [PGTu2IO],y
                rep   #$20
                cmp   PGTu2Value
                bne   PGTU2Read16Try
                clc
                rtl

* Probe the W5100 using the default Retry Time-value Register ($07D0).  This is
* the public Uthernet II detection method.  Returns carry clear when found.

PGTU2Probe      ent
                rep   #$30
                jsl   PGTU2EnableAI
                ldx   #W5RTR
                jsl   PGTU2SetAddress
                sep   #$20
                ldy   #U2IDMData
                lda   [PGTu2IO],y
                cmp   #$07
                bne   PGTU2ProbeFail
                lda   [PGTu2IO],y
                cmp   #$D0
                bne   PGTU2ProbeFail
                rep   #$20
                clc
                rtl
PGTU2ProbeFail  rep   #$20
                sec
                rtl
