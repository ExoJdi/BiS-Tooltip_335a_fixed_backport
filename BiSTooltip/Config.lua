BistooltipAddon = BistooltipAddon or {}
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)
local icon_loaded = false
local icon_name = "BisTooltipIcon"

Bistooltip_source_to_name = {
    ["wowsims"] = "WoWSims Backport",
    ["wh"] = "Wowhead",
    ["wowtbc"] = "WoWTBC"
}

Bistooltip_source_order = { "wowsims", "wowtbc", "wh" }

Bistooltip_source_to_url = {
    ["wowsims"] = "https://poli93.github.io/wotlk/",
    ["wh"] = "https://www.wowhead.com/wotlk",
    ["wowtbc"] = "https://wowtbc.gg/wotlk"
}

local db_defaults = {
    char = {
        class_index = 1,
        spec_index = 1,
        phase_index = 1,
        filter_specs = {},
        highlight_spec = {},
        data_source = "wowsims",
        minimap_icon = true,
        tooltip_with_ctrl = false
    }
}

local configTable = {
    type = "group",
    args = {
        minimap_icon = {
            name = "Show minimap icon",
            order = 0,
            desc = "Shows/hides minimap icon",
            type = "toggle",
            set = function(info, val)
                BistooltipAddon.db.char.minimap_icon = val
                if val == true then
                    if icon_loaded == true then
                        LDBIcon:Show(icon_name)
                    else
                        BistooltipAddon:addMapIcon()
                    end
                else
                    LDBIcon:Hide(icon_name)
                end
            end,
            get = function(info)
                return BistooltipAddon.db.char.minimap_icon
            end
        },
        filter_class_names = {
            name = "Hide class names",
            order = 1,
            desc = "Removes class name separators from item tooltips",
            type = "toggle",
            set = function(info, val)
                BistooltipAddon.db.char.filter_class_names = val
                if BistooltipAddon.RefreshTooltips then
                    BistooltipAddon:RefreshTooltips()
                end
            end,
            get = function(info)
                return BistooltipAddon.db.char.filter_class_names
            end
        },
        tooltip_with_ctrl = {
            name = "Show item tooltips with Ctrl",
            order = 2,
            desc = "Show item tooltips only when holding Ctrl key",
            type = "toggle",
            width = "double",
            set = function(info, val)
                BistooltipAddon.db.char.tooltip_with_ctrl = val
                if BistooltipAddon.RefreshTooltips then
                    BistooltipAddon:RefreshTooltips()
                end
            end,
            get = function(info)
                return BistooltipAddon.db.char.tooltip_with_ctrl
            end
        },
        data_source = {
            name = "Data source",
            order = 3,
            desc = "Changes bis data source",
            type = "select",
            style = "dropdown",
            width = "double",
            values = Bistooltip_source_to_name,
            sorting = Bistooltip_source_order,
            set = function(info, key, val)
                BistooltipAddon.db.char.data_source = key
                BistooltipAddon:changeSpec(key)
            end,
            get = function(info, key)
                return BistooltipAddon.db.char.data_source
            end
        },
        filter_specs = {
            name = "Hide specs",
            order = 4,
            desc = "Removes unselected specs from item tooltips",
            type = "multiselect",
            values = {},
            set = function(info, key, val)
                local ci, si = strsplit(":", key)
                ci = tonumber(ci)
                si = tonumber(si)
                local class_name = Bistooltip_classes[ci].name
                local spec_name = Bistooltip_classes[ci].specs[si]
                if not BistooltipAddon.db.char.filter_specs[class_name] then
                    BistooltipAddon.db.char.filter_specs[class_name] = {}
                end
                BistooltipAddon.db.char.filter_specs[class_name][spec_name] = val
                if BistooltipAddon.RefreshTooltips then
                    BistooltipAddon:RefreshTooltips()
                end
            end,
            get = function(info, key)
                local ci, si = strsplit(":", key)
                ci = tonumber(ci)
                si = tonumber(si)
                local class_name = Bistooltip_classes[ci].name
                local spec_name = Bistooltip_classes[ci].specs[si]
                if not BistooltipAddon.db.char.filter_specs[class_name] then
                    BistooltipAddon.db.char.filter_specs[class_name] = {}
                end
                if BistooltipAddon.db.char.filter_specs[class_name][spec_name] == nil then
                    BistooltipAddon.db.char.filter_specs[class_name][spec_name] = true
                end
                return BistooltipAddon.db.char.filter_specs[class_name][spec_name]
            end
        },
        highlight_spec = {
            name = "Highlight spec",
            order = 5,
            desc = "Highlights selected spec in item tooltips",
            type = "multiselect",
            values = {},
            set = function(info, key, val)
                if val then
                    local ci, si = strsplit(":", key)
                    ci = tonumber(ci)
                    si = tonumber(si)
                    local class_name = Bistooltip_classes[ci].name
                    local spec_name = Bistooltip_classes[ci].specs[si]
                    BistooltipAddon.db.char.highlight_spec = {
                        key = key,
                        class_name = class_name,
                        spec_name = spec_name
                    }
                else
                    BistooltipAddon.db.char.highlight_spec = {}
                end

                if BistooltipAddon.RefreshTooltips then
                    BistooltipAddon:RefreshTooltips()
                end

            end,
            get = function(info, key)
                return BistooltipAddon.db.char.highlight_spec.key == key
            end
        }
    }
}

