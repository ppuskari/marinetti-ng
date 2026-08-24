 LST OFF
 REL
 mx 0

*=================================================
*
* PPPX.CONFIG.S - Configuration window for scripted PPP driver
*
* Copyright (C) 1997-2003 Richard Bennett
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
* 2002.02.11 RJB - Initial release as open source
* 2002.02.22 AJR - Removed redundant DESK.MACS
* 2003.07.23 AJR - Bumped copyright year
*
* NOTE REGARDING VERSION NUMBERS
*
* In order to change the version number, you need to change:
*
* 1. The rVersion resource in PPPX.RES before building PPPX.
* 2. The PPPVERSH and PPPVERSL equates in this file.
*
*=================================================

 USE 4/RJBUTIL.MACS
 USE 4/MEM.MACS
 USE 4/LOCATOR.MACS
 USE 4/EVENT.MACS
 USE 4/WINDOW.MACS
 USE 4/CTL.MACS
 USE 4/TEXTEDIT.MACS
 USE 4/QD.MACS
 USE ../../Equates/BUILD.EQU
 USE ../../Equates/I.EQU
 USE ../../Equates/TCPIP.EQU

 EXT PPPXVERSION

~VersionString MAC
 PHW ]1
 PxL ]2;]3
_VersionString MAC
 LDX #$3903
 JSL $E10000
 <<<

 DUM LLSPACE ;My direct space on Marinetti's direct page
PPPWINDPTR ADRL 0
PPPTMPHANDLE ADRL 0
 DEND

*-------------------------------------------------
* PPPCONFIGURE(connectHandle,disconnectHandle);
*-------------------------------------------------

PPPctlSAVE = $2009
PPPctlCANX = $2008
PPPctlTE = $200A
PPPctlPop = $200B

* UPTO: Change so handles passed are only modified at end. All work handles
*       must be new.

PPPCONFIGURE ENT
 DBGMSG PPPCONFIGURE
 PHB
 PHK
 PLB

* Get connect data handle and save it as MASTCONNSCRIPT

 LDA 9+2,S
 STA MASTCONNSCRIPT+2
 LDA 9,S
 STA MASTCONNSCRIPT

* Get disconnect data handle and save it in MASTDISCSCRIPT

 LDA 5+2,S
 STA MASTDISCSCRIPT+2
 LDA 5,S
 STA MASTDISCSCRIPT

* Start TextEdit if not already started

 JSR STARTTE

* Present window

 ~GetPort

 PEA 0
 PHL PPPXVERSION
 PHL #VERSIONASC
 _VersionString
 LDA VERSIONASC
 AND #$FF
 STA VERSIONASCL

 ~NewWindow2 #0;#0;#0;#0;#0;#PPPXWINDOW;#$800E
 LDA 1,S
 STA PPPWINDPTR
 LDA 1+2,S
 STA PPPWINDPTR+2
 _SetPort

:NEWPOP PHS
 PZL PPPWINDPTR
 PHL #PPPctlPop
 _GetCtlValueByID
 PLA
 DEC
 STA POPVAL
 JSR :SETSCRIPT

 JSR :SETCLEAN

:TOP JSR :SETSAVEBUT
:LOOP ~DoModalWindow #TASKRECORD;#0;#0;#0;#%0100_0000_0000_1000
 PLXA
 CPX #PPPctlCANX
 BEQ :DONE
 CPX #PPPctlSAVE
 BEQ :SAVE
 CPX #PPPctlTE
 BEQ :TOP
 CPX #PPPctlPop
 BEQ :POP
 CPX VERSIONCTL+2
 BEQ :EGG
 BRA :LOOP

:EGG ~AlertWindow #%100_00_1;#0;#EGGALERT
 PLA
 BRA :LOOP

:SAVE JSR :SAVEIT
 BRA :TOP

