# PalAddIn

A lightweight World of Warcraft addon for **The Burning Crusade Classic – Anniversary Edition**
that helps Paladins keep a five-player group buffed.

PalAddIn only ever *shows* and *reminds*. It never casts, never changes your target, and never
touches protected actions in combat.

## Status: v0.1.0 — Blessing assistant

The first release covers Milestones 1 and 2 of [the briefing](docs/plugin-briefing.md):

- Addon skeleton, `.toc`, per-character saved variables with schema migration
- Party detection (player + up to four party members), live roster updates
- A blessing assignment per party member, remembered per character and restored when
  that player rejoins
- Status per member: **Active** (with remaining time), **Expires soon**, **Missing**,
  **Wrong blessing**, plus out-of-range / offline / dead handling
- Movable, lockable, scalable window
- Slash commands and debug logging
- English and German UI text

Not in this release: heal/follow buttons, macro generation, Judgement of Wisdom reminders,
target/mana/damage assistants. See [Roadmap](#roadmap).

## Installation

```powershell
.\scripts\install.ps1
```

That links the addon into your WoW AddOns folder, so editing a file here and typing `/reload`
in-game is the whole loop. No elevation and no Developer Mode needed — it creates a **directory
junction**, which the game follows exactly like a symlink. (It falls back to a real symlink if
the junction fails, which happens when the repository sits on a network share or a non-NTFS
volume; a symlink does need Developer Mode or an elevated shell.)

If neither works:

```powershell
.\scripts\install.ps1 -Mode Copy     # works anywhere; re-run after every change
```

The script auto-detects the usual install locations. If yours is elsewhere, copy
`.env.local.example` to `.env.local` and set `WOW_ADDONS_DIR` (it's git-ignored), or pass
`-AddonsDir`. To install by hand instead, copy the `PalAddIn` folder — only that subfolder,
not the repository root — into:

```
<World of Warcraft>\_anniversary_\Interface\AddOns\PalAddIn
```

Then enable *PalAddIn* in the character-select AddOns list.

> The Anniversary client lives in `_anniversary_`. `_classic_era_` is the Vanilla client —
> installing there targets the wrong game, which is why the script never auto-detects it.

## There is no build step

WoW addons ship as source. The client embeds a Lua 5.1 interpreter, reads `PalAddIn.toc` as the
manifest, and executes each listed `.lua` file as text in the order listed — no compiler, no
bundler, no artifact. That load order is load-bearing: every file hangs its module on a shared
`ns` table and reads the others at file scope, so a file may only reference modules listed above
it in the `.toc`.

| Change | What's needed |
| --- | --- |
| A `.lua` file | `/reload` in-game |
| The `.toc` file | Full client restart — the manifest is read only at startup |
| A new file | Add it to the `.toc`, **and** restart |

`scripts\package.ps1` builds `dist\PalAddIn-<version>.zip` for distribution, with a single
top-level `PalAddIn` folder as addon managers expect. That is the closest thing to a build here.

Your settings are never stored in the addon folder — WoW writes them to
`WTF\Account\...\SavedVariables\PalAddIn.lua`, so reinstalling or re-linking cannot lose them.

## Client version

`## Interface: 20506` matches the TBC Anniversary client (`WowClassic.exe` 2.5.6). If a future
patch makes the addon show as out of date, either tick **Load out of date AddOns**, or update
the `## Interface:` line to the value from:

```
/run print((select(4, GetBuildInfo())))
```

## Usage

Type `/paladdin` to toggle the window. Each row is a party member:

| Player | Blessing | Status |
| --- | --- | --- |
| Character A | Blessing of Might | Active 8:12 |
| Character B | Blessing of Wisdom | Missing |
| Character C | Blessing of Salvation | Expires soon 43s |
| Character D | Blessing of Might | Blessing of Kings |

Click the blessing button on a row to pick that player's blessing (or clear it). Greater
Blessings count as satisfying the same assignment — an assignment of *Might* is happy with
either Blessing of Might or Greater Blessing of Might.

### Slash commands

| Command | Effect |
| --- | --- |
| `/paladdin` | Toggle the window (`/pal` also works) |
| `/paladdin lock [on\|off]` | Lock or unlock dragging |
| `/paladdin reset` | Reset window position and scale |
| `/paladdin sound [on\|off]` | Reminder sound when something is missing (out of combat only) |
| `/paladdin warn <seconds>` | Expiration warning threshold (default 60) |
| `/paladdin enable` / `disable` | Turn the addon on or off |
| `/paladdin debug` | Toggle debug logging to chat |
| `/paladdin help` | Show the command list |

## Design notes

A few decisions worth knowing before changing the code:

- **Blessings are identified by a key, not a spell ID.** Assignments store `"MIGHT"`, so they
  survive rank-ups and work for both normal and Greater Blessings.
- **Detection matches spell IDs first, localized names second.** Names are resolved from the
  client's own spell data at login, so no localized string is ever hard-coded, and a wrong rank
  ID in `Blessings.lua` degrades gracefully instead of silently reporting "Missing".
- **All changed APIs go through `Compat.lua`.** Aura reads prefer `C_UnitAuras.GetAuraDataByIndex`
  and fall back to `UnitAura`, so the addon survives either API generation.
- **Out-of-range members report "Out of range", not "Missing".** Auras on units outside
  visibility range are stale, and a false "Missing" is worse than no answer.
- **No polling.** Updates are event-driven (`GROUP_ROSTER_UPDATE`, `UNIT_AURA`, …), coalesced
  into at most one refresh per frame, plus a 1s ticker that only advances the countdowns.

## Testing

There is no Lua toolchain in this repository and no automated test suite — the addon is
verified in the live client. Before releasing a change, check at minimum:

- [ ] Loads with no Lua error (`/console scriptErrors 1`)
- [ ] All five party members appear, and the list updates when someone joins or leaves
- [ ] Assignments survive `/reload` and a full game restart
- [ ] Missing, expiring and wrong-blessing states each display correctly
- [ ] Nothing breaks or errors while entering and leaving combat
- [ ] Works on both an English and a German client

## Roadmap

| Milestone | Contents |
| --- | --- |
| 3 | Heal and follow secure action buttons, optional macro generation |
| 4 | Judgement of Wisdom reminders with configurable modes |
| 5 | Options panel, sounds and visual emphasis, polish |
| Later | Target assistant, mana assistant, damage recommendations, combat summary |

## License

MIT — see [LICENSE](LICENSE).
