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
$Cp2 = Join-Path $DevRoot "Tools\cp2\cp2.exe"
$SourceRoot = Join-Path $RepoRoot "Petar_gsTCP\apps\tcprxtest"
$Source = Join-Path $SourceRoot "PGT.TCPRXTEST.S"
$OutputRoot = Join-Path $RepoRoot "build-local"
$Binary = Join-Path $OutputRoot "PGTTCPRXTEST"
$NapsBinary = Join-Path $OutputRoot "PGTTCPRXTEST#B30000"
$Image = Join-Path $OutputRoot "PGTTCPRXTest.po"

foreach ($path in @($Assembler, $Cp2, $Source)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file not found: $path"
    }
}
if (-not (Test-Path -LiteralPath $Library -PathType Container)) {
    throw "Merlin library not found: $Library"
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
Push-Location $SourceRoot
try {
    & $Assembler $Library (Split-Path -Leaf $Source)
    if ($LASTEXITCODE -ne 0) { throw "Merlin 32 failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
if (-not (Test-Path -LiteralPath $Binary -PathType Leaf)) {
    throw "Expected application was not created: $Binary"
}

Copy-Item -LiteralPath $Binary -Destination $NapsBinary -Force
Remove-Item -LiteralPath $Image -Force -ErrorAction SilentlyContinue
& $Cp2 create-disk-image $Image 32mb ProDOS
if ($LASTEXITCODE -ne 0) { throw "cp2 create-disk-image failed" }
& $Cp2 rename $Image : PGTTCP
if ($LASTEXITCODE -ne 0) { throw "cp2 rename failed" }
& $Cp2 add --from-naps --strip-paths $Image $NapsBinary
if ($LASTEXITCODE -ne 0) { throw "cp2 add failed" }
& $Cp2 test $Image
if ($LASTEXITCODE -ne 0) { throw "cp2 filesystem test failed" }

$hash = (Get-FileHash -LiteralPath $Binary -Algorithm SHA256).Hash.ToLowerInvariant()
$imageHash = (Get-FileHash -LiteralPath $Image -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Built application: $Binary"
Write-Host "Application SHA256: $hash"
Write-Host "Built disk image: $Image"
Write-Host "Disk SHA256: $imageHash"
