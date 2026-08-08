-- enUS is the fallback locale. Every key used anywhere in the addon must exist here.
local _, ns = ...

local L = setmetatable({}, {
    -- A missing translation falls back to the key itself, so a typo shows up as
    -- readable English instead of "nil".
    __index = function(t, key) return key end,
})

ns.L = L

L["PalAddIn"] = "PalAddIn"
L["Player"] = "Player"
L["Blessing"] = "Blessing"
L["Status"] = "Status"
L["Active"] = "Active"
L["Missing"] = "Missing"
L["Expires soon"] = "Expires soon"
L["Wrong blessing"] = "Wrong blessing"
L["Unassigned"] = "Unassigned"
L["Out of range"] = "Out of range"
L["Offline"] = "Offline"
L["Dead"] = "Dead"
L["None"] = "None"
L["Not in a group"] = "Not in a group"
L["%d missing"] = "%d missing"
L["Assign a blessing"] = "Assign a blessing"
L["Clear assignment"] = "Clear assignment"
L["Window hidden. Type /paladdin to show it again."] = "Window hidden. Type /paladdin to show it again."
L["Window locked."] = "Window locked."
L["Window unlocked."] = "Window unlocked."
L["UI position reset."] = "UI position reset."
L["Debug mode enabled."] = "Debug mode enabled."
L["Debug mode disabled."] = "Debug mode disabled."
L["Sound enabled."] = "Sound enabled."
L["Sound disabled."] = "Sound disabled."
L["Addon enabled."] = "Addon enabled."
L["Addon disabled."] = "Addon disabled."
L["Expiration warning set to %d seconds."] = "Expiration warning set to %d seconds."
L["Commands:"] = "Commands:"
L["toggle the window"] = "toggle the window"
L["lock or unlock the window"] = "lock or unlock the window"
L["reset window position and scale"] = "reset window position and scale"
L["toggle debug logging"] = "toggle debug logging"
L["toggle reminder sound"] = "toggle reminder sound"
L["set the expiration warning in seconds"] = "set the expiration warning in seconds"
L["enable or disable the addon"] = "enable or disable the addon"
L["show this help"] = "show this help"
