-- Per-character saved variables plus schema migration.
local _, ns = ...

local Database = {}
ns.Database = Database

Database.SCHEMA_VERSION = 1

local defaults = {
    version = Database.SCHEMA_VERSION,
    settings = {
        enabled = true,
        expirationWarningSeconds = 60,
        soundEnabled = false,
        debug = false,
    },
    -- ["Name-Realm"] = { blessingKey = "MIGHT" }
    playerAssignments = {},
    ui = {
        point = nil,        -- { point, relativePoint, x, y }
        scale = 1.0,
        locked = false,
        shown = true,
    },
}

local function applyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            applyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

-- Migrations are keyed by the version they upgrade *from*. Nothing to do yet,
-- but the hook exists so schema changes never need a wipe.
local migrations = {}

local function migrate(db)
    local version = tonumber(db.version) or 0
    while version < Database.SCHEMA_VERSION do
        local step = migrations[version]
        if not step then break end
        step(db)
        version = version + 1
    end
    db.version = Database.SCHEMA_VERSION
end

function Database:Initialize()
    if type(PalAddInDB) ~= "table" then PalAddInDB = {} end
    migrate(PalAddInDB)
    applyDefaults(PalAddInDB, defaults)
    self.db = PalAddInDB
    return self.db
end

function Database:Settings()
    return self.db.settings
end

function Database:UI()
    return self.db.ui
end

function Database:GetAssignment(playerKey)
    if not playerKey then return nil end
    local entry = self.db.playerAssignments[playerKey]
    return entry and entry.blessingKey or nil
end

-- Assignments are intentionally never pruned when someone leaves the group, so
-- a returning player keeps their blessing.
function Database:SetAssignment(playerKey, blessingKey)
    if not playerKey then return end
    if blessingKey then
        local entry = self.db.playerAssignments[playerKey] or {}
        entry.blessingKey = blessingKey
        self.db.playerAssignments[playerKey] = entry
    else
        self.db.playerAssignments[playerKey] = nil
    end
end

function Database:ResetUI()
    local ui = self.db.ui
    ui.point = nil
    ui.scale = defaults.ui.scale
    ui.locked = false
end
