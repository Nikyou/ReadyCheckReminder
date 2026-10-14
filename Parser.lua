-- note lines + reminders in, display items out.
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

-- keyword, optional number, then colon/space/end of line. "soak" matches "soak2" but not "soakers".
-- keywords keep trailing spaces ("P1 Soak " is valid). returns matched, lineNumber or nil, rest
function Parser.MatchKeywordLine(line, keyword)
    if not line or not keyword or keyword == "" then return false end
    local text = gsub(gsub(line, "{[^}]*}", " "), "^%s+", "")
    local len = #keyword
    if lower(sub(text, 1, len)) ~= lower(keyword) then return false end
    local digits, after = match(sub(text, len + 1), "^(%d*)(.*)$")
    if after ~= "" and not find(after, "^[:%s,;]") then return false end
    return true, tonumber(digits), (gsub(after, "^:", ""))
end

-- start/end lines of a keyword group: the keyword with no number after it
function Parser.IsKeywordLine(line, keyword)
    local matched, number = Parser.MatchKeywordLine(line, keyword)
    return matched and number == nil
end

local function splitName(name)
    local short, realm = match(name, "^([^%-]+)%-(.+)$")
    if short then return short, realm end
    return name, nil
end

-- members = { name, subgroup }, names without a realm get playerRealm. case-insensitive.
-- nicknameLookup(token) -> { ["Name-Realm"] = true } or nil, itself nil when nicknames are off
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

-- nickname goes to NSRT as written, only the names it returns are matched case-insensitively

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
        local ok, number, rest = Parser.MatchKeywordLine(line, keyword)
        if ok then
            local pos = findPlayer(roster, Parser.Tokenize(rest), 1)
            if pos then matches[#matches + 1] = {line = number or 1, hasNumber = number ~= nil, pos = pos} end
        end
    end
    return matches
end

-- start keyword, name lines, end keyword. numbering restarts per block, skips empty lines.
-- no end keyword = runs to the end of the note
function Parser.FindKeywordGroupMatches(startKeyword, endKeyword, lines, roster)
    local matches = {}
    if not startKeyword or startKeyword == "" or not endKeyword or endKeyword == "" then return matches end
    local inBlock, index = false, 0
    for _, line in ipairs(lines) do
        local tokens = Parser.Tokenize(line)
        if not inBlock then
            if Parser.IsKeywordLine(line, startKeyword) then inBlock, index = true, 0 end
        elseif Parser.IsKeywordLine(line, endKeyword) then
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
-- items: { template, vars = { line, pos } or nil }, or { missingLine, reminderName } if the line has no text
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

-- fake note with the player on every line that has a text, so each shows once and no warnings
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
