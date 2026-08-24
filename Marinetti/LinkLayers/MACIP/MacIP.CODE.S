 LST OFF
*=================================================
*
* MACIP.CODE.S - MacIP link layer module
*
* Copyright (C) 1998-2003 Richard Bennett
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
* 2002.03.29 RJBF - Initial release as open source
* 2002.10.17 AJR  - Add debug dump to disk
* 2003.07.23 AJR  - Bumped version number
*
*=================================================
 REL
 mx 0

 USE 4/RJBUTIL.MACS
 USE 4/MEM.MACS
 USE 4/INT.MACS
 USE 4/CTL.MACS
 USE 4/WINDOW.MACS
 USE 4/EVENT.MACS
 USE 4/TCPIP.MACS
 USE ../../EQUATES/BUILD.EQU
 USE ../../EQUATES/I.EQU
 USE ../../EQUATES/TCPIP.EQU

MYLLINTVERS = 2

macipdebug = 0
debugtodisk = 0 ;requires showtraffic on to work...

showtraffic = 0
showtodisk = 0

* Set version to 1.2

MacIPVERSH = $0120 ;MMMM_MMMM_mmmm_bbbb
MacIPVERSL = $A000 ;sss0_0000_rrrr_rrrr ss-20=d,40=a,60=b,80=f,A0=r

~SetPort MAC
 PHL ]1
_SetPort MAC
 Tool $1B04
 <<<
~GetPort MAC
 PHS 2
_GetPort MAC
 Tool $1C04
 <<<
~VersionString MAC
 PHW ]1
 PxL ]2;]3
_VersionString MAC
 LDX #$3903
 JSL $E10000
 <<<

*

 DUM LLSPACE ;My direct space on Marinetti's direct page
MACIPTMPHANDLE ADRL 0
MACIPTMPTR ADRL 0
WINDPTR ADRL 0
MACIPQHANDLE ADRL 0
MACIPQPTR ADRL 0
MACIPAUTHMSGHANDLE ADRL 0
 DEND

MacIP DBGMSG MacIP
 JMP (ROUTINES,X)

mcVersion = 3

DEFAULTmc ORG 0
 DA mcVersion ;Version of data
mcLOCALIP DFB 0,0,0,0
mcGATEWAYIP DFB 0,0,0,0
mcLOCALAUTO DA 0 ;no
mcGATEWAYAUTO DA 1 ;yes
mclen
 ORG

CONNECTDATA DS mclen

PARMSTACK = 4
PARMSTACKB = 1+PARMSTACK

DBGMACIP MAC
 do macipdebug
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

 do macipdebug
 USE 4/TEXT.MACS
 fin

* MacIPInterfaceV():interfaceV:integer;
* MacIPStartup():interfaceV:integer;
* MacIPShutdown();
* MacIPModuleInfo(infoBlockPtr:longword);
* MacIPGetDatagram():datagramHandle:handle;
* MacIPSendDatagram(datagramPtr:longword,datagramLength:integer);
* MacIPConnect(conMsgFlag:integer,usernamePtr:longword,passwordPtr:longword,displayPtr:longword,conHandle:handle);
* MacIPReconStatus():reconStatus:boolean;
* MacIPReconnect(displayPtr:longword);
* MacIPDisconnect(conMsgFlag:integer,usernamePtr:longword,passwordPtr:longword,displayPtr:longword,disconHandle:handle);
* MacIPGetVariables():variablesPtr:longword
* MacIPConfigure(connectHandle,disconnectHandle);
* MacIPConfigFName(configFileNamePtr:longword);

*-------------------------------------------------
* Dispatch table
*-------------------------------------------------

ROUTINES DA MacIPInterfaceV
 DA MacIPStartup
 DA MacIPShutdown
 DA MacIPModuleInfo
 DA MacIPGetDatagram
 DA MacIPSendDatagram
 DA MacIPConnect
 DA MacIPReconstatus
 DA MacIPReconnect
 DA MacIPDisconnect
 DA MacIPGetVariables
 DA MacIPConfigure
 DA MacIPConfigFName

*-------------------------------------------------
* Variables and stuff
*-------------------------------------------------

USERID DA 0

GATEWAYATLKADDR ADR 0

*-------------------------------------------------
* MacIPInterfaceV():interfaceV:integer;
*-------------------------------------------------

MacIPInterfaceV DBGMSG MacIPInterfaceV():interfaceV:integer;
 LDA #MYLLINTVERS
 STA PARMSTACK,S

*-------------------------------------------------
* MacIPStartup():interfaceV:integer;
* MacIPShutdown()
*-------------------------------------------------

MacIPStartup DBGMSG MacIPStartup
MacIPShutdown DBGMSG MacIPShutdown
 LDA #lvVer
 STA >VARIABLES+lvVersion
 LDA #terrOK
 CLC
 RTL

*-------------------------------------------------
* MacIPModuleInfo(infoBlockPtr:longword);
*-------------------------------------------------

