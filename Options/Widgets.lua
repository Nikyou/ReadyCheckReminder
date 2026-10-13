-- small widget helpers for the settings UI. all stock Blizzard templates (same ones the
-- Settings / Edit Mode panels use) plus the Menu system, panels borrow the M33kAuras backdrop.

local _, ns = ...

local Style = {
    ACCENT = { NORMAL_FONT_COLOR:GetRGBA() },            -- gold, titles and selections
    TEXT = { HIGHLIGHT_FONT_COLOR:GetRGBA() },
    MUTED = { GRAY_FONT_COLOR:GetRGBA() },
    WARN = { RED_FONT_COLOR:GetRGBA() },
    SELECTED = { 1, 0.82, 0, 0.25 },                     -- tint for the selected row
    HIGHLIGHT_TEXTURE = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
}
ns.Style = Style

local W = {}
ns.Widgets = W

-- size -> font object: 14+ large gold, 13 gold, 12 white, 11 small white, 10 small grey
local function fontObject(size)
    if size and size >= 14 then return "GameFontNormalLarge" end
    if size == 13 then return "GameFontNormal" end
    if size == 11 then return "GameFontHighlightSmall" end
    if size and size <= 10 then return "GameFontDisableSmall" end
    return "GameFontHighlight"
end

function W.Label(parent, text, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY", fontObject(size))
    if color then label:SetTextColor(unpack(color)) end
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

-- same pane as M33kAuras (AceGUI TabGroup / InlineGroup)
local GROUP_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 5, bottom = 3 },
}

function W.Group(parent)
    local group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    group:SetBackdrop(GROUP_BACKDROP)
    group:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    group:SetBackdropBorderColor(0.4, 0.4, 0.4)
    return group
end

-- same look for the big areas (boss tree, editor, preview, text boxes)
W.Panel = W.Group

function W.Divider(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.15)
    line:SetHeight(1)
    return line
end

-- hover highlight plus a selected tint that stays on, toggled with row:SetRowSelected()
function W.StyleRow(row)
    row:SetHighlightTexture(Style.HIGHLIGHT_TEXTURE, "ADD")
    row.selectedTexture = row:CreateTexture(nil, "BACKGROUND")
    row.selectedTexture:SetAllPoints()
    row.selectedTexture:SetTexture(Style.HIGHLIGHT_TEXTURE)
    row.selectedTexture:SetBlendMode("ADD")
    row.selectedTexture:SetVertexColor(unpack(Style.SELECTED))
    row.selectedTexture:Hide()
    function row:SetRowSelected(selected) self.selectedTexture:SetShown(selected and true or false) end
end

function W.Button(parent, text, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, height or 22)
    button:SetText(text or "")
    button:SetScript("OnClick", function(self, ...) if onClick then onClick(self, ...) end end)
    function button:SetLabel(value) self:SetText(value) end
    function button:FitWidth(padding) self:SetWidth(self:GetTextWidth() + (padding or 24)) end
    return button
end

function W.CheckBox(parent, text, onChange)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(24, 24)
    box.Text:SetFontObject("GameFontHighlight")
    box:SetScript("OnClick", function(self)
        if onChange then onChange(self:GetChecked()) end
    end)
    function box:SetLabel(value)
        self.Text:SetText(value)
        self:SetHitRectInsets(0, -(self.Text:GetStringWidth() + 4), 0, 0)
    end
    -- includes the label, FlowLayout uses this
    function box:GetFullWidth() return 24 + self.Text:GetStringWidth() + 4 end
    box:SetLabel(text or "")
    return box
end

-- icon sits between the box and the label. icon is a path or file ID,
-- texCoords is optional { left, right, top, bottom }
function W.IconCheckBox(parent, text, icon, texCoords, onChange)
    local box = W.CheckBox(parent, text, onChange)
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.icon:SetSize(18, 18)
    box.icon:SetPoint("LEFT", box, "RIGHT", 2, 0)
    box.icon:SetTexture(icon)
    if texCoords then box.icon:SetTexCoord(unpack(texCoords)) end
    box.Text:ClearAllPoints()
    box.Text:SetPoint("LEFT", box.icon, "RIGHT", 4, 0)
    box:SetHitRectInsets(0, -(box.Text:GetStringWidth() + 26), 0, 0)
    return box
end

