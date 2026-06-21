-- ============================================================
--  NEXUS UI  |  Menu Library  v2.0
--  Glassmorphism · Fluid Animations · Zero-Bug Architecture
-- ============================================================

local Menu = {}

-- ============================================================
--  CONSTANTS  (single source of truth)
-- ============================================================
local EASE   = 0.14      -- lerp strength per frame
local FPS_MS = 0         -- Wait() arg (0 = max fps)

local C = {
    -- Backgrounds
    BG_BASE    = { 0.04, 0.04, 0.07, 0.92 },   -- deep navy-black
    BG_PANEL   = { 0.06, 0.06, 0.10, 0.88 },
    BG_ITEM    = { 0.08, 0.08, 0.13, 0.70 },
    BG_ITEM_S  = { 0.14, 0.12, 0.22, 0.95 },   -- selected
    BG_TAB     = { 0.06, 0.06, 0.10, 0.80 },
    BG_TAB_S   = { 0.16, 0.14, 0.28, 0.95 },   -- selected tab

    -- Accents  (indigo → cyan)
    ACC1       = { 0.38, 0.40, 0.95 },  -- #6166F2 indigo
    ACC2       = { 0.13, 0.83, 0.93 },  -- #22D4EE cyan
    ACC_DIM    = { 0.25, 0.27, 0.65 },

    -- Text
    TEXT       = { 0.95, 0.95, 1.00 },
    TEXT_DIM   = { 0.50, 0.52, 0.65 },
    TEXT_SEL   = { 1.00, 1.00, 1.00 },

    -- Borders
    BORDER     = { 0.38, 0.40, 0.95, 0.35 },
    BORDER_LO  = { 0.20, 0.20, 0.35, 0.25 },

    -- Toggle on/off
    TOG_OFF    = { 0.14, 0.14, 0.22, 1.0 },
    TOG_ON     = { 0.38, 0.40, 0.95, 1.0 },
    KNOB       = { 0.95, 0.95, 1.00, 1.0 },

    -- Slider
    SLIDER_BG  = { 0.10, 0.10, 0.18, 1.0 },

    -- Scrollbar
    SB_BG      = { 0.12, 0.12, 0.20, 0.60 },
    SB_THUMB   = { 0.38, 0.40, 0.95, 0.90 },

    -- Separator
    SEP        = { 0.20, 0.20, 0.35, 0.50 },

    -- Snowflake
    SNOW       = { 0.75, 0.80, 1.00, 0.30 },
}

-- ============================================================
--  LAYOUT  (all raw px, scale applied at draw time)
-- ============================================================
local L = {
    W           = 340,
    HEADER_H    = 96,
    TAB_H       = 30,
    ITEM_H      = 36,
    FOOTER_H    = 24,
    ITEMS_PAGE  = 9,
    GAP         = 2,     -- spacing between sections
    PAD_X       = 14,    -- horizontal text padding
    RADIUS_LG   = 8,
    RADIUS_SM   = 5,
    RADIUS_ITEM = 4,
    SB_W        = 3,
    SB_PAD      = 6,
    ACCENT_W    = 3,     -- left accent bar width
}

-- ============================================================
--  STATE
-- ============================================================
Menu.Visible            = false
Menu.CurrentCategory    = 2
Menu.CurrentTab         = 1
Menu.CurrentItem        = 1
Menu.OpenedCategory     = nil
Menu.ItemScrollOffset   = 0
Menu.CatScrollOffset    = 0
Menu.CurrentTopTab      = 1
Menu.Categories         = nil
Menu.TopLevelTabs       = nil
Menu.AnticheatList      = {}

-- Smooth selectors (animated Y positions)
Menu._selY              = 0
Menu._catSelY           = 0
Menu._tabSelX           = 0

-- Alpha states (fade-in/out panels)
Menu._menuAlpha         = 0.0
Menu._loadAlpha         = 1.0
Menu._keySelectorAlpha  = 0.0
Menu._keybindsAlpha     = 0.0

-- Loading
Menu.IsLoading          = true
Menu.LoadingComplete    = false
Menu.LoadingProgress    = 0.0
Menu.LoadingStart       = nil
Menu.LoadingDuration    = 2800

-- Key picking
Menu.SelectingKey       = false
Menu.SelectedKey        = nil
Menu.SelectedKeyName    = nil
Menu._tempKey           = nil

Menu.SelectingBind      = false
Menu.BindingItem        = nil
Menu.BindingKey         = nil
Menu.BindingKeyName     = nil
Menu._tempBindKey       = nil

-- Input modal
Menu.InputOpen          = false
Menu.InputText          = ""
Menu.InputTitle         = ""
Menu.InputSubtitle      = ""
Menu.InputCallback      = nil

-- Visual options
Menu.ShowSnowflakes     = true
Menu.ShowKeybinds       = false
Menu.EditorMode         = false
Menu.EditorDragging     = false
Menu._edgX, Menu._edgY = 0, 0

-- Position / scale
Menu.Position = { x = 24, y = 84 }
Menu.Scale    = 1.0

-- Banner
Menu.Banner = {
    enabled  = true,
    imageUrl = "https://i.imgur.com/rTPcs0v.jpeg",
    height   = 96,
}
Menu.bannerTexture = nil

-- Key states
Menu._keyStates = {}

-- ============================================================
--  ANTICHEAT  (optional panel)
-- ============================================================
function Menu.SetAnticheatInfo(list)
    Menu.AnticheatList = {}
    if type(list) ~= "table" then return end
    for _, name in ipairs(list) do
        table.insert(Menu.AnticheatList, name)
    end
end

-- ============================================================
--  HELPERS  – math / color
-- ============================================================
local function lerp(a, b, t)
    return a + (b - a) * t
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- Normalise 0-255 OR 0-1 float into 0-1
local function n(v)
    return v > 1.0 and v / 255.0 or v
end

local function lerpColor(cA, cB, t)
    return {
        lerp(cA[1], cB[1], t),
        lerp(cA[2], cB[2], t),
        lerp(cA[3], cB[3], t),
        cA[4] and cB[4] and lerp(cA[4], cB[4], t) or nil,
    }
end

-- accent gradient color by vertical position (0–1)
local function accentAt(t)
    return lerpColor(C.ACC1, C.ACC2, clamp(t, 0, 1))
end

-- ============================================================
--  SCALED GEOMETRY  (all sizes * Menu.Scale)
-- ============================================================
local function S(v)
    return v * (Menu.Scale or 1.0)
end

local function geo()
    local s = Menu.Scale or 1.0
    local g = {}
    for k, v in pairs(L) do g[k] = v * s end
    g.x = Menu.Position.x
    g.y = Menu.Position.y
    return g
end

-- Header height (banner or default)
local function headerH(g)
    return Menu.Banner.enabled and S(Menu.Banner.height) or g.HEADER_H
end

