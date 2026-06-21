-- ============================================================
--  NEXUS UI  |  V5 CRASH-PROOF ULTRA STABLE
-- ============================================================

local Menu = {}

-- ============================================================
-- SAFE HELPERS
-- ============================================================

local function isTable(v)
    return type(v) == "table"
end

local function lerp(a,b,t) return a + (b-a)*t end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end

-- ============================================================
-- THEME
-- ============================================================

Menu.Theme = {
    a1 = {0.10,0.85,0.95},
    a2 = {0.35,0.45,1.00}
}

-- ============================================================
-- CONSTANTS
-- ============================================================

local C = {
    bg = {0.04,0.04,0.07,0.94},
    panel = {0.06,0.06,0.10,0.90},
    item = {0.08,0.08,0.13,0.75},
    item_s = {0.12,0.12,0.20,0.95},
    text = {0.95,0.95,1,1},
}

local L = {
    W = 310,
    ITEM_H = 30,
    HEADER_H = 90,
}

-- ============================================================
-- BANNERS
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
Menu.Categories = {}
Menu.CurrentCategory = 1
Menu.CurrentItem = 1
Menu.Opened = false

Menu.Mouse = {x=0,y=0,down=false,pressed=false}
Menu.Scroll = 0
Menu.ScrollVel = 0

Menu.Position = {x=40,y=90}

-- ============================================================
-- SAFE INPUT
-- ============================================================

local function updateMouse()

    local ok, c = pcall(function()
        if Susano.GetCursorPos then
            return Susano.GetCursorPos()
        end
        return nil
    end)

    if ok and isTable(c) then
        Menu.Mouse.x = c[1] or 0
        Menu.Mouse.y = c[2] or 0
    end

    local ok2, d = pcall(function()
        if Susano.GetAsyncKeyState then
            return Susano.GetAsyncKeyState(0x01)
        end
        return false
    end)

    d = ok2 and d or false

    Menu.Mouse.pressed = d and not Menu.Mouse.down
    Menu.Mouse.down = d
end

local function inside(x,y,w,h)
    return Menu.Mouse.x>=x and Menu.Mouse.x<=x+w and Menu.Mouse.y>=y and Menu.Mouse.y<=y+h
end

-- ============================================================
-- SAFE DRAW WRAPPERS
-- ============================================================

local function rect(x,y,w,h,c,a)
    if Susano.DrawFilledRect and isTable(c) then
        Susano.DrawFilledRect(x,y,w,h,c[1],c[2],c[3],a or 1)
    end
end

local function text(x,y,t,s,c,a)
    if Susano.DrawText and isTable(c) then
        Susano.DrawText(x,y,t,s,c[1],c[2],c[3],a or 1)
    end
end

-- ============================================================
-- ITEM
-- ============================================================

local function activate(it)
    if not isTable(it) then return end

    if it.type == "toggle" then
        it.value = not it.value

    elseif it.type == "action" and type(it.onClick) == "function" then
        pcall(it.onClick)
    end
end

local function drawItem(x,y,w,it,sel,i,total)

    if not isTable(it) then return end

    local hover = inside(x,y,w,L.ITEM_H)

    local bg = sel and C.item_s or C.item
    rect(x,y,w,L.ITEM_H,bg,0.9)

    text(x+12,y+8,it.name or "item",13,C.text,1)

    if hover and Menu.Mouse.pressed then
        activate(it)
    end
end

-- ============================================================
-- HEADER
-- ============================================================

local function drawHeader(x,y,w)

    if Menu.TextureMain and Susano.DrawImage then
        Susano.DrawImage(Menu.TextureMain,x,y,w,L.HEADER_H,1,1,1,1,0)
    else
        rect(x,y,w,L.HEADER_H,C.bg,1)
    end
end

-- ============================================================
-- SAFE CATEGORIES
-- ============================================================

function Menu.DrawCategories()

    if not isTable(Menu.Categories) then return end

    local x,y = Menu.Position.x,Menu.Position.y
    local w = L.W

    drawHeader(x,y,w)

    local count = #Menu.Categories
    if count <= 0 then return end

    for i=1,count do

        local cat = Menu.Categories[i]
        if isTable(cat) then

            local yy = y + L.HEADER_H + (i-1)*L.ITEM_H
            local sel = (Menu.CurrentCategory == i)

            if inside(x,yy,w,L.ITEM_H) and Menu.Mouse.pressed then
                Menu.CurrentCategory = i
            end

            drawItem(x,yy,w,cat,sel,i,count)
        end
    end
end

-- ============================================================
-- SAFE OPENED VIEW
-- ============================================================

function Menu.DrawOpened()

    if not isTable(Menu.Categories) then return end

    local cat = Menu.Categories[Menu.CurrentCategory]
    if not isTable(cat) or not isTable(cat.tabs) then return end

    local tab = cat.tabs[1]
    if not isTable(tab) or not isTable(tab.items) then return end

    local items = tab.items

    local x,y = Menu.Position.x,Menu.Position.y
    local w = L.W

    drawHeader(x,y,w)

    local startY = y + L.HEADER_H + 10

    local count = #items
    if count <= 0 then return end

    Menu.ScrollVel = clamp(Menu.ScrollVel,0,count*L.ITEM_H)
    Menu.Scroll = lerp(Menu.Scroll, Menu.ScrollVel, 0.12)

    for i=1,count do

        local it = items[i]
        local yy = startY + (i-1)*L.ITEM_H - Menu.Scroll

        if yy > -50 and yy < 600 then
            local sel = (Menu.CurrentItem == i)

            if inside(x,yy,w,L.ITEM_H) and Menu.Mouse.pressed then
                Menu.CurrentItem = i
                activate(it)
            end

            drawItem(x,yy,w,it,sel,i,count)
        end
    end
end

-- ============================================================
-- RENDER SAFE
-- ============================================================

function Menu.Render()

    updateMouse()

    if not Susano.BeginFrame or not Susano.SubmitFrame then return end

    Susano.BeginFrame()

    if Menu.Visible then
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
-- TOGGLE SAFE
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
-- LOAD TEXTURES SAFE
-- ============================================================

function Menu.LoadTextures()

    if not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end

    CreateThread(function()
        local ok,data = Susano.HttpGet(Menu.Banner.main)
        if ok == 200 and data then
            Menu.TextureMain = Susano.LoadTextureFromBuffer(data)
        end
    end)

    CreateThread(function()
        local ok,data = Susano.HttpGet(Menu.Banner.key)
        if ok == 200 and data then
            Menu.TextureKey = Susano.LoadTextureFromBuffer(data)
        end
    end)
end

Menu.LoadTextures()

return Menu
