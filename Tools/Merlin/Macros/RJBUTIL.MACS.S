*
* RJBUTIL.MACS - Copyright (c) 1989-1991 by Oz Data
*                Standard Merlin util macs copyright (c) Roger Wagner Publ.
*

PHWL MAC
 PHW ]1
 PHL ]2
 <<<
PHLW MAC
 PHL ]1
 PHW ]2
 <<<
PLxW MAC
 DO ]0/1
 PLW ]1
 DO ]0/2
 PLW ]2
 DO ]0/3
 PLW ]3
 DO ]0/4
 PLW ]4
 FIN
 FIN
 FIN
 FIN
 <<<
PxW MAC
 DO ]0/1
 PHW ]1
 DO ]0/2
 PHW ]2
 DO ]0/3
 PHW ]3
 DO ]0/4
 PHW ]4
 FIN
 FIN
 FIN
 FIN
 <<<
PxL MAC
 DO ]0/1
 PHL ]1
 DO ]0/2
 PHL ]2
 DO ]0/3
 PHL ]3
 DO ]0/4
 PHL ]4
 FIN
 FIN
 FIN
 FIN
 <<<
P2SL MAC
 PHA
P1SL MAC
 PHA
PHL MAC
 IF #=]1
 PEA ^]1
 ELSE
 PHW ]1+2
 FIN
 PHW ]1
 <<<
P2SW MAC
 PHA
P1SW MAC
 PHA
PHW MAC
 if #=]1
 PEA ]1
 else
 if MX/2
 LDA ]1+1
 PHA
 fin
 LDA ]1
 PHA
 fin
 <<<
PushSpace MAC
PHS MAC
 DO ]0
 do 6/]1
 LUP ]1
 PHA
 --^
 else
 TSC
 SEC
 SBC #]1
 TCS
 fin
 ELSE
 PHA
 FIN
 <<<
PLXY MAC
 PLX
 PLY
 do ]0
 STX ]1
 STY ]1+2
 fin
 <<<
PLYA MAC
 PLY
 PLA
 do ]0
 STY ]1
 STA ]1+2
 fin
 <<<
PLXA MAC
 PLX
 PLA
 do ]0
 STX ]1
 STA ]1+2
 fin
 <<<
PLAX MAC
 PLA
 PLX
 do ]0
 STA ]1
 STX ]1+2
 fin
 <<<
PHAX MAC
 DO ]0
 LDA ]1
 LDX ]1+2
 FIN
 PHX
 PHA
 <<<
PHXY MAC
 DO ]0
 LDX ]1
 LDY ]1+2
 FIN
 PHY
 PHX
 <<<
PHXA MAC
 do ]0
 LDX ]1
 LDA ]1+2
 fin
 PHA
 PHX
 <<<
PHYA MAC
 do ]0
 LDY ]1
 LDA ]1+2
 fin
 PHA
 PHY
 <<<
PLS MAC
 do ]0
 LUP ]1
 PLA
 else
 PLA
 fin
 --^
 <<<
PLL MAC
 do ]0
 do ]0-1
 if X,]2
 PLX
 STX ]1
 PLX
 STX ]1+2
 else
 PLY
 STY ]1
 PLY
 STY ]1+2
 fin
 else
 PLA
 STA ]1
 PLA
 STA ]1+2
 fin
 else
 PLA
 PLA
 fin
 <<<
PLW MAC
 PLA
 STA ]1
 <<<
TEST MAC
 if mx&%10 ;If A is now short
 LDA ]1
 ORA ]1+1
 else
 LDA ]1
 ORA ]1+2
 fin
 <<<
STXA MAC
 STX ]1
 STA ]1+2
 <<<
STYA MAC
 STY ]1
 STA ]1+2
 <<<
STXY MAC
 STX ]1
 STY ]1+2
 <<<
STAX MAC
 STA ]1
 STX ]1+2
 <<<
LXA MAC
LDXA MAC
 if #,]1
 LDX #]1
 LDA #^]1
 else
 if [,]1
 LDA ]1
 TAX
 INY
 INY
 LDA ]1
 else
 LDX ]1
 LDA ]1+2
 fin
 fin
 <<<
LYA MAC
 if #,]1
 LDY #]1
 LDA #^]1
 else
 LDY ]1
 LDA ]1+2
 fin
 <<<
LDXY MAC
LXY MAC
 if #,]1
 LDX #]1
 LDY #^]1
 else
 LDX ]1
 LDY ]1+2
 fin
 <<<
