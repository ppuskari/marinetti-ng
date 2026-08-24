 LST OFF
*=================================================
*
* I.DISPATCH.S - Dispatch  manager for Marinetti
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
* 2002.09.30 RJB - Initial release as open source
*
*=================================================
 REL
 mx 0

 USE 4/RJBUTIL.MACS
 USE 4/LOAD.MACS
 USE 4/MISC.MACS
 USE 4/TEXT.MACS
 USE 4/INT.MACS
 USE 4/RESOURCE.MACS
 USE ../EQUATES/BUILD.EQU
 USE ../EQUATES/I.EQU
 USE ../EQUATES/TCPIP.EQU

* NOTE: Any code called through here may NOT assume data bank!

*-------------------------------------------------
* This file contains various dispatch tables,
* connecting the various modules and protocol layers.
*
* The basic TCP/IP layer model is:
*
*       |-------------|
*       | Application | ---> Telnet, FTP, Ping, Finger, Gopher, email etc.
*       |-------------|
*              |
*       |-------------|
*       |  Transport  | ---> TCP, UDP
*       |-------------|
*              |
*       |-------------|
*       |   Network   | ---> IP, ICMP, IGMP
*       |-------------|
*              |
*       |-------------|
*       |    Link1    | ---> Device driver (SLIP, PPP etc.)  "LINK" prefix
*       |-------------|
*              |
*       |-------------|
*       |    Link0    | ---> Interface card / port
*       |-------------|
*
*-------------------------------------------------

 EXT MYID,MYDP,IPID

LINKCONFIGFNAME ENT
 LDA INTV
 CMP #2
 BCS :DISPATCH ;Version 2 is supported
 LDA >MODLISTINDEX
 TAX
 LDA >MODULELIST+liMethodID,X
 PHS 2
 PHA
 _HexIt
 PLL >:CONFIGFNAME+10
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

:CONFIGFNAME STR 'LLV01CFG.xxxx'

:DISPATCH LDX #LLCONFIGFNAME
 BRA LINKDISPATCH

*-------------------------------------------------

LINKINTERFACEV LDX #LLINTERFACEV
 BRA LINKDISPATCH

LINKSTARTUP LDX #LLSTARTUP
 BRA LINKDISPATCH

LINKSHUTDOWN LDX #LLSHUTDOWN
 BRA LINKDISPATCH

LINKMODULEINFO ENT
 LDX #LLMODULEINFO
 BRA LINKDISPATCH

LINKGETPACKET ENT
 LDX #LLGETPACKET
 BRA LINKDISPATCH

LINKSENDPACKET ENT
 LDX #LLSENDPACKET
 BRA LINKDISPATCH

LINKCONNECT ENT
 LDX #LLCONNECT
 BRA LINKDISPATCH

LINKRECONSTATUS ENT
 LDX #LLRECONSTATUS
 BRA LINKDISPATCH

LINKRECONNECT ENT
 LDX #LLRECONNECT
 BRA LINKDISPATCH

LINKDISCONNECT ENT
 LDX #LLDISCONNECT
 BRA LINKDISPATCH

LINKGETVARIABLES ENT
 LDX #LLGETVARIABLES
 BRA LINKDISPATCH

LINKCONFIGURE ENT
 LDX #LLCONFIGURE
% BRA LINKDISPATCH

LINKDISPATCH LDA >MYID
 TAY
 LDA >LLDPAGE
LINKMOD JML 0 ;X=call,A=DP(or 0000),Y=Marinetti UserID (not module's)
;DP=Marinetti DP

INTV DA 0 ;Interface version of current link layer
MODLISTINDEX DA 0 ;Index into MODULELIST of current link layer

*-------------------------------------------------
* Admin code, loaders etc.
*-------------------------------------------------

DUMPLINKLAYER ENT
 LDA >LINKMOD+1
 ORA >LINKMOD+1+1
 BEQ :DUMPED
 PHD
 LDA >MYDP
 TCD
 JSL LINKSHUTDOWN
 PHS
 LDA >LLUSERID
 PHA
 PEA 0
 _UserShutDown
 PLS
 LDA #0
 STA >LLUSERID
 STA >LINKMOD+1
 STA >LINKMOD+1+1
 STA >INTV
 STA >MODLISTINDEX
 PLD
:DUMPED LDA #terrOK
 CLC
 RTL

PATHLEN = 15 ;Length of '*:System:TCPIP:'

*-------------------------------------------------
* LOADLINKLAYER
*-------------------------------------------------

LOADLINKLAYER ENT

 TAX

 LDA >LINKMOD+1
 ORA >LINKMOD+1+1
 BNEL :LOADED

 PHB
 PHK
 PLB

 PHD
 LDA >MYDP
 TCD

 PHX

 LDX #0
]L1 LDA MODULELIST,X
 BEQL :NOENTRY
 CMP 1,S
 BEQ :GOTMODULE
 TXA
 CLC
 ADC #lilen
 TAX
 BRA ]L1
