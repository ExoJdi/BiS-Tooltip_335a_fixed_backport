BistooltipAddon = BistooltipAddon or {}
local AceGUI = LibStub("AceGUI-3.0")

local class = nil
local spec = nil
local phase = nil
local class_index = nil
local spec_index = nil
local phase_index = nil

local class_options = {}
local class_options_to_class = {}

local spec_options = {}
local spec_options_to_spec = {}
local spec_frame = nil
local items = {}
local spells = {}
local main_frame = nil

local classDropdown = nil
local specDropdown = nil
local phaseDropDown = nil

local checkmarks = {}
local boemarks = {}

local dropdownSyncInProgress = false

local ESC_FRAME_NAME = "BisTooltipMainWindow"

local WOWSIMS_URL = "https://poli93.github.io/wotlk/"

StaticPopupDialogs["BISTOOLTIP_WOWSIMS_LINK"] = {
    text = "WoW Sims Backport - copy the link:",
    button1 = CLOSE,
    hasEditBox = true,
    editBoxWidth = 250,
    OnShow = function(self)
        local eb = _G[self:GetName() .. "EditBox"]
        if eb then
            eb:SetText(WOWSIMS_URL)
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

local function createItemFrame(item_id, size, with_checkmark)
    if not item_id or item_id <= 0 then
        return AceGUI:Create("Label")
    end

    local item_frame = AceGUI:Create("Icon")
    item_frame:SetImageSize(size, size)

    local itemName, itemLink, _, _, _, _, _, _, _, itemIcon, _, itemType, _, bindType = GetItemInfo(item_id)

    if not itemName then
        item_frame:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
        item_frame._bistooltip_itemID = item_id

        item_frame:SetCallback("OnClick", function(button)
            local link = item_frame._bistooltip_itemLink or ("\124cffffffff\124Hitem:" .. item_id .. ":0:0:0:0:0:0:0\124h[item]\124h\124r")
            SetItemRef(link, link, "LeftButton")
        end)
        item_frame:SetCallback("OnEnter", function(widget)
            GameTooltip:SetOwner(item_frame.frame)
            GameTooltip:SetPoint("TOPRIGHT", item_frame.frame, "TOPRIGHT", 220, -13)
            local link = item_frame._bistooltip_itemLink or ("item:" .. item_id .. ":0:0:0:0:0:0:0")
            GameTooltip:SetHyperlink(link)
        end)
        item_frame:SetCallback("OnLeave", function(widget)
            GameTooltip:Hide()
        end)

        if BistooltipAddon and BistooltipAddon.QueueItemFrameUpdate then
            BistooltipAddon:QueueItemFrameUpdate(item_id, item_frame)
        end
        return item_frame
    end

    item_frame:SetImage(itemIcon)
    item_frame._bistooltip_itemLink = itemLink

    if with_checkmark then
        local checkMark = item_frame.frame:CreateTexture(nil, "OVERLAY")
        checkMark:SetWidth(32)
        checkMark:SetHeight(32)
        checkMark:SetPoint("CENTER", 6, -8)
        checkMark:SetTexture("Interface\\AddOns\\Bistooltip\\checkmark-16.tga")
        table.insert(checkmarks, checkMark)
    end

    if bindType == 2 then
        local boeMark = item_frame.frame:CreateTexture(nil, "OVERLAY")
        boeMark:SetWidth(12)
        boeMark:SetHeight(12)
        boeMark:SetPoint("TOPLEFT", 2, -5)
        boeMark:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        table.insert(boemarks, boeMark)
    end

    item_frame:SetCallback("OnClick", function(button)
        SetItemRef(itemLink, itemLink, "LeftButton")
    end)
    item_frame:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(item_frame.frame)
        GameTooltip:SetPoint("TOPRIGHT", item_frame.frame, "TOPRIGHT", 220, -13)
        GameTooltip:SetHyperlink(itemLink)
    end)
    item_frame:SetCallback("OnLeave", function(widget)
        GameTooltip:Hide()
    end)

    return item_frame
end

local function createSpellFrame(spell_id, size)
    if not spell_id or spell_id <= 0 then
        local f = AceGUI:Create("Label")
        return f
    end

    local spell_frame = AceGUI:Create("Icon")
    spell_frame:SetImageSize(size, size)

    local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spell_id)
    if not name or not icon then
        spell_frame:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
        return spell_frame
    end

    spell_frame:SetImage(icon)
    local link = GetSpellLink(spell_id)
    if not link then
        link = "\124cffffd000\124Hspell:" .. spell_id .. "\124h[" .. name .. "]\124h\124r"
    end

    spell_frame:SetCallback("OnClick", function(button)
        SetItemRef(link, link, "LeftButton")
    end)
    spell_frame:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(spell_frame.frame)
        GameTooltip:SetPoint("TOPRIGHT", spell_frame.frame, "TOPRIGHT", 220, -13)
        GameTooltip:SetHyperlink(link)
    end)
    spell_frame:SetCallback("OnLeave", function(widget)
        GameTooltip:Hide()
    end)

    return spell_frame
