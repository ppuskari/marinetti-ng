 LST OFF
 mx 0

*=================================================
*
* PPPX.CHAP.S - CHAP implementation for PPP link layers
*
* Copyright (C) 2002-2005 Andrew Roughan
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
* 2002.03.14 AJR - Added support for CHAP with MD5
* 2004.10.24 AJR - Added support for MS-CHAP v1 (based on work from 2002.08.25)
* 2004.10.28 AJR - Added extraction of challenge from MS-CHAP Auth failure
* 2004.11.02 AJR - Added LmChallengeResponse (required by Windows 9x)
* 2005.02.06 AJR - Split CHAP into new source code module for ease of maintenance
*
*=================================================

*-------------------------------------------------
* Handles CHAP state - X = C223
*-------------------------------------------------

HANDLECHAP DBGMSG HANDLECHAP
 LDA #false
 STA USEAUTHFAILURECHALLENGE

 LDA [PPPDGMPTR]
 AND #$FF
 DEC
 BEQL :CHALLENGE ;1
 DEC
 DEC
 BEQL :ACK ;3
 DEC
 BEQ :NAK ;4
 CLC
 RTS

*-------------------------------------------------

:NAK LDA CHAPTYPE
 CMP #$8000 ;MS-CHAP has a way of allowing a retry
 BNEL :NAKNAK

* check for MS-CHAP retry code

 LDY #2
 LDA [PPPDGMPTR],Y
 XBA
 CLC
 SBC #1+1+2 ;Length of Code, Identifier & Length fields
 BEQL :NAKNAK

 TAX ;Message length

 LDA PPPDGMPTR
 CLC
 ADC #4 ;Skip Code, Identifier & Length fields
 STA TEMPDPPTR
 STA ChallengePtr
 LDA PPPDGMPTR+2
 BCC :PGOK
 INC
:PGOK STA TEMPDPPTR+2
 STA ChallengePtr+2

 LDY #0
:FINDR LDA [TEMPDPPTR],Y
 AND #$7F7F
 INY
 DEX
 BEQ :end
 CMP #'R='
 BNE :FINDR
 INY
 DEX

 SEP $20
 LDA [TEMPDPPTR],Y
 AND #$7F
 CMP #'1'
 REP $20
 BNE :end ;If we can't retry, then stop
 INY
 DEX
 BEQ :end

* convert ASCII representation of HEX challenge at PPPDGMPTR into HEX

:FINDC LDA [TEMPDPPTR],Y
 AND #$7F7F
 INY
 DEX
 BEQ :reuse ;C is optional. If no C, re-use old challenge
 CMP #'C='
 BNE :FINDC
 INY
 DEX

 CPX #$0F
 BCC :end ;not enough length left for new challenge

 LDA #0 ;set up index
 PHA

 LDX #8 ;convert 16 ASCII bytes into 8 HEX bytes
]CHALLENGELOOP LDA [TEMPDPPTR],Y
 AND #$7F7F
 SEP $30
 JSR ASCTOHEXNYBBLE
 BCS :BADCODE
 ASL
 ASL
 ASL
 ASL
 STA :store
 XBA
 JSR ASCTOHEXNYBBLE
 BCS :BADCODE
% CLC
 ADC :store
 XBA ;save result
 PLA ;get ChallengePtr index
 PHY ;save TEMPDPPTR index
 TAY
 XBA ;get result back
 STA [TEMPDPPTR],Y ;This is really ChallengePtr!
 TYA
 PLY ;get TEMPDPPTR index
 INC
 PHA ;save ChallengePtr index
 REP $30
 INY
 INY
 DEX
 BNE ]CHALLENGELOOP
 PLA ;discard index

* set up to send new response

 LDA #true
 STA USEAUTHFAILURECHALLENGE
 BRA :CHALLENGE

:store DA 0

:BADCODE REP $30

:end   ;We got unexpected data or end of buffer

:reuse BRA :NAKNAK ;In theory, user should be presented with
 ;opportunity to re-enter password. However, we
 ;don't do this, and there is no point to submit
 ;a response that failed, so exit.

:NAKNAK LDA #terrBADUSERPASS&terrmask
 BRA :JOIN

*-------------------------------------------------

:ACK LDA #true
 STA CHAPDONE
