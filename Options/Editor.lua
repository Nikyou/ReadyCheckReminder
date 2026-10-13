-- Reminder editor: name, template fields, texts, load conditions, live preview.
-- Typing just saves and refreshes the preview, only structural changes redo the layout.

local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local W, Style = ns.Widgets, ns.Style

local Editor = {}
ns.Editor = Editor

local WIDTH = 456      -- content width
local PAD = 12
local LABEL_GAP = 16   -- label height above an input
local CHECK_ROW = 26   -- row height inside load condition boxes
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local scroll, content, hint
local body             -- everything under the preview, anchored to it so it moves when the preview grows
local origin           -- what place() positions against: content (header) or body
local previewTop, bodyHeight = 0, 0
local reminder, bossKey
local static = {}      -- every non-pooled widget, hidden before each layout
local lineRows, groupRows = {}, {}
local loadBoxes = {}   -- difficulty / role / range: { title, box, checks }
local classChecks, specChecks = {}, {}
local openSections = {} -- open class/spec sections, cleared when another reminder is opened

local function register(widget)
    static[#static + 1] = widget
    return widget
end

local function place(widget, x, y)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", origin, "TOPLEFT", x, -y)
    widget:Show()
end

local function changed(structural)
    if structural then Editor:Layout() end
    Editor:RefreshPreview()
    ns.RemindersTab.OnReminderChanged()
end

local function label(text, color, size)
    return register(W.Label(content, text, size, color))
end

local function sectionTitle(text)
    return label(text, Style.ACCENT, 13)
end

local function classColor(classFile)
    local color = C_ClassColor.GetClassColor(classFile)
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

-- keyword lines show the line as it's written in the note (soak1, soak2...), groups show "Line 1"
local function lineLabel(line)
    if reminder.type == "keywordLine" and (reminder.keyword or "") ~= "" then
        return reminder.keyword .. line
    end
    return format(L["Line %d"], line)
end

local function refreshLineLabels()
    for _, row in ipairs(lineRows) do
        if row:IsShown() then row.label:SetText(lineLabel(row.line)) end
    end
end

-- hover help for the text boxes, TimelineReminders style: "{code} -> what it turns into"
local ARROW = "|A:common-icon-forwardarrow:0:0|a"
local EXAMPLE_VARS = { line = 2, pos = 3 }

local function fillTextTooltip(tip)
    tip:SetText(L["Reminder text"])
    tip:AddLine(L["Some text replacements are supported, for example:"], 1, 1, 1, true)
    tip:AddLine(" ")
    local function example(code, result)
        result = result or ns.Display.FormatText(ns.Wildcards.Expand(code, EXAMPLE_VARS, ns.Wildcards.Lookup))
        tip:AddLine(code .. " " .. ARROW .. " " .. result, 1, 1, 1)
    end
    example("{spell:642}")
    example("{spellname:642}")
    example("{npc:<id>}", L["NPC name"])
    example("{icon:237510}")
    example("{texture:Interface\\TargetingFrame\\UI-RaidTargetingIcon_1}")
    example("{rt1}")
    example("{diamond}")
    example("{Demon Hunter}")
    example("{Frost Mage}")
    example("{tank} {healer} {dps}")
    if reminder and ns.Parser.SupportsLineVars(reminder.type) then
        example("{line}", L["line number"])
        example("{pos}", L["your position in the line"])
    end
    -- typed into an edit box the code is ||c...||r, shown here the same way
    example("||cffff0000" .. L["Text"] .. "||r", "|cffff0000" .. L["Text"] .. "|r")
    tip:AddLine(" ")
    tip:AddLine(L["Raid marker names work in every client language."], 0.6, 0.6, 0.6, true)
end

local function lineRow(index)
    local row = lineRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, content)
    row:SetSize(WIDTH - 2 * PAD, 24)
    row.label = W.Label(row, "", nil, Style.MUTED)
    row.label:SetPoint("LEFT")
    row.label:SetWidth(60)
    row.label:SetWordWrap(false)
    row.edit = W.EditBox(row, WIDTH - 2 * PAD - 64, function(text)
        reminder.texts[row.line] = text
        changed()
    end)
    W.AddTooltip(row.edit, fillTextTooltip)
    row.edit:SetPoint("LEFT", 70, 0)
    lineRows[index] = row
    return row
