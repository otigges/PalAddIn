---
name: generate-image
description: Generate an icon, texture or illustration with the OpenAI Images API via scripts/New-Image.ps1. Use when the project needs artwork — an addon icon, a status glyph, a README banner or diagram illustration — rather than describing a picture in text. Also covers converting the result into a format WoW can actually load.
---

# Generating images

`scripts/New-Image.ps1` wraps the OpenAI Images API (`gpt-image-1`). It reads the key from
`.env.local` and writes a PNG, optionally a downscaled copy and a WoW-loadable TGA.

## Before generating

- **Every run costs money.** Confirm with the user before the first generation of a session,
  and before any batch. Don't silently iterate through ten variants to get a nicer result.
- **Ask whether artwork is actually wanted.** A status column that reads `Missing` in red is
  usually better than an icon. Prefer text and color unless the user asked for art.
- **Never print, echo, or commit the API key.** It lives only in `.env.local`, which is
  git-ignored. The script never emits it, including on error — keep it that way.

## Usage

```powershell
# Icon with transparent background, downscaled to 64px, plus a TGA for in-game use
.\scripts\New-Image.ps1 -Prompt "..." -Transparent -ResizeTo 64 -Tga

# Illustration for docs
.\scripts\New-Image.ps1 -Prompt "..." -Size 1536x1024 -Out assets\banner.png
```

| Parameter | Notes |
| --- | --- |
| `-Prompt` | Required. Be explicit about style, framing, background. |
| `-Out` | Defaults to `assets\generated\<slug-from-prompt>.png`. |
| `-Size` | `1024x1024` (default), `1536x1024`, `1024x1536`, `auto`. Small sizes are not offered by the API — generate large, then `-ResizeTo`. |
| `-Quality` | `low` / `medium` (default) / `high`. Low is fine for drafts. |
| `-Transparent` | Transparent background. Use for anything overlaid on the game UI. |
| `-ResizeTo` | Square downscale, e.g. `64`. Writes `<name>-64.png` alongside the original. |
| `-Tga` | Also writes 32-bit uncompressed TGA. |

## Formats: what WoW can load

**The client does not load PNG.** Addon textures must be `.tga` (32-bit uncompressed) or `.blp`.
This is the single most common way generated art fails to show up in game.

- Use `-Tga` for anything referenced by `SetTexture()` in Lua.
- Keep dimensions a **power of two** (32, 64, 128, 256). The script warns if they aren't.
- PNG is correct for README images and docs — those are read by GitHub, not the client.

## Prompting for addon art

Icons are viewed at 16–64px on a cluttered background, so the usual failure is too much detail:

- Ask for: flat vector style, thick outlines, one clear silhouette, centered, high contrast,
  transparent background, no text, no border, no drop shadow.
- Avoid: photorealism, fine gradients, small internal detail, lettering (models render text
  poorly and it is illegible at icon size anyway).
- Name the palette explicitly. Blessing icons want gold/holy tones matching the paladin theme.

A prompt that works: *"flat vector icon of an open hand emitting golden light, thick dark
outline, centered, high contrast, transparent background, no text, game UI icon style"*.

## Where files go

- `assets/generated/` — scratch output, git-ignored. Iterate here.
- `PalAddIn/Textures/` — assets the addon actually ships. Promote a chosen file here
  deliberately, and reference it by path from Lua.

Tell the user what was generated and where; they review and commit.
