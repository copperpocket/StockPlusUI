-- modules/chat_enhance.lua : enhance the default chat frame (opacity, buttons,
-- text fade time, unified conditional fading). All deviations from native are
-- gated behind toggles; with toggles off, native behavior is fully restored.
local SPU = _G["StockPlusUI"]

local chat = { name = "chat_enhance" }
SPU:register_module(chat)

local db
local native_time_visible = {}

local shared_buttons = {
    "FriendsMicroButton",
    "ChatFrameMenuButton",
}

-- ---- buttons ---------------------------------------------------------------
-- Set alpha on the button FRAME only (cascades to Up/Down/Bottom children).
-- Setting both parent and children multiplies alpha, making the scroll buttons
-- fade far faster than the independent social/menu buttons.

local function apply_buttons()
    for i = 1, NUM_CHAT_WINDOWS do
        local bf = _G["ChatFrame" .. i .. "ButtonFrame"]
        if bf then
            if db.hide_buttons then
                bf:Hide()
            else
                bf:Show()
                bf:SetAlpha(db.buttons_alpha)   -- cascades to Up/Down/Bottom children
            end
        end
    end
    -- Independent buttons that live outside the button frame.
    for i = 1, #shared_buttons do
        local b = _G[shared_buttons[i]]
        if b then
            if db.hide_buttons then b:Hide() else b:Show(); b:SetAlpha(db.buttons_alpha) end
        end
    end
end

-- Move every chat window's edit box above its frame (or restore to bottom).
-- When on top, the edit box is mouse-DISABLED so clicks pass through to the
-- tabs underneath (open it with Enter/slash, like DragonUI/ElvUI). This runs
-- regardless of the fade setting.
local function apply_editbox_position()
    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        local cf = _G["ChatFrame" .. i]
        if eb and cf then
            eb:ClearAllPoints()
            if db.editbox_on_top then
                eb:SetPoint("BOTTOMLEFT",  cf, "TOPLEFT",  -5, 22)
                eb:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT",  5, 22)
                eb:EnableMouse(false)   -- click-through: open via Enter, not click
            else
                eb:SetPoint("TOPLEFT",  cf, "BOTTOMLEFT",  -5, 0)
                eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT",  5, 0)
                eb:EnableMouse(true)    -- restore default click-to-open
            end
        end
    end
end

-- Zero the clamp insets so the chat frame can slide to the very screen edges.
-- Blizzard reserves left space (button column) and bottom space (edit box) via
-- negative insets; with our buttons hidden we want them to slide off-screen.
local function apply_clamp_insets()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            cf:SetClampRectInsets(0, 0, 0, 0)
        end
    end
end

-- ---- text fade (gated behind faster_text_fade) -----------------------------

local function apply_text_fade()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            if db.faster_text_fade then
                cf:SetFading(true)
                cf:SetTimeVisible(db.text_visible_time)
                cf:SetFadeDuration(1.0)
            else
                cf:SetTimeVisible(native_time_visible[i] or 120)
            end
        end
    end
end

local function apply_chat()
    if not db then return end
    apply_text_fade()
    apply_buttons()
    apply_editbox_position()
    apply_clamp_insets()
end

SPU.apply_chat = apply_chat
function SPU:refresh_chat()
    apply_chat()
    if SPU.refresh_chat_fade then SPU:refresh_chat_fade() end
end

-- ---- state evaluation ------------------------------------------------------

local mouse_over_chat

local function mouse_over_cluster()
    if ChatFrame1 and ChatFrame1:IsVisible() and MouseIsOver(ChatFrame1) then return true end
    for i = 1, NUM_CHAT_WINDOWS do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab and tab:IsShown() and MouseIsOver(tab) then return true end
        local bf = _G["ChatFrame" .. i .. "ButtonFrame"]
        if bf and bf:IsShown() and MouseIsOver(bf) then return true end
    end
    return false
end

-- General "cluster should be visible" state. Note: editbox focus is handled
-- separately below, but typing should still reveal the whole cluster.
local function should_show()
    if SPU:should_ui_show() then return true end
    if mouse_over_chat then return true end
    local eb = _G["ChatFrame1EditBox"]
    if eb and eb:HasFocus() then return true end
    return false
end

-- ---- faders ----------------------------------------------------------------

local tab_fader, current_tab_alpha
local eb_fader,  current_eb_alpha

