-- Thin shim over the API calls that changed between the original TBC client and
-- the modernized Anniversary client. Everything else in the addon goes through
-- here, so an API change only has to be fixed in one place.
local _, ns = ...

local Compat = {}
ns.Compat = Compat

local C_UnitAuras = _G.C_UnitAuras
local C_Spell = _G.C_Spell

-- Which aura API this client offers is resolved once, at load, so the choice is
-- visible in debug output instead of being re-guessed on every scan.
local getAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local unitAura = _G.UnitAura

Compat.auraApi = (getAuraDataByIndex and "C_UnitAuras.GetAuraDataByIndex")
    or (unitAura and "UnitAura")
    or "none"

-- Returns: name, icon, duration, expirationTime, sourceUnit, spellId
-- duration/expirationTime are 0 for permanent auras.
-- Returns nil both for "no aura at this index" and for an unusable API, so the
-- caller's scan loop terminates either way instead of erroring.
function Compat.GetAura(unit, index, filter)
    if getAuraDataByIndex then
        local data = getAuraDataByIndex(unit, index, filter)
        if not data then return nil end
        return data.name, data.icon, data.duration, data.expirationTime, data.sourceUnit, data.spellId
    end

    if unitAura then
        local name, icon, _, _, duration, expirationTime, source, _, _, spellId = unitAura(unit, index, filter)
        if not name then return nil end
        return name, icon, duration, expirationTime, source, spellId
    end

    return nil
end

-- Returns the localized spell name for a spell ID, or nil if the client does
-- not know that ID (wrong rank, wrong expansion, typo in our tables).
function Compat.GetSpellName(spellID)
    if C_Spell then
        if C_Spell.GetSpellName then
            return C_Spell.GetSpellName(spellID)
        end
        if C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            return info and info.name
        end
    end

    local GetSpellInfo = _G.GetSpellInfo
    if GetSpellInfo then
        return (GetSpellInfo(spellID))
    end
    return nil
end

function Compat.GetSpellTexture(spellID)
    if C_Spell then
        if C_Spell.GetSpellTexture then
            return C_Spell.GetSpellTexture(spellID)
        end
        if C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            return info and info.iconID
        end
    end

    local GetSpellInfo = _G.GetSpellInfo
    if GetSpellInfo then
        return (select(3, GetSpellInfo(spellID)))
    end
    return nil
end

function Compat.GetClassColor(classFile)
    if not classFile then return 1, 1, 1 end
    if _G.C_ClassColor and _G.C_ClassColor.GetClassColor then
        local color = _G.C_ClassColor.GetClassColor(classFile)
        if color then return color.r, color.g, color.b end
    end
    local colors = _G.RAID_CLASS_COLORS
    local color = colors and colors[classFile]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

-- Realm-qualified key for a unit, e.g. "Thrall-Firemaw". Returns nil while the
-- unit's name is still being resolved by the client.
function Compat.UnitKey(unit)
    if not UnitExists(unit) then return nil end
    local name, realm = UnitName(unit)
    if not name or name == "" or name == _G.UNKNOWNOBJECT then return nil end
    if not realm or realm == "" then realm = ns.playerRealm end
    return name .. "-" .. (realm or "")
end

function Compat.GetPlayerRealm()
    local realm = _G.GetNormalizedRealmName and GetNormalizedRealmName()
    if realm and realm ~= "" then return realm end
    realm = GetRealmName() or ""
    return (realm:gsub("%s+", ""))
end
