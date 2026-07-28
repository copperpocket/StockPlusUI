-- modules/worldmap.lua : scale, fade, move the world map, and show coordinates.
local SPU = _G["StockPlusUI"]

local module = { name = "worldmap" }
SPU:register_module(module)

local db
local map_fader
local mouse_over = false
local current_alpha
local coords_text

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

-- ---- drag (Blizzard's title button) ----------------------------------------

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

-- ---- coordinates (cursor + player) -----------------------------------------

local function setup_coords()
    if not WorldMapFrame then return end

    local text = WorldMapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetTextColor(1, 0.82, 0)
    coords_text = text

    -- (the OnUpdate block stays exactly as-is)
    local acc = 0
    WorldMapFrame:HookScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.05 then return end
        acc = 0

        local detail = WorldMapDetailFrame
        if not detail then text:SetText("") return end

        -- player coords
        local pstr = ""
        local px, py = GetPlayerMapPosition("player")
        if px and py and (px ~= 0 or py ~= 0) then
            pstr = string.format("Player: %.1f, %.1f", px * 100, py * 100)
        end

        -- cursor coords over the map detail area
        local cstr = ""
        local mx, my = GetCursorPosition()
        local scale = detail:GetEffectiveScale()
        if scale and scale > 0 then
            mx = mx / scale
            my = my / scale
            local left, top = detail:GetLeft(), detail:GetTop()
            local w, h = detail:GetWidth(), detail:GetHeight()
            if left and top and w and h and w > 0 and h > 0 then
                local cx = (mx - left) / w
                local cy = (top - my) / h
                if cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
                    cstr = string.format("Cursor: %.1f, %.1f", cx * 100, cy * 100)
                end
            end
        end

        if pstr ~= "" and cstr ~= "" then
            text:SetText(pstr .. "  |  " .. cstr)
        else
            text:SetText(pstr .. cstr)
        end
    end)
end

local function position_coords()
    if not coords_text then return end
    coords_text:ClearAllPoints()
    if is_windowed() then
        -- windowed: on the bottom border (your tuned values)
        coords_text:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMLEFT", 25, -2)
    else
        -- fullscreen: bottom-left of the map detail area, matching the
        -- "Show Quest Objectives" text height on the right
        coords_text:SetPoint("BOTTOMLEFT", WorldMapDetailFrame or WorldMapFrame, "BOTTOMLEFT", 10, -20)
    end
end


-- ---- init ------------------------------------------------------------------

function module:on_init(settings)
    db = settings
    map_fader = SPU:create_fader(get_map_frames, 0.2)

    if WorldMapFrame then
        setup_drag()
        setup_coords()
        position_coords()

        WorldMapFrame:HookScript("OnShow", function()
            apply_scale()
            apply_position()
            position_coords()
            current_alpha = nil
            mouse_over = false
            WorldMapFrame:SetAlpha(db.map_alpha or 1.0)
            apply_map_fade()
        end)

        if WorldMapFrame_SetView then
            hooksecurefunc("WorldMapFrame_SetView", function()
                apply_scale()
                apply_position()
                position_coords()
            end)
        end
        if WorldMap_ToggleSizeUp then
            hooksecurefunc("WorldMap_ToggleSizeUp", function()
                apply_scale()
                apply_position()
                position_coords()
            end)
        end
        if WorldMap_ToggleSizeDown then
            hooksecurefunc("WorldMap_ToggleSizeDown", function()
                apply_scale()
                apply_position()
                position_coords()
            end)
        end
    end

    SPU:register_event("PLAYER_ENTERING_WORLD", apply_scale)
    apply_scale()

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
    local sub    = SPU:make_subtitle(panel, "Scale, fade, and move the world map. Drag the title bar to reposition.", header)

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
