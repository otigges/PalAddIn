<#
.SYNOPSIS
    Generates an image with the OpenAI Images API and saves it as PNG,
    optionally resized and converted to TGA for use as a WoW texture.

.DESCRIPTION
    The API key is read from $env:OPENAI_API_KEY, then from .env.local
    (OPENAI_API_KEY, or OPEN_AI_API_KEY as an alias). The key is never printed.

    WoW does not load PNG textures. Use -Tga to also write a 32-bit uncompressed
    TGA, which the client does load, and keep the size a power of two.

.PARAMETER Prompt
    What to draw. Be explicit about style, framing and background.

.PARAMETER Out
    Output path. Defaults to assets\generated\<slug>.png.

.PARAMETER Size
    Generation size: 1024x1024 (default), 1536x1024, 1024x1536, or auto.

.PARAMETER Transparent
    Request a transparent background. Recommended for icons.

.PARAMETER ResizeTo
    Also downscale to this square pixel size, e.g. 64 for an action icon.

.PARAMETER Tga
    Also write a 32-bit uncompressed .tga next to the PNG, for in-game use.

.EXAMPLE
    .\scripts\New-Image.ps1 -Prompt "a golden paladin blessing hand symbol, flat icon, thick outline, centered" -Transparent -ResizeTo 64 -Tga

.EXAMPLE
    .\scripts\New-Image.ps1 -Prompt "banner illustration for a WoW paladin addon README" -Size 1536x1024 -Out assets\banner.png
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$Out,

    [ValidateSet('1024x1024', '1536x1024', '1024x1536', 'auto')]
    [string]$Size = '1024x1024',

    [ValidateSet('low', 'medium', 'high', 'auto')]
    [string]$Quality = 'medium',

    # gpt-image-1 needs a verified OpenAI organization and returns 403 without
    # one. dall-e-3 has no such requirement, but cannot do transparency.
    [ValidateSet('gpt-image-1', 'dall-e-3')]
    [string]$Model = 'gpt-image-1',

    [switch]$Transparent,

    [int]$ResizeTo,

    [switch]$Tga
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Get-ApiKey {
    if ($env:OPENAI_API_KEY) { return $env:OPENAI_API_KEY }

    $envFile = Join-Path $repoRoot '.env.local'
    if (Test-Path $envFile) {
        foreach ($line in Get-Content $envFile) {
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }

            $separator = $trimmed.IndexOf('=')
            if ($separator -lt 1) { continue }

            $name = $trimmed.Substring(0, $separator).Trim()
            if ($name -in @('OPENAI_API_KEY', 'OPEN_AI_API_KEY')) {
                $value = $trimmed.Substring($separator + 1).Trim().Trim('"', "'")
                if ($value -and $value -ne 'sk-...') { return $value }
            }
        }
    }

    if ($env:OPEN_AI_API_KEY) { return $env:OPEN_AI_API_KEY }
    return $null
}

# Writes a 32-bit uncompressed TGA with a top-left origin. WoW loads this;
# it does not load PNG.
function Write-Tga {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Path)

    $width = $Bitmap.Width
    $height = $Bitmap.Height

    $stream = [System.IO.File]::Create($Path)
    try {
        $writer = New-Object System.IO.BinaryWriter($stream)

        $writer.Write([byte]0)      # id length
        $writer.Write([byte]0)      # no colour map
        $writer.Write([byte]2)      # uncompressed true-colour
        $writer.Write([byte[]]@(0, 0, 0, 0, 0))  # colour map spec
        $writer.Write([int16]0)     # x origin
        $writer.Write([int16]0)     # y origin
        $writer.Write([int16]$width)
        $writer.Write([int16]$height)
        $writer.Write([byte]32)     # bits per pixel
        $writer.Write([byte]0x28)   # 8 alpha bits, top-left origin

        # BGRA, row by row from the top because of the origin bit above.
        $buffer = New-Object byte[] ($width * $height * 4)
        $offset = 0
        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $pixel = $Bitmap.GetPixel($x, $y)
                $buffer[$offset++] = $pixel.B
                $buffer[$offset++] = $pixel.G
                $buffer[$offset++] = $pixel.R
                $buffer[$offset++] = $pixel.A
            }
        }
        $writer.Write($buffer)
        $writer.Flush()
    }
    finally {
        $stream.Dispose()
    }
}

$apiKey = Get-ApiKey
if (-not $apiKey) {
    throw @"
No OpenAI API key found.
Set OPENAI_API_KEY in .env.local (copy .env.local.example), or set the
environment variable. See .env.local.example for the exact format.
"@
}

if (-not $Out) {
    # Slug from the first few words, so repeated runs are easy to tell apart.
    $slug = ($Prompt -replace '[^a-zA-Z0-9 ]', '' -split '\s+' |
        Where-Object { $_ } | Select-Object -First 5) -join '-'
    if (-not $slug) { $slug = 'image' }
    $Out = Join-Path $repoRoot "assets\generated\$($slug.ToLower()).png"
}
elseif (-not [IO.Path]::IsPathRooted($Out)) {
    $Out = Join-Path $repoRoot $Out
}

