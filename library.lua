local Menu = {}

local function SafeIpairs(value)
    if type(value) == "table" then
        return ipairs(value)
    end
    return function() return nil end
end
Menu.Visible = false
Menu.PreventResetFrame = true
Menu.MenuToggleKey = 0x4E -- N
Menu.BuildVersion = "Build v8.0.1"
Menu.CurrentCategory = 2
Menu.CurrentPage = 1
Menu.ItemsPerPage = 9
Menu.scrollbarY = nil
Menu.scrollbarHeight = nil
Menu.OpenedCategory = nil
Menu.CurrentItem = 1
Menu.CurrentTab = 1
Menu.ItemScrollOffset = 0
Menu.CategoryScrollOffset = 0
Menu.EditorDragging = false
Menu.EditorDragOffsetX = 0
Menu.EditorDragOffsetY = 0
Menu.EditorMode = false
Menu.ShowSnowflakes = true
Menu.SelectorY = 0
Menu.CategorySelectorY = 0
Menu.TabSelectorX = 0
Menu.TabSelectorWidth = 0
Menu.SmoothFactor = 0.22
Menu.VisualSmoothFactor = 0.20
Menu.SmoothScrollCatY = 0
Menu.SmoothScrollItemY = 0
Menu.PlayerInfoAlpha = 0.0
Menu.PlayerInfo = nil
Menu.GradientType = 1
Menu.ScrollbarPosition = 1

Menu.LoadingBarAlpha = 0.0
Menu.KeySelectorAlpha = 0.0
Menu.KeybindsInterfaceAlpha = 0.0

Menu.LoadingProgress = 0.0
Menu.IsLoading = true
Menu.LoadingComplete = false
Menu.LoadingStartTime = nil
Menu.LoadingDuration = 3000

Menu.SelectingKey = false
Menu.SelectedKey = Menu.MenuToggleKey
Menu.SelectedKeyName = "N"
Menu.TempKeyPressed = nil          -- para mostrar tecla en selector de menú

Menu.SelectingBind = false
Menu.BindingItem = nil
Menu.BindingKey = nil
Menu.BindingKeyName = nil
Menu.TempPressedKey = nil

Menu.ShowKeybinds = false
Menu.CurrentTopTab = 1

-- Panel de anticheat (opcional)
Menu.AnticheatList = {}
function Menu.SetAnticheatInfo(detectedList)
    if not detectedList or type(detectedList) ~= "table" then
        Menu.AnticheatList = {}
        return
    end
    Menu.AnticheatList = {}
    for _, name in SafeIpairs(detectedList) do
        table.insert(Menu.AnticheatList, { name = name, detected = true })
    end
end

-- ========== PALETA: FONDO NEGRO 30% OPACIDAD ==========
Menu.Colors = {
    BgMain      = { r = 0,   g = 0,   b = 0,   a = 77 },   -- 30% opacidad
    BorderNeon  = { r = 0,   g = 210, b = 255, a = 150 },
    Accent      = { r = 0,   g = 180, b = 255 },
    AccentDark  = { r = 0,   g = 120, b = 200 },
    Text        = { r = 255, g = 255, b = 255 },
    TextDim     = { r = 160, g = 170, b = 210 },
    Selected    = { r = 0,   g = 150, b = 230 },
}
Menu.CurrentTheme = "BlackGlass"

function Menu.ApplyTheme(themeName)
    -- Solo mantenemos un tema consistente (negro con acentos neón)
    Menu.Colors.BgMain     = { r = 0,   g = 0,   b = 0,   a = 77 }
    Menu.Colors.BorderNeon = { r = 0,   g = 210, b = 255, a = 150 }
    Menu.Colors.Accent     = { r = 0,   g = 180, b = 255 }
    Menu.Colors.AccentDark = { r = 0,   g = 120, b = 200 }
    Menu.Colors.Text       = { r = 255, g = 255, b = 255 }
    Menu.Colors.TextDim    = { r = 160, g = 170, b = 210 }
    Menu.Colors.Selected   = { r = 0,   g = 150, b = 230 }
    if Menu.Banner.enabled and Menu.Banner.imageUrl then
        Menu.LoadBannerTexture(Menu.Banner.imageUrl)
    end
    if Menu.PlayerInfoBanner and Menu.PlayerInfoBanner.enabled and Menu.PlayerInfoBanner.imageUrl then
        Menu.LoadPlayerInfoBannerTexture(Menu.PlayerInfoBanner.imageUrl)
    end
end

-- Dimensiones con bordes delgados
Menu.Position = {
    x = 55,
    y = 80,
    width = 360,
    itemHeight = 34,
    mainMenuHeight = 26,
    headerHeight = 100,
    footerHeight = 26,
    footerSpacing = 5,
    mainMenuSpacing = 5,
    footerRadius = 4,
    itemRadius = 4,
    scrollbarWidth = 7,
    scrollbarPadding = 4,
    headerRadius = 6,
    anticheatPanelHeight = 0,
    anticheatSpacing = 6
}
Menu.Scale = 1.0

function Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    return {
        x = Menu.Position.x,
        y = Menu.Position.y,
        width = Menu.Position.width * scale,
        itemHeight = Menu.Position.itemHeight * scale,
        mainMenuHeight = Menu.Position.mainMenuHeight * scale,
        headerHeight = Menu.Position.headerHeight * scale,
        footerHeight = Menu.Position.footerHeight * scale,
        footerSpacing = Menu.Position.footerSpacing * scale,
        mainMenuSpacing = Menu.Position.mainMenuSpacing * scale,
        footerRadius = Menu.Position.footerRadius * scale,
        itemRadius = Menu.Position.itemRadius * scale,
        scrollbarWidth = Menu.Position.scrollbarWidth * scale,
        scrollbarPadding = Menu.Position.scrollbarPadding * scale,
        headerRadius = Menu.Position.headerRadius * scale,
        anticheatPanelHeight = Menu.Position.anticheatPanelHeight * scale,
        anticheatSpacing = Menu.Position.anticheatSpacing * scale
    }
end

