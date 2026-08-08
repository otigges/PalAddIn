-- Event wiring, slash commands and debug logging.
local ADDON_NAME, ns = ...

local L = ns.L
local Database = ns.Database
local Blessings = ns.Blessings
local Group = ns.Group
local UI = ns.UI
local Compat = ns.Compat

local Core = {}
ns.Core = Core

local PREFIX = "|cff4a9effPalAddIn|r: "

local function print_(message)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end
ns.Print = print_

-- Safe before the database exists (Debug is called from Blessings:Build()).
function ns.Debug(format, ...)
    local db = Database.db
    if not db or not db.settings.debug then return end
    local ok, message = pcall(string.format, format, ...)
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888PalAddIn debug:|r " .. (ok and message or format))
end

--------------------------------------------------------------------------------
-- Refresh scheduling
--------------------------------------------------------------------------------

-- Events are coalesced into at most one refresh per frame, and a 1s ticker
-- keeps the expiry countdowns moving. No polling beyond that.
local dirty = false

function Core:RequestRefresh()
    dirty = true
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "PalAddInEventFrame")

local handlers = {}

handlers.ADDON_LOADED = function(name)
    if name ~= ADDON_NAME then return end
    Database:Initialize()
    ns.Debug("database initialized (schema %d)", Database.db.version)
end

handlers.PLAYER_LOGIN = function()
    ns.playerRealm = Compat.GetPlayerRealm()
    Blessings:Build()
    Group:Update()
    UI:Initialize()
    if not Database:Settings().enabled then UI:Hide() end
    Core:RequestRefresh()

    local _, class = UnitClass("player")
    if class ~= "PALADIN" then
        ns.Debug("player is not a paladin (%s); addon still available", tostring(class))
    end
end

handlers.PLAYER_ENTERING_WORLD = function()
    Group:Update()
    Core:RequestRefresh()
end

handlers.GROUP_ROSTER_UPDATE = function()
    Group:Update()
    Core:RequestRefresh()
end

handlers.UNIT_AURA = function(unit)
    if Group:TracksUnit(unit) then
        Core:RequestRefresh()
    end
end

handlers.PLAYER_REGEN_ENABLED = function()
    Core:RequestRefresh()
end

handlers.PLAYER_REGEN_DISABLED = function()
    Core:RequestRefresh()
end

for event in pairs(handlers) do
    eventFrame:RegisterEvent(event)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if not handler then return end
    if event ~= "ADDON_LOADED" and event ~= "PLAYER_LOGIN" then
        if not Database.db or not Database.db.settings.enabled then return end
    end
    handler(...)
end)

eventFrame:SetScript("OnUpdate", function()
    if not dirty then return end
    dirty = false
    UI:Refresh()
end)

C_Timer.NewTicker(1, function()
    if Database.db and Database.db.settings.enabled then
        Core:RequestRefresh()
    end
end)

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

local function boolFromArg(arg, current)
    if arg == "on" or arg == "1" or arg == "true" then return true end
    if arg == "off" or arg == "0" or arg == "false" then return false end
    return not current
end

local function showHelp()
    print_(L["Commands:"])
    local lines = {
        { "/paladdin", L["toggle the window"] },
        { "/paladdin lock", L["lock or unlock the window"] },
        { "/paladdin reset", L["reset window position and scale"] },
        { "/paladdin sound", L["toggle reminder sound"] },
        { "/paladdin warn <seconds>", L["set the expiration warning in seconds"] },
        { "/paladdin enable|disable", L["enable or disable the addon"] },
        { "/paladdin debug", L["toggle debug logging"] },
        { "/paladdin help", L["show this help"] },
    }
    for _, line in ipairs(lines) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffff00%s|r - %s", line[1], line[2]))
    end
end

local commands = {}

commands.lock = function(arg)
    local ui = Database:UI()
    ui.locked = boolFromArg(arg, ui.locked)
    print_(ui.locked and L["Window locked."] or L["Window unlocked."])
end

commands.reset = function()
    Database:ResetUI()
    UI:ApplyLayout()
    print_(L["UI position reset."])
end

commands.debug = function(arg)
    local settings = Database:Settings()
    settings.debug = boolFromArg(arg, settings.debug)
    print_(settings.debug and L["Debug mode enabled."] or L["Debug mode disabled."])
end

commands.sound = function(arg)
    local settings = Database:Settings()
    settings.soundEnabled = boolFromArg(arg, settings.soundEnabled)
    print_(settings.soundEnabled and L["Sound enabled."] or L["Sound disabled."])
end

commands.warn = function(arg)
    local seconds = tonumber(arg)
    if not seconds then return showHelp() end
    seconds = math.max(0, math.min(300, math.floor(seconds)))
    Database:Settings().expirationWarningSeconds = seconds
    print_(string.format(L["Expiration warning set to %d seconds."], seconds))
    Core:RequestRefresh()
end

commands.enable = function()
    Database:Settings().enabled = true
    print_(L["Addon enabled."])
    Group:Update()
    UI:Show()
end

commands.disable = function()
    Database:Settings().enabled = false
    print_(L["Addon disabled."])
    UI:Hide()
end

commands.help = showHelp

-- `config` currently has no dedicated panel; assignments are made in the main
-- window, so it just opens it.
commands.config = function() UI:Show() end

SLASH_PALADDIN1 = "/paladdin"
SLASH_PALADDIN2 = "/pal"

SlashCmdList["PALADDIN"] = function(input)
    local command, rest = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "" then
        UI:Toggle()
        return
    end
    local handler = commands[command]
    if handler then
        handler(rest ~= "" and rest or nil)
    else
        showHelp()
    end
end
