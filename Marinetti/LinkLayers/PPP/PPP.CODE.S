 LST OFF
 REL
 mx 0

*=================================================
*
* PPP.CODE.S - Mainline code for standard PPP driver
*
* Copyright (C) 1997-2002 Richard Bennett
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
* 2002.02.22 RJB - Fixed exceptionally rare overrun condition. (See "WAS in")
* 2002.03.19 AJR - Added support for CHAP with MD5
* 2002.08.28 AJR - Patch to Set/Restore Data Bank Register during PPPSTARTUP
* 2002.09.09 AJR - Lock PPPDGMHANDLE during PPPCONNECT
* 2002.09.18 AJR - Handle LCPTerminateRequest and LCPTerminateAck
*                - Display LCP/IPCP code in SysFail for unsupported codes
* 2002.09.22 AJR - Resend CHAP response if no ACK/NAK received within CHAPTIMEINTERVAL
*                - Use CHAP tickle only if CHAP is possible
* 2002.11.10 AJR - Modified Debug output into format compatible with Text2Pcap
* 2003.07.23 AJR - Closed debug file on Disconnect & fixed output of CRLF
* 2005.03.28 AJR - Retrofit changes from PPPx.CODE 1.3d4 including:
*                - Split CHAP into new source code module for ease of maintenance
*                - Closed debug file on failed connection
*                - Return terrBADUSERPASS when CHAPRETRY count is reached.
* 2005.03.28 AJR - Retrofit changes from PPPx.CODE 1.3d6 including:
*                - Implement LCPTerminateRequest in PPPDisconnect
*                - Handle incoming escape sequences as per RFC [1171684]
*                - Improve debug output format for Ethereal
*
* NOTE REGARDING VERSION NUMBERS
*
* In order to change the version number, you need to change:
*
* 1. The rVersion resource in PPP.RES before building PPP.
* 2. The PPPVERSH and PPPVERSL equates in this file.
*
*=================================================

 USE 4/RJBUTIL.MACS
 USE 4/MEM.MACS
 USE 4/INT.MACS
 USE 4/MISC.MACS
 USE 4/CRYPTO.MACS
 USE 4/EVENT.MACS
 USE 4/HASHTOOL.MACS
 USE 4/LOCATOR.MACS
 USE ../../Equates/BUILD.EQU
 USE ../../Equates/I.EQU
 USE ../../Equates/TCPIP.EQU

MYLLVERSION = 2

LCPTIMEINTERVAL = 120 ;2 seconds - configuration response timouts
LCPRETRYCOUNT = 5
PAPTIMEINTERVAL = 180 ;3 seconds
PAPRETRYCOUNT = 5
CHAPTIMEINTERVAL = 180 ;3 seconds
CHAPRETRYCOUNT = 5
RESTARTTIMEINTERVAL = 180 ;3 seconds
IPCPTIMEINTERVAL = 120 ;2 seconds
IPCPRETRYCOUNT = 5

TICKLETIMEINTERVAL = 120 ;2 seconds

 DUM LLSPACE ;My direct space on Marinetti's direct page
PPPDGMHANDLE ADRL 0
PPPDGMPTR ADRL 0
USERNAMEPTR ADRL 0
PASSWORDPTR ADRL 0
MATCHPTR DA 0
MATCHLENM1 DA 0
CFGHANDLE ADRL 0
CFGPTR ADRL 0
TEMPDPPTR
TEMPDPHANDLE
DESDPHANDLE ADRL 0
 ERR *-1/$100 ;We can use $E0-$FF only
 DEND

 EXT DelayVBLs,NODPDEREF
 EXT Dvr8530ForceChar,Dvr8530CharsInBuffer,Dvr8530ReadChar
 EXT Dvr8530Init,Dvr8530Shutdown,Dvr8530CheckChar
 EXT Dvr8530FlushBuffer

pppdebug = 0
debugtodisk = 0 ;requires showtraffic on to work...

showtraffic = 0
showtodisk = 0

memcheck = 1 ;checks for handle overruns while building

* Set version to 1.3d6

PPPVERSH = $0130 ;MMMM_MMMM_mmmm_bbbb
PPPVERSL = $2006 ;sss0_0000_rrrr_rrrr ss-20=d,40=a,60=b,80=f,A0=r

*

WINDOWLEN = 50 ;Length of match window (must by multiple of 2)

PARMSTACK = 4
PARMSTACKB = 1+PARMSTACK

DBGPPP MAC
 do pppdebug
 JMP OK
 if ',]1
T1 STR ]1
 else
T1 STR ']1'
 fin
OK PHX
 PHY
 PHA
 do debugtodisk
 LDA #T1
 JSR DUMPLINE
 else
 PEA ^*
 PER T1
 _WriteLine
 fin
 PLA
 PLY
 PLX
 fin
 <<<

 do pppdebug
 USE 4/TEXT.MACS
 fin

* PPPINTERFACEV():interfaceV:integer;
* PPPSTARTUP():interfaceV:integer;
* PPPSHUTDOWN();
* PPPMODULEINFO():moduleNamePtr:longword;
* PPPGETPACKET():packetHandle:handle;
* PPPSENDPACKET(datagramPtr:longword,datagramLength:integer);
* PPPCONNECT(authMsgHandle,conMsgFlag,usernamePtr,passwordPtr,displayPtr,conHandle);
* PPPRECONSTATUS():reconStatus:boolean;
* PPPRECONNECT(displayPtr:longword);
* PPPDISCONNECT(conMsgFlag:integer,usernamePtr:longword,passwordPtr:longword,displayPtr:longword,disconHandle:handle);
* PPPGETVARIABLES():variablesPtr:longword
* PPPCONFIGURE(connectHandle,disconnectHandle);
* PPPCONFIGFNAME(configFileNamePtr:longword);

 EXT PPPCONFIGURE

*-------------------------------------------------
* Main entry point
*
* On Entry X=Call Number, Y=Marinetti UserID, A=Direct Page
*-------------------------------------------------

PPP DBGMSG PPPentry
 JMP (:ROUTINES,X)

:ROUTINES DA PPPINTERFACEV
 DA PPPSTARTUP
 DA PPPSHUTDOWN
 DA PPPMODULEINFO
 DA PPPGETPACKET
 DA PPPSENDPACKET
 DA PPPCONNECT
 DA PPPRECONSTATUS
 DA PPPRECONNECT
 DA PPPDISCONNECT
 DA PPPGETVARIABLES
 DA PPPCONFIGURE
 DA PPPCONFIGFNAME

*-------------------------------------------------
* PPPINTERFACEV():interfaceV:integer;
*-------------------------------------------------

PPPINTERFACEV DBGMSG PPPINTERFACEV():interfaceV:integer;
 LDA #MYLLVERSION
 STA PARMSTACK,S
 LDA #lvVer
 STA >VARIABLES+lvVersion
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* PPPSTARTUP()
*-------------------------------------------------

PPPSTARTUP DBGMSG PPPSTARTUP
 PHB
 PHK
 PLB
 STY MARINETTIUSERID
 LDA #true
 STA HASHFLAG ;Assume that Hashtool will be available
 STA CRYPTOFLAG ;Assume that Crypto tool will be available
 PEA #0
 _hashStatus
 PLA
 BNE :LOADED
 ~LoadOneTool #$80;#$102 ;Hashtool Version 1.02
 BCC :LOADED
 LDA #false
 STA HASHFLAG ;Hashtool is not available
 DBGPPP 'Tool128 Hashtool Not Started. No CHAP support.'
 BRA :DESNOTLOADED ;MS-CHAP requires Hashtool too
:LOADED _hashStartUp

 PEA #0
 _cryptoStatus
 PLA
 BNE :DESLOADED
 ~LoadOneTool #]cryptotoolnum;#100 ;Crypto tool Version 1
 BCS :DESNOTLOADED

:DESLOADED
 PHA ;Space for result
 PHA
 PEA $0000
 PEA $0100 ;We want 1 page for DP
 PHW MARINETTIUSERID
 PEA %1100_0000_0001_0001 ;Locked, Fixed, NotCross, Bank
 PEA $0000
 PEA $0000 ;Bank 0
 _NewHandle
 PLL DESDPHANDLE
 BCS :DESNOTLOADED
 DEREF DESDPHANDLE
 PHX ;Address in Bank 00 of DP Space
 _cryptoStartUp
 BCC :DESOK

:DESNOTLOADED LDA #false
 STA CRYPTOFLAG ;DES tool is not available
 DBGPPP 'Tool129 DES tool Not Started. No MS-CHAP support.'

:DESOK
 LDA #lvVer
 STA VARIABLES+lvVersion
 PLB
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* PPPSHUTDOWN()
*-------------------------------------------------

PPPSHUTDOWN DBGMSG PPPSHUTDOWN
 LDA >CRYPTOFLAG
 CMP #true
 BNE :HASH
 _cryptoShutDown
 PHL DESDPHANDLE
 _DisposeHandle
:HASH LDA >HASHFLAG
 BEQ :NOSHUTDOWN
 _hashShutDown
:NOSHUTDOWN LDA #lvVer
 STA >VARIABLES+lvVersion
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* PPPMODULEINFO(infoBlockPtr:longword);
*-------------------------------------------------

PPPMODULEINFO DBGMSG PPPMODULEINFO(infoBlockPtr:longword);
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

INFO DA conPPP
IS1 STR 'PPP'
 DS 21-*+IS1
PPPVERSION ENT
 DA PPPVERSL
 DA PPPVERSH
 DA %1000_0000_0000_0000
INFOL = *-INFO

*-------------------------------------------------
* PPPGETPACKET():packetHandle:handle;
*-------------------------------------------------

PPPGETPACKET DBGMSG PPPGETPACKET():packetHandle:handle;
 PHB
 PHK
 PLB
 STY >MARINETTIUSERID
 PHS 2+1
 JSL GETPACKET
 PLA
 CMP #0
 BEQL :NONE

 do showtraffic
 PHA
 LDA 3,S
 STA PPPDGMHANDLE
 LDA 3+2,S
 STA PPPDGMHANDLE+2
 LDA [PPPDGMHANDLE]
 STA PPPDGMPTR
 LDY #2
 LDA [PPPDGMHANDLE],Y
 STA PPPDGMPTR+2
 LDA 1,S
 TAX
 JSR DUMPDGMPTR
 PLA
 fin

 CMP #$0021 ;Internet protocol
 BEQL :IPOK
 CMP #$C021 ;LCP
 BNE :DUMP
 PHA
 LDA 3,S
 STA PPPDGMHANDLE
 LDA 3+2,S
 STA PPPDGMHANDLE+2
 LDA [PPPDGMHANDLE]
 STA PPPDGMPTR
 LDY #2
 LDA [PPPDGMHANDLE],Y
 STA PPPDGMPTR+2
 LDA 1,S
 TAX
 PLA
 LDA [PPPDGMPTR]
 AND #$FF
 CMP #5 ;LCPTerminateRequest
 BNE :DUMP
 DBGPPP PPPGet-TerminateReq
 JSR HANDLELCP
 _DisposeHandle
 LDA #0
 STA 5,S
 STA 5+2,S
 PLB
 DBGPPP PPPGet-ReturnERR
 LDA #terrNOLINKINTERFACE&terrmask
 SEC
 RTL