MacIPModuleInfo DBGMSG MacIPModuleInfo(infoBlockPtr:longword);
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

INFO DA conMacIP
NAME STR 'MacIP'
 DS 21-*+NAME
 DA MacIPVERSL
 DA MacIPVERSH
 DA %0000_0000_0000_0001
INFOL = *-INFO

*-------------------------------------------------
* MacIPGetDatagram():datagramHandle:handle;
*-------------------------------------------------

MacIPGetDatagram DBGMSG MacIPGetDatagram

 PHB
 PHK
 PLB
*
 PHS 2
 PHL DATAGRAMQUEUE
 JSL GETNEXTINQUEUE

 do showtraffic
 LDA 1,S
 EOR 3,S
 BEQ :NONE

 LDA 1,S
 STA MACIPTMPHANDLE
 LDA 3,S
 STA MACIPTMPHANDLE+2
 LDA [MACIPTMPHANDLE]
 STA MACIPTMPTR
 LDY #2
 LDA [MACIPTMPHANDLE],Y
 STA MACIPTMPTR+2
 JSR DUMPDGMPTR
:NONE
 fin

 PLA
 STA 7,S
 PLA
 STA 7,S
*
 PLB
 CLC
 RTL

*-------------------------------------------------
* MacIPSendDatagram(datagramPtr:longword,datagramLength:integer);
*-------------------------------------------------

 do showtraffic
 DUM 4
SENDPKTLEN DA 0
SENDPKTPTR ADRL 0
 DEND
 fin

MacIPSendDatagram DBGMSG MacIPSendDatagram
 do showtraffic
 TSC
 PHD
 TCD
 PHB
 PHK
 PLB

 LDA #outheaderout
 JSR DUMPLINE

 LDA #outtimestamp
 JSR DUMPSTRING

 LDA SENDPKTLEN
 BEQ :DONE
 LDY #0
:LOOP PHY
 LDA [SENDPKTPTR],Y
 JSR DUMPBYTE
 PLY
 INY
 CPY SENDPKTLEN
 BCC :LOOP

:DONE LDA #outnull
 JSR DUMPLINE
 PLB
 PLD
 fin

 PHB
 PHK
 PLB
*
 LDA 7,S
 STA sndBuffAddr
 LDA 7+2,S
 STA sndBuffAddr+2
 LDA 5,S
 STA sndLen

 LDA GATEWAYATLKADDR
 STA sndNet
 LDA GATEWAYATLKADDR+1
 STA sndNet+1

 LDX #SENDDATAGRAM
 LDY #^SENDDATAGRAM
 JSL $E11014
*
 PLA
 STA 5,S
 PLA
 STA 5,S
 PLA
 PLB
 LDA #$0000
 CLC
 RTL

* Parms

SENDDATAGRAM DFB 0 ;Sync
 DFB $0D ;SendDatagram
SENDDGMRESULT DA 0 ;Result code
 DFB 0 ;Checksum Flag
sndNet DS 2 ;Destination network
sndNode DS 1 ;Destination node
 DFB 72 ;Destination skt (IP=72)
 DFB 72 ;Source skt (IP=72)
 DFB 22 ;DDP type (IP=22)
 ADRL BDS

BDS DS 6 ;Reserved
sndLen DA 0
sndBuffAddr ADRL 0
 DA -1 ;End of BDS Flag

*-------------------------------------------------
* MacIPConnect(authMsgHandle:handle,
*              conMsgFlag:integer,
*              usernamePtr:longword,
*              passwordPtr:longword,
*              displayPtr:longword,
*              conHandle:handle);
*-------------------------------------------------

MacIPConnect DBGMSG MacIPConnect

 PHB
 PHK
 PLB

 STY USERID

 LDA #586
 STA VARIABLES+lvMTU

* Set up display routine

 LDA 21,S ;connect messages?
 BNE :YESCON
 STZ DISPLAYPTR+1
 STZ DISPLAYPTR+1+1
 BRA :CONJOIN

:YESCON LDA 9,S
 STA DISPLAYPTR+1
 LDA 9+1,S
 STA DISPLAYPTR+1+1

:CONJOIN

 LDA #:INITSTR
 JSR SHOWPSTRING

* Copy out auth message handle

 LDA 23,S
 STA MACIPAUTHMSGHANDLE
 LDA 23+2,S
 STA MACIPAUTHMSGHANDLE+2

* Copy in connect data

 LDA 5,S ;Connect handle
 STA MACIPTMPHANDLE
 LDA 5+2,S
 STA MACIPTMPHANDLE+2
 DEREF MACIPTMPHANDLE;MACIPTMPTR
 LDA [MACIPTMPTR]
 CMP #mcVersion ;version?
 BNE :SKIPVERS
 PZL MACIPTMPHANDLE
 PHL #CONNECTDATA
 PHL #mclen
 _HandToPtr
:SKIPVERS

* Make a new queue for datagrams

 PHA
 PHA
 JSL NEWQUEUE
 PLL DATAGRAMQUEUE

