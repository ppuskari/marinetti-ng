 LST OFF
*=================================================
*
* C.INIT.S - Main code for TCPIP CDev
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
*
* When the CDEV is opened, the Control Panel
* calls it in the following order:
*
*    BootCDEV     (only called on the REAL boot)
*    RectCDEV
*    CreateCDEV
*    InitCDEV     (RunCDEV events may be called before any of these!)
*
*-------------------------------------------------

 USE 4/RJBUTIL.MACS
 USE 4/RESOURCE.MACS
 USE 4/MEM.MACS
* USE 4/MISC.MACS
 USE 4/WINDOW.MACS
 USE 4/CTL.MACS
 USE 4/QD.MACS
 USE 4/TCPIP.MACS

 USE ../EQUATES/BUILD.EQU
 USE ../EQUATES/TCPIP.EQU

~GetCodeResConverter MAC
 PHS 2
_GetCodeResConverter MAC
 Tool $3403
 <<<
~WriteCString MAC
 PHL ]1
_WriteCString MAC
 Tool $200C
 <<<
~WriteLine MAC
 PHL ]1
_WriteLine MAC
 Tool $1A0C
 <<<
_WaitCursor MAC
 Tool $A12
 <<<
~LoadOneTool MAC
 PxW ]1;]2
_LoadOneTool MAC
 Tool $F01
 <<<
_Int2Dec MAC
 Tool $260B
 <<<
_Dec2Int MAC
 Tool $280B
 <<<

 EXT SETDEFAULTBUT

MainSetup = $1001
MainConnect = 1
MainDisconnect = 2

SetupWindow = $FF9
SLIPWindow = $FF8

DiscoAlert = 1
ReconAlert = 2
AuthAlert = 3

DEBUG = 0

 DUM 1
TMPHANDLE ADRL 0
TMPTR ADRL 0
TMPTR2 ADRL 0
DPLEN
RTLADDR ADRL 0
DATA2 ADRL 0
DATA1 ADRL 0
MESSAGE DA 0
RESULT ADRL 0
 DEND

DBGMSG MAC
 do EYECATCHERS
 IMBED ]1
 fin
 <<<

*-------------------------------------------------
* Code
*-------------------------------------------------

CDEV PHB
 PHK
 PLB
 TSC
 SEC
 SBC #DPLEN-1
 TCS
 PHD
 TCD
*
 LDA MESSAGE
 ASL
 TAX
 JSR (:CMDTBL-2,X)
*
 LDA RTLADDR
 STA DATA1+2
 LDA RTLADDR+2
 STA MESSAGE
 PLD
 TSC
 CLC
 ADC #DPLEN-1+10
 TCS
 PLB
 RTL

:CMDTBL DA :RTS ;1 - MachineCDEV
 DA BootCDEV ;2 - BootCDEV
 DA :RTS ;3 - reserved
 DA InitCDEV ;4 - InitCDEV
 DA CloseCDEV ;5 - CloseCDEV
 DA :RTS ;6 - EventsCDEV
 DA CreateCDEV ;7 - CreateCDEV
 DA :RTS ;8 - AboutCDEV
 DA :RTS ;9 - RectCDEV
 DA HitCDEV ;10 - HitCDEV
 DA :RTS ;11 - RunCDEV

:RTS RTS

CHECKTCP DBGMSG CHECKTCP
 ~TCPIPVersion
 BCC :OUT
 PLS
 ~LoadOneTool #$36;#$200
 ~TCPIPVersion
:OUT PLS
 RTS

*-------------------------------------------------
* BootCDEV
*-------------------------------------------------

BootCDEV DBGMSG BootCDEV

 JSR CHECKTCP
 BCSL :RTS

 ~TCPIPGetBootConnectFlag
 PLA
 BEQ :RTS

 SEP $20
 LDA >$E0C029
 REP $20
 BMI :SKIP1
 ~WriteCString #:CONNECT
:SKIP1
 ~TCPIPConnect #0
 BCC :CONOK

 SEP $20
 LDA >$E0C029
 REP $20
 BMI :SKIP2
 ~WriteLine #:FAILED
