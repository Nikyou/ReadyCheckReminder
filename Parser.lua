-- note lines + reminders in, display items out.
-- no WoW API in here (roster and nickname lookup get passed in) so tests/ can load it.
local _, ns = ...
ns = ns or {}

local Parser = {}
ns.Parser = Parser

local find, sub, lower, gsub, gmatch, match = string.find, string.sub, string.lower, string.gsub, string.gmatch, string.match
local sort = table.sort

Parser.TYPE_GROUP = "group"
Parser.TYPE_KEYWORD_LINE = "keywordLine"
Parser.TYPE_KEYWORD_GROUP = "keywordGroup"

-- raid marks like {rt2} / {star} are dropped
function Parser.Tokenize(line)
    local tokens = {}
    if not line or line == "" then return tokens end
    line = gsub(line, "{[^}]*}", " ")
    for word in gmatch(line, "[^ \t,;]+") do tokens[#tokens + 1] = word end
    return tokens
end

local function stripColon(word) return (gsub(word, ":$", "")) end

-- keyword with an optional number glued on. returns matched, lineNumber:
-- "soak" gives true, nil / "soak2" gives true, 2 / "grimsoak1" gives false
function Parser.MatchKeyword(word, keyword)
    if not word or not keyword or keyword == "" then return false end
    word = stripColon(word)
    local len = #keyword
    if #word < len or lower(sub(word, 1, len)) ~= lower(keyword) then return false end
    local rest = sub(word, len + 1)
    if rest == "" then return true, nil end
    if find(rest, "^%d+$") then return true, tonumber(rest) end
    return false
end

-- whole word only, for keyword groups
function Parser.IsKeyword(word, keyword)
    if not word or not keyword or keyword == "" then return false end
    return lower(stripColon(word)) == lower(keyword)
end

local function splitName(name)
    local short, realm = match(name, "^([^%-]+)%-(.+)$")
    if short then return short, realm end
    return name, nil
end

-- members: { name = "Name" or "Name-Realm", subgroup = n }. names without a realm get playerRealm.
-- nicknameLookup(token) returns { ["Name-Realm"] = true } or nil; pass nil when nicknames are off.
-- names match case-insensitively
function Parser.NewRoster(members, playerName, playerRealm, nicknameLookup)
    local roster = {byFull = {}, byShort = {}, player = nil, nicknameLookup = nicknameLookup, cache = {}}
    for _, member in ipairs(members or {}) do
        if type(member.name) == "string" and member.name ~= "" then
            local short, realm = splitName(member.name)
            realm = realm or playerRealm
            local entry = {name = short, full = realm and (short .. "-" .. realm) or short, subgroup = member.subgroup}
            entry.isPlayer = lower(short) == lower(playerName or "") and (not playerRealm or lower(realm) == lower(playerRealm))
            if entry.isPlayer then roster.player = entry end
            roster.byFull[lower(entry.full)] = entry
            -- on a short-name clash keep the player, otherwise the first one seen
            local shortKey = lower(short)
            local existing = roster.byShort[shortKey]
            if not existing or (entry.isPlayer and not existing.isPlayer) then roster.byShort[shortKey] = entry end
        end
    end
    return roster
end

local function lookupName(roster, name)
    name = lower(name) -- WoW's string.lower handles Cyrillic etc. too, plain Lua doesn't
    local entry = roster.byFull[name]
    if entry then return entry end
    local short, realm = splitName(name)
    if not realm then return roster.byShort[short] end
    return nil
end

-- the nickname goes to NSRT exactly as written, only the character names it returns
-- are matched case-insensitively

local function resolveNickname(roster, token)
    local chars = roster.nicknameLookup and roster.nicknameLookup(token)
    if type(chars) ~= "table" then return nil end
    local keys = {}
    for key in pairs(chars) do if type(key) == "string" then keys[#keys + 1] = key end end
    sort(keys) -- pairs() order is random, keep results stable
    local first, firstLoose
    for _, key in ipairs(keys) do
        local entry = lookupName(roster, key)
        if entry then
            if entry.isPlayer then return entry end
            first = first or entry
        else
            -- realm written differently or missing, fall back to the short name
            local loose = roster.byShort[lower((splitName(key)))]
            if loose then
                if loose.isPlayer and not first then return loose end
                firstLoose = firstLoose or loose
            end
        end
    end
    return first or firstLoose
end

-- nil for plain words and people not in the group. cached per roster, false = known miss
function Parser.Resolve(roster, token)
    local cached = roster.cache[token]
    if cached ~= nil then return cached or nil end
    local entry = lookupName(roster, token)
    if not entry then entry = resolveNickname(roster, token) end
    roster.cache[token] = entry or false
    return entry
end

-- player's position counting only words that resolve to someone in the group
local function findPlayer(roster, tokens, first)
    local pos = 0
    for i = first, #tokens do
        local entry = Parser.Resolve(roster, tokens[i])
        if entry then
            pos = pos + 1
            if entry.isPlayer then return pos end
        end
    end
    return nil
end

-- "<keyword>[number] names..." lines. matches are { line, hasNumber, pos }
function Parser.FindKeywordLineMatches(keyword, lines, roster)
    local matches = {}
    if not keyword or keyword == "" then return matches end
    for _, line in ipairs(lines) do
        local tokens = Parser.Tokenize(line)
        local ok, number = Parser.MatchKeyword(tokens[1], keyword)
        if ok then
            local pos = findPlayer(roster, tokens, 2)
            if pos then matches[#matches + 1] = {line = number or 1, hasNumber = number ~= nil, pos = pos} end
        end
    end
    return matches
end

-- start keyword, lines of names, end keyword. line numbers restart at 1 in each block and
-- skip empty lines. missing end keyword = block runs to the end of the note
function Parser.FindKeywordGroupMatches(startKeyword, endKeyword, lines, roster)
    local matches = {}
    if not startKeyword or startKeyword == "" or not endKeyword or endKeyword == "" then return matches end
    local inBlock, index = false, 0
    for _, line in ipairs(lines) do
        local tokens = Parser.Tokenize(line)
        if not inBlock then
            if Parser.IsKeyword(tokens[1], startKeyword) then inBlock, index = true, 0 end
        elseif Parser.IsKeyword(tokens[1], endKeyword) then
            inBlock = false
        elseif #tokens > 0 then
            index = index + 1
            local pos = findPlayer(roster, tokens, 1)
            if pos then matches[#matches + 1] = {line = index, hasNumber = true, pos = pos} end
        end
    end
    return matches
end

local function findMatches(reminder, lines, roster)
    if reminder.type == Parser.TYPE_KEYWORD_LINE then
        return Parser.FindKeywordLineMatches(reminder.keyword, lines, roster)
    elseif reminder.type == Parser.TYPE_KEYWORD_GROUP then
        return Parser.FindKeywordGroupMatches(reminder.startKeyword, reminder.endKeyword, lines, roster)
    end
    return {}
end

local function nonEmpty(text) return type(text) == "string" and text ~= "" and text or nil end

local function textForMatch(reminder, m)
    if reminder.perLine and m.hasNumber then return nonEmpty(reminder.texts and reminder.texts[m.line]) end
    return nonEmpty(reminder.text)
end

-- ctx = { mrtLines, nsrtLines, roster }
-- items are { template, vars = { line, pos } or nil }, or { missingLine, reminderName } as a
-- warning when the matched line has no per-line text
function Parser.EvaluateReminder(reminder, ctx)
    local items = {}
    if reminder.type == Parser.TYPE_GROUP then
        local subgroup = ctx.roster.player and ctx.roster.player.subgroup
        if not subgroup then return items end
        for _, entry in ipairs(reminder.groups or {}) do
            if entry.groups and entry.groups[subgroup] then
                local text = nonEmpty(entry.text)
                if text then items[1] = {template = text} end
                break
            end
        end
        return items
    end

    -- MRT wins, NSRT only if MRT has nothing for this reminder
    local matches = findMatches(reminder, ctx.mrtLines or {}, ctx.roster)
    if #matches == 0 then matches = findMatches(reminder, ctx.nsrtLines or {}, ctx.roster) end
    for _, m in ipairs(matches) do
        local text = textForMatch(reminder, m)
        if text then
            items[#items + 1] = {template = text, vars = {line = m.line, pos = m.pos}}
        else
            items[#items + 1] = {missingLine = m.line, reminderName = reminder.name or ""}
        end
    end
    return items
end

-- in settings order. skips disabled ones and anything ctx.filter (load conditions) rejects
function Parser.Evaluate(reminders, ctx)
    local items = {}
    for _, reminder in ipairs(reminders or {}) do
        if reminder.enabled and (not ctx.filter or ctx.filter(reminder)) then
            for _, item in ipairs(Parser.EvaluateReminder(reminder, ctx)) do
                item.reminder = reminder
                items[#items + 1] = item
            end
        end
    end
    return items
end

-- Test runs

local MOCK_FILLER = "-" -- never a player, keeps a block line counted but empty

local function definedLines(reminder)
    local lines = {}
    for line, text in pairs(reminder.texts or {}) do
        if type(line) == "number" and nonEmpty(text) then lines[#lines + 1] = line end
    end
    sort(lines)
    return lines
end

-- fake note with the player on every line that has a text, so a test shows each text once
-- and never trips the missing line warning
function Parser.BuildMockLines(reminder, playerName)
    local lines = {}
    if reminder.type == Parser.TYPE_KEYWORD_LINE then
        local keyword = reminder.keyword
        if not keyword or keyword == "" then return lines end
        if reminder.perLine then
            for _, line in ipairs(definedLines(reminder)) do lines[#lines + 1] = keyword .. line .. " " .. playerName end
            if nonEmpty(reminder.text) then lines[#lines + 1] = keyword .. " " .. playerName end
        elseif nonEmpty(reminder.text) then
            lines[1] = keyword .. "1 " .. playerName
        end
    elseif reminder.type == Parser.TYPE_KEYWORD_GROUP then
        local first, last = reminder.startKeyword, reminder.endKeyword
        if not first or first == "" or not last or last == "" then return lines end
        local body = {}
        if reminder.perLine then
            local defined = {}
            for _, line in ipairs(definedLines(reminder)) do defined[line] = true end
            local max = 0
            for line in pairs(defined) do if line > max then max = line end end
            for line = 1, max do body[line] = defined[line] and playerName or MOCK_FILLER end
        elseif nonEmpty(reminder.text) then
            body[1] = playerName
        end
        if #body > 0 then
            lines[1] = first
            for _, line in ipairs(body) do lines[#lines + 1] = line end
            lines[#lines + 1] = last
        end
    end
    return lines
end

local function withoutWarnings(items)
    local valid = {}
    for _, item in ipairs(items) do if not item.missingLine then valid[#valid + 1] = item end end
    return valid
end

-- real notes first (unless mockOnly), mock note if they give nothing. warnings are dropped
function Parser.EvaluateForTest(reminder, ctx, mockOnly)
    local player = ctx.roster.player
    if not player then return {} end
    local items = {}
    if not mockOnly then items = withoutWarnings(Parser.EvaluateReminder(reminder, ctx)) end
    if #items > 0 then return items end

    if reminder.type == Parser.TYPE_GROUP then
        -- pretend the player is in the first group that has a text
        for _, entry in ipairs(reminder.groups or {}) do
            if nonEmpty(entry.text) and entry.groups and next(entry.groups) then return {{template = entry.text}} end
        end
        return {}
    end
    local mock = {mrtLines = Parser.BuildMockLines(reminder, player.name), nsrtLines = {}, roster = ctx.roster}
    return withoutWarnings(Parser.EvaluateReminder(reminder, mock))
end

-- {line} / {pos} only mean something for keyword types
function Parser.SupportsLineVars(reminderType)
    return reminderType == Parser.TYPE_KEYWORD_LINE or reminderType == Parser.TYPE_KEYWORD_GROUP
end

return Parser
