 LST OFF
*=================================================
*
* I.IPC.S - Miscellaneous IPC subroutines
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
* 2002.02.16 RJB - Initial release as open source
*
*=================================================
 REL
 mx 0

 USE 4/RJBUTIL.MACS
 USE 4/LOCATOR.MACS
 USE ../Equates/BUILD.EQU
 USE ../Equates/I.EQU
 USE ../Equates/TCPIP.EQU

*-------------------------------------------------
* IPC stuff - OUTGOING
*-------------------------------------------------

SENDIPC ENT ;xa=indata, y=code
 PHY
 PEA %01
 PEA #^:TARGETSTR
 PEA #:TARGETSTR
 PHA
 PHX
 PEA 0
 PEA 0
 _SendRequest
 RTL

:TARGETSTR STR 'TCP/IP~'

 SAV I.IPC.L

 END