end

local function groupRow(index)
    local row = groupRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, content)
    row:SetSize(WIDTH - 2 * PAD, 50)
    row.chips = {}
    for group = 1, 8 do
        local chip = W.Chip(row, tostring(group), function(self)
            local set = reminder.groups[row.entry].groups
            set[group] = not set[group] or nil
            self:SetChecked(set[group])
            changed()
        end)
        chip:SetPoint("TOPLEFT", (group - 1) * 44, 0)
        row.chips[group] = chip
    end
    row.remove = W.Button(row, "x", 22, 20, function()
        table.remove(reminder.groups, row.entry)
        changed(true)
    end)
    row.remove:SetPoint("TOPRIGHT")
    row.edit = W.EditBox(row, WIDTH - 2 * PAD - 6, function(text)
        reminder.groups[row.entry].text = text
        changed()
    end)
    W.AddTooltip(row.edit, fillTextTooltip)
    row.edit:SetPoint("TOPLEFT", 6, -26)
    groupRows[index] = row
    return row
end

local w = {}

-- titled box with two columns of checkboxes, like the M33kAuras multiselect load options
local function createLoadBox(setName, title, values, labels)
    local entry = { title = sectionTitle(title), box = register(W.Group(content)), checks = {} }
    for _, value in ipairs(values) do
        local check = W.Chip(entry.box, labels[value], function(self)
            local set = reminder.load[setName]
            set[value] = not set[value] or nil
            self:SetChecked(set[value])
            changed()
        end)
        check.value = value
        entry.checks[#entry.checks + 1] = check
    end
    loadBoxes[#loadBoxes + 1] = { setName = setName, entry = entry }
end

local function createClassAndSpecSections()
    w.classHeader = register(W.SectionToggle(content, L["Class"], function()
        openSections.class = not openSections.class
        changed(true)
    end))
    w.classBox = register(W.Group(content))
    w.specHeader = register(W.SectionToggle(content, L["Specialization"], function()
        openSections.spec = not openSections.spec
        changed(true)
    end))
    w.specBox = register(W.Group(content))
    w.specHint = label(L["Select a class to choose its specializations."], Style.MUTED, 11)

    for _, class in ipairs(ns.LoadConditions.GetClasses()) do
        local check = W.IconCheckBox(w.classBox, class.name, CLASS_ICONS, CLASS_ICON_TCOORDS[class.classFile], function()
            local set = reminder.load.class
            set[class.classFile] = not set[class.classFile] or nil
            if not set[class.classFile] then
                for _, spec in ipairs(class.specs) do reminder.load.spec[spec.id] = nil end
            end
            changed(true)
        end)
        check.Text:SetTextColor(classColor(class.classFile))
        check.class = class
        classChecks[#classChecks + 1] = check
        for _, spec in ipairs(class.specs) do
            local specCheck = W.IconCheckBox(w.specBox, spec.name, spec.icon, nil, function()
                local set = reminder.load.spec
                set[spec.id] = not set[spec.id] or nil
                changed(true) -- updates the "(n selected)" header
            end)
            specCheck.Text:SetTextColor(classColor(class.classFile))
            specCheck.classFile = class.classFile
            specCheck.specID = spec.id
            specChecks[#specChecks + 1] = specCheck
        end
    end
end

local function createWidgets()
    -- header: buttons on the right, name and state on the left, preview under the buttons
    w.test = register(W.Button(content, L["Test"], nil, 22, function() ns.addon:TestReminder(bossKey, reminder) end))
    w.test:FitWidth()
    w.send = register(W.Button(content, L["Send"], nil, 22, function() ns.Comms.SendReminders(bossKey, { reminder }) end))
    w.send:FitWidth()
    w.duplicate = register(W.Button(content, L["Duplicate"], nil, 22, function() ns.RemindersTab.DuplicateReminder(reminder) end))
    w.duplicate:FitWidth()
    w.export = register(W.Button(content, L["Export"], nil, 22, function()
        ns.Options:ShowExport(ns.ImportExport.ExportReminder(bossKey, reminder))
    end))
    w.export:FitWidth()
    w.delete = register(W.Button(content, L["Delete"], nil, 22, function() ns.RemindersTab.DeleteReminder(reminder) end))
    w.delete:FitWidth()

    w.nameLabel = label(L["Name"], Style.MUTED)
    w.name = register(W.EditBox(content, 260, function(text) reminder.name = text; changed() end))
    w.enabled = register(W.CheckBox(content, L["Enabled"], function(checked) reminder.enabled = checked; changed() end))
    w.typeLabel = label("", Style.MUTED, 11)

    w.previewTitle = sectionTitle(L["Preview"])
    w.previewHelp = label(L["Your result with the current notes and group (load conditions are ignored)."], Style.MUTED, 11)
    w.previewHelp:SetWidth(WIDTH - 2 * PAD)
    w.preview = register(W.Panel(content))
    w.preview:SetWidth(WIDTH - 2 * PAD)
    w.previewText = W.Label(w.preview, "")
    w.previewText:SetPoint("TOPLEFT", 8, -8)
    w.previewText:SetPoint("RIGHT", -8, 0)
    w.previewText:SetJustifyV("TOP")

    w.matchTitle = sectionTitle(L["Matching"])
    w.keywordLabel = label(L["Keyword (a line starts with it, optionally followed by a number: soak, soak1, soak2...)"], Style.MUTED)
    w.keywordLabel:SetWidth(WIDTH - 2 * PAD)
    w.keyword = register(W.EditBox(content, 200, function(text)
        reminder.keyword = text:gsub("%s", "")
        refreshLineLabels()
        changed()
    end))
    w.startLabel = label(L["Start keyword"], Style.MUTED)
    w.start = register(W.EditBox(content, 200, function(text) reminder.startKeyword = text:gsub("%s", ""); changed() end))
    w.endLabel = label(L["End keyword"], Style.MUTED)
    w.stop = register(W.EditBox(content, 200, function(text) reminder.endKeyword = text:gsub("%s", ""); changed() end))

    w.textTitle = sectionTitle(L["Texts"])
    w.perLine = register(W.CheckBox(content, L["One text per line"], function(checked) reminder.perLine = checked; changed(true) end))
    w.textLabel = label("", Style.MUTED)
    w.text = register(W.EditBox(content, WIDTH - 2 * PAD, function(text) reminder.text = text; changed() end))
    W.AddTooltip(w.text, fillTextTooltip)
    w.addLine = register(W.Button(content, L["Add line"], nil, 22, function()
        reminder.texts[ns.Reminders.MaxLine(reminder) + 1] = ""
        changed(true)
    end))
    w.addLine:FitWidth()
    w.removeLine = register(W.Button(content, L["Remove last line"], nil, 22, function()
        reminder.texts[ns.Reminders.MaxLine(reminder)] = nil
        changed(true)
    end))
    w.removeLine:FitWidth()

    w.groupsTitle = sectionTitle(L["Raid groups"])
    w.groupsHelp = label(L["Select the groups for each text. Groups without a text show nothing."], Style.MUTED)
    w.groupsHelp:SetWidth(WIDTH - 2 * PAD)
    w.addGroup = register(W.Button(content, L["Add mapping"], nil, 22, function()
        table.insert(reminder.groups, { groups = {}, text = "" })
        changed(true)
    end))
    w.addGroup:FitWidth()

    w.warning = label("", Style.WARN)
    w.warning:SetWidth(WIDTH - 2 * PAD)

    w.loadTitle = sectionTitle(L["Load conditions"])
    w.loadHelp = label(L["Nothing selected means any."], Style.MUTED)
    createLoadBox("difficulty", L["Instance Difficulty"], ns.LoadConditions.DIFFICULTIES,
        { lfr = L["LFR"], normal = L["Normal"], heroic = L["Heroic"], mythic = L["Mythic"] })
    createLoadBox("role", L["Spec Role"], ns.LoadConditions.ROLES, {
        TANK = (INLINE_TANK_ICON or "") .. " " .. L["Tank"],
        HEALER = (INLINE_HEALER_ICON or "") .. " " .. L["Healer"],
        DAMAGER = (INLINE_DAMAGER_ICON or "") .. " " .. L["Damage"],
    })
    createLoadBox("range", L["Spec Position"], ns.LoadConditions.RANGES, { melee = L["Melee"], ranged = L["Ranged"] })
    createClassAndSpecSections()
end

local INNER = WIDTH - 2 * PAD

-- returns the box height
local function layoutGrid(box, checks)
    local column = (INNER - 16) / 2
    for index, check in ipairs(checks) do
        local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
        check:ClearAllPoints()
        check:SetPoint("TOPLEFT", box, "TOPLEFT", 8 + col * column, -(6 + row * CHECK_ROW))
        check:Show()
    end
    return math.ceil(#checks / 2) * CHECK_ROW + 10
end

-- one per line, returns the box height
local function layoutList(box, checks)
    local row = 0
    for _, check in ipairs(checks) do
        if check:IsShown() then
            check:ClearAllPoints()
            check:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -(6 + row * CHECK_ROW))
            row = row + 1
        end
    end
    return row * CHECK_ROW + 10
end

local function countSelected(set)
    local count = 0
    for _ in pairs(set) do count = count + 1 end
    return count
end

local function sectionLabel(text, set)
    local count = countSelected(set)
    return count > 0 and format(L["%s (%d selected)"], text, count) or text
end

local function layoutLoad(y)
    place(w.loadTitle, PAD, y)
    place(w.loadHelp, PAD + 130, y + 2)
    y = y + 26
    for _, item in ipairs(loadBoxes) do
        local entry = item.entry
        place(entry.title, PAD, y)
        y = y + 18
        for _, check in ipairs(entry.checks) do check:SetChecked(reminder.load[item.setName][check.value]) end
        local height = layoutGrid(entry.box, entry.checks)
        place(entry.box, PAD, y)
        entry.box:SetSize(INNER, height)
        y = y + height + 10
    end

    -- class
    w.classHeader:SetLabel(sectionLabel(L["Class"], reminder.load.class))
    w.classHeader:SetOpen(openSections.class)
    place(w.classHeader, PAD, y)
    y = y + 24
    if openSections.class then
        for _, check in ipairs(classChecks) do
            check:SetChecked(reminder.load.class[check.class.classFile])
            check:Show()
        end
        local height = layoutList(w.classBox, classChecks)
        place(w.classBox, PAD, y)
        w.classBox:SetSize(INNER, height)
        y = y + height + 8
    end

    -- spec list only shows specs of the selected classes
    w.specHeader:SetLabel(sectionLabel(L["Specialization"], reminder.load.spec))
    w.specHeader:SetOpen(openSections.spec)
    place(w.specHeader, PAD, y)
    y = y + 24
    if openSections.spec then
        if next(reminder.load.class) == nil then
            place(w.specHint, PAD + 8, y)
            y = y + 22
        else
            for _, check in ipairs(specChecks) do
                check:SetShown(reminder.load.class[check.classFile] == true)
                check:SetChecked(reminder.load.spec[check.specID])
            end
            local height = layoutList(w.specBox, specChecks)
            place(w.specBox, PAD, y)
            w.specBox:SetSize(INNER, height)
            y = y + height + 8
        end
    end
    return y
end

local function layoutTexts(y)
    local isLine = reminder.type == "keywordLine"
    place(w.textTitle, PAD, y)
    y = y + 24
    place(w.perLine, PAD, y)
    w.perLine:SetChecked(reminder.perLine)
    y = y + 24
    if isLine or not reminder.perLine then
        w.textLabel:SetText(reminder.perLine and L["Text for lines without a number"] or L["Text for all lines"])
        place(w.textLabel, PAD, y)
        y = y + LABEL_GAP
        place(w.text, PAD + 6, y)
        w.text:SetText(reminder.text or "")
        y = y + 30
    end
    local count = 0
    if reminder.perLine then
        count = math.max(ns.Reminders.MaxLine(reminder), 1)
        for line = 1, count do
            local row = lineRow(line)
            row.line = line
            row.label:SetText(lineLabel(line))
            row.edit:SetText(reminder.texts[line] or "")
            place(row, PAD, y)
            y = y + 28
        end
        place(w.addLine, PAD, y)
        place(w.removeLine, PAD + w.addLine:GetWidth() + 6, y)
        y = y + 30
    end
    for index = count + 1, #lineRows do lineRows[index]:Hide() end
    return y
end

local function layoutGroups(y)
    place(w.groupsTitle, PAD, y)
    y = y + 22
    place(w.groupsHelp, PAD, y)
    y = y + w.groupsHelp:GetStringHeight() + 8
    for index, entry in ipairs(reminder.groups) do
        local row = groupRow(index)
        row.entry = index
        for group = 1, 8 do row.chips[group]:SetChecked(entry.groups[group]) end
        row.edit:SetText(entry.text or "")
        place(row, PAD, y)
        y = y + 58
    end
    for index = #reminder.groups + 1, #groupRows do groupRows[index]:Hide() end
    if #reminder.groups < ns.Reminders.MAX_GROUP_ENTRIES then
        place(w.addGroup, PAD, y)
        y = y + 30
    end
    return y
end

-- name + enabled, then type and buttons, preview underneath. returns the preview's y
local function layoutHeader()
    local y = PAD
    place(w.nameLabel, PAD, y)
    y = y + LABEL_GAP
    place(w.name, PAD + 6, y)
    w.name:SetText(reminder.name or "")
    place(w.enabled, PAD + 280, y - 2)
    w.enabled:SetChecked(reminder.enabled)
    y = y + 30

    w.typeLabel:SetText(ns.RemindersTab.TYPE_LABELS[reminder.type])
    place(w.typeLabel, PAD, y + 5)
    local right = WIDTH - PAD
    for _, button in ipairs({ w.delete, w.export, w.duplicate, w.send, w.test }) do
        right = right - button:GetWidth()
        place(button, right, y)
        right = right - 6
    end
    y = y + 36

    place(w.previewTitle, PAD, y)
    y = y + 22
    place(w.previewHelp, PAD, y)
    y = y + w.previewHelp:GetStringHeight() + 6
    place(w.preview, PAD, y)
    return y
end

function Editor:Layout()
    for _, widget in ipairs(static) do widget:Hide() end
    for _, row in ipairs(lineRows) do row:Hide() end
    for _, row in ipairs(groupRows) do row:Hide() end
    hint:SetShown(reminder == nil)
    if not reminder then
        scroll:SetContentHeight(1)
        return
    end

    origin = content
    previewTop = layoutHeader()

    -- everything else goes in body, which hangs off the preview
    origin = body
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", w.preview, "BOTTOMLEFT", -PAD, -14)
    body:SetWidth(WIDTH)
    local y = 0

    if reminder.type == "group" then
        y = layoutGroups(y)
    else
        place(w.matchTitle, PAD, y)
        y = y + 24
        if reminder.type == "keywordLine" then
            place(w.keywordLabel, PAD, y)
            y = y + w.keywordLabel:GetStringHeight() + 4
            place(w.keyword, PAD + 6, y)
            w.keyword:SetText(reminder.keyword or "")
            y = y + 32
        else
            place(w.startLabel, PAD, y)
            place(w.endLabel, PAD + 220, y)
            y = y + LABEL_GAP
            place(w.start, PAD + 6, y)
            w.start:SetText(reminder.startKeyword or "")
            place(w.stop, PAD + 226, y)
            w.stop:SetText(reminder.endKeyword or "")
            y = y + 32
        end
        y = layoutTexts(y)
    end

    place(w.warning, PAD, y)
    y = y + 34

    bodyHeight = layoutLoad(y + 6)
    body:SetHeight(math.max(1, bodyHeight))
    self:RefreshPreview()
end

local function updateWarnings()
    local unsupported = false
    if not ns.Parser.SupportsLineVars(reminder.type) then
        for _, text in ipairs(ns.Reminders.AllTexts(reminder)) do
            local found = ns.Wildcards.Scan(text)
            if found.line or found.pos then unsupported = true end
        end
    end
    w.warning:SetText(unsupported
        and L["{line} and {pos} only work in keyword reminders; here they are shown as written."]
        or "")
end

-- body is anchored under the preview, so a taller preview just pushes it down. no relayout
-- while typing, which would rebuild the form and lose the edit box focus
function Editor:RefreshPreview()
    if not reminder or not w.preview then return end
    updateWarnings()
    local lines = {}
    local boss = ns.Database.GetBoss(bossKey)
    local ctx = boss and ns.addon:BuildContext(boss)
    if ctx then
        local items = ns.Parser.EvaluateReminder(reminder, ctx)
        for _, item in ipairs(items) do
            if item.missingLine then
                local warn = Style.WARN
                lines[#lines + 1] = format("|cff%02x%02x%02x%s|r", warn[1] * 255, warn[2] * 255, warn[3] * 255,
                    format(L["No text for line %d (%s)"], item.missingLine, item.reminderName))
            else
                lines[#lines + 1] = ns.Display.FormatText(ns.Wildcards.Expand(item.template, item.vars, ns.Wildcards.Lookup))
            end
        end
    end
    if #lines == 0 then
        w.previewText:SetTextColor(unpack(Style.MUTED))
        w.previewText:SetText(L["Nothing to show for you with the current note."])
    else
        w.previewText:SetTextColor(unpack(Style.TEXT))
        w.previewText:SetText(table.concat(lines, "\n"))
    end
    -- body follows the anchor, only the sizes need updating
    local height = w.previewText:GetStringHeight() + 16
    w.preview:SetHeight(height)
    scroll:SetContentHeight(previewTop + height + 14 + bodyHeight + PAD)
end

function Editor:Create(parent)
    scroll = W.ScrollArea(parent)
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -24, 4)
    content = scroll.content
    body = CreateFrame("Frame", nil, content)
    body:SetSize(WIDTH, 1)
    hint = W.Label(parent, L["Select or create a reminder."], nil, Style.MUTED)
    hint:SetPoint("TOPLEFT", PAD, -PAD)
    createWidgets()
    self:Layout()
end

-- class/spec sections start collapsed for each new reminder, otherwise they'd carry over
function Editor:SetReminder(newBossKey, newReminder)
    if newReminder ~= reminder then wipe(openSections) end
    bossKey, reminder = newBossKey, newReminder
    if content then
        scroll:SetVerticalScroll(0)
        self:Layout()
    end
end

-- called when the settings window opens
function Editor:ResetSections()
    wipe(openSections)
end

function Editor:Refresh()
    if content then self:Layout() end
end