LYX MAC
 if #,]1
 LDY #]1
 LDX #^]1
 else
 LDY ]1
 LDX ]1+2
 fin
 <<<
LAX MAC
LDAX MAC
 if #,]1
 LDA #]1
 LDX #^]1
 else
 LDA ]1
 LDX ]1+2
 fin
 <<<
CPXA MAC
 if #,]1
 CMP #^]1
 BNE LESS02
 CPX #]1
 else
 CMP ]1+2
 BNE LESS02
 CPX ]1
 fin
LESS02 <<<
CPXY MAC
 if #,]1
 CPY #^]1
 BNE LESS02
 CPX #]1
 else
 CPY ]1+2
 BNE LESS02
 CPX ]1
 fin
LESS02 <<<
DEXA MAC
 DEX
 CPX #$FFFF
 BNE OK
 DEC
OK <<<
INXA MAC
 INX
 BNE OK
 INC
OK <<<
SBXA MAC ;SBXA location
 PHA ;SBXA #num
 TXA
 SEC
 SBC ]1
 TAX
 PLA
 SBC #0
 <<<
SBXAL MAC ;SBXA location
 PHA ;SBXA #num
 TXA
 SEC
 SBC ]1
 TAX
 PLA
 if #,]1
 SBC #>]1
 else
 SBC ]1+2
 fin
 <<<
ADXA MAC ;ADXA location
 PHA ;ADXA #num
 TXA
 CLC
 ADC ]1
 TAX
 PLA
 ADC #0
 <<<
ADXAL MAC
 PHA
 TXA
 CLC
 ADC ]1
 TAX
 PLA
 if #,]1
 ADC #>]1
 else
 ADC ]1+2
 fin
 <<<
ADDL MAC
 LDA ]1
 CLC
 ADC ]2
 STA ]1
 LDA ]1+2
 if #,]2
 ADC >]2
 else
 ADC ]2+2
 fin
 STA ]1+2
 <<<
PHADR MAC
 PHW ]1+1
 PHB
 LDA ]1
 STA 1,S
 <<<
NEWHANDLELONG MAC
 PHS 2
 PEA ^]1
 PEA ]1
 PEI ID
 PEA $18 ;No bank wrap, no special
 PEA 0
 PEA 0
 LDX #$902
 JSL $E10000
 <<<
NEWHANDLEWORD MAC
 PHS 2
 PEA 0
 PHW ]1
 PEI ID
 PEA $18
 PEA 0
 PEA 0
 LDX #$902
 JSL $E10000
 <<<
PLDEREF MAC
 PLXA ]1
 DEREF ]1
 <<<
PLHNDPTR MAC
 PLXA ]1
 DEREF ]1
 STXA ]2
 <<<
REREF MAC
 LDY #2
 STA []1],Y
 TXA
 STA []1]
 <<<
DEREF MAC
 LDA []1]
 TAX
 LDY #2
 LDA []1],Y
 do ]0/2
 STXA ]2
 fin
 <<<
LOCK MAC
 LDY #4
 LDA []1],Y
 do ]0
 else
 STA ]2
 fin
 ORA #$8000
 STA []1],Y
 <<<
LOCKSAVE MAC
 LDY #4
 LDA []1],Y
 STA ]2
 ORA #$8000
 STA []1],Y
 <<<
UNLOCK MAC
 LDY #4
 do ]0
 LDA []1],Y
 AND #$7FFF
 STA []1],Y
 else
 LDA ]2
 STA []1],Y
 fin
 <<<
WAITVBL MAC
]Z = 0
 if mx/2-1
 SEP $20
]Z = 1
 fin
 LDAL $E0C019
 BMI *-4
 LDAL $E0C019
 BPL *-4
 do ]Z
 REP $20
 fin
 <<<
SYSERR MAC
 BCC OK
 PHA
 if ',]1
 PEA ^STR
 PEA STR
 else
 PEA ^]1
 PEA ]1
 fin
 PHK
 PEA 0
 CLC
 JML $E1001C
 if ',]1
STR STR ]1
 fin
OK <<<
KEY MAC
 SEP $20
 LDAL $E0C000
 BPL *-4
 STAL $E0C010
 REP $20
 <<<
MVB MAC
]Z = 0
 if mx/2-1
 SEP $20
]Z = 1
 fin
 LDA ]2
 STA ]1
 do ]Z
 REP $20
 fin
 <<<
MVW MAC
 LDA ]2
 STA ]1
 if mx/2
 LDA ]2+1
 STA ]1+1
 fin
 <<<
