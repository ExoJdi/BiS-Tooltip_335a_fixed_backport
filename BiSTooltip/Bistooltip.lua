BistooltipAddon = BistooltipAddon or {}
local eventFrame = CreateFrame("Frame", nil, UIParent)
Bistooltip_phases_string = ""

local function specHighlighted(class_name, spec_name)
    return (BistooltipAddon.db.char.highlight_spec.spec_name == spec_name and
               BistooltipAddon.db.char.highlight_spec.class_name == class_name)
end

function BistooltipAddon:RefreshTooltips()
    local tooltips = { GameTooltip, ItemRefTooltip }
    for _, tt in ipairs(tooltips) do
        if tt and tt.IsShown and tt:IsShown() then
            local _, link = tt:GetItem()
            if link then
                tt:SetHyperlink("|cff9d9d9d|Hitem:3299::::::::20:257::::::|h[Fractured Canine]|h|r")
                tt:SetHyperlink(link)
            end
        end
    end
end

local function specFiltered(class_name, spec_name)
    if specHighlighted(class_name, spec_name) then
        return false
    end
    if IsAltKeyDown() then
        return false
    end
    local classFilter = BistooltipAddon.db.char.filter_specs and BistooltipAddon.db.char.filter_specs[class_name]
    if classFilter then
        if classFilter[spec_name] == nil then
            classFilter[spec_name] = true
        end
        return not classFilter[spec_name]
    end
    return false
end

local function classNamesFiltered()
    if BistooltipAddon.db.char.filter_class_names then
        return true
    end
end

local function getFilteredItem(item)
    local filtered_item = {}

    for ki, spec in ipairs(item) do
        local class_name = spec.class_name
        local spec_name = spec.spec_name
        if (not specFiltered(class_name, spec_name)) then
            table.insert(filtered_item, spec)
        end
    end
    return filtered_item
end

local function printSpecLine(tooltip, slot, class_name, spec_name)
    local slot_name = slot.name
    local slot_ranks = slot.ranks
    local prefix = "   "
    if BistooltipAddon.db.char.filter_class_names then
        prefix = ""
    end
    local left_text = prefix .. "|T" .. Bistooltip_spec_icons[class_name][spec_name] .. ":14|t " .. spec_name
    if (slot_name == "Off hand" or slot_name == "Weapon" or slot_name == "Weapon 1h" or slot_name == "Weapon 2h") then
        left_text = left_text .. " (" .. slot_name .. ")"
    end
    tooltip:AddDoubleLine(left_text, slot_ranks, 1, 0.8, 0)
end

local function printClassName(tooltip, class_name)
    tooltip:AddLine(class_name, 1, 0.8, 0)
end

function searchIDInBislistsClassSpec(structure, id, class, spec)
    local paths = {}
    local seen = {}

    local sortedPhases = {}
    for _, phase in ipairs(Bistooltip_wowsims_phases) do
        if structure[class] and structure[class][spec] and structure[class][spec][phase] then
            table.insert(sortedPhases, phase)
        end
    end

    for _, phase in ipairs(sortedPhases) do
        local items = structure[class][spec][phase]

        for index, itemData in pairs(items) do
            if type(itemData) == "table" and itemData[1] then
                for i, itemId in ipairs(itemData) do
                    if i ~= "slot_name" and i ~= "enhs" and itemId == id then
                        local phaseLabel
                        if i == 1 then
                            phaseLabel = phase .. " BIS"
                        else
                            phaseLabel = phase .. " alt " .. i
                        end

                        if not seen[phaseLabel] then
                            table.insert(paths, phaseLabel)
                            seen[phaseLabel] = true
                        end
                    end
                end
            end
        end
    end

    if #paths > 0 then
        return table.concat(paths, " / ")
    else
        return nil
    end
end

local function caseInsensitivePairs(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        return a:lower() < b:lower()
    end)
    local i = 0
    return function()
        i = i + 1
        local k = keys[i]
        if k then
            return k, t[k]
        end
    end
end