:DUMP _DisposeHandle
 BRA :NONEOUT
:IPOK PLA
 STA 7,S
 PLA
 STA 7,S
 PLB
 LDA #terrOK
 CLC
 RTL
:NONE PLS 2
:NONEOUT LDA #0
 STA 5,S
 STA 5+2,S
 PLB
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* PPPSENDPACKET(datagramPtr:longword,datagramLength:integer);
*-------------------------------------------------

PPPSENDPACKET DBGMSG PPPSENDPACKET(datagramPtr:longword,datagramLength:integer);
 PHB
 PHK
 PLB
 LDA #$0021
 JSR OPENPACKET
 PLB
 LDA PARMSTACK+2+2,S
 PHA
 LDA 2+PARMSTACK+2,S
 PHA
 LDA 2+2+PARMSTACK,S
 PHA
 JSL PPPWRITEPACKET
 JSL PPPCLOSEPACKET
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
* PPPWRITEPACKET(dataPtr:longword,dataLength:integer);
*-------------------------------------------------

 DUM 4
SENDPKTLEN DA 0
SENDPKTPTR ADRL 0
 DEND

PPPWRITEPACKET DBGMSG PPPWRITEPACKET(dataPtr:longword,dataLength:integer);
 TSC
 PHD
 TCD
 PHB
 PHK
 PLB
 LDA SENDPKTLEN
 BEQ :DONE
 LDY #0
:LOOP PHY
 LDA [SENDPKTPTR],Y
 JSR OUTCHARCRC
 PLY
 INY
 CPY SENDPKTLEN
 BCC :LOOP
:DONE PLB
 PLD
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
* PPPCLOSEPACKET();
*-------------------------------------------------

PPPCLOSEPACKET DBGMSG PPPCLOSEPACKET();

 do showtraffic
 PHB
 PHK
 PLB
 fin

 LDA >OUTPPPCRC
 EOR #$FF
 PHA
 do showtraffic
 JSR DUMPBYTE
 fin
 JSL Dvr8530ForceChar
 LDA >OUTPPPCRC+1
 EOR #$FF
 PHA
 do showtraffic
 JSR DUMPBYTE
 fin
 JSL Dvr8530ForceChar
 do showtraffic
 LDA #$7E
 PHA
 JSR DUMPBYTE
 LDA #outnull
 JSR DUMPLINE
 else
 PEA $7E
 fin
 JSL Dvr8530ForceChar
 do showtraffic
 PLB
 fin
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* PPPCONNECT(authMsgHandle,conMsgFlag,usernamePtr,passwordPtr,displayPtr,conHandle);
*-------------------------------------------------

PPPCONNECT DBGMSG PPPCONNECT
 PHB
 PHK
 PLB

 STY MARINETTIUSERID

 ~EMStatus
 PLW EMACTIVE

 LDA >$E100DC ;TickCount without Event Manager active
 STA IDENTIFIER ;for PPP packets

 LDA #false
 STA VARIABLES+lvConnected

 STZ VARIABLES+lvErrors
 STZ VARIABLES+lvIPaddress
 STZ VARIABLES+lvIPaddress+2

 LDA #1500
 STA VARIABLES+lvMTU

 LDA #LCPRETRYCOUNT+1
 STA LCPCOUNT
 LDA #IPCPRETRYCOUNT+1
 STA IPCPCOUNT
 LDA #PAPRETRYCOUNT+1
 STA PAPCOUNT
 LDA #CHAPRETRYCOUNT+1
 STA CHAPCOUNT

 LDA PARMSTACKB+18,S
 STA AUTHHANDLE
 LDA PARMSTACKB+18+2,s
 STA AUTHHANDLE+2

 LDA PARMSTACKB+8,S
 STA PASSWORDPTR
 LDA PARMSTACKB+8+2,S
 STA PASSWORDPTR+2
 LDA PARMSTACKB+12,S
 STA USERNAMEPTR
 LDA PARMSTACKB+12+2,S
 STA USERNAMEPTR+2

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
 JSL PtrToPtr

 LDA #LINKSTR
 JSL SHOWPSTRING

 JSR STARTLINK
 BCSL :ERR

 LDA #false ;turn PAP off by default
 STA PAPFLAG
 STA PAPDONE

% LDA #false ;turn CHAP off by default
 STA CHAPFLAG
 STA CHAPDONE
 STA CHAPRESPONSESENT

 LDA #true
 STA TICKLEFLAG ;turn it on by default

 JSR DIALISP
 BCCL :NEGOTIATE

:ERR1 PHA
 JSR HANGUPMODEM
 LDA #SHUTSTRING
 JSL SHOWPSTRING
 JSL Dvr8530Shutdown
 PLA

:OK EOR #0
 BNE :SKIPZ
 LDA #true
 STA VARIABLES+lvConnected
 LDA #terrOK
:SKIPZ

 do pppdebug
 PHA
 EOR #0
 BEQ :DBGOK
 DBGPPP '=== Connection failed ==='
 do showtraffic
 JSL $E100A8
 DA $2014
 ADRL CLOSE
 fin
 BRA :DBGJOIN
:DBGOK DBGPPP '=== Connected OK ==='
:DBGJOIN PLA
 fin

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

:ERRPL4 PLS 2
 LDA #terrLINKERROR&terrmask
 BRL :ERR1

:ERRPL4BADPW PLS 2
 LDA #terrBADUSERPASS&terrmask
 BRL :ERR1

:NEGSTR STR 'Negotiating PPP options'

:NEGOTIATE ;_GrafOff
 LDX #50
 JSR DELAY

 LDA #:NEGSTR
 JSL SHOWPSTRING

 DBGPPP '=== Starting connection negotiation 1.3d4 ==='

 STZ LCPHOSTOPEN ;0 = False
 STZ LCPMEOPEN
 STZ LCPDONE
 STZ LCPTERMINATE
 STZ IPCPHOSTOPEN
 STZ IPCPMEOPEN
 STZ IPCPDONE

 PHS 2
 JSL GETTICK
 PLXA LCPTIMER
 STXA PAPTIMER
 STXA CHAPTIMER
 STXA IPCPTIMER
 STXA TICKLETIMER

* Look for initial packet

 PHS 2+1
:RETRYINITIAL JSL GETPACKET
 LDA 3,S
 ORA 5,S
 BNEL :GOTPACKET

 LDA TICKLEFLAG ;Tickle link with a dummy PAP (see Oz Email)
 BEQL :SKIPTICKLE
 PHS 2
 JSL GETTICK
 LDA 1+2,S
 CMP TICKLETIMER+2
 BCC :NOTICKLEYET
 BNE :TICKLE
 LDA 1,S
 CMP TICKLETIMER
 BCC :NOTICKLEYET
:TICKLE
 LDA HASHFLAG
 BNE :CHAPTICKLE ;If Hashtool is available, then use CHAP

 LDA #$C023
 JSR OPENPACKET
 LDA #1
 JSR OUTCHARCRC ;Signon
 JSR UNIQUEIDENTIFIER
 JSR OUTCHARCRC ;Identifier
 LDA #0
 JSR OUTCHARCRC ;Length of packet
 LDA #6
 JSR OUTCHARCRC ;Length of packet
 LDA #0
 JSR OUTCHARCRC ;Dummy username
 LDA #0
 JSR OUTCHARCRC ;Dummy password
 JSL PPPCLOSEPACKET
 BRA :SKIPCHAPTICKLE

:CHAPTICKLE LDA #$C223
 JSR OPENPACKET
 LDA #2 ;CHAP Response
 JSR OUTCHARCRC ;Signon
 JSR UNIQUEIDENTIFIER
 JSR OUTCHARCRC ;Identifier
 LDA #0
 JSR OUTCHARCRC ;Length of packet
 LDA #1+1+2+1
 JSR OUTCHARCRC ;Length of packet
 LDA #0
 JSR OUTCHARCRC ;Value-Size
 JSL PPPCLOSEPACKET

:SKIPCHAPTICKLE
 LDA 1,S
 CLC
 ADC #TICKLETIMEINTERVAL
 STA TICKLETIMER
 LDA 1+2,S
 ADC #^TICKLETIMEINTERVAL
 STA TICKLETIMER+2
:NOTICKLEYET PLS 2
:SKIPTICKLE

 JSR CHECKABORT
 BCCL :RETRYINITIAL

:CANX PLS 2+1
 LDA #terrUSERABORTED&terrmask
 BRL :ERR1

* Main loop

:GETLOOP PHS 2+1
 JSL GETPACKET
 LDA 3,S
 ORA 5,S
 BNE :GOTPACKET
 JSR CHECKABORT
 BCS :CANX
 PLS 2+1
 JMP :CHECKTIMERS

* Got a packet, handle it

:GOTPACKET

 PLX
 PLL PPPDGMHANDLE
 LOCK PPPDGMHANDLE

 LDA [PPPDGMHANDLE] ;DEREF without using X
 STA PPPDGMPTR
 LDY #2
 LDA [PPPDGMHANDLE],Y
 STA PPPDGMPTR+2

 do showtraffic
 JSR DUMPDGMPTR
 fin

 CPX #$C021
 BEQ :LCP

 LDA LCPDONE ;Cannot handle other protocols until LCP done
 BEQ :GOTDONE

 CPX #$C023
 BEQ :PAP

 LDA PAPFLAG
 BEQ :SKIPPAP
 LDA PAPDONE ;Cannot handle other protocols until PAP done
 BEQ :GOTDONE
:SKIPPAP

 CPX #$C223
 BEQ :CHAP

 LDA CHAPFLAG
 BEQ :SKIPCHAP
 LDA CHAPDONE ;Cannot handle other protocols until CHAP done
 BEQ :GOTDONE
:SKIPCHAP

 CPX #$8021
 BEQ :IPCP

 JSR PROTOCOLREJECT

:GOTDONE PZL PPPDGMHANDLE
 _DisposeHandle

 JSR CHECKABORT
 BCC :CHECKTIMERS

 LDA #terrUSERABORTED&terrmask
 BRL :ERR1

:LCP JSR HANDLELCP
 BCSL :ERR1
 BRA :GOTDONE

:PAP LDA #false
 STA PAPDONE
 JSR HANDLEPAP
 BCSL :ERR1
 BRA :GOTDONE

:CHAP LDA HASHFLAG
 BEQ :CHAPERR1 ;If Hashtool is not available, CHAP not possible
 LDA CHAPTYPE
 CMP #$0500
 BEQ :CHAPOK
 LDA CRYPTOFLAG
