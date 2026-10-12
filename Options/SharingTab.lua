-- Settings for reminders shared by group members (Comms.lua does the sending).

local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local W, Style = ns.Widgets, ns.Style

local controls = {}

local function db()
    return ns.addon.db.profile.sharing
end

local OPTIONS = {
    { key = "onlyTrusted", label = L["Only trusted"],
      help = L["Receive reminder updates only from the raid leader or raid officers."] },
    { key = "onlyGuild", label = L["Only guild"],
      help = L["Receive reminder updates only from guild members."] },
    { key = "overwrite", label = L["Overwrite by default"],
      help = L["Automatically overwrite reminders when received from other players. When off, you are asked first."] },
}

local function create(parent)
    local title = W.Label(parent, L["Receiving"], 13, Style.ACCENT)
    title:SetPoint("TOPLEFT")
    local intro = W.Label(parent, L["Group members can send you reminders from their export window or the reminder editor (\"Send\")."], nil, Style.MUTED)
    intro:SetPoint("TOPLEFT", 0, -22)
    intro:SetWidth(640)

    local y = 52
    for _, option in ipairs(OPTIONS) do
        local box = W.CheckBox(parent, option.label, function(checked) db()[option.key] = checked end)
        box:SetPoint("TOPLEFT", 0, -y)
        local help = W.Label(parent, option.help, 11, Style.MUTED)
        help:SetPoint("TOPLEFT", 28, -(y + 24))
        help:SetWidth(600)
        controls[option.key] = box
        y = y + 56
    end
end

local function refresh()
    for _, option in ipairs(OPTIONS) do
        controls[option.key]:SetChecked(db()[option.key])
    end
end

table.insert(ns.OptionsTabs, { key = "sharing", label = L["Sharing"], Create = create, Refresh = refresh })
