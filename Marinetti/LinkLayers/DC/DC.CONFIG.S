 LST OFF
*=================================================
*
* DC.CONFIG.S - Configuration window for Direct Connect link layer
*
* Copyright (C) 1998-2002 Richard Bennett
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
* 2003.04.21 RJBF - Initial release as open source
*
*=================================================
 REL
 mx 0

 USE 4/RJBUTIL.MACS
 USE 4/MEM.MACS
 USE 4/CTL.MACS
 USE 4/QD.MACS
 USE 4/WINDOW.MACS
 USE ../../EQUATES/BUILD.EQU
 USE ../../EQUATES/I.EQU
 USE ../../EQUATES/TCPIP.EQU

 EXT DCVERSION

~VersionString MAC
 PHW ]1
 PxL ]2;]3
_VersionString MAC
 LDX #$3903
 JSL $E10000
 <<<

]tcpiptoolnum = $36

~TCPIPConvertIPToHex MAC
 PxL ]1;]2
_TCPIPConvertIPToHex MAC
 LDX #$0D00+]tcpiptoolnum
 JSL $E10000
 <<<
~TCPIPConvertIPToASCII MAC
 PHA
 PxL ]1;]2
 PHW ]3
_TCPIPConvertIPToASCII MAC
 LDX #$0E00+]tcpiptoolnum
 JSL $E10000
 <<<

 DUM LLSPACE ;My direct space on Marinetti's direct page
DCWINDPTR ADRL 0
MASTCONHANDLE ADRL 0
DCTMPTR ADRL 0
 DEND

CFGVERS = 2

DEFAULTCFG ORG 0 ;connect data
CFGVERSION DA CFGVERS ;version
CFGIP DFB 192,168,0,1 ;Default IP
CFGBAUD DA 15 ;19200
CFGPORT DA $8002 ;modem
CFGLEN
 ORG

*-------------------------------------------------
* DCCONFIGURE(connectHandle,disconnectHandle);
*-------------------------------------------------

DCctlSAVE = $2009
DCctlCANX = $2008
DCctlSpeed = $2006
DCctlIP = $2005
DCctlPort = $2002

DCCONFIGURE ENT
 DBGMSG DCCONFIGURE
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
 STA DCTMPTR
 LDY #2
 LDA [MASTCONHANDLE],Y
 STA DCTMPTR+2
 LDA [DCTMPTR] ;get version
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
 PHL DCVERSION
 PHL #VERSIONASC
 _VersionString
 LDA VERSIONASC
 AND #$FF
 STA VERSIONASCL

 ~NewWindow2 #0;#0;#0;#0;#0;#DCWINDOW;#$800E
 LDA 1,S
 STA DCWINDPTR
 LDA 1+2,S
 STA DCWINDPTR+2
 _SetPort

 LOCK MASTCONHANDLE

 LDA [MASTCONHANDLE]
 STA DCTMPTR
 LDY #2
 LDA [MASTCONHANDLE],Y
 STA DCTMPTR+2

 LDY #CFGBAUD
 LDA [DCTMPTR],Y
 PHA
 PZL DCWINDPTR
 PHL #DCctlSpeed
 _SetCtlValueByID

 LDY #CFGPORT
 LDA [DCTMPTR],Y
 PHA
 PZL DCWINDPTR
 PHL #DCctlPort
 _SetCtlValueByID

 PHS
 LDY #CFGIP+2
 LDA [DCTMPTR],Y
 PHA
 DEY
 DEY
 LDA [DCTMPTR],Y
 PHA
 PHL #:TEMPBUFF16
 PEA 0
 _TCPIPConvertIPToASCII
 PLA
 PZL DCWINDPTR
 PHL #DCctlIP
 PHL #:TEMPBUFF16
 _SetLETextByID

 UNLOCK MASTCONHANDLE

:LOOP ~DoModalWindow #TASKRECORD;#0;#0;#0;#%0100_0000_0000_1000
 PLXA
 CPX #DCctlCANX
 BEQL :DONE
 CPX #DCctlSAVE
 BEQ :SAVE
 CPX VERSIONctl+2
 BEQ :EGG
 BRA :LOOP

:EGG ~AlertWindow #%100_00_1;#0;#EGGALERT
 PLA
 BRA :LOOP

:SAVE LOCK MASTCONHANDLE

 LDA [MASTCONHANDLE]
 STA DCTMPTR
 LDY #2
 LDA [MASTCONHANDLE],Y
 STA DCTMPTR+2

 PHS
 PZL DCWINDPTR
 PHL #DCctlSpeed
 _GetCtlValueByID
 PLA
 LDY #CFGBAUD
 STA [DCTMPTR],Y

 PHS
 PZL DCWINDPTR
 PHL #DCctlPort
 _GetCtlValueByID
 PLA
 LDY #CFGPORT
 STA [DCTMPTR],Y

 PZL DCWINDPTR
 PHL #DCctlIP
 PHL #:TEMPBUFF16
 _GetLETextByID
 PHL #:CVTIP
 PHL #:TEMPBUFF16
 _TCPIPConvertIPToHex
 LDY #CFGIP
 LDA :CVTIP
 STA [DCTMPTR],Y
 INY
 INY
 LDA :CVTIP+2
 STA [DCTMPTR],Y

 UNLOCK MASTCONHANDLE

