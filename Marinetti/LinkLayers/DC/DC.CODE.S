 LST OFF
*=================================================
*
* DC.CODE.S - Direct Connect link layer module
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
 USE 4/EVENT.MACS
 USE 4/INT.MACS
 USE 4/MEM.MACS
 USE 4/MISC.MACS
 USE 4/TCPIP.MACS
 USE ../../EQUATES/BUILD.EQU
 USE ../../EQUATES/I.EQU
 USE ../../EQUATES/TCPIP.EQU

 EXT Dvr8530ForceChar,Dvr8530CharsInBuffer,Dvr8530ReadChar
 EXT Dvr8530Init,Dvr8530Shutdown,Dvr8530CheckChar
 EXT Dvr8530FlushBuffer

MYLLINTVERS = 2

* Set version to 1.1f2

DCVERSH = $0110 ;MMMM_MMMM_mmmm_bbbb
DCVERSL = $8002 ;sss0_0000_rrrr_rrrr ss-20=d,40=a,60=b,80=f,A0=r

*

 DUM LLSPACE ;My direct space on Marinetti's direct page
TMPPKTHANDLE ADRL 0
TMPPKTPTR ADRL 0
CFGHANDLE ADRL 0
CFGPTR ADRL 0
 DEND

WINDOWLEN = 50 ;Length of match window (must by multiple of 2)

PARMSTACK = 4
PARMSTACKB = 1+PARMSTACK

* DCINTERFACEV():interfaceV:integer;
* DCSTARTUP():interfaceV:integer;
* DCSHUTDOWN();
* DCMODULEINFO(infoBlockPtr:longword);
* DCGETPACKET():packetHandle:handle;
* DCSENDPACKET(datagramPtr:longword,datagramLength:integer);
* DCCONNECT(conMsgFlag:integer,usernamePtr:longword,passwordPtr:longword,displayPtr:longword,conHandle:handle);
* DCRECONSTATUS():reconStatus:boolean;
* DCRECONNECT(displayPtr:longword);
* DCDISCONNECT(conMsgFlag:integer,usernamePtr:longword,passwordPtr:longword,displayPtr:longword,disconHandle:handle);
* DCGETVARIABLES():variablesPtr:longword
* DCCONFIGURE(connectHandle,disconnectHandle);
* DCCONFIGFNAME(configFileNamePtr:longword);

 EXT DCCONFIGURE

*-------------------------------------------------
* Main entry point
*-------------------------------------------------

DC DBGMSG DC
 JMP (:ROUTINES,X)

:ROUTINES DA DCINTERFACEV
 DA DCSTARTUP
 DA DCSHUTDOWN
 DA DCMODULEINFO
 DA DCGETPACKET
 DA DCSENDPACKET
 DA DCCONNECT
 DA DCRECONSTATUS
 DA DCRECONNECT
 DA DCDISCONNECT
 DA DCGETVARIABLES
 DA DCCONFIGURE
 DA DCCONFIGFNAME

*-------------------------------------------------
* DCINTERFACEV():interfaceV:integer;
*-------------------------------------------------

DCINTERFACEV DBGMSG DCINTERFACEV():interfaceV:integer;
 LDA #MYLLINTVERS
 STA PARMSTACK,S

*-------------------------------------------------
* DCSTARTUP():interfaceV:integer;
* DCSHUTDOWN()
*-------------------------------------------------

DCSTARTUP DBGMSG DCSTARTUP
DCSHUTDOWN DBGMSG DCSHUTDOWN
 LDA #lvVer
 STA >VARIABLES+lvVersion
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* DCMODULEINFO(infoBlockPtr:longword);
*-------------------------------------------------

DCMODULEINFO DBGMSG DCMODULEINFO(infoBlockPtr:longword);
 PHB
 PHK
 PLB
 TSC
 PHD
 TCD
 SEP $30
 LDY #INFOL-1
]L1 LDA INFO,Y
 STA [1+PARMSTACK],Y
 DEY
 BPL ]L1
 REP $30
 PLD
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 LDA #terrOK
 CLC
 RTL

