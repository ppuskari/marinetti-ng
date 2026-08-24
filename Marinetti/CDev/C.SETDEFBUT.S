 LST OFF
*=================================================
*
* C.SETDEFBUT.S - Support routine for TCPIP Cdev
*
* Copyright (C) 1997-2003 Richard Bennett-Forrest
*
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
* This library is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public
* License along with this library; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*
*=================================================
*
* 2007.02.11 RJBF - Initial release as open source
*
*=================================================
 REL
 mx 0
 XC
 XC

*-------------------------------------------------
* SetDefaultBut
*
* Sets the default button - must all be extended controls
*
*        |--------------|
*        |   window     |
*        |-  pointer   -|  grafport
*        |              |
*        |--------------|
*        |     ctlID    |
*        |-            -|
*        |              |
*        |--------------|
*        |      rtl     |
*        |-      |------|
*        |       |
*        |-------|
*
* Changes the default button to ctlID. Also adds RETURN as the second
* key definition, so you can hit RETURN on it. Any other buttons with
* RETURN are zeroed out (just the RETURN). When a button is made the
* default, the old key record is saved in the reserved byte area of
* the button control record, and restored later when the button a
* different button is made the default. You can set bit31 of ctlID to
* bypass the tampering with the reserved bytes.
*
*-------------------------------------------------

 USE 4/RJBUTIL.MACS
 USE 4/MISC.MACS
 USE 4/CTL.MACS

 DUM 1

DP
HANDLE ADRL 0
PTR ADRL 0
DPLEN = *-DP

 DS 1 ;PHB
 ADR 0 ;RTL

CTRLID ADRL 0
WINDOWPTR ADRL 0

 DEND

SetDefaultBut ENT
 PHB
 PHK
 PLB
 TSC
 SEC
 SBC #DPLEN
 TCS
 PHD
 TCD

* Find first control

 LDY #$CA-4
 LDA [WINDOWPTR],Y
 STA HANDLE
 INY
 INY
 LDA [WINDOWPTR],Y
:TOPLOOP STA HANDLE+2
 ORA HANDLE
 BEQL :DONE

 LDA [HANDLE]
 STA PTR
 LDY #2
 LDA [HANDLE],Y
 STA PTR+2

* Is it a button?

 LDY #$14+2
 LDA [PTR],Y
 CMP #$8000
 BNEL :NEXTCTL
 DEY
 DEY
 LDA [PTR],Y
 BNEL :NEXTCTL

* Is it the one I want?

 LDY #$38
 LDA CTRLID
 CMP [PTR],Y
 BNE :UNDEFIT
 INY
 INY
 LDA CTRLID+2
 AND #$7FFF
 CMP [PTR],Y
 BNE :UNDEFIT

* OK, make it so...

 BIT CTRLID+2 ;save it?
 BMI :STICKIT

 LDY #$2E
 LDA [PTR],Y
 BNE :STICKIT ;someone using it?
 LDA #$CC ;mark me in
 STA [PTR],Y
 LDY #$28
 LDA [PTR],Y
 LDY #$2F
 STA [PTR],Y
 LDY #$28+2
 LDA [PTR],Y
 LDY #$2F+2
 STA [PTR],Y
 LDA #$28+2+2
 LDA [PTR],Y
 LDY #$2F+2+2
 STA [PTR],Y

:STICKIT LDY #$28 ;KEY EQUIV
 LDA [PTR],Y
 AND #$00FF ;preserve the first
 ORA #$0D00 ;trash the second... make it RETURN
 STA [PTR],Y
 INY
 INY
 LDA [PTR],Y ;get keyModifiers
 AND #$00FF
 STA [PTR],Y
 INY
 INY
 LDA [PTR],Y ;care bits
 AND #$00FF
 STA [PTR],Y

 PEA #%1

 BRA :DODEF

:UNDEFIT

 LDY #$2E
 LDA [PTR],Y
 AND #$FF
 CMP #$CC
 BNE :TRASHIT
 LDY #$2F
 LDA [PTR],Y
 LDY #$28
 STA [PTR],Y
 LDY #$2F+2
 LDA [PTR],Y
 LDY #$28+2
 STA [PTR],Y
 LDY #$2F+2+2
 LDA [PTR],Y
 LDY #$28+2+2
 STA [PTR],Y
 LDY #$2E
 LDA #0
 STA [PTR],Y
 INY
 STA [PTR],Y
 INY
 INY
 STA [PTR],Y
 INY
 INY
 STA [PTR],Y
 BRA :UNDEFKEY

:TRASHIT SEP $30
 LDY #$29
 LDA [PTR],Y
 CMP #$0D
 BNE :UNDEFKEYOK
 LDA #0
 STA [PTR],Y
 INY
 INY
 STA [PTR],Y
 INY
 INY
 STA [PTR],Y
:UNDEFKEYOK REP $30

:UNDEFKEY PEA #%0

:DODEF LDY #$10
 LDA [PTR],Y
 AND #$FFFE
 ORA 1,S
 CMP [PTR],Y
 BEQ :MODOK
 PHA
 PZL HANDLE
 _HideControl
 PLA
 LDY #$10
 STA [PTR],Y
 PZL HANDLE
 _DrawOneCtl

:MODOK PLA

:NEXTCTL LDA [PTR]
 TAX
 LDY #2
 LDA [PTR],Y
 STX HANDLE
 JMP :TOPLOOP
:DONE
*
 PLD
 TSC
 CLC
 ADC #DPLEN
 TCS
 PLA
 STA 7,S
 PLA
 STA 7,S
 PLA
 PLA
 PLB
 RTL

 SAV C.SETDEFBUT.L

 END
