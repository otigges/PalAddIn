<#
.SYNOPSIS
    Installs PalAddIn into your WoW AddOns folder, as a symlink or a copy.

.DESCRIPTION
    Link mode (the default) points the game at this repository, so editing a
    .lua file and typing /reload in-game is the whole dev loop. It needs
    Developer Mode enabled or an elevated shell, once.

    Copy mode works without any privileges, but has to be re-run after every
    edit. Use it when Link is not possible, or to install for someone else.

    The AddOns directory is resolved in this order:
      1. -AddonsDir
      2. $env:WOW_ADDONS_DIR
      3. WOW_ADDONS_DIR in .env.local
      4. auto-detection of the usual install locations

.EXAMPLE
    .\scripts\install.ps1
    Symlink the addon using an auto-detected or configured AddOns path.

.EXAMPLE
    .\scripts\install.ps1 -Mode Copy -Force
    Copy the addon, replacing whatever PalAddIn folder is already there.
#>
[CmdletBinding()]
param(
    [ValidateSet('Link', 'Copy')]
    [string]$Mode = 'Link',

    [string]$AddonsDir,

    # Required to replace an existing real (non-symlink) PalAddIn folder.
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot 'PalAddIn'

if (-not (Test-Path (Join-Path $source 'PalAddIn.toc'))) {
    throw "Could not find PalAddIn\PalAddIn.toc under '$repoRoot'. Run this from the repository."
}

function Read-EnvLocal {
    $envFile = Join-Path $repoRoot '.env.local'
    if (-not (Test-Path $envFile)) { return $null }

    foreach ($line in Get-Content $envFile) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }

        $separator = $trimmed.IndexOf('=')
        if ($separator -lt 1) { continue }

        $key = $trimmed.Substring(0, $separator).Trim()
        if ($key -ne 'WOW_ADDONS_DIR') { continue }

        # Paths may be quoted; they routinely contain spaces and parentheses.
        return $trimmed.Substring($separator + 1).Trim().Trim('"', "'")
    }
    return $null
}

function Find-AddonsDir {
    $roots = @(
        'C:\Program Files (x86)\World of Warcraft',
        'C:\Program Files\World of Warcraft',
        'D:\World of Warcraft',
        'C:\Games\World of Warcraft'
    )
    # _anniversary_ is the TBC Anniversary client this addon targets.
    # _classic_era_ is deliberately NOT probed: it is the Vanilla client, and
    # auto-installing there would silently target the wrong game.
    foreach ($root in $roots) {
        foreach ($flavor in @('_anniversary_', '_classic_')) {
            # [IO.Path]::Combine, not Join-Path: Join-Path validates the drive and
            # throws on a machine with no D:, which $ErrorActionPreference makes fatal.
            $candidate = [IO.Path]::Combine($root, $flavor, 'Interface', 'AddOns')
            if (Test-Path $candidate) { return $candidate }
        }
    }
    return $null
}

if (-not $AddonsDir) { $AddonsDir = $env:WOW_ADDONS_DIR }
if (-not $AddonsDir) { $AddonsDir = Read-EnvLocal }
if (-not $AddonsDir) {
    $AddonsDir = Find-AddonsDir
    if ($AddonsDir) { Write-Host "Auto-detected AddOns folder: $AddonsDir" -ForegroundColor DarkGray }
}

if (-not $AddonsDir) {
    throw @"
Could not determine your WoW AddOns folder.
Copy .env.local.example to .env.local and set WOW_ADDONS_DIR, or pass -AddonsDir.
"@
}

if (-not (Test-Path $AddonsDir)) {
    throw "AddOns folder does not exist: $AddonsDir"
}

# Guard against pointing at the PalAddIn folder instead of AddOns itself.
if ((Split-Path -Leaf $AddonsDir) -eq 'PalAddIn') {
    throw "WOW_ADDONS_DIR must be the AddOns folder, not the PalAddIn folder inside it: $AddonsDir"
}

$target = Join-Path $AddonsDir 'PalAddIn'

if (Test-Path $target) {
    $existing = Get-Item $target -Force
    $isLink = $existing.Attributes -band [IO.FileAttributes]::ReparsePoint

    if ($isLink) {
        # Delete the link only (symlink or junction). Remove-Item -Recurse on a
        # reparse point can follow it and wipe the target on PowerShell 5.1.
        Write-Host "Removing existing link at $target" -ForegroundColor DarkGray
        [System.IO.Directory]::Delete($target, $false)
    }
    elseif ($Force) {
        Write-Host "Removing existing folder at $target" -ForegroundColor Yellow
        Remove-Item $target -Recurse -Force
    }
    else {
        throw @"
'$target' already exists and is a real folder, not a link.
Re-run with -Force to replace it. Check first that it holds nothing you want —
this deletes it. (Your settings are safe either way: WoW stores them under
WTF\Account\...\SavedVariables\PalAddIn.lua, not in the addon folder.)
"@
    }
}

if ($Mode -eq 'Link') {
    # A junction is tried first because it needs no elevation and no Developer
    # Mode, while the game follows it exactly like a symlink. It only works for
    # directories on local volumes, so a symlink is the fallback for a repo on
    # a network share or a different kind of mount.
    $linkType = $null
    $errors = @()

    foreach ($candidate in @('Junction', 'SymbolicLink')) {
        try {
            New-Item -ItemType $candidate -Path $target -Target $source -ErrorAction Stop | Out-Null
            $linkType = $candidate
            break
        }
        catch {
            $errors += "  $candidate`: $($_.Exception.Message)"
        }
    }

    if (-not $linkType) {
        throw @"
Could not link '$target' to the repository.
$($errors -join "`n")

A junction normally works without any special privileges. If both failed, the
repository is probably on a network share or a non-NTFS volume. Install a plain
copy instead:  .\scripts\install.ps1 -Mode Copy
"@
    }

    Write-Host "Linked ($linkType) $target -> $source" -ForegroundColor Green
    Write-Host "Edit the Lua files here and type /reload in-game to apply." -ForegroundColor DarkGray
}
else {
    Copy-Item $source $target -Recurse -Force
    Write-Host "Copied $source -> $target" -ForegroundColor Green
    Write-Host "Re-run this script after every change, then /reload in-game." -ForegroundColor DarkGray
}

Write-Host "A .toc change needs a full client restart; .lua changes only need /reload." -ForegroundColor DarkGray