-- +/- header for collapsible sections
function W.SectionToggle(parent, text, onToggle)
    local header = CreateFrame("Button", nil, parent)
    header:SetSize(220, 20)
    header.toggle = header:CreateTexture(nil, "ARTWORK")
    header.toggle:SetSize(14, 14)
    header.toggle:SetPoint("LEFT")
    header.label = W.Label(header, text, 13)
    header.label:SetPoint("LEFT", header.toggle, "RIGHT", 4, 0)
    header:SetHighlightTexture(Style.HIGHLIGHT_TEXTURE, "ADD")
    header:SetScript("OnClick", function() onToggle() end)
    function header:SetOpen(open)
        self.toggle:SetTexture(open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    end
    function header:SetLabel(value) self.label:SetText(value) end
    header:SetOpen(false)
    return header
end

-- for sets of choices (groups, classes, roles). onClick gets the box, not the checked state
function W.Chip(parent, text, onClick)
    local chip = W.CheckBox(parent, text)
    chip:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
    return chip
end

-- left to right, wraps at maxWidth, skips hidden widgets. returns the height used
function W.FlowLayout(parent, widgets, maxWidth, x0, y0, gap)
    gap = gap or 8
    local x, y, rowHeight = 0, 0, 0
    for _, widget in ipairs(widgets) do
        if widget:IsShown() then
            local w = widget.GetFullWidth and widget:GetFullWidth() or widget:GetWidth()
            local h = widget:GetHeight()
            if x > 0 and x + w > maxWidth then
                x, y = 0, y + rowHeight + 2
                rowHeight = 0
            end
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", parent, "TOPLEFT", (x0 or 0) + x, -((y0 or 0) + y))
            x = x + w + gap
            rowHeight = math.max(rowHeight, h)
        end
    end
    return y + rowHeight
end

-- fill(tooltip) builds the GameTooltip each time the widget is hovered
function W.AddTooltip(widget, fill)
    widget:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        fill(GameTooltip)
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- onChange only fires for user edits, not SetText
function W.EditBox(parent, width, onChange)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(width or 200, 20)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetScript("OnEnterPressed", edit.ClearFocus)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and onChange then onChange(self:GetText()) end
    end)
    return edit
end

-- put stuff in scroll.content. the scroll bar hangs off the right edge, so leave ~20px for it
function W.ScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    scroll:HookScript("OnSizeChanged", function(_, width) content:SetWidth(width) end)
    function scroll:SetContentHeight(height) content:SetHeight(math.max(1, height)) end
    return scroll
end

-- for import/export strings. clicking anywhere on the panel focuses the edit box
function W.MultiLineEditBox(parent)
    local panel = W.Panel(parent)
    local scroll = W.ScrollArea(panel)
    scroll:SetPoint("TOPLEFT", 8, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local edit = CreateFrame("EditBox", nil, scroll.content)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetMultiLine(true)
    edit:SetMaxLetters(0)
    edit:SetPoint("TOPLEFT")
    edit:SetPoint("TOPRIGHT")
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnTextChanged", function(self, userInput)
        scroll:SetContentHeight(self:GetHeight())
        if userInput and self.onUserInput then self.onUserInput(self) end
    end)
    edit:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
    edit:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, scroll) end)
    panel:EnableMouse(true)
    panel:SetScript("OnMouseDown", function() edit:SetFocus() end)
    panel.edit = edit
    return panel
end

-- onChange only fires for user changes, holder:SetValue() is silent
function W.Slider(parent, text, minValue, maxValue, step, width, onChange)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 40)
    holder.label = W.Label(holder, text)
    holder.label:SetPoint("TOPLEFT")

    local slider = CreateFrame("Frame", nil, holder, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("BOTTOMLEFT")
    slider:SetPoint("BOTTOMRIGHT", -40, 0)
    slider:SetHeight(20)
    local formatters = {
        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
            MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return step < 1 and format("%.1f", value) or tostring(math.floor(value + 0.5)) end),
    }
    slider:Init(minValue, minValue, maxValue, (maxValue - minValue) / step, formatters)

    local updating = false
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not updating and onChange then onChange(value) end
    end, holder)

    function holder:SetValue(value)
        updating = true
        slider:SetValue(value)
        updating = false
    end
    holder.slider = slider
    return holder
end

-- Dropdowns and menus

local MENU_SCROLL_EXTENT = 400 -- menu height in px once a list is long enough to scroll

-- Menu font strings refuse SetFont, so each font file gets its own Font object for the preview
-- (same trick as the AceGUI SharedMedia widgets, LSM only gives us file paths)
local previewFonts, previewFontCount = {}, 0
local function previewFont(path)
    local font = previewFonts[path]
    if not font then
        previewFontCount = previewFontCount + 1
        font = CreateFont("ReadyCheckReminderFontPreview" .. previewFontCount) -- CreateFont needs a unique name
        font:CopyFontObject(GameFontHighlight)
        font:SetFont(path, 12, "")
        previewFonts[path] = font
    end
    return font
end

function W.CloseMenu()
    local manager = Menu and Menu.GetManager and Menu.GetManager()
    if manager then manager:CloseMenus() end
end

-- items are { value, text }, onSelect gets the whole item
function W.OpenMenu(anchor, items, _, onSelect)
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        for _, item in ipairs(items) do
            root:CreateButton(item.text, function() onSelect(item) end)
        end
    end)
end

-- getItems() returns { { value, text, font } }, font is optional and previews that font.
-- onSelect(value) only fires on user picks. placeholder shows while nothing is selected
function W.Dropdown(parent, width, getItems, onSelect, placeholder)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width)
    if placeholder then dropdown:SetDefaultText(placeholder) end

    local function isSelected(value) return dropdown.value == value end
    local function setSelected(value)
        dropdown.value = value
        onSelect(value)
    end
    dropdown:SetupMenu(function(_, root)
        local items = getItems()
        for _, item in ipairs(items) do
            local radio = root:CreateRadio(item.text, isSelected, setSelected, item.value)
            if item.font then
                radio:AddInitializer(function(button)
                    button.fontString:SetFontObject(previewFont(item.font))
                end)
            end
        end
        if #items > 20 then root:SetScrollMode(MENU_SCROLL_EXTENT) end
    end)

    function dropdown:SetValue(value)
        self.value = value
        self:GenerateMenu() -- otherwise the button text doesn't update
    end
    return dropdown
end