% BEQL :ERR1
 BNE :CHAPOK ;If Crypto tool is not available, MSCHAP not possible
:CHAPERR1 JMP :ERR1

:CHAPOK LDA #false
 STA CHAPDONE
 JSR HANDLECHAP
 BCSL :ERR1
 BRA :GOTDONE

:IPCP JSR HANDLEIPCP
 BCSL :ERR1
 BRA :GOTDONE

* Check timers

:CHECKTIMERS

 LDA LCPMEOPEN
 BNEL :SKIPLCPCONFIG
 PHS 2
 JSL GETTICK
 LDA 1+2,S
 CMP LCPTIMER+2
 BCC :NOLCPYET
 BNE :SENDLCP
 LDA 1,S
 CMP LCPTIMER
 BCC :NOLCPYET
:SENDLCP DEC LCPCOUNT
 BEQL :ERRPL4
 DBGPPP SendingConfigureRequest
 LDA #$C021
 JSR OPENPACKET
 LDA #1
 JSR OUTCHARCRC ;Configure-Request
 JSR UNIQUEIDENTIFIER
 JSR OUTCHARCRC ;Identifier
 LDA #0
 JSR OUTCHARCRC ;Length of packet
 LDA #6
 JSR OUTCHARCRC ;Length of packet
 LDA #8
 JSR OUTCHARCRC ;Option: Address-and-Control-Field-Compression
 LDA #2
 JSR OUTCHARCRC ;Length of this option
 JSL PPPCLOSEPACKET
 LDA 1,S
 CLC
 ADC #LCPTIMEINTERVAL
 STA LCPTIMER
 LDA 1+2,S
 ADC #^LCPTIMEINTERVAL
 STA LCPTIMER+2
:NOLCPYET PLS 2
:SKIPLCPCONFIG

 LDA LCPTERMINATE
 BEQ :SKIPLCPTERMINATE

 PHS 2
 JSL GETTICK
 LDA 1+2,S
 CMP LCPTIMER+2
 BCC :NORESTARTTIMEYET
 BNE :GOERRPL4
 LDA 1,S
 CMP LCPTIMER
 BCC :NORESTARTTIMEYET
:GOERRPL4 DBGPPP "Terminate-Ack not received within Restart Time - Terminating"
 BRL :ERRPL4

:NORESTARTTIMEYET PLS 2

:SKIPLCPTERMINATE
 LDA LCPDONE ;Can't do the rest unless LCP is done
 BEQL :GETLOOP

 LDA PAPFLAG
 BEQL :SKIPPAPCONFIG
 LDA PAPDONE
 BNEL :SKIPPAPCONFIG

 PHS 2
 JSL GETTICK
 LDA 1+2,S
 CMP PAPTIMER+2
 BCCL :NOPAPYET
 BNE :SENDPAP
 LDA 1,S
 CMP PAPTIMER
 BCCL :NOPAPYET
:SENDPAP DEC PAPCOUNT
 BEQL :ERRPL4
 DBGPPP SendingPAPSignon
 LDA #$C023
 JSR OPENPACKET
 LDA #1
 JSR OUTCHARCRC ;Signon
 JSR UNIQUEIDENTIFIER
 JSR OUTCHARCRC ;Identifier
 LDA #0
 JSR OUTCHARCRC ;Length of packet
 SEP $20
 LDA [USERNAMEPTR]
 INC
 CLC
 ADC [PASSWORDPTR]
 INC
 ADC #4
 REP $20
 JSR OUTCHARCRC ;Length of packet

 LDA [USERNAMEPTR]
 AND #$FF
 TAX
 LDY #0
]L1 LDA [USERNAMEPTR],Y
 PHX
 PHY
 JSR OUTCHARCRC
 PLY
 PLX
 INY
 DEX
 BPL ]L1

 LDA [PASSWORDPTR]
 AND #$FF
 TAX
 LDY #0
]L1 LDA [PASSWORDPTR],Y
 PHX
 PHY
 JSR OUTCHARCRC
 PLY
 PLX
 INY
 DEX
 BPL ]L1

 JSL PPPCLOSEPACKET

 LDA 1,S
 CLC
 ADC #PAPTIMEINTERVAL
 STA PAPTIMER
 LDA 1+2,S
 ADC #^PAPTIMEINTERVAL
 STA PAPTIMER+2
:NOPAPYET PLS 2
:SKIPPAPCONFIG

 LDA PAPFLAG
 BEQ :SKIPPAPCHECK
 LDA PAPDONE ;Can't do the rest unless PAP is done
 BEQL :GETLOOP
:SKIPPAPCHECK

 LDA CHAPFLAG
 BEQ :SKIPCHAPCHECK
 LDA CHAPRESPONSESENT
 BEQ :CHECKCHAPDONE

 PHS 2
 JSL GETTICK
 LDA 1+2,S
 CMP CHAPTIMER+2
 BCC :PLSCHKCHAP
 BNE :SENDCHAP
 LDA 1,S
 CMP CHAPTIMER
 BCC :PLSCHKCHAP
:SENDCHAP DBGPPP "No CHAP ACK/NAK received within CHAPTIMEINTERVAL"
 DEC CHAPCOUNT
 BEQL :ERRPL4BADPW
 JSR SENDCHAPRESPONSE
:PLSCHKCHAP PLS 2
:CHECKCHAPDONE LDA CHAPDONE ;Can't do the rest unless CHAP is done
 BEQL :GETLOOP

:SKIPCHAPCHECK

* It is possible to get here without authentication having been performed.
* LCPDONE is set to TRUE after LCPConfigureACKs have been exchanged.
* Case 1: Authentication is optional
* Case 2: If host and client cannot agree on the authentication protocol
*    E.g. CHAP not available on client and host unwilling to use PAP (Win95)

 LDA IPCPMEOPEN
 BNEL :SKIPIPCPCONFIG
 PHS 2
 JSL GETTICK
 LDA 1+2,S
 CMP IPCPTIMER+2
 BCCL :NOIPCPYET
 BNE :SENDIPCP
 LDA 1,S
 CMP IPCPTIMER
 BCCL :NOIPCPYET
:SENDIPCP DEC IPCPCOUNT
 BEQL :ERRPL4
 DBGPPP SendingIPCPConfigureRequest
 LDA #$8021
 JSR OPENPACKET
 LDA #1
 JSR OUTCHARCRC ;Configure-Request
 JSR UNIQUEIDENTIFIER
 JSR OUTCHARCRC ;Identifier
 LDA #0
 JSR OUTCHARCRC ;Length of packet

 LDA VARIABLES+lvIPaddress
 ORA VARIABLES+lvIPaddress+2 ;got address yet?
 BNE :SKIPIP

 LDA #10
 JSR OUTCHARCRC ;Length of packet
 LDA #03
 JSR OUTCHARCRC ;Request for IP=03 06 00 00 00 00 (3=CMD,6=LEN)
 LDA #06
 JSR OUTCHARCRC
 LDA VARIABLES+lvIPaddress
 JSR OUTCHARCRC
 LDA VARIABLES+lvIPaddress+1
 JSR OUTCHARCRC
 LDA VARIABLES+lvIPaddress+2
 JSR OUTCHARCRC
 LDA VARIABLES+lvIPaddress+3
 JSR OUTCHARCRC

 INC IPCPCOUNT ;Asking for IP isn't a timeout, so bump it back

 BRA :JOINIP
:SKIPIP
 LDA #4
 JSR OUTCHARCRC ;Length of packet
:JOINIP
 JSL PPPCLOSEPACKET
 LDA 1,S
 CLC
 ADC #IPCPTIMEINTERVAL
 STA IPCPTIMER
 LDA 1+2,S
 ADC #^IPCPTIMEINTERVAL
 STA IPCPTIMER+2
:NOIPCPYET PLS 2
:SKIPIPCPCONFIG

 LDA IPCPDONE
 BEQL :GETLOOP

 LDA #terrOK
 BRL :OK

* Handles LCP state - X = C021

HANDLELCP LDA [PPPDGMPTR]
 AND #$FF
 DEC
 CMP #11
 BCC :DISPATCHLCP
 JSR CODEREJECT
 CLC
 RTS

:DISPATCHLCP ASL
 TAX
 JSR (:LCPTBL,X)
 CLC
 RTS

:LCPTBL DA :LCPCONFIGUREREQUEST
 DA :LCPCONFIGUREACK
 DA :LCPCONFIGURENAK
 DA :LCPCONFIGUREREJECT
 DA :LCPTERMINATEREQUEST
 DA :LCPTERMINATEACK
 DA :LCPCODEREJECT
 DA :LCPPROTOCOLREJECT
 DA :LCPECHOREQUEST
 DA :LCPECHOREPLY
 DA :LCPDISCARDREQUEST

:LCPCONFIGURENAK
:LCPCONFIGUREREJECT
 LSR ;undo previous modifications
 INC
 PHA ;save LCP code to display
 PHL #:noLCP
 _SysFailMgr
; brk 0
; DBGMSG unwrittenLCP
; brk 0
:noLCP STR 'Unsupported LCP code $'

:LCPTERMINATEACK DBGMSG :LCPTERMINATEACK
 DBGPPP :LCPTERMINATEACK
 LDA #false
 STA LCPMEOPEN
 PLA ;JSR from :DISPATCHLCP
 LDA #terrLINKERROR&terrmask
 SEC
 RTS

:LCPTERMINATEREQUEST DBGMSG :LCPTERMINATEREQUEST
 DBGPPP :LCPTERMINATEREQUEST-send-Terminate-Ack
 LDA LCPMEOPEN
 BEQL :RTSTERMREQ

 LDA #$C021
 JSR OPENPACKET
 LDA #6 ;Terminate-Ack
 JSR OUTCHARCRC
 LDY #1
 LDA [PPPDGMPTR],Y
 JSR OUTCHARCRC ;id
 LDY #2
 LDA [PPPDGMPTR],Y
 JSR OUTCHARCRC ;len
 LDY #3
 LDA [PPPDGMPTR],Y
 JSR OUTCHARCRC ;len
 LDY #2
 LDA [PPPDGMPTR],Y
 XBA
 SEC
 SBC #4
 BEQ :NODATA
 TAX
 LDY #0
]L1 LDA [PPPDGMPTR],Y
 PHY
 PHX
 JSR OUTCHARCRC
 PLX
 PLY
 INY
 DEX
 BNE ]L1
:NODATA JSL PPPCLOSEPACKET

 LDA #false
 STA LCPHOSTOPEN
 STA LCPDONE

 JSR SENDLCPTERMINATEREQUEST

:RTSTERMREQ RTS

