 LST OFF
 REL
 mx 0

*=================================================
*
* PPP.CONFIG.S - Configuration window for standard PPP driver
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
*=================================================

 USE 4/RJBUTIL.MACS
 USE 4/MEM.MACS
 USE 4/EVENT.MACS
 USE 4/WINDOW.MACS
 USE 4/CTL.MACS
 USE 4/TEXTEDIT.MACS
 USE 4/QD.MACS
 USE ../../Equates/BUILD.EQU
 USE ../../Equates/I.EQU
 USE ../../Equates/TCPIP.EQU

 EXT PPPVERSION

~VersionString MAC
 PHW ]1
 PxL ]2;]3
_VersionString MAC
 LDX #$3903
 JSL $E10000
 <<<

 DUM LLSPACE ;My direct space on Marinetti's direct page
PPPWINDPTR ADRL 0
MASTCONHANDLE ADRL 0
PPPTMPTR ADRL 0
 DEND

CFGVERS = 2

DEFAULTCFG ORG 0 ;connect data
CFGVERSION DA CFGVERS ;version
CFGINIT STR 'ATZ' ;Init string
 DS 1+50-*+CFGINIT
 DS 1 ;  for 00 at end of GetLEText
CFGDIAL DS 1+50 ;phone number
 DS 1 ;  for 00 at end of GetLEText
CFGBAUD DA 15 ;19200
CFGPORT DA $8002 ;modem port
CFGLEN
 ORG

*-------------------------------------------------
* PPPCONFIGURE(connectHandle,disconnectHandle);
*-------------------------------------------------

PPPctlSAVE = $2009
PPPctlCANX = $2008
PPPctlSpeedPop = $2006
PPPctlInit = $2005
PPPctlDial = $2004
PPPctlPortPop = $2001

* UPTO: Change so handles passed are only modified at end. All work handles
*       must be new.

PPPCONFIGURE ENT
 DBGMSG PPPCONFIGURE
 PHB
 PHK
 PLB

* Get connect data handle and save it as MASTCONN

 LDA 9+2,S
 STA MASTCONHANDLE+2
 LDA 9,S
 STA MASTCONHANDLE

 LDY #8
 LDA [MASTCONHANDLE],Y
 INY
 INY
 ORA [MASTCONHANDLE],Y
 BEQ :SETDEFAULT ;Empty handle?
 LDA [MASTCONHANDLE]
 STA PPPTMPTR
 LDY #2
 LDA [MASTCONHANDLE],Y
 STA PPPTMPTR+2
 LDA [PPPTMPTR] ;get version
 CMP #CFGVERS
 BEQ :CONNOK
:SETDEFAULT PHL #CFGLEN
 PZL MASTCONHANDLE
 _SetHandleSize
 PHL #DEFAULTCFG
 PZL MASTCONHANDLE
 PHL #CFGLEN
 _PtrToHand
:CONNOK

* Present window

 ~GetPort

 PEA 0
 PHL PPPVERSION
 PHL #VERSIONASC
 _VersionString
 LDA VERSIONASC
 AND #$FF
 STA VERSIONASCL

 ~NewWindow2 #0;#0;#0;#0;#0;#PPPWINDOW;#$800E
 LDA 1,S
 STA PPPWINDPTR
 LDA 1+2,S
 STA PPPWINDPTR+2
 _SetPort

 LOCK MASTCONHANDLE

 LDA [MASTCONHANDLE]
 STA PPPTMPTR
 LDY #2
 LDA [MASTCONHANDLE],Y
 STA PPPTMPTR+2

 LDY #CFGPORT
 LDA [PPPTMPTR],Y
 PHA
 PZL PPPWINDPTR
 PHL #PPPctlPortPop
 _SetCtlValueByID

 LDY #CFGBAUD
 LDA [PPPTMPTR],Y
 PHA
 PZL PPPWINDPTR
 PHL #PPPctlSpeedPop
 _SetCtlValueByID

 PZL PPPWINDPTR
 PHL #PPPctlInit
 LDA PPPTMPTR
 CLC
 ADC #CFGINIT
 TAX
 LDA PPPTMPTR+2
 ADC #0
 PHA
 PHX
 _SetLETextByID

 PZL PPPWINDPTR
 PHL #PPPctlDial
 LDA PPPTMPTR
 CLC
 ADC #CFGDIAL
 TAX
 LDA PPPTMPTR+2
 ADC #0
 PHA
 PHX
 _SetLETextByID

 UNLOCK MASTCONHANDLE
