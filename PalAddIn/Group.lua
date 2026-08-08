-- Party roster tracking. Raids are out of scope for the MVP; in a raid the
-- addon simply falls back to showing the player alone.
local _, ns = ...

local Group = {}
ns.Group = Group

local Compat = ns.Compat

Group.members = {}     -- ordered list of { unit, key, name, class }
Group.unitLookup = {}  -- [unit] = true, for cheap UNIT_AURA filtering

local UNITS = { "player", "party1", "party2", "party3", "party4" }

-- Rebuilds the roster. Returns true when the roster actually changed, so
-- callers can skip redundant UI rebuilds on the roster-update spam WoW emits.
function Group:Update()
    local previous = {}
    for index, member in ipairs(self.members) do
        previous[index] = member.key
    end

    wipe(self.members)
    wipe(self.unitLookup)

    for _, unit in ipairs(UNITS) do
        if UnitExists(unit) then
            local key = Compat.UnitKey(unit)
            local _, class = UnitClass(unit)
            self.members[#self.members + 1] = {
                unit = unit,
                key = key,
                name = UnitName(unit) or (key or unit),
                class = class,
            }
            self.unitLookup[unit] = true
        end
    end

    local changed = #self.members ~= #previous
    if not changed then
        for index, member in ipairs(self.members) do
            if member.key ~= previous[index] then
                changed = true
                break
            end
        end
    end

    if changed then
        ns.Debug("roster updated: %d member(s)", #self.members)
    end
    return changed
end

function Group:IsInParty()
    return #self.members > 1
end

function Group:TracksUnit(unit)
    return unit and self.unitLookup[unit] or false
end