:SKIP2
 RTS

:CONOK SEP $20
 LDA >$E0C029
 REP $20
 BMI :RTS
 PHS
 ~TCPIPGetMyIPAddress
 PHL #:IPADDRESS
 PEA 0
 _TCPIPConvertIPToCASCII
 PLA
 CLC
 ADC #4
 SEP $20
 STA :SUCCESS
 REP $20
 ~WriteLine #:SUCCESS
:RTS RTS

:CONNECT ASC 'TCP/IP CDev           v'
 VERASC
 ASC ' -- Connecting to the network',00

:FAILED STR ' failed.'

:SUCCESS STR ' as '
:IPADDRESS DS 15+1

*-------------------------------------------------
* CreateCDEV - Creates the correct window whether TCP is installed or not
*-------------------------------------------------

CreateCDev DBGMSG CreateCDev
 JSR CHECKTCP
 BCC :OK
 LDA #9 ;Bad
 BRA :JOIN
:OK LDA #1
:JOIN PHS 2
 PZL DATA1
 PEA 9
 PEA 0
 PHA
 _NewControl2
 PLS 2
 RTS

*-------------------------------------------------
* InitCDEV - Initialises correct connect/disconnect button
*-------------------------------------------------

InitCDEV DBGMSG InitCDEV
 JSR CHECKTCP
 BCS :RTS
 LXA DATA1
 STXA TMPTR
 JSR SETCONDISCON
:RTS RTS

* SETCONDISCON - Window pointer must be in TMPTR

SETCONDISCON

 PZL TMPTR ;window pointer for SETDEFAULTBUT

 ~TCPIPGetConnectStatus
 PLA
 BEQ :NO

:YES PHL #MainDisconnect
 PEA 255
 PEA 0
 BRA :JOIN

:NO PHL #MainConnect
 PEA 0
 PEA 255
:JOIN
 PHS 2
 PZL TMPTR
 PHL #MainDisconnect
 _GetCtlHandleFromID
 _HiliteControl

 PHS 2
 PZL TMPTR
 PHL #MainConnect
 _GetCtlHandleFromID
 _HiliteControl

 LDA 1+2,S
 ORA #$8000
 STA 1+2,S
 JSL SETDEFAULTBUT

 RTS

*-------------------------------------------------
* CloseCDEV - Saves the preferences when it closes
*-------------------------------------------------

CloseCDEV DBGMSG CloseCDEV
 ~TCPIPVersion
 PLS
 BCS :RTS
 ~TCPIPSavePreferences
:RTS RTS

*-------------------------------------------------
* HitCDEV - Accepts hits from the main window buttons
*-------------------------------------------------

HitCDEV DBGMSG HitCDEV
 ~TCPIPVersion
 PLS
 BCS :RTS
 LDX #0
]L1 LDA :CTLTBL,X
 BEQ :RTS
 EOR DATA2
 BEQ :GOTIT
 INX
 INX
 INX
 INX
 BRA ]L1
:RTS RTS
:GOTIT JMP (:CTLTBL+2,X)

:CTLTBL DA MainSetup,SETUP
 DA MainConnect,CONNECT
 DA MainDisconnect,DISCONNECT
 DA 0

*-------------------------------------------------
* Button procs
*-------------------------------------------------

SetupCancel = $1003
SetupOK = $1002
SetupDNS1 = $200F
SetupDNS2 = $100E
SetupConMsg = $2012
SetupUsername = $2014
SetupPassword = $2013
SetupLinkConfigure = $2018
SetupLinkPopUp = $2019
SetupAlive = $201A
SetupAliveEdit = $201B
SetupAliveMins = $201C
SetupBootConnect = $201D

SETUP DBGMSG SETUP

 ~GetPort

 SEP $20
 LDA >$E0C025
 REP $20
 AND #$C3
 CMP #$41 ;option-shift
 BNE :DOIT
 REP $30
 LDA :MOD+2
 BNE :MOD
 ~GetCodeResConverter
 LDA 3,S
 PHA
 LDA 3,S
 PHA
 PEA $8017
 PEA %01
 _ResourceConverter
 ~LoadResource #$8017;#2
 PLXA TMPHANDLE
 LDA [TMPHANDLE]
 STA :MOD+1
 LDY #1
 LDA [TMPHANDLE],Y
 STA :MOD+1+1
 PEA $8017
 PEA %00
 _ResourceConverter
 ~DetachResource #$8017;#2