* Zero listen handle

 STZ LISTENHANDLE+2

* Open AppleTalk socket

 LDA #:OPENSTR
 JSR SHOWPSTRING

 LDX #OPENSOCKET
 LDY #^OPENSOCKET
 JSL $E11014
 BCC :OPENOK

 PHS 2
 PHW OPENSKTRESULT
 _HexIt
 PLL OPENAUTHERR
 LDA #OPENAUTHMSG
 LDX #OPENAUTHMSGL
 JSR MAKEAUTHMSG
 BRL :LINKERROR

:OPENOK

* Register my name as xxx.xxx.xxx.xxx:IPADDRESS:*

 LDA #:REGISTERSTR
 JSR SHOWPSTRING

 PHA
 PHL CONNECTDATA+mcLOCALIP
 PHL #ENTITYNAME
 PEA 0
 _TCPIPConvertIPToASCII
 PLA
 SEC
 ADC #ENTITYNAME
 JSR MOVEINREGNAME

 LDX #REGISTER
 LDY #^REGISTER
 JSL $E11014 ; RegisterName
 BCC :REGISTEROK

 PHS 2
 PHW REGISTERRESULT
 _HexIt
 PLL REGAUTHERR
 LDA #REGAUTHMSG
 LDX #REGAUTHMSGL
 JSR MAKEAUTHMSG
 BRL :LINKCLOSEERROR

:REGISTEROK

* OK, now look for gateway

 LDA #:GATEWAYSTR
 JSR SHOWPSTRING

 LDA CONNECTDATA+mcGATEWAYAUTO ;Get one automatically?
 BNE :AUTOGATEWAY

* Look for specific gateway

 PHA
 PHL CONNECTDATA+mcGATEWAYIP
 PHL #GATEWAYIPNAME
 PEA 0
 _TCPIPConvertIPToASCII
 PLA
 SEC
 ADC #GATEWAYIPNAME
 JSR MOVEINREGNAME
 LDX #LOOKUPGATEWAYBYIP
 LDY #^LOOKUPGATEWAYBYIP
 JSL $E11014
 BCS :GATEERR

 LDA IPMATCHCNT ;OK, see if we found it
 BRA :CHECKMATCH

:GATEERR LDA LOOKUPGWBYIPRESULT ;Any network errors?

:GATEWAYERROR PHS 2
 PHA ;With error code
 _HexIt
 PLL GWAUTHERR
 LDA #GWAUTHMSG
 LDX #GWAUTHMSGL
 JSR MAKEAUTHMSG
 BRA :LINKCLOSEUNREGERROR

:GATEWAYERROR1 LDA #GW1AUTHMSG ;Just couldn't find it
 LDX #GW1AUTHMSGL
 JSR MAKEAUTHMSG
 BRA :LINKCLOSEUNREGERROR

:AUTOGATEWAY LDX #LOOKUPGATEWAYBYNAME
 LDY #^LOOKUPGATEWAYBYNAME
 JSL $E11014
 BCC :GOMATCH

 LDA LOOKUPGWBYNAMERESULT
 BRA :GATEWAYERROR

:GOMATCH LDA NAMEMATCHCNT

:CHECKMATCH AND #$FF
 BEQ :GATEWAYERROR1

 LDA LOOKBUFF
 STA GATEWAYATLKADDR
 LDA LOOKBUFF+1
 STA GATEWAYATLKADDR+1

 LDA #$8000
 STA VARIABLES+lvConnected

 LDA CONNECTDATA+mcLOCALIP
 STA VARIABLES+lvIPaddress
 LDA CONNECTDATA+mcLOCALIP+2
 STA VARIABLES+lvIPaddress+2

 LDA #0
:ERR TAX

 PLA
 STA 21,S
 PLA
 STA 21,S
 PLA
 PLA
 PLA
 PLA
 PLA
 PLA
 PLA
 PLA
 PLA
 PLB
 TXA
 CMP #1
 RTL

:LINKCLOSEUNREGERROR LDA #UNREGSTR
 JSR SHOWPSTRING
 LDX #UNREGISTER
 LDY #^UNREGISTER
 JSL $E11014 ; RemoveName
:LINKCLOSEERROR LDA #CLOSESTR
 JSR SHOWPSTRING
 LDX #CLOSESOCKET
 LDY #^CLOSESOCKET
 JSL $E11014
:LINKERROR LDA #terrLINKERROR&terrmask
 BRA :ERR

:INITSTR STR 'Initialising (sic) variables'
:OPENSTR STR 'Opening AppleTalk socket'
:REGISTERSTR STR 'Registering named IP address'
:GATEWAYSTR STR 'Looking for IP gateway'

OPENSOCKET DFB 0,$B
OPENSKTRESULT DA 0
 DFB 72
 ADRL LISTEN

