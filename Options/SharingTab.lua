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

-- redraws the status line and the per-player list of the last check
local function renderQuery(query)
    if not controls.results then return end
    if not query then
        controls.status:SetText("")
        controls.results:SetText("")
        controls.resultsScroll:SetContentHeight(1)
        return
    end
    local classes = {}
    for _, member in ipairs(ns.Comms.GetGroupMembers()) do classes[Ambiguate(member.name, "none")] = member.classFile end

    local names, answered = {}, 0
    local sortKeys = {}
    for name in pairs(query.expected) do
        names[#names + 1] = name
        sortKeys[name] = ns.Comms.DisplayName(name):lower()
    end
    -- no response first, so they don't get lost between the counts, then alphabetical
    table.sort(names, function(a, b)
        local aMissing, bMissing = not query.results[a], not query.results[b]
        if aMissing ~= bMissing then return aMissing end
        if sortKeys[a] ~= sortKeys[b] then return sortKeys[a] < sortKeys[b] end
        return a < b
    end)
    for _ in pairs(query.results) do answered = answered + 1 end
    controls.status:SetText(format(query.done and L["%d of %d checked."] or L["Checking: %d of %d"], answered,
                                   #names))

    local single = query.scope and ns.Database.GetBoss(query.scope) ~= nil
    local lines = {}
    for _, name in ipairs(names) do
        local result = query.results[name]
        if result then
            local total = 0
            for _, count in pairs(result.counts) do total = total + count end
            lines[#lines + 1] = colouredName(name, classes) .. ": " .. format(L["reminders: %d"], total)
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
    controls.status = W.Label(parent, "", 11, Style.MUTED)
    controls.status:SetPoint("TOPLEFT", x, -96)

    local panel = W.Panel(parent)
    panel:SetPoint("TOPLEFT", x, -116)
    panel:SetPoint("BOTTOMRIGHT")
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
    renderQuery(ns.Comms.GetQuery())
end

table.insert(ns.OptionsTabs, {key = "sharing", label = L["Sharing"], Create = create, Refresh = refresh})