:GOTMODULE
 STX MODLISTINDEX
 SEP $20
 LDA MODULELIST+liFilename,X ;get length
 PHA ;save it
 LDY #0
]L1 LDA MODULELIST+liFilename+1,X
 STA MODULEFILENAME,Y
 INX
 INY
 CPY #15
 BCC ]L1
 PLA
 CLC
 ADC #15
 STA MODULEPATHNAME
 REP $20
 PLX

 ~GetNewID #$3100
 PLY
 STY :TEMPUSERID

 PHS 1+1+2+1
 PHY
 PHL #MODULEPATHNAME
 PEA #$8000
 PEA #1
 _InitialLoad2 ;MYID;#DNRGSTRING;#$8000;#1
 BCS :NOLINKLAYER
 PLW LLUSERID
 PLL LLENTRY
 PLW LLDPAGE
 PLW LLDPSIZE
 LDA LLENTRY
 STA LINKMOD+1
 LDA LLENTRY+1
 STA LINKMOD+1+1
 PHS
 JSL LINKINTERFACEV
 PLA
 CMP #LLMININTVERSION
 BCC :BADVERSION
 CMP #LLMAXINTVERSION
 BCC :VERSIONOK
 BNE :BADVERSION
:VERSIONOK
 STA INTV
 JSL LINKSTARTUP
 PHS 2
 JSL LINKGETVARIABLES
 PLL LINKVARIABLESPTR
 PLD
 PLB
:LOADED LDA #terrOK
 CLC
 RTL

:NOENTRY PLX
 BRA :ERR

:NOLINKLAYER ~DeleteID :TEMPUSERID
 PLS 5
:ERR PLD
 LDA #terrNOLINKLAYER&terrmask
 SEC
 PLB
 RTL

:BADVERSION PHS
 PHW LLUSERID
 PEA 0
 _UserShutDown
 PLS
 ~DeleteID :TEMPUSERID
 STZ LINKMOD+1
 STZ LINKMOD+1+1
 LDA #terrBADLINKLAYER&terrmask
 PLD
 PLB
 CMP #1
 RTL

:TEMPUSERID DA 0

:OPENPATH ADRL 0

MODULEPATHNAME ENT
 STRL '*:System:TCPIP:'
MODULEFILENAME DS 15

LLUSERID DA 0
LLENTRY ADRL 0
LLDPAGE DA 0
LLDPSIZE DA 0

*-------------------------------------------------
* BuildModuleList - returns with carry and error code
*-------------------------------------------------

BuildModuleList ENT
 DBGMSG BuildModuleList
 PHB
 PHK
 PLB
 PHD
 LDA >MYDP
 TCD
 STZ :LISTINDEX
 STZ :INTVINDEX
 JSL $E100A8
 DA $2010
 ADRL :OPEN
 BCC :GO
 STZ MODULELIST
 PLD
 PLB
 RTL
:GO LDA :OPENREF
 STA :GETDIRREF
 STA :CLOSE+2
 LDA #1
 STA :OFFSET
:READ JSL $E100A8
 DA $201C
 ADRL :GETDIRENTRY
 BCS :DONE
 LDA :FILETYPE
 CMP #$BC
 BNE :NEXT
 LDA :AUXTYPE+2
 BNE :NEXT
 LDA :AUXTYPE
 CMP #$4083
 BEQ :GOTONE
:NEXT INC :OFFSET
 BRA :READ
:DONE JSL $E100A8
 DA $2014
 ADRL :CLOSE
 LDX :LISTINDEX
 STZ MODULELIST,X
 PLD
 PLB
 RTL

:GOTONE LDA :PATH
 STA :SAVEPATH
 CLC
 ADC :PATHNAME+2
 STA :PATH
 LDA :PATHNAME+2
 TAX
 SEP $30
 DEX
]L1 LDA :PATHNAME+2+2,X
 STA :FILENAME,X
 DEX
 BPL ]L1
 REP $30
 ~InitialLoad2 #0;#:PATH;#-1;#1
 BCSL :ERR
 PLW LLUSERID
 PLL LLENTRY
 PLW LLDPAGE
 PLW LLDPSIZE
 LDA LLENTRY
 STA LINKMOD+1
 LDA LLENTRY+1
 STA LINKMOD+1+1
 PHS
 JSL LINKINTERFACEV
 PLA
 CMP #LLMININTVERSION
 BCC :BACK
 CMP #LLMAXINTVERSION
 BCC :VERSIONOK
 BNE :BACK
:VERSIONOK
 LDX :INTVINDEX
 STA MODULEINTV,X
 INX
 INX
 STX :INTVINDEX

 PEA ^MODULELIST
 LDA :LISTINDEX
 CLC
 ADC #MODULELIST
 PHA
 JSL LINKMODULEINFO
 ~UserShutdown LLUSERID;#0
 PLA
 STZ LINKMOD+1
 STZ LINKMOD+1+1

 SEP $20
 LDX :LISTINDEX
 LDA :PATHNAME+2
 STA MODULELIST+liFilename,X
 LDY #0
]L1 LDA :PATHNAME+2+2,Y
 STA MODULELIST+liFilename+1,X
 INX
 INY
 CPY :PATHNAME+2
 BCC ]L1
 REP $30

 LDX :LISTINDEX
 LDA MODULELIST+liMethodID,X
 STA MODULELIST+liMenuItem+rmiItemID,X
 LDA #MODULELIST
 CLC
 ADC :LISTINDEX
 ADC #liName
 STA MODULELIST+liMenuItem+rmiTitleRef,X
 LDA #^MODULELIST
 STA MODULELIST+liMenuItem+rmiTitleRef+2,X

 LDA :LISTINDEX
 CLC
 ADC #lilen
 STA :LISTINDEX