:LOOP ~DoModalWindow #TASKRECORD;#0;#0;#0;#%0100_0000_0000_1000
 PLXA
 CPX #PPPctlCANX
 BEQL :DONE
 CPX #PPPctlSAVE
 BEQ :SAVE
 CPX VERSIONCTL+2
 BEQ :EGG
 BRA :LOOP

:EGG ~AlertWindow #%100_00_1;#0;#EGGALERT
 PLA
 BRA :LOOP

:SAVE LOCK MASTCONHANDLE

 LDA [MASTCONHANDLE]
 STA PPPTMPTR
 LDY #2
 LDA [MASTCONHANDLE],Y
 STA PPPTMPTR+2

 PHS
 PZL PPPWINDPTR
 PHL #PPPctlPortPop
 _GetCtlValueByID
 PLA
 LDY #CFGPORT
 STA [PPPTMPTR],Y

 PHS
 PZL PPPWINDPTR
 PHL #PPPctlSpeedPop
 _GetCtlValueByID
 PLA
 LDY #CFGBAUD
 STA [PPPTMPTR],Y

 PZL PPPWINDPTR
 PHL #PPPctlInit
 LDA PPPTMPTR
 CLC
 ADC #CFGINIT
 TAX
 LDA PPPTMPTR+2
 ADC #0
 PHA
 PHX
 _GetLETextByID

 PZL PPPWINDPTR
 PHL #PPPctlDial
 LDA PPPTMPTR
 CLC
 ADC #CFGDIAL
 TAX
 LDA PPPTMPTR+2
 ADC #0
 PHA
 PHX
 _GetLETextByID

 UNLOCK MASTCONHANDLE

:DONE PZL PPPWINDPTR
 _CloseWindow
 _SetPort
 _InitCursor
 PLA
 STA 7,S
 PLA
 STA 7,S
 PLS 2
 PLB
 RTL

:ID DA 0

:TEMPBUFF52 DS 1+50+1

TASKRECORD DS $2E

*-------------------------------------------------
* Controls
*-------------------------------------------------

CTLLST_00002000 ADRL VERSIONCTL
 ADRL TITLECTL
 ADRL CANXctl
 ADRL SAVEctl
 ADRL RECTCTL
 ADRL SPEEDPOPctl
 ADRL DIALEDITctl
 ADRL MINITEDITctl
 ADRL MINITctl
 ADRL DIALctl
 ADRL PORTPOPctl
 ADRL 0
*
* Control Templates
*

VERSIONCTL DA 9
 ADRL 2 ;ID (1)
 RECTAT 5;436;9;60
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL VERSIONASC+1 ;text reference
VERSIONASCL DA 0
 DA -1 ;right justify

VERSIONASC DS 10

PORTPOPctl DA 10 ;pCount
 ADRL PPPctlPortPop
 DA 23,8,0,0 ;rect
 ADRL $87000000 ;popup
 DA $0040 ;flag
 DA $1080 ;moreFlags
 ADRL 0 ;refCon
 DA 0 ;title width
 ADRL MENU_00000002 ;menu ref
 DA 269 ;initial value
 ADRL 0 ;no ctlColorTable

DIALctl DA 9 ;pCount
 ADRL $2002 ;ID (8194)
 DA 60,12,70,143 ;rect
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL DIALASC ;text reference
 DA DIALASC_CNT ;text size
 DA 0 ;justification

MINITctl DA 9 ;pCount
 ADRL $2003 ;ID (8195)
 DA 44,12,54,143 ;rect
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL MODEMINITASC ;text reference
 DA MODEMINITASC_CNT ;text size
 DA 0 ;justification

