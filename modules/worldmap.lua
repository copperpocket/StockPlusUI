-- modules/worldmap.lua : scale, fade, and move the world map.
--   Phase 1: scale slider.  Phase 3: opacity + hover fade.  Phase 2: drag move.
local SPU = _G["StockPlusUI"]

local module = { name = "worldmap" }
SPU:register_module(module)

local db
local map_fader
local mouse_over = false
local current_alpha
local drag_strip

local function is_windowed()
    return WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE
end

-- ---- scale -----------------------------------------------------------------

local function apply_scale()
    if not db then return end
    if InCombatLockdown() then return end
    if not WorldMapFrame then return end
    if is_windowed() then
        WorldMapFrame:SetScale(db.scale or 1.0)
    else
        WorldMapFrame:SetScale(1.0)   -- fullscreen: Blizzard default
    end
end

SPU.apply_worldmap = apply_scale
function SPU:refresh_worldmap() apply_scale() end

-- ---- saved position --------------------------------------------------------

local function apply_position()
    if InCombatLockdown() then return end
    if not WorldMapFrame then return end
    if is_windowed() then
        local pos = db and db.pos
        if pos then
            WorldMapFrame:ClearAllPoints()
            WorldMapFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        end
    end
    -- fullscreen: do NOT touch position; Blizzard anchors it centered/full
end

-- ---- opacity fade ----------------------------------------------------------

local function get_map_frames()
    return { WorldMapFrame }
end

local function apply_map_fade()
    if not db then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local target = mouse_over and 1.0 or (db.map_alpha or 1.0)
    if current_alpha == target then return end
    current_alpha = target
    if map_fader then map_fader:fade_to(target) end
end

-- ---- drag strip (Phase 2) --------------------------------------------------

local function setup_drag()
    local title = _G["WorldMapTitleButton"]
    if not title then return end
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        WorldMapFrame:SetMovable(true)
        WorldMapFrame:StartMoving()
    end)
    title:SetScript("OnDragStop", function()
        WorldMapFrame:StopMovingOrSizing()
        local point, _, _, x, y = WorldMapFrame:GetPoint()
        db.pos = { point = point or "CENTER", x = x or 0, y = y or 0 }
    end)
end

-- ---- init ------------------------------------------------------------------

function module:on_init(settings)
    db = settings
    map_fader = SPU:create_fader(get_map_frames, 0.2)

    if WorldMapFrame then
        setup_drag()

        WorldMapFrame:HookScript("OnShow", function()
            apply_scale()
            apply_position()
            current_alpha = nil
            mouse_over = false
            WorldMapFrame:SetAlpha(db.map_alpha or 1.0)
            apply_map_fade()
        end)

        -- re-apply (or reset) whenever the map view/size changes
        if WorldMapFrame_SetView then
            hooksecurefunc("WorldMapFrame_SetView", function()
                apply_scale()
                apply_position()
            end)
        end
        -- also handle the windowed/fullscreen toggle if it uses this
        if WorldMap_ToggleSizeUp then
            hooksecurefunc("WorldMap_ToggleSizeUp", function()
                apply_scale()
                apply_position()
            end)
        end
        if WorldMap_ToggleSizeDown then
            hooksecurefunc("WorldMap_ToggleSizeDown", function()
                apply_scale()
                apply_position()
            end)
        end

    end

    SPU:register_event("PLAYER_ENTERING_WORLD", apply_scale)
    apply_scale()

    -- hover poll (only while the map is shown)
    local poller, acc = CreateFrame("Frame"), 0
    poller:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
        local over = MouseIsOver(WorldMapFrame)
        if over ~= mouse_over then
            mouse_over = over
            apply_map_fade()
        end
    end)
end

-- ---- config page -----------------------------------------------------------

SPU:register_config("World Map", function(panel)
    local m = function() return SPU.db.worldmap end

    local header = SPU:make_header(panel, "World Map", nil)
    local sub    = SPU:make_subtitle(panel, "Scale, fade, and move the world map. Drag the top edge to reposition.", header)

    local scale = SPU:make_slider(panel, "StockPlusUIWorldMapScale", "Map scale", sub, -16,
        100, 250, 10, "Map scale: %d%%",
        function() return (m().scale or 1.0) * 100 end,
        function(v)
            m().scale = v / 100
            if SPU.refresh_worldmap then SPU:refresh_worldmap() end
        end)

    local alpha = SPU:make_alpha_slider(panel, "StockPlusUIWorldMapAlpha", "Opacity when not hovered", scale, -30,
        function() return m().map_alpha end,
        function(v)
            m().map_alpha = v
            if WorldMapFrame and WorldMapFrame:IsShown() then
                WorldMapFrame:SetAlpha(v)
            end
        end)

    SPU:make_checkbox(panel, "StockPlusUIWorldMapResetPos", "(check to reset map position)", alpha, -16,
        function() return false end,
        function(v)
            if v then
                m().pos = nil
                print("|cff33ff99StockPlusUI|r map position reset - reopen the map")
            end
        end)
end)
