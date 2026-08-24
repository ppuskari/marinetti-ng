*=================================================
*
* BUILD.EQU.S - Equates for controlling building of Marinetti
*
* Copyright (C) 1997-2001 Richard Bennett
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
* 2000.08.12 RJB - Initial release as open source
* 2003.07.26 AJR - Bumped version number 3.0b1
* 2005.02.09 AJR - Bumped version number 3.0b2
* 2006.06.03 AJR - Added TCPTODISK & TCPDRCV2
* 2006.07.17 AJR - Bumped version number 3.0b3
*
*=================================================

*-------------------------------------------------
* Administrative equates
*-------------------------------------------------

LLMININTVERSION = 1 ;Lowest link layer interface version supported
LLMAXINTVERSION = 2 ;Highest link layer interface version supported

CODESYNCVERSION = 27 ;increment this for every release to
;synchronise tool and init. Must rebuild
;*ALL* modules; init, tool, cdev.

PREFSVERSION = 11 ;increment when layout changes

VERSION = $0300+$8000 ;Tool set version number

VERASC MAC
 ASC '3.0b3' ;Embedded init version number
 <<<

VERSTR MAC ;...and pstring version
 DFB ]VL
]VA VERASC
]VL = *-]VA
 <<<

EXPIRY = 0
DAY = 27
MONTH = 9
YEAR = 2001

EYECATCHERS = 1
INITBUFFCC = 1 ;serial port buffer
INITDPCC = 1 ;direct page

TCPDEBUG = 0 ;TCP diagnostics on -- must TCPIPSetTCPDebug(1)
TCPTOBUFFER = 0 ;TCPDEBUG must be on. Must do a FULL build
TCPTODISK = 0 ;TCPDEBUG must be on. Must do a FULL build
 ERR TCPTOBUFFER+TCPTODISK/2 ;either can be set but not both

* TCPDEBUG macros

TCPD MAC
 do TCPDEBUG
 JSR TCPDUMP
 if ',]1
 ASC ]1
 else
 ASC ']1'
 fin
 DFB 0
 fin
 <<<

TCPSAY MAC
 do TCPDEBUG
 JSR TCPRINT
 if ',]1
 ASC ]1
 else
 ASC ']1'
 fin
 DFB 0
 fin
 <<<

TCPDSEQ MAC
 do TCPDEBUG
 JSR TCPRINT
 ASC ' seq:',00
 LDA 9,S
 TAX
 LDA 9+2,S
 JSR TCPLONG
 JSR TCPRINT
 ASC ' ack:',00
 LDA 13,S
 TAX
 LDA 13+2,S
 JSR TCPLONG
 LDA 1,S
 JSR DUMPFLAGS
 JSR TCPRINT
 HEX 0D00
 JSR DEBUGWAIT
 fin
 <<<

TCPDLEN MAC
 do TCPDEBUG
 JSR TCPRINT
 ASC ' datalen=',00
 LDY #8
 LDA [TCPHANDLE],Y
 JSR TCPSHORT
 fin
 <<<

TCPXA MAC
 do TCPDEBUG
 PHA
 PHX
 JSR TCPRINT
 if ',]1
 ASC ]1
 else
 ASC ']1'
 fin
 DFB 0
 PLX
 PLA
 JSR TCPLONG
 JSR TCPRINT
 HEX 0D00
 fin
 <<<

TCPDRCV MAC
 do TCPDEBUG
 JSR DUMPRCV
 JSR DEBUGWAIT
 fin
 <<<

TCPDRCV2 MAC
 do TCPDEBUG
 JSR DUMPRCV2
 JSR DEBUGWAIT
 fin
 <<<
