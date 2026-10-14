-- the movable on-screen reminder frame
local ADDON_NAME, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local LSM = LibStub("LibSharedMedia-3.0")

local Display = {}
ns.Display = Display

local WARNING_COLOR = {1, 0.35, 0.24}
local ANCHOR_WIDTH, ANCHOR_HEIGHT = 320, 40

local frame, placeholder, timer
local lines = {}
local currentItems, currentSource

local function settings() return ns.addon.db.profile.display end

-- the western Friz Quadrata has no Cyrillic, so Russian names in the note show as boxes.
-- the Cyrillic file ships with every client but misses some accented letters, hence the option
local LATIN_FRIZ, CYRILLIC_FRIZ = "Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT___CYR.TTF"

local function fontPath()
    local path = LSM:Fetch("font", settings().font, true) or STANDARD_TEXT_FONT
    if settings().cyrillicFriz and type(path) == "string" and path:upper() == LATIN_FRIZ:upper() then return CYRILLIC_FRIZ end
    return path
end

local function outlineFlag()
    local outline = settings().outline
    return outline ~= "NONE" and outline or ""
end

-- anchor centre relative to screen centre, rounded to whole pixels
local function centerOffset()
    local cx, cy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return math.floor(cx * scale - ux + 0.5), math.floor(cy * scale - uy + 0.5)
end

-- always store CENTER offsets so the settings tab can show plain x/y
local function savePosition()
    local db = settings()
    db.point, db.relativePoint = "CENTER", "CENTER"
    db.x, db.y = centerOffset()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    if ns.Options then ns.Options:OnAnchorMoved(db.x, db.y) end
end

local function onDragUpdate() if ns.Options then ns.Options:OnAnchorMoved(centerOffset()) end end

local function createFrame()
    frame = CreateFrame("Frame", ADDON_NAME .. "Anchor", UIParent, "BackdropTemplate")
    frame:SetSize(ANCHOR_WIDTH, ANCHOR_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not settings().locked then
            self:StartMoving()
            self:SetScript("OnUpdate", onDragUpdate)
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        savePosition()
    end)
    frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})

    placeholder = frame:CreateFontString(nil, "OVERLAY")
    placeholder:SetPoint("CENTER")
    frame:Hide()
end

local function getLine(index)
    local line = lines[index]
    if not line then
        line = frame:CreateFontString(nil, "OVERLAY")
        line:SetWordWrap(false)
        lines[index] = line
    end
    return line
end

-- DOWN: first line at the top, rest below. UP: last line at the bottom, rest above. same reading order
local function layoutLine(line, index, count)
    local db = settings()
    local justify = db.justify
    local up = db.growth == "UP"
    local horizontal = justify == "LEFT" and "LEFT" or justify == "RIGHT" and "RIGHT" or ""
    local point = (up and "BOTTOM" or "TOP") .. horizontal
    local step = db.fontSize + db.spacing
    local y = up and (count - index) * step or -(index - 1) * step
    line:ClearAllPoints()
    line:SetPoint(point, frame, point, 0, y)
    line:SetJustifyH(justify)
    line:SetFont(fontPath(), db.fontSize, outlineFlag())
end

-- edit boxes save a typed | as ||, so undo that to let colour codes, textures, atlases and links work
function Display.FormatText(text) return (text:gsub("||", "|")) end

local function itemText(item)
    if item.missingLine then return format(L["No text for line %d (%s)"], item.missingLine, item.reminderName), WARNING_COLOR end
    return Display.FormatText(ns.Wildcards.Expand(item.template, item.vars, ns.Wildcards.Lookup))
end

local function render()
    local count = 0
    if currentItems then
        for index, item in ipairs(currentItems) do
            local line = getLine(index)
            local text, color = itemText(item)
            layoutLine(line, index, #currentItems)
            line:SetText(text)
            line:SetTextColor(unpack(color or {1, 1, 1}))
            line:Show()
            count = index
        end
    end
    for index = count + 1, #lines do lines[index]:Hide() end
end

function Display:ApplySettings()
    if not frame then createFrame() end
    local db = settings()
    frame:ClearAllPoints()
    frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    local accent = ns.Style and ns.Style.ACCENT or {0.3, 0.7, 1}
    if db.locked then
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(0, 0, 0, 0)
        frame:EnableMouse(false)
        placeholder:Hide()
        if not currentItems then frame:Hide() end
    else
        frame:SetBackdropColor(0.05, 0.05, 0.07, 0.75)
        frame:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        frame:EnableMouse(true)
        placeholder:SetFont(fontPath(), db.fontSize, outlineFlag())
        placeholder:SetText(L["Text anchor"])
        placeholder:SetShown(not currentItems)
        frame:Show()
    end
    render()
end

function Display:SetPosition(x, y)
    local db = settings()
    db.point, db.relativePoint, db.x, db.y = "CENTER", "CENTER", x, y
    self:ApplySettings()
end

-- replaces whatever is showing. source is an optional tag so callers can check IsShowing(source)
function Display:ShowItems(items, source)
    if not frame then createFrame() end
    if timer then ns.addon:CancelTimer(timer) end
    currentItems, currentSource = items, source
    placeholder:Hide()
    render()
    frame:Show()
    timer = ns.addon:ScheduleTimer(function() Display:HideItems() end, settings().duration)
end

function Display:HideItems()
    if timer then ns.addon:CancelTimer(timer) end
    timer, currentItems, currentSource = nil, nil, nil
    if not frame then return end
    render()
    if settings().locked then
        frame:Hide()
    else
        placeholder:Show()
    end
end

-- called once an NPC or spell name finishes loading
function Display:Refresh() if currentItems then render() end end

function Display:IsShowingItems() return currentItems ~= nil end

function Display:IsShowing(source) return currentItems ~= nil and currentSource == source end
