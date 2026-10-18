-- settings window and the shared dialogs. tab files add themselves to ns.OptionsTabs
local ADDON_NAME, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local W, Style = ns.Widgets, ns.Style

local Options = {}
ns.Options = Options
ns.OptionsTabs = ns.OptionsTabs or {}

local WIDTH, HEIGHT = 1040, 700
local frame, activeTab
local tabFrames = {}

-- boss picked in the Reminders tab. lives here so an import can jump to the imported boss
Options.selectedBossKey = nil

local function selectTab(key)
    activeTab = key
    for index, tab in ipairs(ns.OptionsTabs) do
        local selected = tab.key == key
        if selected then PanelTemplates_SetTab(frame, index) end
        if selected and not tabFrames[tab.key] then
            local content = CreateFrame("Frame", nil, frame.Inset)
            content:SetPoint("TOPLEFT", 12, -12)
            content:SetPoint("BOTTOMRIGHT", -12, 12)
            tab.Create(content)
            tabFrames[tab.key] = content
        end
        if tabFrames[tab.key] then
            tabFrames[tab.key]:SetShown(selected)
            if selected and tab.Refresh then tab.Refresh() end
        end
    end
end

function Options.GetVersionText()
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    -- unpackaged dev copies still say @project-version@, show nothing for those
    if not version or not version:match("^v?%d") then return "" end
    return format("v%s", (version:gsub("^v", "")))
end