REGISTER DFB 0,$E
REGISTERRESULT DA 0
 ADRL 0
 ADRL NAMESTRUCT
 DFB 2,8 ;retry count, retry interval
 DS 2 ;reserved
 DFB 72,0

UNREGISTER DFB 0,$F
UNREGRESULT DA 0
 ADRL ENTITYNAME

NAMESTRUCT DS 9 ;reserved
ENTITYNAME DS 1+15+1+9+1+1

LOOKUPGATEWAYBYIP DFB 0,$10 ;LookupName
LOOKUPGWBYIPRESULT DA 0
 ADRL 0
 ADRL GATEWAYIPNAME
 DFB 3,4
 DS 2
 DA 40 ;Buffer length
 ADRL LOOKBUFF
 DFB 1 ;max number of matches requested
IPMATCHCNT DS 1 ;actual number of matched

GATEWAYIPNAME DS 1+15+1+9+1+1

LOOKUPGATEWAYBYNAME DFB 0,$10 ;LookupName
LOOKUPGWBYNAMERESULT DA 0
 ADRL 0
 ADRL GATEWAYNAME
 DFB 3,4
 DS 2
 DA 40 ;Buffer length
 ADRL LOOKBUFF
 DFB 1
NAMEMATCHCNT DS 1

GATEWAYNAME STR '='
 STR 'IPGATEWAY'
 STR '*'

LOOKBUFF DS 40

DATAGRAMQUEUE ADRL 0

* Appends IPADDRESS:* to location in A

MOVEINREGNAME TAY
 LDX #:APPENDSTRS
 LDA #12-1
 PHB
 MVN :APPENDSTRS,*
 PLB
 RTS

:APPENDSTRS STR 'IPADDRESS'
 STR '*'

SHOWPSTRING TAX
 LDA >DISPLAYPTR+1
 ORA >DISPLAYPTR+1+1
 BEQ SHOWRTS
 PEA ^*
 PHX
DISPLAYPTR JSL 0
SHOWRTS RTS

MAKEAUTHMSG DBGMSG MAKEAUTHMSG
 PEA ^* ;from ptr
 PHA
 PHL MACIPAUTHMSGHANDLE ;to handle
 PEA 0
 PHX ;length
 PEA 0 ;resize first
 PHX
 PHL MACIPAUTHMSGHANDLE
 _SetHandleSize
 _PtrToHand ;Copy it in
 RTS

OPENAUTHMSG ASC 'Received an error $'
OPENAUTHERR ASC 'xxxx trying to open an internet gateway AppleTalk socket.'
OPENAUTHMSGL = *-OPENAUTHMSG

REGAUTHMSG ASC 'Received an error $'
REGAUTHERR ASC 'xxxx trying to register IP address name with AppleTalk '
 ASC 'network.'
REGAUTHMSGL = *-REGAUTHMSG

GWAUTHMSG ASC 'Received an error $'
GWAUTHERR ASC 'xxxx trying to find internet gateway.'
GWAUTHMSGL = *-GWAUTHMSG

GW1AUTHMSG ASC 'Could not find an internet gateway on the network.'
GW1AUTHMSGL = *-GW1AUTHMSG

*-------------------------------------------------
* MacIPReconStatus():reconStatus:boolean;
*-------------------------------------------------

MacIPReconStatus DBGMSG MacIPReconStatus
 LDA #false
 STA PARMSTACK,S
 CLC
 RTL

*-------------------------------------------------
* MacIPReconnect(displayPtr:longword);
*-------------------------------------------------

MacIPReconnect DBGMSG MacIPReconnect
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
* MacIPDisconnect(conMsgFlag:integer,usernamePtr:longword,passwordPtr:longword,displayPtr:longword,disconHandle:handle);
*-------------------------------------------------

MacIPDisconnect DBGMSG MacIPDisconnect

 PHB
 PHK
 PLB

* Set up display routine

 LDA 21,S ;connect messages?
 BNE :YESCON
 STZ DISPLAYPTR+1
 STZ DISPLAYPTR+1+1
 BRA :CONJOIN

:YESCON LDA 9,S
 STA DISPLAYPTR+1
 LDA 9+1,S
 STA DISPLAYPTR+1+1

:CONJOIN

*

 LDA #UNREGSTR
 JSR SHOWPSTRING

 LDX #UNREGISTER
 LDY #^UNREGISTER
 JSL $E11014 ; RemoveName
 BCC :UNREGOK

 LDA UNREGRESULT
 BRA :ERR

:UNREGOK

 LDA #CLOSESTR
 JSR SHOWPSTRING

 LDX #CLOSESOCKET
 LDY #^CLOSESOCKET
 JSL $E11014
 BCC :CLOSEOK

 LDA CLOSESKTRESULT
 BRA :ERR
:CLOSEOK

 LDA #CLEANSTR
 JSR SHOWPSTRING

 PHL DATAGRAMQUEUE
 JSL DESTROYQUEUE

 STZ VARIABLES+lvConnected
 STZ VARIABLES+lvIPaddress
 STZ VARIABLES+lvIPaddress+2

 LDA LISTENHANDLE+2
 BEQ :SKIPDISPOSE
 PHL LISTENHANDLE
 _DisposeHandle
 STZ LISTENHANDLE+2