:POP PHS
 PZL PPPWINDPTR
 PHL #PPPctlPop
 _GetCtlValueByID
 PLA
 DEC
 CMP POPVAL
 BEQ :LOOP ;Same? Don't do anything.
 JSR :CHECKIT
 BCCL :NEWPOP
 LDA POPVAL
 INC
 PHA
 PZL PPPWINDPTR
 PHL #PPPctlPop
 _SetCtlValueByID
 BRL :LOOP

:DONE JSR :CHECKIT
 BCSL :LOOP
 PZL PPPWINDPTR
 _CloseWindow
 _SetPort
 _InitCursor
 JSR ENDTE
 PLA
 STA 7,S
 PLA
 STA 7,S
 PLS 2
 PLB
 RTL

:ID DA 0

:SETSAVEBUT JSR :GETCLEAN
 BEQ :TISCLEAN
 PEA 0
 BRA :TISJOIN
:TISCLEAN PEA 255
:TISJOIN PHS 2
 PZL PPPWINDPTR
 PHL #PPPctlSAVE
 _GetCtlHandleFromID
 _HiliteControl
 RTS

:SETSCRIPT PEA %0000_0000_000_01_101
 LDA POPVAL
 BEQ :CONN
 PHL MASTDISCSCRIPT
 BRA :SETJOIN
:CONN PHL MASTCONNSCRIPT
:SETJOIN PHS 2
 PEA 0
 PHL #0
 PHS 2
 PZL PPPWINDPTR
 PHL #PPPctlTE
 _GetCtlHandleFromID
 _TESetText
 RTS

:SETCLEAN PHS 2
 PZL PPPWINDPTR
 PHL #PPPctlTE
 _GetCtlHandleFromID
 PLXA PPPTMPHANDLE
 DEREF PPPTMPHANDLE;PPPTMPHANDLE
 LDY #$10
 LDA [PPPTMPHANDLE],Y ;ctlFlag
 AND #%1111_1111_1011_1111 ;Clear dirty flag
 STA [PPPTMPHANDLE],Y
 RTS

:GETCLEAN PHS 2
 PZL PPPWINDPTR
 PHL #PPPctlTE
 _GetCtlHandleFromID
 PLXA PPPTMPHANDLE
 DEREF PPPTMPHANDLE;PPPTMPHANDLE
 LDY #$10
 LDA [PPPTMPHANDLE],Y ;ctlFlag
 AND #%0100_0000
 RTS

:CHECKIT JSR :GETCLEAN
 BEQ :SCOK
 LDA POPVAL
 BEQ :DOCONN
 ~AlertWindow #%100_00_1;#:DSUBS;#SaveAlert
 BRA :JOINCHECK
:DOCONN ~AlertWindow #%100_00_1;#:CSUBS;#SaveAlert
:JOINCHECK PLA
 BEQ :SCOK
 DEC
 BEQ :CANX
:SAVEIT JSR GETSCRIPT
:SCONNOK JSR :SETCLEAN
:SCOK CLC
 RTS
:CANX SEC
 RTS

:DSUBS ADRL :DSTR
:DSTR STR 'disconnect'
:CSUBS ADRL :CSTR
:CSTR STR 'connect'

;:MYID DA 0

POPVAL DA 0

MASTCONNSCRIPT ADRL 0
MASTDISCSCRIPT ADRL 0

GETSCRIPT PHS 2
 PEA %0000_0000_000_11_101
 PHL #:SCRIPT
 PHS 2
 PEA 0
 PHL #0
 PHS 2
 PZL PPPWINDPTR
 PHL #PPPctlTE
 _GetCtlHandleFromID
 _TEGetText
 PLS 2

* Copy to master handle

 LDA POPVAL
 BEQ :CONN2

 LXA :SCRIPT
 STXA PPPTMPHANDLE
 LDY #8+2
 LDA [PPPTMPHANDLE],Y
 PHA
 DEY
 DEY
 LDA [PPPTMPHANDLE],Y
 PHA
 PHL MASTDISCSCRIPT
 _SetHandleSize
 PZL PPPTMPHANDLE
 PHL MASTDISCSCRIPT
 LDY #8+2
 LDA [PPPTMPHANDLE],Y
 PHA
 DEY
 DEY
 LDA [PPPTMPHANDLE],Y
 PHA
 _HandToHand
 ~DisposeHandle :SCRIPT
 RTS

