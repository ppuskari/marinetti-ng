# PGT36 R3C HARDEN-R1K1 native player build + ProDOS deployment image
# Windows PowerShell 5.1 compatible
[CmdletBinding()]
param([switch]$KeepNapsFile)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$ExpectedOmfSha256 = 'b51aba537ce45e374ff99fefe03f6e1f9d8e2c6b9b6d6a3e072d010f663c4948'
$ExpectedOmfBytes  = 57930
$Here       = $PSScriptRoot
$Probe      = $Here
$DevRoot    = $null

for ($i=0; $i -lt 7 -and $Probe; $i++) {
    if (Test-Path -LiteralPath (Join-Path $Probe 'tools')) {
        $DevRoot = $Probe
        break
    }
    $Probe = Split-Path -Parent $Probe
}

if (-not $DevRoot) {
    foreach ($candidate in @('C:\AppleIIgsDev_02','C:\AppleIIgsDev\_02')) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'tools')) {
            $DevRoot = $candidate
            break
        }
    }
}

if (-not $DevRoot) {
    throw 'Could not locate AppleIIgsDev_02 root containing tools.'
}

$ToolsRoot  = Join-Path $DevRoot 'tools'
$MakeFile   = Join-Path $Here 'pgt36r3c.make.s'
$OmfFile    = Join-Path $Here 'PGT36R3C'
$NapsFile   = Join-Path $Here 'PGT36R3C#B30000'
$PoFile     = Join-Path $Here 'PGT36R3C.po'
$BuildLog   = Join-Path $Here 'PGT36R3C-Windows-build.log'
$CatalogLog = Join-Path $Here 'PGT36R3C-po-catalog.txt'

function Require-Path {
    param([string]$Path,[string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label not found: $Path"
    }
}

function Find-OneFile {
    param([string]$Root,[string]$Name,[string]$Label)
    Require-Path $Root "$Label search root"
    $items = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Name |
        Sort-Object FullName)
    if ($items.Count -lt 1) {
        throw "$Label not found under: $Root"
    }
    return $items[0].FullName
}

Write-Host '===== PGT36 R3C HARDEN PLAYER BUILD ====='
$MerlinTree = Join-Path $ToolsRoot 'Merlin32_v1.2_b2'
$Cp2Tree    = Join-Path $ToolsRoot 'cp2'
$MerlinExe  = Find-OneFile $MerlinTree 'Merlin32.exe' 'Merlin32.exe'
$Cp2Exe     = Find-OneFile $Cp2Tree 'cp2.exe' 'CiderPress2 cp2.exe'
$LocatorMac = Find-OneFile $MerlinTree 'Locator.Macs.s' 'Locator.Macs.s'
$LibraryRoot = Split-Path -Parent $LocatorMac

foreach ($f in @($OmfFile,$NapsFile,$PoFile,$BuildLog,$CatalogLog)) {
    if (Test-Path -LiteralPath $f) {
        Remove-Item -LiteralPath $f -Force
    }
}

Push-Location $Here
try {
    & $MerlinExe $LibraryRoot $MakeFile 2>&1 |
        Tee-Object -FilePath $BuildLog
    if ($LASTEXITCODE -ne 0) {
        throw "Merlin32 failed: $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Require-Path $OmfFile 'OMF'
$omf  = Get-Item -LiteralPath $OmfFile
$hash = (Get-FileHash -LiteralPath $OmfFile -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Bytes : $($omf.Length)"
Write-Host "SHA256: $hash"

if ($omf.Length -ne $ExpectedOmfBytes) {
    throw "Size mismatch: expected $ExpectedOmfBytes got $($omf.Length)"
}
if ($hash -ne $ExpectedOmfSha256) {
    throw "Hash mismatch: expected $ExpectedOmfSha256 got $hash"
}

Write-Host 'PASS: OMF matches validated reference build.'
Copy-Item -LiteralPath $OmfFile -Destination $NapsFile -Force

& $Cp2Exe cdi $PoFile 32m ProDOS
if ($LASTEXITCODE -ne 0) { throw 'cp2 create image failed.' }
& $Cp2Exe rename $PoFile ':' PGT36R3C
if ($LASTEXITCODE -ne 0) { throw 'cp2 rename failed.' }
& $Cp2Exe add $PoFile $NapsFile
if ($LASTEXITCODE -ne 0) { throw 'cp2 add failed.' }
& $Cp2Exe catalog --wide $PoFile 2>&1 |
    Tee-Object -FilePath $CatalogLog
if ($LASTEXITCODE -ne 0) { throw 'cp2 catalog failed.' }

if (-not $KeepNapsFile -and (Test-Path -LiteralPath $NapsFile)) {
    Remove-Item -LiteralPath $NapsFile -Force
}

Write-Host "READY: $PoFile"
