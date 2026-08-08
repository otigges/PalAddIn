-- Compact party overview: one row per party member showing the assigned
-- blessing and its current status. Deliberately built from plain frames and
-- textures rather than XML templates that may not exist on every client build.
local _, ns = ...

local UI = {}
ns.UI = UI

local L = ns.L
local Blessings = ns.Blessings
local Group = ns.Group
local Compat = ns.Compat

local ROW_HEIGHT = 20
local FRAME_WIDTH = 380
local HEADER_HEIGHT = 42
local MAX_ROWS = 5

-- Column offsets within a row, in row-local coordinates. Wide enough for the
-- longest German blessing name ("Segen der Erlösung") at the small font.
local COL_NAME = { x = 2, w = 100 }
local COL_BLESSING = { x = 106, w = 150 }
local COL_STATUS = { x = 262, w = 100 }

-- Row background tint, so a missing blessing is visible from across the screen
-- rather than only as small red text.
local ROW_TINT = {
    MISSING  = { 0.65, 0.10, 0.10, 0.55 },
    EXPIRING = { 0.65, 0.42, 0.05, 0.45 },
    WRONG    = { 0.60, 0.30, 0.05, 0.45 },
}

local STATUS_COLORS = {
    ACTIVE     = { 0.25, 0.85, 0.30 },
    EXPIRING   = { 1.00, 0.75, 0.15 },
    MISSING    = { 1.00, 0.25, 0.25 },
    WRONG      = { 1.00, 0.50, 0.10 },
    UNASSIGNED = { 0.60, 0.60, 0.60 },
    UNKNOWN    = { 0.55, 0.55, 0.65 },
    OFFLINE    = { 0.50, 0.50, 0.50 },
    DEAD       = { 0.55, 0.45, 0.45 },
}

local STATUS_TEXT = {
    ACTIVE     = "Active",
    EXPIRING   = "Expires soon",
    MISSING    = "Missing",
    WRONG      = "Wrong blessing",
    UNASSIGNED = "Unassigned",
    UNKNOWN    = "Out of range",
    OFFLINE    = "Offline",
    DEAD       = "Dead",
}

local frame, menu
local rows = {}
local lastSoundAt = 0
local scratchAttention = {}

local function addBackground(target, r, g, b, a)
    local texture = target:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(target)
    texture:SetColorTexture(r, g, b, a)
    return texture
end

--------------------------------------------------------------------------------
-- Blessing selection menu
--------------------------------------------------------------------------------