:MOD JSL 0
 _SetPort
 RTS

:DOIT ~NewWindow2 #0;#0;#0;#0;#2;#SetupWindow;#$800E
 LDA 1,S
 STA TMPTR
 LDA 1+2,S
 STA TMPTR+2
 _SetPort

 ~TCPIPGetDNS #:MAINDNS

 ~TCPIPConvertIPToASCII :MAINDNS;#:DNSBUFF;#0
 PLA
 PZL TMPTR
 PHL #SetupDNS1
 PHL #:DNSBUFF
 _SetLETextByID

 ~TCPIPConvertIPToASCII :AUXDNS;#:DNSBUFF;#0
 PLA
 PZL TMPTR
 PHL #SetupDNS2
 PHL #:DNSBUFF
 _SetLETextByID

 ~TCPIPGetUsername #:TEMPBUFF51
 PZL TMPTR
 PHL #SetupUsername
 PHL #:TEMPBUFF51
 _SetLETextByID

 ~TCPIPGetPassword #:TEMPBUFF51
 PZL TMPTR
 PHL #SetupPassword
 PHL #:TEMPBUFF51
 _SetLETextByID

 ~TCPIPGetConnectMsgFlag
 PZL TMPTR
 PHL #SetupConMsg
 _SetCtlValueByID

 ~TCPIPGetBootConnectFlag
 PZL TMPTR
 PHL #SetupBootConnect
 _SetCtlValueByID

 ~TCPIPGetAliveFlag
 PLA
 BEQ :ALIVEOK
 LDA #1
:ALIVEOK PHA
 PZL TMPTR
 PHL #SetupAlive
 _SetCtlValueByID

 ~TCPIPGetAliveMinutes
 LDA 1,S
 PEA ^:TEMPBUFF51+1
 PEA :TEMPBUFF51+1
 CMP #10
 BCC :SINGLE
 CMP #100
 BCC :DOUBLE
:TRIPLE LDA #3
 BRA :SETMINS
:DOUBLE LDA #2
 BRA :SETMINS
:SINGLE LDA #1
:SETMINS PHA
 PEA 0
 SEP $20
 STA :TEMPBUFF51
 REP $20
 _Int2Dec
 PZL TMPTR
 PHL #SetupAliveEdit
 PHL #:TEMPBUFF51
 _SetLETextByID

* If link is up, disable "OK" and "Configure" buttons

 ~TCPIPGetConnectStatus
 PLA
 BEQ :ISDOWN

 PEA 255
 PHS 2
 PZL TMPTR
 PHL #SetupOK
 _GetCtlHandleFromID
 _HiliteControl

 PEA 255
 PHS 2
 PZL TMPTR
 PHL #SetupLinkConfigure
 _GetCtlHandleFromID
 _HiliteControl

:ISDOWN

* Do pop-up

 ~TCPIPGetModuleNames
 PLXA TMPTR2
 LDX #0
 LDY #0
]L1 LDA [TMPTR2],Y
 BEQ :DONELIST
 TYA
 CLC
 ADC #liMenuItem
 ADC TMPTR2
 STA :ITEMLIST,X
 LDA TMPTR2+2
 STA :ITEMLIST+2,X
 TYA
 CLC
 ADC #lilen
 TAY
 INX
 INX
 INX
 INX
 CPX #20*4
 BCC ]L1
:DONELIST STZ :ITEMLIST,X
 STZ :ITEMLIST+2,X
 ~TCPIPGetConnectMethod
 PLW :CONMETHOD
 PHS 2
 PZL TMPTR
 PEA 0
 PHL #:POPCTL
 _NewControl2
 PLXA

*