:DONE PZL DCWINDPTR
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

:CVTIP ADRL 0
 DA 0

:TEMPBUFF16 DS 1+15

TASKRECORD DS $2E

*-------------------------------------------------
* Controls and stuff
*-------------------------------------------------

CTLLST
 ADRL VERSIONCTL
 ADRL TITLEctl
 ADRL CANXctl
 ADRL SAVEctl
 ADRL LINEctl
 ADRL SPEEDPOPctl
 ADRL EDITctl
 ADRL LOCALIPctl
 ADRL PORTctl
 ADRL 0

VERSIONCTL DA 9
 ADRL 2 ;ID (1)
 RECTAT 5;242;9;60
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL VERSIONASC+1 ;text reference
VERSIONASCL DA 0
 DA -1 ;right justify

VERSIONASC DS 10

PORTctl
 DA 10 ; pCount
 ADRL DCctlPort
 DA 23,8,0,0 ; rect
 ADRL $87000000 ; popup
 DA $0040 ; flag
 DA $1080 ; moreFlags
 ADRL 0 ; refCon
 DA 0 ; title width
 ADRL MENU_00000002 ; menu ref
 DA 269 ; initial value
 ADRL 0 ; no ctlColorTable

LOCALIPctl
 DA 9 ; pCount
 ADRL $2003 ; ID (8195)
 DA 44,12,54,143 ; rect
 ADRL $81000000 ; static text
 DA $0000 ; flag
 DA $1000 ; moreFlags
 ADRL 0 ; refCon
 ADRL LOCALIPASC ; text reference
 DA LOCALIPASC_CNT ; text size
 DA 0 ; justification

EDITctl
 DA 8 ; pCount
 ADRL DCctlIP
 DA 42,144,55,270 ; rect
 ADRL $83000000 ; line edit
 DA $0000 ; flag
 DA $7000 ; moreFlags
 ADRL 0 ; refCon
 DA 15 ; max size
 ADRL BLANKSTR ; default

SPEEDPOPctl
 DA 10 ; pCount
 ADRL DCctlSpeed
 DA 23,188,0,0 ; rect
 ADRL $87000000 ; popup
 DA $0040 ; flag
 DA $1080 ; moreFlags
 ADRL 0 ; refCon
 DA 0 ; title width
 ADRL MENU_00000001 ; menu ref
 DA 1 ; initial value
 ADRL 0 ; no ctlColorTable

TITLEctl
 DA 8 ; pCount
 ADRL $2007 ; ID (8199)
 DA 5,12,14,193 ; rect
 ADRL $81000000 ; static text
 DA $0000 ; flag
 DA $1000 ; moreFlags
 ADRL 0 ; refCon
 ADRL TITLEASC ; text reference
 DA TITLEASC_CNT ; text size

CANXctl DA 9 ;pCount
 ADRL DCctlCANX
 DA 62,34,75,124 ;rect
 ADRL $80000000 ;simple button
 DA $0000 ;flag
 DA $3000 ;moreFlags
 ADRL 0 ;refCon
 ADRL CANXSTR ;title
 ADRL 0 ;no ctlColorTable
 HEX 1B1B ;keyEquivalent
 DA $0000,$0000 ;modifiers

SAVEctl
 DA 9 ; pCount
 ADRL DCctlSave
 DA 62,188,75,280 ; rect
 ADRL $80000000 ; simple button
 DA $0001 ; flag
 DA $1000 ; moreFlags
 ADRL 0 ; refCon
 ADRL SAVESTR ; title
 ADRL 0 ; no ctlColorTable
 HEX 0D0D00000000

LINEctl
 DA 8 ; pCount
 ADRL $200C ; ID (8204)
 DA 15,12,16,302 ; rect
 ADRL $87FF0003
 DA $0002 ; flag
 DA $1000 ; moreFlags
 ADRL 0 ; refCon
 DA 1,1

PRINTERSTR STR 'Printer Port'

PORTSTR STR ' Port '

BLANKSTR STR ' '

B9600STR STR '9600'

B19200STR STR '19200'

B38400STR STR '38400'

B57600STR STR '57600'

B2400STR STR '2400'

B1200STR STR '1200'

MODEMSTR STR 'Modem Port'

B4800STR STR '4800'

ATSTR STR ' at '

CANXSTR STR 'Cancel'

SAVESTR STR 'Save'

*
* MENU DEFINITIONS
*

