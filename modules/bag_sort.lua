-- modules/bag_sort.lua : bag sorting — merge stacks, sort by quality, with
-- configurable fill direction. Triggered by a button on the backpack frame.
local SPU = _G["StockPlusUI"]

local module = { name = "bag_sort" }
SPU:register_module(module)

local db
local FIRST_BAG, LAST_BAG = 0, 4
local MAX_STEPS = 300

-- ---- helpers ---------------------------------------------------------------

local function item_id_at(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    return link and tonumber(link:match("item:(%d+)")) or nil
end

local function scan_bags()
    local items = {}
    for bag = FIRST_BAG, LAST_BAG do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, count = GetContainerItemInfo(bag, slot)
                local name, _, quality = GetItemInfo(link)
                items[#items + 1] = {
                    bag = bag, slot = slot, link = link,
                    name = name or "?", quality = quality or 0,
                    count = count or 1,
                    id = tonumber(link:match("item:(%d+)")) or 0,
                }
            end
        end
    end
    return items
end

-- Category rank: lower number sorts first. Uses GetItemInfo's itemType
-- (English client strings). Unlisted types fall to the bottom.
local CATEGORY_RANK = {
    ["Quest"]        = 1,
    ["Weapon"]       = 2,
    ["Armor"]        = 2,   -- gear grouped with weapons
    ["Consumable"]   = 3,
    ["Trade Goods"]  = 4,
    ["Recipe"]       = 5,
    ["Miscellaneous"]= 6,
}
local CATEGORY_DEFAULT = 99   -- anything not listed goes last

local function category_rank(link)
    local _, _, _, _, _, itemType = GetItemInfo(link)
    return CATEGORY_RANK[itemType] or CATEGORY_DEFAULT
end

local function compare(a, b)
    -- 1) quality (rarity) descending
    if a.quality ~= b.quality then return a.quality > b.quality end
    -- 2) category rank ascending (quest first, then gear, etc.)
    local ca, cb = category_rank(a.link), category_rank(b.link)
    if ca ~= cb then return ca < cb end
    -- 3) item ID ascending (groups identical/related items)
    if a.id ~= b.id then return a.id < b.id end
    -- 4) stack count descending
    return a.count > b.count
end

local function build_slot_sequence()
    local seq = {}
    local bags = {}
    if db and db.reverse_bags then
        for b = LAST_BAG, FIRST_BAG, -1 do bags[#bags + 1] = b end
    else
        for b = FIRST_BAG, LAST_BAG do bags[#bags + 1] = b end
    end
    for _, bag in ipairs(bags) do
        local slots = GetContainerNumSlots(bag)
        if db and db.pack_to_back then
            for slot = slots, 1, -1 do
                seq[#seq + 1] = { bag = bag, slot = slot }
            end
        else
            for slot = 1, slots do
                seq[#seq + 1] = { bag = bag, slot = slot }
            end
        end
    end
    return seq
end

local function any_locked()
    for bag = FIRST_BAG, LAST_BAG do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local _, _, locked = GetContainerItemInfo(bag, slot)
            if locked then return true end
        end
    end
    return false
end

-- ---- merge detection -------------------------------------------------------

local function find_merge()
    local seen = {}
    for bag = FIRST_BAG, LAST_BAG do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = tonumber(link:match("item:(%d+)"))
                local _, count = GetContainerItemInfo(bag, slot)
                local _, _, _, _, _, _, _, maxStack = GetItemInfo(link)
                maxStack = maxStack or 1
                if id and maxStack > 1 and count and count < maxStack then
                    local prev = seen[id]
                    if prev then
                        return { bag = bag, slot = slot }, { bag = prev.bag, slot = prev.slot }
                    else
                        seen[id] = { bag = bag, slot = slot }
                    end
                end
            end
        end
    end
    return nil
end

-- ---- engine ----------------------------------------------------------------

local phase = nil
local target_id = {}
local steps = 0
local runner = CreateFrame("Frame")
runner:Hide()

local function stop(msg)
    phase = nil
    runner:Hide()
    if CursorHasItem() then ClearCursor() end
    if msg then print("|cff33ff99StockPlusUI|r " .. msg) end
end

local function build_target(items)
    target_id = {}
    for i = 1, #items do
        target_id[i] = items[i].id
    end
end

local function find_item(id, seq)
    for i = 1, #seq do
        local s = seq[i]
        if item_id_at(s.bag, s.slot) == id and target_id[i] ~= id then
            return i
        end
    end
    return nil
end

local function do_sort_tick()
    local seq = build_slot_sequence()
    for i = 1, #seq do
        local want = target_id[i]
        local s = seq[i]
        local cur = item_id_at(s.bag, s.slot)
        if cur ~= want and want ~= nil then
            local j = find_item(want, seq)
            if j and j ~= i then
                local a, b = seq[i], seq[j]
                if GetContainerItemLink(a.bag, a.slot) then
                    PickupContainerItem(a.bag, a.slot)
                    PickupContainerItem(b.bag, b.slot)
                else
                    PickupContainerItem(b.bag, b.slot)
                    PickupContainerItem(a.bag, a.slot)
                end
                return true
            end
        end
    end
    return false
end

runner:SetScript("OnUpdate", function()
    if not phase then return end
    if any_locked() then return end
    if CursorHasItem() then return end

    steps = steps + 1
    if steps > MAX_STEPS then stop("sort stopped (step cap)") return end

    if phase == "merge" then
        local src, dst = find_merge()
        if src and dst then
            PickupContainerItem(src.bag, src.slot)
            PickupContainerItem(dst.bag, dst.slot)
            return
        end
        local items = scan_bags()
        table.sort(items, compare)
        build_target(items)
        phase = "sort"
        return
    end

    if phase == "sort" then
        if not do_sort_tick() then stop() end
    end
end)

local function start_sort()
    if phase then return end
    if InCombatLockdown() then print("|cff33ff99StockPlusUI|r can't sort in combat") return end
    if CursorHasItem() then print("|cff33ff99StockPlusUI|r clear the cursor first") return end
    steps = 0
    phase = "merge"
    runner:Show()
end
SPU.bag_sort_start = start_sort

-- ---- the on-bag button -----------------------------------------------------

local function create_button()
    local btn = CreateFrame("Button", "StockPlusUIBagSortButton", ContainerFrame1)
    btn:SetSize(24, 24)
    btn:SetPoint("TOPRIGHT", ContainerFrame1, "TOPRIGHT", -30, -16)
    btn:SetFrameLevel(ContainerFrame1:GetFrameLevel() + 5)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    btn:SetScript("OnClick", function() start_sort() end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Sort Bags")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ---- init ------------------------------------------------------------------

function module:on_init(settings)
    db = settings
    create_button()
end

SLASH_STOCKPLUSSORT1 = "/spusort"
SlashCmdList["STOCKPLUSSORT"] = function()
    start_sort()
end

-- ---- config page (fill-direction options only) -----------------------------

SPU:register_config("Bag Sort", function(panel)
    local b = function() return SPU.db.bag_sort end

    local header = SPU:make_header(panel, "Bag Sort", nil)
    local sub    = SPU:make_subtitle(panel, "Click the sort button on your bag. Choose the fill direction below.", header)

    local revbags = SPU:make_checkbox(panel, "StockPlusUIBagRevBags", "Fill last bag first", sub, -16,
        function() return b().reverse_bags end,
        function(v) b().reverse_bags = v end)

    SPU:make_checkbox(panel, "StockPlusUIBagToBack", "Pack items to back (front stays open)", revbags, -6,
        function() return b().pack_to_back end,
        function(v) b().pack_to_back = v end)
end)