INFO DA conDirectConnect
IS1 STR 'Direct Connect'
 DS 21-*+IS1
DCVERSION ENT
 DA DCVERSL
 DA DCVERSH
 DA %1000_0000_0000_0000
INFOL = *-INFO

*-------------------------------------------------
* DCGETPACKET():packetHandle:handle;
*-------------------------------------------------

DCGETPACKET DBGMSG DCGETPACKET():packetHandle:handle;
 PHB
 PHK
 PLB
 STY :USERID
*

:TOPLOOP LDX #0

:SCANLOOP PHX

 PHS
 PHX
 JSL Dvr8530CheckChar
 PLA

 PLX
 BCSL :NONE

 CMP #$C0
 BEQ :BUILDONE
 INX
 BPL :SCANLOOP
 ;off end of buffer. Ping of death? gather and see
:BUILDONE CPX #0
 BNE :BUILDOK
 PHS
 JSL Dvr8530ReadChar
 PLA
 BRA :TOPLOOP

:BUILDOK PHS 2
 PEA 0
 PHX
 PHW :USERID
 PEA $0018
 PEA 0
 PEA 0
 _NewHandle
 PLXA TMPPKTHANDLE
 DEREF TMPPKTHANDLE;TMPPKTPTR

 STZ :CHOPSIZE

 LDY #0
:BUILDLOOP PHY
 PHS
 JSL Dvr8530ReadChar
 PLA
 BCS :OVERRUN
 CMP #$C0
 BEQ :ENDPKT
 CMP #$DB
 BNE :STUFFIT
 PHS
 JSL Dvr8530ReadChar
 PLA
 CMP #$DC
 BEQ :STUFFC0
 CMP #$DD
 BEQ :STUFFDB
 BRA :STUFFIT ;Invalid code! Take it anyway...
:STUFFDB LDA #$DB
 BRA :STUFFIT1
:STUFFC0 LDA #$C0
:STUFFIT1 INC :CHOPSIZE
:STUFFIT PLY
 SEP $20
 STA [TMPPKTPTR],Y
 REP $20
 INY
 BRA :BUILDLOOP

:ENDPKT PLS

 LDA :CHOPSIZE
 BEQ :CHOPOK

 LDY #8
 LDA [TMPPKTHANDLE],Y
 SEC
 SBC :CHOPSIZE
 TAX
 INY
 INY
 LDA [TMPPKTHANDLE],Y
 SBC #0
 PHXA
 PZL TMPPKTHANDLE
 _SetHandleSize

:CHOPOK

 LDA TMPPKTHANDLE
 STA PARMSTACKB,S
 LDA TMPPKTHANDLE+2
 STA PARMSTACKB+2,S
 LDA #terrOK
 PLB
 CLC
 RTL

:OVERRUN PLS ;Packet WAS in buffer, but is now gone.
 PZL TMPPKTHANDLE ;possible buffer full with last character
 _DisposeHandle ;being the packet end.
 BRL :TOPLOOP

:NONE LDA #0
 STA PARMSTACKB,S
 STA PARMSTACKB+2,S
% LDA #terrOK
 PLB
 CLC
 RTL

:CHOPSIZE DA 0

:USERID DA 0

*-------------------------------------------------
* DCSENDPACKET(datagramPtr:longword,datagramLength:integer);
*-------------------------------------------------

DCSENDPACKET DBGMSG DCSENDPACKET(datagramPtr:longword,datagramLength:integer);
 PEA $C0
 JSL Dvr8530ForceChar
 LDA PARMSTACK+2+2,S
 PHA
 LDA 2+PARMSTACK+2,S
 PHA
 LDA 2+2+PARMSTACK,S
 PHA
 JSL DCWRITEPACKET
 PEA $C0
 JSL Dvr8530ForceChar
 PHB
 PLA
 STA 5,S
 PLA
 STA 5,S
 PLA
 PLB
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* DCWRITEPACKET(dataPtr:longword,dataLength:integer);
*-------------------------------------------------

 DUM 4
