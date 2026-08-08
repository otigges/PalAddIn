# PalAddIn

## Project Overview

PalAddIn is a lightweight World of Warcraft addon for **The Burning Crusade Classic Anniversary Edition**. It assists Paladin players in five-player groups with recurring support and combat tasks.

The addon should provide clear reminders and recommendations without attempting to automate gameplay or make protected combat decisions.

## Primary Goals

PalAddIn should help with:

1. Assigning and maintaining the correct blessings.
2. Maintaining Judgement of Wisdom on appropriate enemies.
3. Identifying the correct combat target.
4. Managing mana efficiently.
5. Improving damage through simple situational recommendations.
6. Quickly healing or following specific group members.

## Design Principles

* Start with a small, reliable MVP.
* Prefer clear visual cues over complex interfaces.
* Avoid unnecessary dependencies.
* Never automate protected combat actions.
* Do not change targets or cast spells automatically.
* Support both English and German game clients where practical.
* Identify spells internally by spell ID where possible.
* Keep configuration character-specific by default.
* Ensure compatibility with the current TBC Classic Anniversary client and its modernized addon API.

## MVP Scope

### 1. Group Detection

The addon should detect:

* The player entering or leaving a party.
* Changes to party composition.
* Party member names, classes and unit IDs.
* Whether the group contains up to four other players.
* Whether the player is currently in combat.

The UI should update when the group changes.

### 2. Blessing Assignments

Allow the user to assign a blessing to each party member.

Initially supported blessings:

* Blessing of Might
* Blessing of Wisdom
* Blessing of Kings
* Blessing of Salvation
* Blessing of Light
* Blessing of Sanctuary

The addon should:

* Store the assignment for each character.
* Restore known assignments when the same character rejoins.
* Show which assigned blessings are currently missing.
* Show blessings that will expire soon.
* distinguish between a missing blessing and a different Paladin blessing being active.
* Support normal and Greater Blessings where available.
* Provide optional out-of-combat reminder sounds.
* Never cast a blessing automatically.

A compact party overview could look conceptually like this:

| Player      | Class   | Assigned blessing | Status         |
| ----------- | ------- | ----------------- | -------------- |
| Character A | Warrior | Might             | Active         |
| Character B | Priest  | Wisdom            | Missing        |
| Character C | Mage    | Salvation         | Expires soon   |
| Character D | Rogue   | Might             | Wrong blessing |

### 3. Judgement of Wisdom Reminder

For the current hostile target, detect whether Judgement of Wisdom is active.

The addon should warn when:

* The current target is attackable and does not have Judgement of Wisdom.
* Judgement of Wisdom is about to expire.
* The Paladin may need to activate Seal of Wisdom before judging.
* Judgement is currently on cooldown.

This is a recommendation only. The addon must not automatically cast Seal of Wisdom or Judgement.

The reminder should be configurable because Judgement of Wisdom is not useful for every enemy, especially enemies that die quickly.

Possible modes:

* Disabled
* Bosses only
* Elites and bosses
* All hostile targets
* Manual target marking

### 4. Heal and Follow Actions

For each of the other four party members, provide:

* A heal action.
* A follow action.

Support two implementations:

#### Addon Buttons

Preferred implementation using secure action buttons:

* One configurable heal button per party member.
* One follow button per party member.
* Buttons may be prepared or reconfigured only when allowed by the WoW API.
* Existing buttons must continue to work during combat where permitted.
* The addon must not dynamically change protected attributes during combat.

#### Generated Macros

Optional alternative:

* Generate one `Heal <name>` macro per party member.
* Generate one `Follow <name>` macro per party member.
* Use character-specific macro slots.
* Detect and update macros previously created by PalAddIn.
* Never overwrite unrelated user macros.
* Only create or update macros outside combat.
* Warn if insufficient macro slots are available.
* Provide an explicit “Generate/Update Macros” button.

Example macro bodies:

```text
#showtooltip
/cast [@CharacterName,help,nodead] Flash of Light
```

```text
/follow CharacterName
```

The healing spell should be configurable globally or per party member.

### 5. Persistent Configuration

Use `SavedVariablesPerCharacter` for persistent state.

Suggested structure:

```lua
PalAddInDB = {
    version = 1,
    settings = {
        enabled = true,
        wisdomMode = "elite",
        expirationWarningSeconds = 15,
        soundEnabled = false,
        macroGenerationEnabled = false,
    },
    playerAssignments = {
        ["CharacterName-Realm"] = {
            blessingSpellId = 12345,
            healSpellId = 12345,
        },
    },
    ui = {
        position = {},
        scale = 1.0,
        locked = false,
    },
}
```

Provide migration support when the schema version changes.

### 6. Basic Configuration UI

The initial UI should allow:

* Enabling or disabling the addon.
* Assigning a blessing to each current party member.
* Choosing the default healing spell.
* Overriding the healing spell for an individual player.
* Selecting the Judgement of Wisdom reminder mode.
* Configuring the expiration warning threshold.
* Enabling or disabling sounds.
* Generating or updating macros.
* Locking and unlocking the main window.
* Resetting the UI position.

Slash commands:

```text
/paladdin
/paladdin config
/paladdin lock
/paladdin reset
/paladdin macros
/paladdin debug
```

The slash command should be `/paladdin`, matching the addon name “PalAddIn”.

## Later Features

These features should be designed for, but do not need to be part of the first MVP.

### Target Assistant

Provide recommendations based on:

