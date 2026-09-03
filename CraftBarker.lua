--[[
    CraftBarker

    A small Classic addon for advertising a character's professions.
]]

local ADDON_NAME, CraftBarker = ...
_G.CraftBarker = CraftBarker

local OLD_DEFAULT_TEMPLATE = "LFW {profession} {link} - whisper me for crafts."
local DEFAULT_TEMPLATE = "LFW {profession} - whisper me for crafts."
local DEFAULT_CHANNEL = "TRADE"
local CUSTOM_CHANNEL = "CUSTOM"
local MAX_PROFESSION_TABS = 2

local CHANNELS = {
    { id = "TRADE", label = "Trade" },
    { id = "GUILD", label = "Guild" },
    { id = "SAY", label = "Say" },
    { id = "YELL", label = "Yell" },
    { id = "PARTY", label = "Party" },
    { id = "RAID", label = "Raid" },
    { id = CUSTOM_CHANNEL, label = "Custom" },
}

local PRIMARY_PROFESSION_NAMES = {
    ["alchemy"] = true,
    ["blacksmithing"] = true,
    ["enchanting"] = true,
    ["engineering"] = true,
    ["herbalism"] = true,
    ["jewelcrafting"] = true,
    ["leatherworking"] = true,
    ["mining"] = true,
    ["skinning"] = true,
    ["tailoring"] = true,

    -- Localized fallbacks for common German clients.
    ["alchemie"] = true,
    ["schmiedekunst"] = true,
    ["schmieden"] = true,
    ["verzauberkunst"] = true,
    ["verzaubern"] = true,
    ["ingenieurskunst"] = true,
    ["ingenieurwesen"] = true,
    ["kraeuterkunde"] = true,
    ["kuerschnerei"] = true,
    ["lederverarbeitung"] = true,
    ["schneiderei"] = true,
    ["bergbau"] = true,
    ["verhuetten"] = true,
    ["juwelenschleifen"] = true,
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffCraftBarker:|r " .. tostring(message))
end

local function NormalizeName(name)
    if not name then return "" end
    return tostring(name):lower():gsub("ä", "ae"):gsub("ö", "oe"):gsub("ü", "ue"):gsub("ß", "ss")
end

local function Trim(value)
    if not value then return "" end
    return tostring(value):match("^%s*(.-)%s*$") or ""
end

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    elseif atan2 then
        return atan2(y, x)
    elseif x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end
    return 0
end

local function IsPrimaryProfessionName(name)
    return PRIMARY_PROFESSION_NAMES[NormalizeName(name)] == true
end

local function AddProfession(professions, seen, name, skill, maxSkill, icon)
    if not name or name == "" or seen[name] then return end
    if #professions >= MAX_PROFESSION_TABS then return end

    seen[name] = true
    professions[#professions + 1] = {
        name = name,
        skill = skill,
        maxSkill = maxSkill,
        icon = icon,
    }
end

local function GetOpenProfession()
    if GetCraftDisplaySkillLine then
        local name, skill, maxSkill = GetCraftDisplaySkillLine()
        if name and name ~= "" and name ~= "UNKNOWN" then
            return { name = name, skill = skill, maxSkill = maxSkill }
        end
    end

    if GetTradeSkillLine then
        local name, skill, maxSkill = GetTradeSkillLine()
        if name and name ~= "" and name ~= "UNKNOWN" then
            return { name = name, skill = skill, maxSkill = maxSkill }
        end
    end
end

local function EnsureDB()
    if type(CraftBarkerCharDB) ~= "table" then
        CraftBarkerCharDB = {}
    end

    CraftBarkerCharDB.templates = CraftBarkerCharDB.templates or {}
    CraftBarkerCharDB.channel = CraftBarkerCharDB.channel or DEFAULT_CHANNEL
    CraftBarkerCharDB.customChannel = CraftBarkerCharDB.customChannel or "Trade"
    CraftBarkerCharDB.selectedTab = CraftBarkerCharDB.selectedTab or 1
    CraftBarkerCharDB.minimap = CraftBarkerCharDB.minimap or { angle = 225 }

    for professionName, template in pairs(CraftBarkerCharDB.templates) do
        if template == OLD_DEFAULT_TEMPLATE then
            CraftBarkerCharDB.templates[professionName] = DEFAULT_TEMPLATE
        end
    end
end

function CraftBarker:GetCharacterProfessions()
    local professions = {}
    local seen = {}

    if GetProfessions and GetProfessionInfo then
        local prof1, prof2 = GetProfessions()

        if prof1 then
            local name, icon, skill, maxSkill = GetProfessionInfo(prof1)
            AddProfession(professions, seen, name, skill, maxSkill, icon)
        end

        if prof2 then
            local name, icon, skill, maxSkill = GetProfessionInfo(prof2)
            AddProfession(professions, seen, name, skill, maxSkill, icon)
        end
    end

    if #professions < MAX_PROFESSION_TABS and GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
            if not isHeader and IsPrimaryProfessionName(skillName) then
                AddProfession(professions, seen, skillName, skillRank, skillMaxRank)
            end
        end
    end

    local openProfession = GetOpenProfession()
    if openProfession then
        AddProfession(professions, seen, openProfession.name, openProfession.skill, openProfession.maxSkill)
    end

    self.professions = professions
    return professions
end

function CraftBarker:GetProfession(slot)
    if not self.professions then
        self:GetCharacterProfessions()
    end
    return self.professions and self.professions[slot]
end

function CraftBarker:GetActiveSlot()
    EnsureDB()
    local slot = tonumber(CraftBarkerCharDB.selectedTab) or 1
    if slot < 1 or slot > MAX_PROFESSION_TABS then
        slot = 1
    end
    return slot
end

function CraftBarker:SetActiveSlot(slot)
    EnsureDB()
    slot = tonumber(slot) or 1
    if slot < 1 or slot > MAX_PROFESSION_TABS then
        slot = 1
    end
    CraftBarkerCharDB.selectedTab = slot
end

function CraftBarker:GetTemplateKey(slot)
    local profession = self:GetProfession(slot)
    if profession and profession.name and profession.name ~= "" then
        return profession.name
    end
    return "__slot" .. tostring(slot)
end

function CraftBarker:GetTemplate(slot)
    EnsureDB()
    local key = self:GetTemplateKey(slot)
    if not CraftBarkerCharDB.templates[key] then
        CraftBarkerCharDB.templates[key] = DEFAULT_TEMPLATE
    end
    return CraftBarkerCharDB.templates[key]
end

function CraftBarker:SetTemplate(slot, text)
    EnsureDB()
    CraftBarkerCharDB.templates[self:GetTemplateKey(slot)] = text
end

function CraftBarker:BuildMessage(profession, template)
    local message = template or DEFAULT_TEMPLATE
    local professionName = profession and profession.name or ""

    message = message:gsub("{([%a]+)}", function(key)
        if key == "profession" then
            return professionName
        end
        return "{" .. key .. "}"
    end)

    return message
end

local function FindChannelNumber(channelName)
    channelName = Trim(channelName)
    if channelName == "" then return nil end

    local numericChannel = channelName:match("^(%d+)$")
    if numericChannel then
        return tonumber(numericChannel)
    end

    channelName = channelName:lower()

    local channels = { GetChannelList() }
    for i = 1, #channels, 2 do
        local number, name = channels[i], channels[i + 1]
        if type(name) == "string" then
            local lowerName = name:lower()
            if lowerName == channelName or lowerName:find(channelName, 1, true) then
                return number
            end
        end
    end
end

function CraftBarker:GetSelectedChannel()
    EnsureDB()
    return CraftBarkerCharDB.channel or DEFAULT_CHANNEL
end

function CraftBarker:SetSelectedChannel(channelId)
    EnsureDB()
    CraftBarkerCharDB.channel = channelId or DEFAULT_CHANNEL
end

function CraftBarker:SendMessage(message)
    local channel = self:GetSelectedChannel()

    if channel == "TRADE" then
        local tradeNumber = FindChannelNumber("Trade") or FindChannelNumber("Handel")
        if not tradeNumber then
            Print("Trade channel was not found. Join Trade or choose another channel.")
            return
        end
        SendChatMessage(message, "CHANNEL", nil, tradeNumber)
        return
    end

    if channel == CUSTOM_CHANNEL then
        local channelNumber = FindChannelNumber(CraftBarkerCharDB.customChannel)
        if not channelNumber then
            Print("Custom channel was not found.")
            return
        end
        SendChatMessage(message, "CHANNEL", nil, channelNumber)
        return
    end

    SendChatMessage(message, channel)
end

function CraftBarker:CreateWindow()
    if self.window then return self.window end

    local frameTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "CraftBarkerFrame", UIParent, frameTemplate)
    frame:SetSize(430, 345)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    frame:Hide()

    table.insert(UISpecialFrames, "CraftBarkerFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("CraftBarker")

    local titleLine = frame:CreateTexture(nil, "ARTWORK")
    titleLine:SetPoint("TOPLEFT", 22, -39)
    titleLine:SetPoint("TOPRIGHT", -22, -39)
    titleLine:SetHeight(1)
    if titleLine.SetColorTexture then
        titleLine:SetColorTexture(0.55, 0.45, 0.28, 0.9)
    else
        titleLine:SetTexture(0.55, 0.45, 0.28, 0.9)
    end

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)

    frame.tabs = {}
    for slot = 1, MAX_PROFESSION_TABS do
        local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tab:SetSize(178, 24)
        tab:SetPoint("TOPLEFT", 24 + ((slot - 1) * 190), -50)
        tab:SetScript("OnClick", function()
            CraftBarker:SetActiveSlot(slot)
            CraftBarker:LoadActiveTab()
        end)
        frame.tabs[slot] = tab
    end

    local professionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    professionLabel:SetPoint("TOPLEFT", 24, -88)
    professionLabel:SetText("Profession")
    frame.professionLabel = professionLabel

    local professionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    professionText:SetPoint("LEFT", professionLabel, "RIGHT", 10, 0)
    professionText:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
    professionText:SetJustifyH("LEFT")
    frame.professionText = professionText

    local templateLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    templateLabel:SetPoint("TOPLEFT", professionLabel, "BOTTOMLEFT", 0, -22)
    templateLabel:SetText("Template")

    local templateBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    templateBox:SetPoint("TOPLEFT", templateLabel, "BOTTOMLEFT", 4, -8)
    templateBox:SetPoint("RIGHT", frame, "RIGHT", -32, 0)
    templateBox:SetHeight(30)
    templateBox:SetAutoFocus(false)
    templateBox:SetFontObject(ChatFontNormal)
    templateBox:SetScript("OnEscapePressed", templateBox.ClearFocus)
    templateBox:SetScript("OnTextChanged", function()
        if not frame.loadingTemplate then
            CraftBarker:SetTemplate(CraftBarker:GetActiveSlot(), templateBox:GetText())
        end
        CraftBarker:RefreshPreview()
    end)
    frame.templateBox = templateBox

    local helperText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    helperText:SetPoint("TOPLEFT", templateBox, "BOTTOMLEFT", -4, -8)
    helperText:SetText("Placeholder: {profession}. Shift-click items or skills to insert links.")

    local channelLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", helperText, "BOTTOMLEFT", 0, -18)
    channelLabel:SetText("Channel")

    local dropdown = CreateFrame("Frame", "CraftBarkerChannelDropDown", frame, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", channelLabel, "RIGHT", -8, -3)
    frame.channelDropdown = dropdown

    UIDropDownMenu_SetWidth(dropdown, 110)
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        if level ~= 1 then return end
        for _, channel in ipairs(CHANNELS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = channel.label
            info.value = channel.id
            info.checked = CraftBarker:GetSelectedChannel() == channel.id
            info.func = function()
                CraftBarker:SetSelectedChannel(channel.id)
                UIDropDownMenu_SetText(dropdown, channel.label)
                CraftBarker:RefreshChannelControls()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local customBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    customBox:SetPoint("LEFT", dropdown, "RIGHT", 10, 2)
    customBox:SetSize(120, 30)
    customBox:SetAutoFocus(false)
    customBox:SetScript("OnTextChanged", function(self)
        EnsureDB()
        CraftBarkerCharDB.customChannel = self:GetText()
    end)
    frame.customBox = customBox

    local previewLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -25)
    previewLabel:SetText("Preview")

    local previewBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    previewBox:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 4, -8)
    previewBox:SetPoint("RIGHT", frame, "RIGHT", -32, 0)
    previewBox:SetHeight(30)
    previewBox:SetAutoFocus(false)
    previewBox:SetFontObject(ChatFontNormal)
    previewBox:SetScript("OnEscapePressed", previewBox.ClearFocus)
    frame.previewBox = previewBox

    local resetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetButton:SetSize(78, 24)
    resetButton:SetPoint("BOTTOMLEFT", 24, 14)
    resetButton:SetText("Reset")
    resetButton:SetScript("OnClick", function()
        local slot = CraftBarker:GetActiveSlot()
        frame.templateBox:SetText(DEFAULT_TEMPLATE)
        CraftBarker:SetTemplate(slot, DEFAULT_TEMPLATE)
        CraftBarker:RefreshPreview()
    end)

    local sendButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sendButton:SetSize(96, 24)
    sendButton:SetPoint("BOTTOMRIGHT", -24, 14)
    sendButton:SetText("Send")
    sendButton:SetScript("OnClick", function()
        local slot = CraftBarker:GetActiveSlot()
        local profession = CraftBarker:GetProfession(slot)
        if not profession then
            Print("No profession found for this tab.")
            return
        end

        local template = frame.templateBox:GetText()
        CraftBarker:SetTemplate(slot, template)

        local message = CraftBarker:BuildMessage(profession, template)
        if Trim(message) == "" then
            Print("The advertisement is empty.")
            return
        end

        CraftBarker:SendMessage(message)
    end)
    frame.sendButton = sendButton

    self.window = frame
    return frame
