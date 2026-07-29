-- modules/chat_enhance.lua : enhance the default chat frame (opacity, buttons,
-- text fade time, class-colored names). Chat visibility is INDEPENDENT of the
-- shared UI conditions; it fades on its own (hover / typing / native fade).
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

local function apply_buttons()
    for i = 1, NUM_CHAT_WINDOWS do
        local bf = _G["ChatFrame" .. i .. "ButtonFrame"]
        if bf then
            if db.hide_buttons then
                bf:Hide()
            else
                bf:Show()
                bf:SetAlpha(db.buttons_alpha)
            end
        end
    end
    for i = 1, #shared_buttons do
        local b = _G[shared_buttons[i]]
        if b then
            if db.hide_buttons then b:Hide() else b:Show(); b:SetAlpha(db.buttons_alpha) end
        end
    end
end

local function apply_editbox_position()
    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        local cf = _G["ChatFrame" .. i]
        if eb and cf then
            eb:ClearAllPoints()
            if db.editbox_on_top then
                eb:SetPoint("BOTTOMLEFT",  cf, "TOPLEFT",  -5, 22)
                eb:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT",  5, 22)
                eb:EnableMouse(false)
            else
                eb:SetPoint("TOPLEFT",  cf, "BOTTOMLEFT",  -5, 0)
                eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT",  5, 0)
                eb:EnableMouse(true)
            end
        end
    end
end

local function apply_clamp_insets()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            cf:SetClampRectInsets(0, 0, 0, 0)
        end
    end
end

-- ---- text fade -------------------------------------------------------------

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

local function reveal_chat_text()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.ScrollDown then cf:ScrollDown() end
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

-- ---- class colored names ---------------------------------------------------

local orig_GetColoredName

local function get_class_color_from_guid(guid)
    if not guid or guid == "" then return nil end
    local _, class = GetPlayerInfoByGUID(guid)
    if class and RAID_CLASS_COLORS[class] then
        return RAID_CLASS_COLORS[class]
    end
    return nil
end

-- Wrap Blizzard's GetColoredName (called per chat line with the sender GUID at
-- arg12) so the DISPLAY name is class-colored. The |Hplayer|h link is untouched.
local function setup_class_colors()
    if orig_GetColoredName then return end
    orig_GetColoredName = _G.GetColoredName

    _G.GetColoredName = function(event, arg1, arg2, arg3, arg4, arg5, arg6,
                                 arg7, arg8, arg9, arg10, arg11, arg12, ...)
        local name = orig_GetColoredName(event, arg1, arg2, arg3, arg4, arg5,
            arg6, arg7, arg8, arg9, arg10, arg11, arg12, ...)

        if not (db and db.class_colors) then return name end
        if not name or name == "" then return name end

        local color = get_class_color_from_guid(arg12)
        if color then
            return string.format("|cff%02x%02x%02x%s|r",
                color.r * 255, color.g * 255, color.b * 255, name)
        end
        return name
    end
end

-- ---- state evaluation (INDEPENDENT of shared conditions) -------------------

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

local function should_show()
    if mouse_over_chat then return true end
    local eb = _G["ChatFrame1EditBox"]
    if eb and eb:HasFocus() then return true end
    return false
end

-- ---- faders ----------------------------------------------------------------

local tab_fader, current_tab_alpha
local eb_fader,  current_eb_alpha

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

    local tab_t = show and db.tabs_shown_alpha or db.tabs_faded_alpha
    if current_tab_alpha ~= tab_t and tab_fader then
        current_tab_alpha = tab_t
        tab_fader:fade_to(tab_t)
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            eb:SetAlpha(eb:HasFocus() and db.tabs_shown_alpha or 0)
        end
    end
    current_eb_alpha = nil

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

    setup_class_colors()

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

    hooksecurefunc("FCF_SavePositionAndDimensions", function() if db then apply_clamp_insets() end end)

    SPU:register_event("PLAYER_ENTERING_WORLD", function()
        apply_chat()
        SPU:refresh_chat_fade()
    end)
    apply_chat()

    local function on_state() apply_fade_state() end
    SPU:register_event("UPDATE_CHAT_WINDOWS", apply_chat)
    SPU:register_event("UPDATE_CHAT_COLOR",   apply_chat)

    hooksecurefunc("FCF_SelectDockFrame", function() if db then apply_buttons() end end)

    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            eb:HookScript("OnEditFocusGained", function()
                if db and db.show_text_on_type then reveal_chat_text() end
                on_state()
            end)
            eb:HookScript("OnEditFocusLost", function()
                on_state()
            end)
            eb:HookScript("OnShow", function()
                apply_editbox_position()
                on_state()
            end)
            eb:HookScript("OnHide", on_state)
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

-- ---- config page -----------------------------------------------------------
SPU:register_config("Chat", function(panel)
    local c = function() return SPU.db.chat_enhance end

    local header = SPU:make_header(panel, "Chat", nil)
    local sub    = SPU:make_subtitle(panel, "Chat opacity, fading, and class colors, independent of the shared conditions.", header)

    local content, scroll, top = SPU:make_scroll(panel, sub)

    local fade_tabs = SPU:make_checkbox(content, "StockPlusUIChatFadeTabs", "Fade tabs and background", top, -8,
        function() return c().fade_tabs end,
        function(v) c().fade_tabs = v; if SPU.refresh_chat_fade then SPU:refresh_chat_fade() end end)

    local faded = SPU:make_alpha_slider(content, "StockPlusUIChatTabsAlpha", "Faded opacity", fade_tabs, -22,
        function() return c().tabs_faded_alpha end,
        function(v) c().tabs_faded_alpha = v; if SPU.refresh_chat_fade then SPU:refresh_chat_fade() end end)

    local bg = SPU:make_alpha_slider(content, "StockPlusUIChatBgAlpha", "Background opacity", faded, -32,
        function() return c().bg_alpha end,
        function(v) c().bg_alpha = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    local hide = SPU:make_checkbox(content, "StockPlusUIChatHideButtons", "Hide side buttons", bg, -32,
        function() return c().hide_buttons end,
        function(v) c().hide_buttons = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    local btn = SPU:make_alpha_slider(content, "StockPlusUIChatBtnAlpha", "Side button opacity", hide, -22,
        function() return c().buttons_alpha end,
        function(v) c().buttons_alpha = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    local ftf = SPU:make_checkbox(content, "StockPlusUIChatFasterText", "Faster text fade", btn, -32,
        function() return c().faster_text_fade end,
        function(v) c().faster_text_fade = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    local vis = SPU:make_slider(content, "StockPlusUIChatVisTime", "Text visible time", ftf, -22,
        5, 60, 1, "Text visible time: %ds",
        function() return c().text_visible_time end,
        function(v) c().text_visible_time = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    local edittop = SPU:make_checkbox(content, "StockPlusUIChatEditTop", "Edit box on top", vis, -14,
        function() return c().editbox_on_top end,
        function(v) c().editbox_on_top = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    local showtype = SPU:make_checkbox(content, "StockPlusUIChatShowOnType", "Show chat text while typing", edittop, -8,
        function() return c().show_text_on_type end,
        function(v) c().show_text_on_type = v; if SPU.refresh_chat then SPU:refresh_chat() end end)

    SPU:make_checkbox(content, "StockPlusUIChatClassColors", "Class-colored names", showtype, -8,
        function() return c().class_colors end,
        function(v) c().class_colors = v end)

    content:SetHeight(400)
end)