MVL MAC
 MVW ]1;]2
 MVW ]1+2;]2+2
 <<<
PROC MAC
 PHB
 PHK
 PLB
 TSC
 PHD
 TCD
 <<<
PROCFRAME = 5
ENDPROC MAC
 PLD
 PLX
 PLY
]TVAL1 = {]1/2}
]TVAL2 = {]1*2}/2
 LUP ]TVAL1
 PLA
 --^
 do 1!{2*]TVAL1/]TVAL2}
 PLB
 fin
 PHY
 PHX
 PLB
 RTL
 <<<
CENTRERECT MAC ;Used to be called RECT
 do ]0/2
]X = 640
]Y = 200
 fin
 do ]0/3
 if 3,]3
]X = 320
]Y = 200
 else
]X = 640
]Y = 200
 fin
 fin
 do ]0/4
]X = ]4
]Y = ]3
 fin
]X1 = ]2/2
]Y1 = ]1/2
 DA ]Y/2-]Y1,]X/2-]X1,]Y/2+]Y1,]X/2+]X1
 <<<
RECTAT MAC ;RECTAT y;x;height;width
 do ]0/4 ;RECTAT y;x
 DA ]1,]2,]1+]3,]2+]4
 else
 DA ]1,]2,0,0
 fin
 <<<
CHECK MAC
 LDX *-6
 do ]0
 if ',]1
 COP $7F
 DFB 1
 STR ]1
 else
 COP ]1
 fin
 else
 COP 0
 fin
 <<<
COPERR MAC
 BCC OK
 LDX *-8
 do ]0
 COPMSG ]1
 else
 COPMSG 'Toolerr- code in A, tool in X.'
 fin
OK <<<
COPMSG MAC
 COP $7F
 DFB 1
 STR ]1
 <<<
COPADR MAC
COPDISPADR MAC
 COP $7F
 DFB 2
 ADRL ]1
 <<<
LP MAC
 LST ON
* Paused...
 PAU
 <<<
PZL MAC
 PEI ]1+2
 PEI ]1
 <<<
EYE MAC
 do DEBUG
 ASC ]1
 fin
 <<<
BCSL MAC
 BCC OK
 BRL ]1
OK <<<
BCCL MAC
 BCS OK
 BRL ]1
OK <<<
BNEL MAC
 BEQ OK
 BRL ]1
OK <<<
BEQL MAC
 BNE OK
 BRL ]1
OK <<<
BMIL MAC
 BPL OK
 BRL ]1
OK <<<
BPLL MAC
 BMI OK
 BRL ]1
OK <<<
BVSL MAC
 BVC OK
 BRL ]1
OK <<<
BVCL MAC
 BVS OK
 BRL ]1
OK <<<
GETDP MAC ;Gets DP space starting at 0
 PHD
 TSC
 SEC
 SBC ]1
 TCS
 INC
 TCD
 <<<
PUTDP MAC
 TSC
 CLC
 ADC ]1
 TCS
 PLD
 <<<
TEMPDPON MAC
 TSC
 PHD
 INC
 TCD
 <<<
TEMPDPOFF MAC
 PLD
 <<<
DECR MAC
 LDA ]1
 BNE OK
 if mx/2
 DEC ]1+1
 else
 DEC ]1+2
 fin
OK DEC ]1
 <<<
INCREMENT MAC
 LDA ]1
 INC
 STA ]1
 BNE OK
 LDA ]1+2
 INC
 STA ]1+2
OK <<<
INCR MAC
 if >,]1
 LST ON
* No absolute long INC in 65816. Use INCREMENT macro.
 LST OFF
 fin
 INC ]1
 BNE OK
 if mx/2
 INC ]1+1
 else
 INC ]1+2
 fin
OK <<<
EMBED MAC
IMBED MAC
 BRL OK
 DA $7771
 if ',]1
 STR ]1
 else
 STR ']1'
 fin
OK <<<
ITEMID MAC
 do ]0 ; ITEMID INIT       - Defined initial ID of 1
 if I,]1 ; ITEMID            - Defines next incremental ID
]RJBIZ = 0 ; ITEMID SAME       - Defines last ID again
 fin
 if S,]1
 else
]RJBIZ = ]RJBIZ+1
 fin
 else
]RJBIZ = ]RJBIZ+1
 fin
 DA ]RJBIZ
 <<<