DIALEDITctl DA 8 ;pCount
 ADRL PPPctlDial
 DA 58,152,71,376 ;rect
 ADRL $83000000 ;line edit
 DA $0000 ;flag
 DA $7000 ;moreFlags
 ADRL 0 ;refCon
 DA 50 ;max size
 ADRL NULL ;default

MINITEDITctl DA 8 ;pCount
 ADRL PPPctlInit
 DA 42,152,55,376 ;rect
 ADRL $83000000 ;line edit
 DA $0000 ;flag
 DA $7000 ;moreFlags
 ADRL 0 ;refCon
 DA 50 ;max size
 ADRL NULL ;default

SPEEDPOPctl DA 10 ;pCount
 ADRL PPPctlSpeedPop
 DA 23,188,0,0 ;rect
 ADRL $87000000 ;popup
 DA $0040 ;flag
 DA $1080 ;moreFlags
 ADRL 0 ;refCon
 DA 0 ;title width
 ADRL MENU_00000001 ;menu ref
 DA 1 ;initial value
 ADRL 0 ;no ctlColorTable

TITLECTL DA 9 ;pCount
 ADRL $2007 ;ID (8199)
 DA 5,12,14,113 ;rect
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL TITLEASC ;text reference
 DA TITLEASC_CNT ;text size
 DA 0 ;justification

CANXctl DA 9 ;pCount
 ADRL PPPctlCANX
 DA 58,400,71,494 ;rect
 ADRL $80000000 ;simple button
 DA $0000 ;flag
 DA $3000 ;moreFlags
 ADRL 0 ;refCon
 ADRL CANCELSTR ;title
 ADRL 0 ;no ctlColorTable
 HEX 1B1B ;keyEquivalent
 DA $0000,$0000 ;modifiers

SAVEctl DA 9 ;pCount
 ADRL PPPctlSAVE
 DA 39,400,52,494 ;rect
 ADRL $80000000 ;simple button
 DA $0001 ;flag
 DA $3000 ;moreFlags
 ADRL 0 ;refCon
 ADRL SAVESTR ;title
 ADRL 0 ;no ctlColorTable
 HEX 0D0D ;keyEquivalent
 DA $0000,$0000 ;modifiers

RECTCTL DA 8 ;pCount
 ADRL $200C ;ID (8204)
 DA 15,12,16,496 ;rect
 ADRL $87FF0003
 DA $0002
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 DA 1,1

PPORTSTR STR 'Printer Port'

PORTSTR STR ' Port: '

NULL DFB 0

B9600STR STR '9600'

B19200STR STR '19200'

B38400STR STR '38400'

B57600STR STR '57600'

B2400STR STR '2400'

B1200STR STR '1200'

MPORTSTR STR 'Modem Port'

B4800STR STR '4800'

ATSTR STR ' at '

CANCELSTR STR 'Cancel'

SAVESTR STR 'Save'

*
* Menu Definitions
*

MENU_00000001 DA 0 ;menu template version
 DA 1 ;menu ID
 DA $0000 ;menu flag
 ADRL ATSTR ;title
 ADRL MENUITEM_0000010C ;menuItem 1
 ADRL MENUITEM_0000010B ;menuItem 2
 ADRL MENUITEM_00000001 ;menuItem 3
 ADRL MENUITEM_00000107 ;menuItem 4
 ADRL MENUITEM_00000108 ;menuItem 5
 ADRL MENUITEM_00000109 ;menuItem 6
 ADRL MENUITEM_0000010A ;menuItem 7
 ADRL 0 ;end of menuItem list

MENU_00000002 DA 0 ;menu template version
 DA 2 ;menu ID
 DA $0000 ;menu flag
 ADRL PORTSTR ;title
 ADRL MENUITEM_0000010D ;menuItem 1
 ADRL MENUITEM_0000010E ;menuItem 2
 ADRL 0 ;end of menuItem list
*
* Menu Item Definition
*