:LOOP ~DoModalWindow #TASKRECORD;#0;#0;#0;#%0100_0000_0000_1000
 PLXA
 CPX #SetupAliveEdit
 BEQ :ALIVEON
 CPX #SetupAliveMins
 BEQ :ALIVETOGGLE
 CPX #SetupCancel
 BEQL :DONE
 CPX #SetupOK
 BEQ :OK
 CPX #SetupLinkConfigure
 BNE :LOOP
 JSR CONFIGURE
 BRA :LOOP

:ALIVETOGGLE PHS
 PZL TMPTR
 PHL #SetupAlive
 _GetCtlValueByID
 PLA
 BEQ :ALIVEON
 PEA 0
 BRA :ALIVEJOINS
:ALIVEON PEA 1
:ALIVEJOINS PZL TMPTR
 PHL #SetupAlive
 _SetCtlValueByID
 BRA :LOOP

:OK PZL TMPTR
 PHL #SetupDNS1
 PHL #:DNSBUFF
 _GetLETextByID
 ~TCPIPConvertIPToHex #:DNSRES;#:DNSBUFF
 LXA :DNSRES
 STXA :MAINDNS

 PZL TMPTR
 PHL #SetupDNS2
 PHL #:DNSBUFF
 _GetLETextByID
 ~TCPIPConvertIPToHex #:DNSRES;#:DNSBUFF
 LXA :DNSRES
 STXA :AUXDNS

 ~TCPIPSetDNS #:MAINDNS

 PZL TMPTR
 PHL #SetupUsername
 PHL #:TEMPBUFF51
 _GetLETextByID
 ~TCPIPSetUsername #:TEMPBUFF51

 PZL TMPTR
 PHL #SetupPassword
 PHL #:TEMPBUFF51
 _GetLETextByID
 ~TCPIPSetPassword #:TEMPBUFF51

 PHS
 PZL TMPTR
 PHL #SetupConMsg
 _GetCtlValueByID
 _TCPIPSetConnectMsgFlag

 PHS
 PZL TMPTR
 PHL #SetupBootConnect
 _GetCtlValueByID
 _TCPIPSetBootConnectFlag

 PHS
 PZL TMPTR
 PHL #SetupLinkPopUp
 _GetCtlValueByID
 _TCPIPSetConnectMethod

 PHS
 PZL TMPTR
 PHL #SetupAlive
 _GetCtlValueByID
 _TCPIPSetAliveFlag

 PZL TMPTR
 PHL #SetupAliveEdit
 PHL #:TEMPBUFF51
 _GetLETextByID
 PHS
 PHL #:TEMPBUFF51+1
 LDA :TEMPBUFF51
 AND #$FF
 PHA
 PEA 0
 _Dec2Int
 LDA 1,S
 BNE :DECOK
 LDA #30 ;default
 STA 1,S
:DECOK _TCPIPSetAliveMinutes

 ~TCPIPSavePreferences
:DONE
 PZL TMPTR
 _CloseWindow
 _SetPort
 _InitCursor
 RTS

:FLAG DA 0,0

:DNSBUFF DS 1+15+1

:MAINDNS ADRL 0
:AUXDNS ADRL 0

:DNSRES ADRL 0
 DA 0

:TEMPBUFF51 DS 1+50+1

:POPCTL DA 9
 ADRL SetupLinkPopUp
 DA 92,10,0,0
 ADRL $87000000
 DA %0000000000000010
 DA %0001_0000_100_00_0_00
 ADRL 0
 DA 0
 ADRL :MENU
:CONMETHOD DA 0

:MENU DA 0,1,%0000_0000_0000_1000
 ADRL :MENUTITLE
:ITEMLIST LUP 20
 ADRL 0
 --^
 ADRL 0

:MENUTITLE STR ' Link layer: '

TASKRECORD DS $2E

*-------------------------------------------------
* Configure link
*-------------------------------------------------

