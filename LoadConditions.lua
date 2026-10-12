-- load conditions. an empty set always passes
local _, ns = ...

local LoadConditions = {}
ns.LoadConditions = LoadConditions

-- difficultyID (3rd return of GetInstanceInfo) to load key. 7 is old LFR, 17 current
local DIFFICULTY = {[7] = "lfr", [17] = "lfr", [14] = "normal", [15] = "heroic", [16] = "mythic"}
LoadConditions.DIFFICULTIES = {"lfr", "normal", "heroic", "mythic"}
LoadConditions.ROLES = {"DAMAGER", "TANK", "HEALER"}
LoadConditions.RANGES = {"melee", "ranged"}

-- hardcoded; Holy Paladin and Mistweaver are melee
local SPEC_RANGE = {
    -- Warrior
    [71] = "melee",
    [72] = "melee",
    [73] = "melee",
    -- Paladin
    [65] = "melee",
    [66] = "melee",
    [70] = "melee",
    -- Hunter (Survival is melee)
    [253] = "ranged",
    [254] = "ranged",
    [255] = "melee",
    -- Rogue
    [259] = "melee",
    [260] = "melee",
    [261] = "melee",
    -- Priest
    [256] = "ranged",
    [257] = "ranged",
    [258] = "ranged",
    -- Death Knight
    [250] = "melee",
    [251] = "melee",
    [252] = "melee",
    -- Shaman
    [262] = "ranged",
    [263] = "melee",
    [264] = "ranged",
    -- Mage
    [62] = "ranged",
    [63] = "ranged",
    [64] = "ranged",
    -- Warlock
    [265] = "ranged",
    [266] = "ranged",
    [267] = "ranged",
    -- Monk
    [268] = "melee",
    [269] = "melee",
    [270] = "melee",
    -- Druid
    [102] = "ranged",
    [103] = "melee",
    [104] = "melee",
    [105] = "ranged",
    -- Demon Hunter (Devourer is ranged)
    [577] = "melee",
    [581] = "melee",
    [1480] = "ranged",
    -- Evoker
    [1467] = "ranged",
    [1468] = "ranged",
    [1473] = "ranged",
}
LoadConditions.SPEC_RANGE = SPEC_RANGE

-- Sanitize drop specs whose class isn't selected
local CLASS_SPECS = {
    DEATHKNIGHT = {250, 251, 252},
    DEMONHUNTER = {577, 581, 1480},
    DRUID = {102, 103, 104, 105},
    EVOKER = {1467, 1468, 1473},
    HUNTER = {253, 254, 255},
    MAGE = {62, 63, 64},
    MONK = {268, 269, 270},
    PALADIN = {65, 66, 70},
    PRIEST = {256, 257, 258},
    ROGUE = {259, 260, 261},
    SHAMAN = {262, 263, 264},
    WARLOCK = {265, 266, 267},
    WARRIOR = {71, 72, 73},
}
local SPEC_CLASS = {}
for classFile, specs in pairs(CLASS_SPECS) do for _, specID in ipairs(specs) do SPEC_CLASS[specID] = classFile end end

function LoadConditions.GetSpecClass(specID) return SPEC_CLASS[specID] end

local function usable(value) return value ~= nil and not issecretvalue(value) end

-- GetSpecializationInfoForClassID is still a global, only the count moved to C_SpecializationInfo
local GetNumSpecsForClass = C_SpecializationInfo.GetNumSpecializationsForClassID
local GetSpecInfoForClass = GetSpecializationInfoForClassID

-- editor order, alphabetical by class file
local CLASS_ORDER = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK",
    "WARRIOR",
}
LoadConditions.CLASS_ORDER = CLASS_ORDER

-- static so validation works before class info is loaded, migrations run that early
local CLASS_FILES = {}
for _, classFile in ipairs(CLASS_ORDER) do CLASS_FILES[classFile] = true end

local classList -- { classFile, name, classID, specs = { { id, name, icon, role } } }, specs in game order

function LoadConditions.GetClasses()
    if classList and #classList > 0 then return classList end
    local byFile = {}
    for classID = 1, GetNumClasses() do
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info and info.classFile then
            local entry = {classFile = info.classFile, name = info.className, classID = classID, specs = {}}
            for index = 1, GetNumSpecsForClass(classID) or 0 do
                local specID, specName, _, icon, role = GetSpecInfoForClass(classID, index)
                if specID then
                    entry.specs[#entry.specs + 1] = {id = specID, name = specName, icon = icon, role = role}
                end
            end
            byFile[info.classFile] = entry
        end
    end
    classList = {}
    for _, classFile in ipairs(CLASS_ORDER) do if byFile[classFile] then classList[#classList + 1] = byFile[classFile] end end
    return classList
end

function LoadConditions.IsValidClass(classFile) return type(classFile) == "string" and CLASS_FILES[classFile] == true end

function LoadConditions.IsValidSpec(specID) return type(specID) == "number" and SPEC_RANGE[specID] ~= nil end

-- fields stay nil when the API gives a secret value, which then fails any non-empty condition
function LoadConditions.GetPlayerState()
    local state = {}
    local _, classFile = UnitClass("player")
    if usable(classFile) then state.class = classFile end
    local specIndex = C_SpecializationInfo.GetSpecialization()
    if usable(specIndex) and specIndex then
        local specID, _, _, _, role = C_SpecializationInfo.GetSpecializationInfo(specIndex)
        if usable(specID) then
            state.spec = specID
            state.range = SPEC_RANGE[specID]
        end
        if usable(role) then state.role = role end
    end
    local _, _, difficultyID = GetInstanceInfo()
    if usable(difficultyID) then state.difficulty = DIFFICULTY[difficultyID] end
    return state
end

local function passes(set, value)
    if type(set) ~= "table" or next(set) == nil then return true end
    return value ~= nil and set[value] == true
end

-- opts.ignoreDifficulty for test runs outside the raid
function LoadConditions.Check(reminder, state, opts)
    local load = reminder.load
    if type(load) ~= "table" then return true end
    if not (opts and opts.ignoreDifficulty) and not passes(load.difficulty, state.difficulty) then return false end
    return passes(load.class, state.class) and passes(load.spec, state.spec) and passes(load.role, state.role)
             and passes(load.range, state.range)
end
