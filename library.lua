-- ============================================================
--  NEXUS UI  |  V4 ULTRA INSANE EDITION
--  Smooth UI Engine · Mouse Interaction · Banner System
--  Inertia Scroll · Glass UI · Theme Engine
-- ============================================================

local Menu = {}

-- ============================================================
-- CONFIG
-- ============================================================

local function lerp(a,b,t) return a + (b-a)*t end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function smooth(t) return t*t*(3-2*t) end

-- ============================================================
-- THEME
-- ============================================================

Menu.Theme = {
    a1 = {0.10,0.85,0.95},
    a2 = {0.35,0.45,1.00}
}

function Menu.SetAccent(r,g,b)
    Menu.Theme.a1 = {r,g,b}
    Menu.Theme.a2 = {r*0.6,g*0.8,math.min(1,b+0.15)}
end

-- ============================================================
-- UI CONSTANTS
-- ============================================================

local C = {
    bg = {0.04,0.04,0.07,0.94},
    panel = {0.06,0.06,0.10,0.90},
    item = {0.08,0.08,0.13,0.75},
    item_s = {0.12,0.12,0.20,0.95},
    text = {0.95,0.95,1,1},
    dim = {0.6,0.6,0.75,1}
}

local L = {
    W = 310,
    ITEM_H = 30,
    HEADER_H = 90,
    PAD = 12
}

-- ============================================================
-- BANNERS (YOUR IMAGES)
-- ============================================================

Menu.Banner = {
    main = "https://i.imgur.com/KNnAjq7.jpeg",
    key  = "https://i.imgur.com/3dSCLwF.jpeg"
}

Menu.TextureMain = nil
Menu.TextureKey = nil

-- ============================================================
-- STATE
-- ============================================================

Menu.Visible = false
Menu.Categories = nil
Menu.CurrentCategory = 2
Menu.CurrentItem = 1
Menu.Opened = false

Menu.Mouse = {x=0,y=0,down=false,pressed=false}
Menu.Hover = nil

Menu.Scroll = 0
Menu.ScrollVel = 0

Menu.Position = {x=40,y=90}

-- ============================================================
-- INPUT
-- ============================================================

local function updateMouse()
    if Susano.GetCursorPos then
        local c = Susano.GetCursorPos()
        Menu.Mouse.x = c[1] or 0
        Menu.Mouse.y = c[2] or 0
    end

    if Susano.GetAsyncKeyState then
        local d = Susano.GetAsyncKeyState(0x01)
        Menu.Mouse.pressed = (d==true or d==1) and not Menu.Mouse.down
        Menu.Mouse.down = (d==true or d==1)
    end
end

local function inside(x,y,w,h)
    return Menu.Mouse.x>=x and Menu.Mouse.x<=x+w and Menu.Mouse.y>=y and Menu.Mouse.y<=y+h
end

-- ============================================================
-- DRAW HELPERS
-- ============================================================

local function rect(x,y,w,h,c,a)
    Susano.DrawFilledRect(x,y,w,h,c[1],c[2],c[3],a or 1)
end

local function text(x,y,t,s,c,a)
    Susano.DrawText(x,y,t,s,c[1],c[2],c[3],a or 1)
end

local function gradient(x,y,w,h)
    for i=0,h do
        local t=i/h
        local c={
            lerp(Menu.Theme.a1[1],Menu.Theme.a2[1],t),
            lerp(Menu.Theme.a1[2],Menu.Theme.a2[2],t),
            lerp(Menu.Theme.a1[3],Menu.Theme.a2[3],t),
        }
        rect(x,y+i,w,1,c,0.9)
    end
end

-- ============================================================
-- CLICK ACTION
-- ============================================================

local function activate(it)
    if not it then return end
    if it.type=="toggle" then
        it.value = not it.value
    elseif it.type=="action" and it.onClick then
        it.onClick()
    end
end

-- ============================================================
-- ITEM
-- ============================================================

local function drawItem(x,y,w,it,sel,i,total)

    local hover = inside(x,y,w,L.ITEM_H)
    if hover then Menu.Hover = it end

    local bg = sel and C.item_s or (hover and {0.10,0.10,0.18,0.9} or C.item)
    rect(x,y,w,L.ITEM_H,bg,0.9)

    if sel then
        local t=i/total
        local c={
            lerp(Menu.Theme.a1[1],Menu.Theme.a2[1],t),
            lerp(Menu.Theme.a1[2],Menu.Theme.a2[2],t),
            lerp(Menu.Theme.a1[3],Menu.Theme.a2[3],t),
        }
        rect(x,y,3,L.ITEM_H,c,1)
    end

    text(x+12,y+8,it.name or "item",13,C.text,1)

    if hover and Menu.Mouse.pressed then
        activate(it)
    end
