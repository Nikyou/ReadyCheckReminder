-- {...} text replacements in reminder texts, in the style of TimelineReminders:
--   {spell:<id>} spell icon, {spellname:<id>} spell name, {npc:<id>} npc name,
--   {icon:<id or path>} / {texture:<id or path>}, raid markers ({rt1}, {star}, {ромб}...),
--   English class / spec names and {tank} {healer} {dps} as icons, {line} and {pos}.
-- Expand/Scan get the game lookups passed in so the tests can run them; the in-game ones are at the bottom.
local _, ns = ...
ns = ns or {}

local Wildcards = {}
ns.Wildcards = Wildcards

local format, lower = string.format, string.lower

-- raid marker names in every client language, in {rt1}..{rt8} order
local MARKER_NAMES = {
    { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" },
    { "stern", "kreis", "diamant", "dreieck", "mond", "quadrat", "kreuz", "totenschädel" },
    { "étoile", "cercle", "losange", "triangle", "lune", "carré", "croix", "crâne" },
    { "stella", "cerchio", "rombo", "triangolo", "luna", "quadrato", "croce", "teschio" },
    { "звезда", "круг", "ромб", "треугольник", "полумесяц", "квадрат", "крест", "череп" },
    { "dorado", "naranja", "morado", "verde", "plateado", "azul", "rojo", "blanco" },
    { "dourado", "laranja", "roxo", "verde", "prateado", "azul", "vermelho", "branco" },
}
local markerIndex = {}
for _, names in ipairs(MARKER_NAMES) do
    for index, name in ipairs(names) do markerIndex[lower(name)] = index end
end

local MARKER_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t"

local CLASSES = {
    ["warrior"] = "warrior", ["paladin"] = "paladin", ["hunter"] = "hunter", ["rogue"] = "rogue",
    ["priest"] = "priest", ["death knight"] = "deathknight", ["shaman"] = "shaman", ["mage"] = "mage",
    ["warlock"] = "warlock", ["monk"] = "monk", ["druid"] = "druid", ["demon hunter"] = "demonhunter",
    ["evoker"] = "evoker",
}

local ROLE_ATLAS = {
    tank = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    healer = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    dps = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
}

-- English spec names. {Arms} works on its own, names shared by two classes need the class
-- too ({Frost Mage}, {Holy Priest}); every spec also works as "{Spec Class}"
local SPECS = {
    { 71, "Arms", "Warrior" }, { 72, "Fury", "Warrior" }, { 73, "Protection", "Warrior" },
    { 65, "Holy", "Paladin" }, { 66, "Protection", "Paladin" }, { 70, "Retribution", "Paladin" },
    { 253, "Beast Mastery", "Hunter" }, { 254, "Marksmanship", "Hunter" }, { 255, "Survival", "Hunter" },
    { 259, "Assassination", "Rogue" }, { 260, "Outlaw", "Rogue" }, { 261, "Subtlety", "Rogue" },
    { 256, "Discipline", "Priest" }, { 257, "Holy", "Priest" }, { 258, "Shadow", "Priest" },
    { 250, "Blood", "Death Knight" }, { 251, "Frost", "Death Knight" }, { 252, "Unholy", "Death Knight" },
    { 262, "Elemental", "Shaman" }, { 263, "Enhancement", "Shaman" }, { 264, "Restoration", "Shaman" },
    { 62, "Arcane", "Mage" }, { 63, "Fire", "Mage" }, { 64, "Frost", "Mage" },
    { 265, "Affliction", "Warlock" }, { 266, "Demonology", "Warlock" }, { 267, "Destruction", "Warlock" },
    { 268, "Brewmaster", "Monk" }, { 269, "Windwalker", "Monk" }, { 270, "Mistweaver", "Monk" },
    { 102, "Balance", "Druid" }, { 103, "Feral", "Druid" }, { 104, "Guardian", "Druid" }, { 105, "Restoration", "Druid" },
    { 577, "Havoc", "Demon Hunter" }, { 581, "Vengeance", "Demon Hunter" }, { 1480, "Devourer", "Demon Hunter" },
    { 1467, "Devastation", "Evoker" }, { 1468, "Preservation", "Evoker" }, { 1473, "Augmentation", "Evoker" },
}
local specByName = {}
do
    local count = {}
    for _, spec in ipairs(SPECS) do
        local name = lower(spec[2])
        count[name] = (count[name] or 0) + 1
        specByName[name .. " " .. lower(spec[3])] = spec[1]
    end
    for _, spec in ipairs(SPECS) do
        local name = lower(spec[2])
        if count[name] == 1 then specByName[name] = spec[1] end
    end
end

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local function textureMarkup(texture)
    return format("|T%s:0|t", texture)
end

-- spell icons cropped a little like the default UI does
local function spellIconMarkup(texture)
    return format("|T%s:0:0:0:0:64:64:5:59:5:59|t", texture)
end

-- one {...} token -> replacement, or nil to leave it as written
local function replace(inner, vars, lookup)
    local key, value = inner:match("^(%a+):(.+)$")
    if key then
        key = lower(key)
        local id = tonumber(value)
        if key == "spell" and id then
            local icon = lookup and lookup.spellIcon and lookup.spellIcon(id)
            return spellIconMarkup(icon or QUESTION_MARK)
        elseif key == "spellname" and id then
            local name = lookup and lookup.spell and lookup.spell(id)
            return (type(name) == "string" and name ~= "") and name or format("[spellname:%d]", id)
        elseif key == "npc" and id then
            local name = lookup and lookup.npc and lookup.npc(id)
            return (type(name) == "string" and name ~= "") and name or format("[npc:%d]", id)
        elseif key == "icon" or key == "texture" then
            return textureMarkup(value)
        end
        return nil
    end

    local name = lower(inner)
    if name == "line" or name == "pos" then
        local number = vars and vars[name]
        return number and tostring(number) or nil
    end
    local marker = tonumber(name:match("^rt([1-8])$")) or markerIndex[name]
    if marker then return format(MARKER_ICON, marker) end
    if ROLE_ATLAS[name] then return format("|A:%s:0:0|a", ROLE_ATLAS[name]) end
    if CLASSES[name] then return format("|A:classicon-%s:0:0|a", CLASSES[name]) end
    local specID = specByName[name]
    if specID then
        local icon = lookup and lookup.specIcon and lookup.specIcon(specID)
        return icon and textureMarkup(icon) or nil
    end
    return nil
end

-- vars = { line, pos }, nil for group reminders (then {line}/{pos} stay as written).
-- lookup = { npc, spell, spellIcon, specIcon } functions taking an ID. unknown tokens are left alone
function Wildcards.Expand(text, vars, lookup)
    if type(text) ~= "string" or text == "" then return "" end
    return (text:gsub("{([^{}]+)}", function(inner) return replace(inner, vars, lookup) end))
end

-- returns { npc = { [id] = true }, spell = { [id] = true }, line = bool, pos = bool }
-- spell holds the {spellname:} IDs, the ones that need a name loaded
function Wildcards.Scan(text)
    local found = { npc = {}, spell = {}, line = false, pos = false }
    if type(text) ~= "string" then return found end
    for inner in text:gmatch("{([^{}]+)}") do
        local key, id = inner:match("^(%a+):(%d+)$")
        key = key and lower(key)
        if key == "npc" then
            found.npc[tonumber(id)] = true
        elseif key == "spellname" then
            found.spell[tonumber(id)] = true
        else
            local name = lower(inner)
            if name == "line" or name == "pos" then found[name] = true end
        end
    end
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

local function usableIcon(icon)
    return icon ~= nil and not issecretvalue(icon) and icon ~= 0 and icon or nil
end

Wildcards.Lookup = {
    npc = function(id) return Wildcards.GetNpcName(id) end,
    spell = function(id) return Wildcards.GetSpellName(id) end,
    spellIcon = function(id) return usableIcon(C_Spell.GetSpellTexture(id)) end,
    specIcon = function(id) return usableIcon((select(4, GetSpecializationInfoByID(id)))) end,
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
