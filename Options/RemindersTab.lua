-- Reminders tab: boss tree, reminder list (drag to reorder), editor
local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local W, Style = ns.Widgets, ns.Style
local DB = ns.Database

local Tab = {}
ns.RemindersTab = Tab

local TREE_WIDTH, LIST_WIDTH, ROW = 230, 250, 22

Tab.TYPE_LABELS = {keywordLine = L["Keyword line"], keywordGroup = L["Keyword group"], group = L["Group-based"]}

local tree, list, emptyHint
local treeRows, listRows = {}, {}
local selectedReminderId

local function selectedBossKey() return ns.Options.selectedBossKey end

-- expanded tree sections are saved between sessions, everything starts collapsed
local function expanded() return ns.addon.db.global.ui.expanded end

local function treeNodes()
    local nodes = {}
    local function add(depth, key, text, boss)
        nodes[#nodes + 1] = {depth = depth, key = key, text = text, boss = boss}
        return expanded()[key] == true
    end
    for _, expansion in ipairs(ns.Raids) do
        if add(0, expansion.key, DB.GetExpansionName(expansion)) then
            for _, season in ipairs(expansion.seasons) do
                if add(1, season.key, DB.GetSeasonName(season)) then
                    for _, raid in ipairs(season.raids) do
                        if add(2, raid.key, DB.GetRaidName(raid)) then
                            for _, boss in ipairs(raid.bosses) do
                                add(3, boss.key, DB.GetBossName(boss), boss)
                            end
                        end
                    end
                end
            end
        end
    end
    return nodes
end

local function treeRow(index)
    local row = treeRows[index]
    if row then return row end
    row = CreateFrame("Button", nil, tree.content)
    row:SetHeight(ROW)
    W.StyleRow(row)
    row.toggle = row:CreateTexture(nil, "ARTWORK")
    row.toggle:SetSize(14, 14)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.text = W.Label(row, "")
    row.text:SetPoint("RIGHT", -4, 0)
    row.text:SetWordWrap(false)
    row.count = W.Label(row, "", 11, Style.MUTED)
    row.count:SetPoint("RIGHT", -6, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.text:GetText())
        GameTooltip:AddLine(L["Right-click to send or export"], 1, 1, 1)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    treeRows[index] = row
    return row
end

-- right-click menu on a tree row: a boss sends/exports its list, a section every boss under it
local function openTreeMenu(row, node)
    local items
    if node.boss then
        items = {
            {
                text = L["Send to group"],
                run = function()
                    ns.Options:ShowPlayerPicker(function(targets) ns.Comms.SendBoss(node.key, targets) end)
                end,
            }, {text = L["Export"], run = function() ns.Options:ShowReminderExport(node.key) end},
        }
    else
        items = {
            {
                text = L["Send to group"],
                run = function()
                    ns.Options:ShowPlayerPicker(function(targets) ns.Comms.SendSection(node.key, targets) end)
                end,
            }, {
                text = L["Export"],
                run = function()
                    local text = ns.ImportExport.ExportSection(node.key)
                    if text then
                        ns.Options:ShowExport(text)
                    else
                        ns.Options:ShowMessage(L["There are no reminders in this section."])
                    end
                end,
            },
        }
    end
    W.OpenMenu(row, items, nil, function(item) item.run() end)
end

function Tab.RefreshTree()
    local nodes = treeNodes()
    for index, node in ipairs(nodes) do
        local row = treeRow(index)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW)
        row:SetPoint("RIGHT", tree.content, "RIGHT")
        local indent = 6 + node.depth * 14
        row.text:ClearAllPoints()
        row.text:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
        row.icon:SetShown(node.boss ~= nil)
        row.toggle:SetShown(node.boss == nil)
        if node.boss then
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", indent, 0)
            row.icon:SetTexture(DB.GetBossIcon(node.boss))
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            local count = #(ns.addon.db.profile.reminders[node.key] or {})
            local selected = node.key == selectedBossKey()
            row.text:SetText(node.text)
            row.text:SetTextColor(unpack(selected and Style.ACCENT or Style.TEXT))
            row.count:SetText(count > 0 and tostring(count) or "")
            row:SetRowSelected(selected)
        else
            local open = expanded()[node.key] == true
            row.toggle:ClearAllPoints()
            row.toggle:SetPoint("LEFT", indent, 0)
            row.toggle:SetTexture(open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
            row.text:SetPoint("LEFT", row.toggle, "RIGHT", 4, 0)
            row.text:SetText(node.text)
            row.text:SetTextColor(unpack(Style.ACCENT))
            row.count:SetText("")
            row:SetRowSelected(false)
        end
        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                openTreeMenu(self, node)
            elseif node.boss then
                Tab.SelectBoss(node.key)
            else
                expanded()[node.key] = not expanded()[node.key] or nil
                Tab.RefreshTree()
            end
        end)
        row:Show()
    end
    for index = #nodes + 1, #treeRows do treeRows[index]:Hide() end
    tree:SetContentHeight(#nodes * ROW)
end

local dragFrom, dragMarker

-- slot under the cursor, 1..#list + 1 (one past the end means drop at the bottom)
local function insertionIndex(count)
    local _, cursorY = GetCursorPosition()
    for index = 1, count do
        local row = listRows[index]
        local scale = row:GetEffectiveScale()
        local top, bottom = row:GetTop(), row:GetBottom()
        if top and cursorY / scale > (top + bottom) / 2 then return index end
    end
    return count + 1
end

local function updateDragMarker()
    local reminders = ns.Reminders.GetList(selectedBossKey())
    local index = insertionIndex(#reminders)
    dragMarker:ClearAllPoints()
    local row = listRows[math.min(index, #reminders)]
    if index <= #reminders then
        dragMarker:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 0)
        dragMarker:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", 0, 0)
    else
        dragMarker:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, 0)
        dragMarker:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, 0)
    end
    dragMarker:Show()
end

local function listRow(index)
    local row = listRows[index]
    if row then return row end
    row = CreateFrame("Button", nil, list.content)
    row:SetHeight(ROW + 4)
    W.StyleRow(row)
    row.check = W.CheckBox(row, "")
    row.check:SetPoint("LEFT", 2, 0)
    row.type = W.Label(row, "", 10, Style.MUTED)
    row.type:SetPoint("RIGHT", -6, 0)
    row.text = W.Label(row, "")
    row.text:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
    row.text:SetPoint("RIGHT", row.type, "LEFT", -6, 0)
    row.text:SetWordWrap(false)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self)
        dragFrom = self.index
        list:SetScript("OnUpdate", updateDragMarker)
    end)
    row:SetScript("OnDragStop", function()
        list:SetScript("OnUpdate", nil)
        dragMarker:Hide()
        if not dragFrom then return end
        local reminders = ns.Reminders.GetList(selectedBossKey())
        local target = insertionIndex(#reminders)
        -- the slot index still counts the dragged row, so moving down lands one too far
        if target > dragFrom then target = target - 1 end
        ns.Reminders.Move(selectedBossKey(), dragFrom, target)
        dragFrom = nil
        Tab.RefreshList()
    end)
    listRows[index] = row
    return row
end

function Tab.RefreshList()
    local bossKey = selectedBossKey()
    local reminders = bossKey and ns.Reminders.GetList(bossKey) or {}
    emptyHint:SetShown(not bossKey or #reminders == 0)
    emptyHint:SetText(bossKey and L["No reminders yet. Click \"New\" to create one."] or L["Select a boss on the left."])
    for index, reminder in ipairs(reminders) do
        local row = listRow(index)
        row.index = index
        row:SetPoint("TOPLEFT", 0, -(index - 1) * (ROW + 6))
        row:SetPoint("RIGHT", list.content, "RIGHT")
        row.text:SetText(reminder.name ~= "" and reminder.name or L["(unnamed)"])
        row.text:SetTextColor(unpack(reminder.enabled and Style.TEXT or Style.MUTED))
        row.type:SetText(Tab.TYPE_LABELS[reminder.type])
        row.check:SetChecked(reminder.enabled)
        row.check:SetScript("OnClick", function(box)
            reminder.enabled = not reminder.enabled
            box:SetChecked(reminder.enabled)
            Tab.RefreshList()
            ns.Editor:Refresh()
        end)
        row:SetRowSelected(reminder.id == selectedReminderId)
        row:SetScript("OnClick", function() Tab.SelectReminder(reminder.id) end)
        row:Show()
    end
    for index = #reminders + 1, #listRows do listRows[index]:Hide() end
    list:SetContentHeight(#reminders * (ROW + 6))
end

local function findReminder(id)
    local bossKey = selectedBossKey()
    if not bossKey or not id then return nil end
    local index = ns.Reminders.FindIndex(bossKey, id)
    return index and ns.Reminders.GetList(bossKey)[index]
end

function Tab.SelectReminder(id)
    selectedReminderId = id
    Tab.RefreshList()
    ns.Editor:SetReminder(selectedBossKey(), findReminder(id))
end

function Tab.SelectBoss(bossKey)
    ns.Options.selectedBossKey = bossKey
    -- make sure the boss is visible in the tree
    local boss = bossKey and DB.GetBoss(bossKey)
    if boss then
        local expansion, season, raid = DB.GetPath(boss)
        expanded()[expansion.key], expanded()[season.key], expanded()[raid.key] = true, true, true
    end
    local first = bossKey and ns.Reminders.GetList(bossKey)[1]
    Tab.RefreshTree()
    Tab.SelectReminder(first and first.id)
end

function Tab.CreateReminder(reminderType)
    local bossKey = selectedBossKey()
    if not bossKey then return end
    local reminder = ns.Reminders.New(reminderType, Tab.TYPE_LABELS[reminderType])
    table.insert(ns.Reminders.GetList(bossKey), reminder)
    Tab.RefreshTree()
    Tab.SelectReminder(reminder.id)
end

function Tab.DuplicateReminder(reminder)
    local bossKey = selectedBossKey()
    local index = ns.Reminders.FindIndex(bossKey, reminder.id)
    local reminders = ns.Reminders.GetList(bossKey)
    local name = ns.Reminders.NextNumberedName(reminder.name, reminders) or format(L["%s (copy)"], reminder.name)
    local copy = ns.Reminders.Duplicate(reminder, name)
    table.insert(reminders, index + 1, copy)
    Tab.RefreshTree()
    Tab.SelectReminder(copy.id)
end

function Tab.DeleteReminder(reminder)
    local name = reminder.name ~= "" and reminder.name or L["(unnamed)"]
    ns.Options:Confirm(format(L["Delete the reminder \"%s\"?"], name), {
        {
            label = L["Delete"],
            onClick = function()
                local bossKey = selectedBossKey()
                local index = ns.Reminders.FindIndex(bossKey, reminder.id)
                if index then table.remove(ns.Reminders.GetList(bossKey), index) end
                local remaining = ns.Reminders.GetList(bossKey)
                local nextReminder = remaining[math.min(index or 1, #remaining)]
                Tab.RefreshTree()
                Tab.SelectReminder(nextReminder and nextReminder.id)
            end,
        }, {label = L["Cancel"]},
    })
end

-- editor calls this when the name or enabled state changes
function Tab.OnReminderChanged() Tab.RefreshList() end

local function create(parent)
    local treePanel = W.Panel(parent)
    treePanel:SetPoint("TOPLEFT")
    treePanel:SetPoint("BOTTOMLEFT")
    treePanel:SetWidth(TREE_WIDTH)
    tree = W.ScrollArea(treePanel)
    tree:SetPoint("TOPLEFT", 4, -4)
    tree:SetPoint("BOTTOMRIGHT", -24, 4)

    local listPanel = CreateFrame("Frame", nil, parent)
    listPanel:SetPoint("TOPLEFT", TREE_WIDTH + 10, 0)
    listPanel:SetPoint("BOTTOMLEFT", TREE_WIDTH + 10, 0)
    listPanel:SetWidth(LIST_WIDTH)

    local new = W.Button(listPanel, L["New"], 70, 24)
    new:SetPoint("TOPLEFT")
    new:SetScript("OnClick", function(self)
        if not selectedBossKey() then return end
        local items = {}
        for _, reminderType in ipairs(ns.Reminders.TYPES) do
            items[#items + 1] = {value = reminderType, text = Tab.TYPE_LABELS[reminderType]}
        end
        W.OpenMenu(self, items, nil, function(item) Tab.CreateReminder(item.value) end, 160)
    end)
    local import = W.Button(listPanel, L["Import"], 80, 24, function()
        ns.Options:ShowImport(function(data) Tab.SelectBoss(ns.ImportExport.FirstBoss(data).key) end)
    end)
    import:SetPoint("LEFT", new, "RIGHT", 6, 0)
    local export = W.Button(listPanel, L["Export"], 88, 24, function()
        local bossKey = selectedBossKey()
        if bossKey then ns.Options:ShowReminderExport(bossKey) end
    end)
    export:SetPoint("LEFT", import, "RIGHT", 6, 0)

    list = W.ScrollArea(listPanel)
    list:SetPoint("TOPLEFT", 0, -32)
    list:SetPoint("BOTTOMRIGHT", -20, 74)
    emptyHint = W.Label(listPanel, "", nil, Style.MUTED)
    emptyHint:SetPoint("TOPLEFT", 4, -40)
    emptyHint:SetPoint("RIGHT", -4, 0)
    dragMarker = list.content:CreateTexture(nil, "OVERLAY")
    dragMarker:SetColorTexture(unpack(Style.ACCENT))
    dragMarker:SetHeight(2)
    dragMarker:Hide()

    local hint = W.Label(listPanel, L["Drag to reorder. This is the display order."], 10)
    hint:SetPoint("BOTTOMLEFT", 0, 56)
    -- real notes like the next ready check, or a fake note with you on every line
    local test = W.Button(listPanel, L["Test with current note"], LIST_WIDTH, 24,
                          function() ns.addon:TestBoss(DB.GetBoss(selectedBossKey() or "")) end)
    W.AddTooltip(test, function(tip)
        tip:SetText(L["Test with current note"])
        tip:AddLine(L["Shows this boss's reminders the way the next ready check would, with the note as it is now. Zone and difficulty are ignored."], 1, 1, 1, true)
    end)
    local testNote = W.Button(listPanel, L["Test with test note"], LIST_WIDTH, 24, function()
        local bossKey = selectedBossKey()
        if bossKey then ns.addon:TestAll(bossKey) else ns.addon:Print(L["Select a boss first."]) end
    end)
    W.AddTooltip(testNote, function(tip)
        tip:SetText(L["Test with test note"])
        tip:AddLine(L["Shows every loaded reminder with a test note that puts you on each of its lines. Zone and difficulty are ignored."], 1, 1, 1, true)
    end)
    testNote:SetPoint("BOTTOMLEFT")
    test:SetPoint("BOTTOMLEFT", 0, 26)

    local editorPanel = W.Panel(parent)
    editorPanel:SetPoint("TOPLEFT", TREE_WIDTH + LIST_WIDTH + 20, 0)
    editorPanel:SetPoint("BOTTOMRIGHT")
    ns.Editor:Create(editorPanel)
end

local function refresh()
    Tab.RefreshTree()
    -- keep the selection if it still exists (profile switches can remove it)
    if not findReminder(selectedReminderId) then
        local first = selectedBossKey() and ns.Reminders.GetList(selectedBossKey())[1]
        selectedReminderId = first and first.id
    end
    Tab.SelectReminder(selectedReminderId)
end

table.insert(ns.OptionsTabs, {key = "reminders", label = L["Reminders"], Create = create, Refresh = refresh})