$outDir = Split-Path -Parent $Out
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

if ($Model -eq 'dall-e-3') {
    # Different size vocabulary, different quality names, and b64 must be asked
    # for explicitly or the API returns an expiring URL instead.
    $dalleSize = switch ($Size) {
        '1536x1024' { '1792x1024' }
        '1024x1536' { '1024x1792' }
        'auto'      { '1024x1024' }
        default     { $Size }
    }
    $payload = [ordered]@{
        model           = 'dall-e-3'
        prompt          = $Prompt
        n               = 1
        size            = $dalleSize
        quality         = $(if ($Quality -eq 'high') { 'hd' } else { 'standard' })
        response_format = 'b64_json'
    }
    if ($Transparent) {
        Write-Warning "dall-e-3 cannot produce transparent backgrounds; -Transparent ignored."
    }
    $effectiveSize = $dalleSize
}
else {
    $payload = [ordered]@{
        model   = 'gpt-image-1'
        prompt  = $Prompt
        n       = 1
        size    = $Size
        quality = $Quality
    }
    if ($Transparent) {
        $payload.background = 'transparent'
        $payload.output_format = 'png'
    }
    $effectiveSize = $Size
}

Write-Host "Generating $effectiveSize image with $Model..." -ForegroundColor Cyan

try {
    # Encode explicitly so non-ASCII prompts survive the round trip.
    $bodyBytes = [Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 5 -Compress))
    $response = Invoke-RestMethod -Uri 'https://api.openai.com/v1/images/generations' `
        -Method Post `
        -Headers @{ Authorization = "Bearer $apiKey" } `
        -ContentType 'application/json' `
        -Body $bodyBytes
}
catch {
    # Deliberately reports the status and API message only — never the request
    # headers, which carry the key.
    $status = $null
    if ($_.Exception.PSObject.Properties.Name -contains 'Response' -and $_.Exception.Response) {
        $status = $_.Exception.Response.StatusCode
    }
    $detail = $_.ErrorDetails.Message
    if (-not $detail) { $detail = $_.Exception.Message }

    if ("$status" -eq 'Unauthorized') {
        throw "OpenAI rejected the API key (401). Check OPENAI_API_KEY in .env.local."
    }
    if ("$status" -eq 'Forbidden' -and $Model -eq 'gpt-image-1') {
        throw @"
OpenAI returned 403 for gpt-image-1 ($detail)

This usually means the organization is not verified for that model. Either
verify it at platform.openai.com/settings/organization/general, or re-run with:
  -Model dall-e-3
"@
    }
    throw "Image generation failed ($status): $detail"
}

$b64 = $response.data[0].b64_json
if (-not $b64) { throw 'The API response contained no image data.' }

[IO.File]::WriteAllBytes($Out, [Convert]::FromBase64String($b64))
Write-Host "Wrote $Out" -ForegroundColor Green

if ($ResizeTo -or $Tga) {
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    }
    catch {
        Write-Warning "System.Drawing unavailable; skipping resize/TGA. PNG is still at $Out"
        return
    }

    $source = [System.Drawing.Image]::FromFile($Out)
    try {
        $target = $source
        if ($ResizeTo) {
            $resized = New-Object System.Drawing.Bitmap($ResizeTo, $ResizeTo)
            $graphics = [System.Drawing.Graphics]::FromImage($resized)
            try {
                $graphics.InterpolationMode = 'HighQualityBicubic'
                $graphics.DrawImage($source, 0, 0, $ResizeTo, $ResizeTo)
            }
            finally { $graphics.Dispose() }

            $resizedPath = [IO.Path]::ChangeExtension($Out, $null).TrimEnd('.') + "-$ResizeTo.png"
            $resized.Save($resizedPath, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Host "Wrote $resizedPath" -ForegroundColor Green
            $target = $resized
        }

        if ($Tga) {
            $bitmap = New-Object System.Drawing.Bitmap($target)
            try {
                $tgaPath = [IO.Path]::ChangeExtension($Out, $null).TrimEnd('.')
                if ($ResizeTo) { $tgaPath += "-$ResizeTo" }
                $tgaPath += '.tga'
                Write-Tga -Bitmap $bitmap -Path $tgaPath
                Write-Host "Wrote $tgaPath ($($bitmap.Width)x$($bitmap.Height), 32-bit)" -ForegroundColor Green

                $isPowerOfTwo = { param($n) $n -gt 0 -and ($n -band ($n - 1)) -eq 0 }
                if (-not (& $isPowerOfTwo $bitmap.Width) -or -not (& $isPowerOfTwo $bitmap.Height)) {
                    Write-Warning "WoW expects power-of-two texture dimensions; this is $($bitmap.Width)x$($bitmap.Height)."
                }
            }
            finally { $bitmap.Dispose() }
        }

        if ($ResizeTo) { $target.Dispose() }
    }
    finally {
        $source.Dispose()
    }
}