:JOINOK LDA #terrOK
:JOIN PHA
 LDA #false ;Stop looking at CHAPTIMER
 STA CHAPRESPONSESENT
 PHL CHAPRESPONSEHANDLE
 _DisposeHandle ;Remove existing storage
 LDY #2
 LDA [PPPDGMPTR],Y
 XBA
 CLC
 SBC #1+1+2 ;Length of Code, Identifier & Length fields
 BEQ :NOMSG

 TAY ;Message length

 LDA PPPDGMPTR
 CLC
 ADC #4 ;Skip Code, Identifier & Length fields
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

:CHALLENGE
 LDA CHAPRESPONSESENT ;Previous Response not received by host?
 BEQ :BUILDIT
 PHL CHAPRESPONSEHANDLE
 _DisposeHandle ;Remove existing storage

:BUILDIT DBGPPP ReceivedCHAPChallenge
 LDA CHAPTYPE
 CMP #$8000
 BEQL MSCHAPCHALLENGE

*-------------------------------------------------
* Handles CHAP MD5 Challenge
*-------------------------------------------------

:DOMD5
* Build Challenge Stream - Identifier + Secret + ChallengeValue
 DBGPPP BuildCHAPSignon
 ~md5init #MDWORKAREA

 PHL #MDWORKAREA
 LDXA PPPDGMPTR
 INXA ;Pointer to Identifier
 PHXA
 PEA #0
 PEA #1 ;Block Length
 _md5append

 PHL #MDWORKAREA
 LXA PASSWORDPTR
 INXA ;Pointer to Password
 PHXA
 LDA [PASSWORDPTR]
 AND #$FF
 PEA #0
 PHA ;Password size
 _md5append

 PHL #MDWORKAREA

 LDA PPPDGMPTR
 CLC
 ADC #5 ;Pointer to Challenge Value
 TAX
 LDA PPPDGMPTR+2
 PHA
 PHX

 LDY #4
 LDA [PPPDGMPTR],Y ;Challenge Value-Size
 AND #$FF
 PEA #0
 PHA
 _md5append

 PHL #MDWORKAREA
 PHL #MD5DIGEST
 _md5finish

* calculate length of response
* RFC1994 Section 4. Packet Format, Length
* Len: Code, Identifier, Len word, Data Field (Len byte, Hash-len, Username-len)
 LDA #1+1+2+1+MDDIGESTLEN
 SEP #$20
 CLC
 ADC [USERNAMEPTR]
 REP #$20
 PHA ;Save Length for later
 TAY
 JSR CREATERESPONSEBUFF ;Length in Y

 LDA [PPPDGMPTR]
 XBA
 AND #$FF ;Identifier
 JSR SAVERESPONSE
 LDA #0 ;Length of packet (high byte)
 JSR SAVERESPONSE
 PLA ;Saved Length (low byte)
 JSR SAVERESPONSE

 LDA #MDDIGESTLEN ;Value-Size
 JSR SAVERESPONSE

 LDY #0
]L1 LDA MD5DIGEST,Y
 JSR SAVERESPONSE
 INY
 CPY #MDDIGESTLEN
 BNE ]L1

 LDA [USERNAMEPTR]
 AND #$FF
 TAX
 LDY #1
]L1 LDA [USERNAMEPTR],Y
 PHX
 JSR SAVERESPONSE
 PLX
 INY
 DEX
 BNE ]L1

 JSR SENDCHAPRESPONSE

 LDA #terrOK
 CMP #1
 RTS

*-------------------------------------------------
* Handles MS-CHAP v1 Challenge
*-------------------------------------------------

MSCHAPCHALLENGE

 DBGPPP BuildMSCHAPv1Signon

 LXA TEMPDPPTR ;Load from Zero Page
 STXA TEMPDPSTORE ;Save in main memory

 LXA PASSWORDPTR
 INXA ;Pointer to Password
 STX :PWSelfMod+1
 STX :PWSelfMod2+1
 SEP #$20
 STA :PWSelfMod+3
 STA :PWSelfMod2+3
 REP #$20
 LDA [PASSWORDPTR]
 AND #$FF
 STA PWLen ;Password size

 LDA USEAUTHFAILURECHALLENGE
 CMP #true
 BEQ :SKIPCHALPTR

 LDA PPPDGMPTR
 CLC
 ADC #5 ;Create Pointer to Challenge Value
 TAX
 LDA PPPDGMPTR+2
 STXA ChallengePtr