local function buildFilterSpecOptions()
    if type(Bistooltip_classes) ~= "table" then
        return
    end
    local filter_specs_options = {}
    for ci, class in ipairs(Bistooltip_classes) do
        for si, spec in ipairs(class.specs) do
            local option_val = "|T" .. Bistooltip_spec_icons[class.name][spec] .. ":16|t " .. class.name .. " " .. spec
            local option_key = ci .. ":" .. si
            filter_specs_options[option_key] = option_val
        end
    end
    configTable.args.filter_specs.values = filter_specs_options
    configTable.args.highlight_spec.values = filter_specs_options
end

local function openSourceSelectDialog()
    local frame = AceGUI:Create("Window")
    frame:SetWidth(300)
    frame:SetHeight(150)
    frame:EnableResize(false)
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        frame = nil
    end)
    frame:SetLayout("List")
    frame:SetTitle(BistooltipAddon.AddonNameAndVersion)

    local labelEmpty = AceGUI:Create("Label")
    labelEmpty:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    labelEmpty:SetText(" ")
    frame:AddChild(labelEmpty)

    local label = AceGUI:Create("Label")
    label:SetText("Please select a bis data source to be used for this addon:")
    label:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    label:SetRelativeWidth(1)
    frame:AddChild(label)

    local labelEmpty2 = AceGUI:Create("Label")
    labelEmpty2:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    labelEmpty2:SetText(" ")
    frame:AddChild(labelEmpty2)

    local sourceDropdown = AceGUI:Create("Dropdown")
    sourceDropdown:SetCallback("OnValueChanged", function(_, _, key)
        BistooltipAddon.db.char.data_source = key
        BistooltipAddon:changeSpec(key)
    end)
    sourceDropdown:SetRelativeWidth(1)
    sourceDropdown:SetList(Bistooltip_source_to_url)
    sourceDropdown:SetValue(BistooltipAddon.db.char["data_source"])
    frame:AddChild(sourceDropdown)
end

local function migrateAddonDB()
    if not BistooltipAddon.db.char.version then
        BistooltipAddon.db.char.version = 6.1
        BistooltipAddon.db.char.highlight_spec = {}
        BistooltipAddon.db.char.filter_specs = {}
        BistooltipAddon.db.char.class_index = 1
        BistooltipAddon.db.char.spec_index = 1
        BistooltipAddon.db.char.phase_index = 1
    end

    if BistooltipAddon.db.char.data_source == nil then
        BistooltipAddon.db.char.data_source = "wowsims"
    end

    if BistooltipAddon.db.char.version == 6.1 then
        BistooltipAddon.db.char.version = 6.2
        if BistooltipAddon.db.char.filter_specs["Death knight"] and
            BistooltipAddon.db.char.filter_specs["Death knight"]["Blood dps"] == nil then
            BistooltipAddon.db.char.filter_specs["Death knight"]["Blood dps"] = true
        end
    end