-- Altura total (incluye panel anticheat si hay datos)
function Menu.GetActualHeight()
    local p = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local bannerH = Menu.Banner.enabled and (Menu.Banner.height * scale) or p.headerHeight
    local height = bannerH
    if Menu.OpenedCategory then
        local cat = Menu.Categories[Menu.OpenedCategory]
        if cat and cat.hasTabs and cat.tabs then
            local tab = cat.tabs[Menu.CurrentTab]
            if tab and tab.items then
                local visible = math.min(Menu.ItemsPerPage, #tab.items)
                height = height + p.mainMenuHeight + p.mainMenuSpacing + (visible * p.itemHeight)
            else
                height = height + p.mainMenuHeight + p.mainMenuSpacing
            end
        else
            height = height + p.mainMenuHeight + p.mainMenuSpacing
        end
    else
        local totalCats = #Menu.Categories - 1
        local visibleCats = math.min(Menu.ItemsPerPage, totalCats)
        height = height + p.mainMenuHeight + p.mainMenuSpacing + (visibleCats * p.itemHeight)
    end
    height = height + p.footerSpacing + p.footerHeight
    if #Menu.AnticheatList > 0 then
        height = height + p.anticheatSpacing + p.anticheatPanelHeight
    end
    return height
end

-- Funciones de dibujo base
function Menu.DrawRect(x, y, w, h, r, g, b, a)
    a = a or 1.0
    if r > 1.0 then r = r/255.0 end
    if g > 1.0 then g = g/255.0 end
    if b > 1.0 then b = b/255.0 end
    if a > 1.0 then a = a/255.0 end
    if Susano.DrawFilledRect then
        Susano.DrawFilledRect(x, y, w, h, r, g, b, a)
    elseif Susano.FillRect then
        Susano.FillRect(x, y, w, h, r, g, b, a)
    elseif Susano.DrawRect then
        for i=0, h-1 do Susano.DrawRect(x, y+i, w, 1, r, g, b, a) end
    end
end

function Menu.DrawText(x, y, text, sz, r, g, b, a)
    local scale = Menu.Scale or 1.0
    sz = (sz or 16) * scale
    if r > 1.0 then r = r/255.0 end
    if g > 1.0 then g = g/255.0 end
    if b > 1.0 then b = b/255.0 end
    if a > 1.0 then a = a/255.0 end
    Susano.DrawText(x, y, text, sz, r, g, b, a)
end

function Menu.DrawRoundedRect(x, y, w, h, r, g, b, a, radius)
    radius = radius or 0
    if radius <= 0 then
        Menu.DrawRect(x, y, w, h, r, g, b, a)
        return
    end
    Menu.DrawRect(x+radius, y, w-2*radius, h, r, g, b, a)
    Menu.DrawRect(x, y+radius, radius, h-2*radius, r, g, b, a)
    Menu.DrawRect(x+w-radius, y+radius, radius, h-2*radius, r, g, b, a)
    for i=0, radius-1 do
        local sw = math.ceil(math.sqrt(radius*radius - i*i))
        local ty = y+radius-1-i
        Menu.DrawRect(x+radius-sw, ty, sw, 1, r, g, b, a)
        Menu.DrawRect(x+w-radius, ty, sw, 1, r, g, b, a)
        local by = y+h-radius+i
        Menu.DrawRect(x+radius-sw, by, sw, 1, r, g, b, a)
        Menu.DrawRect(x+w-radius, by, sw, 1, r, g, b, a)
    end
end

-- Header (banner o logo)
function Menu.DrawHeader()
    local p = Menu.GetScaledPosition()
    local x, y, w = p.x, p.y, p.width-1
    local h = p.headerHeight
    local bannerH = Menu.Banner.enabled and (Menu.Banner.height * (Menu.Scale or 1.0)) or h
    if Menu.Banner.enabled and Menu.bannerTexture and Menu.bannerTexture>0 and Susano.DrawImage then
        Susano.DrawImage(Menu.bannerTexture, x, y, w, bannerH, 1,1,1,1,0)
    else
        Menu.DrawRoundedRect(x, y, w, h, 0,0,0, Menu.Colors.BgMain.a/255.0, p.headerRadius)
        Menu.DrawRect(x, y+h-2, w, 1, Menu.Colors.BorderNeon.r/255.0, Menu.Colors.BorderNeon.g/255.0, Menu.Colors.BorderNeon.b/255.0, Menu.Colors.BorderNeon.a/255.0)
        local logo = "⚡ PHAZE ⚡"
        local fs = 28
        local tw = Susano.GetTextWidth and Susano.GetTextWidth(logo, fs) or (string.len(logo)*14)
        Menu.DrawText(x+w/2-tw/2, y+h/2-fs/2, logo, fs, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 1.0)
    end
end

-- Scrollbar delgada
function Menu.DrawScrollbar(x, startY, visibleHeight, selectedIndex, totalItems, isMainMenu, menuWidth)
    if totalItems < 1 then return end
    local p = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local width = menuWidth or p.width

    -- Siempre a la izquierda del menú, como pediste.
    local railW = math.max(7, p.scrollbarWidth)
    local capH = 18 * scale
    local gap = 9 * scale
    local sbX = x - railW - gap
    local sbY = startY
    local sbH = visibleHeight

    if sbH <= 0 then return end

    -- Cápsulas superior/inferior con flechas decorativas.
    local acR, acG, acB = Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0
    local dimR, dimG, dimB = Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0

    Menu.DrawRoundedRect(sbX-4*scale, sbY-capH-5*scale, railW+8*scale, capH, 0,0,0, 170, 5*scale)
    Menu.DrawRoundedRect(sbX-2*scale, sbY-capH-3*scale, railW+4*scale, capH-4*scale, 12,18,28, 210, 4*scale)
    Menu.DrawText(sbX-2*scale, sbY-capH-3*scale, "▲", 13, acR, acG, acB, 230)

    Menu.DrawRoundedRect(sbX-4*scale, sbY+sbH+5*scale, railW+8*scale, capH, 0,0,0, 170, 5*scale)
    Menu.DrawRoundedRect(sbX-2*scale, sbY+sbH+7*scale, railW+4*scale, capH-4*scale, 12,18,28, 210, 4*scale)
    Menu.DrawText(sbX-2*scale, sbY+sbH+7*scale, "▼", 13, acR, acG, acB, 230)

    -- Rail con glow suave.
    Menu.DrawRoundedRect(sbX-2*scale, sbY, railW+4*scale, sbH, 0,0,0, 135, railW)
    Menu.DrawRoundedRect(sbX, sbY+2*scale, railW, sbH-4*scale, 18,24,38, 185, railW)
    Menu.DrawRect(sbX + railW/2, sbY+8*scale, 1, math.max(0, sbH-16*scale), dimR, dimG, dimB, 45)

    local thumbH = sbH
    local targetY = sbY
    if totalItems > Menu.ItemsPerPage then
        local scrollOffset = isMainMenu and Menu.CategoryScrollOffset or Menu.ItemScrollOffset
        local totalScroll = totalItems - Menu.ItemsPerPage
        local progress = scrollOffset / math.max(1, totalScroll)
        progress = math.min(1, math.max(0, progress))
        thumbH = math.max(24*scale, sbH * (Menu.ItemsPerPage / totalItems))
        targetY = sbY + progress * (sbH - thumbH)
        targetY = math.max(sbY, math.min(sbY+sbH-thumbH, targetY))
    end

    -- Estado separado por tipo. No usa REMOVED_LEGACY_NAME.
    local stateName = isMainMenu and "SmoothScrollCatY" or "SmoothScrollItemY"
    if type(Menu[stateName]) ~= "number" or Menu[stateName] == 0 then
        Menu[stateName] = targetY
    end
    Menu[stateName] = Menu[stateName] + (targetY - Menu[stateName]) * (Menu.VisualSmoothFactor or 0.20)
    local thumbY = Menu[stateName]

    -- Thumb premium con doble capa.
    Menu.DrawRoundedRect(sbX-3*scale, thumbY-1*scale, railW+6*scale, thumbH+2*scale, acR, acG, acB, 70, railW)
    Menu.DrawRoundedRect(sbX-1*scale, thumbY, railW+2*scale, thumbH, acR, acG, acB, 225, railW)
    Menu.DrawRoundedRect(sbX+2*scale, thumbY+4*scale, math.max(2, railW-4*scale), math.max(4, thumbH-8*scale), 255,255,255, 38, railW)
end

-- Pestañas
function Menu.DrawTabs(category, x, startY, width, tabHeight)
    if not category or not category.hasTabs or not category.tabs then return end
    local scale = Menu.Scale or 1.0
    local numTabs = #category.tabs
    local tabWidth = width / numTabs
    for i, tab in SafeIpairs(category.tabs) do
        local tabX = x + (i-1)*tabWidth
        local curW = (i==numTabs) and (x+width - tabX) or (tabWidth + 0.5*scale)
        local isSel = (i == Menu.CurrentTab)
        Menu.DrawRect(tabX, startY, curW, tabHeight, 0,0,0, Menu.Colors.BgMain.a/255.0 * (isSel and 0 or 0.5))
        if isSel then
            local steps = 10
            local stepH = tabHeight / steps
            for s=0, steps-1 do
                local sY = startY + s*stepH
                local sH = math.min(stepH, startY+tabHeight - sY)
                if sH > 0 then
                    local mix = 1 - (s / steps)
                    local r = Menu.Colors.Selected.r/255.0 * (0.3 + mix*0.7)
                    local g = Menu.Colors.Selected.g/255.0 * (0.3 + mix*0.7)
                    local b = Menu.Colors.Selected.b/255.0 * (0.3 + mix*0.7)
                    Menu.DrawRect(tabX, sY, curW, sH, r, g, b, 230)
                end
            end
            Menu.DrawRect(tabX, startY+tabHeight-2, curW, 1, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255)
        end
        local fontSize = 15
        local tw = Susano.GetTextWidth and Susano.GetTextWidth(tab.name, fontSize) or (string.len(tab.name)*8)
        local tx = tabX + curW/2 - tw/2
        local ty = startY + tabHeight/2 - fontSize/2
        local r,g,b = isSel and 255 or Menu.Colors.Text.r, isSel and 255 or Menu.Colors.Text.g, isSel and 255 or Menu.Colors.Text.b
        Menu.DrawText(tx, ty, tab.name, fontSize, r/255.0, g/255.0, b/255.0, 1.0)
    end
end

local function findNextNonSeparator(items, startIndex, direction)
    local idx = startIndex
    local attempts = 0
    while attempts < #items do
        idx = idx + direction
        if idx < 1 then idx = #items
        elseif idx > #items then idx = 1 end
        if items[idx] and not items[idx].isSeparator then return idx end
        attempts = attempts + 1
    end
    return startIndex
end

-- Dibujo de ítem (con toggle smooth)
function Menu.DrawItem(x, itemY, width, itemHeight, item, isSelected, isCategory)
    local scale = Menu.Scale or 1.0
    if item.isSeparator then
        Menu.DrawRect(x, itemY, width, itemHeight, 0,0,0, Menu.Colors.BgMain.a/255.0 * 0.3)
        if item.separatorText then
            local fs = 13
            local tw = Susano.GetTextWidth and Susano.GetTextWidth(item.separatorText, fs) or (string.len(item.separatorText)*7)
            local tx = x + width/2 - tw/2
            local ty = itemY + itemHeight/2 - fs/2
            Menu.DrawText(tx, ty, item.separatorText, fs, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 200)
            local barY = itemY + itemHeight/2
            local barL = 50
            Menu.DrawRect(x+20, barY, barL, 1, 150,150,200, 100)
            Menu.DrawRect(x+width-20-barL, barY, barL, 1, 150,150,200, 100)
        end
        return
    end

    Menu.DrawRect(x, itemY, width, itemHeight, 0,0,0, Menu.Colors.BgMain.a/255.0 * 0.4)

    if isSelected then
        if not isCategory and Menu.SelectorY == 0 then Menu.SelectorY = itemY end
        if isCategory and Menu.CategorySelectorY == 0 then Menu.CategorySelectorY = itemY end
        
        local drawY = isCategory and Menu.CategorySelectorY or Menu.SelectorY
        local targetY = itemY
        local smooth = Menu.SmoothFactor
        if isCategory then
            Menu.CategorySelectorY = drawY + (targetY - drawY) * smooth
            if math.abs(Menu.CategorySelectorY - targetY) < 0.5 then Menu.CategorySelectorY = targetY end
            drawY = Menu.CategorySelectorY
        else
            Menu.SelectorY = drawY + (targetY - drawY) * smooth
            if math.abs(Menu.SelectorY - targetY) < 0.5 then Menu.SelectorY = targetY end
            drawY = Menu.SelectorY
        end

        local steps = 25
        local stepH = itemHeight / steps
        for s=0, steps-1 do
            local sY = drawY + s*stepH
            local sH = math.min(stepH, drawY+itemHeight - sY)
            if sH > 0 then
                local mix = s / steps
                local r = Menu.Colors.Selected.r/255.0 * (0.4 + (1-mix)*0.6)
                local g = Menu.Colors.Selected.g/255.0 * (0.4 + (1-mix)*0.6)
                local b = Menu.Colors.Selected.b/255.0 * (0.4 + (1-mix)*0.6)
                Menu.DrawRect(x, sY, width, sH, r, g, b, 240)
            end
        end
        Menu.DrawRect(x, drawY, width, 1, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255)
        Menu.DrawRect(x, drawY+itemHeight-1, width, 1, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255)
        Menu.DrawRect(x, drawY, 2, itemHeight, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255)
        Menu.DrawRect(x+width-2, drawY, 2, itemHeight, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 200)
        Menu.DrawText(x+18+1, itemY+itemHeight/2-8+1, item.name, 17, 0,0,0, 150)
    end

    local textX = x + 22
    local textY = itemY + itemHeight/2 - 8
    Menu.DrawText(textX, textY, item.name, 17, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 255)
    
    if isCategory then
        Menu.DrawText(x+width-32, textY, "›", 18, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 200)
    end

    if not isCategory then
        if item.type == "toggle" then
            -- Animación suave
            if item.animProgress == nil then item.animProgress = item.value and 1 or 0 end
            if item.animTarget == nil then item.animTarget = item.value and 1 or 0 end
            local diff = item.animTarget - item.animProgress
            if math.abs(diff) > 0.01 then
                item.animProgress = item.animProgress + diff * Menu.SmoothFactor
            else
                item.animProgress = item.animTarget
            end
            
            local toggleW = 40 * scale
            local toggleH = 20 * scale
            local toggleX = x + width - toggleW - 18
            local toggleY = itemY + (itemHeight/2) - toggleH/2
            local rad = toggleH/2
            local rOff, gOff, bOff = 50/255.0, 60/255.0, 90/255.0
            local rOn, gOn, bOn = Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0
            local r = rOff + (rOn - rOff) * item.animProgress
            local g = gOff + (gOn - gOff) * item.animProgress
            local b = bOff + (bOn - bOff) * item.animProgress
            Menu.DrawRoundedRect(toggleX, toggleY, toggleW, toggleH, r, g, b, 255, rad)
            
            local knobSize = toggleH - 6
            local knobY = toggleY + 3
            local offX = toggleX + 3
            local onX = toggleX + toggleW - knobSize - 3
            local knobX = offX + (onX - offX) * item.animProgress
            Menu.DrawRoundedRect(knobX, knobY, knobSize, knobSize, 255,255,255, 255, knobSize/2)
            
        elseif item.type == "slider" then
            local sliderW = 120 * scale
            local sliderH = 5 * scale
            local sliderX = x + width - sliderW - 70
            local sliderY = itemY + (itemHeight/2) - sliderH/2
            local minV = item.min or 0
            local maxV = item.max or 100
            local val = item.value or minV
            local percent = (val - minV) / (maxV - minV)
            percent = math.min(1, math.max(0, percent))
            Menu.DrawRect(sliderX, sliderY, sliderW, sliderH, 40,50,80, 180)
            if percent > 0 then
                Menu.DrawRect(sliderX, sliderY, sliderW * percent, sliderH, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255)
            end
            local thumbSize = 10 * scale
            local thumbX = sliderX + sliderW*percent - thumbSize/2
            local thumbY = sliderY + sliderH/2 - thumbSize/2
            Menu.DrawRoundedRect(thumbX, thumbY, thumbSize, thumbSize, 255,255,255, 255, thumbSize/2)
            local valText = string.format("%.0f", val)
            local tw = Susano.GetTextWidth and Susano.GetTextWidth(valText, 11) or (string.len(valText)*6)
            Menu.DrawText(sliderX+sliderW+10, sliderY-2, valText, 11, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 200)
        elseif item.type == "selector" and item.options then
            local selIdx = item.selected or 1
            local opt = item.options[selIdx] or ""
            local full = "< " .. opt .. " >"
            local fs = 15
            local tw = Susano.GetTextWidth and Susano.GetTextWidth(full, fs) or (string.len(full)*8)
            local tx = x + width - tw - 22
            Menu.DrawText(tx, textY, full, fs, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 255)
        elseif item.type == "toggle_selector" then
            local toggleW = 36 * scale
            local toggleH = 18 * scale
            local toggleX = x + width - toggleW - 18
            local toggleY = itemY + (itemHeight/2) - toggleH/2
            local rad = toggleH/2
            if item.value then
                Menu.DrawRoundedRect(toggleX, toggleY, toggleW, toggleH, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255, rad)
            else
                Menu.DrawRoundedRect(toggleX, toggleY, toggleW, toggleH, 50,60,90, 200, rad)
            end
            local knobSize = toggleH - 4
            local knobY = toggleY + 2
            local knobX = item.value and (toggleX + toggleW - knobSize - 2) or (toggleX + 2)
            Menu.DrawRoundedRect(knobX, knobY, knobSize, knobSize, 255,255,255, 255, knobSize/2)
            if item.options then
                local selIdx = item.selected or 1
                local opt = item.options[selIdx] or ""
                local optText = "< " .. opt .. " >"
                local fs = 13
                local tw = Susano.GetTextWidth and Susano.GetTextWidth(optText, fs) or (string.len(optText)*7)
                local tx = toggleX - tw - 12
                Menu.DrawText(tx, textY, optText, fs, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 255)
            end
        end
    end
end

-- Panel anticheat (opcional)
function Menu.DrawAnticheatPanel()
    if #Menu.AnticheatList == 0 then return end
    local p = Menu.GetScaledPosition()
    local x = p.x
    local scale = Menu.Scale or 1.0
    local bannerH = Menu.Banner.enabled and (Menu.Banner.height * scale) or p.headerHeight
    local contentHeight = 0
    if Menu.OpenedCategory then
        local cat = Menu.Categories[Menu.OpenedCategory]
        if cat and cat.hasTabs and cat.tabs then
            local tab = cat.tabs[Menu.CurrentTab]
            if tab and tab.items then
                local visible = math.min(Menu.ItemsPerPage, #tab.items)
                contentHeight = bannerH + p.mainMenuHeight + p.mainMenuSpacing + (visible * p.itemHeight)
            else
                contentHeight = bannerH + p.mainMenuHeight + p.mainMenuSpacing
            end
        else
            contentHeight = bannerH + p.mainMenuHeight + p.mainMenuSpacing
        end
    else
        local totalCats = #Menu.Categories - 1
        local visibleCats = math.min(Menu.ItemsPerPage, totalCats)
        contentHeight = bannerH + p.mainMenuHeight + p.mainMenuSpacing + (visibleCats * p.itemHeight)
    end
    local footerY = p.y + contentHeight + p.footerSpacing
    local y = footerY + p.footerHeight + p.anticheatSpacing
    local w = p.width - 1
    local perColumn = math.ceil(#Menu.AnticheatList / 2)
    local rows = math.min(perColumn, 5)
    local h = 35 + rows * 20
    p.anticheatPanelHeight = h
    Menu.Position.anticheatPanelHeight = h / (Menu.Scale or 1.0)

    Menu.DrawRoundedRect(x, y, w, h, 0,0,0, Menu.Colors.BgMain.a/255.0 * 0.8, 4)
    Menu.DrawRect(x, y, w, 1, Menu.Colors.BorderNeon.r/255.0, Menu.Colors.BorderNeon.g/255.0, Menu.Colors.BorderNeon.b/255.0, 120)
    local title = "🛡️ ANTICHEATS DETECTADOS"
    local fsTitle = 11
    local twTitle = Susano.GetTextWidth and Susano.GetTextWidth(title, fsTitle) or (string.len(title)*6)
    Menu.DrawText(x + w/2 - twTitle/2, y + 8, title, fsTitle, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255)

    local startListY = y + 24
    local colWidth = (w - 30) / 2
    local perCol = math.ceil(#Menu.AnticheatList / 2)
    for i, ac in SafeIpairs(Menu.AnticheatList) do
        local col = 0
        local row = i - 1
        if i > perCol then
            col = 1
            row = i - perCol - 1
        end
        local itemX = x + 15 + col * (colWidth + 5)
        local itemY = startListY + row * 18
        Menu.DrawText(itemX, itemY, ac.name, 10, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 255)
        Menu.DrawText(itemX + 130, itemY, "✓", 10, 100,255,100, 255)
    end
end

-- Menú principal y submenús
function Menu.DrawCategories()
    if type(Menu.Categories) ~= "table" then return end
    if Menu.OpenedCategory then
        local cat = Menu.Categories[Menu.OpenedCategory]
        if not cat or not cat.hasTabs or not cat.tabs then
            Menu.OpenedCategory = nil
            return
        end

        local p = Menu.GetScaledPosition()
        local x = p.x
        local startY = p.y + p.headerHeight
        local w = p.width
        local itemH = p.itemHeight
        local tabH = p.mainMenuHeight
        local spacing = p.mainMenuSpacing

        Menu.DrawTabs(cat, x, startY, w, tabH)

        local curTab = cat.tabs[Menu.CurrentTab]
        if curTab and curTab.items then
            local itemsY = startY + tabH + spacing
            local total = #curTab.items
            local maxVis = Menu.ItemsPerPage
            if Menu.CurrentItem > Menu.ItemScrollOffset + maxVis then
                Menu.ItemScrollOffset = Menu.CurrentItem - maxVis
            elseif Menu.CurrentItem <= Menu.ItemScrollOffset then
                Menu.ItemScrollOffset = math.max(0, Menu.CurrentItem - 1)
            end
            local visible = 0
            for i=1, math.min(maxVis, total) do
                local idx = i + Menu.ItemScrollOffset
                if idx <= total then
                    visible = visible + 1
                    local yPos = itemsY + (i-1)*itemH
                    local isSel = (idx == Menu.CurrentItem)
                    Menu.DrawItem(x, yPos, w, itemH, curTab.items[idx], isSel, false)
                end
            end
            local nonSep = 0
            for _,it in SafeIpairs(curTab.items) do if not it.isSeparator then nonSep = nonSep+1 end end
            if nonSep > 0 then
                Menu.DrawScrollbar(x, itemsY, visible*itemH, Menu.CurrentItem, nonSep, false, w)
            end
        end
        return
    end

    -- Menú principal
    local p = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x = p.x
    local bannerH = Menu.Banner.enabled and (Menu.Banner.height * scale) or p.headerHeight
    local startY = p.y + bannerH
    local w = p.width
    local itemH = p.itemHeight
    local tabH = p.mainMenuHeight
    local spacing = p.mainMenuSpacing

    if Menu.TopLevelTabs then
        local tabCount = #Menu.TopLevelTabs
        local tabW = w / tabCount
        for i, tab in SafeIpairs(Menu.TopLevelTabs) do
            local tabX = x + (i-1)*tabW
            local isSel = (i == Menu.CurrentTopTab)
            Menu.DrawRect(tabX, startY, tabW, tabH, 0,0,0, Menu.Colors.BgMain.a/255.0 * (isSel and 0 or 0.5))
            if isSel then
                local steps = 10
                local stepH = tabH / steps
                for s=0, steps-1 do
                    local sY = startY + s*stepH
                    local sH = math.min(stepH, startY+tabH - sY)
                    if sH > 0 then
                        local mix = 1 - (s / steps)
                        local r = Menu.Colors.Selected.r/255.0 * (0.3 + mix*0.7)
                        local g = Menu.Colors.Selected.g/255.0 * (0.3 + mix*0.7)
                        local b = Menu.Colors.Selected.b/255.0 * (0.3 + mix*0.7)
                        Menu.DrawRect(tabX, sY, tabW, sH, r, g, b, 230)
                    end
                end
                Menu.DrawRect(tabX, startY+tabH-2, tabW, 1, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255)
            end
            local fs = 15
            local tw = Susano.GetTextWidth and Susano.GetTextWidth(tab.name, fs) or (string.len(tab.name)*8)
            local tx = tabX + tabW/2 - tw/2
            local ty = startY + tabH/2 - fs/2
            local r,g,b = isSel and 255 or Menu.Colors.Text.r, isSel and 255 or Menu.Colors.Text.g, isSel and 255 or Menu.Colors.Text.b
            Menu.DrawText(tx, ty, tab.name, fs, r/255.0, g/255.0, b/255.0, 1.0)
        end
        startY = startY + tabH + spacing
    else
        Menu.DrawRect(x, startY, w, tabH, 0,0,0, Menu.Colors.BgMain.a/255.0 * 0.5)
        local steps = 10
        local stepH = tabH / steps
        for s=0, steps-1 do
            local sY = startY + s*stepH
            local sH = math.min(stepH, startY+tabH - sY)
            if sH > 0 then
                local mix = 1 - (s / steps)
                local r = Menu.Colors.Selected.r/255.0 * (0.3 + mix*0.7)
                local g = Menu.Colors.Selected.g/255.0 * (0.3 + mix*0.7)
                local b = Menu.Colors.Selected.b/255.0 * (0.3 + mix*0.7)
                Menu.DrawRect(x, sY, w, sH, r, g, b, 230)
            end
        end
        Menu.DrawRect(x, startY+tabH-2, w, 1, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255)
        local title = Menu.Categories[1] and Menu.Categories[1].name or "MENÚ PRINCIPAL"
        local fs = 16
        local tw = Susano.GetTextWidth and Susano.GetTextWidth(title, fs) or (string.len(title)*8)
        Menu.DrawText(x+w/2-tw/2, startY+tabH/2-fs/2, title, fs, 1,1,1, 1.0)
        startY = startY + tabH + spacing
    end

    local totalCats = #Menu.Categories - 1
    local maxVis = Menu.ItemsPerPage
    if Menu.CurrentCategory > Menu.CategoryScrollOffset + maxVis + 1 then
        Menu.CategoryScrollOffset = Menu.CurrentCategory - maxVis - 1
    elseif Menu.CurrentCategory <= Menu.CategoryScrollOffset + 1 then
        Menu.CategoryScrollOffset = math.max(0, Menu.CurrentCategory - 2)
    end

    local visible = 0
    for i=1, math.min(maxVis, totalCats) do
        local idx = i + Menu.CategoryScrollOffset + 1
        if idx <= #Menu.Categories then
            visible = visible + 1
            local cat = Menu.Categories[idx]
            local yPos = startY + (i-1)*itemH
            local isSel = (idx == Menu.CurrentCategory)
            local fakeItem = { name = cat.name, isSeparator = false }
            Menu.DrawItem(x, yPos, w, itemH, fakeItem, isSel, true)
        end
    end

    if totalCats > 0 then
        Menu.DrawScrollbar(x, startY, visible*itemH, Menu.CurrentCategory, totalCats, true, w)
    end
end

function Menu.DrawFooter()
    local p = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x = p.x
    local bannerH = Menu.Banner.enabled and (Menu.Banner.height * scale) or p.headerHeight
    local totalH = bannerH
    if Menu.OpenedCategory then
        local cat = Menu.Categories[Menu.OpenedCategory]
        if cat and cat.hasTabs and cat.tabs then
            local tab = cat.tabs[Menu.CurrentTab]
            if tab and tab.items then
                local vis = math.min(Menu.ItemsPerPage, #tab.items)
                totalH = totalH + p.mainMenuHeight + p.mainMenuSpacing + (vis * p.itemHeight)
            else
                totalH = totalH + p.mainMenuHeight + p.mainMenuSpacing
            end
        else
            totalH = totalH + p.mainMenuHeight + p.mainMenuSpacing
        end
    else
        local vis = math.min(Menu.ItemsPerPage, #Menu.Categories-1)
        totalH = totalH + p.mainMenuHeight + p.mainMenuSpacing + (vis * p.itemHeight)
    end
    local footerY = p.y + totalH + p.footerSpacing
    local w = p.width - 1
    local h = p.footerHeight
    Menu.DrawRoundedRect(x, footerY, w, h, 0,0,0, Menu.Colors.BgMain.a/255.0, p.footerRadius)
    Menu.DrawRect(x, footerY, w, 1, Menu.Colors.BorderNeon.r/255.0, Menu.Colors.BorderNeon.g/255.0, Menu.Colors.BorderNeon.b/255.0, 100)
    local text = ".gg/sentexmodz"
    local fs = 11
    local tw = Susano.GetTextWidth and Susano.GetTextWidth(text, fs) or (string.len(text)*6)
    Menu.DrawText(x+15, footerY+h/2-fs/2, text, fs, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 255)
    local versionText = Menu.BuildVersion or "Build v8.0.1"
    local vw = Susano.GetTextWidth and Susano.GetTextWidth(versionText, fs) or (string.len(versionText)*6)
    Menu.DrawText(x+w-vw-15, footerY+h/2-fs/2, versionText, fs, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 255)
    local page = ""
    if Menu.OpenedCategory then
        local cat = Menu.Categories[Menu.OpenedCategory]
        if cat and cat.hasTabs and cat.tabs then
            local tab = cat.tabs[Menu.CurrentTab]
            if tab and tab.items then
                page = string.format("%d/%d", Menu.CurrentItem, #tab.items)
            end
        end
    else
        page = string.format("%d/%d", Menu.CurrentCategory-1, #Menu.Categories-1)
    end
    if page ~= "" then
        local pw = Susano.GetTextWidth and Susano.GetTextWidth(page, fs) or (string.len(page)*6)
        Menu.DrawText(x+w/2-pw/2, footerY+h/2-fs/2, page, fs, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 255)
    end
end

-- Barra de progreso de carga
function Menu.DrawLoadingBar(alpha)
    if alpha <= 0 then return end
    local sw, sh = 1920, 1080
    if Susano.GetScreenWidth then sw, sh = Susano.GetScreenWidth(), Susano.GetScreenHeight() end
    local w = 500
    local h = 4
    local x = sw/2 - w/2
    local y = sh - 80
    Menu.DrawRoundedRect(x, y, w, h, 40,50,80, 180*alpha, 2)
    local progressW = w * (Menu.LoadingProgress / 100)
    if progressW > 0 then
        Menu.DrawRoundedRect(x, y, progressW, h, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255*alpha, 2)
        Menu.DrawRect(x+progressW-3, y, 4, h, 1,1,1, 150*alpha)
    end
    local percent = string.format("%.0f%%", Menu.LoadingProgress)
    local fs = 15
    local tw = Susano.GetTextWidth and Susano.GetTextWidth(percent, fs) or (string.len(percent)*8)
    Menu.DrawText(x+w/2-tw/2, y-20, percent, fs, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 255*alpha)
    local status = "INICIANDO"
    if Menu.LoadingProgress >= 100 then status = "LISTO" end
    local stw = Susano.GetTextWidth and Susano.GetTextWidth(status, 13) or (string.len(status)*7)
    Menu.DrawText(x+w/2-stw/2, y-38, status, 13, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255*alpha)
end

-- Selector de tecla (para abrir menú y para keybinds) CON BANNER Y VISUALIZACIÓN EN VIVO
function Menu.DrawKeySelector(alpha)
    if alpha <= 0 then return end
    local sw, sh = 1920, 1080
    if Susano.GetScreenWidth then sw, sh = Susano.GetScreenWidth(), Susano.GetScreenHeight() end
    local w = 420
    local h = 150
    local x = sw/2 - w/2
    local y = sh - 200

    -- Fondo principal
    Menu.DrawRoundedRect(x, y, w, h, 0,0,0, 220*alpha, 6)
    Menu.DrawRect(x, y, w, 1, Menu.Colors.BorderNeon.r/255.0, Menu.Colors.BorderNeon.g/255.0, Menu.Colors.BorderNeon.b/255.0, 200*alpha)

    -- Banner (si está habilitado)
    local bannerH = 0
    if Menu.Banner.enabled and Menu.bannerTexture and Menu.bannerTexture>0 and Susano.DrawImage then
        bannerH = 50
        Susano.DrawImage(Menu.bannerTexture, x+10, y+5, w-20, bannerH, 1,1,1, 0.8*alpha, 0)
    else
        -- Logo textual pequeño
        bannerH = 30
        Menu.DrawText(x+20, y+8, "⚡ PHAZE ⚡", 20, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255*alpha)
    end

    local title = "▸ ASIGNAR TECLA ◂"
    Menu.DrawText(x+20, y + bannerH + 12, title, 14, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255*alpha)
    
    local itemName = Menu.BindingItem and Menu.BindingItem.name or "Abrir menú"
    local displayKey = Menu.BindingKeyName or "..."
    if Menu.SelectingKey and Menu.TempKeyPressed then
        displayKey = Menu.TempKeyPressed
    elseif Menu.SelectingBind and Menu.TempPressedKey then
        displayKey = Menu.TempPressedKey
    end
    
    Menu.DrawText(x+20, y + bannerH + 40, itemName, 14, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 255*alpha)
    Menu.DrawText(x+20, y + bannerH + 65, "Presiona cualquier tecla...", 12, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 200*alpha)
    
    local boxW, boxH = 75, 45
    local boxX = x + w - boxW - 20
    local boxY = y + h/2 - boxH/2
    Menu.DrawRect(boxX, boxY, boxW, boxH, 0,0,0, 255*alpha)
    Menu.DrawRect(boxX, boxY, boxW, 1, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 200*alpha)
    local kw = Susano.GetTextWidth and Susano.GetTextWidth(displayKey, 18) or (string.len(displayKey)*9)
    Menu.DrawText(boxX+boxW/2-kw/2, boxY+boxH/2-9, displayKey, 18, 255,240,100, 255*alpha)
end

-- Panel de teclas rápidas (lateral)
function Menu.DrawKeybindsInterface(alpha)
    if alpha <= 0 then return end
    if type(Menu.Categories) ~= "table" then return end
    local binds = {}
    for _,cat in SafeIpairs(Menu.Categories) do
        if cat.hasTabs and cat.tabs then
            for _,tab in SafeIpairs(cat.tabs) do
                if tab.items then
                    for _,it in SafeIpairs(tab.items) do
                        if it.bindKey and it.bindKeyName and (it.type=="toggle" or it.type=="action") then
                            table.insert(binds, {name=it.name, key=it.bindKeyName, active=it.type=="toggle" and it.value})
                        end
                    end
                end
            end
        end
    end
    if #binds == 0 then return end
    local sw, sh = 1920, 1080
    if Susano.GetScreenWidth then sw, sh = Susano.GetScreenWidth(), Susano.GetScreenHeight() end
    local w = 250
    local h = 40 + #binds * 24
    local x = sw - w - 20
    local y = 80
    Menu.DrawRoundedRect(x, y, w, h, 0,0,0, 200*alpha, 6)
    Menu.DrawRect(x, y, w, 1, Menu.Colors.BorderNeon.r/255.0, Menu.Colors.BorderNeon.g/255.0, Menu.Colors.BorderNeon.b/255.0, 150*alpha)
    Menu.DrawText(x+15, y+10, "⚡ TECLAS RÁPIDAS", 12, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255*alpha)
    for i, bind in SafeIpairs(binds) do
        local lineY = y + 32 + (i-1)*22
        local text = bind.name .. "  [" .. bind.key .. "]"
        if bind.active ~= nil then
            text = text .. (bind.active and "  ✓" or "  ✗")
        end
        Menu.DrawText(x+15, lineY, text, 11, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 200*alpha)
    end
end

-- Partículas de nieve
Menu.Particles = {}
for i=1, 100 do
    table.insert(Menu.Particles, {
        x = math.random(0,1000)/1000,
        y = math.random(0,1000)/1000,
        speedY = math.random(20,100)/10000,
        speedX = math.random(-20,20)/10000,
        size = math.random(1,2)
    })
end

function Menu.DrawBackground()
    local p = Menu.GetScaledPosition()
    local x = p.x
    local y = p.y
    local w = p.width - 1
    local actualHeight = Menu.GetActualHeight()
    -- Fondo negro con 30% opacidad
    Menu.DrawRoundedRect(x, y, w, actualHeight, 0,0,0, Menu.Colors.BgMain.a/255.0, p.headerRadius)
    if Menu.ShowSnowflakes then
        for _, part in SafeIpairs(Menu.Particles) do
            part.y = part.y + part.speedY
            part.x = part.x + part.speedX
            if part.y > 1 then part.y = 0; part.x = math.random(0,1000)/1000 end
            if part.x < 0 then part.x = 1 elseif part.x > 1 then part.x = 0 end
            local px = x + part.x * w
            local py = y + part.y * actualHeight
            Menu.DrawRect(px, py, part.size, part.size, 200,220,255, 100)
        end
    end
end

-- ========== MANEJO DE ENTRADA ==========
Menu.KeyStates = {}
function Menu.IsKeyJustPressed(keyCode)
    if not Susano or not Susano.GetAsyncKeyState then return false end

    local down, pressed = Susano.GetAsyncKeyState(keyCode)

    -- Susano puede devolver booleanos o numeros segun version/build.
    local downNow =
        down == true or
        down == 1 or
        (type(down) == "number" and down ~= 0)

    local pressedNow =
        pressed == true or
        pressed == 1 or
        (type(pressed) == "number" and pressed ~= 0)

    local wasDown = Menu.KeyStates[keyCode] or false
    Menu.KeyStates[keyCode] = downNow

    return pressedNow or (downNow and not wasDown)
end

local captureKeys = {
    0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,
    0x4E,0x4F,0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,
    0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,
    0x20,0x1B,0x08,0x09,0x10,0x11,0x12,
    0x25,0x26,0x27,0x28,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x7B,
    0x2D,0x2E,0x21,0x22,0x23,0x24
}
Menu.KeyNames = {
    [0x08]="Retroceso", [0x09]="Tabulador", [0x0D]="Intro", [0x10]="Mayús",
    [0x11]="Ctrl", [0x12]="Alt", [0x13]="Pausa", [0x14]="Bloq Mayús",
    [0x1B]="ESC", [0x20]="Espacio", [0x21]="Re Pág", [0x22]="Av Pág",
    [0x23]="Fin", [0x24]="Inicio", [0x25]="Izquierda", [0x26]="Arriba",
    [0x27]="Derecha", [0x28]="Abajo", [0x2D]="Insert", [0x2E]="Supr",
    [0x30]="0", [0x31]="1", [0x32]="2", [0x33]="3", [0x34]="4",
    [0x35]="5", [0x36]="6", [0x37]="7", [0x38]="8", [0x39]="9",
    [0x41]="A", [0x42]="B", [0x43]="C", [0x44]="D", [0x45]="E",
    [0x46]="F", [0x47]="G", [0x48]="H", [0x49]="I", [0x4A]="J",
    [0x4B]="K", [0x4C]="L", [0x4D]="M", [0x4E]="N", [0x4F]="O",
    [0x50]="P", [0x51]="Q", [0x52]="R", [0x53]="S", [0x54]="T",
    [0x55]="U", [0x56]="V", [0x57]="W", [0x58]="X", [0x59]="Y",
    [0x5A]="Z", [0x60]="0 num", [0x61]="1 num", [0x62]="2 num",
    [0x63]="3 num", [0x64]="4 num", [0x65]="5 num", [0x66]="6 num",
    [0x67]="7 num", [0x68]="8 num", [0x69]="9 num",
    [0x6A]="Multiplicar", [0x6B]="Sumar", [0x6D]="Restar", [0x6E]="Decimal",
    [0x6F]="Dividir", [0x70]="F1", [0x71]="F2", [0x72]="F3", [0x73]="F4",
    [0x74]="F5", [0x75]="F6", [0x76]="F7", [0x77]="F8", [0x78]="F9",
    [0x79]="F10", [0x7A]="F11", [0x7B]="F12",
    [0x90]="Bloq Num", [0x91]="Bloq Despl",
    [0xA0]="Mayús Izq", [0xA1]="Mayús Der", [0xA2]="Ctrl Izq",
    [0xA3]="Ctrl Der", [0xA4]="Alt Izq", [0xA5]="Alt Der"
}
function Menu.GetKeyName(k) return Menu.KeyNames[k] or ("0x"..string.format("%02X",k)) end

function Menu.HandleInput()
    if Menu.IsLoading or not Menu.LoadingComplete then return end
    if Menu.InputOpen then return end

    -- Asignación de tecla para binding (ítems)
    if Menu.SelectingBind then
        if Menu.IsKeyJustPressed(0x0D) then
            if Menu.BindingKey and Menu.BindingItem then
                Menu.BindingItem.bindKey = Menu.BindingKey
                Menu.BindingItem.bindKeyName = Menu.BindingKeyName
            end
            Menu.SelectingBind = false
            Menu.BindingItem = nil
            Menu.TempPressedKey = nil
            return
        end
        for _,k in SafeIpairs(captureKeys) do
            if k ~= 0x0D and Menu.IsKeyJustPressed(k) then
                Menu.BindingKey = k
                Menu.BindingKeyName = Menu.GetKeyName(k)
                Menu.TempPressedKey = Menu.BindingKeyName
                break
            end
        end
        return
    end

    -- Selección de tecla para abrir menú
    if Menu.SelectingKey then
        if Menu.IsKeyJustPressed(0x0D) then
            if Menu.SelectedKey then
                Menu.SelectingKey = false
                Menu.TempKeyPressed = nil
            end
            return
        end
        for _,k in SafeIpairs(captureKeys) do
            if k ~= 0x0D and Menu.IsKeyJustPressed(k) then
                Menu.SelectedKey = k
                Menu.SelectedKeyName = Menu.GetKeyName(k)
                Menu.TempKeyPressed = Menu.SelectedKeyName
                break
            end
        end
        return
    end

    -- Ejecutar keybinds
    if type(Menu.Categories) == "table" then
    for _,cat in SafeIpairs(Menu.Categories) do
        if cat.hasTabs and cat.tabs then
            for _,tab in SafeIpairs(cat.tabs) do
                if tab.items then
                    for _,it in SafeIpairs(tab.items) do
                        if it.bindKey and (it.type=="toggle" or it.type=="action") then
                            if Menu.IsKeyJustPressed(it.bindKey) then
                                if it.type=="toggle" then
                                    it.value = not it.value
                                    it.animTarget = it.value and 1 or 0
                                    if it.name == "Modo editor" then Menu.EditorMode = it.value end
                                    if it.name == "Mostrar teclas rápidas" then Menu.ShowKeybinds = it.value end
                                    if it.name == "Copos de nieve" then Menu.ShowSnowflakes = it.value end
                                    if it.onClick then it.onClick(it.value) end
                                elseif it.type=="action" then
                                    if it.onClick then it.onClick() end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    end

    -- Tecla para mostrar/ocultar menú
    local toggleKey = Menu.SelectedKey or Menu.MenuToggleKey or 0x4E
    if Menu.IsKeyJustPressed(toggleKey) then
        Menu.Visible = not Menu.Visible
        if not Menu.Visible and not Menu.ShowKeybinds then
            if Susano.ResetFrame and not Menu.PreventResetFrame then Susano.ResetFrame() end
        end
    end

    if not Menu.Visible then return end

    -- Modo editor
    if Menu.EditorMode then
        local sw, sh = 1920, 1080
        if Susano.GetScreenWidth then sw, sh = Susano.GetScreenWidth(), Susano.GetScreenHeight() end
        local cursor = Susano.GetCursorPos and Susano.GetCursorPos()
        local mx, my = 0,0
        if cursor then
            if type(cursor)=="table" then
                mx = cursor[1] or cursor.x or 0
                my = cursor[2] or cursor.y or 0
            else
                mx, my = cursor.x or 0, cursor.y or 0
            end
        end
        local lmb = false
        if Susano.GetAsyncKeyState then
            local d,p = Susano.GetAsyncKeyState(0x01)
            lmb = d==true or d==1
        end
        if lmb and not Menu.EditorDragging then
            local menuW = Menu.Position.width
            local totalH = Menu.GetActualHeight()
            if mx>=Menu.Position.x and mx<=Menu.Position.x+menuW and my>=Menu.Position.y and my<=Menu.Position.y+totalH then
                Menu.EditorDragging = true
                Menu.EditorDragOffsetX = mx - Menu.Position.x
                Menu.EditorDragOffsetY = my - Menu.Position.y
            end
        elseif not lmb then
            Menu.EditorDragging = false
        end
        if Menu.EditorDragging then
            local newX = mx - Menu.EditorDragOffsetX
            local newY = my - Menu.EditorDragOffsetY
            newX = math.max(0, math.min(sw-Menu.Position.width, newX))
            newY = math.max(0, math.min(sh-totalH, newY))
            Menu.Position.x = newX
            Menu.Position.y = newY
        end
        return
    end

    -- Navegación normal
    if Menu.OpenedCategory then
        local cat = Menu.Categories[Menu.OpenedCategory]
        if not cat or not cat.hasTabs or not cat.tabs then
            Menu.OpenedCategory = nil
            return
        end
        local curTab = cat.tabs[Menu.CurrentTab]
        if curTab and curTab.items then
            -- Movimiento vertical
            if Menu.IsKeyJustPressed(0x26) then  -- Up
                Menu.CurrentItem = findNextNonSeparator(curTab.items, Menu.CurrentItem, -1)
            elseif Menu.IsKeyJustPressed(0x28) then  -- Down
                Menu.CurrentItem = findNextNonSeparator(curTab.items, Menu.CurrentItem, 1)
            -- Sliders y selectores (← y →)
            elseif Menu.IsKeyJustPressed(0x25) then  -- Left
                local item = curTab.items[Menu.CurrentItem]
                if item then
                    if item.type == "slider" then
                        local step = item.step or 1
                        item.value = math.max(item.min or 0, (item.value or 0) - step)
                        if item.name == "Menú suave" then Menu.SmoothFactor = item.value/100 end
                        if item.name == "Tamaño del menú" then Menu.Scale = item.value/100 end
                        if item.onClick then item.onClick(item.value) end
                    elseif item.type == "selector" then
                        local idx = (item.selected or 1) - 1
                        if idx < 1 then idx = #item.options end
                        item.selected = idx
                        if item.name == "Tema del menú" then Menu.ApplyTheme(item.options[idx]) end
                        if item.onClick then item.onClick(item.selected, item.options[item.selected]) end
                    elseif item.type == "toggle_selector" then
                        local idx = (item.selected or 1) - 1
                        if idx < 1 then idx = #item.options end
                        item.selected = idx
                    elseif item.type == "toggle" and item.hasSlider then
                        item.sliderValue = math.max(item.sliderMin or 0, (item.sliderValue or 0) - (item.sliderStep or 0.1))
                    end
                end
            elseif Menu.IsKeyJustPressed(0x27) then  -- Right
                local item = curTab.items[Menu.CurrentItem]
                if item then
                    if item.type == "slider" then
                        local step = item.step or 1
                        item.value = math.min(item.max or 100, (item.value or 0) + step)
                        if item.name == "Menú suave" then Menu.SmoothFactor = item.value/100 end
                        if item.name == "Tamaño del menú" then Menu.Scale = item.value/100 end
                        if item.onClick then item.onClick(item.value) end
                    elseif item.type == "selector" then
                        local idx = (item.selected or 1) + 1
                        if idx > #item.options then idx = 1 end
                        item.selected = idx
                        if item.name == "Tema del menú" then Menu.ApplyTheme(item.options[idx]) end
                        if item.onClick then item.onClick(item.selected, item.options[item.selected]) end
                    elseif item.type == "toggle_selector" then
                        local idx = (item.selected or 1) + 1
                        if idx > #item.options then idx = 1 end
                        item.selected = idx
                    elseif item.type == "toggle" and item.hasSlider then
                        item.sliderValue = math.min(item.sliderMax or 100, (item.sliderValue or 0) + (item.sliderStep or 0.1))
                    end
                end
            -- Navegación horizontal con Q y E (cambio de pestaña)
            elseif Menu.IsKeyJustPressed(0x51) then  -- Q
                if Menu.CurrentTab > 1 then
                    Menu.CurrentTab = Menu.CurrentTab - 1
                    local newTab = cat.tabs[Menu.CurrentTab]
                    if newTab and newTab.items then
                        Menu.CurrentItem = findNextNonSeparator(newTab.items, 0, 1)
                    else
                        Menu.CurrentItem = 1
                    end
                elseif Menu.TopLevelTabs then
                    Menu.CurrentTopTab = Menu.CurrentTopTab - 1
                    if Menu.CurrentTopTab < 1 then Menu.CurrentTopTab = #Menu.TopLevelTabs end
                    Menu.UpdateCategoriesFromTopTab()
                end
            elseif Menu.IsKeyJustPressed(0x45) then  -- E
                if Menu.CurrentTab < #cat.tabs then
                    Menu.CurrentTab = Menu.CurrentTab + 1
                    local newTab = cat.tabs[Menu.CurrentTab]
                    if newTab and newTab.items then
                        Menu.CurrentItem = findNextNonSeparator(newTab.items, 0, 1)
                    else
                        Menu.CurrentItem = 1
                    end
                elseif Menu.TopLevelTabs then
                    Menu.CurrentTopTab = Menu.CurrentTopTab + 1
                    if Menu.CurrentTopTab > #Menu.TopLevelTabs then Menu.CurrentTopTab = 1 end
                    Menu.UpdateCategoriesFromTopTab()
                end
            -- Atrás / Cerrar
            elseif Menu.IsKeyJustPressed(0x08) then  -- Backspace
                if Menu.TopLevelTabs and Menu.TopLevelTabs[Menu.CurrentTopTab].autoOpen then
                    if Menu.CurrentTopTab > 1 then
                        Menu.CurrentTopTab = 1
                        Menu.UpdateCategoriesFromTopTab()
                    else
                        Menu.Visible = false
                    end
                else
                    Menu.OpenedCategory = nil
                    Menu.CurrentItem = 1
                    Menu.CurrentTab = 1
                end
            elseif Menu.IsKeyJustPressed(0x0D) then  -- Enter
                local item = curTab.items[Menu.CurrentItem]
                if item and not item.isSeparator then
                    if item.type == "toggle" or item.type == "toggle_selector" then
                        item.value = not item.value
                        item.animTarget = item.value and 1 or 0
                        if item.name == "Mostrar teclas rápidas" then Menu.ShowKeybinds = item.value end
                        if item.name == "Modo editor" then Menu.EditorMode = item.value end
                        if item.name == "Copos de nieve" then Menu.ShowSnowflakes = item.value end
                        if item.onClick then item.onClick(item.value) end
                    elseif item.type == "action" then
                        if item.name == "Cambiar tecla de menú" then
                            Menu.SelectingKey = true
                            Menu.TempKeyPressed = nil
                        end
                        if item.onClick then item.onClick() end
                    elseif item.type == "selector" then
                        if item.onClick then item.onClick(item.selected, item.options[item.selected]) end
                    end
                end
            elseif Menu.IsKeyJustPressed(0x78) then  -- F9
                local item = curTab.items[Menu.CurrentItem]
                if item and not item.isSeparator then
                    Menu.SelectingBind = true
                    Menu.BindingItem = item
                    Menu.BindingKey = item.bindKey
                    Menu.BindingKeyName = item.bindKeyName
                    Menu.TempPressedKey = item.bindKeyName or "..."
                end
            end
        end
    else
        -- Menú principal
        if Menu.IsKeyJustPressed(0x26) then  -- Up
            Menu.CurrentCategory = Menu.CurrentCategory - 1
            if Menu.CurrentCategory < 2 then Menu.CurrentCategory = #Menu.Categories end
        elseif Menu.IsKeyJustPressed(0x28) then  -- Down
            Menu.CurrentCategory = Menu.CurrentCategory + 1
            if Menu.CurrentCategory > #Menu.Categories then Menu.CurrentCategory = 2 end
        elseif Menu.IsKeyJustPressed(0x25) or Menu.IsKeyJustPressed(0x41) then  -- Left / A (cambiar top tab)
            if Menu.TopLevelTabs then
                Menu.CurrentTopTab = Menu.CurrentTopTab - 1
                if Menu.CurrentTopTab < 1 then Menu.CurrentTopTab = #Menu.TopLevelTabs end
                Menu.UpdateCategoriesFromTopTab()
            end
        elseif Menu.IsKeyJustPressed(0x27) or Menu.IsKeyJustPressed(0x45) then  -- Right / E
            if Menu.TopLevelTabs then
                Menu.CurrentTopTab = Menu.CurrentTopTab + 1
                if Menu.CurrentTopTab > #Menu.TopLevelTabs then Menu.CurrentTopTab = 1 end
                Menu.UpdateCategoriesFromTopTab()
            end
        elseif Menu.IsKeyJustPressed(0x0D) then  -- Enter
            local cat = Menu.Categories[Menu.CurrentCategory]
            if cat and cat.hasTabs and cat.tabs then
                Menu.OpenedCategory = Menu.CurrentCategory
                Menu.CurrentTab = 1
                if cat.tabs[1] and cat.tabs[1].items then
                    Menu.CurrentItem = findNextNonSeparator(cat.tabs[1].items, 0, 1)
                else
                    Menu.CurrentItem = 1
                end
            end
        elseif Menu.IsKeyJustPressed(0x08) then  -- Backspace: cerrar menú
            Menu.Visible = false
        end
    end
end

function Menu.UpdateCategoriesFromTopTab()
    if not Menu.TopLevelTabs then return end
    local currentTop = Menu.TopLevelTabs[Menu.CurrentTopTab]
    if not currentTop then return end
    Menu.Categories = {}
    table.insert(Menu.Categories, { name = currentTop.name })
    for _, cat in SafeIpairs(currentTop.categories) do
        table.insert(Menu.Categories, cat)
    end
    Menu.CurrentCategory = 2
    Menu.CategoryScrollOffset = 0
    Menu.OpenedCategory = nil
    if currentTop.autoOpen then
        Menu.OpenedCategory = 2
        Menu.CurrentTab = 1
        Menu.ItemScrollOffset = 0
        Menu.CurrentItem = 1
    end
end

Menu.Banner = {
    enabled = true,
    imageUrl = "https://i.imgur.com/KNnAjq7.jpeg",
    height = 100
}
Menu.bannerTexture = nil
Menu.bannerWidth = 0
Menu.bannerHeight = 0

Menu.PlayerInfoBanner = {
    enabled = true,
    imageUrl = "https://i.imgur.com/Zqt1mHg.jpeg",
    height = 46
}
Menu.playerInfoBannerTexture = nil
Menu.playerInfoBannerWidth = 0
Menu.playerInfoBannerHeight = 0

function Menu.LoadBannerTexture(url)
    if not url or url == "" then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end
    CreateThread(function()
        local status, body = Susano.HttpGet(url)
        if status == 200 and body and #body > 0 then
            local tex, w, h = Susano.LoadTextureFromBuffer(body)
            if tex and tex ~= 0 then
                Menu.bannerTexture = tex
                Menu.bannerWidth = w
                Menu.bannerHeight = h
            end
        end
    end)
end

function Menu.LoadPlayerInfoBannerTexture(url)
    if not url or url == "" then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end
    CreateThread(function()
        local status, body = Susano.HttpGet(url)
        if status == 200 and body and #body > 0 then
            local tex, w, h = Susano.LoadTextureFromBuffer(body)
            if tex and tex ~= 0 then
                Menu.playerInfoBannerTexture = tex
                Menu.playerInfoBannerWidth = w
                Menu.playerInfoBannerHeight = h
            end
        end
    end)
end


function Menu.GetCurrentSelectedItem()
    if not Menu.Categories then return nil, nil, nil end
    if Menu.OpenedCategory then
        local cat = Menu.Categories[Menu.OpenedCategory]
        if cat and cat.hasTabs and cat.tabs then
            local tab = cat.tabs[Menu.CurrentTab]
            if tab and tab.items then
                return tab.items[Menu.CurrentItem], cat, tab
            end
        end
    else
        local cat = Menu.Categories[Menu.CurrentCategory]
        return cat, cat, nil
    end
    return nil, nil, nil
end

function Menu.IsOnlineCategory(cat, tab)
    local c = cat and cat.name and string.lower(tostring(cat.name)) or ""
    local t = tab and tab.name and string.lower(tostring(tab.name)) or ""
    return c:find("en linea", 1, true) or c:find("online", 1, true) or t:find("en linea", 1, true) or t:find("online", 1, true)
end

local function _cleanPlayerMenuName(name)
    name = tostring(name or "")
    name = name:gsub("%[.-%]", "")
    name = name:gsub("[»•›<>()]", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

function Menu.ResolvePlayerFromItem(item)
    if not item then return nil end

    local candidates = {
        item.serverId, item.serverID, item.sid,
        item.playerId, item.playerID, item.player,
        item.id, item.value,
        Menu.SelectedPlayer
    }

    for _,v in SafeIpairs(candidates) do
        local n = tonumber(v)
        if n then
            for _,pid in SafeIpairs(GetActivePlayers and GetActivePlayers() or {}) do
                if GetPlayerServerId(pid) == n or pid == n then
                    return pid, GetPlayerServerId(pid)
                end
            end
        end
    end

    local targetName = string.lower(_cleanPlayerMenuName(item.name or item.label or item.text or ""))
    if targetName ~= "" and GetActivePlayers then
        for _,pid in SafeIpairs(GetActivePlayers()) do
            local pname = GetPlayerName(pid) or ""
            if string.lower(pname) == targetName or string.lower(_cleanPlayerMenuName(pname)) == targetName then
                return pid, GetPlayerServerId(pid)
            end
        end
        for _,pid in SafeIpairs(GetActivePlayers()) do
            local pname = string.lower(GetPlayerName(pid) or "")
            if pname ~= "" and (targetName:find(pname, 1, true) or pname:find(targetName, 1, true)) then
                return pid, GetPlayerServerId(pid)
            end
        end
    end

    return nil, nil
end

function Menu.UpdateHoveredPlayerInfo()
    local item, cat, tab = Menu.GetCurrentSelectedItem()
    if not Menu.Visible or not Menu.IsOnlineCategory(cat, tab) or not item or item.isSeparator then
        Menu.PlayerInfo = nil
        Menu.PlayerInfoAlpha = math.max(0, (Menu.PlayerInfoAlpha or 0) - 0.08)
        return
    end

    local pid, sid = Menu.ResolvePlayerFromItem(item)
    if not pid then
        Menu.PlayerInfo = nil
        Menu.PlayerInfoAlpha = math.max(0, (Menu.PlayerInfoAlpha or 0) - 0.08)
        return
    end

    local ped = GetPlayerPed(pid)
    if not ped or ped == 0 or (DoesEntityExist and not DoesEntityExist(ped)) then
        Menu.PlayerInfo = nil
        Menu.PlayerInfoAlpha = math.max(0, (Menu.PlayerInfoAlpha or 0) - 0.08)
        return
    end

    local myPed = PlayerPedId and PlayerPedId() or 0
    local distance = 0.0
    if myPed ~= 0 and GetEntityCoords then
        local a = GetEntityCoords(myPed)
        local b = GetEntityCoords(ped)
        if a and b then distance = #(a - b) end
    end

    local weaponHash = GetSelectedPedWeapon and GetSelectedPedWeapon(ped) or 0
    local unarmed = GetHashKey and GetHashKey("WEAPON_UNARMED") or -1569615261
    local hasWeapon = weaponHash and weaponHash ~= 0 and weaponHash ~= unarmed

    Menu.PlayerInfo = {
        name = GetPlayerName(pid) or _cleanPlayerMenuName(item.name),
        serverId = sid or 0,
        localId = pid,
        distance = distance,
        hasWeapon = hasWeapon,
        weaponHash = weaponHash or 0
    }
    Menu.PlayerInfoAlpha = math.min(1, (Menu.PlayerInfoAlpha or 0) + 0.12)
end

function Menu.DrawPlayerInfoPanel()
    Menu.UpdateHoveredPlayerInfo()
    local info = Menu.PlayerInfo
    local alpha = Menu.PlayerInfoAlpha or 0
    if not info or alpha <= 0 then return end

    local p = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x = p.x + p.width + 12
    local y = p.y + p.headerHeight + 10
    local w = 235 * scale
    local bannerH = (Menu.PlayerInfoBanner and Menu.PlayerInfoBanner.enabled) and ((Menu.PlayerInfoBanner.height or 46) * scale) or 0
    local gap = bannerH > 0 and (-3 * scale) or 0
    local panelH = 132 * scale
    local totalH = bannerH + gap + panelH
    local acR, acG, acB = Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0

    -- Banner superior "Player Info", cargado igual que el banner principal.
    if bannerH > 0 then
        if Menu.playerInfoBannerTexture and Menu.playerInfoBannerTexture > 0 and Susano.DrawImage then
            Susano.DrawImage(Menu.playerInfoBannerTexture, x, y, w, bannerH, 1, 1, 1, 1.0 * alpha, 0)
        else
            Menu.DrawRoundedRect(x, y, w, bannerH, 0,0,0, 185*alpha, 7)
            Menu.DrawRoundedRect(x+2, y+2, w-4, bannerH-4, 8,12,20, 150*alpha, 6)
            Menu.DrawRect(x, y+bannerH-1, w, 1, acR, acG, acB, 160*alpha)
            local title = "PLAYER INFO"
            local fs = 16
            local tw = Susano.GetTextWidth and Susano.GetTextWidth(title, fs) or (string.len(title)*8)
            Menu.DrawText(x+w/2-tw/2, y+bannerH/2-fs/2, title, fs, acR, acG, acB, 255*alpha)
        end
    end

    local panelY = y + bannerH + gap
    Menu.DrawRoundedRect(x, panelY, w, panelH, 0,0,0, 185*alpha, 8)
    Menu.DrawRoundedRect(x+2, panelY+2, w-4, panelH-4, 8,12,20, 160*alpha, 7)
    Menu.DrawRect(x, panelY, w, 1, acR, acG, acB, 180*alpha)
    Menu.DrawRect(x, panelY+panelH-1, w, 1, acR, acG, acB, 60*alpha)

    Menu.DrawText(x+14, panelY+12, info.name, 16, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 255*alpha)

    local lineY = panelY + 42
    Menu.DrawText(x+14, lineY, "ID servidor", 11, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 220*alpha)
    Menu.DrawText(x+w-55, lineY, tostring(info.serverId), 12, 1,1,1, 255*alpha)

    lineY = lineY + 22
    Menu.DrawText(x+14, lineY, "ID local", 11, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 220*alpha)
    Menu.DrawText(x+w-55, lineY, tostring(info.localId), 12, 1,1,1, 255*alpha)

    lineY = lineY + 22
    Menu.DrawText(x+14, lineY, "Distancia", 11, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 220*alpha)
    Menu.DrawText(x+w-75, lineY, string.format("%.1fm", info.distance or 0), 12, 1,1,1, 255*alpha)

    lineY = lineY + 22
    local weaponText = info.hasWeapon and ("Si 0x" .. string.format("%X", tonumber(info.weaponHash) or 0)) or "No"
    Menu.DrawText(x+14, lineY, "Arma en mano", 11, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 220*alpha)
    Menu.DrawText(x+w-105, lineY, weaponText, 12, info.hasWeapon and 1 or 0.6, info.hasWeapon and 0.86 or 1, info.hasWeapon and 0.35 or 0.6, 255*alpha)
end

function Menu.Render()
    if Menu.TopLevelTabs and not Menu.Categories then Menu.UpdateCategoriesFromTopTab() end
    if not Susano.BeginFrame then return end
    local dt = GetFrameTime and GetFrameTime() or 0.016
    local anim = 5.0 * dt
    if Menu.IsLoading then
        Menu.LoadingBarAlpha = math.min(1, Menu.LoadingBarAlpha + anim)
    else
        Menu.LoadingBarAlpha = math.max(0, Menu.LoadingBarAlpha - anim)
    end
    if Menu.SelectingKey or Menu.SelectingBind then
        Menu.KeySelectorAlpha = math.min(1, Menu.KeySelectorAlpha + anim)
    else
        Menu.KeySelectorAlpha = math.max(0, Menu.KeySelectorAlpha - anim)
    end
    if Menu.ShowKeybinds then
        Menu.KeybindsInterfaceAlpha = math.min(1, Menu.KeybindsInterfaceAlpha + anim)
    else
        Menu.KeybindsInterfaceAlpha = math.max(0, Menu.KeybindsInterfaceAlpha - anim)
    end
    Susano.BeginFrame()
    if Menu.KeybindsInterfaceAlpha > 0 then Menu.DrawKeybindsInterface(Menu.KeybindsInterfaceAlpha) end
    if Menu.Visible then
        if Menu.EditorMode and Susano.EnableOverlay then Susano.EnableOverlay(true)
        elseif not Menu.EditorMode and Susano.EnableOverlay then Susano.EnableOverlay(false) end
        Menu.DrawBackground()
        Menu.DrawHeader()
        Menu.DrawCategories()
        Menu.DrawFooter()
        Menu.DrawPlayerInfoPanel()
        Menu.DrawAnticheatPanel()
    end
    if Menu.InputOpen then Menu.DrawInputWindow() end
    if Menu.LoadingBarAlpha > 0 then Menu.DrawLoadingBar(Menu.LoadingBarAlpha) end
    if Menu.KeySelectorAlpha > 0 then Menu.DrawKeySelector(Menu.KeySelectorAlpha) end
    if Menu.OnRender then pcall(Menu.OnRender) end
    if Susano.SubmitFrame then Susano.SubmitFrame() end
    if not Menu.Visible and not Menu.ShowKeybinds and Menu.LoadingBarAlpha<=0 and Menu.KeySelectorAlpha<=0 then
        if Susano.ResetFrame and not Menu.PreventResetFrame then Susano.ResetFrame() end
    end
end

function Menu.OpenInput(title, subtitle, callback)
    if type(subtitle)=="function" then callback, subtitle = subtitle, "Escribe el texto abajo" end
    Menu.InputTitle = title
    Menu.InputSubtitle = subtitle
    Menu.InputText = ""
    Menu.InputCallback = callback
    Menu.InputOpen = true
    Menu.SelectingKey = false
    Menu.SelectingBind = false
end

function Menu.DrawInputWindow()
    if not Menu.InputOpen then return end
    local sw, sh = 1920,1080
    if Susano.GetScreenWidth then sw, sh = Susano.GetScreenWidth(), Susano.GetScreenHeight() end
    local w, h = 350, 140
    local x, y = sw/2-w/2, sh/2-h/2
    Menu.DrawRoundedRect(x, y, w, h, 0,0,0, 230, 6)
    Menu.DrawRect(x, y, w, 1, Menu.Colors.BorderNeon.r/255.0, Menu.Colors.BorderNeon.g/255.0, Menu.Colors.BorderNeon.b/255.0, 255)
    Menu.DrawText(x+20, y+20, Menu.InputTitle, 17, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 255)
    Menu.DrawText(x+20, y+50, Menu.InputSubtitle, 12, Menu.Colors.TextDim.r/255.0, Menu.Colors.TextDim.g/255.0, Menu.Colors.TextDim.b/255.0, 255)
    local boxW, boxH = w-40, 30
    local boxX, boxY = x+20, y+80
    Menu.DrawRect(boxX-1, boxY-1, boxW+2, boxH+2, 0,0,0, 255)
    Menu.DrawRect(boxX, boxY, boxW, boxH, 0,0,0, 200)
    local display = Menu.InputText
    if math.floor(GetGameTimer()/500)%2==0 then display = display.."|" end
    if #display>30 then display = "..."..string.sub(display,-30) end
    Menu.DrawText(boxX+10, boxY+5, display, 15, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 255)
    if Menu.IsKeyJustPressed(0x0D) then
        Menu.InputOpen = false
        if Menu.InputCallback then Menu.InputCallback(Menu.InputText) end
    end
    if Menu.IsKeyJustPressed(0x08) then
        Menu.InputText = string.sub(Menu.InputText,1,-2)
    end
    if Menu.IsKeyJustPressed(0x1B) then Menu.InputOpen = false end
    local shift = Susano.GetAsyncKeyState and (Susano.GetAsyncKeyState(0x10) or Susano.GetAsyncKeyState(0xA0) or Susano.GetAsyncKeyState(0xA1))
    for i=0x41,0x5A do
        if Menu.IsKeyJustPressed(i) then
            local ch = string.char(i)
            if not shift then ch = string.lower(ch) end
            Menu.InputText = Menu.InputText .. ch
        end
    end
    for i=0x30,0x39 do
        if Menu.IsKeyJustPressed(i) then Menu.InputText = Menu.InputText .. string.char(i) end
    end
    if Menu.IsKeyJustPressed(0x20) then Menu.InputText = Menu.InputText .. " " end
    if Menu.IsKeyJustPressed(0xBD) then
        Menu.InputText = Menu.InputText .. (shift and "_" or "-")
    end
end

-- Inicialización: carga visual y apertura fija con N
CreateThread(function()
    Menu.LoadingStartTime = GetGameTimer() or 0
    while Menu.IsLoading do
        local now = GetGameTimer() or Menu.LoadingStartTime
        local elapsed = now - Menu.LoadingStartTime
        Menu.LoadingProgress = (elapsed / Menu.LoadingDuration) * 100
        if Menu.LoadingProgress >= 100 then
            Menu.LoadingProgress = 100
            Menu.IsLoading = false
            Menu.LoadingComplete = true
            Menu.SelectingKey = false
            Menu.SelectedKey = Menu.MenuToggleKey or 0x4E
            Menu.SelectedKeyName = "N"
            Menu.TempKeyPressed = nil
            break
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        Menu.Render()
        if Menu.LoadingComplete then Menu.HandleInput() end
        Wait(0)
    end
end)

if Menu.Banner.enabled and Menu.Banner.imageUrl then Menu.LoadBannerTexture(Menu.Banner.imageUrl) end
if Menu.PlayerInfoBanner and Menu.PlayerInfoBanner.enabled and Menu.PlayerInfoBanner.imageUrl then
    Menu.LoadPlayerInfoBannerTexture(Menu.PlayerInfoBanner.imageUrl)
end
Menu.ApplyTheme("BlackGlass")

-- Valores por defecto (fondo negro ya está, nieve activada)
CreateThread(function()
    while not Menu.Categories do Wait(100) end
    Wait(500)
    for _,cat in SafeIpairs(Menu.Categories) do
        if cat.name == "Ajustes" and cat.tabs then
            for _,tab in SafeIpairs(cat.tabs) do
                if tab.name == "General" and tab.items then
                    for _,it in SafeIpairs(tab.items) do
                        if it.name == "Fondo negro" and it.type == "toggle" then
                            it.value = true   -- ahora el fondo ya es negro, no hace falta este toggle, pero lo dejamos
                        end
                        if it.name == "Copos de nieve" and it.type == "toggle" then
                            it.value = true
                            Menu.ShowSnowflakes = true
                        end
                    end
                end
            end
        end
    end
end)

return Menu