:CONN2 LXA :SCRIPT
 STXA PPPTMPHANDLE
 LDY #8+2
 LDA [PPPTMPHANDLE],Y
 PHA
 DEY
 DEY
 LDA [PPPTMPHANDLE],Y
 PHA
 PHL MASTCONNSCRIPT
 _SetHandleSize
 PZL PPPTMPHANDLE
 PHL MASTCONNSCRIPT
 LDY #8+2
 LDA [PPPTMPHANDLE],Y
 PHA
 DEY
 DEY
 LDA [PPPTMPHANDLE],Y
 PHA
 _HandToHand
 ~DisposeHandle :SCRIPT
 RTS

:SCRIPT ADRL 0

STARTTE PEA 0
 _TEStatus
 PLA
 STA TESTATUS
 BNE :RTS
 ~LoadOneTool #34;#$0100
 ~MMStartUp
 PHS 2
 PEA 0
 PEA $0100
 LDA 9,S
 PHA
 PEA $C015
 PEA 0
 PEA 0
 _NewHandle
 PLXA TMPHANDLE
 STXA TEDPHANDLE
 LDA [TMPHANDLE]
 PHA
 _TEStartUp
:RTS RTS

ENDTE LDA TESTATUS
 BNE :RTS
 _TEShutDown
 ~DisposeHandle TEDPHANDLE
:RTS RTS

TESTATUS DA 0
TEDPHANDLE ADRL 0

TASKRECORD DS $2E

*-------------------------------------------------
* Controls
*-------------------------------------------------

CTLLIST equ *
 ADRL VERSIONCTL
 adrl TITLEctl ;control 1
 adrl EXITctl ;control 2
 adrl SAVEctl ;control 3
 adrl TEctl ;control 4
 adrl POPMENUctl ;control 5
 adrl RECTCTL ;control 6
 adrl 0 ;end of control list

VERSIONCTL DA 9
 ADRL 2 ;ID (1)
 RECTAT 5;250;9;60
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL VERSIONASC+1 ;text reference
VERSIONASCL DA 0
 DA -1 ;right justify

VERSIONASC DS 10

TITLEctl equ *
 dw 9 ;pCount
 adrl $2007 ;ID (8199)
 dw 5,12,14,177 ;rect
 adrl $81000000 ;static text
 dw $0000 ;flag
 dw $1000 ;moreFlags
 adrl 0 ;refCon
 adrl TITLEASC ;text reference
 dw TITLEASCL ;text size
 dw 0 ;justification

EXITctl equ *
 dw 9 ;pCount
 adrl PPPctlCANX
 dw 135,46,148,136 ;rect
 adrl $80000000 ;simple button
 dw $0000 ;flag
 dw $1000 ;moreFlags
 adrl 0 ;refCon
 adrl EXITSTR ;title
 adrl 0 ;no ctlColorTable
 hex 1B1B ;keyEquivalent
 dw $0000,$0000 ;modifiers

SAVEctl equ *
 dw 9 ;pCount
 adrl PPPctlSAVE
 dw 135,190,148,280 ;rect
 adrl $80000000 ;simple button
 dw $0000 ;flag
 dw $1000 ;moreFlags
 adrl 0 ;refCon
 adrl SAVESTR ;title
 adrl 0 ;no ctlColorTable
 hex 5373 ;keyEquivalent
 dw $0100,$0100 ;modifiers

