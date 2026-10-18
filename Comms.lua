-- sharing over AceComm, like MRT / NSRT. we send the plain export string, so shares go
-- through ImportExport.Decode same as a paste. profiles are never shared.
-- receiver filters: onlyTrusted (leader/assists), onlyGuild, overwrite (no asking).
-- while a popup is open, new shares wait in the queue and run in order after it.
-- newer sender: one info popup per sender+version, still imports. too new for us: refused.
-- older than the import cutoff: ignored with a chat line.
-- whole group gets one message, a picked subset gets whispers.
-- the count check is a silent request/answer on QUERY_PREFIX, only sent when someone asks.
local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local AceComm = LibStub("AceComm-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local Comms = {}
ns.Comms = Comms

local PREFIX = "RCRShare"
local QUERY_PREFIX = "RCRQuery"
local QUERY_TIMEOUT = 5 -- seconds to wait for answers
local queue = {} -- { data, sender } waiting to be applied
local prompting = false
local versionNotices = {} -- sender@version -> true, so each popup only shows once

-- 12.x can hand us secret values (sender, unit checks) that can't be compared, treat as missing
local function usable(value) return value ~= nil and not issecretvalue(value) end

local function settings() return ns.addon.db.profile.sharing end

local function groupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

-- other online group members as { name, classFile, subgroup }, sorted by group then name.
-- name keeps the realm when there is one, whispers need it
function Comms.GetGroupMembers()
    local members = {}
    local function add(name, classFile, subgroup, online)
        if not usable(name) or not name or not usable(online) or not online then return end
        if UnitIsUnit(name, "player") then return end
        members[#members + 1] = {name = name, classFile = usable(classFile) and classFile or nil, subgroup = subgroup or 1}
    end
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local name, _, subgroup, _, _, classFile, _, online = GetRaidRosterInfo(index)
            add(name, classFile, usable(subgroup) and subgroup or 1, online)
        end
    else
        for index = 1, 4 do
            local unit = "party" .. index
            if UnitExists(unit) then
                local name, realm = UnitName(unit)
                if usable(name) and name and usable(realm) and realm and realm ~= "" then
                    name = name .. "-" .. realm
                end
                add(name, select(2, UnitClass(unit)), 1, UnitIsConnected(unit))
            end
        end
    end
    table.sort(members, function(a, b)
        if a.subgroup ~= b.subgroup then return a.subgroup < b.subgroup end
        return a.name < b.name
    end)
    return members
end

-- Sending

-- addon messages are locked down during encounters, say so instead of failing silently
local function canSend()
    if not groupChannel() then
        ns.addon:Print(L["You are not in a group."])
        return false
    end
    if C_ChatInfo.InChatMessagingLockdown() then
        ns.addon:Print(L["Addon messages are restricted right now. Try again after the encounter."])
        return false
    end
    return true
end

-- targets = list of names to whisper, nil for the whole group
local function send(prefix, text, targets, priority)
    if targets then
        for _, name in ipairs(targets) do AceComm:SendCommMessage(prefix, text, "WHISPER", name, priority) end
    else
        AceComm:SendCommMessage(prefix, text, groupChannel(), nil, priority)
    end
end

-- Share delivery
-- big shares go out in lots of parts. CTL retries throttled ones but drops anything else that fails,
-- and then the whole share is lost on the other end, so we send it once more.
-- receivers (ACK_VERSION+) answer with an "ack" on QUERY_PREFIX, id is a checksum of the text.
-- states: sending, waiting, ok, failed, none (no answer) or the ack reason

Comms.ACK_VERSION = "12.1.7"
local ACK_TIMEOUT = 10 -- seconds, counted from the last part
local RETRY_DELAY = 3
local shares = {} -- [id] = share, kept around for late answers
local shareCounter = 0
Comms.onShareUpdate = nil

local function shareID(text) return tostring(LibDeflate:Adler32(text)) end

local ACK_STATES = {ok = true, blocked = true, tooNew = true, tooOld = true, damaged = true}

local function shareUpdated(share) if Comms.onShareUpdate then Comms.onShareUpdate(share) end end

-- from -> to for the given names, or everyone
local function moveStates(share, names, from, to)
    for name in pairs(names or share.states) do
        if share.states[name] == from then share.states[name] = to end
    end
end

-- all deliveries finished, give the answers a few seconds
local function sendingDone(share)
    shareUpdated(share)
    ns.addon:ScheduleTimer(function()
        moveStates(share, nil, "waiting", "none")
        share.done = true
        shareUpdated(share)
    end, ACK_TIMEOUT)
end

-- one whisper, or the group message when target is nil
local function deliver(share, text, target, retried)
    share.sending = share.sending + 1
    local channel = target and "WHISPER" or groupChannel()
    local ok = channel ~= nil
    local names = target and {[Ambiguate(target, "none")] = true} or nil
    local function finished()
        share.sending = share.sending - 1
        if not ok and not retried then
            share.sending = share.sending + 1 -- still busy until the retry runs
            ns.addon:ScheduleTimer(function()
                share.sending = share.sending - 1
                deliver(share, text, target, true)
            end, RETRY_DELAY)
            return
        end
        moveStates(share, names, "sending", ok and "waiting" or "failed")
        if share.sending == 0 then sendingDone(share) else shareUpdated(share) end
    end
    if not channel then return finished() end
    -- called after each part: sent bytes, total bytes, did it go out
    AceComm:SendCommMessage(PREFIX, text, channel, target, "BULK", function(_, sent, total, didSend)
        if didSend == false then ok = false end
        if sent >= total then finished() end
    end)
end

-- returns the share (nil if we can't send) and opens the status window
function Comms.SendString(text, count, targets)
    if not canSend() then return nil end
    shareCounter = shareCounter + 1
    local share = {id = shareID(text), serial = shareCounter, count = count, group = not targets, states = {}, sending = 0}
    local names = targets
    if not names then
        names = {}
        for _, member in ipairs(Comms.GetGroupMembers()) do names[#names + 1] = member.name end
    end
    for _, name in ipairs(names) do share.states[Ambiguate(name, "none")] = "sending" end
    shares[share.id] = share
    if ns.Options then ns.Options:ShowShareStatus(share) end
    if targets then
        for _, name in ipairs(targets) do deliver(share, text, name) end
    else
        deliver(share, text, nil)
    end
    return share
end

-- receiver adds them or replaces by ID
function Comms.SendReminders(bossKey, reminders, targets)
    return Comms.SendString(ns.ImportExport.ExportReminders(bossKey, reminders), #reminders, targets)
end

-- receiver can replace their whole list for this boss
function Comms.SendBoss(bossKey, targets)
    return Comms.SendString(ns.ImportExport.ExportBoss(bossKey), #ns.Reminders.GetList(bossKey), targets)
end

-- every boss with reminders under an expansion / season / raid
function Comms.SendSection(sectionKey, targets)
    local text, count = ns.ImportExport.ExportSection(sectionKey)
    if not text then
        ns.addon:Print(L["There are no reminders in this section."])
        return false
    end
    return Comms.SendString(text, count, targets)
end

-- Reminder count check

local function encodeQuery(message)
    return LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(LibSerialize:Serialize(message)))
end

local function decodeQuery(text)
    local decoded = LibDeflate:DecodeForWoWAddonChannel(text)
    local inflated = decoded and LibDeflate:DecompressDeflate(decoded)
    if not inflated then return nil end
    local ok, message = LibSerialize:Deserialize(inflated)
    return ok and type(message) == "table" and message or nil
end

-- bosses a check covers: one boss, a section, or nil for every boss
local function scopeBosses(scope)
    if scope then
        local boss = ns.Database.GetBoss(scope)
        if boss then return {boss} end
        return ns.Database.GetSectionBosses(scope) or {}
    end
    local list = {}
    for _, boss in ns.Database.IterateBosses() do list[#list + 1] = boss end
    return list
end

-- { [bossKey] = count } for our own reminders in a scope. a single boss is always listed, even at 0
function Comms.CountReminders(scope)
    local counts = {}
    local bosses = scopeBosses(scope)
    for _, boss in ipairs(bosses) do
        local count = #(ns.addon.db.profile.reminders[boss.key] or {})
        if count > 0 or #bosses == 1 then counts[boss.key] = count end
    end
    return counts
end

-- the check that's running or finished last: { id, scope, expected = { name = true },
-- results = { [name] = { counts, version } }, done = bool }
local query
local queryCounter = 0
Comms.onQueryUpdate = nil -- set by the settings UI to redraw

local function queryUpdated() if Comms.onQueryUpdate then Comms.onQueryUpdate(query) end end

-- scope is a boss or section key, nil for everything
function Comms.RequestCounts(scope, targets)
    if not canSend() then return false end
    queryCounter = queryCounter + 1
    local id = format("%d-%d", time(), queryCounter)
    query = {id = id, scope = scope, expected = {}, results = {}, done = false}
    local expected = targets
    if not expected then
        expected = {}
        for _, member in ipairs(Comms.GetGroupMembers()) do expected[#expected + 1] = member.name end
    end
    for _, name in ipairs(expected) do query.expected[Ambiguate(name, "none")] = true end
    send(QUERY_PREFIX, encodeQuery({t = "req", id = id, scope = scope}), targets, "NORMAL")
    ns.addon:ScheduleTimer(function()
        if query and query.id == id then
            query.done = true
            queryUpdated()
        end
    end, QUERY_TIMEOUT)
    queryUpdated()
    return true
end

function Comms.GetQuery() return query end

function Comms.OnQuery(prefix, text, _, sender)
    if prefix ~= QUERY_PREFIX or not usable(sender) or not usable(text) or type(text) ~= "string" then return end
    if UnitIsUnit(sender, "player") then return end
    local inRaid, inParty = UnitInRaid(sender), UnitInParty(sender)
    if not usable(inRaid) or not usable(inParty) or not (inRaid or inParty) then return end
    local message = decodeQuery(text)
    if not message or type(message.id) ~= "string" then return end
    if message.t == "req" then
        if C_ChatInfo.InChatMessagingLockdown() then return end
        local scope = type(message.scope) == "string" and message.scope or nil
        local answer = {
            t = "res",
            id = message.id,
            counts = Comms.CountReminders(scope),
            version = ns.ImportExport.GetAddonVersion(),
        }
        AceComm:SendCommMessage(QUERY_PREFIX, encodeQuery(answer), "WHISPER", sender, "NORMAL")
    elseif message.t == "res" and query and query.id == message.id and type(message.counts) == "table" then
        local counts = {}
        for bossKey, count in pairs(message.counts) do
            if type(bossKey) == "string" and type(count) == "number" and ns.Database.GetBoss(bossKey) then
                counts[bossKey] = count
            end
        end
        local name = Ambiguate(sender, "none")
        query.results[name] = {counts = counts, version = type(message.version) == "string" and message.version or nil}
        query.expected[name] = true
        queryUpdated()
    elseif message.t == "ack" and ACK_STATES[message.status] then
        local name = Ambiguate(sender, "none")
        local share = shares[message.id]
        if not share and message.status == "damaged" then
            -- damaged text won't match the checksum, use their latest share
            for _, pending in pairs(shares) do
                local state = pending.states[name]
                if (state == "waiting" or state == "none") and (not share or pending.serial > share.serial) then share = pending end
            end
        end
        if share and share.states[name] and share.states[name] ~= "failed" then
            share.states[name] = message.status
            shareUpdated(share)
        end
    end
end

-- Receiving

-- sender is "Name" or "Name-Realm". anything secret counts as a fail
local function inGroup(sender)
    local inRaid, inParty = UnitInRaid(sender), UnitInParty(sender)
    return usable(inRaid) and usable(inParty) and (inRaid or inParty) and true or false
end

function Comms.IsSenderAllowed(sender)
    local opts = settings()
    if not inGroup(sender) then return false end
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

local function versionNotice(sender, version, message)
    local key = sender .. "@" .. tostring(version)
    if versionNotices[key] then return end
    versionNotices[key] = true
    ns.Options:ShowDialog({instance = "version", title = L["Newer version"], message = message, buttons = {{label = L["Close"]}}})
end

-- plain name, or the NSRT nickname when that's on. GetName follows NSRT's own setting,
-- errors are ignored so without NSRT it's just the name
function Comms.DisplayName(name)
    if settings().nsrtNicknames and type(NSAPI) == "table" and type(NSAPI.GetName) == "function" then
        local ok, nickname = pcall(NSAPI.GetName, NSAPI, name)
        if ok and usable(nickname) and type(nickname) == "string" and nickname ~= "" then return nickname end
    end
    return Ambiguate(name, "none")
end

-- same, class coloured
function Comms.PlayerName(name, classFile)
    local shown = Comms.DisplayName(name)
    if not classFile and UnitExists(name) then classFile = select(2, UnitClass(name)) end
    local color = usable(classFile) and classFile and C_ClassColor.GetClassColor(classFile)
    return color and color:WrapTextInColorCode(shown) or shown
end

-- AceComm callback, tests call it directly too
function Comms.OnReceive(prefix, message, _, sender)
    if prefix ~= PREFIX or not usable(sender) or not usable(message) or type(message) ~= "string" then return end
    if UnitIsUnit(sender, "player") then return end
    if not inGroup(sender) then return end
    -- let the sender know, older versions ignore it
    local function acknowledge(status)
        if C_ChatInfo.InChatMessagingLockdown() then return end
        AceComm:SendCommMessage(QUERY_PREFIX, encodeQuery({t = "ack", id = shareID(message), status = status}), "WHISPER",
                                sender, "NORMAL")
    end
    if not Comms.IsSenderAllowed(sender) then return acknowledge("blocked") end
    local name = Ambiguate(sender, "short") -- real name, so the newer version popup shows once per player
    local shown = Comms.PlayerName(sender)
    local data, err, reason = ns.ImportExport.Decode(message)
    if not data then
        acknowledge(reason == "tooNew" and "tooNew" or reason == "tooOld" and "tooOld" or "damaged")
        if reason == "tooNew" then
            versionNotice(name, err, format(
                            L["%s shared reminders you cannot import yet:\n%s\n\nPlease update Ready Check Reminder."], shown, err))
        elseif reason == "tooOld" then
            ns.addon:Print(format(L["Ignored reminders from %s: %s"], shown, err))
        end
        return
    end
    if data.kind == "profile" or data.unlinked then return end -- we never send these
    acknowledge("ok")
    if data.newer then
        versionNotice(name, data.addonVersion, format(
                        L["%s uses a newer version of Ready Check Reminder (%s); you have %s.\n\nTheir reminders are still imported when nothing conflicts. Consider updating."],
                        shown, data.addonVersion, ns.ImportExport.GetAddonVersion() or "?"))
    end
    queue[#queue + 1] = {data = data, sender = shown}
    processNext()
end

function Comms.QueueLength() return #queue end

function Comms.Init()
    AceComm:RegisterComm(PREFIX, Comms.OnReceive)
    AceComm:RegisterComm(QUERY_PREFIX, Comms.OnQuery)
end