CTLID MAC
 do ]0-1 ; CTLID group;INIT     - Defined initial ID of 1
 if I,]2 ; CTLID group          - Defines next incremental ID
]RJBIZ = ]1*$10000 ; CTLID group;SAME     - Defines last ID again
 fin
 if S,]2
 else
]RJBIZ = ]RJBIZ+1
 fin
 else
]RJBIZ = ]RJBIZ+1
 fin
 ADRL ]RJBIZ
 <<<
TRK MAC
 do #,]1
 LDA ]1
 else
 LDA #]1
 fin
 STAL $380
 <<<
UserTool MAC
 LDX #]1 ; load tool call #
 JSL $E10008 ; go to dispatcher
 <<<
 DUM 0
RECTY1 DA 0
RECTX1 DA 0
RECTY2 DA 0
RECTX2 DA 0
 DEND
 DUM 0
ERECWHAT DA 0
ERECMESSAGE ADRL 0
ERECWHEN ADRL 0
ERECWHERE
ERECWHEREY DA 0
ERECWHEREX DA 0
ERECMODIFIERS DA 0
ERECLEN
 DEND
EMDA = %0000010000000000
EMSW = %0000001000000000
EMA = %0000000100000000
EMU = %0000000001000000
EMAK = %0000000000100000
EMKD = %0000000000001000
EMMU = %0000000000000100
EMMD = %0000000000000010
 DUM 0
EVENTNULL DS 1
EVENTMOUSEDOWN DS 1
EVENTMOUSEUP DS 1
EVENTKEYDOWN DS 1
 DS 1
EVENTAUTOKEY DS 1
EVENTUPDATE DS 1
 DS 1
EVENTACTIVATE DS 1
EVENTSWITCH DS 1
EVENTDESKACC DS 1
 DEND
*
* RJBDEBUG.MACS
*
SHIFTHOOK MAC ;A=0000-Off,FFFF-On
 do DEBUG
 PEA ^BEAT
 PEA BEAT
 EOR #0
 BNE ON
 LDX #$1303 ;DelHeartBeat
 HEX AF
ON LDX #$1203 ;SetHeartBeat
 JSL $E10000
 BRA DONE
BEAT ADRL 0
 DA 30
 DA $A55A
 mx %11
 LDA #30
 STAL BEAT+4
 LDAL $E0C025
 LSR
 BCS Y
 LDA #$C0
 ORAL $E0C029
 STAL $E0C029
 RTL
Y LDAL $E0C029
 AND #$7F
 STAL $E0C029
 RTL
 mx 0
DONE fin
 <<<
SAY MAC
 do DEBUG
 PEA ^STRING
 PEA STRING
 LDX #$1A0C ;WriteLine
 JSL $E10000
 BRA DONE
STRING STR ]1
DONE fin
 <<<
SAYWORD MAC
 do DEBUG
 PHA
 do ]0
 LUP ]0
 LDA ]1
 fin
 PHA
 PHA
 PHA
 LDX #$2A0B ;Hexit
 JSL $E10000
 PLXA
 XBA
 PHA
 XBA
 PHA
 TXA
 XBA
 PHA
 XBA
 PHA
 LDX #$180C ;WriteChar
 JSL $E10000
 LDX #$180C
 JSL $E10000
 LDX #$180C
 JSL $E10000
 LDX #$180C
 JSL $E10000
 do ]0
 --^
 fin
 PLA
 fin
 <<<
* Equates
ToBusyStrip EQU $E10180 ;X = error, Y = bytes to strip
ToStrip EQU $E10184 ;X = error, Y = bytes to strip
INCBUSY EQU $E10064
DECBUSY EQU $E10068
********************************

Push4 MAC
 PushLong #0
 PushLong #0
 <<<

PushLong MAC
 IF #=]1
 PushWord #^]1
 ELSE
 PushWord ]1+2
 FIN
 PushWord ]1
 <<<

PushWord MAC
 IF #=]1
 PEA ]1
 ELSE
 IF MX/2
 LDA ]1+1
 PHA
 FIN
 LDA ]1
 PHA
 FIN
 <<<

PullLong MAC
 DO ]0
 PullWord ]1
 PullWord ]1+2
 ELSE
 PullWord
 PullWord
 FIN
 <<<

PullWord MAC
 PLA
 DO ]0
 STA ]1
 FIN
 IF MX/2
 PLA
 DO ]0
 STA ]1+1
 FIN
 FIN
 <<<

MoveLong MAC
 MoveWord ]1;]2
 MoveWord ]1+2;]2+2
 <<<