end

local function createEnhancementsFrame(enhancements)
    local frame = AceGUI:Create("SimpleGroup")
    frame:SetLayout("Table")
    frame:SetWidth(40)
    frame:SetHeight(40)
    frame:SetUserData("table", {
        columns = {{
            weight = 14
        }, {
            width = 14
        }},
        spaceV = -10,
        spaceH = 0,
        align = "BOTTOMRIGHT"
    })
    frame:SetFullWidth(true)
    frame:SetFullHeight(true)
    frame:SetHeight(0)
    frame:SetAutoAdjustHeight(false)
    for i, enhancement in ipairs(enhancements) do
        local size = 16

        if enhancement.type == "none" then
            frame:AddChild(createItemFrame(-1, size))
        end
        if enhancement.type == "item" then
            frame:AddChild(createItemFrame(enhancement.id, size))
        end
        if enhancement.type == "spell" then
            frame:AddChild(createSpellFrame(enhancement.id, size))
        end
    end
    return frame
end

local function drawItemSlot(slot)
    local f = AceGUI:Create("Label")
    f:SetText(slot.slot_name)
    f:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    spec_frame:AddChild(f)
    spec_frame:AddChild(createEnhancementsFrame(slot.enhs))

    for i, item_id in ipairs(slot) do
        if item_id and Bistooltip_char_equipment and Bistooltip_char_equipment[item_id] then
            spec_frame:AddChild(createItemFrame(item_id, 40, true))
        else
            spec_frame:AddChild(createItemFrame(item_id, 40))
        end
    end
end

local function drawTableHeader(frame)
    local f = AceGUI:Create("Label")
    f:SetText("Slot")
    f:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    local color = 0.6
    f:SetColor(color, color, color)
    frame:AddChild(f)
    frame:AddChild(AceGUI:Create("Label"))
    for i = 1, 6 do
        f = AceGUI:Create("Label")
        f:SetText("Top " .. i)
        f:SetColor(color, color, color)
        frame:AddChild(f)
    end
end

local function saveData()
    BistooltipAddon.db.char.class_index = class_index
    BistooltipAddon.db.char.spec_index = spec_index
    BistooltipAddon.db.char.phase_index = phase_index
end

local function clearCheckMarks()
    for key, value in ipairs(checkmarks) do
        value:SetTexture(nil)
    end
    checkmarks = {}
end

local function clearBoeMarks()
    for key, value in ipairs(boemarks) do
        value:SetTexture(nil)
    end
    boemarks = {}
end

local function drawSpecData()
    if not spec_frame then
        return
    end
    clearCheckMarks()
    clearBoeMarks()
    saveData()
    items = {}
    spells = {}
    spec_frame:ReleaseChildren()
    drawTableHeader(spec_frame)
    if not spec or not phase then
        return
    end
    local classTbl = Bistooltip_bislists and Bistooltip_bislists[class]
    local specTbl = classTbl and classTbl[spec]
    local slots = specTbl and specTbl[phase]
    if type(slots) ~= "table" then slots = {} end
    for i, slot in ipairs(slots) do
        drawItemSlot(slot)
    end
end

local function buildClassDict()
    if not Bistooltip_classes or type(Bistooltip_classes) ~= "table" or #Bistooltip_classes == 0 then
        return
    end

    class_options = {}
    for ci, class in ipairs(Bistooltip_classes) do
        local option_name = class.name
        table.insert(class_options, option_name)
        class_options_to_class[option_name] = {
            name = class.name,
            i = ci
        }
    end

    if #class_options > 0 and not class then
        class = class_options_to_class[class_options[1]].name
    end
end

local function buildSpecsDict(class_i)
    if not Bistooltip_classes or type(Bistooltip_classes) ~= "table" then
        return
    end

    spec_options = {}
    spec_options_to_spec = {}
    local class = Bistooltip_classes[class_i]
    for si, spec in ipairs(class.specs) do
        local option_name = "|T" .. Bistooltip_spec_icons[class.name][spec] .. ":14|t " .. spec
        table.insert(spec_options, option_name)
        spec_options_to_spec[option_name] = spec
    end
end


local function loadData()
    class_index = BistooltipAddon.db.char.class_index or 1
    spec_index = BistooltipAddon.db.char.spec_index or 1
    phase_index = BistooltipAddon.db.char.phase_index or 1

    if class_index and class_options and class_options[class_index] then
        local class_option = class_options[class_index]
        if class_options_to_class[class_option] then
            class = class_options_to_class[class_option].name
            buildSpecsDict(class_index)
        end
    end

    if spec_index and spec_options and spec_options[spec_index] then
        spec = spec_options_to_spec[spec_options[spec_index]]
    end

    if phase_index and Bistooltip_phases then
        phase = Bistooltip_phases[phase_index]
    end
