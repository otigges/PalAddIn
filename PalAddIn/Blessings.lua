-- Blessing spell data and aura inspection.
--
-- Blessings are identified by a stable key ("MIGHT"), never by a rank-specific
-- spell ID or a localized name. Detection matches an aura in two ways:
--   1. by spell ID, against the rank tables below
--   2. by localized name, resolved from the client at login
-- The second pass means a wrong or missing ID in the tables degrades into a
-- still-working detection instead of a silent "Missing".
local _, ns = ...

local Blessings = {}
ns.Blessings = Blessings

local Compat = ns.Compat

-- Normal and Greater ranks through TBC. Greater ranks share the same key, so a
-- Greater Blessing of Might satisfies an assignment of "Might".
Blessings.ORDER = { "MIGHT", "WISDOM", "KINGS", "SALVATION", "LIGHT", "SANCTUARY" }

local SPELLS = {
    MIGHT = {
        normal  = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140 },
        greater = { 25782, 25916, 27141 },
    },
    WISDOM = {
        normal  = { 19742, 19850, 19852, 19853, 19854, 25290, 27142 },
        greater = { 25894, 25918, 27143 },
    },
    KINGS = {
        normal  = { 20217 },
        greater = { 25898 },
    },
    SALVATION = {
        normal  = { 1038 },
        greater = { 25895 },
    },
    LIGHT = {
        normal  = { 19977, 19978, 19979, 27144 },
        greater = { 25890, 27145 },
    },
    SANCTUARY = {
        normal  = { 20911, 20912, 20913, 20914, 27168 },
        greater = { 25899, 27169 },
    },
}

-- English fallbacks, used only if the client cannot resolve any of the IDs for
-- a blessing (which would also mean detection for it is broken).
local FALLBACK_NAMES = {
    MIGHT = "Blessing of Might",
    WISDOM = "Blessing of Wisdom",
    KINGS = "Blessing of Kings",
    SALVATION = "Blessing of Salvation",
    LIGHT = "Blessing of Light",
    SANCTUARY = "Blessing of Sanctuary",
}

local spellIDToKey = {}   -- [spellID]  = "MIGHT"
local nameToKey = {}      -- [localized name] = "MIGHT"
local displayName = {}    -- ["MIGHT"] = localized "Blessing of Might"
local displayIcon = {}    -- ["MIGHT"] = texture

-- Called once at PLAYER_LOGIN, when the client's spell data is available.
function Blessings:Build()
    wipe(spellIDToKey)
    wipe(nameToKey)
    wipe(displayName)
    wipe(displayIcon)

    local unresolved = {}

    for key, ranks in pairs(SPELLS) do
        for _, group in ipairs({ "normal", "greater" }) do
            for _, spellID in ipairs(ranks[group] or {}) do
                spellIDToKey[spellID] = key

                local name = Compat.GetSpellName(spellID)
                if name then
                    nameToKey[name] = key
                    -- Prefer the normal (non-Greater) name for display.
                    if group == "normal" and not displayName[key] then
                        displayName[key] = name
                        displayIcon[key] = Compat.GetSpellTexture(spellID)
                    end
                else
                    unresolved[#unresolved + 1] = spellID
                end
            end
        end

        if not displayName[key] then
            displayName[key] = FALLBACK_NAMES[key]
        end
    end

    if #unresolved > 0 then
        ns.Debug("unresolved spell IDs (%d): %s", #unresolved, table.concat(unresolved, ", "))
    end
end

function Blessings:GetDisplayName(key)
    return key and (displayName[key] or FALLBACK_NAMES[key] or key) or nil
end

function Blessings:GetIcon(key)
    return key and displayIcon[key] or nil
end

-- Finds the first paladin blessing on the unit. Returns key, expirationTime,
-- duration; or nil when the unit has no blessing at all.
function Blessings:FindOnUnit(unit)
    for index = 1, 40 do
        local name, _, duration, expirationTime, _, spellID = Compat.GetAura(unit, index, "HELPFUL")
        if not name then break end

        local key = (spellID and spellIDToKey[spellID]) or nameToKey[name]
        if key then
            return key, expirationTime or 0, duration or 0
        end
    end
    return nil
end

-- Status codes returned by GetStatus. The UI maps these to text and colors.
Blessings.STATUS = {
    UNASSIGNED = "UNASSIGNED",
    ACTIVE = "ACTIVE",
    EXPIRING = "EXPIRING",
    MISSING = "MISSING",
    WRONG = "WRONG",
    UNKNOWN = "UNKNOWN",   -- out of range: auras cannot be read reliably
    OFFLINE = "OFFLINE",
    DEAD = "DEAD",
}

-- Returns status, activeKey, secondsRemaining.
function Blessings:GetStatus(unit, assignedKey, warningSeconds)
    if not UnitIsConnected(unit) then
        return self.STATUS.OFFLINE, nil, nil
    end
    if UnitIsDeadOrGhost(unit) then
        return self.STATUS.DEAD, nil, nil
    end
    if not assignedKey then
        return self.STATUS.UNASSIGNED, nil, nil
    end
    -- Auras on units outside visibility range are stale, so we say "unknown"
    -- rather than falsely reporting a missing blessing.
    if not UnitIsVisible(unit) then
        return self.STATUS.UNKNOWN, nil, nil
    end

    local foundKey, expirationTime, duration = self:FindOnUnit(unit)
    if not foundKey then
        return self.STATUS.MISSING, nil, nil
    end
    if foundKey ~= assignedKey then
        return self.STATUS.WRONG, foundKey, nil
    end

    -- duration == 0 means a permanent aura; nothing to warn about.
    if duration and duration > 0 and expirationTime and expirationTime > 0 then
        local remaining = expirationTime - GetTime()
        if remaining <= (warningSeconds or 60) then
            return self.STATUS.EXPIRING, foundKey, remaining
        end
        return self.STATUS.ACTIVE, foundKey, remaining
    end

    return self.STATUS.ACTIVE, foundKey, nil
end