:SKIPDISPOSE

 LDA #0
:ERR TAX

 PLA
 STA 17,S
 PLA
 STA 17,S
 PLA
 PLA
 PLA
 PLA
 PLA
 PLA
 PLA
 PLB
 TXA
 CMP #1
 RTL

UNREGSTR STR 'Removing named IP address'
CLOSESTR STR 'Closing AppleTalk socket'
CLEANSTR STR 'Cleaning up'

CLOSESOCKET DFB 0,$C
CLOSESKTRESULT DA 0
 DFB 72

*-------------------------------------------------
* MacIPGetVariables():variablesPtr:longword
*-------------------------------------------------

MacIPGetVariables DBGMSG MacIPGetVariables
 LDA #VARIABLES
 STA 4,S
 LDA #^VARIABLES
 STA 4+2,S
 LDA #0
 CLC
 RTL

VARIABLES DS lvlen

*-------------------------------------------------
* MacIPConfigFName(configFileNamePtr:longword);
*-------------------------------------------------

MacIPConfigFName DBGMSG MacIPConfigFName(configFileNamePtr:longword);
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

:CONFIGFNAME STR 'MacIP.config'

*-------------------------------------------------
* This is the listen hook routine called directly by
* AppleTalk when it gets a datagram. All registers are
* undefined. ie. no DP
*-------------------------------------------------

LISTENHANDLE ADRL 0

LISTEN DBGMSG LISTEN
 PHB
 PHK
 PLB
*
 LDA LISTENHANDLE+2 ;Got one already allocated?
 BNE :GOTHANDLE
 PHS 2
 PHL #586
 PHW USERID
 PEA $0018
 PHS 2
 _NewHandle
 PLL LISTENHANDLE

:GOTHANDLE PHL LISTENHANDLE
 TSC
 PHD
 TCD
 LDA [1]
 STA READADDRESS
 LDY #2
 LDA [1],Y
 STA READADDRESS+2
 PLD
 PLS 2

 LDX #READBUFFER
 LDY #^READBUFFER
 JSL $E11014 ; ReadBuffer
 BCC :READOK

 LDA READRESULT
 CMP #$202
 BNE :ERR
:READOK

 LDA TRANS ;Is it full 586? Or do we need to shorten it?
 CMP #586
 BEQ :LENOK

 PEA 0
 PHA
 PHL LISTENHANDLE
 _SetHandleSize
:LENOK

* Now add the handle to the datagram queue. Remember, I have no DP

 PHL DATAGRAMQUEUE
 TSC
 PHD
 TCD

 LDY #8
 LDA [1],Y
 PHA ;save a copy of index to new entry
 CLC
 ADC #4
 PEA 0
 PHA
 PZL 1
 _SetHandleSize

 LDA [1]
 TAX
 LDY #2
 LDA [1],Y
 STA 1+2
 STX 1

 PLY ;get index to now last entry
 PHY
 LDA #0
 STA [1],Y
 INY
 INY
 STA [1],Y
 PLY ;get index again
 DEY
 DEY
 LDA LISTENHANDLE+2
 STA [1],Y
 DEY
 DEY
 LDA LISTENHANDLE
 STA [1],Y
 PLD
 PLS 2

 STZ LISTENHANDLE+2
*
:ERR
 PLB
 RTL

READBUFFER DFB 0,8
READRESULT DA 0
 DA 586
READADDRESS ADRL 0
 DFB -1
TRANS DA 0

*-------------------------------------------------
* Queue library routines
*-------------------------------------------------

* NEWQUEUE():masterhandle

NEWQUEUE DBGMSG NEWQUEUE
 ~NewHandle #4;USERID;#$0018;#0
 PLA
 STA MACIPQHANDLE
 STA 6,S
 PLA
 STA MACIPQHANDLE+2
 STA 6,S
 LDA [MACIPQHANDLE]
 STA MACIPQPTR
 LDY #2
 LDA [MACIPQHANDLE],Y
 STA MACIPQPTR+2
 LDA #0
 STA [MACIPQPTR]
 STA [MACIPQPTR],Y
 RTL

* DESTROYQUEUE(masterhandle)

DESTROYQUEUE DBGMSG DESTROYQUEUE
 LDA 4,S
 STA MACIPQHANDLE
 LDA 4+2,S
 STA MACIPQHANDLE+2
 LOCK MACIPQHANDLE
 LDA [MACIPQHANDLE]
 STA MACIPQPTR
 LDY #2
 LDA [MACIPQHANDLE],Y
 STA MACIPQPTR+2
 LDY #2
:LOOP LDA [MACIPQPTR],Y
 BEQ :DONE
 PHY
 PHA
 DEY
 DEY
 LDA [MACIPQPTR],Y
 PHA
 _DisposeHandle
 PLY
 INY
 INY
 INY
 INY
 BRA :LOOP
