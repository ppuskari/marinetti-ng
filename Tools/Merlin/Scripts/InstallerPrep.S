*
* InstallerPrep.S - Merlin16+ Link File
*
* Read the HowToRelease document for more info on how to use this script
*
* Utility for Marinetti Open Source Project
*
* Copies files to be released from MOSP directory structure to
* packaging directory in preparation for using InstallMagic.
*
* When using the MOSP CVS Repository directory structure as your work area
* you can execute it with the command "link 'tools/merlin/scripts/InstallerPrep".
* To enter a command in Merlin, enter the editor and press Open-Apple-O.
*
* Author: andrew.roughan@writeme.com
*
* 2002-10-08 AJR Initial Release
* 2003-06-10 AJR Changed fork copy settings to be correct
* 2003-07-18 AJR Corrected READ.ME to README.DOC
* 2003-07-24 AJR Corrected README.DOC fork copy flag
*

doDir KBD "Create directory structure? 0=No, 1=Yes"

 do doDir
 CMD CREATE :RAM5:Marinetti
 CMD CREATE :RAM5:Marinetti:CDevs
 CMD CREATE :RAM5:Marinetti:System.Setup
 CMD CREATE :RAM5:Marinetti:Tools
 CMD CREATE :RAM5:Marinetti:TCPIP
 CMD CREATE :RAM5:Marinetti:Icons
 CMD CREATE :RAM5:Marinetti:Applications
 CMD CREATE :RAM5:Marinetti:Documentation
 fin

 CMD COPYFORK Marinetti:Documentation:README.DOC :RAM5:Marinetti:README.DOC -b -l -7
 CMD COPYFORK ChangeLog :RAM5:Marinetti:CHANGES -d -l -7
 CMD COPYFORK *:System:Cdevs:TCPIP :RAM5:Marinetti:CDevs:TCPIP -r -l
 CMD COPYFORK *:System:System.Setup:TCPIP :RAM5:Marinetti:System.Setup:TCPIP -b -l
 CMD COPYFORK *:System:Tools:Tool054 :RAM5:Marinetti:Tools:Tool054 -d -l
 CMD COPYFORK *:System:TCPIP:MacIP :RAM5:Marinetti:TCPIP:MacIP -b -l
 CMD COPYFORK *:System:TCPIP:PPP :RAM5:Marinetti:TCPIP:PPP -b -l
 CMD COPYFORK *:System:TCPIP:SLIP :RAM5:Marinetti:TCPIP:SLIP -b -l
 CMD COPYFORK *:System:TCPIP:PPP.scripted :RAM5:Marinetti:TCPIP:PPP.scripted -b -l
 CMD COPYFORK *:System:TCPIP:Direct.Connect :RAM5:Marinetti:TCPIP:Direct.Connect -b -l
 CMD COPYFORK *:Icons:Ftype.TCPIP :RAM5:Marinetti:Icons:Ftype.TCPIP -d -l
 CMD COPYFORK Applications:Telnet:Telnet :RAM5:Marinetti:Applications:Telnet -d -l
 CMD COPYFORK Applications:Casper:Casper :RAM5:Marinetti:Applications:Casper -b -l
 CMD COPYFORK Marinetti:Documentation:DirConnect.DOC :RAM5:Marinetti:Documentation:DirConnect.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:Marinetti.DOC :RAM5:Marinetti:Documentation:Marinetti.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:PPP.DOC :RAM5:Marinetti:Documentation:PPP.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:PPP.Script.DOC :RAM5:Marinetti:Documentation:PPP.Script.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:SLIP.DOC :RAM5:Marinetti:Documentation:SLIP.DOC -b -l
 CMD COPYFORK Marinetti:Documentation:MacIP.DOC :RAM5:Marinetti:Documentation:MacIP.DOC -b -l