end

function CraftBarker:RefreshTabs()
    if not self.window then return end

    local activeSlot = self:GetActiveSlot()
    for slot = 1, MAX_PROFESSION_TABS do
        local tab = self.window.tabs[slot]
        local profession = self:GetProfession(slot)
        tab:SetText(profession and profession.name or ("Profession " .. slot))

        if slot == activeSlot then
            tab:LockHighlight()
        else
            tab:UnlockHighlight()
        end
    end
end

function CraftBarker:RefreshChannelControls()
    if not self.window then return end

    local selected = self:GetSelectedChannel()
    local label = "Trade"
    for _, channel in ipairs(CHANNELS) do
        if channel.id == selected then
            label = channel.label
            break
        end
    end
    UIDropDownMenu_SetText(self.window.channelDropdown, label)

    if selected == CUSTOM_CHANNEL then
        self.window.customBox:Show()
    else
        self.window.customBox:Hide()
    end
end

function CraftBarker:RefreshPreview()
    if not self.window then return end

    local slot = self:GetActiveSlot()
    local profession = self:GetProfession(slot)
    if not profession then
        self.window.professionText:SetText("No profession found for this tab")
        self.window.previewBox:SetText("")
        return
    end

    local skillText = ""
    if profession.skill and profession.maxSkill then
        skillText = " (" .. profession.skill .. "/" .. profession.maxSkill .. ")"
    end

    self.window.professionText:SetText((profession.name or "Unknown") .. skillText)
    self.window.previewBox:SetText(self:BuildMessage(profession, self.window.templateBox:GetText()))
