-- addon setup, saved variables, events, the ready check itself and slash commands
local ADDON_NAME, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")

local addon = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
ns.addon = addon

local SCHEMA_VERSION = 1

local defaults = {
    profile = {
        display = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 220,
            font = "Friz Quadrata TT",
            fontSize = 22,
            outline = "OUTLINE",
            justify = "CENTER",
            growth = "DOWN", -- DOWN = lines go below the anchor, UP = above
            spacing = 6,
            duration = 15,
            locked = true,
        },
        minimap = {hide = false},
        sharing = {
            onlyTrusted = true, -- leader/assists only
            onlyGuild = true,
            overwrite = false, -- ask before overwriting existing reminders
        },
        reminders = {}, -- [bossKey] = ordered list
    },
    locale = {
        -- name caches, AceDB keeps one per client locale
        npc = {}, -- [npcID] = name
        spell = {}, -- [spellID] = name
    },
    global = {
        build = nil, -- build the name caches were filled on
        scan = {from = 1, to = 25000, chunk = 500},
        ui = {expanded = {}}, -- open tree nodes in the Reminders tab
    },
}

-- 12.x can hand back secret values in combat/restricted states, treat those as missing
local function usable(value) return value ~= nil and not issecretvalue(value) end

-- migrations[n] takes a profile from schema n - 1 to n
local migrations = {
    [1] = function(profile)
        -- first versioned schema, just run everything through Sanitize
        for bossKey, list in pairs(profile.reminders) do
            local clean = {}
            for _, reminder in ipairs(list) do clean[#clean + 1] = ns.Reminders.Sanitize(reminder) end
            profile.reminders[bossKey] = clean
        end
    end,
}

function addon:MigrateProfile()
    local profile = self.db.profile
    local version = profile.schemaVersion or 0
    for target = version + 1, SCHEMA_VERSION do if migrations[target] then migrations[target](profile) end end
    profile.schemaVersion = SCHEMA_VERSION
end

-- npc/spell names can change with any patch, so wipe the caches of all locales on a new build
function addon:CheckBuild()
    local build = select(2, GetBuildInfo())
    local global = self.db.global
    global.cache = nil -- old cache location, before it moved to the locale section
    if global.build == build then return end
    local sv = rawget(self.db, "sv")
    if sv and sv.locale then wipe(sv.locale) end
    rawset(self.db, "locale", nil) -- AceDB rebuilds it from defaults on next access
    global.build = build
end

function addon:OnProfileChanged()
    self:MigrateProfile()
    ns.Display:ApplySettings()
    local icon = LibStub("LibDBIcon-1.0")
    icon:Refresh(ADDON_NAME, self.db.profile.minimap)
    if ns.Options then ns.Options:OnProfileChanged() end
end

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ReadyCheckReminderDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    self:CheckBuild()
    self:MigrateProfile()

    self:RegisterChatCommand("rcr", "OnSlashCommand")
    self:SetupMinimapButton()
    ns.Comms.Init()
end

function addon:OnEnable()
    self:RegisterEvent("READY_CHECK")
    self:RegisterEvent("ENCOUNTER_START")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "PrewarmCurrentInstance")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "PrewarmCurrentInstance")
    ns.Display:ApplySettings()
end

function addon:Print(...) print("|cff4db8ff" .. L["Ready Check Reminder"] .. "|r:", ...) end

local PARTY_UNITS = {"player", "party1", "party2", "party3", "party4"}