CONFIGURE DBGMSG CONFIGURE
 ~TCPIPGetConnectMethod ;Get current

 PHS
 PZL TMPTR
 PHL #SetupLinkPopUp
 _GetCtlValueByID
 LDA 1,S
 STA :METHOD
 _TCPIPSetConnectMethod ;Got temp connect method

 ~MMStartUp
 PLW :ID

 ~TCPIPGetConnectData :ID;:METHOD
 LDA 1,S
 STA :CONNECTHANDLE
 LDA 1+2,S
 STA :CONNECTHANDLE+2

 ~TCPIPGetDisconnectData :ID;:METHOD
 LDA 1,S
 STA :DISCONNECTHANDLE
 LDA 1+2,S
 STA :DISCONNECTHANDLE+2

 _TCPIPEditLinkConfig

 ~TCPIPSetConnectData :METHOD;:CONNECTHANDLE
 ~TCPIPSetDisconnectData :METHOD;:DISCONNECTHANDLE

 _TCPIPSetConnectMethod ;Restore original method

 RTS

:ID DA 0
:METHOD DA 0

:CONNECTHANDLE ADRL 0
:DISCONNECTHANDLE ADRL 0

UPDATEWIND ;Control is in DATA1, use it to look up WINDPTR
 LDA [DATA1]
 STA TMPTR
 LDY #2
 LDA [DATA1],Y
 STA TMPTR+2
 LDY #4+2
 LDA [TMPTR],Y
 PHA
 DEY
 DEY
 LDA [TMPTR],Y
 PHA
 _DrawControls
 RTS

CONNECT DBGMSG CONNECT
 ~TCPIPGetReconnectStatus
 PLA
 BEQ :CONNECT
 ~AlertWindow #%100_10_1;#0;#ReconAlert
 JSR UPDATEWIND
 PLA
 BEQ :CANX
 DEC
 BEQ :CONNECT
 ~TCPIPReconnect #0
 BCC :CONOK
 BRL :ERR
:CANX RTS
:CONNECT _WaitCursor
 ~NewWindow2 #0;#0;#0;#0;#0;#CONWINDOW;#$800E
 LDA 1,S
 STA CONNECTWINDPTR
 LDA 1+2,S
 STA CONNECTWINDPTR+2
 _DrawControls
 ~TCPIPConnect #CONNECTDISPLAY
 PHP
 PHA
 ~CloseWindow CONNECTWINDPTR
 _InitCursor
 PLA
 PLP
 BCS :ERR
:CONOK LDA [DATA1]
 STA TMPTR
 LDY #2
 LDA [DATA1],Y
 STA TMPTR+2
 LDY #4
 LDA [TMPTR],Y
 TAX
 INY
 INY
 LDA [TMPTR],Y
 STXA TMPTR
 JMP SETCONDISCON
:ERR STA TMPTR
 PHS 2
 ~MMStartUp
 _TCPIPGetAuthMessage
 PLXA TMPHANDLE
 PHS 2
 PHXA
 _GetHandleSize
 LDA 1,S
 ORA 1+2,S
 BEQ :NOAUTH
 LDA 1,S ;Add a word to the end
 CLC
 ADC #2
 TAX
 LDA 1+2,S
 ADC #0
 PHA
 PHX
 PZL TMPHANDLE
 _SetHandleSize
 DEREF TMPHANDLE;TMPTR
 STXA :SUBARRAY
 PLY ;one still on stack as space for alertwindow
 LDA #0
 STA [TMPTR],Y
 PEA #%110_10_0
 PHL #:SUBARRAY
 PHL #AuthAlert
 _AlertWindow
 PLA
 PZL TMPHANDLE
 _Disposehandle
 RTS
:NOAUTH PZL TMPHANDLE
 _Disposehandle
 PLS ;need one for alertwindow
 PEA #%110_10_1
 PHL #:CONSUBS
 PEA 0
 PEI TMPTR ;the error code
 _AlertWindow
 PLA
 RTS

:SUBARRAY ADRL 0

:CONSUBS ADRL :CONSTR

:CONSTR STR 'connect'

CONNECTWINDPTR ADRL 0

CONNECTDISPLAY ~GetPort
 ~SetPort >CONNECTWINDPTR
 ~EraseRect #DISSTAT+6 ;Is wider than the connect one
 PHW >CONSTAT+6+RECTX1
 LDA >CONSTAT+6+RECTY2
 DEC
 PHA
 _MoveTo
 LDA 8+2,S
 PHA
 LDA 2+8,S
 PHA
 _DrawString
 _SetPort
 PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 RTL