:DONE UNLOCK MACIPQHANDLE
 PZL MACIPQHANDLE
 _DisposeHandle
 PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 RTL

* GETNEXTINQUEUE(masterhandle):handle

GETNEXTINQUEUE DBGMSG GETNEXTINQUEUE

 LDA 4,S
 STA MACIPQHANDLE
 LDA 4+2,S
 STA MACIPQHANDLE+2

 LDA [MACIPQHANDLE]
 STA MACIPQPTR
 LDY #2
 LDA [MACIPQHANDLE],Y
 STA MACIPQPTR+2

 LDA [MACIPQPTR]
 STA 8,S
 LDA [MACIPQPTR],Y
 STA 8+2,S
 BEQ :OUT ;None

 LDY #8
 LDA [MACIPQHANDLE],Y
 PHA

 LDY #6
]L1 LDA [MACIPQPTR],Y
 TAX
 DEY
 DEY
 LDA [MACIPQPTR],Y
 PHA
 DEY
 DEY
 TXA
 STA [MACIPQPTR],Y
 DEY
 DEY
 PLA
 STA [MACIPQPTR],Y
 TYA
 CLC
 ADC #8
 TAY
 CMP 1,S
 BCC ]L1

 PLS

 PEA 0
 LDY #8
 LDA [MACIPQHANDLE],Y
 SEC
 SBC #4
 PHA
 PZL MACIPQHANDLE
 _SetHandleSize

:OUT PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 RTL

*-------------------------------------------------
* MacIPConfigure(connectHandle,disconnectHandle);
*-------------------------------------------------

MacIPConfigure DBGMSG MacIPConfigure
 PHB
 PHK
 PLB
 LDA 9+2,S
 STA MACIPTMPHANDLE+2
 LDA 9,S
 STA MACIPTMPHANDLE
 LDY #8
 LDA [MACIPTMPHANDLE],Y
 INY
 INY
 ORA [MACIPTMPHANDLE],Y
 BEQ :ZEROLEN
 DEREF MACIPTMPHANDLE;MACIPTMPTR
 LDA [MACIPTMPTR]
 CMP #mcVersion ;check version
 BEQ :VERSOK

:ZEROLEN PHL #mclen
 PZL MACIPTMPHANDLE
 _SetHandleSize
 PHL #DEFAULTmc
 PZL MACIPTMPHANDLE
 PHL #mclen
 _PtrToHand

:VERSOK

 ~GetPort

 PEA 0
 PEA MacIPVERSH
 PEA MacIPVERSL
 PHL #VERSIONASC
 _VersionString
 LDA VERSIONASC
 AND #$FF
 STA VERSIONASCL

 ~NewWindow2 #0;#0;#0;#0;#0;#WINDPARMS;#$800E
 LDA 1,S
 STA WINDPTR
 LDA 1+2,S
 STA WINDPTR+2
 _SetPort

 LOCK MACIPTMPHANDLE

 DEREF MACIPTMPHANDLE;MACIPTMPTR

 PHA
 LDY #mcLOCALIP+2
 LDA [MACIPTMPTR],Y
 PHA
 DEY
 DEY
 LDA [MACIPTMPTR],Y
 PHA
 PHL #:WORKBUFF
 PEA 0
 _TCPIPConvertIPToASCII
 PLA
 PZL WINDPTR
 PHL LOCALLECTL+2
 PHL #:WORKBUFF
 _SetLETextByID

 PHA
 LDY #mcGATEWAYIP+2
 LDA [MACIPTMPTR],Y
 PHA
 DEY
 DEY
 LDA [MACIPTMPTR],Y
 PHA
 PHL #:WORKBUFF
 PEA 0
 _TCPIPConvertIPToASCII
 PLA
 PZL WINDPTR
 PHL GATEWAYLECTL+2
 PHL #:WORKBUFF
 _SetLETextByID

 PEA 1
 PZL WINDPTR
 LDY #mcLOCALAUTO
 LDA [MACIPTMPTR],Y
 BEQ :LOCALFORCE
:LOCALAUTO PHL LOCALAUTOCTL+2
 BRA :JOINLOCAL
:LOCALFORCE PHL LOCALFORCECTL+2
:JOINLOCAL _SetCtlValueByID

 PEA 1
 PZL WINDPTR
 LDY #mcGATEWAYAUTO
 LDA [MACIPTMPTR],Y
 BEQ :GATEWAYFORCE
:GATEWAYAUTO PHL GATEWAYAUTOCTL+2
 BRA :JOINGATEWAY
:GATEWAYFORCE PHL GATEWAYFORCECTL+2
:JOINGATEWAY _SetCtlValueByID

 UNLOCK MACIPTMPHANDLE