local function create()
    frame = CreateFrame("Frame", ADDON_NAME .. "Options", UIParent, "ButtonFrameTemplate")
    ButtonFrameTemplate_HidePortrait(frame)
    frame:SetTitle(L["Ready Check Reminder"])
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    -- not clamped, so it can be pushed half off screen. /rcr reset brings it back
    frame:SetClampedToScreen(false)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, ADDON_NAME .. "Options") -- Escape closes it

    -- room for the tabs above the inset and the version footer below
    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint("TOPLEFT", 4, -60)
    frame.Inset:SetPoint("BOTTOMRIGHT", -6, 26)

    -- lighter see-through background like M33kAuras (PANEL_BACKGROUND_COLOR at 80%)
    local r, g, b = CreateColorFromHexString("ff1f1e21"):GetRGB()
    frame.Bg:SetColorTexture(r, g, b, 0.8)
    frame.Inset.Bg:Hide()

    frame.Tabs = {}
    for index, tab in ipairs(ns.OptionsTabs) do
        local button = CreateFrame("Button", nil, frame, "PanelTopTabButtonTemplate")
        button:SetID(index)
        button:SetText(tab.label)
        PanelTemplates_TabResize(button, 0)
        if index == 1 then
            button:SetPoint("BOTTOMLEFT", frame.Inset, "TOPLEFT", 8, -2)
        else
            button:SetPoint("LEFT", frame.Tabs[index - 1], "RIGHT", 4, 0)
        end
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            selectTab(tab.key)
        end)
        frame.Tabs[index] = button
    end
    PanelTemplates_SetNumTabs(frame, #frame.Tabs)

    local version = W.Label(frame, Options.GetVersionText(), 10)
    version:SetPoint("BOTTOMRIGHT", -12, 8)
    version:SetJustifyH("RIGHT")
    frame.versionText = version

    frame:SetScript("OnHide", W.CloseMenu)
    selectTab(ns.OptionsTabs[1].key)
end

function Options:ResetPosition()
    if not frame then create() end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    if not frame:IsShown() then self:Toggle() end
end

function Options:Toggle()
    if not frame then create() end
    if frame:IsShown() then
        frame:Hide()
    else
        if ns.Editor then ns.Editor:ResetSections() end
        frame:Show()
        selectTab(activeTab)
    end
end

function Options:RefreshActiveTab()
    if not frame or not frame:IsShown() then return end
    for _, tab in ipairs(ns.OptionsTabs) do if tab.key == activeTab and tab.Refresh then tab.Refresh() end end
end

function Options:OnProfileChanged() self:RefreshActiveTab() end

function Options:OnNameResolved() if ns.Editor and frame and frame:IsShown() then ns.Editor:RefreshPreview() end end

-- Display calls this during the drag and on drop, the Display tab hooks onAnchorMoved
function Options:OnAnchorMoved(x, y) if self.onAnchorMoved then self.onAnchorMoved(x, y) end end

-- Dialogs

local dialogs = {} -- one frame per instance key ("main", "share", ...)
local CHECK_ROW = 22

local function createDialog()
    local dialog = CreateFrame("Frame", nil, UIParent)
    dialog.Border = CreateFrame("Frame", nil, dialog, "DialogBorderTranslucentTemplate")
    dialog.Border:SetAllPoints()
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetToplevel(true)
    dialog:EnableMouse(true)
    dialog:SetPoint("CENTER")
    dialog.title = W.Label(dialog, "", 14)
    dialog.title:SetPoint("TOP", 0, -16)
    dialog.title:SetJustifyH("CENTER")
    dialog.message = W.Label(dialog, "")
    dialog.message:SetJustifyV("TOP")
    dialog.input = W.MultiLineEditBox(dialog)
    dialog.fieldLabel = W.Label(dialog, "", nil, Style.MUTED)
    dialog.field = W.EditBox(dialog, 300)

    -- checklist with All / None buttons
    dialog.list = W.Panel(dialog)
    dialog.list.scroll = W.ScrollArea(dialog.list)
    dialog.list.scroll:SetPoint("TOPLEFT", 8, -6)
    dialog.list.scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    dialog.list.boxes = {}
    dialog.all = W.Button(dialog, L["All"], nil, 20, function()
        for _, box in ipairs(dialog.list.boxes) do if box:IsShown() then box:SetChecked(true) end end
    end)
    dialog.all:FitWidth()
    dialog.none = W.Button(dialog, L["None"], nil, 20,
                           function() for _, box in ipairs(dialog.list.boxes) do box:SetChecked(false) end end)
    dialog.none:FitWidth()

    -- read-only list, the send status redraws it
    dialog.results = W.Panel(dialog)
    dialog.results.scroll = W.ScrollArea(dialog.results)
    dialog.results.scroll:SetPoint("TOPLEFT", 8, -8)
    dialog.results.scroll:SetPoint("BOTTOMRIGHT", -26, 8)
    dialog.results.text = W.Label(dialog.results.scroll.content, "")
    dialog.results.text:SetPoint("TOPLEFT")
    dialog.results.text:SetPoint("RIGHT")
    dialog.results.text:SetJustifyV("TOP")
    function dialog.results:SetText(text)
        self.text:SetText(text)
        self.scroll:SetContentHeight(self.text:GetStringHeight() + 8)
    end

    dialog.toggle = W.CheckBox(dialog, "")

    dialog.buttons = {}
    dialog:Hide()
    return dialog
end

local function checklistSelection(dialog, items)
    local selected = {}
    for index, item in ipairs(items) do if dialog.list.boxes[index]:GetChecked() then selected[#selected + 1] = item.key end end
    return selected
end

-- opts: title and buttons, everything else optional
--   message    plain text
--   input      { text, readOnly }, the big multi-line box for import/export strings
--   field      { label, text }, single-line input
--   checklist  { { key, label, checked } }
--   results    text for a scrolling list, dialog.results:SetText() redraws it
--   toggle     { label, checked, onClick(checked) }, one checkbox at the bottom
--   buttons    { { label, onClick(value) } }, value is the input text, field text or checked keys
--   instance   key for a separate window so it doesn't replace the "main" one (comms uses "share")
-- returns the dialog frame
function Options:ShowDialog(opts)
    local key = opts.instance or "main"
    local dialog = dialogs[key]
    if not dialog then
        dialog = createDialog()
        dialogs[key] = dialog
        if key ~= "main" then
            -- sit above the main dialog and a bit higher so both stay visible
            dialog:ClearAllPoints()
            dialog:SetPoint("CENTER", 0, 120)
            dialog:SetFrameLevel(dialog:GetFrameLevel() + 50)
        end
    end
    W.CloseMenu()
    local width = (opts.input or opts.checklist or opts.results) and 580 or 460
    local inner = width - 48
    local y = 44
    dialog.title:SetText(opts.title or "")

    dialog.message:SetShown(opts.message ~= nil)
    if opts.message then
        dialog.message:ClearAllPoints()
        dialog.message:SetPoint("TOPLEFT", 24, -y)
        dialog.message:SetWidth(inner)
        dialog.message:SetText(opts.message)
        y = y + dialog.message:GetStringHeight() + 12
    end

    dialog.fieldLabel:SetShown(opts.field ~= nil)
    dialog.field:SetShown(opts.field ~= nil)
    if opts.field then
        dialog.fieldLabel:SetText(opts.field.label or "")
        dialog.fieldLabel:ClearAllPoints()
        dialog.fieldLabel:SetPoint("TOPLEFT", 24, -y)
        dialog.field:ClearAllPoints()
        dialog.field:SetPoint("TOPLEFT", 30, -(y + 16))
        dialog.field:SetText(opts.field.text or "")
        y = y + 50
    end

    local hasList = opts.checklist ~= nil
    dialog.list:SetShown(hasList)
    dialog.all:SetShown(hasList)
    dialog.none:SetShown(hasList)
    if hasList then
        dialog.all:ClearAllPoints()
        dialog.all:SetPoint("TOPLEFT", 24, -y)
        dialog.none:ClearAllPoints()
        dialog.none:SetPoint("LEFT", dialog.all, "RIGHT", 6, 0)
        y = y + 26
        local listHeight = math.min(300, math.max(60, #opts.checklist * CHECK_ROW + 12))
        dialog.list:ClearAllPoints()
        dialog.list:SetPoint("TOPLEFT", 24, -y)
        dialog.list:SetSize(inner, listHeight)
        local content = dialog.list.scroll.content
        for index, item in ipairs(opts.checklist) do
            local box = dialog.list.boxes[index]
            if not box then
                box = W.CheckBox(content, "")
                dialog.list.boxes[index] = box
            end
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", 0, -((index - 1) * CHECK_ROW + 2))
            box:SetLabel(item.label)
            box:SetChecked(item.checked ~= false)
            box:Show()
        end
        for index = #opts.checklist + 1, #dialog.list.boxes do dialog.list.boxes[index]:Hide() end
        dialog.list.scroll:SetContentHeight(#opts.checklist * CHECK_ROW + 8)
        dialog.list.scroll:SetVerticalScroll(0)
        y = y + listHeight + 12
    end

    dialog.input:SetShown(opts.input ~= nil)
    if opts.input then
        dialog.input:ClearAllPoints()
        dialog.input:SetPoint("TOPLEFT", 24, -y)
        dialog.input:SetSize(inner, 260)
        y = y + 272
        local edit = dialog.input.edit
        edit:SetText(opts.input.text or "")
        if opts.input.readOnly then
            local fixed = opts.input.text or ""
            edit.onUserInput = function(box)
                box:SetText(fixed)
                box:HighlightText()
            end
        else
            edit.onUserInput = nil
        end
        edit:SetFocus()
        edit:HighlightText()
    elseif opts.field then
        dialog.field:SetFocus()
    end

    dialog.results:SetShown(opts.results ~= nil)
    if opts.results then
        dialog.results:ClearAllPoints()
        dialog.results:SetPoint("TOPLEFT", 24, -y)
        dialog.results:SetSize(inner, 260)
        dialog.results:SetText(opts.results)
        dialog.results.scroll:SetVerticalScroll(0)
        y = y + 272
    end

    dialog.toggle:SetShown(opts.toggle ~= nil)
    if opts.toggle then
        dialog.toggle:ClearAllPoints()
        dialog.toggle:SetPoint("TOPLEFT", 20, -y)
        dialog.toggle:SetLabel(opts.toggle.label)
        dialog.toggle:SetChecked(opts.toggle.checked)
        dialog.toggle:SetScript("OnClick", function(box) opts.toggle.onClick(box:GetChecked()) end)
        y = y + 30
    end

    dialog:SetSize(width, math.max(140, y + 56))

    for _, button in ipairs(dialog.buttons) do button:Hide() end
    local right = -24
    for index = #opts.buttons, 1, -1 do
        local spec = opts.buttons[index]
        local button = dialog.buttons[index]
        if not button then
            button = W.Button(dialog, "", nil, 24)
            dialog.buttons[index] = button
        end
        button:SetLabel(spec.label)
        button:FitWidth(30)
        button:ClearAllPoints()
        button:SetPoint("BOTTOMRIGHT", right, 20)
        right = right - button:GetWidth() - 6
        button:SetScript("OnClick", function()
            local value
            if opts.input then
                value = dialog.input.edit:GetText()
            elseif opts.field then
                value = dialog.field:GetText()
            elseif opts.checklist then
                value = checklistSelection(dialog, opts.checklist)
            end
            dialog:Hide()
            if spec.onClick then spec.onClick(value) end
        end)
        button:Show()
    end
    dialog.share = opts.share -- for ShowShareStatus
    dialog:Show()
    dialog:Raise()
    return dialog
end

function Options:Confirm(message, buttons) self:ShowDialog({title = L["Please confirm"], message = message, buttons = buttons}) end

function Options:ShowMessage(message)
    self:ShowDialog({title = L["Ready Check Reminder"], message = message, buttons = {{label = L["Close"]}}})
end

-- with makeString(linked) there's a "Tie to boss" box to switch strings
function Options:ShowExport(text, makeString, linked)
    linked = linked ~= false
    local toggle
    if makeString then
        toggle = {
            label = L["Tie to boss"],
            checked = linked,
            onClick = function(checked) self:ShowExport(makeString(checked), makeString, checked) end,
        }
    end
    self:ShowDialog({
        title = L["Export"],
        message = linked and L["Copy this string (Ctrl+C) and share it."]
          or L["Copy this string (Ctrl+C) and share it. It is not tied to a boss and is imported to whichever boss is selected."],
        input = {text = text, readOnly = true},
        toggle = toggle,
        buttons = {{label = L["Close"]}},
    })
end

-- Send status

local SHARE_STATES = {
    sending = {L["sending..."], "|cff999999"},
    waiting = {L["waiting for confirmation..."], "|cff999999"},
    ok = {L["received"], "|cff33ff33"},
    failed = {L["could not send"], "|cffff3333"},
    none = {L["no confirmation"], "|cff999999"},
    blocked = {L["not imported: blocked by their sharing settings"], "|cffff3333"},
    tooNew = {L["not imported: they need a newer version"], "|cffff3333"},
    tooOld = {L["not imported: your version is too old for them"], "|cffff3333"},
    damaged = {L["not imported: it arrived damaged"], "|cffff3333"},
}

-- header and player lines, anyone without "received" on top, then by name
local function shareStatusText(share)
    local names, confirmed, total = {}, 0, 0
    for name, state in pairs(share.states) do
        names[#names + 1] = name
        total = total + 1
        if state == "ok" then confirmed = confirmed + 1 end
    end
    local keys = {}
    for _, name in ipairs(names) do keys[name] = ns.Comms.DisplayName(name):lower() end
    table.sort(names, function(a, b)
        local aDone, bDone = share.states[a] == "ok", share.states[b] == "ok"
        if aDone ~= bDone then return bDone end
        if keys[a] ~= keys[b] then return keys[a] < keys[b] end
        return a < b
    end)
    local lines = {}
    local unconfirmed = false
    for _, name in ipairs(names) do
        local state = SHARE_STATES[share.states[name]] or {"?", "|cff999999"}
        lines[#lines + 1] = ns.Comms.PlayerName(name) .. ": " .. state[2] .. state[1] .. "|r"
        if share.states[name] == "none" then unconfirmed = true end
    end
    if unconfirmed then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cff999999"
                              .. format(L["Players with no confirmation may not have the addon, or have a version older than %s."],
                                        ns.Comms.ACK_VERSION) .. "|r"
    end
    local header = share.group and format(L["Sending %d reminder(s) to your group."], share.count)
                     or format(L["Sending %d reminder(s) to %d player(s)."], share.count, total)
    header = header .. "\n" .. format(share.done and L["%d of %d confirmed."] or L["Confirmed: %d of %d"], confirmed, total)
    return header, table.concat(lines, "\n")
end

-- redraws whenever someone's state changes
function Options:ShowShareStatus(share)
    local header, lines = shareStatusText(share)
    local dialog = self:ShowDialog({
        title = L["Sending reminders"],
        message = header,
        results = lines,
        share = share,
        buttons = {{label = L["Close"]}},
    })
    ns.Comms.onShareUpdate = function(updated)
        if not dialog:IsShown() or dialog.share ~= updated then return end
        local newHeader, newLines = shareStatusText(updated)
        dialog.message:SetText(newHeader)
        dialog.results:SetText(newLines)
    end
end

-- who gets a share or a check. everyone online starts ticked. onConfirm gets nil targets if
-- nobody was unticked (one group message), otherwise the picked names (whispers).
-- unticked = { [name] = true }, lets a refresh keep the choices
function Options:ShowPlayerPicker(onConfirm, title, confirmLabel, unticked)
    local members = ns.Comms.GetGroupMembers()
    if #members == 0 then
        self:ShowMessage(IsInGroup() and L["There is nobody else online in your group."] or L["You are not in a group."])
        return
    end
    local items = {}
    for _, member in ipairs(members) do
        items[#items + 1] = {
            key = member.name,
            label = ns.Comms.PlayerName(member.name, member.classFile),
            checked = not (unticked and unticked[member.name]),
        }
    end
    -- re-reads the group, keeping whoever was unticked unticked. new players come in ticked
    local function refresh(selected)
        local stillTicked, nowUnticked = {}, {}
        for _, name in ipairs(selected) do stillTicked[name] = true end
        for _, item in ipairs(items) do if not stillTicked[item.key] then nowUnticked[item.key] = true end end
        self:ShowPlayerPicker(onConfirm, title, confirmLabel, nowUnticked)
    end
    self:ShowDialog({
        title = title or L["Send to"],
        message = L["Choose the players. Everyone online in your group is selected."],
        checklist = items,
        buttons = {
            {
                label = confirmLabel or L["Send"],
                onClick = function(selected)
                    if #selected == 0 then return end
                    onConfirm(#selected < #items and selected or nil)
                end,
            }, {label = L["Refresh"], onClick = refresh}, {label = L["Cancel"]},
        },
    })
end

-- picking every reminder makes a boss string instead, so the importer can replace their list
function Options:ShowReminderExport(bossKey)
    local list = ns.Reminders.GetList(bossKey)
    if #list == 0 then
        self:ShowMessage(L["This boss has no reminders to export."])
        return
    end
    local items = {}
    for _, reminder in ipairs(list) do
        items[#items + 1] = {key = reminder, label = reminder.name ~= "" and reminder.name or L["(unnamed)"]}
    end
    self:ShowDialog({
        title = L["Export reminders"],
        message = format(L["Choose the reminders of %s to export."], ns.Database.GetBossName(ns.Database.GetBoss(bossKey))),
        checklist = items,
        buttons = {
            {
                label = L["Export"],
                onClick = function(selected)
                    if #selected == 0 then return end
                    local function makeString(linked)
                        if #selected == #list then return ns.ImportExport.ExportBoss(bossKey, not linked) end
                        return ns.ImportExport.ExportReminders(bossKey, selected, not linked)
                    end
                    self:ShowExport(makeString(true), makeString)
                end,
            }, {
                label = L["Send to group"],
                onClick = function(selected)
                    if #selected == 0 then return end
                    self:ShowPlayerPicker(function(targets)
                        if #selected == #list then
                            ns.Comms.SendBoss(bossKey, targets)
                        else
                            ns.Comms.SendReminders(bossKey, selected, targets)
                        end
                    end)
                end,
            }, {label = L["Cancel"]},
        },
    })
end

function Options:ShowImport(onDone)
    local IE = ns.ImportExport
    self:ShowDialog({
        title = L["Import"],
        message = L["Paste a reminder string (Ctrl+V)."],
        input = {text = ""},
        buttons = {
            {
                label = L["Import"],
                onClick = function(text)
                    local data, err = IE.Decode(text)
                    if data and data.kind == "profile" then
                        err, data = L["This is a profile string. Import it in the Profiles tab."], nil
                    end
                    if not data then
                        self:ShowMessage(err)
                        return
                    end
                    local notice
                    if data.unlinked then
                        -- no boss in the string, use the selected one
                        data.boss = Options.selectedBossKey and ns.Database.GetBoss(Options.selectedBossKey)
                        if not data.boss then
                            self:ShowMessage(L["This string is not tied to a boss. Select a boss in the list first, then import it again."])
                            return
                        end
                        notice = format(L["This string is not tied to a boss, so it will be imported to the selected boss: %s."],
                                        ns.Database.GetBossName(data.boss))
                    end
                    local function apply(mode)
                        IE.Apply(data, mode)
                        Options.selectedBossKey = ns.ImportExport.FirstBoss(data).key
                        if onDone then onDone(data) end
                    end
                    local summary = IE.Summary(data)
                    if notice then summary = notice .. "\n\n" .. summary end
                    local buttons
                    if IE.WouldOverwrite(data) then
                        local replaceLabel = (data.kind == "boss" or data.kind == "section") and L["Replace all"]
                                               or L["Replace existing"]
                        buttons = {
                            {label = replaceLabel, onClick = function() apply("replace") end},
                            {label = L["Add as new"], onClick = function() apply("add") end}, {label = L["Cancel"]},
                        }
                        summary = summary .. "\n\n"
                                    .. L["Some of this already exists. Replace it or add the import as new reminders?"]
                    else
                        buttons = {{label = L["Import"], onClick = function() apply("add") end}, {label = L["Cancel"]}}
                    end
                    self:Confirm(summary, buttons)
                end,
            }, {label = L["Cancel"]},
        },
    })
end

-- settings always go in, reminders are picked per boss
function Options:ShowProfileExport()
    local items = {}
    for _, boss in ns.Database.IterateBosses() do
        local count = #(ns.addon.db.profile.reminders[boss.key] or {})
        if count > 0 then
            items[#items + 1] = {key = boss.key, label = format("%s (%d)", ns.Database.GetBossName(boss), count)}
        end
    end
    local function export(bossKeys) self:ShowExport(ns.ImportExport.ExportProfile(bossKeys or {})) end
    if #items == 0 then
        export({})
        return
    end
    self:ShowDialog({
        title = L["Export profile"],
        message = L["Display and minimap settings are always included. Choose the bosses whose reminders to include."],
        checklist = items,
        buttons = {{label = L["Export"], onClick = export}, {label = L["Cancel"]}},
    })
end

-- import into a new profile or over the current one
function Options:ShowProfileImport()
    local IE = ns.ImportExport
    local db = ns.addon.db
    self:ShowDialog({
        title = L["Import profile"],
        message = L["Paste a profile string (Ctrl+V)."],
        input = {text = ""},
        buttons = {
            {
                label = L["Import"],
                onClick = function(text)
                    local data, err = IE.Decode(text)
                    if data and data.kind ~= "profile" then
                        err, data = L["This is a reminder string. Import it in the Reminders tab."], nil
                    end
                    if not data then
                        self:ShowMessage(err)
                        return
                    end
                    local function intoNew(name)
                        name = strtrim(name or "")
                        if name == "" then
                            self:ShowMessage(L["Enter a profile name."])
                            return
                        end
                        local exists = false
                        for _, existing in ipairs(db:GetProfiles()) do
                            if existing == name then exists = true end
                        end
                        local function apply()
                            db:SetProfile(name)
                            if exists then db:ResetProfile() end
                            IE.ApplyProfile(data)
                        end
                        if exists then
                            self:Confirm(format(L["The profile \"%s\" already exists. Overwrite it?"], name),
                                         {{label = L["Overwrite"], onClick = apply}, {label = L["Cancel"]}})
                        else
                            apply()
                        end
                    end
                    self:ShowDialog({
                        title = L["Import profile"],
                        message = IE.ProfileSummary(data) .. "\n\n" .. format(
                          L["Import into a new profile, or into the current profile \"%s\" (its settings and the reminders of the bosses above are replaced)."],
                          db:GetCurrentProfile()),
                        field = {label = L["New profile name"], text = L["Imported"]},
                        buttons = {
                            {label = L["Create profile"], onClick = intoNew}, {
                                label = L["Into current"],
                                onClick = function()
                                    self:Confirm(format(L["Overwrite the settings of \"%s\"?"], db:GetCurrentProfile()), {
                                        {label = L["Overwrite"], onClick = function()
                                            IE.ApplyProfile(data)
                                        end}, {label = L["Cancel"]},
                                    })
                                end,
                            }, {label = L["Cancel"]},
                        },
                    })
                end,
            }, {label = L["Cancel"]},
        },
    })
end