MENU_00000001
 DA 0 ; menu template version
 DA 1 ; menu ID
 DA $0000 ; menu flag
 ADRL ATSTR ; title
 ADRL MENUITEM_0000010C ; menu 1
 ADRL MENUITEM_0000010B ; menu 2
 ADRL MENUITEM_00000001 ; menu 3
 ADRL MENUITEM_00000107 ; menu 4
 ADRL MENUITEM_00000108 ; menu 5
 ADRL MENUITEM_00000109 ; menu 6
 ADRL MENUITEM_0000010A ; menu 7
 ADRL 0 ; end of menuItem list

MENU_00000002
 DA 0 ; menu template version
 DA 2 ; menu ID
 DA $0000 ; menu flag
 ADRL PORTSTR ; title
 ADRL MENUITEM_0000010D ; menu 1
 ADRL MENUITEM_0000010E ; menu 2
 ADRL 0 ; end of menuItem list
*
* MENU ITEM DEFINITION
*

MENUITEM_00000001
 DA 0 ; menuitem template version
 DA 12 ; menuitem ID
 DFB 00 ; alternate characters
 DFB 00
 DA 0000 ; check character
 DA $0000 ; menubar flag
 ADRL B4800STR ; menu

MENUITEM_00000107
 DA 0 ; menuitem template version
 DA 14 ; menuitem ID
 DFB 00 ; alternate characters
 DFB 00
 DA 0000 ; check character
 DA $0000 ; menubar flag
 ADRL B9600STR ; menu

MENUITEM_00000108
 DA 0 ; menuitem template version
 DA 15 ; menuitem ID
 DFB 00 ; alternate characters
 DFB 00
 DA 0000 ; check character
 DA $0000 ; menubar flag
 ADRL B19200STR ; menu

MENUITEM_00000109
 DA 0 ; menuitem template version
 DA 16 ; menuitem ID
 DFB 00 ; alternate characters
 DFB 00
 DA 0000 ; check character
 DA $0000 ; menubar flag
 ADRL B38400STR ; menu

MENUITEM_0000010A
 DA 0 ; menuitem template version
 DA 17 ; menuitem ID
 DFB 00 ; alternate characters
 DFB 00
 DA 0000 ; check character
 DA $0000 ; menubar flag
 ADRL B57600STR ; menu

MENUITEM_0000010B
 DA 0 ; menuitem template version
 DA 10 ; menuitem ID
 DFB 00 ; alternate characters
 DFB 00
 DA 0000 ; check character
 DA $0000 ; menubar flag
 ADRL B2400STR ; menu

MENUITEM_0000010C
 DA 0 ; menuitem template version
 DA 8 ; menuitem ID
 DFB 0 ; alternate characters
 DFB 0
 DA 0000 ; check character
 DA $0000 ; menubar flag
 ADRL B1200STR ; menu

MENUITEM_0000010D
 DA 0 ; menuitem template version
 DA 32769 ; menuitem ID
 DFB 00 ; alternate characters
 DFB 00
 DA 0000 ; check character
 DA $0000 ; menubar flag
 ADRL PRINTERSTR ; menu

MENUITEM_0000010E
 DA 0 ; menuitem template version
 DA 32770 ; menuitem ID
 DFB 00 ; alternate characters
 DFB 00
 DA 0000 ; check character
 DA $0000 ; menubar flag
 ADRL MODEMSTR ; menu

LOCALIPASC ASC 'Local IP address:'
LOCALIPASC_CNT = *-LOCALIPASC

TITLEASC ASC 'Direct Connect'
TITLEASC_CNT = *-TITLEASC

DCWINDOW DA $50 ; template size
 DA $20A0 ; frame bits
 ADRL 0 ; no title
 ADRL 0 ; window refcon
 DA 0,0,0,0 ; zoom rectangle
 ADRL WCOLOR_00000FFB ; color table
 DA 0,0 ; origin y/x
 DA 0,0 ; data height/width
 DA 0,0 ; max height/width
 DA 0,0 ; scroll vert/horiz
 DA 0,0 ; page vert/horiz
 ADRL 0 ; info refcon
 DA 0 ; info height
 ADRL 0 ; frame defproc
 ADRL 0 ; info defproc
 ADRL 0 ; content defproc
 CENTRERECT 82;314
; DA 65,168,147,482 ; position
 ADRL -1 ; plane
 ADRL CTLLST ; control reference
 DA 3 ; indescref

WCOLOR_00000FFB
 DA $0000 ; frame color
 DA $0F0F ; title color
 DA $0000 ; titlebar color
 DA $F0FF ; grow color
 DA $00F0 ; info color

EGGALERT ASC '63~Direct Connect (IIGS to IIGS) for Marinetti',0D0D
 ASC 'Copyright (c) 1998-2002 by Richard Bennett',0D0D
 ASC '~^#0'
 DFB 0

 SAV DC.CONFIG.L

 END