:SKIPCHALPTR

* Calculate length of MS Chap Response Stream

* RFC1994 Section 4. Packet Format, Length
* Len: Code, Identifier, Len word, Data Field (ValueSize byte, Value-len, Username-len)
 SEP #$20
 LDA #1+1+2+1+49
% LDY CHAPTYPE
% CPY #$8000
% BEQ :SKIPV1 ;MS CHAPv1 does not use Name field
 CLC
 ADC [USERNAMEPTR]
:SKIPV1 REP #$20
 PHA ;Save Length for later
 TAY
 JSR CREATERESPONSEBUFF ;Length in Y

 LDA [PPPDGMPTR]
 XBA
 AND #$FF ;Identifier
 JSR SAVERESPONSE
 LDA #0 ;Length of packet (high byte)
 JSR SAVERESPONSE
 PLA ;Saved Length (low byte)
 JSR SAVERESPONSE
 LDA #49 ;Value-size
 JSR SAVERESPONSE

*LmChallengeResponse

*LmPasswordHash
* In: 0-to-14-oem-char Password
* Out: 16-octet PasswordHash

* Set UcasePassword to the uppercased Password
* Zero pas UcasePassword to 14 characters

 LXA #LmPassword
 STXA TEMPDPPTR

 LDX #0
 SEP #$30
 LDA PWLen ;Password size
 BEQ :ZEROFILL
]L5
*self mod is required because of lack of DP space available
:PWSelfMod2 LDAL #$0000,X ;Patched with actual long location of PW
 CMP #'a'
 BCC :SKIPFORCE
 CMP #'z'+1
 BCS :SKIPFORCE
 AND #$DF ;Force Upper Case (same as SEC, SBC #$20)
:SKIPFORCE TXY
 STA [TEMPDPPTR],Y
 INX
 CPX PWLen
 BNE ]L5
:ZEROFILL LDA #0 ;zero fill to max of 14 characters
 TXY
]L4 CPY #14
 BEQ :ZEND
 STA [TEMPDPPTR],Y
 INY
 BRA ]L4
:ZEND REP #$30

* Convert 1st chunk of LmPassword, add parity and create LmPasswordHashPt1
 PHL #LmParityPasswordPt1
 PHL #LmPasswordPt1
 _desAddParity

 PHL #LmPasswordHashPt1
 PHL #LmParityPasswordPt1
 PHL #StdText
 PEA #0 ;Encode
 _desCipher

* Convert 2nd chunk of LmPassword, add parity and create LmPasswordHashPt2
 PHL #LmParityPasswordPt2
 PHL #LmPasswordPt2
 _desAddParity

 PHL #LmPasswordHashPt2
 PHL #LmParityPasswordPt2
 PHL #StdText
 PEA #0 ;Encode
 _desCipher

*ChallengeResponse
* In: Challenge
* In: Password hash
* Out: response

* Padding of Password hash to 21 octets is already performed by data structure

* Convert 1st chunk of Password hash, add parity and create response part 1
 PHL #ParityPasswordHashPt1
 PHL #PasswordHashPt1
 _desAddParity

 PHL #ChallengeResponsePt1
 PHL #ParityPasswordHashPt1
 PHL ChallengePtr
 PEA #0 ;Encode
 _desCipher

* Convert 2nd chunk of Password hash, add parity and create response part 2
 PHL #ParityPasswordHashPt2
 PHL #PasswordHashPt2
 _desAddParity

 PHL #ChallengeResponsePt2
 PHL #ParityPasswordHashPt2
 PHL ChallengePtr
 PEA #0 ;Encode
 _desCipher

* Convert 3rd chunk of Password hash, add parity and create response part 3
 PHL #ParityPasswordHashPt3
 PHL #PasswordHashPt3
 _desAddParity

 PHL #ChallengeResponsePt3
 PHL #ParityPasswordHashPt3
 PHL ChallengePtr
 PEA #0 ;Encode
 _desCipher

* Output LmChallengeResponse
 LDY #0
]L1 LDA ChallengeResponse,Y
 JSR SAVERESPONSE
 INY
 CPY #ChallengeResponseLen
 BNE ]L1