MoveWord MAC
 LDA ]1
 STA ]2
 IF MX/2
 LDA ]1+1
 STA ]2+1
 FIN
 <<<

MoveBlock MAC ;1st_byte;last_byte;dest
 DO ]2/]1
 DO ]3/]1
 LDX #]2
 LDY #]3+]2-]1
 LDA #]2-]1
 MVP ]1,]3
 ELSE
 LDX #]1
 LDY #]3
 LDA #]2-]1
 MVN ]1,]3
 FIN
 ELSE
 ERR 1 ;Last adrs < first adrs
 FIN
 <<<

CmpLong MAC
 LDA ]1
 CMP ]2
 IF #=]1
 LDA ^]1
 ELSE
 LDA ]1+2
 FIN
 IF #=]2
 SBC ^]2
 ELSE
 SBC ]2+2
 FIN
 <<<

LONGACC MAC ;Assumes native mode
 IF MX&2 ;If A is now short
 REP %00100000
 FIN
 <<<

LONGXY MAC ;Assumes native mode
 IF MX&1 ;If X is now short
 REP %00010000
 FIN
 <<<

LONGAX MAC ;Assumes native mode
 IF MX ;If not now in full 16
 REP %00110000
 FIN
 <<<

SHORTACC MAC ;Assumes native mode
 IF MX&2 ;If A is now short,
 ELSE ; ignore
 SEP %00100000
 FIN
 <<<

SHORTXY MAC ;Assumes native mode
 IF MX&1 ;If X is now short,
 ELSE  ; ignore
 SEP %00010000
 FIN
 <<<

SHORTAX MAC ;Assumes native mode
 IF MX!%11 ;If not now in full 8
 SEP %00110000
 FIN
 <<<

LONGI MAC ; Duplicates APW function
 LST OFF
 DO ]1 ; If arg = 1 = "on" = make long

 IF MX-3/-1 ; If M is short and X is long
; Leave alone
 FIN ; End of this test

 IF MX/3 ; If M is short and X is short
 MX %10 ; Make X long, leave M short
 FIN ; End of this test

 IF MX!3/3 ; If M is long and X is long
 FIN ; Leave alone

 IF MX-2/-1 ; If M is long and X is short
 MX %00 ; Make X long, leave M long
 FIN ; End of this test

 ELSE ; If arg = 0 = "off" = make short

 IF MX/3 ; If M is short and X is short
 ; Leave alone
 FIN ; End of this test

 IF MX-3/-1 ; If M is short and X is long
 MX %11 ; Make X short, leave M short
 FIN ; End of this test

 IF MX-2/-1 ; If M is long and X is short
 ; Leave alone
 FIN ; End of this test


 IF MX!3/3 ; If M is long and X is long
 MX %01 ; Make X short, leave M long
 FIN ; Leave alone

 FIN ; End of macro tests

 LST RTN
 <<<

LONGA MAC ; Duplicates APW function
 LST OFF
 DO ]1 ; If arg = 1 = "on" = make long

 IF MX-3/-1 ; If M is short and X is long
 MX %00 ; Make M long, leave X long
 FIN ; End of this test

 IF MX/3 ; If M is short and X is short
 MX %01 ; Make M long, leave X short
 FIN ; End of this test

 IF MX!3/3 ; If M is long and X is long
 FIN ; Leave alone

 IF MX-2/-1 ; If M is long and X is short
 ; Leave alone
 FIN ; End of this test

 ELSE ; If arg = 0 = "off" = make short

 IF MX/3 ; If M is short and X is short
 ; Leave alone
 FIN ; End of this test

 IF MX-3/-1 ; If M is short and X is long
 ; Leave alone
 FIN ; End of this test

 IF MX-2/-1 ; If M is long and X is short
 MX %11 ; Make M short, leave X short
 FIN ; End of this test


 IF MX!3/3 ; If M is long and X is long
 MX %10 ; Make M short, leave X long
 FIN ; Leave alone

 FIN ; End of macro tests

 LST RTN
 <<<

M65816 MAC
 DO ]1
 XC
 XC ; Full 65816 mode for assembler
 MX %00
 ELSE
 MX %11 ; 8 bit mode for assembler
 FIN
 <<<

Expmac MAC ; Replace APW GEN function
 DO ]1
 EXP ONLY ; Expand macros
 ELSE
 EXP OFF
 FIN
 <<<

Tool MAC
 LDX #]1 ; load tool call #
 JSL $E10000 ; go to dispatcher
 <<<
