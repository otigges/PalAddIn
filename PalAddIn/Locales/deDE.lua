local _, ns = ...

if GetLocale() ~= "deDE" then return end

local L = ns.L

-- Blessing names are never translated here; they come from the client's own
-- spell data, so they are always correct for whatever locale is running.
L["Player"] = "Spieler"
L["Blessing"] = "Segen"
L["Status"] = "Status"
L["Active"] = "Aktiv"
L["Missing"] = "Fehlt"
L["Expires soon"] = "Läuft bald ab"
L["Wrong blessing"] = "Falscher Segen"
L["Unassigned"] = "Nicht zugewiesen"
L["Out of range"] = "Außer Reichweite"
L["Offline"] = "Offline"
L["Dead"] = "Tot"
L["None"] = "Keiner"
L["Not in a group"] = "Nicht in einer Gruppe"
L["Assign a blessing"] = "Segen zuweisen"
L["Clear assignment"] = "Zuweisung entfernen"
L["Window locked."] = "Fenster gesperrt."
L["Window unlocked."] = "Fenster entsperrt."
L["UI position reset."] = "Fensterposition zurückgesetzt."
L["Debug mode enabled."] = "Debugmodus aktiviert."
L["Debug mode disabled."] = "Debugmodus deaktiviert."
L["Sound enabled."] = "Ton aktiviert."
L["Sound disabled."] = "Ton deaktiviert."
L["Addon enabled."] = "Addon aktiviert."
L["Addon disabled."] = "Addon deaktiviert."
L["Expiration warning set to %d seconds."] = "Ablaufwarnung auf %d Sekunden gesetzt."
L["Commands:"] = "Befehle:"
L["toggle the window"] = "Fenster ein-/ausblenden"
L["lock or unlock the window"] = "Fenster sperren/entsperren"
L["reset window position and scale"] = "Fensterposition und -größe zurücksetzen"
L["toggle debug logging"] = "Debugausgabe ein-/ausschalten"
L["toggle reminder sound"] = "Erinnerungston ein-/ausschalten"
L["set the expiration warning in seconds"] = "Ablaufwarnung in Sekunden setzen"
L["enable or disable the addon"] = "Addon aktivieren oder deaktivieren"
L["show this help"] = "diese Hilfe anzeigen"