-- Tabs + resize handles (NOT the edit box; it has its own rule).
local function get_fade_frames()
    local out = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab and tab:IsShown() then out[#out + 1] = tab end
        local rz = _G["ChatFrame" .. i .. "ResizeButton"]
        if rz then out[#out + 1] = rz end
    end
    return out
end

local function get_editbox()
    local eb = _G["ChatFrame1EditBox"]
    return eb and { eb } or {}
end

-- ---- background fader ------------------------------------------------------

local bg_driver = CreateFrame("Frame")
bg_driver:Hide()
local bg_from, bg_to, bg_elapsed, bg_dur, bg_current, bg_target = 0, 0, 0, 0, nil, nil

local function set_bg(alpha)
    bg_current = alpha
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then FCF_SetWindowAlpha(cf, alpha, true) end
    end
end

bg_driver:SetScript("OnUpdate", function(self, dt)
    bg_elapsed = bg_elapsed + dt
    local t = (bg_dur > 0) and (bg_elapsed / bg_dur) or 1
    if t >= 1 then set_bg(bg_to); self:Hide()
    else set_bg(bg_from + (bg_to - bg_from) * t) end
end)

local function fade_bg_to(target)
    bg_from    = bg_current or target
    bg_to      = target
    bg_elapsed = 0
    bg_dur     = db.fade_time or 0.25
    if bg_dur <= 0 or bg_from == bg_to then set_bg(target); bg_driver:Hide()
    else bg_driver:Show() end
end

-- ---- unified fade application ----------------------------------------------

local function apply_fade_state()
    if not db or not db.fade_tabs then return end

    local show = should_show()

    -- tabs + resize
    local tab_t = show and db.tabs_shown_alpha or db.tabs_faded_alpha
    if current_tab_alpha ~= tab_t and tab_fader then
        current_tab_alpha = tab_t
        tab_fader:fade_to(tab_t)
    end

    -- edit boxes: visible only while actually focused (typing). Otherwise
    -- alpha 0. Mouse enable/disable is handled in apply_editbox_position.
    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            eb:SetAlpha(eb:HasFocus() and db.tabs_shown_alpha or 0)
        end
    end
    current_eb_alpha = nil

    -- background
    local bg_t = db.bg_alpha * (show and 1.0 or db.tabs_faded_alpha)
    if bg_target ~= bg_t then
        bg_target = bg_t
        fade_bg_to(bg_t)
    end
end

SPU.apply_chat_fade = apply_fade_state

function SPU:refresh_chat_fade()
    if not db then return end
    if db.fade_tabs then
        current_tab_alpha = nil
        current_eb_alpha  = nil
        bg_target = nil
        apply_fade_state()
    else
        bg_driver:Hide()
        current_tab_alpha, current_eb_alpha, bg_target, bg_current = nil, nil, nil, nil
        if tab_fader then tab_fader:set(1.0) end
        if eb_fader  then eb_fader:set(1.0)  end
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            if cf then FCF_SetWindowAlpha(cf, db.bg_alpha) end
        end
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            if cf and cf:IsShown() then FCFTab_UpdateAlpha(cf) end
        end
    end
end

-- ---- init ------------------------------------------------------------------

function chat:on_init(settings)
    db = settings

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            native_time_visible[i] = (cf.GetTimeVisible and cf:GetTimeVisible()) or 120
        end
    end

    tab_fader = SPU:create_fader(get_fade_frames, db.fade_time)
    eb_fader  = SPU:create_fader(get_editbox,     db.fade_time)

    local orig_fade_in  = FCF_FadeInChatFrame
    local orig_fade_out = FCF_FadeOutChatFrame
    FCF_FadeInChatFrame  = function(frame) if db and db.fade_tabs then return end return orig_fade_in(frame)  end
    FCF_FadeOutChatFrame = function(frame) if db and db.fade_tabs then return end return orig_fade_out(frame) end

    hooksecurefunc("FCFTab_UpdateAlpha", function(chatFrame)
        if not db or not db.fade_tabs then return end
        local tab = _G[chatFrame:GetName() .. "Tab"]
        if tab and current_tab_alpha then tab:SetAlpha(current_tab_alpha) end
    end)

    -- Blizzard resets clamp insets when a chat frame is moved/docked; reassert.
    hooksecurefunc("FCF_SavePositionAndDimensions", function() if db then apply_clamp_insets() end end)

    SPU:register_event("PLAYER_ENTERING_WORLD", apply_chat)
    apply_chat()

    local function on_state() apply_fade_state() end
    SPU:register_event("PLAYER_REGEN_DISABLED",  on_state)
    SPU:register_event("PLAYER_REGEN_ENABLED",   on_state)
    SPU:register_event("PLAYER_TARGET_CHANGED",  on_state)
    SPU:register_event("PLAYER_ENTERING_WORLD",  on_state)
    SPU:register_event("UNIT_HEALTH",       function(_, u) if u == "player" then on_state() end end)
    SPU:register_event("UNIT_MANA",         function(_, u) if u == "player" then on_state() end end)
    SPU:register_event("UNIT_RAGE",         function(_, u) if u == "player" then on_state() end end)
    SPU:register_event("UNIT_ENERGY",       function(_, u) if u == "player" then on_state() end end)
    SPU:register_event("UNIT_RUNIC_POWER",  function(_, u) if u == "player" then on_state() end end)
    SPU:register_event("UNIT_DISPLAYPOWER", function(_, u) if u == "player" then on_state() end end)
    SPU:register_event("UPDATE_CHAT_WINDOWS", apply_chat)
    SPU:register_event("UPDATE_CHAT_COLOR",   apply_chat)

    hooksecurefunc("FCF_SelectDockFrame", function() if db then apply_buttons() end end)

    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            eb:HookScript("OnEditFocusGained", on_state)
            eb:HookScript("OnEditFocusLost",   on_state)
            eb:HookScript("OnShow", function()
                apply_editbox_position()   -- re-assert position each time it appears
                on_state()
            end)
            eb:HookScript("OnHide",            on_state)
        end
    end

    local poller, acc = CreateFrame("Frame"), 0
    poller:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        local over = mouse_over_cluster()
        if over ~= mouse_over_chat then
            mouse_over_chat = over
            apply_fade_state()
        end
    end)

    SPU:refresh_chat_fade()
end

-- ---- config page (ordered to match other sections) -------------------------

SPU:register_config("Chat", function(panel)
    local c = function() return SPU.db.chat_enhance end

    local header = SPU:make_header(panel, "Chat", nil)
    local sub    = SPU:make_subtitle(panel, "Enhance chat opacity and fading. With toggles off, chat behaves like default WoW.", header)

    local fade_tabs = SPU:make_checkbox(panel, "StockPlusUIChatFadeTabs", "Fade chat frame", sub, -12,
        function() return c().fade_tabs end,
        function(v) c().fade_tabs = v; if SPU.refresh_chat_fade then SPU:refresh_chat_fade() end end)

    local faded = SPU:make_alpha_slider(panel, "StockPlusUIChatTabsAlpha", "Faded opacity", fade_tabs, -22,
        function() return c().tabs_faded_alpha end,
        function(v) c().tabs_faded_alpha = v; if SPU.refresh_chat_fade then SPU:refresh_chat_fade() end end)

    local bg = SPU:make_alpha_slider(panel, "StockPlusUIChatBgAlpha", "Background opacity", faded, -32,
        function() return c().bg_alpha end,
        function(v) c().bg_alpha = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    local hide = SPU:make_checkbox(panel, "StockPlusUIChatHideButtons", "Hide side buttons", bg, -32,
        function() return c().hide_buttons end,
        function(v) c().hide_buttons = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    local btn = SPU:make_alpha_slider(panel, "StockPlusUIChatBtnAlpha", "Side button opacity", hide, -22,
        function() return c().buttons_alpha end,
        function(v) c().buttons_alpha = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    local ftf = SPU:make_checkbox(panel, "StockPlusUIChatFasterText", "Faster text fade", btn, -32,
        function() return c().faster_text_fade end,
        function(v) c().faster_text_fade = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    local vis = SPU:make_slider(panel, "StockPlusUIChatVisTime", "Text visible time", ftf, -22,
        5, 60, 1, "Text visible time: %ds",
        function() return c().text_visible_time end,
        function(v) c().text_visible_time = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    SPU:make_checkbox(panel, "StockPlusUIChatEditTop", "Edit box on top", vis, -14,
        function() return c().editbox_on_top end,
        function(v) c().editbox_on_top = v; if SPU.refresh_chat then SPU:refresh_chat() end end)
end)