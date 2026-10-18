-- sharing settings and the reminder count check
local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local W, Style = ns.Widgets, ns.Style

local controls = {}
local ALL_BOSSES = "*"
local checkScope = ALL_BOSSES

local function db() return ns.addon.db.profile.sharing end

local OPTIONS = {
    {
        key = "onlyTrusted",
        label = L["Only trusted"],
        help = L["Receive reminder updates only from the raid leader or raid officers."],
    }, {key = "onlyGuild", label = L["Only guild"], help = L["Receive reminder updates only from guild members."]}, {
        key = "overwrite",
        label = L["Overwrite by default"],
        help = L["Automatically overwrite reminders when received from other players. When off, you are asked first."],
    }, {
        key = "nsrtNicknames",
        label = L["Use NSRT nicknames"],
        help = L["Shows players by their Northern Sky Raid Tools nickname when sending, in the reminder check and in messages. Does nothing without NSRT."],
    },
}

-- everything in the boss tree, indented by depth
local function scopeItems()
    local DB = ns.Database
    local items = {{value = ALL_BOSSES, text = L["All bosses"]}}
    local function add(key, text, depth) items[#items + 1] = {value = key, text = string.rep("   ", depth) .. text} end
    for _, expansion in ipairs(ns.Raids) do
        add(expansion.key, DB.GetExpansionName(expansion), 0)
        for _, season in ipairs(expansion.seasons) do
            add(season.key, DB.GetSeasonName(season), 1)
            for _, raid in ipairs(season.raids) do
                add(raid.key, DB.GetRaidName(raid), 2)
                for _, boss in ipairs(raid.bosses) do add(boss.key, DB.GetBossName(boss), 3) end
            end
        end
    end
    return items
end

local function colouredName(name, classes) return ns.Comms.PlayerName(name, classes[name]) end

-- Sorting
-- every rule gives each player a value, nil always goes last. saved in profile.sharing.checkSort,
-- rules missing there get added at the end

local SORT_CRITERIA = {
    {key = "response", label = L["Response"], asc = L["No response first"], desc = L["Response first"]},
    {key = "count", label = L["Reminder count"], asc = L["Fewest first"], desc = L["Most first"]},
    {key = "name", label = L["Player name"], asc = L["A to Z"], desc = L["Z to A"]},
    {key = "class", label = L["Class"], asc = L["A to Z"], desc = L["Z to A"]},
    {key = "group", label = L["Raid group"], asc = L["1 to 8"], desc = L["8 to 1"]},
}
local CRITERIA_BY_KEY = {}
for _, criterion in ipairs(SORT_CRITERIA) do CRITERIA_BY_KEY[criterion.key] = criterion end
local DEFAULT_ON = {response = true, name = true}

-- saved order, unknown or doubled keys dropped, missing ones appended
local function sortRules()
    local saved = db().checkSort
    local rules, seen = {}, {}
    if type(saved) == "table" then
        for _, rule in ipairs(saved) do
            if type(rule) == "table" and CRITERIA_BY_KEY[rule.key] and not seen[rule.key] then
                seen[rule.key] = true
                rules[#rules + 1] = {key = rule.key, on = rule.on and true or false, desc = rule.desc and true or false}
            end
        end
    end
    for _, criterion in ipairs(SORT_CRITERIA) do
        if not seen[criterion.key] then
            rules[#rules + 1] = {key = criterion.key, on = DEFAULT_ON[criterion.key] or false, desc = false}
        end
    end
    db().checkSort = rules
    return rules
end

local function totalCount(result)
    local total = 0
    for _, count in pairs(result.counts) do total = total + count end
    return total
end

-- real name settles any ties left
local function sortNames(names, query, members)
    local values = {}
    for _, name in ipairs(names) do
        local result, member = query.results[name], members[name]
        local classFile = member and member.classFile
        values[name] = {
            response = result and 1 or 0,
            count = result and totalCount(result) or nil,
            name = ns.Comms.DisplayName(name):lower(),
            class = classFile and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] or classFile):lower() or nil,
            group = member and member.subgroup or nil,
        }
    end
    local rules = {}
    for _, rule in ipairs(sortRules()) do if rule.on then rules[#rules + 1] = rule end end
    table.sort(names, function(a, b)
        for _, rule in ipairs(rules) do
            local x, y = values[a][rule.key], values[b][rule.key]
            if x ~= y then
                if x == nil then return false end
                if y == nil then return true end
                if rule.desc then return x > y end
                return x < y
            end
        end
        return a < b
    end)
end

-- redraws the status line and the per-player list of the last check
local function renderQuery(query)
    if not controls.results then return end
    if not query then
        controls.status:SetText("")
        controls.results:SetText("")
        controls.resultsScroll:SetContentHeight(1)
        return
    end
    local classes, members = {}, {}
    for _, member in ipairs(ns.Comms.GetGroupMembers()) do
        local name = Ambiguate(member.name, "none")
        classes[name], members[name] = member.classFile, member
    end

    local names, answered = {}, 0
    for name in pairs(query.expected) do names[#names + 1] = name end
    sortNames(names, query, members)
    for _ in pairs(query.results) do answered = answered + 1 end
    controls.status:SetText(format(query.done and L["%d of %d checked."] or L["Checking: %d of %d"], answered,
                                   #names))

    local single = query.scope and ns.Database.GetBoss(query.scope) ~= nil
    local lines = {}
    for _, name in ipairs(names) do
        local result = query.results[name]
        if result then
            lines[#lines + 1] = colouredName(name, classes) .. ": " .. format(L["reminders: %d"], totalCount(result))
            if not single then
                for _, boss in ns.Database.IterateBosses() do
                    local count = result.counts[boss.key]
                    if count and count > 0 then
                        lines[#lines + 1] = "|cff999999    " .. ns.Database.GetBossName(boss) .. ": " .. count .. "|r"
                    end
                end
            end
        else
            lines[#lines + 1] = colouredName(name, classes) .. ": |cff999999" .. (query.done and L["no response"] or "...") .. "|r"
        end
    end
    controls.results:SetText(table.concat(lines, "\n"))
    controls.resultsScroll:SetContentHeight(controls.results:GetStringHeight() + 8)
end

local function create(parent)
    local title = W.Label(parent, L["Receiving"], 13, Style.ACCENT)
    title:SetPoint("TOPLEFT")
    local intro = W.Label(parent,
                          L["Group members can send you reminders from their export window or the reminder editor (\"Send\")."],
                          nil, Style.MUTED)
    intro:SetPoint("TOPLEFT", 0, -22)
    intro:SetWidth(560)

    local y = 52
    for _, option in ipairs(OPTIONS) do
        local box = W.CheckBox(parent, option.label, function(checked) db()[option.key] = checked end)
        box:SetPoint("TOPLEFT", 0, -y)
        local help = W.Label(parent, option.help, 11, Style.MUTED)
        help:SetPoint("TOPLEFT", 28, -(y + 24))
        help:SetWidth(530)
        controls[option.key] = box
        y = y + 56
    end

    -- reminder count check, right column
    local x = 600
    local checkTitle = W.Label(parent, L["Reminder check"], 13, Style.ACCENT)
    checkTitle:SetPoint("TOPLEFT", x, 0)
    local checkHelp = W.Label(parent, L["Check how many reminders players have for each boss. Only players with the addon can be checked."], nil,
                              Style.MUTED)
    checkHelp:SetPoint("TOPLEFT", x, -22)
    checkHelp:SetPoint("RIGHT", parent, "RIGHT")
    controls.scope = W.Dropdown(parent, 250, scopeItems, function(value) checkScope = value end)
    controls.scope:SetPoint("TOPLEFT", x, -64)
    local check = W.Button(parent, L["Check"], nil, 22, function()
        ns.Options:ShowPlayerPicker(function(targets)
            ns.Comms.RequestCounts(checkScope ~= ALL_BOSSES and checkScope or nil, targets)
        end, L["Reminder check"], L["Check"])
    end)
    check:FitWidth()
    check:SetPoint("LEFT", controls.scope, "RIGHT", 8, 0)

    -- one row per rule, refilled from sortRules() when the order changes
    local sortOpen = false
    local sortRows = {}
    local sortHeader
    local function sortChanged()
        controls.refreshSort()
        renderQuery(ns.Comms.GetQuery())
    end
    local function moveRule(index, delta)
        local rules = sortRules()
        local other = index + delta
        if not rules[other] then return end
        rules[index], rules[other] = rules[other], rules[index]
        sortChanged()
    end
    for index = 1, #SORT_CRITERIA do
        local row = {}
        row.box = W.CheckBox(parent, "", function(checked)
            sortRules()[index].on = checked
            sortChanged()
        end)
        row.direction = W.Dropdown(parent, 150, function()
            local criterion = CRITERIA_BY_KEY[sortRules()[index].key]
            return {{value = false, text = criterion.asc}, {value = true, text = criterion.desc}}
        end, function(value)
            sortRules()[index].desc = value
            sortChanged()
        end)
        row.up = W.ArrowButton(parent, "UP", function() moveRule(index, -1) end)
        row.down = W.ArrowButton(parent, "DOWN", function() moveRule(index, 1) end)
        sortRows[index] = row
    end

    controls.status = W.Label(parent, "", 11, Style.MUTED)
    local panel = W.Panel(parent)
    panel:SetPoint("BOTTOMRIGHT")

    local function layout()
        sortHeader:SetOpen(sortOpen)
        local top = 94
        sortHeader:SetPoint("TOPLEFT", x, -top)
        top = top + 24
        for _, row in ipairs(sortRows) do
            for _, widget in pairs(row) do widget:SetShown(sortOpen) end
            if sortOpen then
                row.box:SetPoint("TOPLEFT", x, -top)
                row.direction:SetPoint("TOPLEFT", x + 160, -top)
                row.up:SetPoint("LEFT", row.direction, "RIGHT", 6, 0)
                row.down:SetPoint("LEFT", row.up, "RIGHT", 0, 0)
                top = top + 26
            end
        end
        controls.status:SetPoint("TOPLEFT", x, -(top + 2))
        panel:SetPoint("TOPLEFT", x, -(top + 22))
    end
    sortHeader = W.SectionToggle(parent, L["Sorting"], function()
        sortOpen = not sortOpen
        layout()
    end)
    W.AddTooltip(sortHeader, function(tooltip)
        tooltip:SetText(L["Sorting"])
        tooltip:AddLine(L["Players are sorted by the ticked rules from top to bottom. Use the arrows to change their order."], 1, 1, 1, true)
    end)

    function controls.refreshSort()
        local rules = sortRules()
        for index, row in ipairs(sortRows) do
            local rule = rules[index]
            row.box:SetLabel(index .. ". " .. CRITERIA_BY_KEY[rule.key].label)
            row.box:SetChecked(rule.on)
            row.direction:SetValue(rule.desc)
            row.direction:SetEnabled(rule.on)
            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #rules)
        end
    end
    layout()
    controls.resultsScroll = W.ScrollArea(panel)
    controls.resultsScroll:SetPoint("TOPLEFT", 8, -8)
    controls.resultsScroll:SetPoint("BOTTOMRIGHT", -26, 8)
    controls.results = W.Label(controls.resultsScroll.content, "")
    controls.results:SetPoint("TOPLEFT")
    controls.results:SetPoint("RIGHT")
    controls.results:SetJustifyV("TOP")

    ns.Comms.onQueryUpdate = renderQuery
end

local function refresh()
    for _, option in ipairs(OPTIONS) do controls[option.key]:SetChecked(db()[option.key]) end
    controls.scope:SetValue(checkScope)
    controls.refreshSort()
    renderQuery(ns.Comms.GetQuery())
end

table.insert(ns.OptionsTabs, {key = "sharing", label = L["Sharing"], Create = create, Refresh = refresh})