end

function CraftBarker:LoadActiveTab()
    if not self.window then return end

    self:GetCharacterProfessions()
    self:RefreshTabs()

    self.window.loadingTemplate = true
    self.window.templateBox:SetText(self:GetTemplate(self:GetActiveSlot()))
    self.window.loadingTemplate = false

    self:RefreshChannelControls()
    self:RefreshPreview()
end

function CraftBarker:OpenWindow()
    EnsureDB()

    local frame = self:CreateWindow()
    frame.customBox:SetText(CraftBarkerCharDB.customChannel or "Trade")
    self:LoadActiveTab()
    frame:Show()
    frame.templateBox:SetFocus()
end

function CraftBarker:InsertLinkIntoTemplate(link)
    local frame = self.window
    if not link or not frame or not frame:IsShown() or not frame.templateBox then
        return false
    end

    local activeChat = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if activeChat and activeChat:IsShown() and not frame.templateBox:HasFocus() then
        return false
    end

    frame.templateBox:SetFocus()
    frame.templateBox:Insert(link)
    self:RefreshPreview()
    return true
end

function CraftBarker:InstallChatLinkHook()
    if ChatEdit_InsertLink and not self.chatEditInsertLinkHooked then
        self.chatEditInsertLinkHooked = true
        local originalChatEditInsertLink = ChatEdit_InsertLink
        ChatEdit_InsertLink = function(link, ...)
            if CraftBarker:InsertLinkIntoTemplate(link) then
                return true
            end
            return originalChatEditInsertLink(link, ...)
        end
    end

    if HandleModifiedItemClick and not self.modifiedItemClickHooked then
        self.modifiedItemClickHooked = true
        local originalHandleModifiedItemClick = HandleModifiedItemClick
        HandleModifiedItemClick = function(link, ...)
            if IsModifiedClick and IsModifiedClick("CHATLINK") and CraftBarker:InsertLinkIntoTemplate(link) then
                return true
            end
            return originalHandleModifiedItemClick(link, ...)
        end
    end