end

local function drawDropdowns()
    local dropDownGroup = AceGUI:Create("SimpleGroup")

    dropDownGroup:SetLayout("Table")
    dropDownGroup:SetUserData("table", {
        columns = {
            { weight = 160, alignH = "LEFT" },
            { weight = 160, alignH = "CENTER" },
            { weight = 120, alignH = "RIGHT" }
        },
        space = 10,
        alignV = "middle"
    })
    main_frame:AddChild(dropDownGroup)

    classDropdown = AceGUI:Create("Dropdown")
    specDropdown = AceGUI:Create("Dropdown")
    phaseDropDown = AceGUI:Create("Dropdown")
    specDropdown:SetDisabled(true)

    phaseDropDown:SetCallback("OnValueChanged", function(_, _, key)
        if dropdownSyncInProgress then
            return
        end
        phase_index = key
        phase = Bistooltip_phases[key]
        drawSpecData()
    end)

    specDropdown:SetCallback("OnValueChanged", function(_, _, key)
        if dropdownSyncInProgress then
            return
        end
        spec_index = key
        spec = spec_options_to_spec[spec_options[key]]
        drawSpecData()
    end)

    classDropdown:SetCallback("OnValueChanged", function(_, _, key)
        if dropdownSyncInProgress then
            return
        end
        class_index = key
        class = class_options_to_class[class_options[key]].name

        specDropdown:SetDisabled(false)
        buildSpecsDict(key)
        dropdownSyncInProgress = true
        specDropdown:SetList(spec_options)
        specDropdown:SetValue(1)
        dropdownSyncInProgress = false
        spec_index = 1
        spec = spec_options_to_spec[spec_options[1]]
        drawSpecData()
    end)

    classDropdown:SetList(class_options)
    phaseDropDown:SetList(Bistooltip_phases)

    dropDownGroup:AddChild(classDropdown)
    dropDownGroup:AddChild(specDropdown)
    dropDownGroup:AddChild(phaseDropDown)

    classDropdown:SetWidth(140)
    specDropdown:SetWidth(140)
    phaseDropDown:SetWidth(80)
    dropDownGroup:DoLayout()

    local fillerFrame = AceGUI:Create("Label")
    fillerFrame:SetText(" ")
    main_frame:AddChild(fillerFrame)

    classDropdown:SetValue(class_index)
    if (class_index) then
        buildSpecsDict(class_index)
        specDropdown:SetList(spec_options)
        specDropdown:SetDisabled(false)
    end
    specDropdown:SetValue(spec_index)
    phaseDropDown:SetValue(phase_index)
end

local function createSpecFrame()
    local frame = AceGUI:Create("ScrollFrame")
    frame:SetLayout("Table")
    frame:SetUserData("table", {
        columns = {{
            weight = 40
        }, {
            width = 44
        }, {
            width = 44
        }, {
            width = 44
        }, {
            width = 44
        }, {
            width = 44
        }, {
            width = 44
        }, {
            width = 44
        }},
        space = 1,
        align = "middle"
    })
    frame:SetFullWidth(true)
    frame:SetHeight(380)
    frame:SetAutoAdjustHeight(false)
    main_frame:AddChild(frame)
    spec_frame = frame
end

function BistooltipAddon:reloadData()
    buildClassDict()
    class_index = BistooltipAddon.db.char.class_index or 1
    spec_index = BistooltipAddon.db.char.spec_index or 1
    phase_index = BistooltipAddon.db.char.phase_index or 1

    if class_options and class_options[class_index] and class_options_to_class[class_options[class_index]] then
        class = class_options_to_class[class_options[class_index]].name
        buildSpecsDict(class_index)
    end

    if spec_options and spec_options[spec_index] and spec_options_to_spec[spec_options[spec_index]] then
        spec = spec_options_to_spec[spec_options[spec_index]]
    end

    if Bistooltip_phases and phase_index then
        phase = Bistooltip_phases[phase_index]
    end

    if main_frame then
        if Bistooltip_phases then
            phaseDropDown:SetList(Bistooltip_phases)
        end
        if class_options then
            classDropdown:SetList(class_options)
        end
        if spec_options then
            specDropdown:SetList(spec_options)
        end

        classDropdown:SetValue(class_index)
        specDropdown:SetValue(spec_index)
        phaseDropDown:SetValue(phase_index)

        drawSpecData()
        main_frame:SetStatusText("")
    end
end