:LCPCODEREJECT DBGMSG :LCPCODEREJECT ;I don't send bad codes!
:LCPECHOREPLY DBGMSG :LCPECHOREPLY ;I never sent one, so ignore this
:LCPDISCARDREQUEST DBGMSG :LCPDISCARDREQUEST ;data sink, purge and ignore
 RTS

:LCPPROTOCOLREJECT DBGMSG :LCPPROTOCOLREJECT ;I don't use bad protocols!
 DBGPPP :LCPPROTOCOLREJECT
 LDY #4
 LDA [PPPDGMPTR],Y
 XBA ;The rejected protocol
 CMP #$C023
 BEQ :NOPAPSUPPORT
 CMP #$C223
 BEQ :NOCHAPSUPPORT
 RTS
:NOPAPSUPPORT LDA #false
 STA PAPFLAG
 RTS
:NOCHAPSUPPORT LDA #false
 STA CHAPFLAG
 RTS

:LCPCONFIGUREACK DBGMSG :LCPCONFIGUREACK ;He's ACKing my Configure-Request
 DBGPPP :LCPCONFIGUREACK
 LDA #true
 STA LCPMEOPEN
 STA ADRCTLOUTFLAG
 JMP CHECKDONES

:LCPECHOREQUEST DBGMSG :LCPECHOREQUEST
 LDX #$C021
 JMP ECHOREPLY

:LCPCONFIGUREREQUEST DBGMSG :LCPCONFIGUREREQUEST
 DBGPPP :LCPCONFIGUREREQUEST
 STZ GOODOPTLENGTH ;Zero out option buffers
 STZ BADOPTLENGTH
 LDY #2
 LDA [PPPDGMPTR],Y
 XBA ;Packet length
 SEC
 SBC #4 ;Length of options
 BEQL :CHECKOPTIONS
 INY
 INY ;Point to first option
:TOPOPTLOOP PHA ;Remaining length on stack
 LDA [PPPDGMPTR],Y
 AND #$FF
 CMP #1 ;Maximum-Receive-Unit
 BEQL :OPT_MRU
 CMP #3 ;Authentication-Protocol
 BEQ :OPT_AP
 CMP #8 ;Address-and-Control-Field-Compression
 BEQL :OPT_ADRCTL
 JMP :OPTNAK

*

:OPT_AP INY
 INY
 LDA [PPPDGMPTR],Y

 INY
 PHA
 LDA [PPPDGMPTR],Y
 TAX ;X holds MD5 or MSCHAP algorithm code
 PLA
 DEY

 DEY
 DEY
 CMP #$23C0 ;$C023
 BNE :NOPAP
 LDA #true
 STA PAPFLAG
 DBGPPP opt:AP:PAP
 JMP :OPTACK
:NOPAP CMP #$23C2 ;$C223
 BNE :NOCHAP
 LDA HASHFLAG
 BEQ :NOCHAP ;If Hashtool is not available, CHAP not possible

 TXA
 AND #$FF00
 STA CHAPTYPE
 CMP #$0500 ;CHAP with MD5
 BEQ :GOTIT
 CMP #$8000 ;MS-CHAP v1
 BNE :NOCHAP
 LDX CRYPTOFLAG
 BEQ :NOCHAP ;If Crypto tool is not available, MSCHAP not possible
 DBGPPP opt:AP:MSCHAPv1

:GOTIT
 LDA #true
 STA CHAPFLAG
 DBGPPP opt:AP:CHAP
 BRA :OPTACK

:NOCHAP LDA #0
 STA CHAPTYPE
 DBGPPP opt:AP:?
 BRA :OPTNAK

:OPT_ADRCTL LDA #true
 STA ADRCTLINFLAG
 BRA :OPTACK

:OPT_MRU INY
 INY
 LDA [PPPDGMPTR],Y
 DEY
 DEY
 XBA
 STA VARIABLES+lvMTU
 BRA :OPTACK

*

:OPTNAK LDX BADOPTLENGTH
 LDA [PPPDGMPTR],Y
 STA BADOPTS,X
 INX
 INX
 INY
 INY
 XBA
 AND #$FF ;Length of option
 STA :OPTLEN
 DEC ;Decrement the type and length bytes so far...
 DEC
 BEQ :OPTNAKCOPIED
]L1 PHA
 LDA [PPPDGMPTR],Y
 STA BADOPTS,X
 INY
 INX
 PLA
 DEC
 BNE ]L1
:OPTNAKCOPIED STX BADOPTLENGTH
 BRA :NEXTOPT

:OPTACK LDX GOODOPTLENGTH
 LDA [PPPDGMPTR],Y
 STA GOODOPTS,X
 INX
 INX
 INY
 INY
 XBA
 AND #$FF ;Length of option
 STA :OPTLEN
 DEC ;Decrement the type and length bytes so far...
 DEC
 BEQ :OPTACKCOPIED
]L1 PHA
 LDA [PPPDGMPTR],Y
 STA GOODOPTS,X
 INY
 INX
 PLA
 DEC
 BNE ]L1
:OPTACKCOPIED STX GOODOPTLENGTH

:NEXTOPT PLA
 SEC
 SBC :OPTLEN
 BNEL :TOPOPTLOOP

:CHECKOPTIONS

 LDA BADOPTLENGTH ;Any bad options to reject?
 BEQL :MUSTBEGOOD
 DBGPPP badoptslcp-send-Configure-Reject
 DBGMSG BADOPTIONS
 LDA #$C021
 JSR OPENPACKET
 LDA #4 ;Configure-Reject
 JSR OUTCHARCRC
 LDY #1
 LDA [PPPDGMPTR],Y ;Get identifier
 JSR OUTCHARCRC
 LDA #0
 JSR OUTCHARCRC ;Length low
 LDA BADOPTLENGTH
 CLC
 ADC #4
 JSR OUTCHARCRC ;Length high
 LDX #0
]L1 LDA BADOPTS,X
 PHX
 JSR OUTCHARCRC
 PLX
 INX
 CPX BADOPTLENGTH
 BCC ]L1
 JSL PPPCLOSEPACKET
 RTS

:MUSTBEGOOD DBGMSG GOODOPTIONS
 LDA #$C021
 JSR OPENPACKET
 LDA #2
 JSR OUTCHARCRC ;Configure-Ack
 LDY #1
 LDA [PPPDGMPTR],Y ;Return what he used
 JSR OUTCHARCRC ;Identifier
 LDA #0
 JSR OUTCHARCRC ;Length of packet low
 LDA GOODOPTLENGTH
 CLC
 ADC #4
 JSR OUTCHARCRC ;Length high
 LDA GOODOPTLENGTH
 BEQ :SKIPGOPTS
 LDX #0
]L1 LDA GOODOPTS,X
 PHX
 JSR OUTCHARCRC
 PLX
 INX
 CPX GOODOPTLENGTH
 BCC ]L1
:SKIPGOPTS JSL PPPCLOSEPACKET
 LDA #true
 STA LCPHOSTOPEN
 JMP CHECKDONES

:OPTLEN DA 0

SENDLCPTERMINATEREQUEST
 DBGPPP ...and-Terminate-Request

 LDA #$C021
 JSR OPENPACKET
 LDA #5
 JSR OUTCHARCRC ;Terminate-Request
 JSR UNIQUEIDENTIFIER
 JSR OUTCHARCRC ;Identifier
 LDA #0
 JSR OUTCHARCRC ;Length of packet
 LDA #4
 JSR OUTCHARCRC ;Length of packet
 JSL PPPCLOSEPACKET

 DBGPPP "...Wait Restart-Time for Terminate-Ack"
 PHS 2
 JSL GETTICK
 PLA
 CLC
 ADC #RESTARTTIMEINTERVAL
 STA LCPTIMER
 PLA
 ADC #^RESTARTTIMEINTERVAL
 STA LCPTIMER+2
 LDA #true
 STA LCPTERMINATE
 RTS

*-------------------------------------------------
* Handles CHAP state - X = C223
*-------------------------------------------------

 PUT ../PPPx/PPPx.CHAP

*-------------------------------------------------
* Handles PAP state - X = C023
*-------------------------------------------------

HANDLEPAP LDA [PPPDGMPTR]
 AND #$FF
 DEC
 DEC
 BEQ :ACK ;2
 DEC
 BEQ :NAK
 CMP #2
 BEQ :ACK
:PAPRTS CLC
 RTS

:NAK LDA #terrBADUSERPASS&terrmask
 BRA :JOIN

:ACK LDA #true
 STA PAPDONE
 LDA #terrOK
:JOIN PHA
 LDY #2
 LDA [PPPDGMPTR],Y
% XBA
 BEQ :NOMSG
 INY
 INY
 LDA [PPPDGMPTR],Y
 AND #$FF ;Got message length
 BEQ :NOMSG
 TAY
 LDA PPPDGMPTR
 CLC
 ADC #5
 TAX
 LDA PPPDGMPTR+2
 PHA
 PHX ;from
 PHS 2 ;to
 PEA 0
 PHY ;length

 PEA 0
 PHY
 PHL AUTHHANDLE
 _SetHandleSize

 LXA AUTHHANDLE
 JSL NODPDEREF
 STA 5+2,S
 TXA
 STA 5,S
 JSL PtrToPtr

:NOMSG PLA
 CMP #1
 RTS

*-------------------------------------------------
* Handles IPCP state - X = 8021
*-------------------------------------------------

HANDLEIPCP LDA [PPPDGMPTR]
 AND #$FF
 DEC
 CMP #7
 BCC :DISPATCHIPCP
 JSR CODEREJECT
 CLC
 RTS

:DISPATCHIPCP ASL
 TAX
 JSR (:IPCPTBL,X)
 CLC
 RTS

:IPCPTBL DA :IPCPCONFIGUREREQUEST
 DA :IPCPCONFIGUREACK
 DA :IPCPCONFIGURENAK
 DA :IPCPCONFIGUREREJECT
 DA :IPCPTERMINATEREQUEST
 DA :IPCPTERMINATEACK
 DA :IPCPCODEREJECT

:IPCPCONFIGUREREJECT
 LSR ;undo previous modifications
 INC
 PHA ;save IPCP code to display
 PHL #:noIPCP
 _SysFailMgr
:noIPCP STR 'Unsupported IPCP code $'
; brk 0
; DBGMSG unwrittenIPCP
; brk 0

:IPCPTERMINATEACK DBGMSG :IPCPTERMINATEACK
 DBGPPP :IPCPTERMINATEACK
 LDA #false
 STA IPCPMEOPEN
 JMP CHECKDONES

