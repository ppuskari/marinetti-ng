# Source and licensing audit

Audit date: 2026-08-24

## Marinetti Open Source Project

Authoritative locations:

- [Marinetti home page](https://www.apple2.org/marinetti/index.html)
- [Marinetti project on SourceForge](https://sourceforge.net/projects/marinetti/)
- [SourceForge source-code downloads](https://sourceforge.net/projects/marinetti/files/Source%20code/)
- [Archived CVS repository download](https://sourceforge.net/code-snapshots/cvs/m/ma/marinetti.zip)

SourceForge removed its CVS service in 2025 and now provides repository archives. This repository's initial upstream tree was extracted from the head revisions of the `MOSP` module in that archive.

The upstream root `LICENCE` is GNU LGPL version 2.1, and the principal source modules carry notices permitting use under LGPL 2.1 or, at the recipient's option, a later version.

Important completeness limits recorded by upstream:

- `PrepareDevEnv` says not all source files were released and that intermediate build files were required.
- `HowToBuild` repeats that the Init build links included source with other modules.
- The latest recovered `ChangeLog` entry is Marinetti 3.0b5 (2012).
- The [Marinetti download page](https://www.apple2.org/marinetti/index.html) publishes TCPIP 3.0b11 (2019), so the latest distributed binary is newer than the clearly identified source baseline.

Status: suitable for open-source research and modification under LGPL-2.1-or-later, but not yet established as the complete corresponding source for the newest public binary.

## Uthernet II link layer

Authoritative/public locations:

- [Marinetti link-layer downloads](https://speccie.uk/software/marinetti-link-layers/)
- [Uthernet II hardware information](https://github.com/a2retrosystems/uthernet2)

The link-layer page publishes Uthernet II binary version 2.0.5 and separately publishes ORCA/M source for a generic emulator link layer. It does not publish a Uthernet II source archive. The accompanying link-layer manual describes the link layers as freeware and identifies copyright ownership; freeware is not automatically an open-source license.

The recovered Marinetti CVS tree has no Uthernet or Uthernet II link-layer source directory.

Status: do not copy, modify, or redistribute a reconstructed or obtained Uthernet II link-layer source tree until its copyright holders provide the source under a clear license or otherwise grant permission.

## Useful independent W5100/Uthernet II references

These projects may help explain or independently implement W5100 access, but their code must remain separate until license compatibility and derivation are reviewed:

- [cshepherd/gbbs-utherii](https://github.com/cshepherd/gbbs-utherii) — MIT-licensed Uthernet II driver.
- [A2osX/A2osX Uthernet II driver](https://github.com/A2osX/A2osX/blob/master/DRV/UTHERNET2.DRV.S.txt) — repository uses a project-specific license; review before reuse.
- [UltimateDrive IIgs networking driver](https://github.com/Ultimate-Drive/UltimateDrive-IIgsDrivers/blob/main/gsos-marinetti-driver/src/orca/uthernet2.asm) — no repository license detected during this audit; treat as reference-only unless clarified.

## Chain of custody for the initial import

- Download URL: `https://sourceforge.net/code-snapshots/cvs/m/ma/marinetti.zip`
- Archive format: ZIP containing the original RCS `,v` files.
- Imported module: `MOSP`
- Imported revision choice: head revision of every non-`Attic` file.
- Imported file count: 132 upstream files.
- Transformations: RCS framing and doubled-`@` escapes removed; file payload bytes otherwise preserved. No source formatting or line-ending conversion was intentionally performed.

The full CVS/RCS history has not yet been converted into Git. The original SourceForge archive should remain the reference for per-file history until a verified history conversion is added.