DISCONNECT DBGMSG DISCONNECT
 ~GetPort
 _WaitCursor
 ~NewWindow2 #0;#0;#0;#0;#0;#DISWINDOW;#$800E
 LDA 1,S
 STA CONNECTWINDPTR
 LDA 1+2,S
 STA CONNECTWINDPTR+2
 _DrawControls
 ~TCPIPDisconnect #0;#CONNECTDISPLAY
 BCC :DISCOK
 CMP #terrLOGINSPENDING
 SEC
 BNE :DISCOK ;Not OK, but should continue on with failure
 PHS
 PEA #%110_10_1
 PHL #0
 PEA 0
 PHW #DiscoAlert
 _InitCursor
 _AlertWindow
 JSR UPDATEWIND
 PHL CONNECTWINDPTR
 _DrawControls
 PLA
 CLC
 BEQ :DISCOK ;Pretend it was OK, so no alert is presented
 ~TCPIPDisconnect #$8000;#CONNECTDISPLAY
:DISCOK PHP
 PHA
 ~CloseWindow CONNECTWINDPTR
 _InitCursor
 PLA
 PLP
 BCS :ERR
 LDA [DATA1] ;Convert controlHandle to windPtr to port
 STA TMPTR
 LDY #2
 LDA [DATA1],Y
 STA TMPTR+2
 LDY #4
 LDA [TMPTR],Y
 TAX
 INY
 INY
 LDA [TMPTR],Y
 STXA TMPTR
 _SetPort
 JMP SETCONDISCON
:ERR PHS
 PEA #%110_10_1
 PHL #:DISSUBS
 PEA 0
 PHA
 _AlertWindow
 PLA
 _SetPort
 RTS

:DISSUBS ADRL :DISSTR

:DISSTR STR 'disconnect'

CONWINDOW DA $50 ;template size
 DA $00A0 ;frame bits
 ADRL 0 ;no title
 ADRL 0 ;window refcon
 DA 0,0,0,0 ;zoom rectangle
 ADRL 0 ;standard colors
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
 CENTRERECT 41;332
 ADRL -1 ;plane
 ADRL CONCTLS
 DA 3

CONCTLS ADRL CONSTAT
 ADRL CONICON
 ADRL CANXSTAT
 ADRL 0

CONSTAT DA 9 ;pCount
 ADRL 1 ;ID (1)
 DA 11,94,20,332 ;rect
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL CONTXT
 DA CONTXTL ;text size
 DA 0 ;justification
CONTXT ASC 'Connecting to the network...',0D
CONTXTL = *-CONTXT

CANXSTAT DA 966 ;pCount
 ADRL 1 ;ID (1)
 DA 21,94,30,299 ;rect
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL CANXTXT
 DA CANXTXTL ;text size
 DA 0 ;justification
CANXTXT ASC 'Press ',11,'. to cancel'
CANXTXTL = *-CANXTXT

DISWINDOW DA $50 ;template size
 DA $00A0 ;frame bits
 ADRL 0 ;no title
 ADRL 0 ;window refcon
 DA 0,0,0,0 ;zoom rectangle
 ADRL 0 ;standard colors
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
 CENTRERECT 41;372
 ADRL -1 ;plane
 ADRL DISCTLS
 DA 3

DISCTLS ADRL DISSTAT
 ADRL CONICON
 ADRL CANXSTAT
 ADRL 0

DISSTAT DA 9 ;pCount
 ADRL 1 ;ID (1)
 DA 11,94,20,372 ;rect
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL DISTXT
 DA DISTXTL ;text size
 DA 0 ;justification
DISTXT ASC 'Disconnecting from the network...',0D
DISTXTL = *-DISTXT

CONICON DA 7
 ADRL 2
 DA 6,22,34,77
 ADRL $07FF0001
 DA %0000_0000_0000_1100
 DA %0001_0000_00_10_00_00
 ADRL 0
 ADRL 1

CONRESERVED ADRL 0

 SAV C.INIT.L

 END