:IPCPTERMINATEREQUEST DBGMSG :IPCPTERMINATEREQUEST
 DBGPPP :IPCPTERMINATEREQUEST-send-Terminate-Ack
 LDA IPCPMEOPEN
 BEQL :RTSTERMREQ

 LDA #$8021
 JSR OPENPACKET
 LDA #6 ;Terminate-Ack
 JSR OUTCHARCRC
 LDY #1
 LDA [PPPDGMPTR],Y
 JSR OUTCHARCRC ;id
 LDY #2
 LDA [PPPDGMPTR],Y
 JSR OUTCHARCRC ;len
 LDY #3
 LDA [PPPDGMPTR],Y
 JSR OUTCHARCRC ;len
 LDY #2
 LDA [PPPDGMPTR],Y
 XBA
 SEC
 SBC #4
 BEQ :NODATA
 TAX
 LDY #0
]L1 LDA [PPPDGMPTR],Y
 PHY
 PHX
 JSR OUTCHARCRC
 PLX
 PLY
 INY
 DEX
 BNE ]L1
:NODATA JSL PPPCLOSEPACKET

 LDA #false
 STA IPCPHOSTOPEN
 JSR CHECKDONES

 DBGPPP ...and-Terminate-Request

 LDA #$8021
 JSR OPENPACKET
 LDA #5
 JSR OUTCHARCRC ;Terminate-Request
 JSR UNIQUEIDENTIFIER
 JSR OUTCHARCRC ;Identifier
 LDA #0
 JSR OUTCHARCRC ;Length of packet
 LDA #4
 JSR OUTCHARCRC ;Length of packet
 JSL PPPCLOSEPACKET

:RTSTERMREQ RTS

:IPCPCONFIGURENAK DBGMSG :IPCPCONFIGURENAK ;He's NAKing my configure
 DBGPPP :IPCPCONFIGURENAK-check-for-IP-address-reply
 LDY #2
 LDA [PPPDGMPTR],Y ;Get length
 SEC
 SBC #4 ;Subtract code(1), id(1) and length(2)
 BEQ :RTSNAK
 INY
 INY
]L1 TAX
 LDA [PPPDGMPTR],Y
 CMP #$0603 ;03 06 xx xx xx xx
 BEQ :GETIPADDR
 XBA
 AND #$FF ;stick option length on stack
 PHA
 TYA ;bump datagram index by option length
 CLC
 ADC 1,S
 TAY
 TXA
 SEC
 SBC 1,S
 PLX
 EOR #0
 BNE ]L1
 RTS
:GETIPADDR INY
 INY
 LDA [PPPDGMPTR],Y
 STA VARIABLES+lvIPaddress
 INY
 INY
 LDA [PPPDGMPTR],Y
 STA VARIABLES+lvIPaddress+2
:RTSNAK RTS

:IPCPCODEREJECT DBGMSG :IPCPCODEREJECT ;I don't send bad codes!
 DBGPPP :IPCPCODEREJECT
 RTS

:IPCPCONFIGUREACK DBGMSG :IPCPCONFIGUREACK ;He's ACKing my Configure-Request
 DBGPPP :IPCPCONFIGUREACK
 LDA #true
 STA IPCPMEOPEN
 JMP CHECKDONES

:IPCPCONFIGUREREQUEST DBGMSG :IPCPCONFIGUREREQUEST
 DBGPPP :IPCPCONFIGUREREQUEST
 STZ GOODOPTLENGTH ;Zero out option buffers
 STZ BADOPTLENGTH
 LDY #2
 LDA [PPPDGMPTR],Y
 XBA ;Packet length
 SEC
 SBC #4 ;Length of options
 BEQL :CHECKOPTIONS
 INY
 INY ;Point to first option
:TOPOPTLOOP PHA ;Remaining length on stack

 LDA [PPPDGMPTR],Y
 AND #$FF
 CMP #3 ;IP-Address
 BEQ :OPT_IPADR
 BRA :OPTNAK

*

:OPT_IPADR DBGPPP opt:IP-ADDRESS
 BRA :OPTACK

*

:OPTNAK LDX BADOPTLENGTH
 LDA [PPPDGMPTR],Y
 STA BADOPTS,X
 INX
 INX
 INY
 INY
 XBA
 AND #$FF ;Length of option
 STA :OPTLEN
 DEC ;Decrement the type and length bytes so far...
 DEC
 BEQ :OPTNAKCOPIED
]L1 PHA
 LDA [PPPDGMPTR],Y
 STA BADOPTS,X
 INY
 INX
 PLA
 DEC
 BNE ]L1
:OPTNAKCOPIED STX BADOPTLENGTH
 BRA :NEXTOPT

:OPTACK LDX GOODOPTLENGTH
 LDA [PPPDGMPTR],Y
 STA GOODOPTS,X
 INX
 INX
 INY
 INY
 XBA
 AND #$FF ;Length of option
 STA :OPTLEN
 DEC ;Decrement the type and length bytes so far...
 DEC
 BEQ :OPTACKCOPIED
]L1 PHA
 LDA [PPPDGMPTR],Y
 STA GOODOPTS,X
 INY
 INX
 PLA
 DEC
 BNE ]L1
:OPTACKCOPIED STX GOODOPTLENGTH

:NEXTOPT PLA
 SEC
 SBC :OPTLEN
 BNEL :TOPOPTLOOP

:CHECKOPTIONS

 LDA BADOPTLENGTH ;Any bad options to reject?
 BEQL :MUSTBEGOOD
 DBGPPP badoptsipcp-send-Configure-Reject
 DBGMSG BADOPTIONS
 LDA #$8021
 JSR OPENPACKET
 LDA #4 ;Configure-Reject
 JSR OUTCHARCRC
 LDY #1
 LDA [PPPDGMPTR],Y ;Get identifier
 JSR OUTCHARCRC
 LDA #0
 JSR OUTCHARCRC ;Length low
 LDA BADOPTLENGTH
 CLC
 ADC #4
 JSR OUTCHARCRC ;Length high
 LDX #0
]L1 LDA BADOPTS,X
 PHX
 JSR OUTCHARCRC
 PLX
 INX
 CPX BADOPTLENGTH
 BCC ]L1
 JSL PPPCLOSEPACKET
 RTS

:MUSTBEGOOD DBGMSG GOODOPTIONS
 LDA #$8021
 JSR OPENPACKET
 LDA #2
 JSR OUTCHARCRC ;Configure-Ack
 LDY #1
 LDA [PPPDGMPTR],Y ;Return what he used
 JSR OUTCHARCRC ;Identifier
 LDA #0
 JSR OUTCHARCRC ;Length of packet low
 LDA GOODOPTLENGTH
 CLC
 ADC #4
 JSR OUTCHARCRC ;Length high
 LDA GOODOPTLENGTH
 BEQ :SKIPGOPTS
 LDX #0
]L1 LDA GOODOPTS,X
 PHX
 JSR OUTCHARCRC
 PLX
 INX
 CPX GOODOPTLENGTH
 BCC ]L1
:SKIPGOPTS JSL PPPCLOSEPACKET
 LDA #true
 STA IPCPHOSTOPEN
 JMP CHECKDONES

:OPTLEN DA 0

LINKSTR STR 'Starting serial port driver'

AUTHHANDLE ADRL 0

ADRCTLINFLAG DA false ;Address-and-Control-Field-Compression in
ADRCTLOUTFLAG DA false ;Address-and-Control-Field-Compression out

TICKLEFLAG DA true ;yes
TICKLETIMER ADRL 0

LCPHOSTOPEN DA 0
LCPMEOPEN DA 0
LCPDONE DA 0
LCPTERMINATE DA 0

PAPFLAG DA true
PAPDONE DA 0
HASHFLAG DA true
CHAPFLAG DA true
CHAPDONE DA 0
CHAPRESPONSESENT DA 0
CHAPTYPE DA 0 ;8000 for MSCHAP, 0500 for MD5
CRYPTOFLAG DA true

IPCPHOSTOPEN DA 0
IPCPMEOPEN DA 0
IPCPDONE DA 0

LCPTIMER ADRL 0
PAPTIMER ADRL 0
CHAPTIMER ADRL 0
IPCPTIMER ADRL 0

LCPCOUNT DA 0
PAPCOUNT DA 0
CHAPCOUNT DA 0
IPCPCOUNT DA 0

MDWORKAREA DS mdWorkBlkLen
MD5DIGEST DS MDDIGESTLEN

CHECKDONES LDA LCPHOSTOPEN
 BEQ :SKIPLCP
 LDA LCPMEOPEN
 BEQ :SKIPLCP
 LDA #true
 STA LCPDONE
:SKIPLCP
 LDA IPCPHOSTOPEN
 BEQ :SKIPIPCP
 LDA IPCPMEOPEN
 BEQ :SKIPIPCP
 LDA #true
 STA IPCPDONE
:SKIPIPCP
 RTS

*-------------------------------------------------
* PPPRECONSTATUS():reconStatus:boolean;
*-------------------------------------------------

PPPRECONSTATUS DBGMSG PPPRECONSTATUS():reconStatus:boolean;
 LDA #false
 STA PARMSTACK,S
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* PPPRECONNECT(displayPtr:longword);
*-------------------------------------------------

PPPRECONNECT DBGMSG PPPRECONNECT(displayPtr:longword);
 PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 LDA #terrNORECONSUPPRT&terrmask
 SEC
 RTL

*-------------------------------------------------
* PPPDISCONNECT(conMsgFlag:integer,usernamePtr:longword,passwordPtr:longword,displayPtr:longword,disconHandle:handle);
*-------------------------------------------------

PPPDISCONNECT DBGMSG PPPDISCONNECT
 PHB
 PHK
 PLB
*=================================================
 JSR SENDLCPTERMINATEREQUEST

 DBGPPP PPPDisc-afterSend

* Main loop to receive TerminateAck

:GETLOOP PHS 2+1
 JSL GETPACKET
 LDA 3,S
 ORA 5,S
 BNE :GOTPACKET
 JSR CHECKABORT
 BCSL :CANX
 PLS 2+1
 JMP :CHECKTIMERS

* Got a packet, handle it

:GOTPACKET
 DBGPPP PPPDisc-gotpacket

 PLX
 PLL PPPDGMHANDLE
 LOCK PPPDGMHANDLE

 LDA [PPPDGMHANDLE]
 STA PPPDGMPTR
 LDY #2
 LDA [PPPDGMHANDLE],Y
 STA PPPDGMPTR+2

 do showtraffic
 JSR DUMPDGMPTR
 fin

 CPX #$C021 ;LCP? if not, dump it
 BEQ :LCP

:GOTDONE DBGPPP PPPDisc-gotdone
 PZL PPPDGMHANDLE
 _DisposeHandle

 JSR CHECKABORT
 BCC :CHECKTIMERS

 LDA #terrUSERABORTED&terrmask
 BRL :ERR

:LCP DBGPPP PPPDisc-LCP
 JSR HANDLELCP
 BCC :GOTDONE
 JMP :GotTermAck

*-------------------------------------------------
* Check timers

