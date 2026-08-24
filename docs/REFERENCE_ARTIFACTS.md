# Reference artifact inventory

Inventory date: 2026-08-24

The originals listed here are stored locally in `incoming/` and ignored by Git. They were tested for archive integrity with CiderPress II 1.2.0. Analysis copies were extracted under ignored `analysis/` directories in both AppleDouble and NAPS forms so resource forks and Apple IIgs file metadata are preserved.

## Uploaded originals

| File | Bytes | SHA-256 | Identification |
| --- | ---: | --- | --- |
| `EmulatorLL.zip` | 21,676 | `65CA53C5D30E610DBB9D804A9EBBE6B3190552F695CF86770438519FCE9521EA` | ORCA/M emulator link-layer source package |
| `link_layer_manual.pdf` | 5,953,394 | `468AC981DE78BC0FD9244B7B6DB79FFB3011E45A379DFDD929C8B60383715CDA` | Link-layer manual with copyright and configuration terms |
| `mar2.0.1.bxy` | 109,824 | `453DE6B40711E5E3F97388245E69C45AC1E4CC25C8D1F2712C330E33CE62A2D3` | Marinetti 2.0.1 installer |
| `Mar30ProgGuide.pdf` | 1,387,145 | `BCA4716BD403EA6D485BA951A78446D93053C05F56A6FFC0AEB3ABE58D3E29CC` | Marinetti 3.0 Programmer's Guide |
| `Marinetti_abstraction.gif` | 9,059 | `DFD8E08688660387AC1D0D4D2A84624A66957C1B1BD16FED635CABBE3A74638A` | Stack/module diagram |
| `Marinetti3.0b1.SHK` | 141,837 | `59076F89DCE0B70E3E96BE55E7446E1A4ABFB8B2FE3D52687EB049866BD8CD6A` | Marinetti 3.0b1 installer |
| `sweet16ll.bxy` | 6,144 | `C342879A088CC8A8E4848D21F3E98680EA5C58844B27CF3FBEB37DE60F2EC15C` | Sweet16 link layer 1.0.6 |
| `TCPIP30b11.SHK` | 35,486 | `1D32B759C2FC6C557443081DEBB5A515649E0D6FE5FA27BC98834C220C2AA902` | TCPIP Init 3.0b11 plus changelog |
| `uthernet2ll.bxy` | 6,528 | `F124C73789804294DD92D7377B460447BF1BE09E0130E6C2B7E4F3100613EED3` | Uthernet II link layer 2.0.5 |
| `uthernetll.bxy` | 6,400 | `26CD7D6891A0AB5970D54EA89AA67A281879006269C9AF18236F90BB8077FAF0` | Original Uthernet link layer 1.0.5 |

## Extracted binary fingerprints

The NAPS suffix encodes ProDOS file type and auxiliary type. A trailing `r` identifies a resource fork.

| Payload | Type / aux | Data bytes | Data SHA-256 | Resource bytes | Resource SHA-256 |
| --- | --- | ---: | --- | ---: | --- |
| Marinetti 2.0.1 installer | `S16/$DB02` | 12,242 | `08518B57E432C3ECFFE857938FE5518897813E10BBC8195C0EDDDDA95757BBB6` | 105,133 | `E689F3A6D3D508C3719E2FFE7BE4FAE075B7DC767D1BBAE0C9BCB875F7547F6F` |
| Marinetti 3.0b1 installer | `S16/$DB02` | 12,242 | `08518B57E432C3ECFFE857938FE5518897813E10BBC8195C0EDDDDA95757BBB6` | 139,264 | `DC410D1212CFBECAC0E62875D65FB0A406C8D8BDBC35E9ED9972C68CE9B80CEA` |
| Sweet16 | `LDF/$4083` | 10,065 | `4B079293A6330B463A37C46D5C6A9CDB0987719FF16B8B797AB34AA61A839634` | 744 | `E3CFD97370088D132AD2D6DD8A3199BD78F3085514F29CEFBE13162A062D9AAA` |
| TCPIP | `PIF/$0000` | 39,810 | `DE6AEECA9A40D940D3D1A9C93EB8F2C576F063A05549587A71F8F8251F20306D` | 592 | `4F70B3CF43A0DEE068070350B50AE50689C564329C7CD0C3BA686CE1583EDC6B` |
| Uthernet II | `LDF/$4083` | 10,841 | `27E76E68E5F770EDE7389A250CD0125EE63F14D0D3D03479686B04BC8C5AEBC2` | 753 | `235E215FF43EE84B994AE105FA7B74D2CDD3ECDDD6B68FE0334362D5C8D47E1A` |
| Uthernet | `LDF/$4083` | 10,648 | `92390A93004E47B778744CCEC04E0518CBB199F3658E961DF71B729ED2F4F817` | 752 | `1AA0B342C534EC2EAE6C1C2F3F34C57ACC58D07DD12DE1CE4ADF09FD8A9805FD` |

The Marinetti 2.0.1 and 3.0b1 installers use the same 12,242-byte installer executable; their installable content differs in their resource forks.

## Version/resource confirmation

- TCPIP archive metadata identifies release 3.0b11 dated 2019-07-17. Its OMF payload has eight segments: `TCPIP`, `TCP`, `DNR`, `UDP`, `IP`, `Dispatcher`, `Preference`, and `Library`.
- Uthernet II's version resource identifies `Uthernet v2.0.5`, copyright 2006-2024 Ewen Wannop.
- Original Uthernet's version resource identifies `Uthernet v1.0.5`, copyright 2006-2024 Ewen Wannop.
- Sweet16's version resource identifies version 1.0.6, copyright 2006-2024 Ewen Wannop.

## Source and redistribution status

`EmulatorLL.zip` contains `emulator.asm`, `emulator.macros`, and an assembly driver. The source header explicitly licenses the module under LGPL 2.1 or later and records its derivation from the Direct Connect link layer, the original Uthernet work, and BSD-licensed ip65 code. This is a useful link-layer structure reference and a candidate for a separately documented source import.

The uploaded link-layer manual states that the Uthernet, Uthernet II, and Sweet16 link layers are freeware, restricts electronic distribution/archiving, and requires advance permission from Ewen Wannop for free distribution. Those binary artifacts, their resource forks, and local disassemblies must remain untracked unless permission is obtained.

## TCPIP 3.0b5-to-3.0b11 gap

The 3.0b11 archive's changelog identifies these post-3.0b5 changes that are not represented by the recovered root changelog:

- 3.0b6: `LOOKFORDELIMIT` receive-size calculation, `TCPREAD` more-flag handling, stack imbalances in `INITIAL_CLOSED` and `INITIAL_SYNSENT`, and ICMP echo reply address/data handling.
- 3.0b7: `LOOKFORDELIMIT` at end of buffer.
- 3.0b8: `GETNEXTINQUEUE` performance offset, TCP reads returning closing-with-data, and `TCPIPCancelDNR` raw-stack parameter comparison.
- 3.0b9: removal of pointer-to-pointer checking that degraded performance.
- 3.0b10: direct-page/bank handling in `IPSENDDATAGRAM`, `TCPIPReadLineTCP` return behavior, error-table length, disabling `TCPTOSSUNCLAIMED`, `LOOKFORDELIMIT` push flag/offset, and TCP MSS option generation.
- 3.0b11: corrected `TCPIPReadLineTCP` TCP error value and combined the two 3.0b10 codebases.

These entries provide a bounded source-recovery checklist before optimization begins.

