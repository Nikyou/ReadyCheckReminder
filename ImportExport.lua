-- copy-paste strings for reminders and profiles
-- string: "!RCR1!" .. EncodeForPrint(CompressDeflate(Serialize(payload)))
-- payload.kind:
--   "reminders"  { boss = bossKey, reminders = { ... } }  some reminders of one boss
--   "boss"       { boss = bossKey, reminders = { ... } }  the whole list of one boss
--   "section"    { section = key, bosses = { [bossKey] = { ... } } }  whole lists of every boss with
--                reminders under an expansion / season / raid
--   "profile"    { settings = { display, minimap }, reminders = { [bossKey] = { ... } } }
-- every payload also has:
--   addonVersion  version that made it, like "12.1.0"
--   minVersion    oldest version allowed to import it (the maker's MIN_READER_VERSION)
local ADDON_NAME, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local ImportExport = {}
ns.ImportExport = ImportExport

local PREFIX = "!RCR1!"
local PAYLOAD_VERSION = 1
local MAX_REMINDERS = 200
local MAX_SUMMARY_NAMES = 10

-- oldest version that can read strings made by this one. bump it when the data changes in a
-- way older versions would misread, so they refuse the string instead of importing junk.
local MIN_READER_VERSION = "12.1.0"

-- the other direction: refuse strings made by versions older than this, for when reminders
-- change so much that old data isn't worth converting. nil = accept everything.
ImportExport.IMPORT_CUTOFF_VERSION = nil

local function parseVersion(version)
    if type(version) ~= "string" then return nil end
    local parts = {}
    for number in version:gmatch("%d+") do parts[#parts + 1] = tonumber(number) end
    return #parts > 0 and parts or nil
end

-- -1 / 0 / 1 like a comparator, nil if either side isn't a version string
function ImportExport.CompareVersions(a, b)
    local pa, pb = parseVersion(a), parseVersion(b)
    if not pa or not pb then return nil end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

function ImportExport.GetAddonVersion() return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") end

function ImportExport.Encode(payload)
    payload.v = PAYLOAD_VERSION
    payload.addonVersion = payload.addonVersion or ImportExport.GetAddonVersion()
    payload.minVersion = payload.minVersion or MIN_READER_VERSION
    local serialized = LibSerialize:Serialize(payload)
    local compressed = LibDeflate:CompressDeflate(serialized, {level = 9})
    return PREFIX .. LibDeflate:EncodeForPrint(compressed)
end
local encode = ImportExport.Encode

-- Export

function ImportExport.ExportReminder(bossKey, reminder) return ImportExport.ExportReminders(bossKey, {reminder}) end

-- "reminders" kind: gets added to the boss's list on import
function ImportExport.ExportReminders(bossKey, reminders)
    return encode({kind = "reminders", boss = bossKey, reminders = reminders})
end

-- "boss" kind: the importer can replace their whole list with it
-- every boss with reminders under an expansion/season/raid key. bosses without reminders are
-- left out so the receiver's lists for them aren't wiped. returns nil when there's nothing
function ImportExport.ExportSection(sectionKey)
    local bosses, count = {}, 0
    for _, boss in ipairs(ns.Database.GetSectionBosses(sectionKey) or {}) do
        local list = ns.Reminders.GetList(boss.key)
        if #list > 0 then
            bosses[boss.key] = list
            count = count + #list
        end
    end
    if count == 0 then return nil, 0 end
    return encode({kind = "section", section = sectionKey, bosses = bosses}), count
end

function ImportExport.ExportBoss(bossKey) return
  encode({kind = "boss", boss = bossKey, reminders = ns.Reminders.GetList(bossKey)}) end

-- settings always go in; reminders only for the bosses in bossKeys (can be empty)
function ImportExport.ExportProfile(bossKeys)
    local profile = ns.addon.db.profile
    local reminders = {}
    for _, bossKey in ipairs(bossKeys) do
        local list = profile.reminders[bossKey]
        if list and #list > 0 then reminders[bossKey] = list end
    end
    return encode({kind = "profile", settings = {display = profile.display, minimap = profile.minimap}, reminders = reminders})
end

-- Validation

local function boolean(v) if type(v) == "boolean" then return v end end

local POINTS = {
    CENTER = true,
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

-- key -> validator, returns the cleaned value or nil to drop it
local DISPLAY_FIELDS = {
    point = function(v) return POINTS[v] and v or nil end,
    relativePoint = function(v) return POINTS[v] and v or nil end,
    x = function(v) return type(v) == "number" and math.floor(v + 0.5) or nil end,
    y = function(v) return type(v) == "number" and math.floor(v + 0.5) or nil end,
    font = function(v) return type(v) == "string" and #v <= 100 and v or nil end,
    fontSize = function(v) return type(v) == "number" and math.max(8, math.min(64, v)) or nil end,
    outline = function(v) return (v == "NONE" or v == "OUTLINE" or v == "THICKOUTLINE") and v or nil end,
    justify = function(v) return (v == "LEFT" or v == "CENTER" or v == "RIGHT") and v or nil end,
    growth = function(v) return (v == "UP" or v == "DOWN") and v or nil end,
    spacing = function(v) return type(v) == "number" and math.max(0, math.min(40, v)) or nil end,
    duration = function(v) return type(v) == "number" and math.max(3, math.min(60, v)) or nil end,
    locked = boolean,
}

local MINIMAP_FIELDS = {hide = boolean, minimapPos = function(v) return type(v) == "number" and v or nil end}

local function sanitizeFields(source, fields)
    local clean = {}
    if type(source) ~= "table" then return clean end
    for key, validate in pairs(fields) do
        local value = validate(source[key])
        if value ~= nil then clean[key] = value end
    end
    return clean
end

-- one bad reminder rejects the whole list
local function sanitizeList(list)
    if type(list) ~= "table" or #list > MAX_REMINDERS then return nil end
    local clean = {}
    for _, source in ipairs(list) do
        local reminder = ns.Reminders.Sanitize(source)
        if not reminder then return nil end
        clean[#clean + 1] = reminder
    end
    return clean
end

-- refused: nil, error, "tooOld" or "tooNew"
-- ok: true, plus whether it came from a newer version than ours
local function checkVersion(payload)
    local made, needed, mine = payload.addonVersion, payload.minVersion, ImportExport.GetAddonVersion()
    local cutoff = ImportExport.IMPORT_CUTOFF_VERSION
    if cutoff and (type(made) ~= "string" or (ImportExport.CompareVersions(made, cutoff) or -1) < 0) then
        return nil, format(L["This string was made by an old version (%s) and can no longer be imported."],
                           type(made) == "string" and made or "?"), "tooOld"
    end
    if type(needed) == "string" and ImportExport.CompareVersions(mine, needed) == -1 then
        return nil, format(L["This string needs Ready Check Reminder %s or newer. You have %s."], needed, mine or "?"), "tooNew"
    end
    return true, ImportExport.CompareVersions(made, mine) == 1
end

-- returns { kind, boss?, reminders, settings?, skippedBosses?, addonVersion, newer }
-- or nil, localised error, and "tooOld" / "tooNew" when the version was the problem
function ImportExport.Decode(text)
    if type(text) ~= "string" then return nil, L["The import string is empty."] end
    text = text:gsub("%s", "")
    if text == "" then return nil, L["The import string is empty."] end
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, L["This is not a Ready Check Reminder string."] end
    local decoded = LibDeflate:DecodeForPrint(text:sub(#PREFIX + 1))
    local inflated = decoded and LibDeflate:DecompressDeflate(decoded)
    if not inflated then return nil, L["The import string is damaged."] end
    local ok, payload = LibSerialize:Deserialize(inflated)
    if not ok or type(payload) ~= "table" then return nil, L["The import string is damaged."] end
    if payload.v ~= PAYLOAD_VERSION then return nil, L["This string was made by an unsupported version."] end
    local versionOk, newerOrErr, reason = checkVersion(payload)
    if not versionOk then return nil, newerOrErr, reason end
    local made = type(payload.addonVersion) == "string" and payload.addonVersion or nil
    local data, err = ImportExport.DecodePayload(payload)
    if not data then return nil, err end
    data.addonVersion, data.newer = made, newerOrErr
    return data
end

-- content checks only, versions are already handled by Decode
function ImportExport.DecodePayload(payload)
    if payload.kind == "profile" then
        if type(payload.reminders) ~= "table" then return nil, L["The import string is damaged."] end
        local settings = type(payload.settings) == "table" and payload.settings or {}
        local data = {
            kind = "profile",
            settings = {
                display = sanitizeFields(settings.display, DISPLAY_FIELDS),
                minimap = sanitizeFields(settings.minimap, MINIMAP_FIELDS),
            },
            reminders = {},
            skippedBosses = 0,
        }
        for bossKey, list in pairs(payload.reminders) do
            if type(bossKey) == "string" and ns.Database.GetBoss(bossKey) then
                local clean = sanitizeList(list)
                if not clean then return nil, L["A reminder in this string is invalid."] end
                data.reminders[bossKey] = clean
            else
                data.skippedBosses = data.skippedBosses + 1
            end
        end
        return data
    end

    if payload.kind == "section" then
        if type(payload.bosses) ~= "table" then return nil, L["The import string is damaged."] end
        local data = {kind = "section", section = payload.section, bosses = {}, skippedBosses = 0}
        -- keep the boss order of the tree, unknown bosses (e.g. a newer raid) are skipped
        for _, boss in ns.Database.IterateBosses() do
            local list = payload.bosses[boss.key]
            if list ~= nil then
                local clean = sanitizeList(list)
                if not clean then return nil, L["A reminder in this string is invalid."] end
                data.bosses[#data.bosses + 1] = {boss = boss, reminders = clean}
            end
        end
        for bossKey in pairs(payload.bosses) do
            if type(bossKey) ~= "string" or not ns.Database.GetBoss(bossKey) then
                data.skippedBosses = data.skippedBosses + 1
            end
        end
        if #data.bosses == 0 then return nil, L["None of the bosses in this string are in the boss database."] end
        return data
    end

    local kind = payload.kind == "reminder" and "reminders" or payload.kind
    if kind ~= "reminders" and kind ~= "boss" then return nil, L["The import string is damaged."] end
    local boss = type(payload.boss) == "string" and ns.Database.GetBoss(payload.boss)
    if not boss then return nil, L["The boss in this string is not in the boss database."] end
    local reminders = sanitizeList(payload.reminders)
    if not reminders then return nil, L["A reminder in this string is invalid."] end
    if kind == "reminders" and #reminders == 0 then return nil, L["The import string is damaged."] end
    return {kind = kind, boss = boss, reminders = reminders}
end

-- Reminder import

local function reminderNames(reminders)
    local names = {}
    for i, reminder in ipairs(reminders) do
        if i > MAX_SUMMARY_NAMES then
            names[#names + 1] = format(L["...and %d more"], #reminders - MAX_SUMMARY_NAMES)
            break
        end
        names[#names + 1] = "- " .. (reminder.name ~= "" and reminder.name or L["(unnamed)"])
    end
    return table.concat(names, "\n")
end

local function sectionName(data) return data.section and ns.Database.GetSectionName(data.section) or L["Several bosses"] end

-- total reminder count and a short "what" for chat messages
function ImportExport.Describe(data)
    if data.kind == "section" then
        local count = 0
        for _, entry in ipairs(data.bosses) do count = count + #entry.reminders end
        return count, sectionName(data)
    end
    return #data.reminders, ns.Database.GetBossName(data.boss)
end

-- boss to jump to in the Reminders tab after an import
function ImportExport.FirstBoss(data) return data.kind == "section" and data.bosses[1].boss or data.boss end

local function sectionSummary(data)
    local lines = {format(L["Section: %s"], sectionName(data))}
    local withReminders = 0
    for _, entry in ipairs(data.bosses) do
        lines[#lines + 1] = format(L["- %s: %d reminder(s)"], ns.Database.GetBossName(entry.boss), #entry.reminders)
        if #ns.Reminders.GetList(entry.boss.key) > 0 then withReminders = withReminders + 1 end
    end
    if data.skippedBosses > 0 then
        lines[#lines + 1] = format(L["%d boss(es) not in the boss database were skipped."], data.skippedBosses)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = format(L["%d of these bosses already have reminders."], withReminders)
    return table.concat(lines, "\n")
end

function ImportExport.Summary(data)
    local text
    if data.kind == "section" then
        text = sectionSummary(data)
    else
        local existing = #ns.Reminders.GetList(data.boss.key)
        text = format(L["Boss: %s\nReminders: %d\n%s\n\nThis boss currently has %d reminder(s)."],
                      ns.Database.GetBossName(data.boss), #data.reminders, reminderNames(data.reminders), existing)
    end
    if data.newer then
        text = text .. "\n\n"
                 .. format(L["Made with a newer version (%s); you have %s."], data.addonVersion,
                           ImportExport.GetAddonVersion() or "?")
    end
    return text
end

-- mode "replace": boss and section strings wipe each included boss's list, reminder strings
-- overwrite matching IDs. mode "add": everything appended, clashing IDs get a fresh one
function ImportExport.Apply(data, mode)
    if data.kind == "section" then
        for _, entry in ipairs(data.bosses) do
            ImportExport.Apply({kind = "boss", boss = entry.boss, reminders = entry.reminders}, mode)
        end
        return
    end
    local list = ns.Reminders.GetList(data.boss.key)
    if data.kind == "boss" and mode == "replace" then
        wipe(list)
        for _, reminder in ipairs(data.reminders) do list[#list + 1] = reminder end
        return
    end
    for _, reminder in ipairs(data.reminders) do
        local index = ns.Reminders.FindIndex(data.boss.key, reminder.id)
        if index and mode == "replace" then
            list[index] = reminder
        else
            if index then reminder.id = ns.Reminders.NewID() end
            list[#list + 1] = reminder
        end
    end
end

function ImportExport.WouldOverwrite(data)
    if data.kind == "section" then
        for _, entry in ipairs(data.bosses) do if #ns.Reminders.GetList(entry.boss.key) > 0 then return true end end
        return false
    end
    if data.kind == "boss" then return #ns.Reminders.GetList(data.boss.key) > 0 end
    for _, reminder in ipairs(data.reminders) do if ns.Reminders.FindIndex(data.boss.key, reminder.id) then return true end end
    return false
end

-- Profile import

function ImportExport.ProfileSummary(data)
    local lines = {L["Display and minimap settings"]}
    local bosses = {}
    for bossKey, list in pairs(data.reminders) do
        bosses[#bosses + 1] = {name = ns.Database.GetBossName(ns.Database.GetBoss(bossKey)), count = #list}
    end
    table.sort(bosses, function(a, b) return a.name < b.name end)
    for _, boss in ipairs(bosses) do lines[#lines + 1] = format(L["- %s: %d reminder(s)"], boss.name, boss.count) end
    if #bosses == 0 then lines[#lines + 1] = L["No reminders."] end
    if data.skippedBosses > 0 then
        lines[#lines + 1] = format(L["%d boss(es) not in the boss database were skipped."], data.skippedBosses)
    end
    return table.concat(lines, "\n")
end

-- replaces settings and the lists of bosses in the import, other bosses are left alone
function ImportExport.ApplyProfile(data)
    local profile = ns.addon.db.profile
    for key, value in pairs(data.settings.display) do profile.display[key] = value end
    for key, value in pairs(data.settings.minimap) do profile.minimap[key] = value end
    for bossKey, list in pairs(data.reminders) do profile.reminders[bossKey] = list end
    ns.addon:OnProfileChanged()
end
