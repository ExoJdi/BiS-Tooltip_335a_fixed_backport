BistooltipAddon = BistooltipAddon or LibStub("AceAddon-3.0"):NewAddon("Bis-Tooltip")

Bistooltip_char_equipment = {}

local _pendingItemFrames = {}
local _pendingPollFrame
local _pendingPollElapsed = 0

local function _Bistooltip_ProcessPendingItemFrames()
    for itemID, widgets in pairs(_pendingItemFrames) do
        local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
        if itemName and itemIcon then
            for _, w in ipairs(widgets) do
                if w and w.SetImage then
                    w:SetImage(itemIcon)
                    if itemLink then
                        w._bistooltip_itemLink = itemLink
                    end
                end
            end
            _pendingItemFrames[itemID] = nil
        else
            -- Re-trigger query
            GetItemInfo(itemID)
        end
    end

    if not next(_pendingItemFrames) and _pendingPollFrame then
        _pendingPollFrame:SetScript("OnUpdate", nil)
    end
end

function BistooltipAddon:QueueItemFrameUpdate(itemID, aceIconWidget)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 or not aceIconWidget then return end
    if not aceIconWidget.frame then return end

    local bucket = _pendingItemFrames[itemID]
    if not bucket then
        bucket = {}
        _pendingItemFrames[itemID] = bucket
    end
    bucket[#bucket + 1] = aceIconWidget

    -- Trigger query attempt
    GetItemInfo(itemID)

    if not _pendingPollFrame then
        _pendingPollFrame = CreateFrame("Frame")
    end
    if not _pendingPollFrame:GetScript("OnUpdate") then
        _pendingPollElapsed = 0
        _pendingPollFrame:SetScript("OnUpdate", function(_, elapsed)
            _pendingPollElapsed = _pendingPollElapsed + elapsed
            if _pendingPollElapsed >= 0.25 then
                _pendingPollElapsed = 0
                _Bistooltip_ProcessPendingItemFrames()
            end
        end)
    end
end

function BistooltipAddon:ClearPendingItemFrames()
    -- Drop references to AceGUI Icon widgets so Lua GC can collect them
    for k in pairs(_pendingItemFrames) do
        _pendingItemFrames[k] = nil
    end
    if _pendingPollFrame then
        _pendingPollFrame:SetScript("OnUpdate", nil)
    end
end

local function collectItemIDs(bislists)
    local itemIDs = {}

    for _, classData in pairs(bislists) do
        for _, specData in pairs(classData) do
            for _, phaseData in pairs(specData) do
                for _, itemData in ipairs(phaseData) do
                    for key, value in pairs(itemData) do
                        if type(key) == "number" then
                            table.insert(itemIDs, value)
                        elseif key == "enhs" then
                            for _, enhData in pairs(value) do
                                if enhData.type == "item" and enhData.id then
                                    table.insert(itemIDs, enhData.id)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return itemIDs
end

local function createEquipmentWatcher()
    local frame = CreateFrame("Frame")
    frame:Hide()

    frame:RegisterEvent("BAG_UPDATE")

    local updatePending = false
    local delay = 0.35
    local acc = 0

    local bisItemIDs -- cached list of BiS itemIDs
    local bisIndex = 1
    local bisChunk = 200
    local scanningBis = false

    local function ensureBisItemIDs()
        if not bisItemIDs then
            bisItemIDs = collectItemIDs(Bistooltip_bislists)
        end
    end

    local function scanBagsAndEquipped(collection)
        for bag = 0, NUM_BAG_SLOTS do
            local numSlots = GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local itemID = tonumber(string.match(itemLink, "item:(%d+):"))
                    if itemID then
                        collection[itemID] = 1
                    end
                end
            end
        end

        -- Bank bags (not main bank slots)
        for bankBag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
            local numSlots = GetContainerNumSlots(bankBag)
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bankBag, slot)
                if itemLink then
                    local itemID = tonumber(string.match(itemLink, "item:(%d+):"))
                    if itemID then
                        collection[itemID] = 1
                    end
                end
            end
        end

        for i = 1, 19 do
            local itemID = GetInventoryItemID("player", i)
            if itemID then
                collection[itemID] = 2
            end
        end
    end

    local function beginScan()
        local collection = {}
        scanBagsAndEquipped(collection)
        Bistooltip_char_equipment = collection

        -- Spread the expensive BiS-wide GetItemCount checks across frames
        ensureBisItemIDs()
        bisIndex = 1
        scanningBis = true
        frame:Show()
    end

    frame:SetScript("OnEvent", function()
        updatePending = true
        acc = 0
        frame:Show()
    end)

    frame:SetScript("OnUpdate", function(self, elapsed)
        if updatePending then
            acc = acc + elapsed
            if acc >= delay then
                acc = 0
                updatePending = false
                beginScan()
            end
            return
        end

        if scanningBis and bisItemIDs then
            local stop = bisIndex + bisChunk - 1
            if stop > #bisItemIDs then stop = #bisItemIDs end

            for i = bisIndex, stop do
                local itemID = bisItemIDs[i]
                if itemID then
                    local count = GetItemCount(itemID, true)
                    if count and count > 0 and not Bistooltip_char_equipment[itemID] then
                        Bistooltip_char_equipment[itemID] = 1
                    end
                end
            end
            bisIndex = stop + 1

            if bisIndex > #bisItemIDs then
                scanningBis = false
                self:Hide()
            end
            return
        end

        self:Hide()
    end)
end

function BistooltipAddon:OnInitialize()
    createEquipmentWatcher()
    BistooltipAddon.AceAddonName = "Bis-Tooltip"
    BistooltipAddon.AddonNameAndVersion = "BiS Tooltip"
    BistooltipAddon:initConfig()
    BistooltipAddon:addMapIcon()
    BistooltipAddon:initBislists()
    BistooltipAddon:initBisTooltip()
end