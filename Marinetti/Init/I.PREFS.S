 LST OFF
*=================================================
*
* I.PREFS.S - Preferences data block
*
* Copyright (C) 1997-2005 Richard Bennett-Forrest
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
* 2005.07.10 RJB - Initial release as open source
*
*=================================================
 REL
 mx 0

 USE ../EQUATES/BUILD.EQU
 USE ../EQUATES/I.EQU
 USE ../EQUATES/TCPIP.EQU

PREFERENCES ENT
 DA PREFSVERSION ;prefs version

* -- Reconnect data --

RECONVALID ENT
 DA 0

RECONIPADDRESS ENT
 DFB 0,0,0,0

* --------------------

DNSIPMAIN ENT
 DFB 0,0,0,0

DNSIPAUX ENT
 DFB 0,0,0,0

CONNECTMETHOD ENT
 DA conPPP ;Default = PPP

DEBUGHEX ENT
 DA 0 ;no

DEBUGTCP ENT
 DA 0 ;no

IPUSERSLICE ENT ;slice for IPC poll
 DA DEFIPSLICE
IPRUNQFREQ ENT
 DA DEFIPRUNQFREQ ;frequency for RUNQ
IPRUNQSLICE ENT ;slice for RUNQ
 DA DEFIPRUNQSLICE

TCPUSERSLICE ENT ;this is unused, but passable. %(
 DA DEFTCPUSERSLICE

TCPMAXSEGSEND ENT
 DA DEFTCPMAXSEGSEND
TCPMAXSEGRECEIVE ENT
 DA DEFTCPMAXSEGRECEIVE

TCPRECEIVEWINDOW ENT
 DA DEFTCPRECEIVEWINDOW

CONNECTMSGFLAG ENT
 DA DEFCONNECTMSGFLAG

USERNAME ENT
 DS 1+50

PASSWORD ENT
 DS 1+50

HOSTNAME ENT
 STR 'appleiigs'
 DS 1+30-*+HOSTNAME

ALIVEFLAG ENT
 DA 0 ;defaults to off

ALIVEMINUTES ENT
 DA 30 ;in minutes

BOOTCONNECTFLAG ENT
 DA 0 ;no

PREFSEND

PREFSLENGTH ENT
 DA PREFSEND-PREFERENCES

 SAV I.PREFS.L

 END
