-- MRT/NSRT note reading and cleanup
local _, ns = ...
ns = ns or {}

local Notes = {}
ns.Notes = Notes

local gsub, gmatch, match = string.gsub, string.gmatch, string.match
local tconcat = table.concat

-- "|?|" so these also catch the escaped "||c" form MRT sometimes saves
local STRIP_PATTERNS = {
    {"|?|[Tt].-|?|t", ""}, -- |T...|t textures
    {"|?|H.-|?|h(.-)|?|h", "%1"}, -- hyperlinks, keep the visible text
    {"|?|[cC]%x%x%x%x%x%x%x%x", ""}, -- |cAARRGGBB
    {"|?|[cC][nN][%w_]+:", ""}, -- |cnCOLOUR_NAME:
    {"|?|[rR]", ""}, -- |r
}

-- strips formatting and squashes whitespace. case is left alone
function Notes.Clean(text)
    if type(text) ~= "string" or text == "" then return "" end
    text = gsub(text, "\r\n", "\n")
    text = gsub(text, "\r", "\n")
    for i = 1, #STRIP_PATTERNS do text = gsub(text, STRIP_PATTERNS[i][1], STRIP_PATTERNS[i][2]) end
    local out = {}
    for line in gmatch(text .. "\n", "(.-)\n") do
        line = gsub(line, "[ \t]+", " ")
        out[#out + 1] = match(line, "^ ?(.-) ?$")
    end
    -- the extra "\n" above doesn't add a line, so an existing trailing newline survives
    return tconcat(out, "\n")
end

-- keeps empty lines
function Notes.SplitLines(text)
    local lines = {}
    if type(text) ~= "string" or text == "" then return lines end
    for line in gmatch(text .. "\n", "(.-)\n") do lines[#lines + 1] = line end
    return lines
end

function Notes.Join(first, second)
    local a = type(first) == "string" and first ~= "" and first or nil
    local b = type(second) == "string" and second ~= "" and second or nil
    if a and b then return a .. "\n" .. b end
    return a or b or ""
end

-- Readers (in-game only)

local function safeString(value)
    if value == nil or issecretvalue(value) or type(value) ~= "string" then return nil end
    return value
end

-- shared note first, then personal
function Notes.GetMRTText()
    local note = VMRT and VMRT.Note
    if type(note) ~= "table" then return "" end
    return Notes.Join(safeString(note.Text1), safeString(note.SelfText))
end

function Notes.IsNSRTAvailable() return C_AddOns.IsAddOnLoaded("NorthernSkyRaidTools") and type(NSAPI) == "table" or false end

-- shared note, then the personal note for this encounter. GetReminderString returns personal first
function Notes.GetNSRTText(encounterID)
    if not Notes.IsNSRTAvailable() or type(NSAPI.GetReminderString) ~= "function" then return "" end
    local ok, personal, shared = pcall(NSAPI.GetReminderString, NSAPI, encounterID)
    if not ok then return "" end
    return Notes.Join(safeString(shared), safeString(personal))
end

-- NSRT has no API for its global nicknames toggle, so peek at its saved variable (read only)
function Notes.AreNicknamesEnabled()
    if not Notes.IsNSRTAvailable() then return false end
    local settings = NSRT and NSRT.Settings
    return type(settings) == "table" and settings["GlobalNickNames"] and true or false
end

-- nil when nicknames are off. the lookup gives { ["Name-Realm"] = ... } or nil
function Notes.GetNicknameLookup()
    if not Notes.AreNicknamesEnabled() or type(NSAPI.GetCharacters) ~= "function" then return nil end
    return function(token)
        local ok, chars = pcall(NSAPI.GetCharacters, NSAPI, token)
        if ok and type(chars) == "table" then return chars end
        return nil
    end
end

return Notes