end

-- ============================================================
-- HEADER (MAIN BANNER)
-- ============================================================

local function drawHeader(x,y,w)
    if Menu.TextureMain and Susano.DrawImage then
        Susano.DrawImage(Menu.TextureMain,x,y,w,L.HEADER_H,1,1,1,1,0)
    else
        rect(x,y,w,L.HEADER_H,C.bg,1)
        gradient(x,y,w,3)
    end
end

-- ============================================================
-- KEY MODAL HEADER
-- ============================================================

local function drawKeyHeader(x,y,w)
    if Menu.TextureKey and Susano.DrawImage then
        Susano.DrawImage(Menu.TextureKey,x,y,w,80,1,1,1,1,0)
    else
        rect(x,y,w,80,C.bg,1)
        gradient(x,y,w,3)
    end
end

-- ============================================================
-- CATEGORY VIEW
-- ============================================================

function Menu.DrawCategories()

    local x,y = Menu.Position.x,Menu.Position.y
    local w = L.W

    drawHeader(x,y,w)

    local startY = y + L.HEADER_H

    for i=1,#Menu.Categories-1 do
        local cat = Menu.Categories[i+1]
        local yy = startY + (i-1)*L.ITEM_H

        local sel = Menu.CurrentCategory==i+1

        if inside(x,yy,w,L.ITEM_H) and Menu.Mouse.pressed then
            Menu.CurrentCategory=i+1
        end

        drawItem(x,yy,w,cat,sel,i,#Menu.Categories-1)
    end
end

-- ============================================================
-- OPEN CATEGORY
-- ============================================================

function Menu.DrawOpened()

    local x,y = Menu.Position.x,Menu.Position.y
    local w = L.W

    drawHeader(x,y,w)

    local cat = Menu.Categories[Menu.CurrentCategory]
    if not cat or not cat.tabs then return end

    local tab = cat.tabs[1]
    local items = tab.items or {}

    local startY = y + L.HEADER_H + 10

    -- smooth scroll
    Menu.Scroll = lerp(Menu.Scroll, Menu.ScrollVel, 0.12)
    Menu.ScrollVel = clamp(Menu.ScrollVel,0,#items*L.ITEM_H)

    for i,it in ipairs(items) do
        local yy = startY + (i-1)*L.ITEM_H - Menu.Scroll

        if yy>-50 and yy<600 then
            local sel = i==Menu.CurrentItem

            if inside(x,yy,w,L.ITEM_H) and Menu.Mouse.pressed then
                Menu.CurrentItem=i
                activate(it)
            end

            drawItem(x,yy,w,it,sel,i,#items)
        end
    end
end

-- ============================================================
-- KEYBIND MODAL
-- ============================================================

function Menu.DrawKeybindModal()

    local sw,sh = 1920,1080
    local w,h = 420,160

    local x = sw/2 - w/2
    local y = sh/2 - h/2

    drawKeyHeader(x,y,w)

    rect(x,y+80,w,h-80,C.bg,1)

    text(x+15,y+90,"PRESS ANY KEY TO BIND",14,C.text,1)
end

-- ============================================================
-- RENDER
-- ============================================================

function Menu.Render()

    updateMouse()

    if not Susano.BeginFrame then return end
    Susano.BeginFrame()

    if Menu.Visible and Menu.Categories then
        if Menu.Opened then
            Menu.DrawOpened()
        else
            Menu.DrawCategories()
        end
    end

    Susano.SubmitFrame()
end

-- ============================================================
-- LOOP
-- ============================================================

CreateThread(function()
    while true do
        Menu.Render()
        Wait(0)
    end
end)

-- ============================================================
-- TOGGLE
-- ============================================================

CreateThread(function()
    while true do
        if Susano.GetAsyncKeyState and Susano.GetAsyncKeyState(0x70) then
            Menu.Visible = not Menu.Visible
            Wait(250)
        end
        Wait(0)
    end
end)

-- ============================================================
-- LOAD TEXTURES
-- ============================================================

function Menu.LoadTextures()
    if Susano.HttpGet and Susano.LoadTextureFromBuffer then

        CreateThread(function()
            local ok,data = Susano.HttpGet(Menu.Banner.main)
            if ok==200 then
                Menu.TextureMain = Susano.LoadTextureFromBuffer(data)
            end
        end)

        CreateThread(function()
            local ok,data = Susano.HttpGet(Menu.Banner.key)
            if ok==200 then
                Menu.TextureKey = Susano.LoadTextureFromBuffer(data)
            end
        end)
    end
end

Menu.LoadTextures()

-- ============================================================
-- RETURN
-- ============================================================

return Menu