:BACK LDA :SAVEPATH
 STA :PATH
 BRL :NEXT

:ERR PLS 5
 BRA :BACK

:CLOSE DA 1,0

:OPEN DA 2
:OPENREF DA 0
 ADRL :PATH

:PATH STRL '*:System:TCPIP:'
:FILENAME DS 40

:SAVEPATH DA 0

:GETDIRENTRY DA 13
:GETDIRREF DA 0,0,0
:OFFSET DA 1
 ADRL :PATHNAME
 DA 0
:FILETYPE DA 0
 ADRL 0,0
 DS 16
 DA 0
:AUXTYPE ADRL 0

:PATHNAME DA 32
 DA 40
 DS 40

:LISTINDEX DA 0
:INTVINDEX DA 0

*-------------------------------------------------
* Boot time display - must have called BuildModuleList first!
*-------------------------------------------------

SHOWLINKVERSIONS ENT
 DBGMSG SHOWLINKVERSIONS
 PHB
 PHK
 PLB
 LDX #0
:LOOP LDA MODULELIST,X
 BEQL :DONE
 PHX
 PEA 0
 LDA MODULELIST+liVersion+2,X
 PHA
 LDA MODULELIST+liVersion,X
 PHA
 PHL #:OUTBUFFER+22

 SEP $30
 LDX #32-1
 LDA #$20
]L1 STA :OUTBUFFER,X
 DEX
 BPL ]L1
 REP $30

 _VersionString

 SEP $30
 LDA :OUTBUFFER+22
 TAX
 STZ :OUTBUFFER+22+1,X
 LDA #'v'
 STA :OUTBUFFER+22
 REP $30

 LDA 1,S
 SEC
 ADC #MODULELIST+liName
 TAX
 LDA 1,S
 TAY
 LDA MODULELIST+liName,Y
 AND #$FF
 DEC
 LDY #:OUTBUFFER+1
 PHB
 MVN MODULELIST+liName,:OUTBUFFER+1
 PLB

* Check for icon

 LDA 1,S
 TAX
 LDA MODULELIST+liFlags,X
 AND #1
 BEQ :SKIPICON

 SEP $20
 LDA MODULELIST+liFilename,X ;get length
 PHA ;save it
 LDY #0
]L1 LDA MODULELIST+liFilename+1,X
 STA MODULEFILENAME,Y
 INX
 INY
 CPY #15
 BCC ]L1
 PLA
 CLC
 ADC #15
 STA MODULEPATHNAME
 REP $20

 ~OpenResourceFile #%11;#0;#MODULEPATHNAME
 ~LoadResource #$8001;#1
 PLXA TMPHANDLE
 PHL #:OUTBUFFER
 LDY #2
 LDA [TMPHANDLE],Y
 PHA
 LDA [TMPHANDLE]
 PHA
 _ShowBootInfo
 _CloseResourceFile
 BRA :NEXT

:SKIPICON

*

 PHL #:OUTBUFFER
 PHL #0
 _ShowBootInfo

:NEXT

 PLA
 CLC
 ADC #lilen
 TAX
 BRL :LOOP

:DONE PLB
 RTL

:OUTBUFFER DS 22 ;the name
 DS 1 ;the 'v'
 DS 9 ;the version
 DFB 0 ;null byte

*-------------------------------------------------
* List of available modules
*-------------------------------------------------

MODULELIST ENT
 LUP 10
 DS lilen
 --^
 DA 0

MODULEINTV ENT
 LUP 10
 DA 0
 --^

*-------------------------------------------------
* System triggers
*-------------------------------------------------

SystemTriggers ENT
 DS strgCount*4

*-------------------------------------------------
* User trigger dispatch - assumes user is open (ie. USERPTR is set)
*
* Y = trigger number
* CallUserTrigger(parm:longptr; actionCode:word):word
*-------------------------------------------------

CallUserTrigger ENT
 DBGMSG CallUserTrigger

 TYA
 ASL
 CLC
 ADC #uwTriggers
 TAY
 LDA [USERPTR],Y
 STA >:JML+1
 INY
 LDA [USERPTR],Y
 ORA >:JML+1
 BEQ :NOTRIGGER
 STA >:JML+1+1

 LDA >IPID

:JML JML 0

:NOTRIGGER PHB ;OK, grab the return address
 PLA
 STA 5,S
 PLA
 STA 5,S
 PLS
 PLB
 RTL

 SAV I.DISPATCH.L

 END