:CHECKTIMERS
 DBGPPP PPPDisc-checktimers
 PHS 2
 JSL GETTICK
 LDA 1+2,S
 CMP LCPTIMER+2
 BCC :NORESTARTTIMEYET
 BNE :GOERRPL4
 LDA 1,S
 CMP LCPTIMER
 BCC :NORESTARTTIMEYET
:GOERRPL4 DBGPPP "Terminate-Ack not received within Restart Time - Terminating"
 BRL :ERRPL4

:NORESTARTTIMEYET PLS 2
 DBGPPP PPPDisc-norestart

 JMP :GETLOOP

:CANX DBGPPP PPPDisc-canx
 PLS 2+1
 LDA #terrUSERABORTED&terrmask
 BRL :ERR

:ERRPL4 DBGPPP PPPDisc-errpl4
 PLS 2
 LDA #terrLINKERROR&terrmask
 BRL :ERR

:GotTermAck
 DBGPPP PPPDisc-GotTermAck
*=================================================

* ~EMStatus ;Add this if I ever add user aborts in disconnect
* PLW EMACTIVE
 JSR HANGUPMODEM

 do showtraffic
 JSL $E100A8
 DA $2014
 ADRL CLOSE
 fin

 LDA #SHUTSTRING
 JSL SHOWPSTRING
 JSL Dvr8530Shutdown
 LDA #false
 STA VARIABLES+lvConnected
 LDA #terrOK
:ERR TAX
 PLA
 STA 17,S
 PLA
 STA 17,S
 PLS 7
 TXA
 PLB
 CMP #1
 RTL

SHUTSTRING STR 'Shutdown serial port'

*-------------------------------------------------
* PPPGETVARIABLES():variablesPtr:longword
*-------------------------------------------------

PPPGETVARIABLES DBGMSG PPPGETVARIABLES
 LDA #VARIABLES
 STA PARMSTACK,S
 LDA #^VARIABLES
 STA PARMSTACK+2,S
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* PPPCONFIGFNAME(configFileNamePtr:longword);
*-------------------------------------------------

PPPCONFIGFNAME DBGMSG PPPCONFIGFNAME(configFileNamePtr:longword);
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

:CONFIGFNAME STR 'PPP.config'

*-------------------------------------------------
* Internal: STARTLINK - Must be called with CONFIGURATION valid
*-------------------------------------------------

STARTLINK DBGMSG STARTLINK
 PHS
 PHW CONFIGURATION+CFGPORT
 PHW CONFIGURATION+CFGBAUD
 PEA 0 ;HH?
 JSL Dvr8530Init
 PLA
 BNE :ERR
 LDA #0
 CLC
 RTS
:ERR LDA #terrLINKERROR&terrmask
 SEC
 RTS

*-------------------------------------------------
* Internal: GETPACKET
*-------------------------------------------------

MARINETTIUSERID DA 0

GETPACKET DBGMSG GETPACKET ; GETPACKET():pkt:handle,protocol:integer

:TOPLOOP LDX #0

:SCANLOOP PHX

 PHS
 PHX
 JSL Dvr8530CheckChar
 PLA

 PLX
 BCSL :CHECKTEXT ;No packets, check for NO CARRIER

 CMP #$7E
 BEQ :BUILDONE
 INX
 BPL :SCANLOOP

 LDX #0 ;off end of buffer. Ping of death? slurp one

:BUILDONE CPX #0
 BNE :BUILDOK
 PHS
 JSL Dvr8530ReadChar

 PLA
 BRA :TOPLOOP

:BUILDOK PHS 2
 PEA 0

 do memcheck
 TXA
 STA >handleLength
 fin

 PHX
 PHW MARINETTIUSERID
 PEA $0018 ;no bank cross, no special
 PEA 0
 PEA 0
 _NewHandle
 PLXA PPPDGMHANDLE
 DEREF PPPDGMHANDLE;PPPDGMPTR

 LDA #4 ;Start with 4, to remove header as well
 STA :CHOPSIZE

 LDY #0
:BUILDLOOP PHY
 PHS
 JSL Dvr8530ReadChar
 PLA
 BCSL :OVERRUN
 CMP #$7E
 BEQ :ENDPKT
 CMP #$7D
 BNE :STUFFIT
 PHS
 JSL Dvr8530ReadChar
 PLA
 CMP #$7E
 BEQL :ABORTFRAME
 EOR #$20 ;5E->7E, 5D->7D etc
 INC :CHOPSIZE
:STUFFIT PLY
 SEP $20
 STA [PPPDGMPTR],Y
 REP $20
 do memcheck
 TYA
 CMP >handleLength
 BCC :memOK
 PHA
 PHL #memCheckFail
 _SysFailMgr
:memOK
 fin

 INY
 BRA :BUILDLOOP

:ENDPKT PLX

 CPX #3 ;Need checksum (2 bytes) + address (1) at least
 BCCL :TOOSMALL

;X=packet length

* Got packet. Is it valid?

% LDA [PPPDGMHANDLE]
% STA PPPDGMPTR
% LDY #2
% LDA [PPPDGMHANDLE],Y
% STA PPPDGMPTR+2

 LDA ADRCTLINFLAG ;If FF 03 is compressed, it's a real packet
 BNEL :GOTPPP

 LDA [PPPDGMPTR]
 CMP #$03FF ;Is it a valid PPP packet?
 BEQL :GOTPPP

:NOPPPID
 do pppdebug
 DBGPPP "GETPACKET :NOPPPID"
 BRA :PURGITERATE
 fin
:BADCRC
 do pppdebug
 DBGPPP "GETPACKET :BADCRC"
 BRA :PURGITERATE
 fin
:ABORTFRAME
 do pppdebug
 DBGPPP "GETPACKET :ABORTFRAME"
 BRA :PURGITERATE
 fin
:TOOSMALL
 do pppdebug
 DBGPPP "GETPACKET :TOOSMALL"
 fin
:PURGITERATE
 do pppdebug
 DBGPPP "GETPACKET :PURGITERATE - Purging this packet:"
 LDY #0
]L1 LDA [PPPDGMPTR],Y ;Get the protocol (eg. C023, C021, 8021)
 INY
 INY
 CMP #$03FF
 BEQ ]L1
 XBA
 TAX
 JSR DUMPDGMPTR
 fin
 PZL PPPDGMHANDLE
 _DisposeHandle
 do pppdebug
 DBGPPP "GETPACKET :PURGITERATE - Packet purged"
 fin
 JMP :TOPLOOP


:OVERRUN PLS ;Packet WAS in buffer, but is now gone.
 do pppdebug
 DBGPPP "GETPACKET :OVERRUN"
 fin
 JMP :PURGITERATE ;possible buffer full with last character
;being the packet end.

:GOTPPP

* Check checksum - see RFC 1662 - u16 pppfcs16(fcs,cp,len)

 DEX
 DEX
 PHX ;X is packet length (less 2 byte checksum)

 LDY #0
 LDA #$FFFF
]L1 PHX ;X is packet length
 PHA
 LDA [PPPDGMPTR],Y
% AND #$FF
 EOR 1,S
 AND #$FF
 ASL
 TAX
 LDA PPPCRC,X
 PHA
 LDA 3+1,S
 AND #$FF
 EOR 1,S
 PLX
 PLX
 INY
 PLX
 DEX
 BNE ]L1
 EOR #$FFFF

 PLY
 CMP [PPPDGMPTR],Y ;Is it the same checksum
 BNEL :BADCRC

* Return it.

 LDY #0
]L1 LDA [PPPDGMPTR],Y ;Get the protocol (eg. C023, C021, 8021)
 INY
 INY
 CMP #$03FF
 BEQ ]L1
 XBA
 STA 4,S

 LDY #8 ; Ready for chopping size
 LDA [PPPDGMHANDLE],Y
 SEC
 SBC :CHOPSIZE
 TAX
 INY
 INY
 LDA [PPPDGMHANDLE],Y
 SBC #0
 PHXA
 PZL PPPDGMHANDLE

* It's OK to assume address/control MAY be compressed, as it was tested above.

 LDA [PPPDGMPTR]
 CMP #$03FF
 BEQ :SHIFT4
 LDA #2 ;Strip leading protocol (eg. C023)
 BRA :SHIFT
:SHIFT4 LDA #4 ;Strip leading FF 03 and protocol (eg. C023)
:SHIFT
 CLC
 ADC [PPPDGMHANDLE] ; Shift packet back by 4
 TAX
 LDY #2
 LDA [PPPDGMHANDLE],Y
 TAY
 ADC #0
 PHA
 PHX
 PHY
 LDA [PPPDGMHANDLE]
 PHA
 LDA 15,S
 PHA
 LDA 15,S
 PHA
 JSL PtrToPtr ;Shift it

 _SetHandleSize ;...and set the new size.

 LDX PPPDGMHANDLE
 LDA PPPDGMHANDLE+2
 BRA :OUT

* No packets.

:NONE LDX #0
 TXA
 STA 4,S

:OUT STA 6+2,S
 TXA
 STA 6,S

 RTL

:CHECKTEXT LDX #0

:MATCHLOOP LDY #0

:MATCHNEXT PHX
 PHY

 PHS
 PHX
 JSL Dvr8530CheckChar
 PLA

 PLY
 PLX

 BCS :NONE

 CMP #$7E
 BEQL :TOPLOOP ;Now there is a packet!

 SEP $20
 AND #$7F
 CMP :NOCARRIERASC,Y
 REP $20
 BEQ :MATCH
 INX
 BNE :MATCHLOOP
 BRA :NONE

:MATCH INX
 BEQ :NONE
 INY
 CPY #9
 BCC :MATCHNEXT

* Got NO CARRIER

 LDA #false
 STA VARIABLES+lvConnected
 JSL Dvr8530FlushBuffer
 BRA :NONE

:NOCARRIERASC ASC 'NO CARRIER'

:CHOPSIZE DA 0

 do memcheck
handleLength DA 0
memCheckFail STR 'Marinetti PPP trampled on memory $'
 fin

*-------------------------------------------------
* PPP CRC tables
*-------------------------------------------------

