local Menu = {}

-- =========================
-- STATE
-- =========================
Menu.State = {
    visible = false,
    alpha = 0,
    scale = 0.92,

    category = 2,
    item = 1,
    tab = 1,

    opened = false,
    openedCategory = nil,

    animSpeed = 8,

    keybindMenu = false
}

-- =========================
-- CONFIG
-- =========================
Menu.Config = {
    itemsPerPage = 9,
    width = 420
}

-- =========================
-- THEME AAA
-- =========================
Menu.Theme = {
    bg = {0,0,0,0.72},
    panel = {12/255,14/255,20/255,0.95},
    stroke = {0,200/255,255/255,0.8},
    accent = {0,200/255,255/255,1},
    accentSoft = {0,200/255,255/255,0.15},
    text = {1,1,1,1},
    dim = {0.65,0.7,0.85,1}
}

-- =========================
-- UTILS
-- =========================
local function clamp(v,a,b)
    if v<a then return a end
    if v>b then return b end
    return v
end

local function lerp(a,b,t)
    return a + (b-a)*t
end

-- =========================
-- INPUT
-- =========================
Menu.Key = {}

function Menu.Key.down(k)
    if not Susano.GetAsyncKeyState then return false end
    local d,p = Susano.GetAsyncKeyState(k)
    return d or p
end

-- =========================
-- ANIMATION ENGINE
-- =========================
function Menu.Animate()
    local dt = GetFrameTime and GetFrameTime() or 0.016
    local s = Menu.State

    local speed = s.animSpeed * dt

    if Menu.Visible then
        s.alpha = lerp(s.alpha, 1, speed)
        s.scale = lerp(s.scale, 1, speed)
    else
        s.alpha = lerp(s.alpha, 0, speed)
        s.scale = lerp(s.scale, 0.92, speed)
    end
end

-- =========================
-- DRAW HELPERS
-- =========================
function Menu.Rect(x,y,w,h,r,g,b,a)
    if Susano.DrawRect then
        Susano.DrawRect(x,y,w,h,r,g,b,a)
    end
end

function Menu.RRect(x,y,w,h,r,g,b,a)
    Menu.Rect(x,y,w,h,r,g,b,a)
end

function Menu.Text(x,y,t,s,r,g,b,a)
    if Susano.DrawText then
        Susano.DrawText(x,y,t,s,r,g,b,a)
    end
end

-- =========================
-- BACKGROUND AAA
-- =========================
function Menu.DrawBackground()
    local sw = Susano.GetScreenWidth and Susano.GetScreenWidth() or 1920
    local sh = Susano.GetScreenHeight and Susano.GetScreenHeight() or 1080
    local s = Menu.State

    local alpha = s.alpha

    Menu.Rect(0,0,sw,sh,0,0,0,0.55*alpha)

    -- soft vignette effect
    Menu.Rect(0,0,sw,sh,
        0,0,0,0.35*alpha
    )
end

-- =========================
-- HEADER AAA
-- =========================
function Menu.DrawHeader(x,y,w)
    local s = Menu.State

    Menu.Rect(x,y,w,90,
        Menu.Theme.panel[1],
        Menu.Theme.panel[2],
        Menu.Theme.panel[3],
        0.95 * s.alpha
    )

    Menu.Text(x+18,y+25,"PHAZE UI",
        22,
        0,0.8,1,s.alpha
    )

    Menu.Text(x+18,y+55,"AAA Render Build",
        12,
        0.6,0.7,0.85,s.alpha
    )

    Menu.Rect(x,y+89,w,1,
        Menu.Theme.accent[1],
        Menu.Theme.accent[2],
        Menu.Theme.accent[3],
        0.9*s.alpha
    )
end

-- =========================
-- SIDEBAR CATEGORY AAA
-- =========================
function Menu.DrawSidebar(x,y,w,h)
    local s = Menu.State

    Menu.Rect(x,y,w,h,
        10/255,12/255,18/255,0.92*s.alpha
    )

    for i,cat in ipairs(Menu.Categories or {}) do
        local cy = y + 15 + (i-1)*42
        local selected = (i == s.category)

        if selected then
            Menu.Rect(x,cy,3,30,
                Menu.Theme.accent[1],
                Menu.Theme.accent[2],
                Menu.Theme.accent[3],
                s.alpha
            )

            Menu.Rect(x,cy,w,30,
                0,0.8,1,0.08*s.alpha
            )
        end

        Menu.Text(x+12,cy+8,cat.name,
            14,
            1,1,1,
            selected and s.alpha or 0.7*s.alpha
        )
    end