end

function CraftBarker:UpdateMinimapButtonPosition()
    local button = self.minimapButton
    if not button then return end

    EnsureDB()
    local angle = math.rad(CraftBarkerCharDB.minimap.angle or 225)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function CraftBarker:CreateMinimapButton()
    if self.minimapButton or not Minimap then return end

    EnsureDB()

    local button = CreateFrame("Button", "CraftBarkerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    button.icon = icon

    button:SetScript("OnClick", function()
        CraftBarker:OpenWindow()
    end)
    button:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local centerX, centerY = Minimap:GetCenter()
        local x, y = self:GetCenter()
        if centerX and centerY and x and y then
            CraftBarkerCharDB.minimap.angle = math.deg(Atan2(y - centerY, x - centerX))
            CraftBarker:UpdateMinimapButtonPosition()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("CraftBarker")
        GameTooltip:AddLine("Open the profession advertisement window.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    self.minimapButton = button
    self:UpdateMinimapButtonPosition()
end

function CraftBarker:RegisterSlashCommands()
    SLASH_CRAFTBARKER1 = "/cb"
    SLASH_CRAFTBARKER2 = "/craftbarker"
    SlashCmdList.CRAFTBARKER = function()
        CraftBarker:OpenWindow()
    end
end

function CraftBarker:RefreshOpenWindow()
    if self.window and self.window:IsShown() then
        self:LoadActiveTab()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
eventFrame:RegisterEvent("CRAFT_SHOW")
eventFrame:RegisterEvent("CRAFT_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        EnsureDB()
    elseif event == "PLAYER_LOGIN" then
        CraftBarker:RegisterSlashCommands()
        CraftBarker:InstallChatLinkHook()
        CraftBarker:CreateMinimapButton()
        CraftBarker:GetCharacterProfessions()
    elseif event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" then
        CraftBarker:InstallChatLinkHook()
        CraftBarker:RefreshOpenWindow()
    elseif event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_UPDATE" or event == "CRAFT_UPDATE" then
        CraftBarker:RefreshOpenWindow()
    end
end)