-- solo = roster with just the player
function addon:BuildRoster()
    local playerName, playerRealm = UnitFullName("player")
    if not usable(playerName) or not playerName then return nil end
    if not usable(playerRealm) or not playerRealm or playerRealm == "" then playerRealm = GetNormalizedRealmName() end

    local members = {}
    if IsInRaid() then
        local count = GetNumGroupMembers()
        if not usable(count) then count = 0 end
        for index = 1, count do
            local name, _, subgroup = GetRaidRosterInfo(index)
            if usable(name) and name and usable(subgroup) and subgroup then
                members[#members + 1] = {name = name, subgroup = subgroup}
            end
        end
    else
        for _, unit in ipairs(PARTY_UNITS) do
            if UnitExists(unit) then
                local name, realm = UnitFullName(unit)
                if usable(name) and name then
                    if usable(realm) and realm and realm ~= "" then name = name .. "-" .. realm end
                    members[#members + 1] = {name = name, subgroup = 1}
                end
            end
        end
    end
    return ns.Parser.NewRoster(members, playerName, playerRealm, ns.Notes.GetNicknameLookup())
end

function addon:BuildContext(boss)
    local roster = self:BuildRoster()
    if not roster then return nil end
    local Notes = ns.Notes
    local nsrtText = Notes.IsNSRTAvailable() and Notes.GetNSRTText(boss.encounterID) or ""
    return {
        mrtLines = Notes.SplitLines(Notes.Clean(Notes.GetMRTText())),
        nsrtLines = Notes.SplitLines(Notes.Clean(nsrtText)),
        roster = roster,
    }
end

-- returns how many items were shown. opts.ignoreDifficulty is for the test buttons
function addon:RunForBoss(boss, opts)
    local ctx = self:BuildContext(boss)
    if not ctx then return 0 end
    local state = ns.LoadConditions.GetPlayerState()
    ctx.filter = function(reminder) return ns.LoadConditions.Check(reminder, state, opts) end
    local items = ns.Parser.Evaluate(ns.Reminders.GetList(boss.key), ctx)
    if #items > 0 then
        ns.Display:ShowItems(items)
    else
        ns.Display:HideItems()
    end
    return #items
end

function addon:READY_CHECK()
    local boss = ns.Database.FindCurrentBoss()
    if not boss or not ns.Reminders.HasEnabled(boss.key) then return end
    self:RunForBoss(boss)
end

function addon:ENCOUNTER_START() ns.Display:HideItems() end

-- boss Test button: same as a ready check but skips zone and difficulty
function addon:TestBoss(boss)
    if not boss then
        self:Print(L["Select a boss first."])
        return
    end
    if self:RunForBoss(boss, {ignoreDifficulty = true}) == 0 then
        self:Print(format(L["Nothing to show for %s with the current notes."], ns.Database.GetBossName(boss)))
    end
end

-- editor Test: real notes if they match, mock note if not. ignores enabled/load conditions, no warnings
function addon:TestReminder(bossKey, reminder)
    local boss = ns.Database.GetBoss(bossKey or "")
    local ctx = boss and self:BuildContext(boss)
    local items = ctx and ns.Parser.EvaluateForTest(reminder, ctx) or {}
    if #items == 0 then
        self:Print(L["This reminder has no text to show."])
        return
    end
    ns.Display:ShowItems(items)
end

-- Display tab Test: mock notes for one boss (all if bossKey is nil). skips zone/difficulty, second click hides
function addon:TestAll(bossKey)
    if ns.Display:IsShowing("displayTest") then
        ns.Display:HideItems()
        return
    end
    local roster = self:BuildRoster()
    if not roster then return end
    local ctx = {roster = roster} -- mock notes only
    local state = ns.LoadConditions.GetPlayerState()
    local items = {}
    local function addBoss(boss)
        for _, reminder in ipairs(ns.Reminders.GetList(boss.key)) do
            if reminder.enabled and ns.LoadConditions.Check(reminder, state, {ignoreDifficulty = true}) then
                for _, item in ipairs(ns.Parser.EvaluateForTest(reminder, ctx, true)) do items[#items + 1] = item end
            end
        end
    end
    if bossKey then
        local boss = ns.Database.GetBoss(bossKey)
        if boss then addBoss(boss) end
    else
        for _, boss in ns.Database.IterateBosses() do addBoss(boss) end
    end
    if #items == 0 then
        self:Print(L["No loaded reminders to show."])
        return
    end
    ns.Display:ShowItems(items, "displayTest")
end

-- an async npc/spell name came in
function addon:OnNameResolved()
    ns.Display:Refresh()
    if ns.Options then ns.Options:OnNameResolved() end
end

-- ask for npc/spell names early so they're cached by the first ready check
function addon:PrewarmCurrentInstance()
    local instanceID = select(8, GetInstanceInfo())
    if not usable(instanceID) then return end
    local raid = ns.Database.GetRaidByInstanceID(instanceID)
    if not raid then return end
    for _, boss in ipairs(raid.bosses) do ns.Wildcards.Prewarm(ns.Reminders.GetList(boss.key)) end
end

local scanTicker

-- /rcr where: location info, then scan for area IDs named like the subzone. one chunk per frame or the client freezes
function addon:Where(from, to)
    local scan = self.db.global.scan
    if from and to and from >= 1 and to >= from then scan.from, scan.to = from, to end
    local DB = ns.Database
    local instanceID = select(8, GetInstanceInfo())
    local zone, subzone = GetRealZoneText(), DB.GetCurrentSubzone()
    self:Print(format(L["Instance ID: %s"], usable(instanceID) and tostring(instanceID) or "?"))
    self:Print(format(L["Zone: %s"], usable(zone) and zone or "?"))
    self:Print(format(L["Subzone: %s"], subzone or L["(none)"]))
    local boss = DB.FindCurrentBoss()
    self:Print(format(L["Matched boss: %s"], boss and DB.GetBossName(boss) or L["(none)"]))
    if not subzone then return end

    if scanTicker then scanTicker:Cancel() end
    self:Print(format(L["Scanning area IDs %d-%d..."], scan.from, scan.to))
    local nextID, found = scan.from, {}
    scanTicker = C_Timer.NewTicker(0, function(ticker)
        local last = math.min(nextID + scan.chunk - 1, scan.to)
        for areaID = nextID, last do if DB.GetAreaName(areaID) == subzone then found[#found + 1] = areaID end end
        nextID = last + 1
        if nextID > scan.to then
            ticker:Cancel()
            scanTicker = nil
            if #found > 0 then
                self:Print(format(L["Area IDs named \"%s\": %s"], subzone, table.concat(found, ", ")))
            else
                self:Print(format(L["No area ID in %d-%d is named \"%s\"."], scan.from, scan.to, subzone))
            end
        end
    end)
end

function addon:OnSlashCommand(input)
    local command, rest = self:GetArgs(input, 2)
    command = command and command:lower()
    if command == "where" then
        local from, to = self:GetArgs(rest or "", 2)
        self:Where(tonumber(from), tonumber(to))
    elseif command == "reset" then
        ns.Options:ResetPosition()
    elseif command == "help" then
        self:Print(L["/rcr - open the settings"])
        self:Print(L["/rcr reset - move the settings window back to the middle of the screen"])
    else
        ns.Options:Toggle()
    end
end

function addon:SetupMinimapButton()
    local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
        type = "launcher",
        text = L["Ready Check Reminder"],
        icon = 134329,
        OnClick = function() ns.Options:Toggle() end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(L["Ready Check Reminder"])
            tooltip:AddLine(L["Click to open the settings."], 1, 1, 1)
        end,
    })
    LibStub("LibDBIcon-1.0"):Register(ADDON_NAME, launcher, self.db.profile.minimap)
end

function addon:SetMinimapButtonShown(shown)
    self.db.profile.minimap.hide = not shown
    local icon = LibStub("LibDBIcon-1.0")
    if shown then
        icon:Show(ADDON_NAME)
    else
        icon:Hide(ADDON_NAME)
    end
end