local function createMenu()
    menu = CreateFrame("Frame", "PalAddInBlessingMenu", UIParent)
    menu:SetSize(COL_BLESSING.w + 30, 10)
    menu:Hide()
    addBackground(menu, 0.05, 0.05, 0.07, 0.95)

    menu.buttons = {}

    -- A full-screen invisible button behind the menu closes it on any click
    -- elsewhere. This replaces an earlier timed "hide once the mouse leaves",
    -- which closed the menu while the user was still deciding.
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:Hide()
    catcher:SetScript("OnClick", function() menu:Hide() end)
    -- Above the catcher, so the menu's own buttons still receive their clicks.
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu.catcher = catcher

    menu:SetScript("OnShow", function(self) self.catcher:Show() end)
    menu:SetScript("OnHide", function(self)
        self.playerKey = nil
        self.catcher:Hide()
    end)

    local entries = {}
    for _, key in ipairs(Blessings.ORDER) do
        entries[#entries + 1] = key
    end
    entries[#entries + 1] = false -- "Clear assignment"

    for index, key in ipairs(entries) do
        local button = CreateFrame("Button", nil, menu)
        button:SetSize(COL_BLESSING.w + 22, 18)
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (index - 1) * 18)

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetColorTexture(0.3, 0.4, 0.8, 0.4)

        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.text:SetPoint("LEFT", button, "LEFT", 4, 0)
        button.blessingKey = key or nil

        button:SetScript("OnClick", function(self)
            local playerKey = menu.playerKey
            menu:Hide()
            if playerKey then
                ns.Database:SetAssignment(playerKey, self.blessingKey)
                ns.Debug("assigned %s to %s", tostring(self.blessingKey), playerKey)
                UI:Refresh()
            end
        end)

        menu.buttons[index] = button
    end

    menu:SetHeight(8 + #entries * 18)
    return menu
end

function UI:ShowBlessingMenu(anchor, playerKey)
    if not menu then createMenu() end

    if menu:IsShown() and menu.playerKey == playerKey then
        menu:Hide()
        return
    end

    for _, button in ipairs(menu.buttons) do
        button.text:SetText(button.blessingKey and Blessings:GetDisplayName(button.blessingKey)
            or L["Clear assignment"])
    end

    menu.playerKey = playerKey
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menu:Show()
end

--------------------------------------------------------------------------------
-- Main window
--------------------------------------------------------------------------------

local function createRow(index, parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_WIDTH - 16, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -(HEADER_HEIGHT + (index - 1) * ROW_HEIGHT))

    row.bg = row:CreateTexture(nil, "BORDER")
    row.bg:SetAllPoints(row)
    row.bg:SetColorTexture(0, 0, 0, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", row, "LEFT", COL_NAME.x, 0)
    row.name:SetWidth(COL_NAME.w)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.button:SetSize(COL_BLESSING.w, 18)
    row.button:SetPoint("LEFT", row, "LEFT", COL_BLESSING.x, 0)
    row.button:SetScript("OnClick", function(self)
        if self.playerKey then
            UI:ShowBlessingMenu(self, self.playerKey)
        end
    end)
    local buttonText = row.button:GetFontString()
    if buttonText then
        buttonText:SetFontObject("GameFontHighlightSmall")
        -- Truncate with an ellipsis instead of spilling past the button edge.
        buttonText:SetWidth(COL_BLESSING.w - 10)
        buttonText:SetWordWrap(false)
    end

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", row, "LEFT", COL_STATUS.x, 0)
    row.status:SetWidth(COL_STATUS.w)
    row.status:SetJustifyH("LEFT")
    row.status:SetWordWrap(false)

    return row
end

local function createFrame()
    frame = CreateFrame("Frame", "PalAddInFrame", UIParent)
    frame:SetSize(FRAME_WIDTH, HEADER_HEIGHT + MAX_ROWS * ROW_HEIGHT + 8)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    addBackground(frame, 0, 0, 0, 0.75)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
    frame.title:SetText(L["PalAddIn"])

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    frame.close:SetScript("OnClick", function()
        UI:Hide()
        -- Hiding persists across sessions, so without this the window is simply
        -- gone with no on-screen clue how to get it back.
        ns.Print(L["Window hidden. Type /paladdin to show it again."])
    end)

    -- Headers line up with the row columns; rows start at x = 8 inside the frame.
    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + COL_NAME.x, -26)
    header:SetText(L["Player"])
    local headerBlessing = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headerBlessing:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + COL_BLESSING.x, -26)
    headerBlessing:SetText(L["Blessing"])
    local headerStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headerStatus:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + COL_STATUS.x, -26)
    headerStatus:SetText(L["Status"])

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -(HEADER_HEIGHT + 4))
    frame.empty:SetText(L["Not in a group"])
    frame.empty:Hide()

    frame:SetScript("OnDragStart", function(self)
        if not ns.Database:UI().locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.Database:UI().point = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)

    for index = 1, MAX_ROWS do
        rows[index] = createRow(index, frame)
    end

    return frame
end

function UI:Initialize()
    if not frame then createFrame() end
    self:ApplyLayout()

    local ui = ns.Database:UI()
    ns.Debug("UI initialized: shown=%s scale=%s point=%s",
        tostring(ui.shown), tostring(ui.scale),
        ui.point and (ui.point.point .. " " .. tostring(ui.point.x) .. "," .. tostring(ui.point.y)) or "default")

    if ui.shown then self:Show() else self:Hide() end
end

