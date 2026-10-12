-- lookups over Data/Raids.lua, journal names, and finding the boss from the subzone
local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")

local DB = {}
ns.Database = DB

local bossByKey, raidByKey, raidByInstanceID = {}, {}, {}
local bossRaid, raidSeason, seasonExpansion = {}, {}, {}
local sections = {} -- [expansion/season/raid key] = { kind = "expansion" | "season" | "raid", node = ... }

for _, expansion in ipairs(ns.Raids) do
    sections[expansion.key] = {kind = "expansion", node = expansion}
    for _, season in ipairs(expansion.seasons) do
        seasonExpansion[season] = expansion
        sections[season.key] = {kind = "season", node = season}
        for _, raid in ipairs(season.raids) do
            raidByKey[raid.key] = raid
            raidSeason[raid] = season
            sections[raid.key] = {kind = "raid", node = raid}
            if raid.instanceID then raidByInstanceID[raid.instanceID] = raid end
            for _, boss in ipairs(raid.bosses) do
                bossByKey[boss.key] = boss
                bossRaid[boss] = raid
            end
        end
    end
end

function DB.GetBoss(key) return bossByKey[key] end
function DB.GetRaid(key) return raidByKey[key] end
function DB.GetRaidByInstanceID(instanceID) return raidByInstanceID[instanceID] end
function DB.GetRaidOfBoss(boss) return bossRaid[boss] end

-- returns expansion, season, raid
function DB.GetPath(boss)
    local raid = bossRaid[boss]
    local season = raidSeason[raid]
    return seasonExpansion[season], season, raid
end

-- bosses under an expansion, season or raid key, in tree order. nil for unknown keys
function DB.GetSectionBosses(key)
    local section = sections[key]
    if not section then return nil end
    local list = {}
    local function addRaid(raid) for _, boss in ipairs(raid.bosses) do list[#list + 1] = boss end end
    local function addSeason(season) for _, raid in ipairs(season.raids) do addRaid(raid) end end
    if section.kind == "raid" then
        addRaid(section.node)
    elseif section.kind == "season" then
        addSeason(section.node)
    else
        for _, season in ipairs(section.node.seasons) do addSeason(season) end
    end
    return list
end

function DB.GetSectionName(key)
    local section = sections[key]
    if not section then return nil end
    if section.kind == "raid" then return DB.GetRaidName(section.node) end
    if section.kind == "season" then return DB.GetSeasonName(section.node) end
    return DB.GetExpansionName(section.node)
end

function DB.IterateBosses()
    local list = {}
    for _, expansion in ipairs(ns.Raids) do
        for _, season in ipairs(expansion.seasons) do
            for _, raid in ipairs(season.raids) do for _, boss in ipairs(raid.bosses) do list[#list + 1] = boss end end
        end
    end
    return ipairs(list)
end

local function usable(value) return value ~= nil and not issecretvalue(value) end

local journalInstanceCache = {}

function DB.GetJournalInstanceID(raid)
    if raid.journalInstanceID then return raid.journalInstanceID end
    if journalInstanceCache[raid] == nil then
        local id = raid.uiMapID and EJ_GetInstanceForMap(raid.uiMapID)
        journalInstanceCache[raid] = (usable(id) and id ~= 0) and id or false
    end
    return journalInstanceCache[raid] or nil
end

local journalEncounterCache = {}

-- not in the data file yet: walk the journal instance and match on dungeonEncounterID
function DB.GetJournalEncounterID(boss)
    if boss.journalEncounterID then return boss.journalEncounterID end
    if journalEncounterCache[boss] == nil then
        journalEncounterCache[boss] = false
        local instanceID = DB.GetJournalInstanceID(bossRaid[boss])
        if instanceID then
            for index = 1, 30 do
                local name, _, journalEncounterID, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(index, instanceID)
                if not usable(name) or not name then break end
                if usable(dungeonEncounterID) and dungeonEncounterID == boss.encounterID then
                    journalEncounterCache[boss] = journalEncounterID
                    break
                end
            end
        end
    end
    return journalEncounterCache[boss] or nil
end

function DB.GetBossName(boss)
    local id = DB.GetJournalEncounterID(boss)
    local name = id and EJ_GetEncounterInfo(id)
    if usable(name) and type(name) == "string" and name ~= "" then return name end
    return format(L["Encounter %d"], boss.encounterID)
end

DB.PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

function DB.GetBossIcon(boss) return boss.icon or DB.PLACEHOLDER_ICON end

function DB.GetRaidName(raid)
    local id = DB.GetJournalInstanceID(raid)
    local name = id and EJ_GetInstanceInfo(id)
    if usable(name) and type(name) == "string" and name ~= "" then return name end
    return format(L["Instance %d"], raid.instanceID or 0)
end

function DB.GetSeasonName(season) return format(L["Season %d"], season.season) end

function DB.GetExpansionName(expansion)
    local name = _G["EXPANSION_NAME" .. expansion.expansionID]
    if type(name) == "string" and name ~= "" then return name end
    return format(L["Expansion %d"], expansion.expansionID)
end

function DB.GetAreaName(areaID)
    local name = C_Map.GetAreaInfo(areaID)
    if usable(name) and type(name) == "string" and name ~= "" then return name end
    return nil
end

-- minimap text first, GetSubZoneText as fallback
function DB.GetCurrentSubzone()
    local text = GetMinimapZoneText()
    if not usable(text) or text == "" then text = GetSubZoneText() end
    if not usable(text) or text == "" then return nil end
    return text
end

-- assumes one subzone per boss. if two bosses ever share a room this needs position or
-- kill state too
function DB.FindBossBySubzone(raid, subzone)
    if not raid or not subzone then return nil end
    for _, boss in ipairs(raid.bosses) do if boss.areaID and DB.GetAreaName(boss.areaID) == subzone then return boss end end
    return nil
end

-- returns boss, raid (boss can be nil while in the raid)
function DB.FindCurrentBoss()
    local instanceID = select(8, GetInstanceInfo())
    if not usable(instanceID) then return nil end
    local raid = raidByInstanceID[instanceID]
    if not raid then return nil end
    return DB.FindBossBySubzone(raid, DB.GetCurrentSubzone()), raid
end