:LOOP ~DoModalWindow #:TASKRECORD;#0;#0;#0;#%0100_0000_0000_1000
 PLXA
 CPX CANXCTL+2
 BEQL :CLOSEOUT
 CPX SAVECTL+2
 BEQ :SAVE
 CPX LOCALLECTL+2
 BEQ :SETLOCALAUTO
 CPX GATEWAYLECTL+2
 BEQ :SETGATEWAYAUTO
 CPX VERSIONCTL+2
 BEQ :EGG
 BRA :LOOP

:EGG ~AlertWindow #%100_00_1;#0;#EGGALERT
 PLA
 BRA :LOOP

:SETLOCALAUTO PEA 1
 PZL WINDPTR
 PHL LOCALFORCECTL+2
 _SetCtlValueByID
 BRA :LOOP

:SETGATEWAYAUTO PEA 1
 PZL WINDPTR
 PHL GATEWAYFORCECTL+2
 _SetCtlValueByID
 BRL :LOOP

:SAVE LOCK MACIPTMPHANDLE

 DEREF MACIPTMPHANDLE;MACIPTMPTR

 PZL WINDPTR
 PHL LOCALLECTL+2
 PHL #:WORKBUFF
 _GetLETextByID
 PHL #:IPBUFF
 PHL #:WORKBUFF
 _TCPIPConvertIPToHex
 LDY #mcLOCALIP
 LDA :IPBUFF
 STA [MACIPTMPTR],Y
 INY
 INY
 LDA :IPBUFF+2
 STA [MACIPTMPTR],Y

 PZL WINDPTR
 PHL GATEWAYLECTL+2
 PHL #:WORKBUFF
 _GetLETextByID
 PHL #:IPBUFF
 PHL #:WORKBUFF
 _TCPIPConvertIPToHex
 LDY #mcGATEWAYIP
 LDA :IPBUFF
 STA [MACIPTMPTR],Y
 INY
 INY
 LDA :IPBUFF+2
 STA [MACIPTMPTR],Y

 PHA
 PZL WINDPTR
 PHL LOCALAUTOCTL+2
 _GetCtlValueByID
 PLA
 LDY #mcLOCALAUTO
 STA [MACIPTMPTR],Y

 PHA
 PZL WINDPTR
 PHL GATEWAYAUTOCTL+2
 _GetCtlValueByID
 PLA
 LDY #mcGATEWAYAUTO
 STA [MACIPTMPTR],Y

 UNLOCK MACIPTMPHANDLE

:CLOSEOUT PZL WINDPTR
 _CloseWindow
 _SetPort
 PLA
 STA 7,S
 PLA
 STA 7,S
 PLA
 PLA
 PLB
 RTL

:IPBUFF ADRL 0
 DA 0

:WORKBUFF DS 1+15+1

:TASKRECORD DS $2E

CTLLIST ADRL TITLECTL ;control 1
 ADRL TITLELINECTL
 ADRL VERSIONCTL
 ADRL LOCALTITLECTL
 ADRL GATEWAYTITLECTL
 ADRL GATEWAYRECTCTL
 ADRL LOCALRECTCTL
 ADRL LOCALAUTOCTL
 ADRL LOCALFORCECTL
 ADRL GATEWAYAUTOCTL
 ADRL GATEWAYFORCECTL
 ADRL LOCALLECTL
 ADRL GATEWAYLECTL
 ADRL CANXCTL
 ADRL SAVECTL
 ADRL 0

TITLECTL DA 8
 ADRL 1 ;ID (1)
 RECTAT 5;12;10;100
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL MacIPASC ;text reference
 DA MacIPASCL ;text size

VERSIONCTL DA 9
 ADRL 2 ;ID (1)
 RECTAT 5;171;10;40
 ADRL $81000000 ;static text
 DA $0000 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon
 ADRL VERSIONASC+1 ;text reference
VERSIONASCL DA 0
 DA -1 ;right justify

VERSIONASC DS 10

TITLELINECTL DA 6
 ADRL 8 ;ID (8)
 RECTAT 15;12;1;199
 ADRL $87FF0003
 DA $0002 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon

LOCALTITLECTL DA 9 ;pCount
 ADRL 200
 RECTAT 20;22;9;126
 ADRL $81000000
 DA $0000
 DA $1000
 ADRL 0
 ADRL LOCALTITLEASC
 DA LOCALTITLEASCL
 DA 1

LOCALAUTOCTL DA 8
 ADRL 300
 RECTAT 33;22;9;98
 ADRL $84000000
 DA $FF01 ;disabled + family
 DA %0001_0000_0000_0000
 ADRL 0
 ADRL :PSTR
 DA 0
:PSTR STR 'Automatic'

LOCALFORCECTL DA 8
 ADRL 301
 RECTAT 46;22;10;51
 ADRL $84000000
 DA 1 ;family
 DA %0001_0000_0000_0000
 ADRL 0
 ADRL :PSTR
 DA 0
:PSTR STR 'Use'