MENUITEM_00000001 DA 0 ;menuitem template version
 DA 12 ;menuitem ID
 HEX 00 ;alternate characters
 HEX 00
 HEX 0000 ;check character
 DA $0000 ;menubar flag
 ADRL B4800STR ;itemTitle

MENUITEM_00000107 DA 0 ;menuitem template version
 DA 14 ;menuitem ID
 HEX 00 ;alternate characters
 HEX 00
 HEX 0000 ;check character
 DA $0000 ;menubar flag
 ADRL B9600STR ;itemTitle

MENUITEM_00000108 DA 0 ;menuitem template version
 DA 15 ;menuitem ID
 HEX 00 ;alternate characters
 HEX 00
 HEX 0000 ;check character
 DA $0000 ;menubar flag
 ADRL B19200STR ;itemTitle

MENUITEM_00000109 DA 0 ;menuitem template version
 DA 16 ;menuitem ID
 HEX 00 ;alternate characters
 HEX 00
 HEX 0000 ;check character
 DA $0000 ;menubar flag
 ADRL B38400STR ;itemTitle

MENUITEM_0000010A DA 0 ;menuitem template version
 DA 17 ;menuitem ID
 HEX 00 ;alternate characters
 HEX 00
 HEX 0000 ;check character
 DA $0000 ;menubar flag
 ADRL B57600STR ;itemTitle

MENUITEM_0000010B DA 0 ;menuitem template version
 DA 10 ;menuitem ID
 HEX 00 ;alternate characters
 HEX 00
 HEX 0000 ;check character
 DA $0000 ;menubar flag
 ADRL B2400STR ;itemTitle

MENUITEM_0000010C DA 0 ;menuitem template version
 DA 8 ;menuitem ID
 HEX 00 ;alternate characters
 HEX 00
 HEX 0000 ;check character
 DA $0000 ;menubar flag
 ADRL B1200STR ;itemTitle

MENUITEM_0000010D DA 0 ;menuitem template version
 DA 32769 ;menuitem ID
 HEX 00 ;alternate characters
 HEX 00
 HEX 0000 ;check character
 DA $0000 ;menubar flag
 ADRL PPORTSTR ;itemTitle

MENUITEM_0000010E DA 0 ;menuitem template version
 DA 32770 ;menuitem ID
 HEX 00 ;alternate characters
 HEX 00
 HEX 0000 ;check character
 DA $0000 ;menubar flag
 ADRL MPORTSTR ;itemTitle

DIALASC ASC 'Dial phone number:'
DIALASC_Cnt = *-DIALASC

MODEMINITASC ASC 'Modem init string:'
MODEMINITASC_Cnt = *-MODEMINITASC

TITLEASC ASC 'PPP'
TITLEASC_Cnt = *-TITLEASC

*
* Window Definition
*

PPPWINDOW DA $50 ;template size
 DA $20A0 ;frame bits
 ADRL 0 ;no title
 ADRL 0 ;window refcon
 DA 0,0,0,0 ;zoom rectangle
 ADRL WCOLOR_00000FFB ;color table
 DA 0,0 ;origin y/x
 DA 0,0 ;data height/width
 DA 0,0 ;max height/width
 DA 0,0 ;scroll vert/horiz
 DA 0,0 ;page vert/horiz
 ADRL 0 ;info refcon
 DA 0 ;info height
 ADRL 0 ;frame defproc
 ADRL 0 ;info defproc
 ADRL 0 ;content defproc
 CENTRERECT 78;510
; DA 67,64,145,574 ;position
 ADRL -1 ;plane
 ADRL CTLLST_00002000 ;control reference
 DA 3 ;indescref
*
* Window Color Table
*

WCOLOR_00000FFB equ *
 DA $0000 ;frame color
 DA $0F0F ;title color
 DA $0000 ;titlebar color
 DA $F0FF ;grow color
 DA $00F0 ;info color

EGGALERT ASC '63~Point to Point Protocol for Marinetti',0D0D
 ASC 'Copyright (c) 1998-2003 by Richard Bennett',0D0D
 ASC '~^#0'
 DFB 0

 SAV PPP.CONFIG.L

 END