*NtChallengeResponse

 LDA PWLen ;Password size
 BEQL :NULLPASSWORD

 PHA ;Space for result
 PHA
 PEA $0000
 LDA PWLen
 ASL
 PHA ;Size of block = pwlen*2
 PHW MARINETTIUSERID
 PEA %1000_0000_0001_1000 ;Locked, NotCross, NotSpecial
 PEA $0000
 PEA $0000 ;LocationPtr (ignored)
 _NewHandle
 PLXA
 STXA TEMPDPHANDLE
 STXA UNIPWHANDLE
% BCS :MEMORYFULL ;What to do here????

 DEREF TEMPDPHANDLE;TEMPDPPTR ;Careful! these are actually the same locations

*PWtoUnicodePW
* In: PW "MyPw"
* Out: Unicode PW

*Unicode conversion: 'MyPw' -> 'M<null>y<null>P<null>w<null>'
 LDA PWLen
 DEC ;Get index correct for loop count
 TAX
 ASL ;multiply by two
 TAY
]L3
*self mod is required because of lack of DP space available
:PWSelfMod LDAL #$0000,X ;Patched with actual long location of PW
 AND #$FF ;Force Unicode high byte = $00
 STA [TEMPDPPTR],Y
 DEY
 DEY
 DEX
 BPL ]L3

*NtPasswordHash
* In: Unicode PW
* Out: 16 octet password hash
 ~md4init #MDWORKAREA

 PHL #MDWORKAREA
 PHL TEMPDPPTR
 PEA #0
 LDA PWLen
 ASL ;multiply by two
 PHA ;Length of Unicode password
 _md4Append

 PHL #MDWORKAREA
 PHL #PasswordHash
 _md4Finish

 PHL UNIPWHANDLE
 _DisposeHandle

 BRA :SKIPNULL
:NULLPASSWORD
 ~md4init #MDWORKAREA
 PHL #MDWORKAREA
 PHL #PasswordHash
 _md4Finish
:SKIPNULL

*ChallengeResponse
* In: Challenge
* In: Password hash
* Out: response

* Padding of Password hash to 21 octets is already performed by data structure

* Convert 1st chunk of Password hash, add parity and create response part 1
 PHL #ParityPasswordHashPt1
 PHL #PasswordHashPt1
 _desAddParity

 PHL #ChallengeResponsePt1
 PHL #ParityPasswordHashPt1
 PHL ChallengePtr
 PEA #0 ;Encode
 _desCipher

* Convert 2nd chunk of Password hash, add parity and create response part 2
 PHL #ParityPasswordHashPt2
 PHL #PasswordHashPt2
 _desAddParity

 PHL #ChallengeResponsePt2
 PHL #ParityPasswordHashPt2
 PHL ChallengePtr
 PEA #0 ;Encode
 _desCipher

* Convert 3rd chunk of Password hash, add parity and create response part 3
 PHL #ParityPasswordHashPt3
 PHL #PasswordHashPt3
 _desAddParity

 PHL #ChallengeResponsePt3
 PHL #ParityPasswordHashPt3
 PHL ChallengePtr
 PEA #0 ;Encode
 _desCipher

* Output NtChallengeResponse
 LDY #0
]L1 LDA ChallengeResponse,Y
 JSR SAVERESPONSE
 INY
 CPY #ChallengeResponseLen
 BNE ]L1

* Output "Use Windows NT compatible challenge response" Flag
 LDA #1
 JSR SAVERESPONSE

* RFC2433 indicates that Name field is not used for MS CHAP v1
* RFC2759 indicates that the Name field is ASCII for MS CHAP v2
* It is probably the same for MS CHAP v1

% LDY CHAPTYPE
% CPY #$8000
% BEQ :SKIPV1b ;MS CHAPv1 does not use Name field

 LDA [USERNAMEPTR]
 AND #$FF
 TAX
 LDY #1
]L1 LDA [USERNAMEPTR],Y
 PHX
 JSR SAVERESPONSE
 PLX
 INY
 DEX
 BNE ]L1

:SKIPV1b JSR SENDCHAPRESPONSE

 LXA TEMPDPSTORE ;Load from main memory
 STXA TEMPDPPTR ;Restore to Zero Page

 LDA #terrOK
 CMP #1
 RTS

*-------------------------------------------------
* MS CHAP data structures
*-------------------------------------------------