PPPCRC DA $0000,$1189,$2312,$329b,$4624,$57ad,$6536,$74bf
 DA $8c48,$9dc1,$af5a,$bed3,$ca6c,$dbe5,$e97e,$f8f7
 DA $1081,$0108,$3393,$221a,$56a5,$472c,$75b7,$643e
 DA $9cc9,$8d40,$bfdb,$ae52,$daed,$cb64,$f9ff,$e876
 DA $2102,$308b,$0210,$1399,$6726,$76af,$4434,$55bd
 DA $ad4a,$bcc3,$8e58,$9fd1,$eb6e,$fae7,$c87c,$d9f5
 DA $3183,$200a,$1291,$0318,$77a7,$662e,$54b5,$453c
 DA $bdcb,$ac42,$9ed9,$8f50,$fbef,$ea66,$d8fd,$c974
 DA $4204,$538d,$6116,$709f,$0420,$15a9,$2732,$36bb
 DA $ce4c,$dfc5,$ed5e,$fcd7,$8868,$99e1,$ab7a,$baf3
 DA $5285,$430c,$7197,$601e,$14a1,$0528,$37b3,$263a
 DA $decd,$cf44,$fddf,$ec56,$98e9,$8960,$bbfb,$aa72
 DA $6306,$728f,$4014,$519d,$2522,$34ab,$0630,$17b9
 DA $ef4e,$fec7,$cc5c,$ddd5,$a96a,$b8e3,$8a78,$9bf1
 DA $7387,$620e,$5095,$411c,$35a3,$242a,$16b1,$0738
 DA $ffcf,$ee46,$dcdd,$cd54,$b9eb,$a862,$9af9,$8b70
 DA $8408,$9581,$a71a,$b693,$c22c,$d3a5,$e13e,$f0b7
 DA $0840,$19c9,$2b52,$3adb,$4e64,$5fed,$6d76,$7cff
 DA $9489,$8500,$b79b,$a612,$d2ad,$c324,$f1bf,$e036
 DA $18c1,$0948,$3bd3,$2a5a,$5ee5,$4f6c,$7df7,$6c7e
 DA $a50a,$b483,$8618,$9791,$e32e,$f2a7,$c03c,$d1b5
 DA $2942,$38cb,$0a50,$1bd9,$6f66,$7eef,$4c74,$5dfd
 DA $b58b,$a402,$9699,$8710,$f3af,$e226,$d0bd,$c134
 DA $39c3,$284a,$1ad1,$0b58,$7fe7,$6e6e,$5cf5,$4d7c
 DA $c60c,$d785,$e51e,$f497,$8028,$91a1,$a33a,$b2b3
 DA $4a44,$5bcd,$6956,$78df,$0c60,$1de9,$2f72,$3efb
 DA $d68d,$c704,$f59f,$e416,$90a9,$8120,$b3bb,$a232
 DA $5ac5,$4b4c,$79d7,$685e,$1ce1,$0d68,$3ff3,$2e7a
 DA $e70e,$f687,$c41c,$d595,$a12a,$b0a3,$8238,$93b1
 DA $6b46,$7acf,$4854,$59dd,$2d62,$3ceb,$0e70,$1ff9
 DA $f78f,$e606,$d49d,$c514,$b1ab,$a022,$92b9,$8330
 DA $7bc7,$6a4e,$58d5,$495c,$3de3,$2c6a,$1ef1,$0f78

*-------------------------------------------------
* Internal: UNIQUEIDENTIFIER
*-------------------------------------------------

UNIQUEIDENTIFIER INC IDENTIFIER
 LDA IDENTIFIER
 RTS

IDENTIFIER DA 0 ;Like unique ID for IP

*-------------------------------------------------
* TIMEDCMD
*-------------------------------------------------

TIMEDCMD STA :MOD+1
:TOP SEC
:LOOP PHP
 SEP $20
 LDA >$E0C019
 REP $20
 BPL :NOCHANGE
 PLP
 CLC
 PHP
:NOCHANGE PHX
:MOD JSR MATCH?
 BCC :GOTIT
 PLX
 PLP
 BCS :LOOP
 PHP
 SEP $20
 LDA >$E0C019
 REP $20
 BMI :NOCHANGE
 DEX
 BEQ :TIMEOUT
 BPL :BACK
 LDX #$FFFF
:BACK PLP
 JSR CHECKABORT
 BCC :TOP
 LDA #terrUSERABORTED&terrmask
 SEC
 RTS
:GOTIT PLX
 PLP
 CLC
 RTS
:TIMEOUT PLP
 LDA #terrNOLINKRESPONSE
 SEC
 RTS

MATCH? PHA
 JSL Dvr8530CharsInBuffer
 PLA
 BEQ :SECRTS
 PHA
 JSL Dvr8530ReadChar
 PLY
 SEP $30
 LDX #0
]L1 LDA WINDOW+1,X
 STA WINDOW,X
 INX
 CPX MATCHLENM1
 BCC ]L1
 TYA
 AND #$7F
 STA WINDOW,X
 TXY
]L1 LDA WINDOW,Y
 CMP (MATCHPTR),Y
 BNE :NOMATCH
 DEY
 BPL ]L1
 REP $30
 CLC
 RTS
:NOMATCH REP $30
:SECRTS SEC
 RTS

WINDOW DS WINDOWLEN

MATCHCONNECT PHA ;"CONNECT", "BUSY", "NO DIALTONE"
 JSL Dvr8530CharsInBuffer
 PLA
 BEQ :SECRTS
 PHA
 JSL Dvr8530ReadChar
 PLY
 SEP $30
 LDX #0
]L1 LDA WINDOW+1,X
 STA WINDOW,X
 INX
 CPX #11-1
 BCC ]L1
 TYA
 AND #$7F
 STA WINDOW+10
 REP $30
 LDA WINDOW+9
 CMP #'CT'
 BEQ :CONNECT?
 CMP #'SY'
 BEQ :BUSY
 CMP #'NE'
 BEQ :NODIALTONE?
:SECRTS SEC
 RTS
:CONNECT? LDA WINDOW+7
 CMP #'NE'
 BNE :SECRTS
 LDA #0
 CLC
 RTS
:BUSY LDA #1
 CLC
 RTS
:NODIALTONE? LDA WINDOW+7
 CMP #'TO'
 BNE :SECRTS
 LDA #2
 CLC
 RTS

CHECKABORT DBGMSG CHECKABORT
 PHX
 PHY
 LDA EMACTIVE
 BEQ :HARDWARE
 ~GetNextEvent #%0000_0000_0010_1000;#:EVENTRECORD
 PLA
 BEQ :NO
 LDA :EVENTRECORD+ERECWHAT
 CMP #EVENTKEYDOWN
 BEQ :CHECKEVT
 CMP #EVENTAUTOKEY
 BNE :NO
:CHECKEVT LDA :EVENTRECORD+ERECMESSAGE
 AND #$7F
 CMP #$1B
 BEQ :ABORT
 CMP #'.'
 BNE :NO
 LDA :EVENTRECORD+ERECMODIFIERS
 AND #%0000_0001_0000_0000
 BEQ :NO
 BRA :ABORT
:HARDWARE SEP $20
 LDA >$E0C000
 BPL :NO
 CMP #$9B
 BEQ :ABORT
 CMP #"."
 BNE :NO
 LDA >$E0C025
 BPL :NO
:ABORT REP $20
 PLY
 PLX
 SEC
 RTS
:NO REP $20
 PLY
 PLX
 CLC
 RTS

:EVENTRECORD DS 16

EMACTIVE DA 0

GETTICK DBGMSG GETTICK
 PHP
 SEI
 LDA >$E100DC
 STA 5,S
 LDA >$E100DC+2
 STA 5+2,S
 PLP
 RTL

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

* IN:  longword  FROM
*      longword  TO
*      longword  LENGTH

PtrToPtr ENT
 DBGMSG PtrToPtr
 TSC
 PHD
 TCD

 LDA 4+2
 BEQ :LESS64K

:ABOVE64K LDY #0
:BANKLOOP LDA [12],Y
 STA [8],Y
 INY
 INY
 BNE :BANKLOOP
 INC 12+2
 INC 8+2
 DEC 4+2
 BNE :BANKLOOP

:LESS64K LDA 4
 BEQ :DONE ;None
 DEC
 BEQ :ONEBYTE
 DEC
 BEQ :TWOBYTES

* A straight copy loop of two bytes in 8 bit mode is 2 cycles slower than
* this MVN routine! But just to add speed, the custom branches above make
* things even faster!

 LDA #0 ;Make sure both blocks are inside banks
 CLC
 SBC 4
 CMP 8
 BCC :BYTES
 CMP 12
 BCC :BYTES
 LDA 12+2 ;To bank
 XBA
 ORA 8+2 ;From bank
 STA >:MOD+1
 LDX 12
 LDY 8
 LDA 4
 DEC
 PHB
:MOD MVN 0,0
 PLB
 BRA :DONE

:BYTES

 SEP $20 ;Have to do bytes, because it cross banks!
 LDY #0
:COPYLOOP LDA [12],Y
 STA [8],Y
 INY
 CPY 4
 BNE :COPYLOOP
 REP $20
 BRA :DONE

:TWOBYTES LDA [12]
 STA [8]
 BRA :DONE

:ONEBYTE SEP $20
 LDA [12]
 STA [8]
 REP $20

:DONE PLD
 PHB
 PLA
 STA 11,S
 PLA
 STA 11,S
 PLS 4
 PLB
 RTL


*-------------------------------------------------
* Internal PPP output routines - require DBK to be set correctly
*-------------------------------------------------

OPENPACKET PHA ;starts a packet of protocol in A (eg. $C021)
 XBA
 PHA
 LDA #$FFFF
 STA OUTPPPCRC

 do showtraffic
 LDA #outheaderout
 JSR DUMPLINE

 LDA #outtimestamp
 JSR DUMPSTRING
 fin

 PEA $7E
 JSL Dvr8530ForceChar

 LDA 1,S
 CMP #$21C0 ;Illegal to compress LCP (C021) packets
 BEQ :FORCEADRCTL
 LDA >ADRCTLOUTFLAG ;Am I allowed to compress?
 BNE :SKIPADRCTL ;Yes.
:FORCEADRCTL LDA #$FF
 JSR OUTCHARCRC
 LDA #$03
 JSR OUTCHARCRC
:SKIPADRCTL

 PLA
 JSR OUTCHARCRC
 PLA
 JSR OUTCHARCRC
 RTS

OUTCHARCRC JSR ADDTOCRC

 do showtraffic
 JSR DUMPBYTE
 fin

 AND #$FF
 CMP #$7E
 BEQ :7D5E
 CMP #$7D
 BEQ :7D5D
 CMP #$20
 BCS :STUFFIT
 PHA
 PEA $7D
 JSL Dvr8530ForceChar
 PLA
 EOR #$20
:STUFFIT PHA
 JSL Dvr8530ForceChar
 RTS
:7D5E PEA $7D
 JSL Dvr8530ForceChar
 LDA #$5E
 BRA :STUFFIT
:7D5D PEA $7D
 JSL Dvr8530ForceChar
 LDA #$5D
 BRA :STUFFIT

OUTPPPCRC DA 0

ADDTOCRC PHA
% AND #$FF
 EOR OUTPPPCRC
 AND #$FF
 ASL
 TAX
 LDA PPPCRC,X
 PHA
 LDA OUTPPPCRC+1
 AND #$FF
 EOR 1,S
 STA OUTPPPCRC
 PLX
 PLA
 RTS

*-------------------------------------------------
* Internal PPP negotiation code - assumed DBK and DP
*-------------------------------------------------

* Protocol-Reject - X = protocol, PPPDGMHANDLE = handle, PPPDGMPTR = ptr

