-- sharing reminders with the group over AceComm, same idea as MRT / NSRT.
-- we send the exact export string, so incoming shares go through ImportExport.Decode like a
-- pasted string would. profile strings are never shared.
--
-- sharing settings on the receiving side:
--   onlyTrusted  only from the leader or assistants
--   onlyGuild    only from guildmates
--   overwrite    apply shares that overwrite stuff without asking
-- a share that needs a decision opens a popup. anything arriving while it's open waits in
-- the queue and gets handled in order after the popup is answered.
--
-- versions: newer sender -> info popup (once per sender + version), import goes ahead as normal.
-- needs a newer version than ours -> refused, popup says to update. older than the import
-- cutoff -> ignored with a chat line.
local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local AceComm = LibStub("AceComm-3.0")

local Comms = {}
ns.Comms = Comms

local PREFIX = "RCRShare"
local queue = {} -- { data, sender } waiting to be applied
local prompting = false
local versionNotices = {} -- sender@version -> true, so each popup only shows once

-- in 12.x the game can hand us secret values (sender, unit checks) that can't be compared.
-- treat them as missing
local function usable(value) return value ~= nil and not issecretvalue(value) end

local function settings() return ns.addon.db.profile.sharing end

local function groupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

-- Sending

-- true if it was handed to AceComm. addon messages are locked down during encounters,
-- so check that first instead of failing silently
function Comms.SendString(text, count)
    local channel = groupChannel()
    if not channel then
        ns.addon:Print(L["You are not in a group."])
        return false
    end
    if C_ChatInfo.InChatMessagingLockdown() then
        ns.addon:Print(L["Addon messages are restricted right now. Try again after the encounter."])
        return false
    end
    AceComm:SendCommMessage(PREFIX, text, channel, nil, "BULK")
    ns.addon:Print(format(L["Sent %d reminder(s) to your group."], count))
    return true
end

-- receiver adds them or replaces by ID
function Comms.SendReminders(bossKey, reminders)
    return Comms.SendString(ns.ImportExport.ExportReminders(bossKey, reminders), #reminders)
end

-- receiver can replace their whole list for this boss
function Comms.SendBoss(bossKey) return Comms.SendString(ns.ImportExport.ExportBoss(bossKey), #ns.Reminders.GetList(bossKey)) end

-- every boss with reminders under an expansion / season / raid
function Comms.SendSection(sectionKey)
    local text, count = ns.ImportExport.ExportSection(sectionKey)
    if not text then
        ns.addon:Print(L["There are no reminders in this section."])
        return false
    end
    return Comms.SendString(text, count)
end

-- Receiving

-- sender is "Name" or "Name-Realm". anything secret counts as a fail
function Comms.IsSenderAllowed(sender)
    local opts = settings()
    local inRaid, inParty = UnitInRaid(sender), UnitInParty(sender)
    if not usable(inRaid) or not usable(inParty) or not (inRaid or inParty) then return false end
    if opts.onlyTrusted then
        local leader, assistant = UnitIsGroupLeader(sender), UnitIsGroupAssistant(sender)
        if not usable(leader) or not usable(assistant) or not (leader or assistant) then return false end
    end
    if opts.onlyGuild then
        local inGuild = UnitIsInMyGuild(sender)
        if not usable(inGuild) or not inGuild then return false end
    end
    return true
end

local processNext

local function applied(data, sender)
    local count, what = ns.ImportExport.Describe(data)
    ns.addon:Print(format(L["Received %d reminder(s) for %s from %s."], count, what, sender))
    if ns.Options then ns.Options:RefreshActiveTab() end
end

-- the queue is paused while this is open, resolve() picks it back up
local function prompt(data, sender)
    prompting = true
    local function resolve(mode)
        if mode then
            ns.ImportExport.Apply(data, mode)
            applied(data, sender)
        end
        prompting = false
        processNext()
    end
    local replaceLabel = (data.kind == "boss" or data.kind == "section") and L["Replace all"] or L["Replace existing"]
    ns.Options:ShowDialog({
        instance = "share",
        title = format(L["Reminders shared by %s"], sender),
        message = ns.ImportExport.Summary(data) .. "\n\n"
          .. L["Some of this already exists. Replace it or add the import as new reminders?"],
        buttons = {
            {label = replaceLabel, onClick = function() resolve("replace") end},
            {label = L["Add as new"], onClick = function() resolve("add") end},
            {label = L["Ignore"], onClick = function() resolve(nil) end},
        },
    })
end

-- works through the queue until something needs a prompt
function processNext()
    while not prompting and #queue > 0 do
        local share = table.remove(queue, 1)
        local data, sender = share.data, share.sender
        if not ns.ImportExport.WouldOverwrite(data) then
            ns.ImportExport.Apply(data, "add")
            applied(data, sender)
        elseif settings().overwrite then
            ns.ImportExport.Apply(data, "replace")
            applied(data, sender)
        else
            prompt(data, sender)
        end
    end
end

-- once per sender and version per session
local function versionNotice(sender, version, message)
    local key = sender .. "@" .. tostring(version)
    if versionNotices[key] then return end
    versionNotices[key] = true
    ns.Options:ShowDialog({instance = "version", title = L["Newer version"], message = message, buttons = {{label = L["Close"]}}})
end

-- AceComm callback, tests call it directly too
function Comms.OnReceive(prefix, message, _, sender)
    if prefix ~= PREFIX or not usable(sender) or not usable(message) or type(message) ~= "string" then return end
    if UnitIsUnit(sender, "player") then return end
    if not Comms.IsSenderAllowed(sender) then return end
    local name = Ambiguate(sender, "short")
    local data, err, reason = ns.ImportExport.Decode(message)
    if not data then
        if reason == "tooNew" then
            versionNotice(name, err, format(
                            L["%s shared reminders you cannot import yet:\n%s\n\nPlease update Ready Check Reminder."], name, err))
        elseif reason == "tooOld" then
            ns.addon:Print(format(L["Ignored reminders from %s: %s"], name, err))
        end
        return
    end
    if data.kind == "profile" then return end
    if data.newer then
        versionNotice(name, data.addonVersion, format(
                        L["%s uses a newer version of Ready Check Reminder (%s); you have %s.\n\nTheir reminders are still imported when nothing conflicts. Consider updating."],
                        name, data.addonVersion, ns.ImportExport.GetAddonVersion() or "?"))
    end
    queue[#queue + 1] = {data = data, sender = name}
    processNext()
end

function Comms.QueueLength() return #queue end

function Comms.Init() AceComm:RegisterComm(PREFIX, Comms.OnReceive) end
