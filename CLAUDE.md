# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A World of Warcraft addon (Lua) for **TBC Classic – Anniversary Edition**, helping Paladins
manage blessings for a five-player party. `docs/plugin-briefing.md` is the authoritative spec:
it defines the milestones, the MVP acceptance criteria and the hard constraints. Read it before
adding a feature; the current release covers Milestones 1–2 only.

## Build, test, run

There is no build step and never will be — the client interprets the `.lua` files directly, using
`PalAddIn.toc` as the manifest and load order. There is also no package manager, no test suite,
and **no Lua toolchain installed on this machine**, so a change cannot be syntax-checked locally.
Verify in the game client:

```powershell
.\scripts\install.ps1              # symlink (default); -Mode Copy if symlinks are unavailable
.\scripts\package.ps1              # dist\PalAddIn-<version>.zip for distribution
```

- `/reload` in-game picks up `.lua` changes. A `.toc` change needs a full client restart.
- `/console scriptErrors 1` surfaces Lua errors; `/paladdin debug` enables the addon's own
  event/state logging.
- The README's Testing section holds the manual checklist to run before a release.

Target client: TBC **Anniversary**, installed under `_anniversary_` (not `_classic_`, and
emphatically not `_classic_era_`, which is Vanilla). `## Interface: 20506` matches
`WowClassic.exe` 2.5.6.

## Non-negotiable constraints

These come from Blizzard's secure-action rules and from the briefing. Violating them is worse
than shipping the feature late:

- Never cast a spell, change a target, or execute a combat action on the player's behalf.
  Everything is a recommendation the player acts on.
- Never modify protected UI, secure button attributes, or macros while
  `InCombatLockdown()` is true.
- Never hard-code a localized spell name for *logic*. Identify spells by ID, and resolve
  display names from the client's own spell data.
- Don't add external library dependencies without a clear justification.
- No continuous polling. Everything is event-driven.

## Architecture

Load order is fixed in `PalAddIn.toc`; every file receives the shared table via
`local ADDON_NAME, ns = ...` and hangs its module off `ns`. Modules read each other's tables at
file scope, so a file may only reference modules loaded before it.

```
Locales/  →  Database  →  Compat  →  Blessings  →  Group  →  UI  →  Core
```

- **`Compat.lua`** — the single place where client-version differences live. Aura reads prefer
  `C_UnitAuras.GetAuraDataByIndex` and fall back to `UnitAura`; spell lookups prefer `C_Spell`
  and fall back to the global `GetSpellInfo`. When an API turns out to differ on the Anniversary
  client, fix it here, not at the call site.
- **`Database.lua`** — `PalAddInDB` (SavedVariablesPerCharacter), defaults merged non-destructively
  on load, plus a `migrations` table keyed by the version being upgraded *from*. Bump
  `SCHEMA_VERSION` and add a migration rather than changing the shape in place.
- **`Blessings.lua`** — spell ID tables per blessing (normal + Greater ranks) and all aura
  inspection. Two identity concepts matter here:
  - a **blessing key** (`"MIGHT"`) is what gets assigned and stored — stable across ranks, and
    Greater ranks map to the same key, so a Greater Blessing satisfies a normal assignment;
  - detection matches **spell ID first, localized name second**. The name map is built at
    `PLAYER_LOGIN` from the client's data, which is why a wrong or missing rank ID degrades into
    working detection instead of a false "Missing".
  `GetStatus()` returns one of `Blessings.STATUS`; the UI owns the text and colors for those.
- **`Group.lua`** — roster of `player` + `party1..4`. `Update()` returns whether the roster
  actually changed, and `unitLookup` exists so the very chatty `UNIT_AURA` can be filtered cheaply.
- **`UI.lua`** — one window, up to five rows, built from plain frames and textures rather than
  XML templates that may not exist on every client build. Assignments are made through a small
  self-contained menu (no `UIDropDownMenu`, to avoid taint).
- **`Core.lua`** — event registration, slash commands, `ns.Debug`. Events set a `dirty` flag that
  an `OnUpdate` collapses into at most one `UI:Refresh()` per frame; a 1s ticker only exists to
  advance the expiry countdowns. Add new events to the `handlers` table — registration is derived
  from its keys.

Key state that persists: `playerAssignments` is keyed by `"Name-Realm"` and is intentionally
never pruned when a player leaves, so a returning player keeps their blessing.

## Conventions

- Player-facing strings go through `ns.L` (`Locales/enUS.lua` is the fallback and must contain
  every key; `deDE.lua` overrides). Blessing names are never translated by hand — they come from
  the client.
- Report uncertainty in the UI rather than guessing: an out-of-range or offline unit gets its own
  status instead of being reported as missing a blessing.
