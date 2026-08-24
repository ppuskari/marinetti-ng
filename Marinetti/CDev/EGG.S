 LST OFF
*=================================================
*
* EGG.S - Easter egg code for TCPIP Cdev
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

 USE 4/RJBUTIL.MACS
 USE 4/WINDOW.MACS
 USE 4/EVENT.MACS
 USE 4/QD.MACS
 USE 4/CTL.MACS
 USE 4/MISC.MACS

 DUM 0
WINDPTR ADRL 0
TMPTR ADRL 0
TMPHANDLE ADRL 0
DPLEN
 DEND

EGG ENT
 PHB
 PHK
 PLB
 GETDP #DPLEN
 ~GetPort
*
 LDX #8-1
]L1 LDA SRCRECT,X
 STA :SRCRECT,X
 DEX
 DEX
 BPL ]L1

 ~NewWindow2 #0;#0;#0;#0;#0;#EGGWINDOW;#$800E
 LDA 1,S
 STA WINDPTR
 LDA 1+2,S
 STA WINDPTR+2
 _SetPort
 ~PPToPort #ICONLOCINFO;#ICONRECT;#20;#20;#0
 ~NewRgn
 LDA 1,S
 STA TMPHANDLE
 LDA 1+2,S
 STA TMPHANDLE+2
 PHL #:SRCRECT
 _RectRgn
 ~SetClip TMPHANDLE
 ~DisposeRgn TMPHANDLE
 INC :SRCRECT+RECTY1
 INC :SRCRECT+RECTY2
 LDA :SRCRECT+RECTY2
 SEC
 SBC #5
 STA :BLINE
 CLC
 ADC #10
 STA :VLINE
 LDA #EGGTEXT
 STA TMPTR
 LDA #^EGGTEXT
 STA TMPTR+2
 ~FlushEvents #$0FFF;#0
 PLA
 _InitCursor
 LDA #0
:MOVELOOP PHA
 JSR :MOVEIT
 ~MoveTo :SRCRECT+RECTX1;:VLINE
 JSR DECRYPT
 ~DrawString TMPTR
 LDA [TMPTR]
 AND #$FF
 STA :STRLEN
 JSR ENCRYPT
 DEC :VLINE
 LDA :VLINE
 CMP :BLINE
 BNE :CONT
 CLC
 ADC #10
 STA :VLINE
 LDA :STRLEN
 SEC
 ADC TMPTR
 STA TMPTR
 LDA :STRLEN
 AND #$FF
 BEQ :LOOP
 BRA :CONT
:LOOP LDA #EGGTEXT
 STA TMPTR
:CONT ~GetNextEvent #$0FFF;#:EVENTREC
 PLA
 BEQ :NULL
 LDA :EVENTREC+ERECWHAT
 CMP #EVENTMOUSEDOWN
 BEQ :ENDIT
 CMP #EVENTKEYDOWN
 BEQ :ENDIT
:NULL PLA
 JSR :DELAY
 BRL :MOVELOOP
:ENDIT PLA
*
:OUT PZL WINDPTR
 _CloseWindow
 _SetPort
 PUTDP #DPLEN
 PLB
 RTL

:STRLEN DA 0

:DELAY PHA
 PHA
 PHW #110
 _WaitUntil
 PLA
 RTS

:MOVEIT ~GetPort ;source LocInfo
 PHL #:SRCRECT
 PHW :SRCRECT+RECTX1
 LDA :SRCRECT
 DEC
 PHA
 PEA 0
 _PPToPort
 RTS

:VLINE DA 0
:BLINE DA 0

:EVENTREC DS 16

:SRCRECT DA 1,120,79,500

SRCRECT DA 1,120,79,500

ENCRYPT LDA #0
 BRA CRYPT
DECRYPT LDA CRYPT
CRYPT SEP $30
 EOR [TMPTR]
 TAY
]L1 LDA [TMPTR],Y
 EOR CRYPT ;$E2
 STA [TMPTR],Y
 DEY
 BPL ]L1
 REP $30
 RTS

EGGWINDOW dw $50 ;template size
 dw $20A0 ;frame bits
 adrl 0 ;no title
 adrl 0 ;window refcon
 dw 0,0,0,0 ;zoom rectangle
 adrl WCOLOR_00000FFB ;color table
 dw 0,0 ;origin y/x
 dw 0,0 ;data height/width
 dw 0,0 ;max height/width
 dw 0,0 ;scroll vert/horiz
 dw 0,0 ;page vert/horiz
 adrl 0 ;info refcon
 dw 0 ;info height
 adrl 0 ;frame defproc
 adrl 0 ;info defproc
 adrl 0 ;content defproc
 dw 66,74,147,564 ;position
 adrl -1 ;plane
 adrl 0 ;no controls
 dw 0 ;indescref

