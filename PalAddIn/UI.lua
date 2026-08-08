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
local FRAME_WIDTH = 300
local HEADER_HEIGHT = 42
local MAX_ROWS = 5

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
    menu:SetFrameStrata("DIALOG")
    menu:SetSize(160, 10)
    menu:Hide()
    addBackground(menu, 0.05, 0.05, 0.07, 0.95)

    menu.buttons = {}
    menu:SetScript("OnHide", function(self) self.playerKey = nil end)

    -- No global click-away handler exists without hooking Blizzard frames, so
    -- the menu closes shortly after the mouse leaves it.
    menu:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver(8, -8, -8, 8) then
            self.awayFor = 0
        else
            self.awayFor = (self.awayFor or 0) + elapsed
            if self.awayFor > 1.5 then self:Hide() end
        end
    end)
    menu:SetScript("OnShow", function(self) self.awayFor = 0 end)

    local entries = {}
    for _, key in ipairs(Blessings.ORDER) do
        entries[#entries + 1] = key
    end
    entries[#entries + 1] = false -- "Clear assignment"

    for index, key in ipairs(entries) do
        local button = CreateFrame("Button", nil, menu)
        button:SetSize(152, 18)
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

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.name:SetWidth(84)
    row.name:SetJustifyH("LEFT")

    row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.button:SetSize(110, 18)
    row.button:SetPoint("LEFT", row, "LEFT", 88, 0)
    row.button:SetScript("OnClick", function(self)
        if self.playerKey then
            UI:ShowBlessingMenu(self, self.playerKey)
        end
    end)
    local buttonText = row.button:GetFontString()
    if buttonText then buttonText:SetFontObject("GameFontHighlightSmall") end

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", row, "LEFT", 202, 0)
    row.status:SetWidth(82)
    row.status:SetJustifyH("LEFT")

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
    frame.close:SetScript("OnClick", function() UI:Hide() end)

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -26)
    header:SetText(L["Player"])
    local headerBlessing = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headerBlessing:SetPoint("TOPLEFT", frame, "TOPLEFT", 96, -26)
    headerBlessing:SetText(L["Blessing"])
    local headerStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headerStatus:SetPoint("TOPLEFT", frame, "TOPLEFT", 210, -26)
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
    if ns.Database:UI().shown then self:Show() else self:Hide() end
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

            if status == "MISSING" or status == "EXPIRING" or status == "WRONG" then
                missingCount = missingCount + 1
            end
        end
    end

    frame.empty:SetShown(#members == 0)

    -- Reminder sound: out of combat only, and throttled so it cannot turn into
    -- a machine gun while a blessing is being re-applied across the party.
    if settings.soundEnabled and missingCount > 0 and not InCombatLockdown() then
        local now = GetTime()
        if now - lastSoundAt > 10 then
            lastSoundAt = now
            PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 88)
        end
    end
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
