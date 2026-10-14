-- anchor, font and layout settings, display time, minimap toggle and the Test button
local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local LSM = LibStub("LibSharedMedia-3.0")
local W, Style = ns.Widgets, ns.Style

local controls = {}
local ALL_BOSSES = "*"
local testBossKey = ALL_BOSSES

local function db() return ns.addon.db.profile.display end

local function setDisplay(key, value)
    db()[key] = value
    ns.Display:ApplySettings()
end

local function fontItems()
    local items = {}
    for _, name in ipairs(LSM:List("font")) do
        items[#items + 1] = {value = name, text = name, font = LSM:Fetch("font", name, true)}
    end
    return items
end

local OUTLINES = {
    {value = "NONE", text = L["None"]}, {value = "OUTLINE", text = L["Outline"]},
    {value = "THICKOUTLINE", text = L["Thick outline"]},
}

local JUSTIFY = {{value = "LEFT", text = L["Left"]}, {value = "CENTER", text = L["Center"]}, {value = "RIGHT", text = L["Right"]}}

local GROWTH = {{value = "DOWN", text = L["Down"]}, {value = "UP", text = L["Up"]}}

local function bossItems()
    local items = {{value = ALL_BOSSES, text = L["All bosses"]}}
    for _, boss in ns.Database.IterateBosses() do
        local raid = ns.Database.GetRaidOfBoss(boss)
        items[#items + 1] = {
            value = boss.key,
            text = format("%s - %s", ns.Database.GetBossName(boss), ns.Database.GetRaidName(raid)),
        }
    end
    return items
end

local function sectionTitle(parent, text, x, y)
    local label = W.Label(parent, text, 13, Style.ACCENT)
    label:SetPoint("TOPLEFT", x, y)
    return label
end

local function labeled(parent, text, x, y)
    local label = W.Label(parent, text)
    label:SetPoint("TOPLEFT", x, y)
    return label
end

-- applies on Enter or focus loss, bad input just snaps back to the saved value
local function coordinateBox(parent, key)
    local box = W.EditBox(parent, 90)
    local function apply(self)
        local value = tonumber(self:GetText())
        local display = db()
        if value then
            value = math.floor(value + 0.5)
            ns.Display:SetPosition(key == "x" and value or display.x, key == "y" and value or display.y)
        end
        self:SetText(tostring(display[key]))
    end
    box:SetScript("OnEnterPressed", function(self)
        apply(self)
        self:ClearFocus()
    end)
    box:HookScript("OnEditFocusLost", apply)
    return box
end

local function create(parent)
    local COLUMN = 300

    -- Anchor (left column)
    sectionTitle(parent, L["Anchor"], 0, 0)
    controls.unlock = W.CheckBox(parent, L["Unlock anchor"], function(checked) setDisplay("locked", not checked) end)
    controls.unlock:SetPoint("TOPLEFT", 0, -26)
    labeled(parent, L["X"], 0, -50)
    controls.x = coordinateBox(parent, "x")
    controls.x:SetPoint("TOPLEFT", 22, -46)
    labeled(parent, L["Y"], 120, -50)
    controls.y = coordinateBox(parent, "y")
    controls.y:SetPoint("TOPLEFT", 142, -46)
    local reset = W.Button(parent, L["Reset position"], nil, 22, function() ns.Display:SetPosition(0, 220) end)
    reset:FitWidth()
    reset:SetPoint("TOPLEFT", 0, -76)
    local positionHelp = W.Label(parent, L["Offsets of the anchor's center from the screen center."], 11, Style.MUTED)
    positionHelp:SetPoint("TOPLEFT", 0, -104)
    positionHelp:SetWidth(COLUMN)

    -- Text (left column)
    sectionTitle(parent, L["Text"], 0, -134)
    labeled(parent, L["Font"], 0, -158)
    controls.font = W.Dropdown(parent, COLUMN, fontItems, function(value) setDisplay("font", value) end)
    controls.font:SetPoint("TOPLEFT", 0, -174)
    controls.size = W.Slider(parent, L["Font size"], 8, 64, 1, COLUMN, function(value) setDisplay("fontSize", value) end)
    controls.size:SetPoint("TOPLEFT", 0, -204)
    labeled(parent, L["Outline"], 0, -248)
    controls.outline =
      W.Dropdown(parent, COLUMN, function() return OUTLINES end, function(value) setDisplay("outline", value) end)
    controls.outline:SetPoint("TOPLEFT", 0, -264)
    labeled(parent, L["Text alignment"], 0, -294)
    controls.justify = W.Dropdown(parent, COLUMN, function() return JUSTIFY end, function(value) setDisplay("justify", value) end)
    controls.justify:SetPoint("TOPLEFT", 0, -310)
    labeled(parent, L["Text growth"], 0, -340)
    controls.growth = W.Dropdown(parent, COLUMN, function() return GROWTH end, function(value) setDisplay("growth", value) end)
    controls.growth:SetPoint("TOPLEFT", 0, -356)
    controls.spacing = W.Slider(parent, L["Line spacing"], 0, 40, 1, COLUMN, function(value) setDisplay("spacing", value) end)
    controls.spacing:SetPoint("TOPLEFT", 0, -386)

    -- Behaviour and test (right column)
    local right = COLUMN + 60
    sectionTitle(parent, L["Behaviour"], right, 0)
    controls.duration = W.Slider(parent, L["Display duration (seconds)"], 3, 60, 1, COLUMN,
                                 function(value) setDisplay("duration", value) end)
    controls.duration:SetPoint("TOPLEFT", right, -26)
    controls.minimap = W.CheckBox(parent, L["Show minimap button"], function(checked) ns.addon:SetMinimapButtonShown(checked) end)
    controls.minimap:SetPoint("TOPLEFT", right, -76)

    sectionTitle(parent, L["Test"], right, -120)
    local testHelp = W.Label(parent,
                             L["Shows every loaded reminder with a test note that puts you on each of its lines. Zone and difficulty are ignored."],
                             nil, Style.MUTED)
    testHelp:SetPoint("TOPLEFT", right, -144)
    testHelp:SetWidth(COLUMN)
    controls.boss = W.Dropdown(parent, COLUMN, bossItems, function(value) testBossKey = value end)
    controls.boss:SetPoint("TOPLEFT", right, -184)
    local testButton = W.Button(parent, L["Test"], 100, 24,
                                function() ns.addon:TestAll(testBossKey ~= ALL_BOSSES and testBossKey or nil) end)
    testButton:SetPoint("TOPLEFT", right, -214)

    ns.Options.onAnchorMoved = function(x, y)
        if not controls.x:HasFocus() then controls.x:SetText(tostring(x)) end
        if not controls.y:HasFocus() then controls.y:SetText(tostring(y)) end
    end
end

local function refresh()
    local display = db()
    controls.unlock:SetChecked(not display.locked)
    controls.x:SetText(tostring(display.x))
    controls.y:SetText(tostring(display.y))
    controls.font:SetValue(display.font)
    controls.size:SetValue(display.fontSize)
    controls.outline:SetValue(display.outline)
    controls.justify:SetValue(display.justify)
    controls.growth:SetValue(display.growth)
    controls.spacing:SetValue(display.spacing)
    controls.duration:SetValue(display.duration)
    controls.minimap:SetChecked(not ns.addon.db.profile.minimap.hide)
    controls.boss:SetValue(testBossKey)
end

table.insert(ns.OptionsTabs, {key = "display", label = L["Display"], Create = create, Refresh = refresh})