WCOLOR_00000FFB equ *
 dw $0000 ;frame color
 dw $0F0F ;title color
 dw $0000 ;titlebar color
 dw $E0FF ;grow color
 dw $A0F0 ;info color

 ENC $E2
EGGTEXT STR ' '
 STR 'Marinetti -- TCP/IP for the Apple IIGS'
 STR ' '
 STR ' '
 STR 'Clean room developed from the RFCs in 65816'
 STR 'Merlin 16+ assembly code by Richard Bennett'
 STR ' '
 STR 'Special thanks to Geoff Weiss, Dave Miller,'
 STR 'Ewen Wannop, Dave Hecker, Tony Diaz, Erick Wagner'
 STR 'Andrew Roughan, Jeff Blakeney, Mike Westerfield,'
 STR 'Irene Sekler and Giselle Drury.'
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR 'If you found this easter egg on your own, send'
 STR 'email to cturley2@aol.com, with a subject'
 STR 'of: BITE ME YOU PUTZ!'
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR D2,'Once upon a time, there was a man called De...,'
 STR 'let',D5,'s call him Brian. Brian wanted a super project'
 STR 'for his thesis. He thought that a TCP/IP stack'
 STR 'would be a great idea, so he tried to write one.'
 STR ' '
 STR D2,'Unfortunately, not all the source was available'
 STR 'on the Internet, and Brian started to have'
 STR 'problems. So, he handed in his thesis incomplete.'
 STR ' '
 STR D2,'They liked Brian',D5,'s TCP/IP so much, that they'
 STR 'gave him a job building routers. Brian ended up'
 STR 'getting everything he wanted, so he never bothered'
 STR 'to finish his TCP/IP. What a pity he never had the'
 STR 'common decency to let anyone know, not even his'
 STR 'publisher...',D3
 STR ' '
 STR ' '
 STR 'If De..., err, Brian had been honest about where he'
 STR 'was up to, and where his interests lay, the'
 STR 'Apple IIGS would have had TCP/IP back in 1994.'
 STR ' '
 STR 'In fact, the technology used in Marinetti was'
 STR 'available way back in 1986, when the Apple IIGS'
 STR 'was released. If Apple Computer had wanted to,'
 STR 'the first Apple IIGS could have had TCP/IP'
 STR 'support.'
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR 'Marinetti was written for all my friends in the'
 STR 'Apple II community, nobody else. You know who you'
 STR 'are, enjoy, enjoy.'
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR 'Special thanks to Geoff Weiss for his continuing'
 STR 'confidence and his initial guiding light. Marinetti'
 STR 'exists only because of him.'
 STR ' '
 STR ' '
 STR ' '
 STR 'Development phase testers:'
 STR ' '
 STR 'Tony ',D2,'Ethernet',D3,' Diaz'
 STR 'Dave ',D2,'Proud Dad',D3,' Hecker'
 STR 'David ',D2,'DNR',D3,' Miller'
 STR 'Andrew ',D2,'News!',D3,' Roughan'
 STR 'Erick ',D2,'FAQ',D3,' Wagner'
 STR 'Ewen ',D2,'Speccy',D3,' Wannop'
 STR 'Geoff ',D2,'SIS',D3,' Weiss'
 STR ' '
 STR 'Specification feedback:'
 STR ' '
 STR 'S',9A,'nke Behrens'
 STR 'Joachim Lange'
 STR 'Devin Reade'
 STR 'Antoine Vignau'
 STR 'Mike Westerfield'
 STR ' '
 STR 'Alpha testers:'
 STR ' '
 STR 'Jeff Blakeney'
 STR 'Tony Diaz'
 STR 'Dave Hecker'
 STR 'David Miller'
 STR 'Andrew Roughan'
 STR 'Erick Wagner'
 STR 'Ewen Wannop'
 STR 'Geoff Weiss'
 STR 'Mike Westerfield'
 STR ' '
 STR 'Beta testers:'
 STR ' '
 STR 'Jeff Blakeney'
 STR 'Tony Diaz'
 STR 'Dave Hecker'
 STR 'Max Jones'
 STR 'Joe Kohn'
 STR 'David Miller'
 STR 'Andrew Roughan'
 STR 'Erick Wagner'
 STR 'Ewen Wannop'
 STR 'Tony Ward'
 STR 'Geoff Weiss'
 STR 'Mike Westerfield'
 STR 'Chris Vavruska'
 STR ' '
 STR 'Those kind enough to email me with kind words'
 STR 'about Marinetti 1.0:'
 STR ' '
 STR 'Rodney Abel'
 STR 'Cindy Adams'
 STR 'Jim Bauer'
 STR 'Jawaid Bazyar'
 STR 'Greg Buchne'
 STR 'Bruce Clark'
 STR 'Jon Christopher Sy Co'
 STR 'Art Coughlin'
 STR 'Dan DeDona'
 STR 'Jim Dwyer'
 STR 'Dean Esmay'
 STR 'Henrik Gudat'
 STR 'Jeremy Hack'
 STR 'Harold Hislop'
 STR 'Dave Johnson'
 STR 'Max Jones'
 STR 'James Keim'
 STR 'Tim Kellers'
 STR 'Joe Kohn'
 STR 'Daniel Krass'
 STR 'Gene Linkoski'
 STR 'Robert Liptak'
 STR 'Mark Marr-Lyon'
 STR 'Michael Malady'
 STR 'Nathan Mates'
 STR 'Ricardo Matinata'
 STR 'Mike McGovern'
 STR 'Kirk Mitchell'
 STR 'Todd Myers'
 STR 'Greg Nelson'
 STR 'Kevin Noonan'
 STR 'Aaron Pulver'
 STR 'J. Marshall Reber'
 STR 'Toby Reiter'
 STR 'Lucas Scharenbroich'
 STR 'Anne Schnaubelt'
 STR 'Paul Schultz'
 STR 'Kelvin Sherlock'
 STR 'Mitchell Spector'
 STR 'Ryan Suenaga'
 STR 'Joyce Sullivan'
 STR 'Greg Thompson'
 STR 'Gary Utter'
 STR 'Chris Vavruska'
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR 'Sandy booty ass!'
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR 'U da bomber!'
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 STR ' '
 DFB 0
 ENC $00