SENDPKTLEN DA 0
SENDPKTPTR ADRL 0
 DEND

DCWRITEPACKET DBGMSG DCWRITEPACKET(dataPtr:longword,dataLength:integer);
 TSC
 PHD
 TCD
 LDA SENDPKTLEN
 BEQ :DONE
 LDY #0
:LOOP PHY
 LDA [SENDPKTPTR],Y
 AND #$FF
 CMP #$C0
 BEQ :DBDC
 CMP #$DB
 BEQ :DBDD
:STUFFIT PHA
 JSL Dvr8530ForceChar
 PLY
 INY
 CPY SENDPKTLEN
 BCC :LOOP
 BRA :DONE

:DBDC PEA $DB
 JSL Dvr8530ForceChar
 LDA #$DC
 BRA :STUFFIT

:DBDD PEA $DB
 JSL Dvr8530ForceChar
 LDA #$DD
 BRA :STUFFIT

:DONE PLD
 PHB
 PLA
 STA 5,S
 PLA
 STA 5,S
 PLA
 PLB
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* DCCONNECT(conMsgFlag:integer,usernamePtr:longword,passwordPtr:longword,displayPtr:longword,conHandle:handle);
*-------------------------------------------------

DCCONNECT DBGMSG DCCONNECT
 PHB
 PHK
 PLB

 STZ VARIABLES+lvErrors
 STZ VARIABLES+lvIPaddress
 STZ VARIABLES+lvIPaddress+2
 LDA #65535
 STA VARIABLES+lvMTU

 LDA PARMSTACKB+16,S
 BNE :SHOWOK
 STZ DISPLAYPTR+1
 STZ DISPLAYPTR+1+1
 BRA :JOIN
:SHOWOK LDA PARMSTACKB+4,S
 STA DISPLAYPTR+1
 LDA PARMSTACKB+4+1,S
 STA DISPLAYPTR+1+1
 LDA #LINKSTR
 JSL SHOWPSTRING
:JOIN

 LDA PARMSTACKB,S
 STA CFGHANDLE
 LDA PARMSTACKB+2,S
 STA CFGHANDLE+2
 LDA [CFGHANDLE]
 STA CFGPTR
 LDY #2
 LDA [CFGHANDLE],Y
 STA CFGPTR+2
 LDA [CFGPTR]
 CMP #CFGVERS
 BNE :DEF

 PZL CFGPTR
 BRA :DOCFG
:DEF PHL #DEFAULTCFG
:DOCFG PHL #CONFIGURATION
 PHL #CFGLEN
 _TCPIPPtrToPtr

 LDX CONFIGURATION+CFGPORT
 LDA CONFIGURATION+CFGBAUD
 JSR STARTLINK
 BCS :ERR

 LDA #SETIPSTR
 JSL SHOWPSTRING

 LDA CONFIGURATION+CFGIP
 STA VARIABLES+lvIPaddress
 LDA CONFIGURATION+CFGIP+2
 STA VARIABLES+lvIPaddress+2

 LDA #true
 STA VARIABLES+lvConnected
 LDA #terrOK
 BRA :ERR

:ERR TAX
 PLA
 STA 21,S
 PLA
 STA 21,S
 PLS 9
 TXA
 PLB
 CMP #1
 RTL

CFGVERS = 2

DEFAULTCFG ORG 0 ;connect data
CFGVERSION DA CFGVERS ;version
CFGIP DFB 192,168,0,1 ;Default IP
CFGBAUD DA 15 ;19200
CFGPORT DA $8002 ;modem
CFGLEN
 ORG

CONFIGURATION DS CFGLEN