end

-- =========================
-- ITEMS AAA
-- =========================
function Menu.DrawItems(x,y,w)
    local s = Menu.State
    local cat = Menu.Categories and Menu.Categories[s.category]
    if not cat then return end

    local items = cat.items or {}

    for i=1,math.min(#items,Menu.Config.itemsPerPage) do
        local it = items[i]
        local iy = y + (i-1)*45
        local selected = (i == s.item)

        -- base row
        Menu.Rect(x,iy,w,40,
            0,0,0, selected and 0.35*s.alpha or 0.18*s.alpha
        )

        if selected then
            Menu.Rect(x,iy,2,40,
                Menu.Theme.accent[1],
                Menu.Theme.accent[2],
                Menu.Theme.accent[3],
                s.alpha
            )
        end

        Menu.Text(x+15,iy+10,it.name or "item",
            14,1,1,1,s.alpha)

        -- toggle AAA
        if it.type == "toggle" then
            local on = it.value and 1 or 0

            Menu.Rect(x+w-55,iy+12,34,14,
                40/255,50/255,80/255,s.alpha
            )

            Menu.Rect(x+w-55 + on*16,iy+14,10,10,
                1,1,1,s.alpha
            )
        end

        -- slider AAA
        if it.type == "slider" then
            local pct = (it.value or 0)/(it.max or 100)

            Menu.Rect(x+w-140,iy+18,90,3,
                0.2,0.2,0.3,s.alpha
            )

            Menu.Rect(x+w-140,iy+18,90*pct,3,
                Menu.Theme.accent[1],
                Menu.Theme.accent[2],
                Menu.Theme.accent[3],
                s.alpha
            )
        end
    end
end

-- =========================
-- INPUT LOGIC (simplificado AAA)
-- =========================
function Menu.HandleInput()

    local s = Menu.State
    if not Menu.Visible then return end

    if Menu.Key.down(0x26) then s.item = math.max(1, s.item-1) end
    if Menu.Key.down(0x28) then s.item = s.item+1 end

    if Menu.Key.down(0x25) then
        local it = Menu.Categories[s.category].items[s.item]
        if it and it.type=="slider" then
            it.value = math.max(0,(it.value or 0)-1)
        end
    end

    if Menu.Key.down(0x27) then
        local it = Menu.Categories[s.category].items[s.item]
        if it and it.type=="slider" then
            it.value = math.min(100,(it.value or 0)+1)
        end
    end

    if Menu.Key.down(0x0D) then
        local it = Menu.Categories[s.category].items[s.item]
        if it and it.type=="toggle" then
            it.value = not it.value
        end
    end
end

-- =========================
-- RENDER LOOP AAA
-- =========================
function Menu.Render()

    if not Susano.BeginFrame then return end

    Menu.Animate()

    Susano.BeginFrame()

    local sw = Susano.GetScreenWidth and Susano.GetScreenWidth() or 1920
    local sh = Susano.GetScreenHeight and Susano.GetScreenHeight() or 1080

    local s = Menu.State
    local scale = s.scale

    if Menu.Visible or s.alpha > 0.01 then

        Menu.DrawBackground()

        local w = Menu.Config.width * scale
        local h = 600 * scale

        local x = sw/2 - w/2
        local y = sh/2 - h/2

        Menu.DrawHeader(x,y,w)

        Menu.DrawSidebar(x,y+90,120,h-90)

        Menu.DrawItems(x+130,y+110,w-140)

    end

    if Susano.SubmitFrame then
        Susano.SubmitFrame()
    end
end

-- =========================
-- LOOP
-- =========================
CreateThread(function()
    while true do
        Menu.Render()
        Menu.HandleInput()
        Wait(0)
    end
end)

return Menu
