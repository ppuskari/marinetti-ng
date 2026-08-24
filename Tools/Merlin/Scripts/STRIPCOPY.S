*
* StripCopy.S - Merlin16+ link file
*
* Utility for Marinetti Open Source Project
*
* Creates the MOSP CVS Repository directory structure on RAM5
* Copies CVS controlled objects from work area to MOSP directory structure
* Strips High Bits from Merlin source files
*
* This file expects to be executed from the Marinetti root work area.
* When using the MOSP CVS Repository directory structure as your work area
* you can execute it with the command "link 'tools/merlin/scripts/stripcopy".
* To enter a command in Merlin, enter the editor and press Open-Apple-O.
*
* Useful for moving sources from development directory on IIgs
* in preparation for exporting to a Macintosh in anticipation
* of updating a CVS directory structure.
*
* For example:
* I have a development environment within Bernie. I use a Ram disk defined on
* the Mac and mount it in Bernie as RAM5. I use MacCVSClient to checkout
* the MOSP Module onto my hard disk and then copy the MOSP hierarchy to RAM5.
* I start Bernie and copy MOSP hierarchy off RAM5 into work area.
* I work in Merlin and when done, I copy files back to RAM5 with this script
* (without creating the structure) and then quit Bernie. I copy the files
* from RAM5 into the CVS work area and then I Launch MacCVSClient.
* Upon entry, all files are marked as changed. I perform a CVS Update on the
* CVS Work Area and this leaves only the files that I actually changed marked
* as changed. (Because of an issue with file import/export translation, some
* binary files that havent been changed are marked as changed. To fix this
* I just check them out again. I dont know how to prevent this. Do you?)
* I then perform CVS Add or CVS Commit to place my changed files into the
* MOSP CVS Repository on Sourceforge.Net.
*
* Author: andrew.roughan@writeme.com
*
* 2002-03-11 MOSP3.0d1 File and directory set
* 2002-03-12 MOSP3.0d2 File and directory set
* 2002-03-12 MOSP3.0d4 File and directory set
* 2002-03-12 Update for release of I.QLIB
* 2002-03-12 Update for release of PPP and PPPX Link Layers
* 2002-03-13 Patch to correct placement of Casper Subroutine Libraries
* 2002-03-13 MOSP3.0d5 File and directory set
* 2002-03-13 Update for patch of PPP and PPPX Link Layers
* 2002-03-13 Add CopyObject script and PrepareDevEnv document
* 2002-03-14 Add Shownodes.
* 2002-03-18 Add HashTool macro library
* 2002-04-02 Add I.IPC (was meant to be part of 3.0d5 but not delivered)
* 2002-07-02 Add I.PATCH (workaround for entry point on segment boundary)
* 2002-09-01 Add Cryptotool macro library & source files
* 2002-09-05 Update for release of TELNET
* 2002-10-02 Add I.DISPATCH
* 2002-10-02 Update for release of MacIP Link Layer
* 2002-10-05 Add VersionNumbers document (forgotten in March)
* 2003-04-21 Update for release of DC and SLIP Link Layers
* 2003-05-31 Update for release of Orca.C/M/Pascal & GSoftBASIC interface files
* 2003-05-31 Add NiftyList interface file
* 2003-06-15 Add HowToRelease document, InstallerPrep script & InstallMagic files
* 2003-06-30 Update for release of I.INIT
* 2003-07-05 Update for release of MacIP.DOC
* 2003-07-05 Add Readme files for Merlin directories (forgotten in 2002-03)
* 2003-07-13 Add Changelog files for Telnet and Casper (forgotten in 2002-12)
* 2003-07-18 Add CreateObjRel script
* 2003-07-18 Add internal versions of language interface files
* 2005-03-27 Add PPPx.CHAP
* 2005-03-28 Add I.TCP
* 2005-04-14 Add I.IP
* 2005-07-11 Add I.CALLS, I.DNR, I.FRAG, I.PREFS, I.UDP
* 2005-07-17 Remove I.PATCH (has been integrated into I.DNR)
* 2007-06-24 Add files for CDEV
* 2007-06-25 Add files for TCP Snooper
* 2008-01-13 Add CompletePascal interface files
* 2008-01-27 Split I.TCP into I.TCP.DEBUG
* 2008-02-10 Add GSBug TCPIP.Templates file
* 2013-06-29 Add files for Toolstub
* 2013-07-03 Add Icons folder and filetype file
*