local function styleMainFrame()
    if not main_frame or not main_frame.frame then
        return
    end
    local f = main_frame.frame

    for _, child in ipairs({ f:GetChildren() }) do
        if child ~= main_frame.content and child.obj == main_frame
            and child.GetObjectType and child:GetObjectType() == "Button" then
            child:Hide()
        end
    end

    if main_frame.titletext and main_frame.titlebg then
        main_frame.titletext:ClearAllPoints()
        main_frame.titletext:SetPoint("TOP", main_frame.titlebg, "TOP", 0, -19)
        if not f._bistooltip_titleIcon then
            local ic = f:CreateTexture(nil, "OVERLAY")
            ic:SetDrawLayer("OVERLAY", 7)
            ic:SetTexture("Interface\\Icons\\INV_Weapon_Glave_01")
            ic:SetWidth(16)
            ic:SetHeight(16)
            ic:SetPoint("RIGHT", main_frame.titletext, "LEFT", -4, 0)
            f._bistooltip_titleIcon = ic
        end
    end

    if not f._bistooltip_footerGap then
        f._bistooltip_footerGap = CreateFrame("Frame", nil, f)
    end
    if not f._bistooltip_wowsimsBtn then
        local wowsims = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        wowsims:SetText("WoW Sims Backport")
        wowsims:SetHeight(22)
        wowsims:SetWidth(150)
        wowsims:SetScript("OnClick", function()
            StaticPopup_Show("BISTOOLTIP_WOWSIMS_LINK")
        end)
        f._bistooltip_wowsimsBtn = wowsims

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetText(CLOSE)
        closeBtn:SetHeight(22)
        closeBtn:SetWidth(90)
        closeBtn:SetScript("OnClick", function()
            BistooltipAddon:closeMainFrame()
        end)
        f._bistooltip_closeBtn = closeBtn
    end

    local footerGap = f._bistooltip_footerGap
    footerGap:ClearAllPoints()
    if spec_frame and spec_frame.frame then
        footerGap:SetPoint("TOPLEFT", spec_frame.frame, "BOTTOMLEFT", 0, 0)
        footerGap:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    else
        footerGap:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 14)
        footerGap:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 44)
    end

    local wsBtn = f._bistooltip_wowsimsBtn
    local clBtn = f._bistooltip_closeBtn
    local half = (wsBtn:GetWidth() + 20 + clBtn:GetWidth()) / 2
    wsBtn:ClearAllPoints()
    wsBtn:SetPoint("LEFT", footerGap, "CENTER", -half, 0)
    wsBtn:Show()
    clBtn:ClearAllPoints()
    clBtn:SetPoint("RIGHT", footerGap, "CENTER", half, 0)
    clBtn:Show()
end

function BistooltipAddon:createMainFrame()
    if main_frame then
        BistooltipAddon:closeMainFrame()
        return
    end

    main_frame = AceGUI:Create("Frame")
    main_frame:SetWidth(450)
    main_frame:SetHeight(530)

    if main_frame.EnableResize then
        main_frame:EnableResize(false)
    end

    main_frame:SetCallback("OnClose", function(widget)
        BistooltipAddon:closeMainFrame()
    end)

    if main_frame.frame then
        local f = main_frame.frame
        _G[ESC_FRAME_NAME] = f

        local registered = false
        for _, n in ipairs(UISpecialFrames) do
            if n == ESC_FRAME_NAME then
                registered = true
                break
            end
        end
        if not registered then
            table.insert(UISpecialFrames, ESC_FRAME_NAME)
        end

        if not f._bistooltip_escHooked then
            f._bistooltip_escHooked = true
            f:HookScript("OnHide", function()
                if main_frame then
                    BistooltipAddon:closeMainFrame()
                end
            end)
        end
    end

    main_frame:SetLayout("List")
    main_frame:SetTitle(BistooltipAddon.AddonNameAndVersion)
    main_frame:SetStatusText("")

    drawDropdowns()
    createSpecFrame()
    drawSpecData()

    styleMainFrame()
end

function BistooltipAddon:closeMainFrame()
    if main_frame then
        local widget = main_frame
        main_frame = nil
        spec_frame = nil
        classDropdown = nil
        specDropdown = nil
        phaseDropDown = nil
        items = {}
        spells = {}
        clearCheckMarks()
        clearBoeMarks()
        if BistooltipAddon.ClearPendingItemFrames then
            BistooltipAddon:ClearPendingItemFrames()
        end
        if widget.ReleaseChildren then
            widget:ReleaseChildren()
        end
        AceGUI:Release(widget)
    end
end

function BistooltipAddon:initBislists()
    if not Bistooltip_classes or #Bistooltip_classes == 0 then
        Bistooltip_classes = Bistooltip_wowsims_classes
    end

    buildClassDict()
    loadData()
    LibStub("AceConsole-3.0"):RegisterChatCommand("bistooltip", function()
        BistooltipAddon:createMainFrame()
    end, persist)
end