TEctl equ *
 dw 23 ;pCount
 adrl PPPctlTE
 dw 20,12,114,310 ;rect
 adrl $85000000 ;text edit
 dw $0000 ;flag
 dw $7400 ;moreFlags
 adrl 0 ;refCon
 adrl $23A80000 ;textFlags
 dw 65535,65535,65535,65535 ;indentRectangle
 adrl -1 ;vertBar
 dw 0 ;vertAmount
 adrl 0 ;horzBar
 dw 0 ;horzAmount
 adrl 0 ;styleRef
 dw $0015 ;textFlags
 adrl 0 ;textRef
 adrl 0 ;textLength
 adrl 0 ;maxChars
 adrl 0 ;maxLines
 dw $0000 ;maxCharsPerLines
 dw $0000 ;maxHeight
 adrl 0 ;ctlColorTable
 dw $0000 ;drawMode
 adrl 0 ;filterProcPtr

POPMENUctl equ *
 dw 10 ;pCount
 adrl PPPctlPop
 dw 118,10,0,0 ;rect
 adrl $87000000 ;popup
 dw $0040 ;flag
 dw $1000 ;moreFlags
 adrl 0 ;refCon
 dw 0 ;title width
 adrl MENU_00000022 ;menu ref
 dw 1 ;initial value
 adrl 0 ;no ctlColorTable

RECTCTL equ *
 dw 8 ;pCount
 adrl $200C ;ID (8204)
 dw 15,12,16,310 ;rect
 adrl $87FF0003
 DA $0002
 dw $1000 ;moreFlags
 adrl 0 ;refCon
 DA 1,1

EXITSTR STR 'Exit'

SAVESTR STR 'Save'

SCRIPTSTR STR ' Script: '

CONNECTSTR STR 'Connect'

DISCSTR STR 'Disconnect'

*
* Menu Definitions
*

MENU_00000022 equ *
 dw 0 ;menu template version
 dw 34 ;menu ID
 dw $0000 ;menu flag
 adrl SCRIPTSTR ;title
 adrl MENUITEM_0000020A ;menuItem 1
 adrl MENUITEM_0000020B ;menuItem 2
 adrl 0 ;end of menuItem list
*
* Menu Item Definition
*

MENUITEM_0000020A equ *
 dw 0 ;menuitem template version
 dw 1 ;menuitem ID
 hex 00 ;alternate characters
 hex 00
 hex 0000 ;check character
 dw $0000 ;menubar flag
 adrl CONNECTSTR ;itemTitle

MENUITEM_0000020B equ *
 dw 0 ;menuitem template version
 dw 2 ;menuitem ID
 hex 00 ;alternate characters
 hex 00
 hex 0000 ;check character
 dw $0000 ;menubar flag
 adrl DISCSTR ;itemTitle

TITLEASC equ *
 asc 'PPP (scripted)'
TITLEASCL = *-TITLEASC

PPPXWINDOW dw $50 ;template size
 dw $20A0 ;frame bits
 adrl 0 ;no title
 adrl 0 ;window refcon
 dw 0,0,0,0 ;zoom rectangle
 adrl WCOLOR_00000FFB ;color table
 dw 0,0 ;origin y/x
 dw 0,0 ;data height/width
 dw 0,0 ;max height/width
 dw 0,0 ;scroll vert/horiz
 dw 0,0 ;page vert/horiz
 adrl 0 ;info refcon
 dw 0 ;info height
 adrl 0 ;frame defproc
 adrl 0 ;info defproc
 adrl 0 ;content defproc
 dw 29,158,183,482 ;position
 adrl -1 ;plane
 adrl CTLLIST ;control reference
 dw 3 ;indescref

WCOLOR_00000FFB equ *
 dw $0000 ;frame color
 dw $0F0F ;title color
 dw $0000 ;titlebar color
 dw $F0FF ;grow color
 dw $00F0 ;info color

SaveAlert ASC '54~You have modified the *0 script without saving'
 ASC ' it.~Don',D5,'t save~#1~^Save',00

EGGALERT ASC '63~Point to Point Protocol scripted for Marinetti',0D0D
 ASC 'Copyright (c) 1998-2003 by Richard Bennett',0D0D
 ASC '~^#0'
 DFB 0

 SAV PPPX.CONFIG.L

 END
