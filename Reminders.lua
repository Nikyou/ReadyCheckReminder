-- reminder format:
--   id            unique string
--   name          string
--   enabled       boolean
--   type          "group", "keywordLine" or "keywordGroup"
--   keyword       keywordLine only
--   startKeyword, endKeyword   keywordGroup only
--   perLine       keyword types: separate text per line number
--   text          keyword types: text for every line, or for lines without a number when perLine
--   texts         { [line] = string }, used when perLine
--   groups        group type: list of { groups = { [1..8] = true }, text = string }
--   load          { difficulty, class, spec, role, range } sets, empty = any
local _, ns = ...

local Reminders = {}
ns.Reminders = Reminders

Reminders.MAX_LINES = 40
Reminders.MAX_GROUP_ENTRIES = 8
Reminders.MAX_TEXT = 500

local TYPES = {group = true, keywordLine = true, keywordGroup = true}
Reminders.TYPES = {"keywordLine", "keywordGroup", "group"}

Reminders.LOAD_KEYS = {
    difficulty = {lfr = true, normal = true, heroic = true, mythic = true},
    role = {TANK = true, HEALER = true, DAMAGER = true},
    range = {melee = true, ranged = true},
    -- class and spec are checked in LoadConditions
}

local counter = 0
function Reminders.NewID()
    counter = counter + 1
    return format("%x%04x%04x", time(), counter % 0x10000, math.random(0, 0xffff))
end

local function emptyLoad() return {difficulty = {}, class = {}, spec = {}, role = {}, range = {}} end

function Reminders.New(reminderType, name)
    local r = {id = Reminders.NewID(), name = name or "", enabled = true, type = reminderType, load = emptyLoad()}
    if reminderType == "keywordLine" then
        r.keyword, r.perLine, r.text, r.texts = "", false, "", {}
    elseif reminderType == "keywordGroup" then
        r.startKeyword, r.endKeyword, r.perLine, r.text, r.texts = "", "", false, "", {}
    else
        r.groups = {{groups = {}, text = ""}}
    end
    return r
end

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = deepCopy(v) end
    return copy
end
Reminders.DeepCopy = deepCopy

-- "Soak 2" -> "Soak 3", skipping taken numbers. nil if there's no number (caller uses "(copy)")
function Reminders.NextNumberedName(name, list)
    local prefix, number = (name or ""):match("^(.-)(%d+)$")
    if not prefix then return nil end
    local taken = {}
    for _, r in ipairs(list or {}) do taken[r.name] = true end
    number = tonumber(number) + 1
    while taken[prefix .. number] do number = number + 1 end
    return prefix .. number
end

function Reminders.Duplicate(reminder, newName)
    local copy = deepCopy(reminder)
    copy.id = Reminders.NewID()
    copy.name = newName or copy.name
    return copy
end

-- every template, for wildcard scanning
function Reminders.AllTexts(reminder)
    local list = {}
    if type(reminder.text) == "string" then list[#list + 1] = reminder.text end
    for _, text in pairs(reminder.texts or {}) do list[#list + 1] = text end
    for _, entry in ipairs(reminder.groups or {}) do list[#list + 1] = entry.text end
    return list
end

function Reminders.MaxLine(reminder)
    local max = 0
    for line in pairs(reminder.texts or {}) do if type(line) == "number" and line > max then max = line end end
    return max
end

local function str(value, maxLen)
    if type(value) ~= "string" then return nil end
    if #value > (maxLen or Reminders.MAX_TEXT) then value = value:sub(1, maxLen or Reminders.MAX_TEXT) end
    return value
end

-- spaces are kept, even trailing ones ("P1 Soak " is a valid keyword), only tabs/newlines go
local function keyword(value)
    value = str(value, 50)
    return value and (value:gsub("[%c]", "")) or ""
end

local function sanitizeSet(source, allowed)
    local set = {}
    if type(source) ~= "table" then return set end
    for k, v in pairs(source) do if v == true and allowed(k) then set[k] = true end end
    return set
end

-- clean copy for imports and migrations, unknown fields dropped. nil, reason if unusable
function Reminders.Sanitize(source)
    if type(source) ~= "table" then return nil, "not a table" end
    if not TYPES[source.type] then return nil, "unknown type" end
    local r = {
        id = (type(source.id) == "string" and #source.id <= 40 and source.id ~= "") and source.id or Reminders.NewID(),
        name = str(source.name, 100) or "",
        enabled = source.enabled ~= false,
        type = source.type,
    }
    if r.type == "group" then
        r.groups = {}
        if type(source.groups) == "table" then
            for i = 1, math.min(#source.groups, Reminders.MAX_GROUP_ENTRIES) do
                local entry = source.groups[i]
                if type(entry) == "table" then
                    r.groups[#r.groups + 1] = {
                        groups = sanitizeSet(entry.groups,
                                             function(k)
                            return type(k) == "number" and k >= 1 and k <= 8 and k % 1 == 0
                        end),
                        text = str(entry.text) or "",
                    }
                end
            end
        end
    else
        if r.type == "keywordLine" then
            r.keyword = keyword(source.keyword)
        else
            r.startKeyword = keyword(source.startKeyword)
            r.endKeyword = keyword(source.endKeyword)
        end
        r.perLine = source.perLine == true
        r.text = str(source.text) or ""
        r.texts = {}
        if type(source.texts) == "table" then
            for line, text in pairs(source.texts) do
                if type(line) == "number" and line >= 1 and line <= Reminders.MAX_LINES and line % 1 == 0 then
                    r.texts[line] = str(text)
                end
            end
        end
    end
    local load = type(source.load) == "table" and source.load or {}
    local LC = ns.LoadConditions
    local classes = sanitizeSet(load.class, function(k) return LC.IsValidClass(k) end)
    r.load = {
        difficulty = sanitizeSet(load.difficulty, function(k) return Reminders.LOAD_KEYS.difficulty[k] end),
        role = sanitizeSet(load.role, function(k) return Reminders.LOAD_KEYS.role[k] end),
        range = sanitizeSet(load.range, function(k) return Reminders.LOAD_KEYS.range[k] end),
        class = classes,
        -- a spec is only kept if its class is selected too
        spec = sanitizeSet(load.spec, function(k) return LC.IsValidSpec(k) and classes[LC.GetSpecClass(k)] == true end),
    }
    return r
end

-- creates the list on first use
function Reminders.GetList(bossKey)
    local all = ns.addon.db.profile.reminders
    all[bossKey] = all[bossKey] or {}
    return all[bossKey]
end

function Reminders.FindIndex(bossKey, id)
    for i, r in ipairs(Reminders.GetList(bossKey)) do if r.id == id then return i end end
    return nil
end

function Reminders.HasEnabled(bossKey)
    for _, r in ipairs(Reminders.GetList(bossKey)) do if r.enabled then return true end end
    return false
end

function Reminders.Move(bossKey, from, to)
    local list = Reminders.GetList(bossKey)
    if from == to or not list[from] then return end
    to = math.max(1, math.min(to, #list))
    local item = table.remove(list, from)
    table.insert(list, to, item)
end