ICONLOCINFO DA $0080
 ADRL IMAGE01
 DA $15
ICONRECT DA 0,0,37,$15*4

*-------------------------------
* $15 bytes (b4 pack), from X - $0E to $22, Y - $2C to $50.
*-------------------------------
IMAGE01 HEX FFFFFFFFFFFFFFF4444444444FFFFFFFFFFFFFFFFF
 HEX FFFFFFFFFFFF4444444444444444FFFFFFFFFFFFFF
 HEX FFFFFFFFFF44444444444444444444FFFFFFFFFFFF
 HEX FFFFFFFF444444444444444444444444FFFFFFFFFF
 HEX FFFFFFF44444444433333333444444444FFFFFFFFF
 HEX FFFFF444444443333333333333344444444FFFFFFF
 HEX FFFF44444443333333FFFFFFFF3334444444FFFFFF
 HEX FFFF44444333333FFFFFFFFFFFFF444444443FFFFF
 HEX FFF4444433333FFFFFFFFFFFFFF44444444443FFFF
 HEX FF444443333FFFFFFFFFFFFFFF444443344444FFFF
 HEX FF44443333FFFFFFFFFFFFFFF44444333344443FFF
 HEX F44444333FFFFFFFFFFFFFFF444443333F444443FF
 HEX F4444333FFFFFFFFFFFFFFF444443333FFF44443FF
 HEX F4444333FFFFFFFFFFFFFF444443333FFFF444433F
 HEX 4444333FF03FC0FFC0FC004444033C0FFFFF44443F
 HEX 4444333F003FC0FFC0F034444C033C0FFFFF44443F
 HEX 444433FFF03FC0FFC0F044444C03FC0FFFFF444433
 HEX 444433FFF03FC0FFC0F444443C0FFC0FFFFF444433
 HEX 444433FFF03FC0C0C04444403C0C0C0FFFFF444433
 HEX 444433FFF03FC00C044444303C00C00FFFFF444433
 HEX 444433FFF03FC0FF444440003C0FFC0FFFFF444433
 HEX F44443FFFFFFFFF444443333FFFFFFFFFFF4444333
 HEX F444433FFFFFFF444443333FFFFFFFFFFFF4444333
 HEX F444443FFFFFF444443333FFFFFFFFFFFF4444433F
 HEX FF444433FFFF444443333FFFFFFFFFFFFF4444333F
 HEX FF444443FFF444443333FFFFFFFFFFFFF44444333F
 HEX FFF44444FF444443333FFFFFFFFFFFFF44444333FF
 HEX FFFF44444444443333FFFFFFFFFFFFF444443333FF
 HEX FFFF4444444443333FFFFFFFFFFFF4444444333FFF
 HEX FFFFF44444444333FFFFFFFFFFF44444444333FFFF
 HEX FFFFFF3444444444FFFFFFFF44444444433333FFFF
 HEX FFFFFFF344444444444444444444444433333FFFFF
 HEX FFFFFFFFF34444444444444444444433333FFFFFFF
 HEX FFFFFFFFFF334444444444444444333333FFFFFFFF
 HEX FFFFFFFFFFFF33344444444443333333FFFFFFFFFF
 HEX FFFFFFFFFFFFF33333333333333333FFFFFFFFFFFF
 HEX FFFFFFFFFFFFFFFF33333333333FFFFFFFFFFFFFFF

 SAV EGG.L

 END
