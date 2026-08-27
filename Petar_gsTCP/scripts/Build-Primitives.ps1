#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$DevRoot = "C:\AppleIIgsDev_02"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$ToolRoot = Join-Path $DevRoot "_tools\Merlin32_v1.2\Merlin32_v1.2_b2"
$Assembler = Join-Path $ToolRoot "Windows\Merlin32.exe"
$Library = Join-Path $ToolRoot "Library"
$Source = Join-Path $RepoRoot "Petar_gsTCP\build\PGT.PRIMITIVES.S"
$OutputRoot = Join-Path $RepoRoot "build-local"

foreach ($path in @($Assembler, $Source)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file not found: $path"
    }
}
if (-not (Test-Path -LiteralPath $Library -PathType Container)) {
    throw "Merlin library not found: $Library"
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
Push-Location (Split-Path -Parent $Source)
try {
    & $Assembler $Library (Split-Path -Leaf $Source)
    if ($LASTEXITCODE -ne 0) {
        throw "Merlin 32 failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$Output = Join-Path $OutputRoot "pgt-primitives.bin"
if (-not (Test-Path -LiteralPath $Output -PathType Leaf)) {
    throw "Expected output was not created: $Output"
}

$item = Get-Item -LiteralPath $Output
$hash = (Get-FileHash -LiteralPath $Output -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Built $($item.FullName) ($($item.Length) bytes)"
Write-Host "SHA256 $hash"