* The tank’s current target.
* Raid target markers.
* Whether party members are attacking the same target.
* Whether the current target is dead, friendly or crowd-controlled.
* Configurable target priority.

The addon may highlight or recommend a target but must not select it automatically.

### Mana Assistant

Monitor:

* Current and maximum mana.
* Percentage of mana remaining.
* Mana potion availability and cooldown.
* Judgement and Seal usage.
* Expensive abilities such as Consecration.
* Time spent at full mana.
* Mana thresholds configured by the user.

Possible recommendations:

* Conserve mana.
* Use a lower spell rank.
* Avoid Consecration for the current situation.
* Use a mana-restoring consumable.
* Drink after combat.
* Refresh Judgement of Wisdom.

### Damage Recommendations

Provide a simple priority recommendation rather than a full rotation engine.

Possible inputs:

* Current Seal.
* Active Judgement on the target.
* Ability cooldowns.
* Target type and expected lifetime.
* Mana percentage.
* Number of nearby enemies where the API allows reliable detection.
* Paladin specialization or manually selected play style.

Possible outputs:

* Activate a specific Seal.
* Use Judgement.
* Use Consecration.
* Use Hammer of Wrath.
* Continue auto-attacking.
* Conserve mana.

### Combat Summary

After combat, optionally report:

* Blessing uptime.
* Judgement of Wisdom uptime.
* Time spent at very low or full mana.
* Number of Judgements used.
* Long periods without attacking.
* Key missed opportunities.

This should remain lightweight and should not attempt to replace a damage meter.

## Suggested File Structure

```text
PalAddIn/
├── PalAddIn.toc
├── Core.lua
├── Database.lua
├── Group.lua
├── Blessings.lua
├── Wisdom.lua
├── Actions.lua
├── Macros.lua
├── Recommendations.lua
├── Config.lua
├── UI.lua
└── Locales/
    ├── enUS.lua
    └── deDE.lua
```

For the first implementation, fewer files are acceptable. Avoid premature framework-style abstraction.

## Technical Requirements

* Lua compatible with the current WoW Classic client.
* Event-driven implementation.
* No continuous expensive polling.
* Throttle aura and target checks where necessary.
* Use current API namespaces rather than obsolete TBC-era examples.
* Check `InCombatLockdown()` before modifying protected UI elements or macros.
* Use secure button templates for actions that must work during combat.
* Avoid tainting Blizzard UI elements.
* Handle unavailable or changed APIs gracefully.
* Include an optional debug mode with useful event and state logging.
* Avoid hard-coded localized spell names for internal logic.
* Keep displayed text localizable.
* Do not bundle large external libraries unless clearly justified.

## Relevant Events

Investigate the current equivalents of events such as:

```text
ADDON_LOADED
PLAYER_LOGIN
PLAYER_ENTERING_WORLD
GROUP_ROSTER_UPDATE
PLAYER_TARGET_CHANGED
UNIT_AURA
UNIT_POWER_UPDATE
SPELL_UPDATE_COOLDOWN
PLAYER_REGEN_DISABLED
PLAYER_REGEN_ENABLED
```

Do not assume historical API signatures are still valid. Confirm them against the current Anniversary client.

## Combat Restrictions

PalAddIn must comply with Blizzard’s secure-action restrictions.

The addon must not:

* Automatically cast spells.
* Automatically select or change targets.
* Decide and execute a combat action.
* Reconfigure secure buttons during combat.
* Create or edit macros during combat.
* Simulate hardware input.
* Circumvent protected API restrictions.

Recommendations must always require the player to press a button or key.

## Implementation Order

### Milestone 1: Addon Skeleton

* Valid `.toc` file.
* Addon loading and initialization.
* Persistent database.
* Slash commands.
* Debug logging.

### Milestone 2: Group and Blessing Assistant

* Detect party members.
* Configure blessing assignments.
* Detect missing and expiring blessings.
* Display compact status UI.
* Persist assignments.

### Milestone 3: Heal and Follow Actions

* Secure action buttons.
* Configurable healing spell.
* Optional macro generation.
* Safe handling of combat lockdown.

### Milestone 4: Judgement of Wisdom

* Inspect current hostile target.
* Detect Judgement of Wisdom.
* Display missing and expiration warnings.
* Add configurable reminder modes.

### Milestone 5: Usability

* German and English localization.
* Movable and scalable UI.
* Sounds and visual emphasis.
* Robust error handling.
* Test checklist and README.

## MVP Acceptance Criteria

The MVP is complete when:

1. The addon loads without Lua errors on TBC Classic Anniversary.
2. It detects all members of a five-player party.
3. A blessing can be assigned to every party member.
4. Assignments survive `/reload` and game restarts.
5. Missing and expiring blessings are clearly visible.
6. The current target’s Judgement of Wisdom status is displayed.
7. Heal and follow actions can be configured for every party member.
8. Optional macros can be generated without overwriting unrelated macros.
9. No protected action is attempted during combat.
10. The addon remains usable with both English and German clients.
11. Debug mode provides enough information to diagnose API incompatibilities.

## Initial Deliverable

Create the first working version containing:

* Addon skeleton and `.toc`.
* Persistent configuration.
* Party detection.
* Blessing assignments.
* Missing and expiring blessing indicators.
* Basic movable UI.
* Slash commands.
* Debug logging.

Do not implement the full combat recommendation system initially. Establish a reliable group and blessing assistant first, then add secure actions and Judgement of Wisdom support incrementally.
