 LST OFF
 REL
*=================================================
* Shownodes
*
* Author Richard Bennett
*
* Utility for showing available Appletalk Nodes
* on an Appletalk network.
*
* Use Open-Apple-6 from the Merlin editor to 
* Assemble and Link into an executable.
*=================================================

 XC
 XC
 mx 0

_WriteChar MAC
 LDX #$180C
 JSL $E10000
 <<<
_WriteLine MAC
 LDX #$1A0C
 JSL $E10000
 <<<

SHOWNODES PEA #$0C
 _WriteChar
 PEA ^:HEADSTR
 PEA :HEADSTR
 _WriteLine
 JSR SHOWEM
 PEA ^:TAILSTR
 PEA :TAILSTR
 _WriteLine
 SEP $20
 LDX #60*4
]L1 LDA >$E0C000
 BMI :GOTKEY
 LDA >$E0C019
 BPL *-4
 LDA >$E0C019
 BMI *-4
 DEX
 BNE ]L1
 REP $20
 BRA SHOWNODES
 mx %10
:GOTKEY STA >$E0C010
 REP $20
 AND #$7F
 CMP #$1B
 BEQ :QUIT
 CMP #'Q'
 BEQ :QUIT
 CMP #'q'
 BEQ :QUIT
 BRA SHOWNODES
:QUIT JSL $E100A8
 DA $29
 ADRL :QUITP

:QUITP ADRL 0
 DA 0

:HEADSTR STR '[Node    Port Registered name]'
:TAILSTR STR '[ESC to quit, any key to update]'

SHOWEM phk
 plb
 ldx #Params7
 ldy #^Params7
 jsl $e11014 ; LookupName
 lda matched
 and #$00ff
 bne No_quit
 brl rtsx
No_quit sta count
 ldx #0
 stx savx
loop ldx savx
 lda Buffer,x
 pha
 jsl OutHex
 pla
 xba
 jsl OutHex
 inc savx
 inc savx
 ldx savx
 lda Buffer,x
 pha
 jsl OutHex
 pla
 xba
 jsl OutHex
 inc savx
 inc savx
 inc savx ; skip Enumerator
 pea #'-'
 _writechar
 pea #' '
 _writechar
 ldy #3
 sty savy
loop0 ldx savx
 lda Buffer,x ; str length
 and #$00ff
 sta count2
 inc savx
loop1 ldx savx
 lda Buffer,x
 and #$00ff
 pha
 _writechar
 inc savx
 dec count2
 bne loop1
 ldx savy
 lda table-1,x
 and #$00ff
 pha
 _writechar
 dec savy
 bne loop0
 pea #$000a
 _writechar
 dec count
 beq rtsx
 brl loop
rtsx rts

table DFB 13,'@',':'
count ds 2
count2 ds 2
savx ds 2
savy ds 2

Params7 DFB 0
 DFB $10
 ds 2
 ADRL 0
 ADRL Entity3
 DFB 2,8
 ds 2
 DA 586
 ADRL buffer
 DFB 255
matched ds 1

Entity3 STR '='
 STR '='
 STR '*'

OutHex pha
 lsr a
 lsr a
 lsr a
 lsr a
 jsl OutHex1
 pla
 jsl OutHex1
 pea #$0020
 _writechar
 rtl

OutHex1 and #$000f
 clc
 adc #$0030
 cmp #$003a
 bcc OutHex2
 clc
 adc #7
OutHex2 pha
 _writechar
 rtl

Buffer ds 592

 SAV SHOWNODES.L

 END