-- Total menu height for current state
local function menuHeight(g)
    local hH = headerH(g)
    local body = 0
    if Menu.OpenedCategory then
        local cat = Menu.Categories and Menu.Categories[Menu.OpenedCategory]
        if cat and cat.hasTabs and cat.tabs then
            local tab = cat.tabs[Menu.CurrentTab]
            local n2   = tab and tab.items and math.min(L.ITEMS_PAGE, #tab.items) or 0
            body = g.TAB_H + g.GAP + n2 * g.ITEM_H
        end
    else
        local totalCats = Menu.Categories and (#Menu.Categories - 1) or 0
        local vis = math.min(L.ITEMS_PAGE, totalCats)
        body = g.TAB_H + g.GAP + vis * g.ITEM_H
    end
    return hH + body + g.GAP + g.FOOTER_H
end

-- ============================================================
--  DRAW PRIMITIVES
-- ============================================================
local function drawRect(x, y, w, h, col, alpha)
    local a = alpha ~= nil and alpha or (col[4] or 1.0)
    local r, g2, b = n(col[1]), n(col[2]), n(col[3])
    a = n(a)
    if Susano.DrawFilledRect then
        Susano.DrawFilledRect(x, y, w, h, r, g2, b, a)
    elseif Susano.FillRect then
        Susano.FillRect(x, y, w, h, r, g2, b, a)
    elseif Susano.DrawRect then
        for i = 0, math.ceil(h) - 1 do
            Susano.DrawRect(x, y + i, w, 1, r, g2, b, a)
        end
    end
end

local function drawText(x, y, text, size, col, alpha)
    local a   = alpha ~= nil and alpha or (col[4] or 1.0)
    local sz  = size * (Menu.Scale or 1.0)
    Susano.DrawText(x, y, text, sz, n(col[1]), n(col[2]), n(col[3]), n(a))
end

-- Rounded rectangle via corner-fill technique
local function drawRounded(x, y, w, h, col, alpha, radius)
    radius = radius or 0
    if radius < 1 then
        drawRect(x, y, w, h, col, alpha)
        return
    end
    radius = math.min(radius, math.floor(math.min(w, h) / 2))
    -- center cross
    drawRect(x + radius, y,          w - 2 * radius, h,            col, alpha)
    drawRect(x,          y + radius, radius,          h - 2 * radius, col, alpha)
    drawRect(x + w - radius, y + radius, radius,     h - 2 * radius, col, alpha)
    -- corners
    for i = 0, radius - 1 do
        local sw = math.ceil(math.sqrt(math.max(0, radius * radius - i * i)))
        drawRect(x + radius - sw,     y + radius - 1 - i, sw, 1, col, alpha)
        drawRect(x + w - radius,      y + radius - 1 - i, sw, 1, col, alpha)
        drawRect(x + radius - sw,     y + h - radius + i, sw, 1, col, alpha)
        drawRect(x + w - radius,      y + h - radius + i, sw, 1, col, alpha)
    end
end

-- Vertical gradient rect (top→bottom two colours)
local function drawGradientV(x, y, w, h, colTop, colBot, alpha)
    alpha = alpha or 1.0
    local steps = math.max(1, math.ceil(h))
    for i = 0, steps - 1 do
        local t  = i / steps
        local mc = lerpColor(colTop, colBot, t)
        drawRect(x, y + i, w, 1, mc, alpha * n(mc[4] or 1.0))
    end
end

-- Thin horizontal line
local function drawLine(x, y, w, col, alpha)
    drawRect(x, y, w, 1, col, alpha)
end

-- Text width helper (safe fallback)
local function textW(text, size)
    if Susano.GetTextWidth then
        return Susano.GetTextWidth(text, size * (Menu.Scale or 1.0))
    end
    return #text * size * 0.55 * (Menu.Scale or 1.0)
end

-- Screen dimensions (safe)
local function screen()
    if Susano.GetScreenWidth then
        return Susano.GetScreenWidth(), Susano.GetScreenHeight()
    end
    return 1920, 1080
end

-- ============================================================
--  ACCENT BAR  (left glowing stripe per item)
-- ============================================================
local function drawAccentBar(x, y, h, t, alpha)
    local col = accentAt(t)
    drawRect(x, y + 2, S(L.ACCENT_W), h - 4, col, alpha * 0.9)
end

-- ============================================================
--  SCROLLBAR
-- ============================================================
local function drawScrollbar(x, y, visH, offset, total, alpha)
    if total <= L.ITEMS_PAGE then return end
    local g   = geo()
    local sbX = x + g.W - g.SB_PAD - g.SB_W
    local sbH = visH
    local maxScroll = total - L.ITEMS_PAGE
    local prog  = clamp(offset / math.max(1, maxScroll), 0, 1)
    local tH    = math.max(S(14), sbH * (L.ITEMS_PAGE / total))
    local tY    = y + prog * (sbH - tH)
    drawRect(sbX, y,  g.SB_W, sbH, C.SB_BG, alpha * 0.7)
    drawRect(sbX, tY, g.SB_W, tH,  C.SB_THUMB, alpha)
end

-- ============================================================
--  HEADER
-- ============================================================
function Menu.DrawHeader(alpha)
    local g  = geo()
    local x, y, w = g.x, g.y, g.W
    local hH = headerH(g)
    alpha = alpha or 1.0

    if Menu.Banner.enabled and Menu.bannerTexture and Menu.bannerTexture > 0 and Susano.DrawImage then
        Susano.DrawImage(Menu.bannerTexture, x, y, w, hH, 1, 1, 1, alpha, 0)
        -- subtle dark overlay at bottom for readability
        drawGradientV(x, y + hH - 20, w, 20,
            { 0, 0, 0, 0 }, { 0.04, 0.04, 0.07, 0.70 }, alpha)
    else
        -- Glassmorphism panel
        drawRounded(x, y, w, hH, C.BG_BASE, alpha, S(L.RADIUS_LG))
        -- accent gradient strip at top
        drawGradientV(x, y, w, S(2),
            C.ACC1, C.ACC2, alpha)
        -- logo
        local logo = "NEXUS"
        local sub  = "INTERFACE"
        local fs1  = 28
        local fs2  = 11
        local lw   = textW(logo, fs1)
        local sw2  = textW(sub, fs2)
        local cx   = x + w / 2
        drawText(cx - lw / 2, y + hH / 2 - S(fs1) / 2 - S(8),
            logo, fs1, C.TEXT_SEL, alpha)
        drawText(cx - sw2 / 2, y + hH / 2 + S(8),
            sub, fs2, C.ACC_DIM, alpha * 0.85)
        -- bottom border line
        drawLine(x, y + hH - 1, w, C.BORDER, alpha * 0.6)
    end
end

-- ============================================================
--  TABS  (inside category)
-- ============================================================
function Menu.DrawTabs(cat, x, y, w, alpha)
    if not cat or not cat.hasTabs or not cat.tabs then return end
    local g    = geo()
    local tH   = g.TAB_H
    local n2   = #cat.tabs
    local tW   = w / n2

    for i, tab in ipairs(cat.tabs) do
        local tx   = x + (i - 1) * tW
        local curW = (i == n2) and (x + w - tx) or (tW + 0.5)
        local sel  = (i == Menu.CurrentTab)

        if sel then
            drawRounded(tx, y, curW, tH, C.BG_TAB_S, alpha, S(L.RADIUS_SM))
            -- bottom accent line
            local ac = accentAt((i - 1) / math.max(1, n2 - 1))
            drawLine(tx, y + tH - S(2), curW, ac, alpha)
        else
            drawRect(tx, y, curW, tH, C.BG_TAB, alpha * 0.5)
        end

        local fs = 13
        local tw = textW(tab.name, fs)
        drawText(tx + curW / 2 - tw / 2, y + tH / 2 - S(fs) / 2,
            tab.name, fs,
            sel and C.TEXT_SEL or C.TEXT_DIM,
            sel and alpha or alpha * 0.75)
    end

    -- bottom separator
    drawLine(x, y + tH - 1, w, C.BORDER_LO, alpha * 0.4)
end

-- ============================================================
--  SINGLE ITEM
-- ============================================================
local function drawToggle(x, y, itemH, item, alpha)
    local g     = geo()
    local tW    = S(38)
    local tH    = S(20)
    local tX    = x + g.W - tW - g.PAD_X
    local tY    = y + itemH / 2 - tH / 2
    local rad   = tH / 2

    -- animate knob
    if item.animProg == nil then item.animProg = item.value and 1.0 or 0.0 end
    if item.animTgt  == nil then item.animTgt  = item.value and 1.0 or 0.0 end
    item.animProg = lerp(item.animProg, item.animTgt, EASE * 3)

    local bg = lerpColor(C.TOG_OFF, C.TOG_ON, item.animProg)
    drawRounded(tX, tY, tW, tH, bg, alpha, rad)

    local kS    = tH - S(4)
    local kY    = tY + S(2)
    local kXoff = tX + S(2)
    local kXon  = tX + tW - kS - S(2)
    local kX    = lerp(kXoff, kXon, item.animProg)
    drawRounded(kX, kY, kS, kS, C.KNOB, alpha, kS / 2)
end

local function drawSlider(x, y, itemH, item, alpha)
    local g     = geo()
    local sW    = S(100)
    local sH    = S(4)
    local sX    = x + g.W - sW - g.PAD_X - S(38)
    local sY    = y + itemH / 2 - sH / 2
    local minV  = item.min  or 0
    local maxV  = item.max  or 100
    local pct   = clamp((item.value or minV) - minV, 0, maxV - minV) / (maxV - minV)

    drawRounded(sX, sY, sW, sH, C.SLIDER_BG, alpha, S(2))
    if pct > 0 then
        local ac = lerpColor(C.ACC1, C.ACC2, pct)
        drawRounded(sX, sY, sW * pct, sH, ac, alpha, S(2))
    end
    -- thumb
    local tS = S(10)
    drawRounded(sX + sW * pct - tS / 2, sY + sH / 2 - tS / 2, tS, tS,
        C.KNOB, alpha, tS / 2)
    -- value label
    local val = string.format("%.0f", item.value or minV)
    local fs  = 11
    local vw  = textW(val, fs)
    drawText(sX + sW + S(7), sY - S(1), val, fs, C.TEXT_DIM, alpha * 0.9)
end

local function drawSelector(x, y, itemH, item, alpha)
    local g   = geo()
    local sel = item.selected or 1
    local opt = item.options and item.options[sel] or ""
    local txt = "‹ " .. opt .. " ›"
    local fs  = 13
    local tw  = textW(txt, fs)
    local ty  = y + itemH / 2 - S(fs) / 2
    drawText(x + g.W - tw - g.PAD_X, ty, txt, fs, C.ACC_DIM, alpha)
end

local function drawSeparator(x, y, w, itemH, item, alpha)
    local midY = y + itemH / 2
    local txt  = item.separatorText
    if txt and #txt > 0 then
        local fs = 11
        local tw = textW(txt, fs)
        local cx = x + w / 2
        drawText(cx - tw / 2, midY - S(fs) / 2, txt, fs, C.TEXT_DIM, alpha * 0.7)
        local barW = (w - tw - S(40)) / 2
        drawLine(x + S(12),        midY, barW, C.SEP, alpha * 0.5)
        drawLine(cx + tw / 2 + S(8), midY, barW, C.SEP, alpha * 0.5)
    else
        drawLine(x + S(12), midY, w - S(24), C.SEP, alpha * 0.4)
    end
end

function Menu.DrawItem(x, y, w, itemH, item, isSelected, isCat, itemIndex, totalItems, alpha)
    alpha = alpha or 1.0
    if item.isSeparator then
        drawSeparator(x, y, w, itemH, item, alpha)
        return
    end

    -- Background
    local bgAlpha = alpha * (isSelected and 1.0 or 0.55)
    drawRounded(x, y, w, itemH, isSelected and C.BG_ITEM_S or C.BG_ITEM, bgAlpha,
        S(L.RADIUS_ITEM))

    -- Animated accent bar (left)
    if isSelected then
        local t = (itemIndex or 1) / math.max(1, totalItems or 1)
        drawAccentBar(x, y, itemH, t, alpha)
    end

    -- Name
    local tx = x + S(L.PAD_X) + (isSelected and S(L.ACCENT_W + 4) or 0)
    local ty = y + itemH / 2 - S(17) / 2
    drawText(tx, ty, item.name, 15,
        isSelected and C.TEXT_SEL or C.TEXT,
        isSelected and alpha or alpha * 0.9)

    -- Category arrow
    if isCat then
        local arrow = "›"
        local aw    = textW(arrow, 17)
        local g     = geo()
        drawText(x + g.W - aw - S(L.PAD_X), ty, arrow, 17, C.ACC_DIM, alpha * 0.7)
        return
    end

    -- Controls
    local t2 = item.type
    if t2 == "toggle" then
        drawToggle(x, y, itemH, item, alpha)
    elseif t2 == "slider" then
        drawSlider(x, y, itemH, item, alpha)
    elseif t2 == "selector" then
        drawSelector(x, y, itemH, item, alpha)
    elseif t2 == "toggle_selector" then
        drawToggle(x, y, itemH, item, alpha)
        if item.options then
            local sel = item.selected or 1
            local opt = item.options[sel] or ""
            local txt = "‹ " .. opt .. " ›"
            local fs  = 12
            local g   = geo()
            local tw  = textW(txt, fs)
            local tgX = x + g.W - S(38) - g.PAD_X - tw - S(8)
            drawText(tgX, ty, txt, fs, C.TEXT_DIM, alpha * 0.85)
        end
    elseif t2 == "action" then
        local g   = geo()
        local key = item.bindKeyName
        if key then
            local fs  = 11
            local tw  = textW("[" .. key .. "]", fs)
            drawText(x + g.W - tw - g.PAD_X, ty + S(3), "[" .. key .. "]", fs,
                C.ACC_DIM, alpha * 0.7)
        end
    end
end

-- ============================================================
--  FOOTER
-- ============================================================
function Menu.DrawFooter(contentBottom, alpha)
    local g   = geo()
    local x   = g.x
    local w   = g.W
    local y   = contentBottom + g.GAP
    local h   = g.FOOTER_H
    alpha = alpha or 1.0

    drawRounded(x, y, w, h, C.BG_BASE, alpha * 0.9, S(L.RADIUS_SM))
    drawLine(x, y, w, C.BORDER, alpha * 0.4)

    -- left text
    local leftTxt = ".gg/sentexmodz"
    drawText(x + g.PAD_X, y + h / 2 - S(10) / 2, leftTxt, 10, C.TEXT_DIM, alpha * 0.7)

    -- right page counter
    local page = ""
    if Menu.OpenedCategory then
        local cat = Menu.Categories and Menu.Categories[Menu.OpenedCategory]
        if cat and cat.hasTabs and cat.tabs then
            local tab = cat.tabs[Menu.CurrentTab]
            if tab and tab.items then
                page = Menu.CurrentItem .. "/" .. #tab.items
            end
        end
    else
        if Menu.Categories then
            page = (Menu.CurrentCategory - 1) .. "/" .. (#Menu.Categories - 1)
        end
    end
    if #page > 0 then
        local fs = 10
        local pw = textW(page, fs)
        drawText(x + w - pw - g.PAD_X, y + h / 2 - S(fs) / 2,
            page, fs, C.ACC_DIM, alpha * 0.8)
    end
end

-- ============================================================
--  BACKGROUND  (glass panel + snowflakes)
-- ============================================================
Menu._snowflakes = (function()
    local t = {}
    math.randomseed(12345)
    for i = 1, 80 do
        t[i] = {
            x  = math.random() ,
            y  = math.random() ,
            vy = math.random(15, 60) / 10000,
            vx = math.random(-10, 10) / 10000,
            sz = math.random(1, 2),
        }
    end
    return t
end)()

function Menu.DrawBackground(totalH, alpha)
    local g = geo()
    alpha   = alpha or 1.0

    -- Main glass panel
    drawRounded(g.x, g.y, g.W, totalH, C.BG_BASE, alpha * 0.96, S(L.RADIUS_LG))

    -- Subtle top-edge gradient (accent glow)
    drawGradientV(g.x, g.y, g.W, S(2), C.ACC1, C.ACC2, alpha * 0.7)

    -- Outer border
    -- (simulate with slightly brighter inner-edge rects)
    drawLine(g.x,         g.y,           g.W, C.BORDER, alpha * 0.5)
    drawLine(g.x,         g.y + totalH - 1, g.W, C.BORDER_LO, alpha * 0.3)
    drawRect(g.x,         g.y, S(1), totalH, C.BORDER, alpha * 0.4)
    drawRect(g.x + g.W - S(1), g.y, S(1), totalH, C.BORDER_LO, alpha * 0.2)

    -- Snowflakes
    if Menu.ShowSnowflakes then
        for _, p in ipairs(Menu._snowflakes) do
            p.y = p.y + p.vy
            p.x = p.x + p.vx
            if p.y > 1 then p.y = 0; p.x = math.random() end
            if p.x < 0 then p.x = 1 elseif p.x > 1 then p.x = 0 end
            local px = g.x + p.x * g.W
            local py = g.y + p.y * totalH
            drawRect(px, py, p.sz, p.sz, C.SNOW, alpha * 0.6)
        end
    end
end

-- ============================================================
--  CATEGORY LIST  (main menu)
-- ============================================================
function Menu.DrawCategoryList(alpha)
    if not Menu.Categories then return end
    local g     = geo()
    local x     = g.x
    local hH    = headerH(g)
    local startY = g.y + hH

    -- Top-level tabs row (if present)
    if Menu.TopLevelTabs then
        local fakecat = { hasTabs = true, tabs = Menu.TopLevelTabs }
        Menu.DrawTabs(fakecat, x, startY, g.W, alpha)
        startY = startY + g.TAB_H + g.GAP
    else
        -- Section header bar
        local barH = g.TAB_H
        drawRounded(x, startY, g.W, barH, C.BG_PANEL, alpha * 0.8, S(L.RADIUS_SM))
        drawGradientV(x, startY + barH - S(2), g.W, S(2),
            C.ACC1, C.ACC2, alpha * 0.6)
        local title = Menu.Categories[1] and Menu.Categories[1].name or "MAIN MENU"
        local fs    = 13
        local tw    = textW(title, fs)
        drawText(x + g.W / 2 - tw / 2, startY + barH / 2 - S(fs) / 2,
            title, fs, C.TEXT_SEL, alpha)
        startY = startY + barH + g.GAP
    end

    -- Categories
    local total   = #Menu.Categories - 1
    local maxVis  = L.ITEMS_PAGE
    local offset  = Menu.CatScrollOffset
    -- scroll clamp
    if Menu.CurrentCategory > offset + maxVis + 1 then
        Menu.CatScrollOffset = Menu.CurrentCategory - maxVis - 1
    elseif Menu.CurrentCategory <= offset + 1 then
        Menu.CatScrollOffset = math.max(0, Menu.CurrentCategory - 2)
    end
    offset = Menu.CatScrollOffset

    local visible = 0
    for i = 1, math.min(maxVis, total) do
        local idx  = i + offset + 1
        if idx > #Menu.Categories then break end
        visible    = visible + 1
        local cat  = Menu.Categories[idx]
        local iY   = startY + (i - 1) * g.ITEM_H
        local isSel = (idx == Menu.CurrentCategory)

        -- Smooth category selector
        if isSel then
            if Menu._catSelY == 0 then Menu._catSelY = iY end
            Menu._catSelY = lerp(Menu._catSelY, iY, EASE)
            if math.abs(Menu._catSelY - iY) < 0.5 then Menu._catSelY = iY end
        end

        Menu.DrawItem(x, isSel and Menu._catSelY or iY, g.W, g.ITEM_H,
            { name = cat.name }, isSel, true, idx - 1, total, alpha)
    end

    -- Scrollbar
    if total > maxVis then
        drawScrollbar(x, startY, visible * g.ITEM_H, offset, total, alpha)
    end

    -- Footer
    local contentBottom = startY + visible * g.ITEM_H
    Menu.DrawFooter(contentBottom, alpha)
end

-- ============================================================
--  OPENED CATEGORY  (items)
-- ============================================================
function Menu.DrawOpenedCategory(alpha)
    if not Menu.Categories then return end
    local cat = Menu.Categories[Menu.OpenedCategory]
    if not cat or not cat.hasTabs or not cat.tabs then
        Menu.OpenedCategory = nil
        return
    end

    local g      = geo()
    local x      = g.x
    local hH     = headerH(g)
    local startY = g.y + hH

    -- Tabs
    Menu.DrawTabs(cat, x, startY, g.W, alpha)
    startY = startY + g.TAB_H + g.GAP

    local curTab = cat.tabs[Menu.CurrentTab]
    if not curTab or not curTab.items then
        Menu.DrawFooter(startY, alpha)
        return
    end

    local items   = curTab.items
    local total   = #items
    local maxVis  = L.ITEMS_PAGE

    -- Scroll clamping
    if Menu.CurrentItem > Menu.ItemScrollOffset + maxVis then
        Menu.ItemScrollOffset = Menu.CurrentItem - maxVis
    elseif Menu.CurrentItem <= Menu.ItemScrollOffset then
        Menu.ItemScrollOffset = math.max(0, Menu.CurrentItem - 1)
    end

    -- Count non-separator items for scrollbar
    local nonSep = 0
    for _, it in ipairs(items) do
        if not it.isSeparator then nonSep = nonSep + 1 end
    end

    local visible = 0
    for i = 1, math.min(maxVis, total) do
        local idx  = i + Menu.ItemScrollOffset
        if idx > total then break end
        visible    = visible + 1
        local item = items[idx]
        local iY   = startY + (i - 1) * g.ITEM_H
        local isSel = (idx == Menu.CurrentItem)

        -- Smooth item selector
        if isSel then
            if Menu._selY == 0 then Menu._selY = iY end
            Menu._selY = lerp(Menu._selY, iY, EASE)
            if math.abs(Menu._selY - iY) < 0.5 then Menu._selY = iY end
        end

        Menu.DrawItem(x, isSel and Menu._selY or iY, g.W, g.ITEM_H,
            item, isSel, false, idx, total, alpha)
    end

    if nonSep > 0 then
        drawScrollbar(x, startY, visible * g.ITEM_H, Menu.CurrentItem - 1, nonSep, alpha)
    end

    local contentBottom = startY + visible * g.ITEM_H
    Menu.DrawFooter(contentBottom, alpha)
end

-- ============================================================
--  LOADING BAR
-- ============================================================
function Menu.DrawLoadingBar(alpha)
    if alpha <= 0 then return end
    local sw, sh = screen()
    local w, h   = S(460), S(4)
    local x      = sw / 2 - w / 2
    local y      = sh - S(70)

    drawRounded(x, y, w, h, C.BG_PANEL, alpha * 0.9, S(2))
    if Menu.LoadingProgress > 0 then
        local ac = lerpColor(C.ACC1, C.ACC2, Menu.LoadingProgress / 100)
        drawRounded(x, y, w * (Menu.LoadingProgress / 100), h, ac, alpha, S(2))
        -- glow tip
        drawRect(x + w * (Menu.LoadingProgress / 100) - S(3), y, S(4), h,
            { 1, 1, 1, 0.5 }, alpha)
    end

    local pct = string.format("%.0f%%", Menu.LoadingProgress)
    local fs  = 14
    local pw  = textW(pct, fs)
    drawText(x + w / 2 - pw / 2, y - S(22), pct, fs, C.TEXT_SEL, alpha)

    local status = Menu.LoadingProgress >= 100 and "READY" or "LOADING"
    local stw    = textW(status, 11)
    drawText(x + w / 2 - stw / 2, y - S(40), status, 11, C.ACC_DIM, alpha * 0.9)
end

-- ============================================================
--  KEY SELECTOR  MODAL
-- ============================================================
function Menu.DrawKeySelector(alpha)
    if alpha <= 0 then return end
    local sw, sh = screen()
    local w, h   = S(380), S(130)
    local x      = sw / 2 - w / 2
    local y      = sh / 2 - h / 2 + S(80)

    drawRounded(x, y, w, h, C.BG_BASE, alpha * 0.97, S(L.RADIUS_LG))
    drawLine(x, y, w, C.BORDER, alpha * 0.6)
    drawGradientV(x, y, w, S(2), C.ACC1, C.ACC2, alpha * 0.8)

    local title = Menu.BindingItem and ("BIND: " .. Menu.BindingItem.name) or "ASSIGN MENU KEY"
    drawText(x + S(L.PAD_X), y + S(14), title, 13, C.ACC_DIM, alpha)

    local displayKey = "..."
    if Menu.SelectingKey  and Menu._tempKey      then displayKey = Menu._tempKey      end
    if Menu.SelectingBind and Menu._tempBindKey  then displayKey = Menu._tempBindKey  end
    if (not Menu.SelectingKey and not Menu.SelectingBind) then
        displayKey = Menu.SelectedKeyName or Menu.BindingKeyName or "..."
    end

    -- key box
    local bW, bH = S(72), S(42)
    local bX     = x + w - bW - S(L.PAD_X)
    local bY     = y + h / 2 - bH / 2
    drawRounded(bX, bY, bW, bH, C.BG_PANEL, alpha, S(L.RADIUS_SM))
    drawLine(bX, bY, bW, C.BORDER, alpha * 0.7)
    local kw = textW(displayKey, 16)
    drawText(bX + bW / 2 - kw / 2, bY + bH / 2 - S(8),
        displayKey, 16, { 1.0, 0.95, 0.40, 1 }, alpha)

    drawText(x + S(L.PAD_X), y + h / 2 - S(5), "Press any key …", 12, C.TEXT_DIM, alpha * 0.8)
    drawText(x + S(L.PAD_X), y + h - S(20), "[ENTER] confirm", 10, C.TEXT_DIM, alpha * 0.55)
end

-- ============================================================
--  KEYBINDS PANEL  (top-right HUD)
-- ============================================================
function Menu.DrawKeybindsHUD(alpha)
    if alpha <= 0 or not Menu.Categories then return end
    local binds = {}
    for _, cat in ipairs(Menu.Categories) do
        if cat.hasTabs and cat.tabs then
            for _, tab in ipairs(cat.tabs) do
                if tab.items then
                    for _, it in ipairs(tab.items) do
                        if it.bindKey and it.bindKeyName and
                           (it.type == "toggle" or it.type == "action") then
                            table.insert(binds, it)
                        end
                    end
                end
            end
        end
    end
    if #binds == 0 then return end

    local sw, _ = screen()
    local g     = geo()
    local w     = S(220)
    local h     = S(32) + #binds * S(20)
    local x     = sw - w - S(18)
    local y     = S(80)

    drawRounded(x, y, w, h, C.BG_BASE, alpha * 0.92, S(L.RADIUS_LG))
    drawLine(x, y, w, C.BORDER, alpha * 0.5)
    drawGradientV(x, y, w, S(2), C.ACC1, C.ACC2, alpha * 0.7)
    drawText(x + S(12), y + S(9), "HOTKEYS", 10, C.ACC_DIM, alpha)

    for i, it in ipairs(binds) do
        local lineY = y + S(26) + (i - 1) * S(19)
        local status = it.type == "toggle" and (it.value and " ●" or " ○") or ""
        drawText(x + S(12), lineY, it.name .. "  [" .. it.bindKeyName .. "]" .. status,
            10, it.value and C.TEXT_SEL or C.TEXT_DIM, alpha * 0.85)
    end
end

-- ============================================================
--  ANTICHEAT PANEL
-- ============================================================
function Menu.DrawAnticheatPanel(baseY, alpha)
    if #Menu.AnticheatList == 0 then return end
    local g    = geo()
    local x    = g.x
    local w    = g.W
    local y    = baseY + g.GAP
    local rows = math.ceil(#Menu.AnticheatList / 2)
    local h    = S(28) + rows * S(18)

    drawRounded(x, y, w, h, C.BG_BASE, alpha * 0.92, S(L.RADIUS_SM))
    drawLine(x, y, w, C.BORDER, alpha * 0.5)

    local title = "ANTICHEATS DETECTED"
    local fs    = 10
    local tw    = textW(title, fs)
    drawText(x + w / 2 - tw / 2, y + S(8), title,
        fs, C.ACC1, alpha)

    local colW = (w - S(24)) / 2
    local perCol = math.ceil(#Menu.AnticheatList / 2)
    for i, name in ipairs(Menu.AnticheatList) do
        local col = i > perCol and 1 or 0
        local row = col == 0 and (i - 1) or (i - perCol - 1)
        local ix  = x + S(12) + col * (colW + S(4))
        local iy  = y + S(22) + row * S(18)
        drawText(ix, iy, "▸ " .. name, 10, C.TEXT, alpha * 0.85)
    end
end

-- ============================================================
--  EDITOR MODE  (drag to reposition)
-- ============================================================
function Menu.HandleEditorMode()
    if not Menu.EditorMode then return end
    local sw, sh = screen()
    local lmb    = false
    if Susano.GetAsyncKeyState then
        local d = Susano.GetAsyncKeyState(0x01)
        lmb = d == true or d == 1
    end
    local mx, my = 0, 0
    if Susano.GetCursorPos then
        local c = Susano.GetCursorPos()
        if type(c) == "table" then
            mx = c[1] or c.x or 0
            my = c[2] or c.y or 0
        end
    end
    local g  = geo()
    local mH = menuHeight(g)
    if lmb and not Menu.EditorDragging then
        if mx >= g.x and mx <= g.x + g.W and
           my >= g.y and my <= g.y + mH then
            Menu.EditorDragging = true
            Menu._edgX = mx - Menu.Position.x
            Menu._edgY = my - Menu.Position.y
        end
    elseif not lmb then
        Menu.EditorDragging = false
    end
    if Menu.EditorDragging then
        Menu.Position.x = clamp(mx - Menu._edgX, 0, sw - L.W)
        Menu.Position.y = clamp(my - Menu._edgY, 0, sh - mH)
    end
end

-- ============================================================
--  INPUT  – key detection
-- ============================================================
local CAPTURE_KEYS = {
    0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,
    0x4E,0x4F,0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,
    0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,
    0x20,0x1B,0x08,0x09,0x10,0x11,0x12,
    0x25,0x26,0x27,0x28,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x7B,
    0x2D,0x2E,0x21,0x22,0x23,0x24,
}

local KEY_NAMES = {
    [0x08]="Backspace",[0x09]="Tab",[0x0D]="Enter",[0x10]="Shift",
    [0x11]="Ctrl",[0x12]="Alt",[0x1B]="ESC",[0x20]="Space",
    [0x21]="PgUp",[0x22]="PgDn",[0x23]="End",[0x24]="Home",
    [0x25]="Left",[0x26]="Up",[0x27]="Right",[0x28]="Down",
    [0x2D]="Insert",[0x2E]="Delete",
    [0x30]="0",[0x31]="1",[0x32]="2",[0x33]="3",[0x34]="4",
    [0x35]="5",[0x36]="6",[0x37]="7",[0x38]="8",[0x39]="9",
    [0x41]="A",[0x42]="B",[0x43]="C",[0x44]="D",[0x45]="E",
    [0x46]="F",[0x47]="G",[0x48]="H",[0x49]="I",[0x4A]="J",
    [0x4B]="K",[0x4C]="L",[0x4D]="M",[0x4E]="N",[0x4F]="O",
    [0x50]="P",[0x51]="Q",[0x52]="R",[0x53]="S",[0x54]="T",
    [0x55]="U",[0x56]="V",[0x57]="W",[0x58]="X",[0x59]="Y",
    [0x5A]="Z",[0x70]="F1",[0x71]="F2",[0x72]="F3",[0x73]="F4",
    [0x74]="F5",[0x75]="F6",[0x76]="F7",[0x77]="F8",[0x78]="F9",
    [0x79]="F10",[0x7A]="F11",[0x7B]="F12",
}

function Menu.GetKeyName(k)
    return KEY_NAMES[k] or string.format("0x%02X", k)
end

function Menu.IsKeyDown(k)
    if not Susano.GetAsyncKeyState then return false end
    local d = Susano.GetAsyncKeyState(k)
    return d == true or d == 1
end

function Menu.IsKeyJustPressed(k)
    if not Susano.GetAsyncKeyState then return false end
    local d, p = Susano.GetAsyncKeyState(k)
    local was  = Menu._keyStates[k] or false
    Menu._keyStates[k] = (d == true)
    return (p == true) or ((d == true) and not was)
end

-- ============================================================
--  NAVIGATION HELPERS
-- ============================================================
local function nextNonSep(items, idx, dir)
    local n2   = #items
    local tries = 0
    repeat
        idx   = idx + dir
        if idx < 1 then idx = n2 elseif idx > n2 then idx = 1 end
        tries = tries + 1
    until tries > n2 or (items[idx] and not items[idx].isSeparator)
    return idx
end

local function activateItem(item)
    if not item or item.isSeparator then return end
    if item.type == "toggle" or item.type == "toggle_selector" then
        item.value   = not item.value
        item.animTgt = item.value and 1.0 or 0.0
        -- Named effects
        if item.name == "Snowflakes"          then Menu.ShowSnowflakes = item.value end
        if item.name == "Keybinds overlay"    then Menu.ShowKeybinds   = item.value end
        if item.name == "Editor mode"         then Menu.EditorMode      = item.value end
        if item.onClick then item.onClick(item.value) end
    elseif item.type == "action" then
        if item.name == "Set menu key" then
            Menu.SelectingKey = true; Menu._tempKey = nil
        end
        if item.onClick then item.onClick() end
    elseif item.type == "selector" then
        if item.onClick then item.onClick(item.selected, item.options and item.options[item.selected]) end
    end
end

function Menu.UpdateCategoriesFromTopTab()
    if not Menu.TopLevelTabs then return end
    local top = Menu.TopLevelTabs[Menu.CurrentTopTab]
    if not top then return end
    Menu.Categories = { { name = top.name } }
    for _, cat in ipairs(top.categories or {}) do
        table.insert(Menu.Categories, cat)
    end
    Menu.CurrentCategory  = 2
    Menu.CatScrollOffset  = 0
    Menu.OpenedCategory   = nil
    Menu._catSelY         = 0
    if top.autoOpen then
        Menu.OpenedCategory  = 2
        Menu.CurrentTab      = 1
        Menu.ItemScrollOffset = 0
        Menu.CurrentItem     = 1
        Menu._selY           = 0
    end
end

-- ============================================================
--  MAIN INPUT HANDLER
-- ============================================================
function Menu.HandleInput()
    if Menu.IsLoading or not Menu.LoadingComplete then return end
    if Menu.InputOpen then return end  -- handled by input modal

    -- ── Key binding for items (F9 trigger) ──────────────────
    if Menu.SelectingBind then
        if Menu.IsKeyJustPressed(0x0D) then
            if Menu.BindingKey and Menu.BindingItem then
                Menu.BindingItem.bindKey     = Menu.BindingKey
                Menu.BindingItem.bindKeyName = Menu.BindingKeyName
            end
            Menu.SelectingBind = false
            Menu.BindingItem   = nil
            Menu._tempBindKey  = nil
        else
            for _, k in ipairs(CAPTURE_KEYS) do
                if k ~= 0x0D and Menu.IsKeyJustPressed(k) then
                    Menu.BindingKey     = k
                    Menu.BindingKeyName = Menu.GetKeyName(k)
                    Menu._tempBindKey   = Menu.BindingKeyName
                    break
                end
            end
        end
        return
    end

    -- ── Menu-open key assignment ─────────────────────────────
    if Menu.SelectingKey then
        if Menu.IsKeyJustPressed(0x0D) then
            if Menu.SelectedKey then Menu.SelectingKey = false; Menu._tempKey = nil end
        else
            for _, k in ipairs(CAPTURE_KEYS) do
                if k ~= 0x0D and Menu.IsKeyJustPressed(k) then
                    Menu.SelectedKey     = k
                    Menu.SelectedKeyName = Menu.GetKeyName(k)
                    Menu._tempKey        = Menu.SelectedKeyName
                    break
                end
            end
        end
        return
    end

    -- ── Global hotkeys (always active) ──────────────────────
    if Menu.Categories then
        for _, cat in ipairs(Menu.Categories) do
            if cat.hasTabs and cat.tabs then
                for _, tab in ipairs(cat.tabs) do
                    if tab.items then
                        for _, it in ipairs(tab.items) do
                            if it.bindKey and Menu.IsKeyJustPressed(it.bindKey) then
                                activateItem(it)
                            end
                        end
                    end
                end
            end
        end
    end

    -- ── Toggle menu visibility ───────────────────────────────
    local toggleKey = Menu.SelectedKey or 0x31   -- default: numpad 1
    if Menu.IsKeyJustPressed(toggleKey) then
        Menu.Visible = not Menu.Visible
        if not Menu.Visible and not Menu.ShowKeybinds then
            if Susano.ResetFrame then Susano.ResetFrame() end
        end
    end

    if not Menu.Visible then return end

    -- ── Editor drag ─────────────────────────────────────────
    if Menu.EditorMode then
        Menu.HandleEditorMode()
        return
    end

    -- ── Navigation ──────────────────────────────────────────
    if Menu.OpenedCategory then
        local cat = Menu.Categories and Menu.Categories[Menu.OpenedCategory]
        if not cat or not cat.hasTabs or not cat.tabs then
            Menu.OpenedCategory = nil; return
        end
        local tab = cat.tabs[Menu.CurrentTab]
        if not tab or not tab.items then return end
        local items = tab.items

        if Menu.IsKeyJustPressed(0x26) then      -- Up
            Menu.CurrentItem = nextNonSep(items, Menu.CurrentItem, -1)
        elseif Menu.IsKeyJustPressed(0x28) then  -- Down
            Menu.CurrentItem = nextNonSep(items, Menu.CurrentItem,  1)
        elseif Menu.IsKeyJustPressed(0x25) then  -- Left  – slider / selector
            local it = items[Menu.CurrentItem]
            if it then
                if it.type == "slider" then
                    local step = it.step or 1
                    it.value = math.max(it.min or 0, (it.value or 0) - step)
                    if it.name == "Smooth factor" then Menu.SmoothFactor = it.value / 100 end
                    if it.name == "Menu scale"    then Menu.Scale        = it.value / 100 end
                    if it.onClick then it.onClick(it.value) end
                elseif it.type == "selector" or it.type == "toggle_selector" then
                    local idx = (it.selected or 1) - 1
                    if idx < 1 then idx = #it.options end
                    it.selected = idx
                    if it.onClick then it.onClick(it.selected, it.options[it.selected]) end
                end
            end
        elseif Menu.IsKeyJustPressed(0x27) then  -- Right – slider / selector
            local it = items[Menu.CurrentItem]
            if it then
                if it.type == "slider" then
                    local step = it.step or 1
                    it.value = math.min(it.max or 100, (it.value or 0) + step)
                    if it.name == "Smooth factor" then Menu.SmoothFactor = it.value / 100 end
                    if it.name == "Menu scale"    then Menu.Scale        = it.value / 100 end
                    if it.onClick then it.onClick(it.value) end
                elseif it.type == "selector" or it.type == "toggle_selector" then
                    local idx = (it.selected or 1) + 1
                    if idx > #it.options then idx = 1 end
                    it.selected = idx
                    if it.onClick then it.onClick(it.selected, it.options[it.selected]) end
                end
            end
        elseif Menu.IsKeyJustPressed(0x51) then  -- Q  – prev tab / top tab
            if Menu.CurrentTab > 1 then
                Menu.CurrentTab = Menu.CurrentTab - 1
                local nt = cat.tabs[Menu.CurrentTab]
                Menu.CurrentItem = nt and nt.items and nextNonSep(nt.items, 0, 1) or 1
                Menu._selY = 0
            elseif Menu.TopLevelTabs then
                Menu.CurrentTopTab = Menu.CurrentTopTab - 1
                if Menu.CurrentTopTab < 1 then Menu.CurrentTopTab = #Menu.TopLevelTabs end
                Menu.UpdateCategoriesFromTopTab()
            end
        elseif Menu.IsKeyJustPressed(0x45) then  -- E  – next tab / top tab
            if Menu.CurrentTab < #cat.tabs then
                Menu.CurrentTab = Menu.CurrentTab + 1
                local nt = cat.tabs[Menu.CurrentTab]
                Menu.CurrentItem = nt and nt.items and nextNonSep(nt.items, 0, 1) or 1
                Menu._selY = 0
            elseif Menu.TopLevelTabs then
                Menu.CurrentTopTab = Menu.CurrentTopTab + 1
                if Menu.CurrentTopTab > #Menu.TopLevelTabs then Menu.CurrentTopTab = 1 end
                Menu.UpdateCategoriesFromTopTab()
            end
        elseif Menu.IsKeyJustPressed(0x0D) then  -- Enter – activate
            activateItem(items[Menu.CurrentItem])
        elseif Menu.IsKeyJustPressed(0x08) then  -- Backspace – back
            Menu.OpenedCategory  = nil
            Menu.CurrentItem     = 1
            Menu.CurrentTab      = 1
            Menu.ItemScrollOffset = 0
            Menu._selY           = 0
        elseif Menu.IsKeyJustPressed(0x78) then  -- F9 – bind key
            local it = items[Menu.CurrentItem]
            if it and not it.isSeparator then
                Menu.SelectingBind   = true
                Menu.BindingItem     = it
                Menu.BindingKey      = it.bindKey
                Menu.BindingKeyName  = it.bindKeyName
                Menu._tempBindKey    = it.bindKeyName or "..."
            end
        end
    else
        -- Main category list navigation
        if Menu.IsKeyJustPressed(0x26) then       -- Up
            Menu.CurrentCategory = Menu.CurrentCategory - 1
            if Menu.CurrentCategory < 2 then
                Menu.CurrentCategory = #Menu.Categories
            end
        elseif Menu.IsKeyJustPressed(0x28) then   -- Down
            Menu.CurrentCategory = Menu.CurrentCategory + 1
            if Menu.CurrentCategory > #Menu.Categories then
                Menu.CurrentCategory = 2
            end
        elseif Menu.IsKeyJustPressed(0x25) or Menu.IsKeyJustPressed(0x41) then  -- Left/A
            if Menu.TopLevelTabs then
                Menu.CurrentTopTab = Menu.CurrentTopTab - 1
                if Menu.CurrentTopTab < 1 then Menu.CurrentTopTab = #Menu.TopLevelTabs end
                Menu.UpdateCategoriesFromTopTab()
            end
        elseif Menu.IsKeyJustPressed(0x27) or Menu.IsKeyJustPressed(0x45) then  -- Right/E
            if Menu.TopLevelTabs then
                Menu.CurrentTopTab = Menu.CurrentTopTab + 1
                if Menu.CurrentTopTab > #Menu.TopLevelTabs then Menu.CurrentTopTab = 1 end
                Menu.UpdateCategoriesFromTopTab()
            end
        elseif Menu.IsKeyJustPressed(0x0D) then   -- Enter – open category
            local cat = Menu.Categories and Menu.Categories[Menu.CurrentCategory]
            if cat and cat.hasTabs and cat.tabs then
                Menu.OpenedCategory  = Menu.CurrentCategory
                Menu.CurrentTab      = 1
                Menu.ItemScrollOffset = 0
                Menu._selY           = 0
                local t1 = cat.tabs[1]
                Menu.CurrentItem = t1 and t1.items and nextNonSep(t1.items, 0, 1) or 1
            end
        elseif Menu.IsKeyJustPressed(0x08) then   -- Backspace – close
            Menu.Visible = false
        end
    end
end

-- ============================================================
--  INPUT TEXT MODAL
-- ============================================================
function Menu.OpenInput(title, subtitle, callback)
    if type(subtitle) == "function" then callback, subtitle = subtitle, "Type below" end
    Menu.InputTitle    = title or "Input"
    Menu.InputSubtitle = subtitle or "Type below"
    Menu.InputText     = ""
    Menu.InputCallback = callback
    Menu.InputOpen     = true
    Menu.SelectingKey  = false
    Menu.SelectingBind = false
end

function Menu.DrawInputModal()
    if not Menu.InputOpen then return end
    local sw, sh = screen()
    local w, h   = S(320), S(130)
    local x      = sw / 2 - w / 2
    local y      = sh / 2 - h / 2

    drawRounded(x, y, w, h, C.BG_BASE, 0.97, S(L.RADIUS_LG))
    drawLine(x, y, w, C.BORDER, 0.8)
    drawGradientV(x, y, w, S(2), C.ACC1, C.ACC2, 1.0)

    drawText(x + S(L.PAD_X), y + S(12), Menu.InputTitle, 14, C.TEXT_SEL, 1.0)
    drawText(x + S(L.PAD_X), y + S(32), Menu.InputSubtitle, 11, C.TEXT_DIM, 0.8)

    -- Text box
    local bX, bY = x + S(L.PAD_X), y + S(54)
    local bW, bH = w - S(L.PAD_X) * 2, S(28)
    drawRounded(bX, bY, bW, bH, C.BG_PANEL, 1.0, S(L.RADIUS_SM))
    drawLine(bX, bY, bW, C.BORDER, 0.8)

    local cursor = (math.floor((GetGameTimer and GetGameTimer() or 0) / 500) % 2 == 0) and "|" or ""
    local display = Menu.InputText
    if #display > 28 then display = "…" .. display:sub(-26) end
    drawText(bX + S(8), bY + bH / 2 - S(7), display .. cursor, 13, C.TEXT, 1.0)

    drawText(x + S(L.PAD_X), y + h - S(16),
        "[ENTER] confirm  [ESC] cancel", 9, C.TEXT_DIM, 0.6)

    -- Key capture
    if Menu.IsKeyJustPressed(0x0D) then
        Menu.InputOpen = false
        if Menu.InputCallback then Menu.InputCallback(Menu.InputText) end
    elseif Menu.IsKeyJustPressed(0x1B) then
        Menu.InputOpen = false
    elseif Menu.IsKeyJustPressed(0x08) then
        Menu.InputText = Menu.InputText:sub(1, -2)
    else
        local shift = Menu.IsKeyDown(0x10) or Menu.IsKeyDown(0xA0) or Menu.IsKeyDown(0xA1)
        for k = 0x41, 0x5A do
            if Menu.IsKeyJustPressed(k) then
                local ch = string.char(k)
                Menu.InputText = Menu.InputText .. (shift and ch or ch:lower())
            end
        end
        for k = 0x30, 0x39 do
            if Menu.IsKeyJustPressed(k) then Menu.InputText = Menu.InputText .. string.char(k) end
        end
        if Menu.IsKeyJustPressed(0x20) then Menu.InputText = Menu.InputText .. " " end
        if Menu.IsKeyJustPressed(0xBD) then
            Menu.InputText = Menu.InputText .. (shift and "_" or "-")
        end
    end
end

-- ============================================================
--  BANNER LOADER
-- ============================================================
function Menu.LoadBannerTexture(url)
    if not url or url == "" then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end
    CreateThread(function()
        local ok, body = Susano.HttpGet(url)
        if ok == 200 and body and #body > 0 then
            local tex, w, h = Susano.LoadTextureFromBuffer(body)
            if tex and tex ~= 0 then
                Menu.bannerTexture = tex
            end
        end
    end)
end

-- ============================================================
--  MASTER RENDER
-- ============================================================
function Menu.Render()
    -- Bootstrap categories
    if Menu.TopLevelTabs and not Menu.Categories then
        Menu.UpdateCategoriesFromTopTab()
    end
    if not Susano.BeginFrame then return end

    local dt   = (GetFrameTime and GetFrameTime()) or 0.016
    local fade = clamp(dt * 6.0, 0, 1)

    -- Update alphas
    local targetMenuAlpha = (Menu.Visible and Menu.LoadingComplete) and 1.0 or 0.0
    Menu._menuAlpha = lerp(Menu._menuAlpha, targetMenuAlpha, fade)

    local targetLoadAlpha = Menu.IsLoading and 1.0 or 0.0
    Menu._loadAlpha = lerp(Menu._loadAlpha, targetLoadAlpha, fade)

    local targetKeyAlpha = (Menu.SelectingKey or Menu.SelectingBind) and 1.0 or 0.0
    Menu._keySelectorAlpha = lerp(Menu._keySelectorAlpha, targetKeyAlpha, fade)

    local targetKbAlpha = Menu.ShowKeybinds and 1.0 or 0.0
    Menu._keybindsAlpha = lerp(Menu._keybindsAlpha, targetKbAlpha, fade)

    Susano.BeginFrame()

    -- Keybinds HUD (always visible when enabled, even menu hidden)
    if Menu._keybindsAlpha > 0.01 then
        Menu.DrawKeybindsHUD(Menu._keybindsAlpha)
    end

    -- Main menu
    if Menu._menuAlpha > 0.01 then
        local g  = geo()
        local mH = menuHeight(g)
        local a  = Menu._menuAlpha

        Menu.DrawBackground(mH, a)
        Menu.DrawHeader(a)

        if Menu.OpenedCategory then
            Menu.DrawOpenedCategory(a)
        else
            Menu.DrawCategoryList(a)
        end

        -- Anticheat panel below footer
        if #Menu.AnticheatList > 0 then
            Menu.DrawAnticheatPanel(g.y + mH, a)
        end

        -- Editor mode indicator
        if Menu.EditorMode then
            local fs = 10
            drawText(g.x + S(L.PAD_X), g.y + mH + S(4),
                "EDITOR MODE  [drag to reposition]", fs, C.ACC1, a * 0.7)
        end
    end

    -- Modals
    if Menu.InputOpen then Menu.DrawInputModal() end

    if Menu._loadAlpha > 0.01 then
        Menu.DrawLoadingBar(Menu._loadAlpha)
    end

    if Menu._keySelectorAlpha > 0.01 then
        Menu.DrawKeySelector(Menu._keySelectorAlpha)
    end

    -- Custom render hook
    if Menu.OnRender then pcall(Menu.OnRender) end

    if Susano.SubmitFrame then Susano.SubmitFrame() end

    -- Disable overlay when nothing is drawn
    local anythingVisible = Menu._menuAlpha > 0.01
        or Menu._loadAlpha > 0.01
        or Menu._keySelectorAlpha > 0.01
        or Menu._keybindsAlpha > 0.01
        or Menu.InputOpen
    if Susano.EnableOverlay then
        Susano.EnableOverlay(anythingVisible or Menu.EditorMode)
    end
    if not anythingVisible then
        if Susano.ResetFrame then Susano.ResetFrame() end
    end
end

-- ============================================================
--  STARTUP THREADS
-- ============================================================
CreateThread(function()
    Menu.LoadingStart = GetGameTimer and GetGameTimer() or 0
    while Menu.IsLoading do
        local now     = GetGameTimer and GetGameTimer() or Menu.LoadingStart
        local elapsed = now - Menu.LoadingStart
        Menu.LoadingProgress = clamp((elapsed / Menu.LoadingDuration) * 100, 0, 100)
        if Menu.LoadingProgress >= 100 then
            Menu.IsLoading       = false
            Menu.LoadingComplete = true
            Menu.SelectingKey    = true   -- prompt for menu key
            break
        end
        Wait(FPS_MS)
    end
end)

CreateThread(function()
    while true do
        Menu.Render()
        if Menu.LoadingComplete then Menu.HandleInput() end
        Wait(FPS_MS)
    end
end)

-- Banner load
if Menu.Banner.enabled and Menu.Banner.imageUrl then
    Menu.LoadBannerTexture(Menu.Banner.imageUrl)
end

-- ============================================================
return Menu
