-- ============================================================
--  NEXUS UI  |  Menu Library  ULTRA PRO V3
--  Glassmorphism · Smoothstep Animations · Mouse Support
--  Hybrid Input (Keyboard + Mouse) · Theme System
-- ============================================================

local Menu = {}

-- ============================================================
-- CORE CONFIG
-- ============================================================

local function smooth(a, b, t)
    t = t * t * (3 - 2 * t)
    return a + (b - a) * t
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

-- ============================================================
-- THEME SYSTEM (DYNAMIC)
-- ============================================================

Menu.Theme = {
    accent1 = {0.10, 0.85, 0.95},
    accent2 = {0.35, 0.45, 1.00},
}

function Menu.SetAccent(r,g,b)
    Menu.Theme.accent1 = {r,g,b}
    Menu.Theme.accent2 = {math.max(0,r*0.6), math.max(0,g*0.8), math.min(1,b+0.15)}
end

local C = {
    bg      = {0.04,0.04,0.07,0.94},
    panel   = {0.06,0.06,0.10,0.90},
    item    = {0.08,0.08,0.13,0.70},
    item_s  = {0.12,0.12,0.20,0.95},
    text    = {0.95,0.95,1.0,1},
    dim     = {0.55,0.55,0.7,1},
}

-- ============================================================
-- LAYOUT (compact v3)
-- ============================================================

local L = {
    W = 300,
    ITEM_H = 30,
    HEADER_H = 78,
    TAB_H = 26,
    PAD = 10,
    R = 6
}

-- ============================================================
-- STATE
-- ============================================================

Menu.Visible = false
Menu.Categories = nil
Menu.CurrentCategory = 2
Menu.CurrentTab = 1
Menu.CurrentItem = 1
Menu.OpenedCategory = nil

Menu.Scroll = 0
Menu.selY = 0

Menu.Mouse = {x=0,y=0,down=false,pressed=false}
Menu.Hover = nil

Menu.Position = {x=30,y=90}
Menu.Scale = 1.0

Menu.Theme.accent1 = {0.1,0.85,0.95}
Menu.Theme.accent2 = {0.35,0.45,1.0}

-- ============================================================
-- INPUT HELPERS
-- ============================================================

local function getMouse()
    if Susano.GetCursorPos then
        local c = Susano.GetCursorPos()
        Menu.Mouse.x = c[1] or 0
        Menu.Mouse.y = c[2] or 0
    end

    if Susano.GetAsyncKeyState then
        local d = Susano.GetAsyncKeyState(0x01)
        Menu.Mouse.pressed = (d == true or d == 1) and not Menu.Mouse.down
        Menu.Mouse.down = (d == true or d == 1)
    end
end

local function inside(x,y,w,h)
    return Menu.Mouse.x >= x and Menu.Mouse.x <= x+w
       and Menu.Mouse.y >= y and Menu.Mouse.y <= y+h
end

-- ============================================================
-- DRAW HELPERS
-- ============================================================

local function rect(x,y,w,h,c,a)
    a = a or c[4] or 1
    Susano.DrawFilledRect(x,y,w,h,c[1],c[2],c[3],a)
end

local function text(x,y,t,s,c,a)
    Susano.DrawText(x,y,t,s,c[1],c[2],c[3],a or 1)
end

local function grad(x,y,w,h)
    for i=0,h do
        local t=i/h
        local c={
            lerp(Menu.Theme.accent1[1],Menu.Theme.accent2[1],t),
            lerp(Menu.Theme.accent1[2],Menu.Theme.accent2[2],t),
            lerp(Menu.Theme.accent1[3],Menu.Theme.accent2[3],t),
        }
        rect(x,y+i,w,1,c,0.8)
    end
end

-- ============================================================
-- ITEM ACTIVATION
-- ============================================================

local function activate(it)
    if not it then return end

    if it.type=="toggle" then
        it.value = not it.value
        if it.onClick then it.onClick(it.value) end
    elseif it.type=="action" then
        if it.onClick then it.onClick() end
    end
end

-- ============================================================
-- ITEM DRAW (ULTRA SMOOTH)
-- ============================================================

local function drawItem(x,y,w,it,sel,i,total)

    local hover = inside(x,y,w,L.ITEM_H)
    if hover then Menu.Hover = it end

    local bg = sel and C.item_s or (hover and {0.10,0.10,0.18,0.9} or C.item)
    rect(x,y,w,L.ITEM_H,bg,0.9)

    if sel then
        local t=i/total
        local c={
            lerp(Menu.Theme.accent1[1],Menu.Theme.accent2[1],t),
            lerp(Menu.Theme.accent1[2],Menu.Theme.accent2[2],t),
            lerp(Menu.Theme.accent1[3],Menu.Theme.accent2[3],t),
        }
        rect(x,y,3,L.ITEM_H,c,1)
    end

    text(x+12,y+8,it.name or "item",13,sel and C.text or C.dim,1)

    -- CLICK
    if hover and Menu.Mouse.pressed then
        activate(it)
    end
end

-- ============================================================
-- CATEGORY VIEW
-- ============================================================

function Menu.DrawCategories()
    local x,y = Menu.Position.x, Menu.Position.y
    local w = L.W

    local startY = y + L.HEADER_H

    rect(x,y,w,L.HEADER_H,C.bg,1)
    grad(x,y,w,3)

    local total = #Menu.Categories - 1

    for i=1,total do
        local cat = Menu.Categories[i+1]
        local yy = startY + (i-1)*L.ITEM_H

        local sel = (Menu.CurrentCategory==i+1)

        if inside(x,yy,w,L.ITEM_H) and Menu.Mouse.pressed then
            Menu.CurrentCategory=i+1
        end

        drawItem(x,yy,w,cat,sel,i,total)
    end
end

-- ============================================================
-- OPEN CATEGORY
-- ============================================================

function Menu.DrawOpened()
    local x,y = Menu.Position.x, Menu.Position.y
    local w = L.W

    local cat = Menu.Categories[Menu.CurrentCategory]
    if not cat or not cat.tabs then return end

    local tab = cat.tabs[Menu.CurrentTab]
    if not tab then return end

    rect(x,y,w,L.HEADER_H,C.bg,1)
    grad(x,y,w,3)

    local startY = y + L.HEADER_H + 10

    local items = tab.items or {}
    local total = #items

    for i,it in ipairs(items) do
        local yy = startY + (i-1)*L.ITEM_H
        local sel = (i==Menu.CurrentItem)

        if inside(x,yy,w,L.ITEM_H) and Menu.Mouse.pressed then
            Menu.CurrentItem=i
            activate(it)
        end

        drawItem(x,yy,w,it,sel,i,total)
    end
end

-- ============================================================
-- MAIN RENDER
-- ============================================================

function Menu.Render()

    getMouse()

    if not Susano.BeginFrame then return end
    Susano.BeginFrame()

    if Menu.Visible and Menu.Categories then
        if Menu.OpenedCategory then
            Menu.DrawOpened()
        else
            Menu.DrawCategories()
        end
    end

    Susano.SubmitFrame()
end

-- ============================================================
-- INPUT LOOP
-- ============================================================

CreateThread(function()
    while true do
        Menu.Render()
        Wait(0)
    end
end)

-- ============================================================
-- KEY TOGGLE (default F1)
-- ============================================================

CreateThread(function()
    while true do
        if Susano.GetAsyncKeyState and Susano.GetAsyncKeyState(0x70) then
            Menu.Visible = not Menu.Visible
            Wait(300)
        end
        Wait(0)
    end
end)

-- ============================================================
-- RETURN
-- ============================================================

return Menu
