BistooltipAddon = BistooltipAddon or LibStub("AceAddon-3.0"):NewAddon("Bis-Tooltip")

Bistooltip_char_equipment = {}

local _pendingItemFrames = {}
local _pendingPollFrame
local _pendingPollElapsed = 0
local _pendingPrimeRequested = {}
local _itemQueryTooltip

local function _Bistooltip_PrimeItemData(itemID)
    if _pendingPrimeRequested[itemID] then
        return
    end
    _pendingPrimeRequested[itemID] = true

    if not _itemQueryTooltip then
        _itemQueryTooltip = CreateFrame("GameTooltip", "BiSTooltipHiddenItemQueryTooltip", UIParent, "GameTooltipTemplate")
        _itemQueryTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    _itemQueryTooltip:ClearLines()
    _itemQueryTooltip:SetHyperlink("item:" .. itemID .. ":0:0:0:0:0:0:0")
end

local function _Bistooltip_ProcessPendingItemFrames()
    for itemID, widgets in pairs(_pendingItemFrames) do
        local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
        local hasLiveWidgets = false

        -- Drop dead/released AceGUI widgets from the queue to avoid retaining them.
        for i = #widgets, 1, -1 do
            local w = widgets[i]
            if not w or not w.frame or not w.SetImage then
                table.remove(widgets, i)
            else
                hasLiveWidgets = true
            end
        end

        if not hasLiveWidgets then
            _pendingItemFrames[itemID] = nil
        elseif itemName and itemIcon then
            for _, w in ipairs(widgets) do
                w:SetImage(itemIcon)
                w._bistooltip_pendingItemID = nil
                if itemLink then
                    w._bistooltip_itemLink = itemLink
                end
            end
            _pendingPrimeRequested[itemID] = nil
            _pendingItemFrames[itemID] = nil
        else
            -- Re-trigger query
            GetItemInfo(itemID)
            _Bistooltip_PrimeItemData(itemID)
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
    if aceIconWidget._bistooltip_pendingItemID == itemID then return end
    aceIconWidget._bistooltip_pendingItemID = itemID

    local bucket = _pendingItemFrames[itemID]
    if not bucket then
        bucket = {}
        _pendingItemFrames[itemID] = bucket
    end
    bucket[#bucket + 1] = aceIconWidget

    -- Trigger query attempt
    GetItemInfo(itemID)
    _Bistooltip_PrimeItemData(itemID)

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
    for _, bucket in pairs(_pendingItemFrames) do
        for i = 1, #bucket do
            local w = bucket[i]
            if w then
                w._bistooltip_pendingItemID = nil
            end
        end
    end
    for k in pairs(_pendingItemFrames) do
        _pendingItemFrames[k] = nil
    end
    for k in pairs(_pendingPrimeRequested) do
        _pendingPrimeRequested[k] = nil
    end
    if _pendingPollFrame then
        _pendingPollFrame:SetScript("OnUpdate", nil)
    end
end

local function collectItemIDs(bislists)
    local itemIDs = {}
    local seen = {}
    local function addItemID(itemID)
        itemID = tonumber(itemID)
        if itemID and itemID > 0 and not seen[itemID] then
            seen[itemID] = true
            itemIDs[#itemIDs + 1] = itemID
        end
    end

    for _, classData in pairs(bislists) do
        for _, specData in pairs(classData) do
            for _, phaseData in pairs(specData) do
                for _, itemData in ipairs(phaseData) do
                    for key, value in pairs(itemData) do
                        if type(key) == "number" then
                            addItemID(value)
                        elseif key == "enhs" then
                            for _, enhData in pairs(value) do
                                if enhData.type == "item" and enhData.id then
                                    addItemID(enhData.id)
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