function UI:ApplyLayout()
    if not frame then return end
    local ui = ns.Database:UI()
    frame:SetScale(ui.scale or 1.0)
    frame:ClearAllPoints()
    if ui.point then
        frame:SetPoint(ui.point.point or "CENTER", UIParent, ui.point.relativePoint or "CENTER",
            ui.point.x or 0, ui.point.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function formatRemaining(seconds)
    if not seconds or seconds <= 0 then return "" end
    if seconds >= 60 then
        return string.format(" %d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    end
    return string.format(" %ds", math.floor(seconds))
end

function UI:Refresh()
    if not frame or not frame:IsShown() then return end

    local settings = ns.Database:Settings()
    local members = Group.members
    local missingCount = 0
    -- Reused between refreshes; this runs once a second.
    local needsAttention = wipe(scratchAttention)

    for index = 1, MAX_ROWS do
        local row = rows[index]
        local member = members[index]

        if not member then
            row:Hide()
        else
            row:Show()

            local r, g, b = Compat.GetClassColor(member.class)
            row.name:SetText(member.name)
            row.name:SetTextColor(r, g, b)

            local assigned = ns.Database:GetAssignment(member.key)
            row.button.playerKey = member.key
            row.button:SetText(assigned and Blessings:GetDisplayName(assigned) or L["None"])
            row.button:SetEnabled(member.key ~= nil)

            local status, activeKey, remaining =
                Blessings:GetStatus(member.unit, assigned, settings.expirationWarningSeconds)

            local text = L[STATUS_TEXT[status] or status]
            if status == "ACTIVE" or status == "EXPIRING" then
                text = text .. formatRemaining(remaining)
            elseif status == "WRONG" and activeKey then
                text = Blessings:GetDisplayName(activeKey)
            end

            local color = STATUS_COLORS[status] or { 1, 1, 1 }
            row.status:SetText(text)
            row.status:SetTextColor(color[1], color[2], color[3])

            local tint = ROW_TINT[status]
            if tint then
                row.bg:SetColorTexture(tint[1], tint[2], tint[3], tint[4])
                missingCount = missingCount + 1
                needsAttention[#needsAttention + 1] = member.key or member.name
            else
                row.bg:SetColorTexture(0, 0, 0, 0)
            end
        end
    end

    frame.empty:SetShown(#members == 0)

    -- The title doubles as the at-a-glance summary, so a glance at the window
    -- answers "do I need to bless anyone" without reading every row.
    if missingCount > 0 then
        frame.title:SetText(L["PalAddIn"] .. " - " .. string.format(L["%d missing"], missingCount))
        frame.title:SetTextColor(1, 0.45, 0.15)
    else
        frame.title:SetText(L["PalAddIn"])
        frame.title:SetTextColor(1, 0.82, 0)
    end

    self:UpdateReminder(needsAttention, settings)
end

-- Sound fires when the set of players needing attention *changes*, not on a
-- fixed timer, so it prompts once per problem instead of nagging every 10s.
local lastSignature = ""

function UI:UpdateReminder(needsAttention, settings)
    local signature = table.concat(needsAttention, "|")
    if signature == lastSignature then return end

    local wasEmpty = lastSignature == ""
    lastSignature = signature

    if signature == "" or not settings.soundEnabled then return end

    -- Only announce genuinely new problems, and only out of combat: mid-fight
    -- is exactly when re-blessing is not the right call.
    if not wasEmpty or InCombatLockdown() then return end

    local now = GetTime()
    if now - lastSoundAt < 5 then return end
    lastSoundAt = now
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 88)
end

function UI:Show()
    if not frame then return end
    ns.Database:UI().shown = true
    frame:Show()
    self:Refresh()
end

function UI:Hide()
    if not frame then return end
    ns.Database:UI().shown = false
    if menu then menu:Hide() end
    frame:Hide()
end

function UI:Toggle()
    if frame and frame:IsShown() then self:Hide() else self:Show() end
end

function UI:IsShown()
    return frame and frame:IsShown()
end
