-- AceDB profile management in the custom UI: switch, create, copy, delete, reset.

local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("ReadyCheckReminder")
local W, Style = ns.Widgets, ns.Style

local controls = {}

local function db() return ns.addon.db end

local function profileItems(excludeCurrent)
    local items = {}
    local current = db():GetCurrentProfile()
    local profiles = db():GetProfiles()
    table.sort(profiles)
    for _, name in ipairs(profiles) do
        if not excludeCurrent or name ~= current then
            items[#items + 1] = { value = name, text = name }
        end
    end
    return items
end

local function create(parent)
    local WIDTH = 300
    local y = 0
    local function title(text)
        local label = W.Label(parent, text, 13, Style.ACCENT)
        label:SetPoint("TOPLEFT", 0, -y)
        y = y + 22
    end
    local function help(text)
        local label = W.Label(parent, text, nil, Style.MUTED)
        label:SetPoint("TOPLEFT", 0, -y)
        label:SetWidth(600)
        y = y + label:GetStringHeight() + 6
    end

    title(L["Current profile"])
    controls.current = W.Dropdown(parent, WIDTH, profileItems, function(value) db():SetProfile(value) end)
    controls.current:SetPoint("TOPLEFT", 0, -y)
    y = y + 44

    title(L["New profile"])
    controls.newName = W.EditBox(parent, WIDTH)
    controls.newName:SetPoint("TOPLEFT", 6, -y)
    local createButton = W.Button(parent, L["Create"], 90, 22, function()
        local name = strtrim(controls.newName:GetText() or "")
        if name ~= "" then
            db():SetProfile(name)
            controls.newName:SetText("")
        end
    end)
    createButton:SetPoint("LEFT", controls.newName, "RIGHT", 6, 0)
    y = y + 44

    title(L["Copy from"])
    help(L["Copies the settings and reminders of another profile into the current one."])
    controls.copy = W.Dropdown(parent, WIDTH, function() return profileItems(true) end, function(value)
        ns.Options:Confirm(format(L["Overwrite the current profile with \"%s\"?"], value), {
            { label = L["Copy"], onClick = function() db():CopyProfile(value) end },
            { label = L["Cancel"] },
        })
        controls.copy:SetValue(nil)
    end, L["Select a profile"])
    controls.copy:SetPoint("TOPLEFT", 0, -y)
    y = y + 44

    title(L["Delete a profile"])
    controls.delete = W.Dropdown(parent, WIDTH, function() return profileItems(true) end, function(value)
        ns.Options:Confirm(format(L["Delete the profile \"%s\"?"], value), {
            { label = L["Delete"], onClick = function()
                db():DeleteProfile(value)
                ns.Options:RefreshActiveTab()
            end },
            { label = L["Cancel"] },
        })
        controls.delete:SetValue(nil)
    end, L["Select a profile"])
    controls.delete:SetPoint("TOPLEFT", 0, -y)
    y = y + 44

    title(L["Reset"])
    local reset = W.Button(parent, L["Reset current profile"], nil, 22, function()
        ns.Options:Confirm(L["Reset the current profile to defaults? Its reminders will be deleted."], {
            { label = L["Reset"], onClick = function() db():ResetProfile() end },
            { label = L["Cancel"] },
        })
    end)
    reset:FitWidth()
    reset:SetPoint("TOPLEFT", 0, -y)
    y = y + 44

    title(L["Share"])
    help(L["Export the current profile's settings and the reminders of the bosses you choose, or import such a string."])
    local export = W.Button(parent, L["Export profile"], nil, 22, function() ns.Options:ShowProfileExport() end)
    export:FitWidth()
    export:SetPoint("TOPLEFT", 0, -y)
    local import = W.Button(parent, L["Import profile"], nil, 22, function() ns.Options:ShowProfileImport() end)
    import:FitWidth()
    import:SetPoint("LEFT", export, "RIGHT", 6, 0)
end

local function refresh()
    controls.current:SetValue(db():GetCurrentProfile())
    controls.copy:SetValue(nil)
    controls.delete:SetValue(nil)
end

table.insert(ns.OptionsTabs, { key = "profiles", label = L["Profiles"], Create = create, Refresh = refresh })