end

local config_shown = false
function BistooltipAddon:openConfigDialog()
    if config_shown then
        InterfaceOptionsFrame_Show()
    else
        InterfaceOptionsFrame_OpenToCategory(BistooltipAddon.AceAddonName)
    end
    config_shown = not config_shown
end

local function buildFallback()
    if type(Bistooltip_wowsims_bislists) ~= "table" then
        Bistooltip_wowsims_bislists = {}
    end
    return Bistooltip_wowsims_bislists
end

local function isRealId(id)
    return id and id > 0
end

local function itemFaction(id)
    if type(Bistooltip_item_faction) == "table" then
        return Bistooltip_item_faction[id]
    end
    return nil
end

local function buildMirrorToMine(pf)
    local m = {}
    if type(Bistooltip_horde_to_ali) == "table" then
        for a, b in pairs(Bistooltip_horde_to_ali) do
            local fa = itemFaction(a)
            local fb = itemFaction(b)
            if fa == pf and fb and fb ~= pf then
                m[b] = a
            elseif fb == pf and fa and fa ~= pf then
                m[a] = b
            end
        end
    end
    return m
end

local function resolveId(id, mirror, pf)
    if mirror[id] then
        id = mirror[id]
    end
    if not isRealId(id) then
        return nil
    end
    local fr = itemFaction(id)
    if fr and pf and fr ~= pf then
        return nil
    end
    return id
end