SETIPSTR STR 'Setting IP address'
LINKSTR STR 'Starting serial port driver'

*-------------------------------------------------
* DCRECONSTATUS():reconStatus:boolean;
*-------------------------------------------------

DCRECONSTATUS DBGMSG PPPRECONSTATUS
 LDA >VARIABLES+lvConnected ;If connected, no, if not, yes
 EOR #true
 STA PARMSTACK,S
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* DCRECONNECT(displayPtr:longword);
*-------------------------------------------------

DCRECONNECT DBGMSG DCRECONNECT(displayPtr:longword);
 LDA PARMSTACK,S
 STA >DISPLAYPTR+1
 LDA PARMSTACK+1,S
 STA >DISPLAYPTR+1+1
 PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 LDA #LINKSTR
 JSL SHOWPSTRING
 LDX #$8002 ;Try modem port?
 LDA #15 ;Try 19200
 JSR STARTLINK
 RTL

*-------------------------------------------------
* DCDISCONNECT(conMsgFlag:integer,usernamePtr:longword,passwordPtr:longword,displayPtr:longword,disconHandle:handle);
*-------------------------------------------------

DCDISCONNECT DBGMSG DCDISCONNECT
 PHB
 PHK
 PLB

 LDA PARMSTACKB+16,S
 BNE :SHOWOK
 STZ DISPLAYPTR+1
 STZ DISPLAYPTR+1+1
 BRA :JOIN
:SHOWOK LDA PARMSTACKB+4,S
 STA DISPLAYPTR+1
 LDA PARMSTACKB+4+1,S
 STA DISPLAYPTR+1+1
:JOIN
 LDA #:LINKSTR
 JSL SHOWPSTRING
 JSL Dvr8530Shutdown
 LDA #false
 STA VARIABLES+lvConnected
 LDA #terrOK
 TAX
 PLA
 STA 17,S
 PLA
 STA 17,S
 PLS 7
 TXA
 PLB
 CMP #1
 RTL

:LINKSTR STR 'Shutdown serial port'

*-------------------------------------------------
* DCGETVARIABLES():variablesPtr:longword
*-------------------------------------------------

DCGETVARIABLES DBGMSG DCGETVARIABLES
 LDA #VARIABLES
 STA 4,S
 LDA #^VARIABLES
 STA 4+2,S
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* DCCONFIGFNAME(configFileNamePtr:longword);
*-------------------------------------------------

DCCONFIGFNAME DBGMSG DCCONFIGFNAME(configFileNamePtr:longword);
 TSC
 PHD
 TCD
 SEP $30
 LDA >:CONFIGFNAME
 TAX
]L1 LDA >:CONFIGFNAME,X
 TXY
 STA [4],Y
 DEX
 BPL ]L1
 REP $30
 PLD
 PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 LDA #terrOK
 CLC
 RTL

:CONFIGFNAME STR 'Direct.config'

*-------------------------------------------------
* Support subroutines which don't need DBK and DP
*-------------------------------------------------

STARTLINK DBGMSG STARTLINK
 PHS
 PHX ;modem port
 PHA ;baud rate
 PEA 0 ;HH?
 JSL Dvr8530Init
 PLA
 BNE :ERR
 LDA #terrOK
 CLC
 RTS
:ERR LDA #terrLINKERROR&terrmask
 SEC
 RTS

IPASCBUFF DS 15 ;255.255.255.255
 DS 2 ;dummy stuff

*-------------------------------------------------
* Script display routines
*-------------------------------------------------

SHOWPSTRING PHY
 TAX
 LDA >DISPLAYPTR+1
 ORA >DISPLAYPTR+1+1
 BEQ PLYRTL
 PEA ^*
 PHX
DISPLAYPTR JSL 0
PLYRTL PLY
 RTL

*-------------------------------------------------
* Variables
*-------------------------------------------------

VARIABLES DS lvlen

 SAV DC.CODE.L

 END