LOCALLECTL DA 8
 ADRL 302 ;ID (5)
 RECTAT 44;77;13;124
 ADRL $83000000 ;line edit
 DA $0000 ;flag
 DA $7000 ;moreFlags
 ADRL 0 ;refCon
 DA 15 ;max size
 ADRL NULLPSTR

LOCALRECTCTL DA 6
 ADRL 303
 RECTAT 24;12;37;199
 ADRL $87FF0003
 DA $FF01 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon

GATEWAYTITLECTL DA 9 ;pCount
 ADRL 304
 RECTAT 64;22;9;143
 ADRL $81000000
 DA $0000
 DA $1000
 ADRL 0
 ADRL GATEWAYTITLEASC
 DA GATEWAYTITLEASCL
 DA 1

GATEWAYAUTOCTL DA 8
 ADRL 400 ;ID (3)
 RECTAT 77;22;10;134
 ADRL $84000000
 DA 2 ;family
 DA %0001_0000_0000_0000
 ADRL 0
 ADRL :PSTR
 DA 0
:PSTR STR 'Search network'

GATEWAYFORCECTL DA 8
 ADRL 401
 RECTAT 90;22;10;51
 ADRL $84000000
 DA 2 ;family
 DA %0001_0000_0000_0000
 ADRL 0
 ADRL :PSTR
 DA 0
:PSTR STR 'Use'

GATEWAYLECTL DA 8
 ADRL 402
 RECTAT 88;77;13;124
 ADRL $83000000 ;line edit
 DA $0000 ;flag
 DA $7000 ;moreFlags
 ADRL 0 ;refCon
 DA 15 ;max size
 ADRL NULLPSTR ;default

GATEWAYRECTCTL DA 6
 ADRL 403
 RECTAT 68;12;37;199
 ADRL $87FF0003
 DA $FF01 ;flag
 DA $1000 ;moreFlags
 ADRL 0 ;refCon

CANXCTL DA 9
 ADRL $6 ;ID (6)
 RECTAT 112;20;13;70
 ADRL $80000000 ;simple button
 DA $0000 ;flag
 DA $3000 ;moreFlags
 ADRL 0 ;refCon
 ADRL CANXPSTR ;title
 ADRL 0 ;no ctlColorTable
 HEX 1B1B ;keyEquivalent
 DA $0000,$0000 ;modifiers

SAVECTL DA 9
 ADRL $7 ;ID (7)
 RECTAT 112;125;13;75
 ADRL $80000000 ;simple button
 DA $0001 ;flag
 DA $3000 ;moreFlags
 ADRL 0 ;refCon
 ADRL SAVEPSTR ;title
 ADRL 0 ;no ctlColorTable
 HEX 0D0D ;keyEquivalent
 DA $0000,$0000 ;modifiers

NULLPSTR DFB 0

CANXPSTR STR 'Cancel'

SAVEPSTR STR 'Save'

MacIPASC ASC 'MacIP'
MacIPASCL = *-MacIPASC

LOCALTITLEASC ASC 'Local IP address'
LOCALTITLEASCL = *-LOCALTITLEASC

GATEWAYTITLEASC ASC 'Gateway IP address'
GATEWAYTITLEASCL = *-GATEWAYTITLEASC

WINDPARMS DA $50 ;template size
 DA $20A0 ;frame bits
 ADRL 0 ;no title
 ADRL 0 ;window refcon
 DA 0,0,0,0 ;zoom rectangle
 ADRL WINDCOLOUR
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
 CENTRERECT 132;226
 ADRL -1 ;plane
 ADRL CTLLIST
 DA 3 ;indescref

WINDCOLOUR DA $0000 ;frame color
 DA $0F0F ;title color
 DA $0000 ;titlebar color
 DA $F0FF ;grow color
 DA $00F0 ;info color

EGGALERT ASC '93~MacIP for Marinetti',0D
 ASC 'Copyright (c) 1998 by Richard Bennett',0D0D
 ASC 'This module was originally hacked together'
 ASC ' with the assistance of Tony',CA,'Diaz, at his place'
 ASC ' from 1-Aug-1998 to 3-Aug-1998. Tony',D5,'s'
 ASC ' network resources, a disassembler and ample supplies'
 ASC ' of Coke, made up for our complete lack of any AppleTalk'
 ASC ' programming documentation.'
 ASC '~^#0'
 DFB 0

*-------------------------------------------------
* Debug stuff
*-------------------------------------------------
 do showtraffic

DUMPDGMPTR
 LDA #outheaderin
 JSR DUMPLINE

 LDA #outtimestamp
 JSR DUMPSTRING

 lda #0
]l1 tay
 lda [MACIPTMPTR],y
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
 cmp [MACIPTMPHANDLE],y
 bcc ]l1

 LDA #outnull
 JSR DUMPLINE
 rts

outheaderin str 'in:'
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

:PATHNAME STRL ':RAM5:MACIP.trace'

FLUSH DA 1,0

 else

 pea ^*
 pha
 _WriteString
 rts

 fin

 fin

 SAV MacIP.CODE.L

 END
