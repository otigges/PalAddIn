<#
.SYNOPSIS
    Packages PalAddIn into a distributable zip under dist\.

.DESCRIPTION
    The zip contains a single top-level PalAddIn folder, which is what addon
    managers and a manual "extract into AddOns" both expect. The version is
    read from the ## Version line in PalAddIn.toc.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot 'PalAddIn'
$toc = Join-Path $source 'PalAddIn.toc'

if (-not (Test-Path $toc)) {
    throw "Could not find $toc. Run this from the repository."
}

$version = (Select-String -Path $toc -Pattern '^##\s*Version:\s*(.+)$').Matches.Groups[1].Value.Trim()
if (-not $version) { throw "No '## Version:' line found in $toc" }

$dist = Join-Path $repoRoot 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$zip = Join-Path $dist "PalAddIn-$version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }

# Stage so the archive has PalAddIn\ as its single root entry.
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("paladdin-pkg-" + [guid]::NewGuid())
try {
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    Copy-Item $source (Join-Path $staging 'PalAddIn') -Recurse
    Compress-Archive -Path (Join-Path $staging 'PalAddIn') -DestinationPath $zip
}
finally {
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
}

$size = [math]::Round((Get-Item $zip).Length / 1KB, 1)
Write-Host "Created $zip ($size KB)" -ForegroundColor Green