TEMPDPSTORE ADRL 0 ;Used to hold value from DP temporarily
UNIPWHANDLE ADRL 0 ;Handle for Unicode Password memory
PWLen DA 0 ;Length of Ascii password from CDEV
PWPtr ADRL 0 ;Pointer to first byte of Ascii password
USEAUTHFAILURECHALLENGE DA 0

StdText ASC 'KGS!@#$%' ;DesHash known text RFC2433 A.3
ChallengePtr ADRL 0 ;Pointer to Challenge from input stream

LmPassword ;Storage for use by LmPasswordHash operation
LmPasswordPt1 DS 7
LmPasswordPt2 DS 7

LmParityPassword ;Storage for result of AddParity operation
LmParityPasswordPt1 DS 8
LmParityPasswordPt2 DS 8

LmPasswordHash ;Storage for result of LmPasswordHash operation
PasswordHash ;Storage for result of md4 operation (NT)
LmPasswordHashPt1   ;DS 8
PasswordHashPt1 DS 7
PasswordHashPt2 DS 1 ;DS 7
LmPasswordHashPt2 DS 6 ;DS 8
PasswordHashPt3 DS 2 ;DS 7
 HEX 0000000000 ;Padding to 21 Octets.

ParityPasswordHash ;Storage for result of AddParity operation
ParityPasswordHashPt1 DS 8
ParityPasswordHashPt2 DS 8
ParityPasswordHashPt3 DS 8

ChallengeResponse ;Storage for result of DES operation
ChallengeResponsePt1 DS 8
ChallengeResponsePt2 DS 8
ChallengeResponsePt3 DS 8
ChallengeResponseLen EQU *-ChallengeResponse

*-------------------------------------------------
* Subroutines
*-------------------------------------------------

CREATERESPONSEBUFF
* Setup storage area for CHAP Response (in case we need to resend)
 PHA ;Space for result
 PHA
 PEA $0000
 PHY ;Size of block
 PHW MARINETTIUSERID
 PEA %1000_0000_0001_1000 ;Locked, NotCross, NotSpecial
 PEA $0000
 PEA $0000 ;LocationPtr (ignored)
 _NewHandle
 PLXA
 STXA TEMPDPHANDLE
 STXA CHAPRESPONSEHANDLE
% BCS :MEMORYFULL ;What to do here????

 DEREF TEMPDPHANDLE;TEMPDPPTR ;Careful! these are actually the same locations
% LXA TEMPDPPTR
 STX SELFMODA+1
 STX SELFMODB+1
 SEP #$20
 STA SELFMODA+1+2
 STA SELFMODB+1+2
 REP #$20
 LDA #0
 STA CHAPRESPONSEPTR
 RTS

* Routines that call SAVERESPONSE expect Y to be preserved
SAVERESPONSE LDX CHAPRESPONSEPTR
SELFMODA STAL $0000,X
 INX
 STX CHAPRESPONSEPTR
 RTS

SENDCHAPRESPONSE ENT
* Send Hashed Challenge Stream as response
 DBGPPP SendingCHAPSignon
 LDA #$C223
 JSR OPENPACKET
 LDA #2 ;CHAP Response
 JSR OUTCHARCRC

 LDX #0
]LOOP
SELFMODB LDAL $0000,X
 PHX
 JSR OUTCHARCRC
 PLX
 INX
 CPX CHAPRESPONSEPTR
 BNE ]LOOP

 JSL PPPCLOSEPACKET

 LDA #true
 STA CHAPRESPONSESENT

 DBGPPP "...Wait CHAPTimeInterval for ACK or NAK"
 PHS 2
 JSL GETTICK
 PLA
 CLC
 ADC #CHAPTIMEINTERVAL
 STA CHAPTIMER
 PLA
 ADC #^CHAPTIMEINTERVAL
 STA CHAPTIMER+2
 RTS

CHAPRESPONSEHANDLE ADRL 0 ;Used in case response needs to be resent
CHAPRESPONSEPTR DA 0

*-------------------------------------------------
* called with short AXY
*-------------------------------------------------
 mx %11

ASCTOHEXNYBBLE CMP #'0' ;ASC to HEX
 BCC :crap
 CMP #'9'+1
 BCS :tryalpha
 SEC
 SBC #$30 ;'0' -> $0
 BRA :rts
:tryalpha CMP #'F'+1
 BCS :crap
 SEC
 SBC #$37 ;'A' -> $A
:rts CLC
 RTS
:crap SEC
 RTS

 mx 0