local function getStringLength(str)
    return string.len(string.gsub(str, "|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

local DataStore_Inventory = _G.DataStore_Inventory

local function GetItemSource(itemId)
    local source

    local function formatInstanceName(instance)
        local tmpInstance = string.lower(instance)

        if tmpInstance == "the obsidian sanctum (heroic)" then
            instance = "The Obsidian Sanctum(25)"
        elseif tmpInstance == "the eye of eternity (heroic)" then
            instance = "The Eye Of Eternity (25)"
        elseif tmpInstance == "naxxramas (heroic)" then
            instance = "Naxxramas (25)"
        elseif tmpInstance == "ulduar (heroic)" then
            instance = "Ulduar (25)"
        end

        return instance
    end

    for zone, bosses in pairs(lootTable) do
        for boss, items in pairs(bosses) do
            if table.contains(items, itemId) then
                local formattedZone = formatInstanceName(zone)
                source = "|cFFFFFFFFSource:|r |cFF00FF00[" .. formattedZone .. "] - " .. boss .. "|r"
                break
            end
        end
        if source then
            break
        end
    end

    if not source then
        if type(DataStore_Inventory) ~= "table" or type(DataStore_Inventory.GetSource) ~= "function" then
            return nil
        end
        local Instance, Boss = DataStore_Inventory:GetSource(itemId)
        if Instance and Boss then
            local formattedInstance = formatInstanceName(Instance)
            source = "|cFFFFFFFFSource:|r |cFF00FF00[" .. formattedInstance .. "] - " .. Boss .. "|r"
        else
            return nil
        end
    end

    return source
end

local function OnGameTooltipSetItem(tooltip)
    if BistooltipAddon.db.char.tooltip_with_ctrl and not IsControlKeyDown() then
        return
    end

    local _, link = tooltip:GetItem()
    if not link then
        return
    end

    local _, itemId, _, _, _, _, _, _, _, _, _, _, _, _ = strsplit(":", link)
    itemId = tonumber(itemId)

    if not itemId then
        return
    end

    for class, specs in caseInsensitivePairs(Bistooltip_spec_icons) do
        for spec, icon in pairs(specs) do
            if spec ~= "classIcon" then
                if specFiltered(class, spec) then
                else
                local foundPhases = searchIDInBislistsClassSpec(Bistooltip_bislists, itemId, class, spec)

                if foundPhases then
                    local isHighlight = specHighlighted(class, spec)
                    local iconString = string.format("|T%s:18|t", icon)

                    local lineText
                    if classNamesFiltered() then
                        lineText = string.format("%s %s", iconString, spec)
                    else
                        lineText = string.format("%s %s - %s", iconString, class, spec)
                    end

                    if isHighlight then
                        tooltip:AddDoubleLine(lineText, foundPhases, 0, 1, 0, 0, 1, 0)
                    else
                        tooltip:AddDoubleLine(lineText, foundPhases, 1, 1, 0, 1, 1, 0)
                    end
                end
                end
            end
        end
    end

    local itemSource = GetItemSource(itemId)

    if itemSource then
        tooltip:AddLine(" ", 1, 1, 0)
        tooltip:AddLine(itemSource, 1, 1, 1)
        tooltip:AddLine(" ", 1, 1, 0)
    end
end

function BistooltipAddon:initBisTooltip()
    eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
    eventFrame:SetScript("OnEvent", function(_, _, e_key, _, _)
        if GameTooltip:GetOwner() then
            if GameTooltip:GetOwner().hasItem then
                return
            end

            if e_key == "RALT" or e_key == "LALT" then
                local _, link = GameTooltip:GetItem()
                if link then
                    GameTooltip:SetHyperlink("|cff9d9d9d|Hitem:3299::::::::20:257::::::|h[Fractured Canine]|h|r")
                    GameTooltip:SetHyperlink(link)
                end
            end
        end
    end)

    GameTooltip:HookScript("OnTooltipSetItem", OnGameTooltipSetItem)
    ItemRefTooltip:HookScript("OnTooltipSetItem", OnGameTooltipSetItem)
end