local function groupWowsimsByName(wsSlots)
    local g = {}
    for _, s in ipairs(wsSlots) do
        local n = s.slot_name
        g[n] = g[n] or {}
        g[n][#g[n] + 1] = s
    end
    return g
end

local function packSlot(slot_name, enhs, result)
    local merged = { slot_name = slot_name, enhs = enhs }
    for col = 1, 6 do
        merged[col] = result[col] or -1
    end
    return merged
end

local function mergeSlot(oldSlot, wsList, mirror, pf)
    local result = {}
    local seen = {}
    local function add(id)
        id = resolveId(id, mirror, pf)
        if id and not seen[id] and #result < 6 then
            seen[id] = true
            result[#result + 1] = id
        end
    end
    if wsList then
        for j = 1, #wsList do
            add(wsList[j][1])
        end
    end
    for col = 1, 6 do
        add(oldSlot[col])
    end
    return packSlot(oldSlot.slot_name, oldSlot.enhs, result)
end

local function translateSlots(slots, mirror, pf)
    if type(slots) ~= "table" then return slots end
    local out = {}
    for i, slot in ipairs(slots) do
        local result = {}
        local seen = {}
        for col = 1, 6 do
            local id = resolveId(slot[col], mirror, pf)
            if id and not seen[id] then
                seen[id] = true
                result[#result + 1] = id
            end
        end
        out[i] = packSlot(slot.slot_name, slot.enhs, result)
    end
    return out
end

local function mergeSpecPhase(wsSlots, oldSlots, mirror, pf)
    if type(oldSlots) ~= "table" then
        return translateSlots(wsSlots, mirror, pf)
    end
    local g = (type(wsSlots) == "table") and groupWowsimsByName(wsSlots) or nil
    local out = {}
    for i, oldSlot in ipairs(oldSlots) do
        local wsList = nil
        if g then
            local name = oldSlot.slot_name
            wsList = g[name]
            if not wsList and (name == "Ranged" or name == "Relic") then
                wsList = g["Relic"]
            end
        end
        out[i] = mergeSlot(oldSlot, wsList, mirror, pf)
    end
    return out
end

local function assembleActiveBislists()
    local isHorde = (UnitFactionGroup("player") == "Horde")
    local pf = isHorde and 2 or 1
    local primary = isHorde and Bistooltip_bislists_horde or Bistooltip_bislists_alliance
    local fallback = buildFallback()
    local mirror = buildMirrorToMine(pf)

    local active = {}

    if type(fallback) == "table" then
        for className, specs in pairs(fallback) do
            active[className] = active[className] or {}
            local wsClass = primary and primary[className]
            for specName, phases in pairs(specs) do
                active[className][specName] = active[className][specName] or {}
                local wsSpec = wsClass and wsClass[specName]
                for phaseName, oldSlots in pairs(phases) do
                    local wsSlots = wsSpec and wsSpec[phaseName]
                    active[className][specName][phaseName] = mergeSpecPhase(wsSlots, oldSlots, mirror, pf)
                end
            end
        end
    end

    if type(primary) == "table" then
        for className, specs in pairs(primary) do
            active[className] = active[className] or {}
            for specName, phases in pairs(specs) do
                active[className][specName] = active[className][specName] or {}
                for phaseName, wsSlots in pairs(phases) do
                    if active[className][specName][phaseName] == nil then
                        active[className][specName][phaseName] = translateSlots(wsSlots, mirror, pf)
                    end
                end
            end
        end
    end

    Bistooltip_bislists = active
end

local function enableSpec(spec_name)
    if spec_name == "wh" then
        Bistooltip_classes = Bistooltip_wh_classes
        Bistooltip_phases = Bistooltip_wh_phases
        Bistooltip_bislists = Bistooltip_wh_bislists
    elseif spec_name == "wowtbc" then
        Bistooltip_classes = Bistooltip_wowtbc_classes
        Bistooltip_phases = Bistooltip_wowtbc_phases
        Bistooltip_bislists = Bistooltip_wowtbc_bislists
    else
        Bistooltip_classes = Bistooltip_wowsims_classes
        Bistooltip_phases = Bistooltip_wowsims_phases
        assembleActiveBislists()
    end

    if type(Bistooltip_phases) ~= "table" then
        return
    end

    Bistooltip_phases_string = ""
    for i, phase in ipairs(Bistooltip_phases) do
        if i ~= 1 then
            Bistooltip_phases_string = Bistooltip_phases_string .. "/"
        end
        Bistooltip_phases_string = Bistooltip_phases_string .. phase
    end

    buildFilterSpecOptions()
end

function BistooltipAddon:addMapIcon()
    if BistooltipAddon.db.char.minimap_icon then
        icon_loaded = true
        local LDB = LibStub("LibDataBroker-1.1", true)
        local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)
        if LDB then
            local PC_MinimapBtn = LDB:NewDataObject(icon_name, {
                type = "launcher",
                text = icon_name,
                icon = "interface/icons/inv_weapon_glave_01.blp",
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        BistooltipAddon:createMainFrame()
                    end
                    if button == "RightButton" then
                        BistooltipAddon:openConfigDialog()
                    end
                end,
                OnTooltipShow = function(tt)
                    tt:AddLine(BistooltipAddon.AddonNameAndVersion)
                    tt:AddLine("|cffffff00Left click|r to open the BiS lists window")
                    tt:AddLine("|cffffff00Right click|r to open addon configuration window")
                end
            })
            if LDBIcon then
                LDBIcon:Register(icon_name, PC_MinimapBtn, BistooltipAddon.db.char)
            end
        end
    end
end

function BistooltipAddon:changeSpec(spec_name)
    BistooltipAddon.db.char.data_source = spec_name
    enableSpec(spec_name)
    BistooltipAddon:initBislists()
    BistooltipAddon:reloadData()
end

function BistooltipAddon:initConfig()
    BistooltipAddon.db = LibStub("AceDB-3.0"):New("BisTooltipDB", db_defaults, "Default")

    migrateAddonDB()

    enableSpec(BistooltipAddon.db.char.data_source or "wowsims")

    buildFilterSpecOptions()

    LibStub("AceConfig-3.0"):RegisterOptionsTable(BistooltipAddon.AceAddonName, configTable)
    AceConfigDialog:AddToBlizOptions(BistooltipAddon.AceAddonName, BistooltipAddon.AceAddonName)
end
