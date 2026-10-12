-- %npc:<id>, %spell:<id>, %line, %pos, and %% for a literal %.
-- Expand/Scan get name lookups passed in so the tests can run them; the in-game lookups are at the bottom.
local _, ns = ...
ns = ns or {}

local Wildcards = {}
ns.Wildcards = Wildcards

local find, sub, format = string.find, string.sub, string.format
local tconcat = table.concat

-- calls handler(kind, id, raw) per wildcard (kind npc/spell/line/pos) and
-- handler("text", nil, s) for plain text in between
local function walk(text, handler)
    local i, n = 1, #text
    while i <= n do
        local s = find(text, "%", i, true)
        if not s then
            handler("text", nil, sub(text, i))
            return
        end
        if s > i then handler("text", nil, sub(text, i, s - 1)) end
        if sub(text, s + 1, s + 1) == "%" then
            -- "%%pos" shows up as a literal "%pos"
            handler("text", nil, "%")
            i = s + 2
        else
            local _, e, id = find(text, "^npc:(%d+)", s + 1)
            local kind
            if e then
                kind = "npc"
            else
                _, e, id = find(text, "^spell:(%d+)", s + 1)
                if e then
                    kind = "spell"
                else
                    for _, name in ipairs({"line", "pos"}) do
                        local last = s + #name
                        if sub(text, s + 1, last) == name and not find(sub(text, last + 1, last + 1), "^[%w_]") then
                            kind, e = name, last
                            break
                        end
                    end
                end
            end
            if kind then
                handler(kind, id and tonumber(id), sub(text, s, e))
                i = e + 1
            else
                handler("text", nil, "%")
                i = s + 1
            end
        end
    end
end

-- vars = { line, pos }, nil for group reminders (then %line/%pos stay as written).
-- lookup = { npc = fn(id), spell = fn(id) }, unknown names show as [npc:123]
function Wildcards.Expand(text, vars, lookup)
    if type(text) ~= "string" or text == "" then return "" end
    local out = {}
    walk(text, function(kind, id, raw)
        if kind == "text" then
            out[#out + 1] = raw
        elseif kind == "line" or kind == "pos" then
            local value = vars and vars[kind]
            out[#out + 1] = value and tostring(value) or raw
        else
            local name = lookup and lookup[kind] and lookup[kind](id)
            out[#out + 1] = (type(name) == "string" and name ~= "") and name or format("[%s:%d]", kind, id)
        end
    end)
    return tconcat(out)
end

-- returns { npc = { [id] = true }, spell = { [id] = true }, line = bool, pos = bool }
function Wildcards.Scan(text)
    local found = {npc = {}, spell = {}, line = false, pos = false}
    if type(text) ~= "string" then return found end
    walk(text, function(kind, id)
        if kind == "npc" or kind == "spell" then
            found[kind][id] = true
        elseif kind == "line" or kind == "pos" then
            found[kind] = true
        end
    end)
    return found
end

-- Name lookups (in-game only)

local pendingSpells = {}
local npcRetries = {}

-- AceDB locale section, wiped on a new client build (see addon:CheckBuild)
local function cacheTable(kind) return ns.addon.db.locale[kind] end

local function usableName(name) return name ~= nil and not issecretvalue(name) and type(name) == "string" and name ~= "" end

local function nameFromTooltip(npcId)
    local data = C_TooltipInfo.GetHyperlink(format("unit:Creature-0-0-0-0-%d-0", npcId))
    if not data or not data.lines then return nil end
    for _, line in ipairs(data.lines) do
        if line.type == Enum.TooltipDataLineType.UnitName then
            local text = line.leftText
            if usableName(text) then return text end
            return nil
        end
    end
    return nil
end

local function nameFromJournal(npcId)
    local sectionID = ns.NpcSections and ns.NpcSections[npcId]
    if not sectionID then return nil end
    local info = C_EncounterJournal.GetSectionInfo(sectionID)
    if info and usableName(info.title) then return info.title end
    return nil
end

-- cache, then journal section, then tooltip. the tooltip is often empty on first ask for an
-- unseen npc, so retry a few times and refresh the display when it shows up. misses aren't cached
function Wildcards.GetNpcName(npcId)
    local cache = cacheTable("npc")
    local name = cache[npcId]
    if usableName(name) then return name end
    name = nameFromJournal(npcId) or nameFromTooltip(npcId)
    if name then
        cache[npcId] = name
        npcRetries[npcId] = nil
        return name
    end
    local tries = npcRetries[npcId] or 0
    if tries < 5 then
        npcRetries[npcId] = tries + 1
        ns.addon:ScheduleTimer(function() if Wildcards.GetNpcName(npcId) then ns.addon:OnNameResolved() end end, 0.5)
    end
    return nil
end

-- spells the client hasn't loaded yet come back through ContinueOnSpellLoad
function Wildcards.GetSpellName(spellId)
    local cache = cacheTable("spell")
    local name = cache[spellId]
    if usableName(name) then return name end
    name = C_Spell.GetSpellName(spellId)
    if not usableName(name) then
        local info = C_Spell.GetSpellInfo(spellId)
        name = info and info.name
    end
    if usableName(name) then
        cache[spellId] = name
        return name
    end
    if not pendingSpells[spellId] and C_Spell.DoesSpellExist(spellId) then
        pendingSpells[spellId] = true
        Spell:CreateFromSpellID(spellId):ContinueOnSpellLoad(function()
            pendingSpells[spellId] = nil
            local loaded = C_Spell.GetSpellName(spellId)
            if usableName(loaded) then
                cacheTable("spell")[spellId] = loaded
                ns.addon:OnNameResolved()
            end
        end)
    end
    return nil
end

Wildcards.Lookup = {
    npc = function(id) return Wildcards.GetNpcName(id) end,
    spell = function(id) return Wildcards.GetSpellName(id) end,
}

-- request names ahead of time so they're cached before the ready check
function Wildcards.Prewarm(reminders)
    for _, reminder in ipairs(reminders or {}) do
        for _, text in ipairs(ns.Reminders.AllTexts(reminder)) do
            local found = Wildcards.Scan(text)
            for id in pairs(found.npc) do Wildcards.GetNpcName(id) end
            for id in pairs(found.spell) do Wildcards.GetSpellName(id) end
        end
    end
end

return Wildcards