doDir KBD "Create directory structure? 0=No, 1=Yes"

 do doDir
 CMD CREATE :RAM5:MOSP
 CMD CREATE :RAM5:MOSP:Applications
 CMD CREATE :RAM5:MOSP:Applications:Casper
 CMD CREATE :RAM5:MOSP:Applications:Telnet
 CMD CREATE :RAM5:MOSP:Marinetti
 CMD CREATE :RAM5:MOSP:Marinetti:CDev
 CMD CREATE :RAM5:MOSP:Marinetti:Documentation
 CMD CREATE :RAM5:MOSP:Marinetti:Equates
 CMD CREATE :RAM5:MOSP:Marinetti:Icons
 CMD CREATE :RAM5:MOSP:Marinetti:Init
 CMD CREATE :RAM5:MOSP:Marinetti:LinkLayers
 CMD CREATE :RAM5:MOSP:Marinetti:LinkLayers:DC
 CMD CREATE :RAM5:MOSP:Marinetti:LinkLayers:MACIP
 CMD CREATE :RAM5:MOSP:Marinetti:LinkLayers:PPP
 CMD CREATE :RAM5:MOSP:Marinetti:LinkLayers:PPPX
 CMD CREATE :RAM5:MOSP:Marinetti:LinkLayers:SLIP
 CMD CREATE :RAM5:MOSP:Marinetti:Toolstub
 CMD CREATE :RAM5:MOSP:Tools
 CMD CREATE :RAM5:MOSP:Tools:CompletePascal
 CMD CREATE :RAM5:MOSP:Tools:GSBug
 CMD CREATE :RAM5:MOSP:Tools:GSoftBASIC
 CMD CREATE :RAM5:MOSP:Tools:InstallMagic
 CMD CREATE :RAM5:MOSP:Tools:Merlin
 CMD CREATE :RAM5:MOSP:Tools:Merlin:Commands
 CMD CREATE :RAM5:MOSP:Tools:Merlin:Help.Files
 CMD CREATE :RAM5:MOSP:Tools:Merlin:Library
 CMD CREATE :RAM5:MOSP:Tools:Merlin:Macros
 CMD CREATE :RAM5:MOSP:Tools:Merlin:Scripts
 CMD CREATE :RAM5:MOSP:Tools:NiftyList
 CMD CREATE :RAM5:MOSP:Tools:Orca.C
 CMD CREATE :RAM5:MOSP:Tools:Orca.M
 CMD CREATE :RAM5:MOSP:Tools:Orca.Pascal
 CMD CREATE :RAM5:MOSP:Tools:System
 CMD CREATE :RAM5:MOSP:Tools:System:Crypto
 CMD CREATE :RAM5:MOSP:Utilities
 CMD CREATE :RAM5:MOSP:Utilities:ShowNodes
 CMD CREATE :RAM5:MOSP:Utilities:TCPSnooper
 fin

 CMD COPYFORK HowToBuild :RAM5:MOSP:HowToBuild -d -7 -l
 CMD COPYFORK HowToRelease :RAM5:MOSP:HowToRelease -d -7 -l
 CMD COPYFORK ChangeLog :RAM5:MOSP:ChangeLog -d -7 -l
 CMD COPYFORK PrepareDevEnv :RAM5:MOSP:PrepareDevEnv -d -7 -l
 CMD COPYFORK ReleaseNotes :RAM5:MOSP:ReleaseNotes -d -7 -l
 CMD COPYFORK README :RAM5:MOSP:README -d -7 -l
 CMD COPYFORK VersionNumbers :RAM5:MOSP:VersionNumbers -d -7 -l
 CMD COPYFORK Applications:Casper:Casper.LNK.S :RAM5:MOSP:Applications:Casper:Casper.LNK.S -d -7 -l
 CMD COPYFORK Applications:Casper:Casper.RES :RAM5:MOSP:Applications:Casper:Casper.RES -r -l
 CMD COPYFORK Applications:Casper:Casper.S :RAM5:MOSP:Applications:Casper:Casper.S -d -7 -l
 CMD COPYFORK Applications:Casper:Changelog :RAM5:MOSP:Applications:Casper:Changelog -d -7 -l
 CMD COPYFORK Applications:Telnet:Changelog :RAM5:MOSP:Applications:Telnet:Changelog -d -7 -l
 CMD COPYFORK Applications:Telnet:Telnet.S :RAM5:MOSP:Applications:Telnet:Telnet.S -d -7 -l
 CMD COPYFORK Marinetti:CDev:C.S :RAM5:MOSP:Marinetti:CDev:C.S -d -7 -l
 CMD COPYFORK Marinetti:CDev:C.ALL.S :RAM5:MOSP:Marinetti:CDev:C.ALL.S -d -7 -l
 CMD COPYFORK Marinetti:CDev:C.INIT.S :RAM5:MOSP:Marinetti:CDev:C.INIT.S -d -7 -l
 CMD COPYFORK Marinetti:CDev:C.MODS.S :RAM5:MOSP:Marinetti:CDev:C.MODS.S -d -7 -l
 CMD COPYFORK Marinetti:CDev:C.SETDEFBUT.S :RAM5:MOSP:Marinetti:CDev:C.SETDEFBUT.S -d -7 -l
 CMD COPYFORK Marinetti:CDev:C.RES :RAM5:MOSP:Marinetti:CDev:C.RES -r -l
 CMD COPYFORK Marinetti:CDev:EGG.S :RAM5:MOSP:Marinetti:CDev:EGG.S -d -7 -l
 CMD COPYFORK Marinetti:CDev:EGG.LINK.S :RAM5:MOSP:Marinetti:CDev:EGG.LINK.S -d -7 -l
 CMD COPYFORK Marinetti:CDev:EGG.MOD.S :RAM5:MOSP:Marinetti:CDev:EGG.MOD.S -d -7 -l
 CMD COPYFORK Marinetti:Documentation:DirConnect.DOC :RAM5:MOSP:Marinetti:Documentation:DirConnect.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:MacIP.DOC :RAM5:MOSP:Marinetti:Documentation:MacIP.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:Marinetti.DOC :RAM5:MOSP:Marinetti:Documentation:Marinetti.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:PPP.DOC :RAM5:MOSP:Marinetti:Documentation:PPP.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:PPP.Script.DOC :RAM5:MOSP:Marinetti:Documentation:PPP.Script.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:README.DOC :RAM5:MOSP:Marinetti:Documentation:README.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:SLIP.DOC :RAM5:MOSP:Marinetti:Documentation:SLIP.DOC -b -l
 CMD COPYFORK Marinetti:Equates:Build.EQU.S :RAM5:MOSP:Marinetti:Equates:Build.EQU.S -d -7 -l
 CMD COPYFORK Marinetti:Equates:I.EQU.S :RAM5:MOSP:Marinetti:Equates:I.EQU.S -d -7 -l
 CMD COPYFORK Marinetti:Equates:TCPIP.EQU.S :RAM5:MOSP:Marinetti:Equates:TCPIP.EQU.S -d -7 -l
 CMD COPYFORK Marinetti:Icons:FTYPE.TCPIP :RAM5:MOSP:Marinetti:Icons:FTYPE.TCPIP -d -l
 CMD COPYFORK Marinetti:Init:I.ALL.S :RAM5:MOSP:Marinetti:Init:I.ALL.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.CALLS.S :RAM5:MOSP:Marinetti:Init:I.CALLS.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.DISPATCH.S :RAM5:MOSP:Marinetti:Init:I.DISPATCH.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.DNR.S :RAM5:MOSP:Marinetti:Init:I.DNR.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.FRAG.S :RAM5:MOSP:Marinetti:Init:I.FRAG.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.ICMP.S :RAM5:MOSP:Marinetti:Init:I.ICMP.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.INIT.S :RAM5:MOSP:Marinetti:Init:I.INIT.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.IP.S :RAM5:MOSP:Marinetti:Init:I.IP.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.IPC.S :RAM5:MOSP:Marinetti:Init:I.IPC.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.LIB.S :RAM5:MOSP:Marinetti:Init:I.LIB.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.MODS.S :RAM5:MOSP:Marinetti:Init:I.MODS.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.PREFS.S :RAM5:MOSP:Marinetti:Init:I.PREFS.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.QLIB.S :RAM5:MOSP:Marinetti:Init:I.QLIB.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.S :RAM5:MOSP:Marinetti:Init:I.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.TCP.S :RAM5:MOSP:Marinetti:Init:I.TCP.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.TCP.DEBUG.S :RAM5:MOSP:Marinetti:Init:I.TCP.DEBUG.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.UDP.S :RAM5:MOSP:Marinetti:Init:I.UDP.S -d -7 -l
 CMD COPYFORK Marinetti:Init:I.RES :RAM5:MOSP:Marinetti:Init:I.RES -r -l
 CMD COPYFORK Marinetti:LinkLayers:DC:ChangeLog :RAM5:MOSP:Marinetti:LinkLayers:DC:ChangeLog -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:DC:DC.S :RAM5:MOSP:Marinetti:LinkLayers:DC:DC.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:DC:DC.ALL.S :RAM5:MOSP:Marinetti:LinkLayers:DC:DC.ALL.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:DC:DC.CODE.S :RAM5:MOSP:Marinetti:LinkLayers:DC:DC.CODE.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:DC:DC.CONFIG.S :RAM5:MOSP:Marinetti:LinkLayers:DC:DC.CONFIG.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:DC:DC.MODS.S :RAM5:MOSP:Marinetti:LinkLayers:DC:DC.MODS.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:DC:DC.RES :RAM5:MOSP:Marinetti:LinkLayers:DC:DC.RES -r -l
 CMD COPYFORK Marinetti:LinkLayers:MACIP:ChangeLog :RAM5:MOSP:Marinetti:LinkLayers:MACIP:ChangeLog -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:MACIP:MacIP.S :RAM5:MOSP:Marinetti:LinkLayers:MACIP:MacIP.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:MACIP:MacIP.ALL.S :RAM5:MOSP:Marinetti:LinkLayers:MACIP:MacIP.ALL.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:MACIP:MacIP.CODE.S :RAM5:MOSP:Marinetti:LinkLayers:MACIP:MacIP.CODE.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:MACIP:MacIP.MODS.S :RAM5:MOSP:Marinetti:LinkLayers:MACIP:MacIP.MODS.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:MACIP:MacIP.RES :RAM5:MOSP:Marinetti:LinkLayers:MACIP:MacIP.RES -r -l
 CMD COPYFORK Marinetti:LinkLayers:PPP:ChangeLog :RAM5:MOSP:Marinetti:LinkLayers:PPP:ChangeLog -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPP:PPP.S :RAM5:MOSP:Marinetti:LinkLayers:PPP:PPP.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPP:PPP.ALL.S :RAM5:MOSP:Marinetti:LinkLayers:PPP:PPP.ALL.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPP:PPP.CODE.S :RAM5:MOSP:Marinetti:LinkLayers:PPP:PPP.CODE.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPP:PPP.CONFIG.S :RAM5:MOSP:Marinetti:LinkLayers:PPP:PPP.CONFIG.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPP:PPP.MODS.S :RAM5:MOSP:Marinetti:LinkLayers:PPP:PPP.MODS.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPP:PPP.RES :RAM5:MOSP:Marinetti:LinkLayers:PPP:PPP.RES -r -l
 CMD COPYFORK Marinetti:LinkLayers:PPPX:ChangeLog :RAM5:MOSP:Marinetti:LinkLayers:PPPX:ChangeLog -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPPX:PPPx.S :RAM5:MOSP:Marinetti:LinkLayers:PPPX:PPPx.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPPX:PPPx.ALL.S :RAM5:MOSP:Marinetti:LinkLayers:PPPX:PPPx.ALL.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPPX:PPPx.CHAP.S :RAM5:MOSP:Marinetti:LinkLayers:PPPX:PPPx.CHAP.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPPX:PPPx.CODE.S :RAM5:MOSP:Marinetti:LinkLayers:PPPX:PPPx.CODE.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPPX:PPPx.CONFIG.S :RAM5:MOSP:Marinetti:LinkLayers:PPPX:PPPx.CONFIG.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPPX:PPPx.MODS.S :RAM5:MOSP:Marinetti:LinkLayers:PPPX:PPPx.MODS.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:PPPX:PPPx.RES :RAM5:MOSP:Marinetti:LinkLayers:PPPX:PPPx.RES -r -l
 CMD COPYFORK Marinetti:LinkLayers:SLIP:ChangeLog :RAM5:MOSP:Marinetti:LinkLayers:SLIP:ChangeLog -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:SLIP:SLIP.S :RAM5:MOSP:Marinetti:LinkLayers:SLIP:SLIP.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:SLIP:SLIP.ALL.S :RAM5:MOSP:Marinetti:LinkLayers:SLIP:SLIP.ALL.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:SLIP:SLIP.CODE.S :RAM5:MOSP:Marinetti:LinkLayers:SLIP:SLIP.CODE.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:SLIP:SLIP.CONFIG.S :RAM5:MOSP:Marinetti:LinkLayers:SLIP:SLIP.CONFIG.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:SLIP:SLIP.MODS.S :RAM5:MOSP:Marinetti:LinkLayers:SLIP:SLIP.MODS.S -d -7 -l
 CMD COPYFORK Marinetti:LinkLayers:SLIP:SLIP.RES :RAM5:MOSP:Marinetti:LinkLayers:SLIP:SLIP.RES -r -l
 CMD COPYFORK Marinetti:Toolstub:Tool054.S :RAM5:MOSP:Marinetti:Toolstub:Tool054.S -d -7 -l
 CMD COPYFORK Tools:CompletePascal:tcpip.p :RAM5:MOSP:Tools:CompletePascal:tcpip.p -d -7 -l
 CMD COPYFORK Tools:CompletePascal:tcpipx.p :RAM5:MOSP:Tools:CompletePascal:tcpipx.p -d -7 -l
 CMD COPYFORK Tools:GSBug:TCPIP.Templates :RAM5:MOSP:Tools:GSBug:TCPIP.Templates -d -7 -l
 CMD COPYFORK Tools:GSoftBASIC:tcpip.int :RAM5:MOSP:Tools:GSoftBASIC:tcpip.int -d -7 -l
 CMD COPYFORK Tools:GSoftBASIC:tcpipx.int :RAM5:MOSP:Tools:GSoftBASIC:tcpipx.int -d -7 -l
 CMD COPYFORK Tools:InstallMagic:MarinettiFiles :RAM5:MOSP:Tools:InstallMagic:MarinettiFiles -d -7 -l
 CMD COPYFORK Tools:InstallMagic:MarinettiScript :RAM5:MOSP:Tools:InstallMagic:MarinettiScript -d -7 -l
 CMD COPYFORK Tools:InstallMagic:MarinettiRes :RAM5:MOSP:Tools:InstallMagic:MarinettiRes -r -l
 CMD COPYFORK Tools:Merlin:Library:ADDPSTRHANDLE :RAM5:MOSP:Tools:Merlin:Library:ADDPSTRHANDLE -d -l
 CMD COPYFORK Tools:Merlin:Library:CLSTRIP :RAM5:MOSP:Tools:Merlin:Library:CLSTRIP -d -l
 CMD COPYFORK Tools:Merlin:Library:Readme :RAM5:MOSP:Tools:Merlin:Library:Readme -d -7 -l
 CMD COPYFORK Tools:Merlin:Commands:COPYFORK :RAM5:MOSP:Tools:Merlin:Commands:COPYFORK -d -l
 CMD COPYFORK Tools:Merlin:Commands:Readme :RAM5:MOSP:Tools:Merlin:Commands:Readme -d -7 -l
 CMD COPYFORK Tools:Merlin:Help.Files:COPYFORK :RAM5:MOSP:Tools:Merlin:Help.Files:COPYFORK -d -l
 CMD COPYFORK Tools:Merlin:Help.Files:Readme :RAM5:MOSP:Tools:Merlin:Help.Files:Readme -d -7 -l
 CMD COPYFORK Tools:Merlin:Macros:CRYPTO.MACS.S :RAM5:MOSP:Tools:Merlin:Macros:CRYPTO.MACS.S -d -7 -l
 CMD COPYFORK Tools:Merlin:Macros:HASHTOOL.MACS.S :RAM5:MOSP:Tools:Merlin:Macros:HASHTOOL.MACS.S -d -7 -l
 CMD COPYFORK Tools:Merlin:Macros:Readme :RAM5:MOSP:Tools:Merlin:Macros:Readme -d -7 -l
 CMD COPYFORK Tools:Merlin:Macros:RJBUTIL.MACS.S :RAM5:MOSP:Tools:Merlin:Macros:RJBUTIL.MACS.S -d -7 -l
 CMD COPYFORK Tools:Merlin:Macros:TCPIP.MACS.S :RAM5:MOSP:Tools:Merlin:Macros:TCPIP.MACS.S -d -7 -l
 CMD COPYFORK Tools:Merlin:Macros:TCPIPX.MACS.S :RAM5:MOSP:Tools:Merlin:Macros:TCPIPX.MACS.S -d -7 -l
 CMD COPYFORK Tools:Merlin:Scripts:COPYOBJECT.S :RAM5:MOSP:Tools:Merlin:Scripts:COPYOBJECT.S -d -7 -l
 CMD COPYFORK Tools:Merlin:Scripts:CreateObjRel.S :RAM5:MOSP:Tools:Merlin:Scripts:CreateObjRel.S -d -7 -l
 CMD COPYFORK Tools:Merlin:Scripts:InstallerPrep.S :RAM5:MOSP:Tools:Merlin:Scripts:InstallerPrep.S -d -7 -l
 CMD COPYFORK Tools:Merlin:Scripts:STRIPCOPY.S :RAM5:MOSP:Tools:Merlin:Scripts:STRIPCOPY.S -d -7 -l
 CMD COPYFORK Tools:NiftyList:nl.marinetti :RAM5:MOSP:Tools:NiftyList:nl.marinetti -d -7 -l
 CMD COPYFORK Tools:Orca.C:tcpip.h :RAM5:MOSP:Tools:Orca.C:tcpip.h -d -7 -l
 CMD COPYFORK Tools:Orca.C:tcpipx.h :RAM5:MOSP:Tools:Orca.C:tcpipx.h -d -7 -l
 CMD COPYFORK Tools:Orca.M:e16.tcpip :RAM5:MOSP:Tools:Orca.M:e16.tcpip -d -7 -l
 CMD COPYFORK Tools:Orca.M:m16.tcpip :RAM5:MOSP:Tools:Orca.M:m16.tcpip -d -7 -l
 CMD COPYFORK Tools:Orca.M:m16.tcpipx :RAM5:MOSP:Tools:Orca.M:m16.tcpipx -d -7 -l
 CMD COPYFORK Tools:Orca.Pascal:tcpip.pas :RAM5:MOSP:Tools:Orca.Pascal:tcpip.pas -d -7 -l
 CMD COPYFORK Tools:Orca.Pascal:tcpipx.pas :RAM5:MOSP:Tools:Orca.Pascal:tcpipx.pas -d -7 -l
 CMD COPYFORK Tools:System:Crypto:CRYPTO.TOOL.S :RAM5:MOSP:Tools:System:Crypto:CRYPTO.TOOL.S -d -7 -l
 CMD COPYFORK Tools:System:Crypto:CRYPTO.LNK.S :RAM5:MOSP:Tools:System:Crypto:CRYPTO.LNK.S -d -7 -l
 CMD COPYFORK Tools:System:Crypto:CryptoTool.DOC :RAM5:MOSP:Tools:System:Crypto:CryptoTool.DOC -b -l
 CMD COPYFORK Utilities:ShowNodes:SHOWNODES.S :RAM5:MOSP:Utilities:ShowNodes:SHOWNODES.S -d -7 -l
 CMD COPYFORK Utilities:TCPSnooper:cda.asm :RAM5:MOSP:Utilities:TCPSnooper:cda.asm -d -7 -l
 CMD COPYFORK Utilities:TCPSnooper:debug.c :RAM5:MOSP:Utilities:TCPSnooper:debug.c -d -7 -l
 CMD COPYFORK Utilities:TCPSnooper:netstat.c :RAM5:MOSP:Utilities:TCPSnooper:netstat.c -d -7 -l
 CMD COPYFORK Utilities:TCPSnooper:nscda.c :RAM5:MOSP:Utilities:TCPSnooper:nscda.c -d -7 -l
 CMD COPYFORK Utilities:TCPSnooper:makefile.mk :RAM5:MOSP:Utilities:TCPSnooper:makefile.mk -d -7 -l
 CMD COPYFORK Utilities:TCPSnooper:readme :RAM5:MOSP:Utilities:TCPSnooper:readme -d -7 -l
 CMD COPYFORK Utilities:TCPSnooper:ur.c :RAM5:MOSP:Utilities:TCPSnooper:ur.c -d -7 -l