PROTOCOLREJECT DBGMSG PROTOCOLREJECT ;Rejects unknown protocol packets (X=protocol)
 DBGPPP PROTOCOLREJECT
 LDA LCPMEOPEN ;Is my connection open?
 BEQ :SILENTDISCARD
 PHX ;The reject protocol
 LDA #$C021 ;LCP protocol
 JSR OPENPACKET
 LDA #$08
 JSR OUTCHARCRC ;Protocol-Reject
 JSR UNIQUEIDENTIFIER
 JSR OUTCHARCRC ;Identifier
 LDY #8
 LDA [PPPDGMHANDLE],Y ;Get length of incoming data
 DEC
 DEC ;less the checksum
 CLC
 ADC #5 ;plus Code(1),Identifier(1),Length(2),RejProt(2)
 PHA
 XBA
 JSR OUTCHARCRC
 PLA
 JSR OUTCHARCRC
 LDA 1+1,S ;The rejected protol
 JSR OUTCHARCRC
 PLA
 JSR OUTCHARCRC
 LDY #8 ;Send the rejected packet, less checksum
 LDA [PPPDGMHANDLE],Y
 DEC
 DEC
 TAX
 LDY #0
]L1 LDA [PPPDGMPTR],Y
 PHY
 PHX
 JSR OUTCHARCRC
 PLX
 PLY
 INY
 DEX
 BNE ]L1
 JSL PPPCLOSEPACKET
:SILENTDISCARD RTS

* Code-Reject - X = protocol, PPPDGMHANDLE = handle, PPPDGMPTR = ptr

CODEREJECT DBGMSG CODEREJECT ;Rejects unknown code packets (X=protocol)
 DBGPPP CODEREJECT
; LDA LCPMEOPEN ;Is my connection open?
; BEQ :SILENTDISCARD
 TXA ;The protocol
 JSR OPENPACKET
 LDA #$07
 JSR OUTCHARCRC ;Code-Reject
 JSR UNIQUEIDENTIFIER
 JSR OUTCHARCRC ;Identifier
 LDY #8
 LDA [PPPDGMHANDLE],Y ;Get length of incoming data
 DEC
 DEC ;less the checksum
 CLC
 ADC #3 ;plus Code(1),Identifier(1),Length(2)
 PHA
 XBA
 JSR OUTCHARCRC
 PLA
 JSR OUTCHARCRC
 LDY #8 ;Send the rejected packet, less checksum
 LDA [PPPDGMHANDLE],Y
 DEC
 DEC
 TAX
 LDY #0
]L1 LDA [PPPDGMPTR],Y
 PHY
 PHX
 JSR OUTCHARCRC
 PLX
 PLY
 INY
 DEX
 BNE ]L1
 JSL PPPCLOSEPACKET
:SILENTDISCARD RTS

* Echo-Reply - X = protocol, PPPDGMHANDLE = handle, PPPDGMPTR = ptr

ECHOREPLY DBGMSG ECHOREPLY
 DBGPPP ECHOREPLY
 LDA LCPMEOPEN ;Is my connection open?
 BEQ :SILENTDISCARD
 TXA ;protocol
 JSR OPENPACKET
 LDA #10
 JSR OUTCHARCRC ;Echo-Reply
 LDY #1
 LDA [PPPDGMPTR],Y ;Return what he used
 JSR OUTCHARCRC ;Identifier
 LDA #0
 JSR OUTCHARCRC ;Length of packet
 LDA #8
 JSR OUTCHARCRC ;Length of packet
 LDY #4 ;Return the Magic-Number
 LDA [PPPDGMPTR],Y
 JSR OUTCHARCRC
 LDY #5
 LDA [PPPDGMPTR],Y
 JSR OUTCHARCRC
 LDY #6
 LDA [PPPDGMPTR],Y
 JSR OUTCHARCRC
 LDY #7
 LDA [PPPDGMPTR],Y
 JSR OUTCHARCRC
 JSL PPPCLOSEPACKET
:SILENTDISCARD RTS

*-------------------------------------------------
* Buffers
*-------------------------------------------------

GOODOPTLENGTH DA 0
BADOPTLENGTH DA 0

GOODOPTS DS 256
BADOPTS DS 256

*-------------------------------------------------
* Variables
*-------------------------------------------------

VARIABLES DS lvlen

*-------------------------------------------------
* Debug stuff
*-------------------------------------------------
 do showtraffic

DUMPDGMPTR phx

 phx
 phl #outheaderin+6
 pea 4
 _Int2Hex

 LDA #outheaderin
 JSR DUMPLINE

 LDA #outtimestamp
 JSR DUMPSTRING

 LDA 1,S ;output high byte of protocol into packet
 XBA
 PHA
 phl #outbyte+1
 pea 2
 _Int2Hex

 LDA #outbyte
 JSR DUMPSTRING

 LDA 1,S ;output lo byte of protocol into packet
 PHA
 phl #outbyte+1
 pea 2
 _Int2Hex

 LDA #outbyte
 JSR DUMPSTRING

 lda #0
]l1 tay
 lda [pppdgmptr],y
 phy

 pha
 phl #outbyte+1
 pea 2
 _Int2Hex

 LDA #outbyte
 JSR DUMPSTRING

 ply
 iny

 tya
 ldy #8
 cmp [pppdgmhandle],y
 bcc ]l1

 LDA #outnull
 JSR DUMPLINE

 plx

 rts

outheaderin str 'in = xxxx'
outheaderout str 'out:'
outtimestamp str ' 00000000 '
outbyte str 'xx '
outnull dfb 0

DUMPBYTE

 pha
 pha
 phl #outbyte+1
 pea 2
 _Int2Hex
 LDA #outbyte
 JSR DUMPSTRING
 pla
 rts

DUMPLINE
 do showtodisk

 JSR DUMPSTRING
 LDA #:CRSTR
 JSR DUMPSTRING
 JSL $E100A8
 DA $2015
 ADRL FLUSH
 RTS
:CRSTR DFB 1,13

 else

 pea ^*
 pha
 _WriteLine
 rts

 fin

DUMPSTRING
 do showtodisk

 STA :MOD+1
 INC
 STA :ADDRESS
:MOD LDA: 0
 AND #$FF
 STA :LENGTH
 JSL $E100A8
 DA $2001
 ADRL :CREATE
 JSL $E100A8
 DA $2010
 ADRL :OPEN
 BCS :SKIPREFS
 LDA :OPEN+2
 STA :WRITE+2
 STA FLUSH+2
 STA CLOSE+2
:SKIPREFS JSL $E100A8
 DA $2013
 ADRL :WRITE
:DONE RTS

:CREATE DA 4
 ADRL :PATHNAME
 DA $C3,4
 ADRL 0

:WRITE DA 4,0
:ADDRESS ADRL *
:LENGTH ADRL 0,0

:OPEN DA 3,0
 ADRL :PATHNAME
 DA %11

:PATHNAME STRL ':RAM5:PPP.trace'

FLUSH DA 1,0
CLOSE DA 1,0

 else

 pea ^*
 pha
 _WriteString
 rts

 fin

 fin

*-------------------------------------------------
* DIALISP
*
* Dial and manual connect
*-------------------------------------------------

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

CONFIGURATION DS CFGLEN

DIALISP DBGMSG DIALISP

 PEA $0D
 JSL Dvr8530ForceChar

 LDX #60
 JSR DELAY

 LDA CONFIGURATION+CFGINIT
 AND #$FF
 BEQ :NOINIT

 PHA

 LDA #:MINITSTR
 JSL SHOWPSTRING

 LDX #0
:TOPLOOP LDA CONFIGURATION+CFGINIT+1,X
 AND #$7F
 CMP #'R'-$40
 BEQ :CTRLR
 PHX
 PHA
 JSL Dvr8530ForceChar
 JSR WAIT1VBL
 PLX
 INX
 LDA 1,S
 DEC
 STA 1,S
 BNE :TOPLOOP
 BRA :SENDIT
:CTRLR INX
 LDA 1,S
 DEC
 STA 1,S

:SENDIT PHX

 PEA $0D
 JSL Dvr8530ForceChar

 LDA #:OKASC
 STA MATCHPTR
 LDA #2-1
 STA MATCHLENM1
 LDX #5*60 ;5 seconds
 LDA #MATCH?
 JSR TIMEDCMD
 BCS :ERRPL2
 LDX #30
 JSR DELAY
 PLX
 LDA 1,S ;Any chars left?
 BNE :TOPLOOP
 PLS

:NOINIT

 LDA #:DIALSTR
 JSL SHOWPSTRING

 LXA #:ATDT
 JSR SENDPSTRDELAY

 LXA #CONFIGURATION+CFGDIAL
 JSR SENDPSTRDELAY

 JSL Dvr8530FlushBuffer

 PEA $0D
 JSL Dvr8530ForceChar

 LDX #60*60*1 ;1 minute
 LDA #MATCHCONNECT
 JSR TIMEDCMD

 CMP #1
 BEQ :BUSY
 CMP #2
 BEQ :NODIALTONE
;Must be normal error code
:OUT CMP #1
 RTS

:ERRPL2 PLX
 PLX
 BRA :OUT

:BUSY LDA #terrLINKBUSY
 BRA :OUT

:NODIALTONE LDA #terrNOLINKINTERFACE
 BRA :OUT

:ATDT STR 'ATDT'

:OKASC ASC 'OK'

:MINITSTR STR 'Initialising modem'
:DIALSTR STR 'Dialing...'

SENDPSTRDELAY PHD
 PHXA
 TSC
 TCD
 SEP $30
 LDY #0
]L1 TYA
 CMP [1]
 BEQ :SENDOK
 INY
 LDA [1],Y
 PHY
 REP $30
 AND #$7F
 PHA
 JSL Dvr8530ForceChar
 JSR WAIT1VBL
 SEP $30
 PLY
 BRA ]L1
:SENDOK REP $30
 PLXA
 PLD
 RTS

*-------------------------------------------------
* DELAY - X = VBL count
*-------------------------------------------------

WAIT1VBL LDX #1
DELAY SEP $20
]L1 LDA >$E0C019
 BPL *-4
 LDA >$E0C019
 BMI *-4
 DEX
 BNE ]L1
 REP $20
 RTS

*-------------------------------------------------
* HANGUPMODEM
*-------------------------------------------------

HANGUPMODEM LDA #:HANGSTR
 JSL SHOWPSTRING
 LDX #60*3
 JSR DELAY
 LXA #:PLUS3
 JSR SENDPSTRDELAY
 LDX #60
 JSR DELAY
 LXA #:ATH
 JMP SENDPSTRDELAY

:HANGSTR STR 'Hanging up modem'
:PLUS3 STR '+++'
:ATH STR 'ATH',0D

 SAV PPP.CODE.L

 END
