local Menu = {}
print("[Library] SENTEX_DYNAMIC_KEY_SELECTOR loaded - key selected after loading")

local function SafeTable(value)
    return type(value) == "table" and value or {}
end

local function SafeLen(value)
    return type(value) == "table" and #value or 0
end

local function SafeIpairs(value)
    if type(value) == "table" then return ipairs(value) end
    return function() return nil end
end

local function SafeInvoke(fn, ...)
    if type(fn) ~= "function" then return true end
    local ok, err = pcall(fn, ...)
    if not ok then
        print("[Library] callback error: " .. tostring(err))
    end
    return ok
end

Menu.Visible = false
Menu.PreventResetFrame = true
Menu.MenuToggleKey = nil -- Se asigna mediante la UI al terminar la carga
Menu.BuildVersion = "Build v8.0.1"
Menu.CurrentCategory = 2
Menu.CurrentPage = 1
Menu.ItemsPerPage = 11
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

-- Accesibilidad y efectos: opciones conservadoras por defecto.
Menu.ReduceMotion = true
Menu.ShowParticles = false
Menu.ShowSnowflakes = false -- alias de compatibilidad
Menu.ShowBanners = false
Menu.ShowIntenseGlows = false
Menu.HighContrast = false
Menu.TextScale = 1.0
Menu.BackgroundOpacity = 0.80
Menu.KeyRepeatDelay = 320
Menu.KeyRepeatInterval = 85
Menu.KeyRepeatStates = {}

-- Identificadores estables para evitar lógica dependiente del texto visible.
Menu.Ids = {
    EditorMode = "ui_editor_mode",
    ShowKeybinds = "ui_show_keybinds",
    Particles = "ui_particles",
    ReduceMotion = "ui_reduce_motion",
    AnimationSmoothness = "ui_animation_smoothness",
    MenuScale = "ui_menu_scale",
    TextScale = "ui_text_scale",
    BackgroundOpacity = "ui_background_opacity",
    HighContrast = "ui_high_contrast",
    Banners = "ui_banners",
    IntenseGlows = "ui_intense_glows",
    Theme = "ui_theme",
    Accent = "ui_accent",
    ChangeMenuKey = "action_change_menu_key"
}

Menu.SelectorY = 0
Menu.CategorySelectorY = 0
Menu.TabSelectorX = 0
Menu.TabSelectorWidth = 0
Menu.SmoothFactor = 0.10
Menu.VisualSmoothFactor = 0.11
Menu.AnimationSpeed = 10.5
Menu.ToggleAnimationSpeed = 13.0
Menu.FrameDelta = 0.016
Menu.MenuAlpha = 0.0
Menu.RenderAlpha = 1.0
Menu.ContentAlpha = 1.0
Menu.ContentSlideY = 0.0
Menu.LastContentState = nil
Menu.TopTabSelectorX = 0
Menu.TopTabSelectorWidth = 0
Menu.SmoothScrollCatY = 0
Menu.SmoothScrollItemY = 0
Menu.PlayerInfoAlpha = 0.0
Menu.PlayerInfo = nil
Menu.BacaneriasInfoAlpha = 0.0
Menu.BacaneriasInfo = nil
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

-- Aviso estilizado que aparece al terminar la carga.
Menu.LoadedNoticeActive = false
Menu.LoadedNoticeStartTime = nil
Menu.LoadedNoticeDuration = 5600

Menu.SelectingKey = false
Menu.SelectedKey = nil
Menu.SelectedKeyName = "SIN ASIGNAR"
Menu.SelectedControl = nil
Menu.TempKeyPressed = nil          -- para mostrar tecla en selector de menú
Menu.InitialKeySetupActive = false
Menu.KeyCaptureReadyAt = 0
Menu.KeySelectionConfirmedAt = nil
Menu.KeySelectionFeedback = nil
Menu.PreviousSelectedKey = nil
Menu.PreviousSelectedControl = nil

Menu.SelectingBind = false
Menu.BindingItem = nil
Menu.BindingKey = nil
Menu.BindingKeyName = nil
Menu.TempPressedKey = nil

Menu.ShowKeybinds = false
Menu.CurrentTopTab = 1

-- Interacción del menú: no captura el ratón ni bloquea controles.
-- El menú se sigue navegando por teclado y el jugador conserva el movimiento
-- y la cámara libre mientras el menú está abierto.
Menu.BlockGameControlsWhileOpen = false
Menu.UnlockMouseWhileOpen = false
Menu.EditorMouseWhileOpen = true
Menu._InteractionLockActive = false
Menu._CursorCenteredForOpen = false

function Menu.UpdateMenuInteractionLock()
    local menuActive = (Menu.Visible or Menu.SelectingKey or Menu.SelectingBind or Menu.InputOpen) and Menu.LoadingComplete and not Menu.IsLoading
    local cursorActive = Menu.Visible and Menu.EditorMode and Menu.EditorMouseWhileOpen and Menu.LoadingComplete and not Menu.IsLoading

    if cursorActive then
        -- Solo el modo editor necesita cursor del overlay para arrastrar el menú.
        -- Al abrir el menú normal no se activa el overlay, así FiveM conserva
        -- el movimiento del ratón para la cámara del jugador.
        if Susano then
            if Susano.EnableOverlay then pcall(Susano.EnableOverlay, true) end
            if Susano.SetCursorVisible then pcall(Susano.SetCursorVisible, true) end
            if Susano.ShowCursor then pcall(Susano.ShowCursor, true) end
        end

        if not Menu._CursorCenteredForOpen and SetCursorLocation then
            pcall(SetCursorLocation, 0.5, 0.5)
            Menu._CursorCenteredForOpen = true
        end
    else
        Menu._CursorCenteredForOpen = false
        if menuActive or Menu._InteractionLockActive then
            if Susano then
                if Susano.EnableOverlay then pcall(Susano.EnableOverlay, false) end
                if Susano.SetCursorVisible then pcall(Susano.SetCursorVisible, false) end
                if Susano.ShowCursor then pcall(Susano.ShowCursor, false) end
            end
        end
    end

    Menu._InteractionLockActive = cursorActive
end

-- Panel de anticheat (opcional)
Menu.AnticheatList = {}
function Menu.SetAnticheatInfo(detectedList)
    if not detectedList or type(detectedList) ~= "table" then
        Menu.AnticheatList = {}
        return
    end
    Menu.AnticheatList = {}
    for _, name in ipairs(detectedList) do
        table.insert(Menu.AnticheatList, { name = name, detected = true })
    end
end

-- ========== TOKENS VISUALES SEMÁNTICOS ==========
Menu.Colors = {
    BgMain      = { r = 0,   g = 0,   b = 0,   a = 204 },
    BorderNeon  = { r = 0,   g = 210, b = 255, a = 150 },
    Accent      = { r = 0,   g = 180, b = 255 },
    AccentDark  = { r = 0,   g = 120, b = 200 },
    Text        = { r = 255, g = 255, b = 255 },
    TextDim     = { r = 178, g = 188, b = 210 },
    Selected    = { r = 0,   g = 150, b = 230 },
}

Menu.VisualTokens = {}

local function _Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    return math.max(minValue, math.min(maxValue, value))
end

function Menu.RefreshVisualTokens()
    local bgAlpha = math.floor(_Clamp(Menu.BackgroundOpacity or 0.80, 0.60, 0.95) * 255 + 0.5)
    Menu.Colors.BgMain.a = bgAlpha

    local secondary = Menu.HighContrast and { r = 235, g = 240, b = 248 } or { r = 178, g = 188, b = 210 }
    Menu.Colors.TextDim = secondary
    Menu.Colors.BorderNeon.a = Menu.HighContrast and 235 or 150

    Menu.VisualTokens = {
        surface = { r = 0, g = 0, b = 0, a = bgAlpha },
        surfaceMuted = { r = 10, g = 14, b = 22, a = math.min(255, bgAlpha + 14) },
        surfaceElevated = { r = 7, g = 11, b = 18, a = math.min(255, bgAlpha + 28) },
        border = {
            r = Menu.Colors.BorderNeon.r,
            g = Menu.Colors.BorderNeon.g,
            b = Menu.Colors.BorderNeon.b,
            a = Menu.Colors.BorderNeon.a
        },
        accent = {
            r = Menu.Colors.Accent.r,
            g = Menu.Colors.Accent.g,
            b = Menu.Colors.Accent.b,
            a = 255
        },
        focus = {
            r = Menu.Colors.Selected.r,
            g = Menu.Colors.Selected.g,
            b = Menu.Colors.Selected.b,
            a = Menu.HighContrast and 255 or 220
        },
        textPrimary = { r = 255, g = 255, b = 255, a = 255 },
        textSecondary = { r = secondary.r, g = secondary.g, b = secondary.b, a = 235 },
        success = { r = 95, g = 235, b = 155, a = 255 },
        warning = { r = 255, g = 190, b = 80, a = 255 },
        danger = { r = 255, g = 100, b = 110, a = 255 }
    }
end

function Menu.GetToken(name)
    return (Menu.VisualTokens and Menu.VisualTokens[name]) or { r = 255, g = 255, b = 255, a = 255 }
end

function Menu.SetBackgroundOpacity(value)
    local normalized = tonumber(value) or 80
    if normalized > 1 then normalized = normalized / 100 end
    Menu.BackgroundOpacity = _Clamp(normalized, 0.60, 0.95)
    Menu.RefreshVisualTokens()
end

function Menu.SetTextScale(value)
    local normalized = tonumber(value) or 100
    if normalized > 2 then normalized = normalized / 100 end
    Menu.TextScale = _Clamp(normalized, 0.85, 1.35)
end

function Menu.SetHighContrast(enabled)
    Menu.HighContrast = enabled == true
    Menu.RefreshVisualTokens()
end

function Menu.SetParticlesEnabled(enabled)
    Menu.ShowParticles = enabled == true
    Menu.ShowSnowflakes = Menu.ShowParticles
end

function Menu.SetBannersEnabled(enabled)
    Menu.ShowBanners = enabled == true
    if Menu.ShowBanners then
        if Menu.Banner and Menu.Banner.enabled and Menu.Banner.imageUrl and Menu.LoadBannerTexture then
            Menu.LoadBannerTexture(Menu.Banner.imageUrl)
        end
        if Menu.PlayerInfoBanner and Menu.PlayerInfoBanner.enabled and Menu.PlayerInfoBanner.imageUrl and Menu.LoadPlayerInfoBannerTexture then
            Menu.LoadPlayerInfoBannerTexture(Menu.PlayerInfoBanner.imageUrl)
        end
        if Menu.BacaneriasInfoBanner and Menu.BacaneriasInfoBanner.enabled and Menu.BacaneriasInfoBanner.imageUrl and Menu.LoadBacaneriasInfoBannerTexture then
            Menu.LoadBacaneriasInfoBannerTexture(Menu.BacaneriasInfoBanner.imageUrl)
        end
        if Menu.KeySelectorBanner and Menu.KeySelectorBanner.enabled and Menu.KeySelectorBanner.imageUrl and Menu.LoadKeySelectorBannerTexture then
            Menu.LoadKeySelectorBannerTexture(Menu.KeySelectorBanner.imageUrl)
        end
    end
end

function Menu.ShouldDrawBanner(config)
    return Menu.ShowBanners == true and type(config) == "table" and config.enabled == true
end
Menu.CurrentTheme = "BlackGlass"
Menu.CurrentAccentName = "Cian"
Menu.AccentPresets = {
    Cian    = { accent = {0, 180, 255}, dark = {0, 105, 190}, selected = {0, 145, 225}, border = {0, 210, 255} },
    Azul    = { accent = {65, 125, 255}, dark = {35, 72, 190}, selected = {48, 102, 230}, border = {95, 155, 255} },
    Morado  = { accent = {170, 90, 255}, dark = {105, 45, 190}, selected = {145, 70, 225}, border = {195, 125, 255} },
    Rosa    = { accent = {255, 75, 170}, dark = {190, 35, 110}, selected = {225, 55, 145}, border = {255, 115, 195} },
    Rojo    = { accent = {255, 70, 75}, dark = {185, 35, 40}, selected = {225, 50, 55}, border = {255, 115, 115} },
    Verde   = { accent = {60, 220, 145}, dark = {25, 150, 90}, selected = {45, 195, 120}, border = {100, 245, 175} },
    Naranja = { accent = {255, 145, 45}, dark = {190, 85, 20}, selected = {230, 115, 30}, border = {255, 180, 80} },
    Blanco  = { accent = {230, 235, 245}, dark = {130, 140, 160}, selected = {185, 195, 215}, border = {255, 255, 255} }
}
Menu.AccentPresetOrder = {"Cian", "Azul", "Morado", "Rosa", "Rojo", "Verde", "Naranja", "Blanco"}

function Menu.ApplyAccentPreset(name)
    local preset = Menu.AccentPresets[name] or Menu.AccentPresets.Cian
    Menu.CurrentAccentName = Menu.AccentPresets[name] and name or "Cian"
    Menu.Colors.Accent = { r = preset.accent[1], g = preset.accent[2], b = preset.accent[3] }
    Menu.Colors.AccentDark = { r = preset.dark[1], g = preset.dark[2], b = preset.dark[3] }
    Menu.Colors.Selected = { r = preset.selected[1], g = preset.selected[2], b = preset.selected[3] }
    Menu.Colors.BorderNeon = { r = preset.border[1], g = preset.border[2], b = preset.border[3], a = Menu.HighContrast and 235 or 150 }
    Menu.RefreshVisualTokens()
end

function Menu.ApplyTheme(themeName)
    Menu.CurrentTheme = themeName or "BlackGlass"
    Menu.Colors.BgMain  = { r = 0, g = 0, b = 0, a = math.floor((Menu.BackgroundOpacity or 0.80) * 255 + 0.5) }
    Menu.Colors.Text    = { r = 255, g = 255, b = 255 }
    Menu.ApplyAccentPreset(Menu.CurrentAccentName or "Cian")
    Menu.RefreshVisualTokens()
    if Menu.ShowBanners then Menu.SetBannersEnabled(true) end
end

-- Dimensiones base. Todo el cálculo derivado vive en Menu.GetLayout().
Menu.Position = {
    x = 45,
    y = 80,
    width = 360,
    itemHeight = 27,
    rowSpacing = 2,
    mainMenuHeight = 23,
    headerHeight = 72,
    footerHeight = 26,
    footerSpacing = 4,
    mainMenuSpacing = 4,
    footerRadius = 4,
    itemRadius = 3,
    scrollbarWidth = 5,
    scrollbarPadding = 7,
    headerRadius = 6,
    anticheatPanelHeight = 0,
    anticheatSpacing = 6
}
Menu.Scale = 1.0

function Menu.GetScaledPosition()
    local scale = _Clamp(Menu.Scale or 1.0, 0.70, 1.50)
    return {
        x = Menu.Position.x,
        y = Menu.Position.y,
        width = Menu.Position.width * scale,
        itemHeight = Menu.Position.itemHeight * scale,
        rowSpacing = (Menu.Position.rowSpacing or 0) * scale,
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

function Menu.GetLayout()
    local p = Menu.GetScaledPosition()
    local scale = _Clamp(Menu.Scale or 1.0, 0.70, 1.50)
    local headerHeight = Menu.ShouldDrawBanner(Menu.Banner)
        and ((Menu.Banner.height or Menu.Position.headerHeight) * scale)
        or p.headerHeight

    local visibleRows = 0
    local totalRows = 0
    local hasTabBar = true

    if Menu.OpenedCategory then
        local cat = SafeTable(Menu.Categories)[Menu.OpenedCategory]
        if cat and cat.hasTabs and cat.tabs then
            local tab = cat.tabs[Menu.CurrentTab]
            totalRows = tab and SafeLen(tab.items) or 0
            visibleRows = math.min(Menu.ItemsPerPage, totalRows)
        end
    else
        totalRows = math.max(0, SafeLen(Menu.Categories) - 1)
        visibleRows = math.min(Menu.ItemsPerPage, totalRows)
    end

    local rowStride = p.itemHeight + p.rowSpacing
    local rowsHeight = 0
    if visibleRows > 0 then
        rowsHeight = visibleRows * p.itemHeight + math.max(0, visibleRows - 1) * p.rowSpacing
    end

    local tabBlockHeight = hasTabBar and (p.mainMenuHeight + p.mainMenuSpacing) or 0
    local contentTop = p.y + headerHeight
    local rowsTop = contentTop + tabBlockHeight
    local footerY = rowsTop + rowsHeight + p.footerSpacing
    local totalHeight = (footerY - p.y) + p.footerHeight

    local anticheatHeight = 0
    if SafeLen(Menu.AnticheatList) > 0 then
        local perColumn = math.ceil(SafeLen(Menu.AnticheatList) / 2)
        local rows = math.min(perColumn, 5)
        anticheatHeight = (35 + rows * 20) * scale
        totalHeight = totalHeight + p.anticheatSpacing + anticheatHeight
    end

    return {
        p = p,
        scale = scale,
        x = p.x,
        y = p.y,
        width = p.width,
        headerHeight = headerHeight,
        contentTop = contentTop,
        rowsTop = rowsTop,
        rowStride = rowStride,
        rowsHeight = rowsHeight,
        visibleRows = visibleRows,
        totalRows = totalRows,
        footerY = footerY,
        anticheatHeight = anticheatHeight,
        totalHeight = totalHeight
    }
end

function Menu.GetActualHeight()
    return Menu.GetLayout().totalHeight
end

-- Funciones de dibujo base
function Menu.DrawRect(x, y, w, h, r, g, b, a)
    a = (a or 1.0) * (Menu.RenderAlpha or 1.0)
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

function Menu.GetTextSize(size)
    return (tonumber(size) or 16) * _Clamp(Menu.TextScale or 1.0, 0.85, 1.35)
end

function Menu.MeasureText(text, size)
    local resolved = Menu.GetTextSize(size)
    if Susano and Susano.GetTextWidth then
        return Susano.GetTextWidth(tostring(text or ""), resolved)
    end
    return #tostring(text or "") * resolved * 0.52
end

function Menu.DrawText(x, y, text, sz, r, g, b, a)
    sz = Menu.GetTextSize(sz)
    a = (a or 1.0) * (Menu.RenderAlpha or 1.0)
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

function Menu.ExpApproach(current, target, speed)
    current = tonumber(current) or 0.0
    target = tonumber(target) or 0.0
    if Menu.ReduceMotion then return target end
    speed = tonumber(speed) or 10.0
    local dt = math.max(0.001, math.min(0.05, Menu.FrameDelta or 0.016))
    local amount = 1.0 - math.exp(-speed * dt)
    local value = current + (target - current) * amount
    if math.abs(target - value) < 0.015 then return target end
    return value
end

local function _DrawAnimatedGradient(x, y, w, h, alpha)
    local focus = Menu.GetToken("focus")
    if Menu.ReduceMotion or Menu.HighContrast then
        Menu.DrawRect(x, y, w, h, focus.r, focus.g, focus.b, focus.a * (alpha or 1.0))
        return
    end

    local steps = 8
    local stepH = h / steps
    for s = 0, steps - 1 do
        local sy = y + s * stepH
        local sh = math.min(stepH + 0.5, y + h - sy)
        local mix = 1.0 - (s / steps)
        local intensity = 0.52 + mix * 0.48
        Menu.DrawRect(
            x, sy, w, sh,
            focus.r / 255.0 * intensity,
            focus.g / 255.0 * intensity,
            focus.b / 255.0 * intensity,
            (focus.a * (alpha or 1.0))
        )
    end
end

-- Header (banner o logo)
function Menu.DrawHeader()
    local layout = Menu.GetLayout()
    local p = layout.p
    local x, y, w = p.x, p.y, p.width - 1
    local h = layout.headerHeight
    local surface = Menu.GetToken("surfaceElevated")
    local border = Menu.GetToken("border")
    local accent = Menu.GetToken("accent")
    local textPrimary = Menu.GetToken("textPrimary")

    if Menu.ShouldDrawBanner(Menu.Banner) and Menu.bannerTexture and Menu.bannerTexture > 0 and Susano.DrawImage then
        Susano.DrawImage(Menu.bannerTexture, x, y, w, h, 1, 1, 1, 0.82 * (Menu.RenderAlpha or 1.0), 0)
        Menu.DrawRect(x, y + h - 2, w, 2, border.r, border.g, border.b, border.a)
    else
        Menu.DrawRoundedRect(x, y, w, h, surface.r, surface.g, surface.b, surface.a, p.headerRadius)
        Menu.DrawRect(x, y + h - 2, w, 2, border.r, border.g, border.b, border.a)
        local logo = "PHAZE"
        local fs = 23
        local tw = Menu.MeasureText(logo, fs)
        Menu.DrawText(x + w / 2 - tw / 2, y + h / 2 - Menu.GetTextSize(fs) / 2, logo, fs,
            textPrimary.r, textPrimary.g, textPrimary.b, textPrimary.a)
        Menu.DrawRect(x + 14 * layout.scale, y + h - 9 * layout.scale, 42 * layout.scale, 1,
            accent.r, accent.g, accent.b, 170)
    end
end

-- Scrollbar delgada
function Menu.DrawScrollbar(x, startY, visibleHeight, selectedIndex, totalItems, isMainMenu, menuWidth)
    if totalItems <= Menu.ItemsPerPage or visibleHeight <= 0 then return end

    local p = Menu.GetScaledPosition()
    local width = menuWidth or p.width
    local railW = math.max(3, p.scrollbarWidth)
    local sbX = x + width - railW - p.scrollbarPadding
    local sbY = startY
    local sbH = visibleHeight
    local surface = Menu.GetToken("surfaceMuted")
    local accent = Menu.GetToken("accent")

    Menu.DrawRoundedRect(sbX, sbY, railW, sbH, surface.r, surface.g, surface.b, 190, railW / 2)

    local scrollOffset = isMainMenu and Menu.CategoryScrollOffset or Menu.ItemScrollOffset
    local totalScroll = math.max(1, totalItems - Menu.ItemsPerPage)
    local progress = math.min(1, math.max(0, scrollOffset / totalScroll))
    local thumbH = math.max(22 * (Menu.Scale or 1.0), sbH * (Menu.ItemsPerPage / totalItems))
    local targetY = sbY + progress * math.max(0, sbH - thumbH)

    local stateName = isMainMenu and "SmoothScrollCatY" or "SmoothScrollItemY"
    if type(Menu[stateName]) ~= "number" or Menu[stateName] == 0 then Menu[stateName] = targetY end
    Menu[stateName] = Menu.ExpApproach(Menu[stateName], targetY, 12.0)

    Menu.DrawRoundedRect(
        sbX, Menu[stateName], railW, thumbH,
        accent.r, accent.g, accent.b,
        Menu.HighContrast and 255 or 220,
        railW / 2
    )
end

-- Pestañas
function Menu.DrawTabs(category, x, startY, width, tabHeight)
    if not category or not category.hasTabs or not category.tabs then return end
    local numTabs = #category.tabs
    if numTabs < 1 then return end

    local tabWidth = width / numTabs
    local selectedIndex = math.max(1, math.min(numTabs, Menu.CurrentTab or 1))
    local targetX = x + (selectedIndex - 1) * tabWidth
    local targetW = selectedIndex == numTabs and (x + width - targetX) or tabWidth

    if not Menu.TabSelectorX or Menu.TabSelectorX == 0 then
        Menu.TabSelectorX = targetX
        Menu.TabSelectorWidth = targetW
    end
    Menu.TabSelectorX = Menu.ExpApproach(Menu.TabSelectorX, targetX, 11.5)
    Menu.TabSelectorWidth = Menu.ExpApproach(Menu.TabSelectorWidth, targetW, 11.5)

    local surface = Menu.GetToken("surfaceMuted")
    local accent = Menu.GetToken("accent")
    local textSecondary = Menu.GetToken("textSecondary")

    for i = 1, numTabs do
        local tabX = x + (i - 1) * tabWidth
        local currentW = i == numTabs and (x + width - tabX) or tabWidth
        Menu.DrawRect(tabX, startY, currentW, tabHeight,
            surface.r, surface.g, surface.b, Menu.HighContrast and 230 or 175)
    end

    _DrawAnimatedGradient(Menu.TabSelectorX, startY, Menu.TabSelectorWidth, tabHeight, 1.0)
    Menu.DrawRect(Menu.TabSelectorX, startY + tabHeight - 2, Menu.TabSelectorWidth, 2,
        accent.r, accent.g, accent.b, 255)

    for i, tab in ipairs(category.tabs) do
        local tabX = x + (i - 1) * tabWidth
        local currentW = i == numTabs and (x + width - tabX) or tabWidth
        local isSelected = i == selectedIndex
        local fontSize = 13
        local name = tostring(tab.name or "")
        local tw = Menu.MeasureText(name, fontSize)
        local tx = tabX + currentW / 2 - tw / 2
        local ty = startY + tabHeight / 2 - Menu.GetTextSize(fontSize) / 2
        Menu.DrawText(tx, ty, name, fontSize,
            isSelected and 255 or textSecondary.r,
            isSelected and 255 or textSecondary.g,
            isSelected and 255 or textSecondary.b,
            isSelected and 255 or 225)
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
    local surface = Menu.GetToken("surfaceMuted")
    local focus = Menu.GetToken("focus")
    local accent = Menu.GetToken("accent")
    local textPrimary = Menu.GetToken("textPrimary")
    local textSecondary = Menu.GetToken("textSecondary")
    local label = tostring(item.name or item.label or "")

    if item.isSeparator then
        Menu.DrawRoundedRect(x, itemY, width, itemHeight, surface.r, surface.g, surface.b, 125, 2 * scale)
        if item.separatorText then
            local fs = 11
            local separator = tostring(item.separatorText)
            local tw = Menu.MeasureText(separator, fs)
            local ty = itemY + itemHeight / 2 - Menu.GetTextSize(fs) / 2
            Menu.DrawText(x + width / 2 - tw / 2, ty, separator, fs,
                textSecondary.r, textSecondary.g, textSecondary.b, 210)
        end
        return
    end

    Menu.DrawRoundedRect(x, itemY, width, itemHeight,
        surface.r, surface.g, surface.b, Menu.HighContrast and 225 or 165, 2 * scale)

    if isSelected then
        local selectorKey = isCategory and "CategorySelectorY" or "SelectorY"
        local drawY = tonumber(Menu[selectorKey]) or itemY
        if drawY == 0 then drawY = itemY end
        drawY = Menu.ExpApproach(drawY, itemY, Menu.AnimationSpeed or 10.5)
        Menu[selectorKey] = drawY

        Menu.DrawRoundedRect(x, drawY, width, itemHeight,
            focus.r, focus.g, focus.b, Menu.HighContrast and 205 or 150, 2 * scale)
        Menu.DrawRect(x, drawY, 3 * scale, itemHeight, accent.r, accent.g, accent.b, 255)
        if Menu.HighContrast then
            Menu.DrawRect(x, drawY, width, 1, 255, 255, 255, 220)
            Menu.DrawRect(x, drawY + itemHeight - 1, width, 1, 255, 255, 255, 220)
        end
    end

    local fs = 15
    local textX = x + 13 * scale
    local textY = itemY + itemHeight / 2 - Menu.GetTextSize(fs) / 2
    local textAlpha = item.disabled and 120 or 255
    Menu.DrawText(textX, textY, label, fs,
        textPrimary.r, textPrimary.g, textPrimary.b, textAlpha)

    if isCategory then
        local arrow = "›"
        local arrowW = Menu.MeasureText(arrow, 17)
        Menu.DrawText(x + width - arrowW - 13 * scale, textY - 1 * scale, arrow, 17,
            textSecondary.r, textSecondary.g, textSecondary.b, 220)
        return
    end

    if item.type == "toggle" then
        if item.animProgress == nil then item.animProgress = item.value and 1 or 0 end
        item.animTarget = item.value and 1 or 0
        item.animProgress = Menu.ExpApproach(item.animProgress, item.animTarget, Menu.ToggleAnimationSpeed or 13.0)

        local toggleW = 30 * scale
        local toggleH = 15 * scale
        local toggleX = x + width - toggleW - 13 * scale
        local toggleY = itemY + itemHeight / 2 - toggleH / 2
        local offR, offG, offB = 55, 63, 78
        local r = offR + (accent.r - offR) * item.animProgress
        local g = offG + (accent.g - offG) * item.animProgress
        local b = offB + (accent.b - offB) * item.animProgress
        Menu.DrawRoundedRect(toggleX, toggleY, toggleW, toggleH, r, g, b, 245, toggleH / 2)

        local knobSize = toggleH - 4 * scale
        local knobX = toggleX + 2 * scale + (toggleW - knobSize - 4 * scale) * item.animProgress
        Menu.DrawRoundedRect(knobX, toggleY + 2 * scale, knobSize, knobSize,
            255, 255, 255, 255, knobSize / 2)

    elseif item.type == "slider" then
        local sliderW = 88 * scale
        local sliderH = math.max(3, 3 * scale)
        local sliderX = x + width - sliderW - 48 * scale
        local sliderY = itemY + itemHeight / 2 - sliderH / 2
        local minV = tonumber(item.min) or 0
        local maxV = tonumber(item.max) or 100
        local val = tonumber(item.value) or minV
        local span = math.max(0.0001, maxV - minV)
        local percent = math.min(1, math.max(0, (val - minV) / span))

        Menu.DrawRoundedRect(sliderX, sliderY, sliderW, sliderH, 65, 73, 88, 220, sliderH / 2)
        if percent > 0 then
            Menu.DrawRoundedRect(sliderX, sliderY, sliderW * percent, sliderH,
                accent.r, accent.g, accent.b, 255, sliderH / 2)
        end

        local thumbSize = 8 * scale
        Menu.DrawRoundedRect(
            sliderX + sliderW * percent - thumbSize / 2,
            sliderY + sliderH / 2 - thumbSize / 2,
            thumbSize, thumbSize, 255, 255, 255, 255, thumbSize / 2
        )
        local valText = string.format("%.0f", val)
        Menu.DrawText(sliderX + sliderW + 7 * scale,
            itemY + itemHeight / 2 - Menu.GetTextSize(10) / 2,
            valText, 10, textSecondary.r, textSecondary.g, textSecondary.b, 235)

    elseif item.type == "selector" and item.options then
        local selected = item.options[item.selected or 1] or ""
        local display = tostring(selected) .. "  ‹›"
        local tw = Menu.MeasureText(display, 12)
        Menu.DrawText(x + width - tw - 13 * scale,
            itemY + itemHeight / 2 - Menu.GetTextSize(12) / 2,
            display, 12, textSecondary.r, textSecondary.g, textSecondary.b, 245)

    elseif item.type == "toggle_selector" then
        local toggleW = 28 * scale
        local toggleH = 14 * scale
        local toggleX = x + width - toggleW - 13 * scale
        local toggleY = itemY + itemHeight / 2 - toggleH / 2
        local fill = item.value and accent or { r = 55, g = 63, b = 78 }
        Menu.DrawRoundedRect(toggleX, toggleY, toggleW, toggleH, fill.r, fill.g, fill.b, 245, toggleH / 2)

        local knobSize = toggleH - 4 * scale
        local knobX = item.value and (toggleX + toggleW - knobSize - 2 * scale) or (toggleX + 2 * scale)
        Menu.DrawRoundedRect(knobX, toggleY + 2 * scale, knobSize, knobSize,
            255, 255, 255, 255, knobSize / 2)

        if item.options then
            local selected = item.options[item.selected or 1] or ""
            local display = tostring(selected)
            local tw = Menu.MeasureText(display, 11)
            Menu.DrawText(toggleX - tw - 10 * scale,
                itemY + itemHeight / 2 - Menu.GetTextSize(11) / 2,
                display, 11, textSecondary.r, textSecondary.g, textSecondary.b, 235)
        end
    end
end

-- Panel anticheat (opcional)
function Menu.DrawAnticheatPanel()
    if SafeLen(Menu.AnticheatList) == 0 then return end

    local layout = Menu.GetLayout()
    local p = layout.p
    local scale = layout.scale
    local x = p.x
    local y = layout.footerY + p.footerHeight + p.anticheatSpacing
    local w = p.width - 1
    local h = layout.anticheatHeight

    local surface = Menu.GetToken("surfaceElevated")
    local border = Menu.GetToken("border")
    local accent = Menu.GetToken("accent")
    local textPrimary = Menu.GetToken("textPrimary")

    Menu.DrawRoundedRect(x, y, w, h, surface.r, surface.g, surface.b, surface.a, 4 * scale)
    Menu.DrawRect(x, y, w, 1, border.r, border.g, border.b, border.a)

    local title = "ANTICHEATS DETECTADOS"
    local fsTitle = 11
    local twTitle = Menu.MeasureText(title, fsTitle)
    Menu.DrawText(x + w / 2 - twTitle / 2, y + 8 * scale, title, fsTitle,
        accent.r, accent.g, accent.b, 255)

    local startListY = y + 24 * scale
    local colWidth = (w - 30 * scale) / 2
    local perCol = math.ceil(SafeLen(Menu.AnticheatList) / 2)
    for i, ac in SafeIpairs(Menu.AnticheatList) do
        local col = 0
        local row = i - 1
        if i > perCol then
            col = 1
            row = i - perCol - 1
        end
        local itemX = x + 15 * scale + col * (colWidth + 5 * scale)
        local itemY = startListY + row * 18 * scale
        Menu.DrawText(itemX, itemY, ac.name, 10,
            textPrimary.r, textPrimary.g, textPrimary.b, 255)
        Menu.DrawText(itemX + 130 * scale, itemY, "✓", 10, 100, 255, 100, 255)
    end
end

-- Menú principal y submenús
function Menu.DrawCategories()
    local layout = Menu.GetLayout()
    local p = layout.p
    local x = p.x
    local w = p.width
    local itemH = p.itemHeight
    local rowStride = layout.rowStride
    local tabH = p.mainMenuHeight
    local spacing = p.mainMenuSpacing
    local startY = layout.contentTop + (Menu.ContentSlideY or 0)

    if Menu.OpenedCategory then
        local cat = SafeTable(Menu.Categories)[Menu.OpenedCategory]
        if not cat or not cat.hasTabs or not cat.tabs then
            Menu.OpenedCategory = nil
            return
        end

        Menu.DrawTabs(cat, x, startY, w, tabH)
        local curTab = cat.tabs[Menu.CurrentTab]
        if curTab and curTab.items then
            local itemsY = startY + tabH + spacing
            local total = SafeLen(curTab.items)
            local maxVis = Menu.ItemsPerPage

            if Menu.CurrentItem > Menu.ItemScrollOffset + maxVis then
                Menu.ItemScrollOffset = Menu.CurrentItem - maxVis
            elseif Menu.CurrentItem <= Menu.ItemScrollOffset then
                Menu.ItemScrollOffset = math.max(0, Menu.CurrentItem - 1)
            end

            local visible = 0
            for i = 1, math.min(maxVis, total) do
                local idx = i + Menu.ItemScrollOffset
                if idx <= total then
                    visible = visible + 1
                    local yPos = itemsY + (i - 1) * rowStride
                    Menu.DrawItem(x, yPos, w, itemH, curTab.items[idx], idx == Menu.CurrentItem, false)
                end
            end

            local visibleHeight = visible > 0
                and (visible * itemH + math.max(0, visible - 1) * p.rowSpacing)
                or 0
            Menu.DrawScrollbar(x, itemsY, visibleHeight, Menu.CurrentItem, total, false, w)
        end
        return
    end

    if Menu.TopLevelTabs then
        local tabCount = #Menu.TopLevelTabs
        if tabCount > 0 then
            local tabW = w / tabCount
            local selectedTop = math.max(1, math.min(tabCount, Menu.CurrentTopTab or 1))
            local targetX = x + (selectedTop - 1) * tabW
            local targetW = selectedTop == tabCount and (x + w - targetX) or tabW

            if not Menu.TopTabSelectorX or Menu.TopTabSelectorX == 0 then
                Menu.TopTabSelectorX = targetX
                Menu.TopTabSelectorWidth = targetW
            end
            Menu.TopTabSelectorX = Menu.ExpApproach(Menu.TopTabSelectorX, targetX, 11.5)
            Menu.TopTabSelectorWidth = Menu.ExpApproach(Menu.TopTabSelectorWidth, targetW, 11.5)

            local surface = Menu.GetToken("surfaceMuted")
            local accent = Menu.GetToken("accent")
            local textSecondary = Menu.GetToken("textSecondary")

            for i = 1, tabCount do
                local tabX = x + (i - 1) * tabW
                local currentW = i == tabCount and (x + w - tabX) or tabW
                Menu.DrawRect(tabX, startY, currentW, tabH,
                    surface.r, surface.g, surface.b, Menu.HighContrast and 230 or 175)
            end

            _DrawAnimatedGradient(Menu.TopTabSelectorX, startY, Menu.TopTabSelectorWidth, tabH, 1.0)
            Menu.DrawRect(Menu.TopTabSelectorX, startY + tabH - 2, Menu.TopTabSelectorWidth, 2,
                accent.r, accent.g, accent.b, 255)

            for i, tab in ipairs(Menu.TopLevelTabs) do
                local tabX = x + (i - 1) * tabW
                local currentW = i == tabCount and (x + w - tabX) or tabW
                local isSelected = i == selectedTop
                local fs = 13
                local name = tostring(tab.name or "")
                local tw = Menu.MeasureText(name, fs)
                Menu.DrawText(tabX + currentW / 2 - tw / 2,
                    startY + tabH / 2 - Menu.GetTextSize(fs) / 2,
                    name, fs,
                    isSelected and 255 or textSecondary.r,
                    isSelected and 255 or textSecondary.g,
                    isSelected and 255 or textSecondary.b,
                    isSelected and 255 or 225)
            end
        end
    else
        local focus = Menu.GetToken("focus")
        local accent = Menu.GetToken("accent")
        Menu.DrawRect(x, startY, w, tabH, focus.r, focus.g, focus.b, Menu.HighContrast and 230 or 185)
        Menu.DrawRect(x, startY + tabH - 2, w, 2, accent.r, accent.g, accent.b, 255)
        local title = SafeTable(Menu.Categories)[1] and SafeTable(Menu.Categories)[1].name or "MENÚ PRINCIPAL"
        local fs = 14
        local tw = Menu.MeasureText(title, fs)
        Menu.DrawText(x + w / 2 - tw / 2,
            startY + tabH / 2 - Menu.GetTextSize(fs) / 2,
            title, fs, 255, 255, 255, 255)
    end

    startY = startY + tabH + spacing
    local totalCats = math.max(0, SafeLen(Menu.Categories) - 1)
    local maxVis = Menu.ItemsPerPage

    if Menu.CurrentCategory > Menu.CategoryScrollOffset + maxVis + 1 then
        Menu.CategoryScrollOffset = Menu.CurrentCategory - maxVis - 1
    elseif Menu.CurrentCategory <= Menu.CategoryScrollOffset + 1 then
        Menu.CategoryScrollOffset = math.max(0, Menu.CurrentCategory - 2)
    end

    local visible = 0
    for i = 1, math.min(maxVis, totalCats) do
        local idx = i + Menu.CategoryScrollOffset + 1
        if idx <= SafeLen(Menu.Categories) then
            visible = visible + 1
            local cat = SafeTable(Menu.Categories)[idx]
            local yPos = startY + (i - 1) * rowStride
            Menu.DrawItem(x, yPos, w, itemH, { name = cat.name, id = cat.id }, idx == Menu.CurrentCategory, true)
        end
    end

    local visibleHeight = visible > 0
        and (visible * itemH + math.max(0, visible - 1) * p.rowSpacing)
        or 0
    Menu.DrawScrollbar(x, startY, visibleHeight, Menu.CurrentCategory, totalCats, true, w)
end

function Menu.GetFooterContext()
    if Menu.EditorMode then
        return "Arrastra para mover · Desactiva Editor"
    end

    if Menu.OpenedCategory then
        local item = Menu.GetCurrentSelectedItem and select(1, Menu.GetCurrentSelectedItem()) or nil
        if item then
            if item.type == "slider" then return "←/→ Ajustar · ↑/↓ Navegar" end
            if item.type == "selector" or item.type == "toggle_selector" then
                return "←/→ Cambiar · Enter Aplicar"
            end
            if item.type == "toggle" then return "Enter Cambiar · F9 Atajo · Atrás" end
            if item.type == "action" then return "Enter Ejecutar · F9 Atajo · Atrás" end
        end
        return "↑/↓ Navegar · Q/E Pestañas · Atrás"
    end

    return "↑/↓ Categoría · ←/→ Sección · Enter"
end

function Menu.DrawFooter()
    local layout = Menu.GetLayout()
    local p = layout.p
    local x = p.x
    local footerY = layout.footerY
    local w = p.width - 1
    local h = p.footerHeight
    local surface = Menu.GetToken("surfaceElevated")
    local border = Menu.GetToken("border")
    local textSecondary = Menu.GetToken("textSecondary")
    local textPrimary = Menu.GetToken("textPrimary")

    Menu.DrawRoundedRect(x, footerY, w, h, surface.r, surface.g, surface.b, surface.a, p.footerRadius)
    Menu.DrawRect(x, footerY, w, 1, border.r, border.g, border.b, border.a)

    local page = ""
    if Menu.OpenedCategory then
        local cat = SafeTable(Menu.Categories)[Menu.OpenedCategory]
        local tab = cat and cat.tabs and cat.tabs[Menu.CurrentTab] or nil
        if tab and tab.items then page = string.format("%d/%d", Menu.CurrentItem, SafeLen(tab.items)) end
    else
        page = string.format("%d/%d", math.max(0, Menu.CurrentCategory - 1), math.max(0, SafeLen(Menu.Categories) - 1))
    end

    local fs = 9
    local pageW = Menu.MeasureText(page, fs)
    local hint = Menu.GetFooterContext()
    local available = w - pageW - 32 * layout.scale
    if Menu.MeasureText(hint, fs) > available then
        hint = Menu.OpenedCategory and "Navegar · Enter · Atrás" or "Navegar · Enter"
    end

    local textY = footerY + h / 2 - Menu.GetTextSize(fs) / 2
    Menu.DrawText(x + 10 * layout.scale, textY, hint, fs,
        textSecondary.r, textSecondary.g, textSecondary.b, textSecondary.a)
    Menu.DrawText(x + w - pageW - 10 * layout.scale, textY, page, fs,
        textPrimary.r, textPrimary.g, textPrimary.b, textPrimary.a)
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
    local tw = Menu.MeasureText(percent, fs)
    Menu.DrawText(x+w/2-tw/2, y-20, percent, fs, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 255*alpha)
    local status = "INICIANDO"
    if Menu.LoadingProgress >= 100 then status = "LISTO" end
    local stw = Menu.MeasureText(status, 13)
    Menu.DrawText(x+w/2-stw/2, y-38, status, 13, Menu.Colors.Accent.r/255.0, Menu.Colors.Accent.g/255.0, Menu.Colors.Accent.b/255.0, 255*alpha)
end

-- Selector de tecla (para abrir menú y para keybinds) CON BANNER Y VISUALIZACIÓN EN VIVO
function Menu.DrawKeySelector(alpha)
    if alpha <= 0 then return end

    local sw, sh = 1920, 1080
    if Susano.GetScreenWidth then sw = Susano.GetScreenWidth() or sw end
    if Susano.GetScreenHeight then sh = Susano.GetScreenHeight() or sh end

    local useBanner = Menu.ShouldDrawBanner(Menu.KeySelectorBanner)
        and Menu.keySelectorBannerTexture and Menu.keySelectorBannerTexture > 0
        and Susano.DrawImage

    local w = 480
    local h = useBanner and 218 or 168
    local x = sw / 2 - w / 2
    local y = sh / 2 - h / 2
    local accent = Menu.GetToken("accent")
    local surface = Menu.GetToken("surfaceElevated")
    local textPrimary = Menu.GetToken("textPrimary")
    local textSecondary = Menu.GetToken("textSecondary")

    if Menu.ShowIntenseGlows then
        Menu.DrawRoundedRect(x - 5, y - 5, w + 10, h + 10,
            accent.r, accent.g, accent.b, 24 * alpha, 10)
    end
    Menu.DrawRoundedRect(x, y, w, h, surface.r, surface.g, surface.b, surface.a * alpha, 8)
    Menu.DrawRect(x, y, w, 2, accent.r, accent.g, accent.b, 235 * alpha)

    local contentTop = y + 18
    if useBanner then
        local bannerH = 70
        Susano.DrawImage(Menu.keySelectorBannerTexture, x + 8, y + 8, w - 16, bannerH,
            1, 1, 1, 0.72 * alpha * (Menu.RenderAlpha or 1.0), 0)
        Menu.DrawRect(x + 8, y + 8 + bannerH - 1, w - 16, 1,
            accent.r, accent.g, accent.b, 150 * alpha)
        contentTop = y + bannerH + 20
    else
        local title = "ASIGNAR TECLA DEL MENÚ"
        local titleSize = 14
        local titleW = Menu.MeasureText(title, titleSize)
        Menu.DrawText(x + w / 2 - titleW / 2, y + 18, title, titleSize,
            accent.r, accent.g, accent.b, 255 * alpha)
        contentTop = y + 50
    end

    if Menu.ShowParticles then
        Menu.DrawPanelSnow(Menu.KeySelectorParticles, x + 8, y + 8, w - 16, h - 16, alpha * 0.40, 0.72)
    end

    local confirmed = Menu.KeySelectionConfirmedAt ~= nil
    local instruction = confirmed and "Tecla guardada" or "Pulsa la tecla que quieras usar"
    local instructionW = Menu.MeasureText(instruction, 12)
    Menu.DrawText(x + w / 2 - instructionW / 2, contentTop, instruction, 12,
        confirmed and Menu.GetToken("success").r or textSecondary.r,
        confirmed and Menu.GetToken("success").g or textSecondary.g,
        confirmed and Menu.GetToken("success").b or textSecondary.b,
        245 * alpha)

    local displayKey = Menu.TempKeyPressed or Menu.SelectedKeyName or "..."
    if displayKey == "SIN ASIGNAR" then displayKey = "..." end

    local boxW, boxH = 190, 44
    local boxX = x + w / 2 - boxW / 2
    local boxY = contentTop + 29
    Menu.DrawRoundedRect(boxX, boxY, boxW, boxH, 12, 17, 26, 245 * alpha, 6)
    Menu.DrawRect(boxX + 14, boxY + boxH - 3, boxW - 28, 2,
        accent.r, accent.g, accent.b, 220 * alpha)

    local keySize = 19
    local keyW = Menu.MeasureText(displayKey, keySize)
    Menu.DrawText(boxX + boxW / 2 - keyW / 2,
        boxY + boxH / 2 - Menu.GetTextSize(keySize) / 2,
        displayKey, keySize, textPrimary.r, textPrimary.g, textPrimary.b, 255 * alpha)

    local footer = confirmed and "Se cerrará automáticamente" or "ESC cancela los cambios manuales"
    local footerW = Menu.MeasureText(footer, 10)
    Menu.DrawText(x + w / 2 - footerW / 2, y + h - 22, footer, 10,
        textSecondary.r, textSecondary.g, textSecondary.b, 210 * alpha)
end

-- Panel de teclas rápidas (lateral)
function Menu.DrawKeybindsInterface(alpha)
    if alpha <= 0 then return end
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
    for i, bind in ipairs(binds) do
        local lineY = y + 32 + (i-1)*22
        local text = bind.name .. "  [" .. bind.key .. "]"
        if bind.active ~= nil then
            text = text .. (bind.active and "  ✓" or "  ✗")
        end
        Menu.DrawText(x+15, lineY, text, 11, Menu.Colors.Text.r/255.0, Menu.Colors.Text.g/255.0, Menu.Colors.Text.b/255.0, 200*alpha)
    end
end

-- Partículas opcionales. Las velocidades están expresadas por segundo.
Menu.Particles = {}
for i = 1, 70 do
    table.insert(Menu.Particles, {
        x = math.random(0, 1000) / 1000,
        y = math.random(0, 1000) / 1000,
        speedY = math.random(12, 60) / 100,
        speedX = math.random(-12, 12) / 100,
        size = math.random(1, 2)
    })
end

function Menu.DrawBackground()
    local layout = Menu.GetLayout()
    local p = layout.p
    local x, y = p.x, p.y
    local w = p.width - 1
    local actualHeight = layout.totalHeight
    local surface = Menu.GetToken("surface")

    Menu.DrawRoundedRect(x, y, w, actualHeight,
        surface.r, surface.g, surface.b, surface.a, p.headerRadius)

    if Menu.ShowParticles then
        local dt = math.max(0.001, math.min(0.05, Menu.FrameDelta or 0.016))
        for _, part in ipairs(Menu.Particles) do
            part.y = part.y + (part.speedY or 0.25) * dt
            part.x = part.x + (part.speedX or 0.0) * dt
            if part.y > 1 then
                part.y = 0
                part.x = math.random(0, 1000) / 1000
            end
            if part.x < 0 then part.x = 1 elseif part.x > 1 then part.x = 0 end

            local px = x + part.x * w
            local py = y + part.y * actualHeight
            if Menu.ShowIntenseGlows and part.size >= 2 then
                local accent = Menu.GetToken("accent")
                Menu.DrawRect(px - 1, py - 1, part.size + 2, part.size + 2,
                    accent.r, accent.g, accent.b, 18)
            end
            Menu.DrawRect(px, py, part.size, part.size, 225, 238, 255, 90)
        end
    end
end

-- ========== MANEJO DE ENTRADA ==========
Menu.KeyStates = {}

local function _AsPressed(value)
    return value == true or value == 1 or (type(value) == "number" and value ~= 0)
end

function Menu.IsKeyDown(keyCode)
    if not Susano or not Susano.GetAsyncKeyState then return false end
    local ok, down = pcall(Susano.GetAsyncKeyState, keyCode)
    return ok and _AsPressed(down) or false
end

function Menu.IsKeyJustPressed(keyCode)
    if not Susano or not Susano.GetAsyncKeyState then return false end

    local ok, down, pressed = pcall(Susano.GetAsyncKeyState, keyCode)
    if not ok then return false end

    local isDown = _AsPressed(down)
    local isPressed = _AsPressed(pressed)
    local wasDown = Menu.KeyStates[keyCode] or false
    Menu.KeyStates[keyCode] = isDown

    return isPressed or (isDown and not wasDown)
end

function Menu.IsKeyPressedOrRepeated(keyCode)
    local now = GetGameTimer and GetGameTimer() or math.floor(os.clock() * 1000)
    local isDown = Menu.IsKeyDown(keyCode)
    local state = Menu.KeyRepeatStates[keyCode]

    if not isDown then
        Menu.KeyRepeatStates[keyCode] = nil
        return false
    end

    if not state then
        Menu.KeyRepeatStates[keyCode] = {
            nextAt = now + (Menu.KeyRepeatDelay or 320)
        }
        return true
    end

    if now >= (state.nextAt or now) then
        state.nextAt = now + (Menu.KeyRepeatInterval or 85)
        return true
    end
    return false
end
local captureKeys = {
    0x08,0x09,0x10,0x11,0x12,0x14,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x2D,0x2E,
    0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,
    0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,
    0x4E,0x4F,0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,
    0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x7B,
    0x90,0x91,0xA0,0xA1,0xA2,0xA3,0xA4,0xA5
}

Menu.KeyNames = {
    [0x08]="Retroceso", [0x09]="Tabulador", [0x0D]="Intro", [0x10]="Mayús",
    [0x11]="Ctrl", [0x12]="Alt", [0x13]="Pausa", [0x14]="Bloq Mayús",
    [0x1B]="ESC", [0x20]="Espacio", [0x21]="PG UP", [0x22]="PG DN",
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

-- Respaldo para builds donde Susano no detecta correctamente alguna tecla.
-- Clave: control FiveM. Valor: Virtual-Key de Windows usado por Susano.
Menu.FiveMControlToVK = {
    [38]=0x45, [23]=0x46, [47]=0x47, [73]=0x58, [29]=0x42,
    [0]=0x56, [74]=0x48, [246]=0x59, [303]=0x55, [311]=0x4B,
    [249]=0x4E, [44]=0x51, [245]=0x54, [45]=0x52, [20]=0x5A,
    [22]=0x20, [21]=0x10, [36]=0x11, [19]=0x12,
    [37]=0x09, [137]=0x14, [18]=0x0D, [194]=0x08,
    [178]=0x2E, [121]=0x2D, [213]=0x24, [214]=0x23,
    [10]=0x21, [11]=0x22,
    [174]=0x25, [175]=0x27, [172]=0x26, [173]=0x28,
    [288]=0x70, [289]=0x71, [170]=0x72, [166]=0x73,
    [167]=0x74, [168]=0x75, [169]=0x76, [56]=0x77,
    [57]=0x78, [58]=0x79
}
Menu.VKToFiveMControl = {}
for control, vk in pairs(Menu.FiveMControlToVK) do
    if Menu.VKToFiveMControl[vk] == nil then Menu.VKToFiveMControl[vk] = control end
end

function Menu.GetKeyName(k)
    return Menu.KeyNames[k] or ("0x" .. string.format("%02X", tonumber(k) or 0))
end

local function _ControlJustPressed(control)
    if control == nil then return false end
    if type(IsDisabledControlJustPressed) == "function" then
        local ok, value = pcall(IsDisabledControlJustPressed, 0, control)
        if ok and value == true then return true end
    end
    if type(IsControlJustPressed) == "function" then
        local ok, value = pcall(IsControlJustPressed, 0, control)
        if ok and value == true then return true end
    end
    return false
end

function Menu.DetectPressedMenuKey()
    for _, vk in ipairs(captureKeys) do
        if Menu.IsKeyJustPressed(vk) then
            return vk, Menu.VKToFiveMControl[vk]
        end
    end

    for control, vk in pairs(Menu.FiveMControlToVK) do
        if _ControlJustPressed(control) then return vk, control end
    end

    return nil, nil
end

function Menu.BeginMenuKeySelection(initialSetup)
    Menu.PreviousSelectedKey = Menu.SelectedKey
    Menu.PreviousSelectedControl = Menu.SelectedControl
    Menu.InitialKeySetupActive = initialSetup == true
    Menu.SelectingKey = true
    Menu.KeySelectionConfirmedAt = nil
    Menu.KeySelectionFeedback = nil
    Menu.TempKeyPressed = nil
    Menu.KeyStates = {}
    Menu.KeyCaptureReadyAt = (GetGameTimer and GetGameTimer() or 0) + 500

    if Menu.InitialKeySetupActive then
        Menu.SelectedKey = nil
        Menu.SelectedControl = nil
        Menu.MenuToggleKey = nil
        Menu.SelectedKeyName = "SIN ASIGNAR"
        Menu.Visible = false
    end
end

function Menu.CommitMenuToggleKey(vk, control)
    if not vk then return end
    Menu.SelectedKey = vk
    Menu.MenuToggleKey = vk
    Menu.SelectedControl = control
    if Menu.SelectedControl == nil then Menu.SelectedControl = Menu.VKToFiveMControl[vk] end
    Menu.SelectedKeyName = Menu.GetKeyName(vk)
    Menu.TempKeyPressed = Menu.SelectedKeyName
    Menu.KeySelectionFeedback = "TECLA ASIGNADA"
    Menu.KeySelectionConfirmedAt = GetGameTimer and GetGameTimer() or 0
end

function Menu.GetMenuToggleKey()
    return Menu.MenuToggleKey or Menu.SelectedKey
end

function Menu.IsMenuToggleJustPressed()
    if Menu.SelectingKey or Menu.InitialKeySetupActive then return false end
    local key = Menu.GetMenuToggleKey()
    if not key then return false end

    local pressed = Menu.IsKeyJustPressed(key)
    local control = Menu.SelectedControl
    if control == nil then control = Menu.VKToFiveMControl[key] end
    if _ControlJustPressed(control) then pressed = true end
    return pressed
end

function Menu.NormalizeIdentifier(value)
    local id = string.lower(tostring(value or ""))
    id = id:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u")
    id = id:gsub("ñ", "n")
    id = id:gsub("[^%w]+", "_")
    id = id:gsub("^_+", ""):gsub("_+$", "")
    return id
end

Menu.LegacyItemIds = {
    ["modo_editor"] = Menu.Ids.EditorMode,
    ["mostrar_teclas_rapidas"] = Menu.Ids.ShowKeybinds,
    ["copos_de_nieve"] = Menu.Ids.Particles,
    ["particulas"] = Menu.Ids.Particles,
    ["menu_suave"] = Menu.Ids.AnimationSmoothness,
    ["reducir_animaciones"] = Menu.Ids.ReduceMotion,
    ["tamano_del_menu"] = Menu.Ids.MenuScale,
    ["escala_de_texto"] = Menu.Ids.TextScale,
    ["opacidad_del_fondo"] = Menu.Ids.BackgroundOpacity,
    ["contraste_alto"] = Menu.Ids.HighContrast,
    ["mostrar_banners"] = Menu.Ids.Banners,
    ["glows_intensos"] = Menu.Ids.IntenseGlows,
    ["tema_del_menu"] = Menu.Ids.Theme,
    ["color_del_menu"] = Menu.Ids.Accent,
    ["cambiar_tecla_de_menu"] = Menu.Ids.ChangeMenuKey
}

function Menu.GetItemId(item)
    if type(item) ~= "table" then return nil end
    if item.id and item.id ~= "" then return tostring(item.id) end
    local normalized = Menu.NormalizeIdentifier(item.name or item.label or item.text)
    item.id = Menu.LegacyItemIds[normalized] or ("item_" .. (normalized ~= "" and normalized or "unnamed"))
    return item.id
end

function Menu.EnsureStableIds(categories, prefix)
    prefix = prefix or "menu"
    for categoryIndex, cat in SafeIpairs(categories) do
        cat.id = cat.id or (prefix .. "_category_" .. Menu.NormalizeIdentifier(cat.name or categoryIndex))
        if cat.tabs then
            for tabIndex, tab in SafeIpairs(cat.tabs) do
                tab.id = tab.id or (cat.id .. "_tab_" .. Menu.NormalizeIdentifier(tab.name or tabIndex))
                for itemIndex, item in SafeIpairs(tab.items) do
                    local legacyId = Menu.GetItemId(item)
                    if not Menu.LegacyItemIds[Menu.NormalizeIdentifier(item.name or item.label or item.text)]
                        and legacyId == "item_" .. Menu.NormalizeIdentifier(item.name or item.label or item.text) then
                        item.id = tab.id .. "_" .. legacyId .. "_" .. tostring(itemIndex)
                    end
                end
            end
        end
    end
end

function Menu.ApplyBuiltInItemState(item)
    local id = Menu.GetItemId(item)
    if id == Menu.Ids.EditorMode then
        Menu.EditorMode = item.value == true
    elseif id == Menu.Ids.ShowKeybinds then
        Menu.ShowKeybinds = item.value == true
    elseif id == Menu.Ids.Particles then
        Menu.SetParticlesEnabled(item.value == true)
    elseif id == Menu.Ids.ReduceMotion then
        Menu.ReduceMotion = item.value == true
    elseif id == Menu.Ids.AnimationSmoothness then
        Menu.SmoothFactor = _Clamp((tonumber(item.value) or 10) / 100, 0.0, 1.0)
    elseif id == Menu.Ids.MenuScale then
        Menu.Scale = _Clamp((tonumber(item.value) or 100) / 100, 0.70, 1.50)
    elseif id == Menu.Ids.TextScale then
        Menu.SetTextScale(item.value)
    elseif id == Menu.Ids.BackgroundOpacity then
        Menu.SetBackgroundOpacity(item.value)
    elseif id == Menu.Ids.HighContrast then
        Menu.SetHighContrast(item.value == true)
    elseif id == Menu.Ids.Banners then
        Menu.SetBannersEnabled(item.value == true)
    elseif id == Menu.Ids.IntenseGlows then
        Menu.ShowIntenseGlows = item.value == true
    end
end

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
        for _,k in ipairs(captureKeys) do
            if k ~= 0x0D and Menu.IsKeyJustPressed(k) then
                Menu.BindingKey = k
                Menu.BindingKeyName = Menu.GetKeyName(k)
                Menu.TempPressedKey = Menu.BindingKeyName
                break
            end
        end
        return
    end

    -- Selección dinámica de la tecla para abrir el menú.
    if Menu.SelectingKey then
        local now = GetGameTimer and GetGameTimer() or 0

        if Menu.KeySelectionConfirmedAt then
            if now - Menu.KeySelectionConfirmedAt >= 900 then
                Menu.SelectingKey = false
                Menu.InitialKeySetupActive = false
                Menu.TempKeyPressed = nil
                Menu.KeySelectionConfirmedAt = nil
                Menu.KeySelectionFeedback = nil
                Menu.LoadedNoticeMessage = "SENTEXMODZ cargado, presiona " .. tostring(Menu.SelectedKeyName or "tu tecla") .. " para abrir"
                Menu.LoadedNoticeStartTime = now
                Menu.LoadedNoticeActive = true
            end
            return
        end

        if now < (Menu.KeyCaptureReadyAt or 0) then return end

        -- ESC cancela solo un cambio manual; en la selección inicial es obligatorio elegir.
        if not Menu.InitialKeySetupActive and Menu.IsKeyJustPressed(0x1B) then
            Menu.SelectedKey = Menu.PreviousSelectedKey
            Menu.MenuToggleKey = Menu.PreviousSelectedKey
            Menu.SelectedControl = Menu.PreviousSelectedControl
            Menu.SelectedKeyName = Menu.GetKeyName(Menu.SelectedKey)
            Menu.SelectingKey = false
            Menu.TempKeyPressed = nil
            return
        end

        local vk, control = Menu.DetectPressedMenuKey()
        if vk and vk ~= 0x1B and vk ~= 0x0D then
            Menu.CommitMenuToggleKey(vk, control)
        end
        return
    end

    -- Ejecutar keybinds
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
                                    Menu.ApplyBuiltInItemState(it)
                                    if it.onClick then SafeInvoke(it.onClick, it.value) end
                                elseif it.type=="action" then
                                    if it.onClick then SafeInvoke(it.onClick) end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Tecla para mostrar/ocultar menú: PG DN / Page Down.
    if Menu.IsMenuToggleJustPressed() then
        Menu.Visible = not Menu.Visible
        Menu.KeyRepeatStates = {}
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
        local editorLayout = Menu.GetLayout()
        local menuW = editorLayout.width
        local totalH = editorLayout.totalHeight
        if lmb and not Menu.EditorDragging then
            if mx >= editorLayout.x and mx <= editorLayout.x + menuW
                and my >= editorLayout.y and my <= editorLayout.y + totalH then
                Menu.EditorDragging = true
                Menu.EditorDragOffsetX = mx - editorLayout.x
                Menu.EditorDragOffsetY = my - editorLayout.y
            end
        elseif not lmb then
            Menu.EditorDragging = false
        end
        if Menu.EditorDragging then
            local newX = mx - Menu.EditorDragOffsetX
            local newY = my - Menu.EditorDragOffsetY
            newX = math.max(0, math.min(sw - menuW, newX))
            newY = math.max(0, math.min(sh - totalH, newY))
            Menu.Position.x = newX
            Menu.Position.y = newY
        end
        return
    end

    -- Navegación normal
    if Menu.OpenedCategory then
        local cat = SafeTable(Menu.Categories)[Menu.OpenedCategory]
        if not cat or not cat.hasTabs or not cat.tabs then
            Menu.OpenedCategory = nil
            return
        end
        local curTab = cat.tabs[Menu.CurrentTab]
        if curTab and curTab.items then
            -- Movimiento vertical
            if Menu.IsKeyPressedOrRepeated(0x26) then  -- Up
                Menu.CurrentItem = findNextNonSeparator(curTab.items, Menu.CurrentItem, -1)
            elseif Menu.IsKeyPressedOrRepeated(0x28) then  -- Down
                Menu.CurrentItem = findNextNonSeparator(curTab.items, Menu.CurrentItem, 1)
            -- Sliders y selectores (← y →)
            elseif Menu.IsKeyPressedOrRepeated(0x25) then  -- Left
                local item = curTab.items[Menu.CurrentItem]
                if item then
                    if item.type == "slider" then
                        local step = item.step or 1
                        item.value = math.max(item.min or 0, (item.value or 0) - step)
                        Menu.ApplyBuiltInItemState(item)
                        if item.onClick then SafeInvoke(item.onClick, item.value) end
                    elseif item.type == "selector" then
                        local idx = (item.selected or 1) - 1
                        if idx < 1 then idx = SafeLen(item.options) end
                        item.selected = idx
                        if Menu.GetItemId(item) == Menu.Ids.Theme then Menu.ApplyTheme(item.options[idx]) end
                        if item.onClick then SafeInvoke(item.onClick, item.selected, item.options[item.selected]) end
                    elseif item.type == "toggle_selector" then
                        local idx = (item.selected or 1) - 1
                        if idx < 1 then idx = SafeLen(item.options) end
                        item.selected = idx
                    elseif item.type == "toggle" and item.hasSlider then
                        item.sliderValue = math.max(item.sliderMin or 0, (item.sliderValue or 0) - (item.sliderStep or 0.1))
                    end
                end
            elseif Menu.IsKeyPressedOrRepeated(0x27) then  -- Right
                local item = curTab.items[Menu.CurrentItem]
                if item then
                    if item.type == "slider" then
                        local step = item.step or 1
                        item.value = math.min(item.max or 100, (item.value or 0) + step)
                        Menu.ApplyBuiltInItemState(item)
                        if item.onClick then SafeInvoke(item.onClick, item.value) end
                    elseif item.type == "selector" then
                        local idx = (item.selected or 1) + 1
                        if idx > SafeLen(item.options) then idx = 1 end
                        item.selected = idx
                        if Menu.GetItemId(item) == Menu.Ids.Theme then Menu.ApplyTheme(item.options[idx]) end
                        if item.onClick then SafeInvoke(item.onClick, item.selected, item.options[item.selected]) end
                    elseif item.type == "toggle_selector" then
                        local idx = (item.selected or 1) + 1
                        if idx > SafeLen(item.options) then idx = 1 end
                        item.selected = idx
                    elseif item.type == "toggle" and item.hasSlider then
                        item.sliderValue = math.min(item.sliderMax or 100, (item.sliderValue or 0) + (item.sliderStep or 0.1))
                    end
                end
            -- Navegación horizontal con Q y E (cambio de pestaña)
            elseif Menu.IsKeyPressedOrRepeated(0x51) then  -- Q
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
            elseif Menu.IsKeyPressedOrRepeated(0x45) then  -- E
                if Menu.CurrentTab < SafeLen(cat.tabs) then
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
                        Menu.ApplyBuiltInItemState(item)
                        if item.onClick then SafeInvoke(item.onClick, item.value) end
                    elseif item.type == "action" then
                        if Menu.GetItemId(item) == Menu.Ids.ChangeMenuKey then
                            Menu.BeginMenuKeySelection(false)
                        end
                        if item.onClick then SafeInvoke(item.onClick) end
                    elseif item.type == "selector" then
                        if item.onClick then SafeInvoke(item.onClick, item.selected, item.options[item.selected]) end
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
        if Menu.IsKeyPressedOrRepeated(0x26) then  -- Up
            Menu.CurrentCategory = Menu.CurrentCategory - 1
            if Menu.CurrentCategory < 2 then Menu.CurrentCategory = SafeLen(Menu.Categories) end
        elseif Menu.IsKeyPressedOrRepeated(0x28) then  -- Down
            Menu.CurrentCategory = Menu.CurrentCategory + 1
            if Menu.CurrentCategory > SafeLen(Menu.Categories) then Menu.CurrentCategory = 2 end
        elseif Menu.IsKeyPressedOrRepeated(0x25) or Menu.IsKeyPressedOrRepeated(0x41) then  -- Left / A (cambiar top tab)
            if Menu.TopLevelTabs then
                Menu.CurrentTopTab = Menu.CurrentTopTab - 1
                if Menu.CurrentTopTab < 1 then Menu.CurrentTopTab = #Menu.TopLevelTabs end
                Menu.UpdateCategoriesFromTopTab()
            end
        elseif Menu.IsKeyPressedOrRepeated(0x27) or Menu.IsKeyPressedOrRepeated(0x45) then  -- Right / E
            if Menu.TopLevelTabs then
                Menu.CurrentTopTab = Menu.CurrentTopTab + 1
                if Menu.CurrentTopTab > #Menu.TopLevelTabs then Menu.CurrentTopTab = 1 end
                Menu.UpdateCategoriesFromTopTab()
            end
        elseif Menu.IsKeyJustPressed(0x0D) then  -- Enter
            local cat = SafeTable(Menu.Categories)[Menu.CurrentCategory]
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
    Menu.EnsureStableIds(Menu.Categories, "top_" .. tostring(Menu.CurrentTopTab or 1))
    if Menu.EnsureVisualSettings then Menu.EnsureVisualSettings() end
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
    height = 72
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

Menu.BacaneriasInfoBanner = {
    enabled = true,
    imageUrl = "https://i.imgur.com/WWNiCPK.png",
    height = 58
}
Menu.bacaneriasInfoBannerTexture = nil
Menu.bacaneriasInfoBannerWidth = 0
Menu.bacaneriasInfoBannerHeight = 0

Menu.KeySelectorBanner = {
    enabled = true,
    imageUrl = "https://i.imgur.com/feEx8tj.jpeg",
    height = 126
}
Menu.keySelectorBannerTexture = nil
Menu.keySelectorBannerWidth = 0
Menu.keySelectorBannerHeight = 0

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


function Menu.LoadBacaneriasInfoBannerTexture(url)
    if not url or url == "" then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end
    CreateThread(function()
        local status, body = Susano.HttpGet(url)
        if status == 200 and body and #body > 0 then
            local tex, w, h = Susano.LoadTextureFromBuffer(body)
            if tex and tex ~= 0 then
                Menu.bacaneriasInfoBannerTexture = tex
                Menu.bacaneriasInfoBannerWidth = w
                Menu.bacaneriasInfoBannerHeight = h
            end
        end
    end)
end

function Menu.LoadKeySelectorBannerTexture(url)
    if not url or url == "" then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end
    CreateThread(function()
        local status, body = Susano.HttpGet(url)
        if status == 200 and body and #body > 0 then
            local tex, w, h = Susano.LoadTextureFromBuffer(body)
            if tex and tex ~= 0 then
                Menu.keySelectorBannerTexture = tex
                Menu.keySelectorBannerWidth = w
                Menu.keySelectorBannerHeight = h
            end
        end
    end)
end


function Menu.GetCurrentSelectedItem()
    if not Menu.Categories then return nil, nil, nil end
    if Menu.OpenedCategory then
        local cat = SafeTable(Menu.Categories)[Menu.OpenedCategory]
        if cat and cat.hasTabs and cat.tabs then
            local tab = cat.tabs[Menu.CurrentTab]
            if tab and tab.items then
                return tab.items[Menu.CurrentItem], cat, tab
            end
        end
    else
        local cat = SafeTable(Menu.Categories)[Menu.CurrentCategory]
        return cat, cat, nil
    end
    return nil, nil, nil
end

function Menu.IsOnlineCategory(cat, tab)
    local categoryId = cat and (cat.id or Menu.NormalizeIdentifier(cat.name)) or ""
    local tabId = tab and (tab.id or Menu.NormalizeIdentifier(tab.name)) or ""
    return categoryId:find("en_linea", 1, true)
        or categoryId:find("online", 1, true)
        or tabId:find("en_linea", 1, true)
        or tabId:find("online", 1, true)
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

    for _,v in ipairs(candidates) do
        local n = tonumber(v)
        if n then
            for _,pid in ipairs(GetActivePlayers and GetActivePlayers() or {}) do
                if GetPlayerServerId(pid) == n or pid == n then
                    return pid, GetPlayerServerId(pid)
                end
            end
        end
    end

    local targetName = string.lower(_cleanPlayerMenuName(item.name or item.label or item.text or ""))
    if targetName ~= "" and GetActivePlayers then
        for _,pid in ipairs(GetActivePlayers()) do
            local pname = GetPlayerName(pid) or ""
            if string.lower(pname) == targetName or string.lower(_cleanPlayerMenuName(pname)) == targetName then
                return pid, GetPlayerServerId(pid)
            end
        end
        for _,pid in ipairs(GetActivePlayers()) do
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
        Menu.PlayerInfoAlpha = Menu.ExpApproach(Menu.PlayerInfoAlpha or 0, 0.0, 12.0)
        return
    end

    local pid, sid = Menu.ResolvePlayerFromItem(item)
    if not pid then
        Menu.PlayerInfo = nil
        Menu.PlayerInfoAlpha = Menu.ExpApproach(Menu.PlayerInfoAlpha or 0, 0.0, 12.0)
        return
    end

    local ped = GetPlayerPed(pid)
    if not ped or ped == 0 or (DoesEntityExist and not DoesEntityExist(ped)) then
        Menu.PlayerInfo = nil
        Menu.PlayerInfoAlpha = Menu.ExpApproach(Menu.PlayerInfoAlpha or 0, 0.0, 12.0)
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
    Menu.PlayerInfoAlpha = Menu.ExpApproach(Menu.PlayerInfoAlpha or 0, 1.0, 9.0)
end

function Menu.IsBacaneriasCategory(cat, tab)
    local categoryId = cat and (cat.id or Menu.NormalizeIdentifier(cat.name)) or ""
    local tabId = tab and (tab.id or Menu.NormalizeIdentifier(tab.name)) or ""
    return categoryId:find("spawn_bacanerias", 1, true) ~= nil
        or categoryId:find("bacanerias", 1, true) ~= nil
        or tabId:find("bacanerias", 1, true) ~= nil
end

local function _NormalizeBacaneriaName(value)
    local s = string.lower(tostring(value or ""))
    s = s:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u"):gsub("ñ", "n")
    s = s:gsub("[^%w%s]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function _FindBacaneriaDefinition(item)
    local B = rawget(_G, "SentexBacanerias")
    if type(B) ~= "table" or type(item) ~= "table" then return nil, nil, nil end

    local explicitKey = item.propKey or item.bacaneriaKey or item.presetKey
    if explicitKey and type(B.PropDefs) == "table" and B.PropDefs[explicitKey] then
        return "PROP", explicitKey, B.PropDefs[explicitKey]
    end
    if explicitKey and type(B.Presets) == "table" and B.Presets[explicitKey] then
        return "PRESET", explicitKey, B.Presets[explicitKey]
    end

    local wanted = _NormalizeBacaneriaName(item.name or item.label or item.text)
    if wanted == "" then return nil, nil, nil end

    if type(B.PropDefs) == "table" then
        for key, def in pairs(B.PropDefs) do
            if type(def) == "table" and (_NormalizeBacaneriaName(def.label) == wanted or _NormalizeBacaneriaName(key) == wanted) then
                return "PROP", key, def
            end
        end
    end
    if type(B.Presets) == "table" then
        for key, preset in pairs(B.Presets) do
            if type(preset) == "table" and (_NormalizeBacaneriaName(preset.label) == wanted or _NormalizeBacaneriaName(key) == wanted) then
                return "PRESET", key, preset
            end
        end
    end
    return nil, nil, nil
end

function Menu.UpdateHoveredBacaneriasInfo()
    local item, cat, tab = Menu.GetCurrentSelectedItem()
    if not Menu.Visible or not Menu.IsBacaneriasCategory(cat, tab) or not item or item.isSeparator then
        Menu.BacaneriasInfo = nil
        Menu.BacaneriasInfoAlpha = Menu.ExpApproach(Menu.BacaneriasInfoAlpha or 0, 0.0, 12.0)
        return
    end

    local kind, key, def = _FindBacaneriaDefinition(item)
    local B = rawget(_G, "SentexBacanerias") or {}
    local custom = item.bacaneriaInfo or item.info or item.description
    local info = {
        title = tostring(item.name or "Bacanería"),
        tab = tostring(tab and tab.name or "General"),
        kind = kind or (item.type == "action" and "ACCIÓN" or string.upper(tostring(item.type or "OPCIÓN"))),
        key = key or "-",
        description = custom,
        model = "-",
        fallback = "-",
        details = ""
    }

    if kind == "PROP" and type(def) == "table" then
        info.title = tostring(def.label or item.name or key)
        info.model = tostring(def.model or "-")
        info.fallback = tostring(def.fallback or "-")
        if not info.description or info.description == "" then
            local placement = def.placeOnGround == false and "Se crea a la altura configurada" or "Se coloca automáticamente sobre el suelo"
            local orientation = def.alignToPlayer and " y se orienta como el jugador." or "."
            info.description = placement .. orientation
        end
        local z = tonumber(def.zOffset) or 0.0
        info.details = string.format("Z: %.1f  |  Congelado: %s  |  Visibilidad: %s", z, B.FreezeProps == false and "NO" or "SÍ", B.NetworkedProps == true and "SERVIDOR" or "LOCAL")
    elseif kind == "PRESET" and type(def) == "table" then
        local count = type(def.items) == "table" and #def.items or 0
        info.title = tostring(def.label or item.name or key)
        info.model = tostring(count) .. " elementos"
        info.fallback = "Conjunto completo"
        if not info.description or info.description == "" then
            info.description = "Genera una composición completa de props alrededor del punto de aparición, respetando la orientación del jugador."
        end
        info.details = string.format("Distancia: %.0f m  |  Congelado: %s  |  Visibilidad: %s", tonumber(B.SpawnDistance) or 45.0, B.FreezeProps == false and "NO" or "SÍ", B.NetworkedProps == true and "SERVIDOR" or "LOCAL")
    else
        if not info.description or info.description == "" then
            local itemId = Menu.GetItemId(item) or ""
            if itemId:find("distancia", 1, true) then
                info.description = "Ajusta a qué distancia del jugador o del punto de mira aparecerán los props y presets."
            elseif itemId:find("congel", 1, true) then
                info.description = "Activa o desactiva la inmovilización de los objetos recién creados."
            elseif itemId:find("visibilidad", 1, true) then
                info.description = "Elige si los objetos se crean localmente o como entidades de red visibles para el servidor."
            elseif itemId:find("limpiar", 1, true) then
                info.description = "Elimina todos los props creados desde Spawn Bacanerías y limpia su lista interna."
            else
                info.description = "Opción de control de Spawn Bacanerías."
            end
        end
        info.model = tostring(item.value ~= nil and item.value or "-")
        info.fallback = tostring(item.type or "opción")
        info.details = "Pestaña: " .. tostring(tab and tab.name or "General")
    end

    Menu.BacaneriasInfo = info
    Menu.BacaneriasInfoAlpha = Menu.ExpApproach(Menu.BacaneriasInfoAlpha or 0, 1.0, 9.0)
end

-- Partículas independientes para paneles secundarios. Comparten estado,
-- apariencia y velocidad por segundo con Menu.ShowParticles.
local function _CreatePanelSnow(count)
    local particles = {}
    for i = 1, count do
        particles[#particles + 1] = {
            x = math.random(0, 1000) / 1000,
            y = math.random(0, 1000) / 1000,
            speedY = math.random(10, 42) / 100,
            speedX = math.random(-10, 10) / 100,
            size = math.random(1, 2),
            glow = math.random(0, 1) == 1
        }
    end
    return particles
end

Menu.PlayerInfoParticles = Menu.PlayerInfoParticles or _CreatePanelSnow(26)
Menu.BacaneriasInfoParticles = Menu.BacaneriasInfoParticles or _CreatePanelSnow(28)
Menu.LoadedNoticeParticles = Menu.LoadedNoticeParticles or _CreatePanelSnow(34)
Menu.KeySelectorParticles = Menu.KeySelectorParticles or _CreatePanelSnow(30)

function Menu.DrawPanelSnow(particles, x, y, w, h, alpha, speedMultiplier)
    if not Menu.ShowParticles or type(particles) ~= "table" or alpha <= 0 then return end
    speedMultiplier = speedMultiplier or 1.0
    local dt = math.max(0.001, math.min(0.05, Menu.FrameDelta or 0.016))

    for _, part in ipairs(particles) do
        part.y = part.y + (part.speedY or 0.24) * speedMultiplier * dt
        part.x = part.x + (part.speedX or 0.0) * speedMultiplier * dt

        if part.y > 1 then
            part.y = 0
            part.x = math.random(0, 1000) / 1000
        end
        if part.x < 0 then part.x = 1 elseif part.x > 1 then part.x = 0 end

        local px = x + part.x * w
        local py = y + part.y * h
        local size = part.size or 1
        local particleAlpha = (size == 2 and 125 or 90) * alpha

        if part.glow and Menu.ShowIntenseGlows then
            Menu.DrawRect(px - 1, py - 1, size + 2, size + 2,
                Menu.Colors.Accent.r, Menu.Colors.Accent.g, Menu.Colors.Accent.b, 26 * alpha)
        end
        Menu.DrawRect(px, py, size, size, 225, 238, 255, particleAlpha)
    end
end

local function _DrawTextShadow(x, y, text, size, r, g, b, alpha)
    Menu.DrawText(x + 1, y + 1, text, size, 0, 0, 0, 190 * alpha)
    Menu.DrawText(x, y, text, size, r, g, b, 255 * alpha)
end

local function _CompactText(text, maxChars)
    text = tostring(text or "-")
    maxChars = maxChars or 14
    if #text > maxChars then
        return string.sub(text, 1, math.max(1, maxChars - 2)) .. ".."
    end
    return text
end

local function _DrawCompactStatCard(x, y, w, h, label, value, valueR, valueG, valueB, alpha)
    local acR = Menu.Colors.Accent.r / 255.0
    local acG = Menu.Colors.Accent.g / 255.0
    local acB = Menu.Colors.Accent.b / 255.0

    -- Tarjeta ligera: una sola capa, sin líneas largas ni cajas superpuestas.
    Menu.DrawRoundedRect(x, y, w, h, 255, 255, 255, 8 * alpha, 5)
    Menu.DrawRect(x + 8, y + 5, 18, 1, acR, acG, acB, 175 * alpha)

    local labelText = _CompactText(string.upper(label or ""), 18)
    local valueText = _CompactText(value, 16)

    Menu.DrawText(
        x + 8, y + 8,
        labelText, 10,
        Menu.Colors.TextDim.r / 255.0,
        Menu.Colors.TextDim.g / 255.0,
        Menu.Colors.TextDim.b / 255.0,
        210 * alpha
    )

    _DrawTextShadow(
        x + 8, y + 20,
        valueText, 13,
        valueR, valueG, valueB,
        alpha
    )
end

function Menu.DrawPlayerInfoPanel()
    Menu.UpdateHoveredPlayerInfo()
    local info = Menu.PlayerInfo
    local alpha = Menu.PlayerInfoAlpha or 0
    if not info or alpha <= 0.01 then return end

    local p = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x = p.x + p.width + 12 * scale
    local mainBannerH = Menu.GetLayout().headerHeight
    local y = p.y + mainBannerH + 8 * scale

    -- Formato compacto: aproximadamente un 18% menos ancho y un 32% menos alto.
    local w = 248 * scale
    local bannerH = 34 * scale
    local bodyH = 128 * scale
    local totalH = bannerH + bodyH

    local acR = Menu.Colors.Accent.r / 255.0
    local acG = Menu.Colors.Accent.g / 255.0
    local acB = Menu.Colors.Accent.b / 255.0
    local cardAlpha = math.min(218, (Menu.Colors.BgMain.a or 77) + 118) * alpha

    -- Una sola tarjeta y una sombra muy contenida.
    Menu.DrawRoundedRect(x + 3 * scale, y + 4 * scale, w, totalH, 0, 0, 0, 58 * alpha, 8 * scale)
    Menu.DrawRoundedRect(x, y, w, totalH, 0, 0, 0, cardAlpha, 7 * scale)
    Menu.DrawRect(x + 9 * scale, y, 48 * scale, 2 * scale, acR, acG, acB, 230 * alpha)

    -- Banner reducido e integrado en la misma tarjeta.
    if Menu.ShouldDrawBanner(Menu.PlayerInfoBanner) and Menu.playerInfoBannerTexture and Menu.playerInfoBannerTexture > 0 and Susano.DrawImage then
        Susano.DrawImage(
            Menu.playerInfoBannerTexture,
            x + 1 * scale, y + 1 * scale,
            w - 2 * scale, bannerH,
            1, 1, 1, 0.88 * alpha * (Menu.RenderAlpha or 1.0), 0
        )

        local fadeH = 14 * scale
        local steps = 7
        for i = 0, steps - 1 do
            local fy = y + bannerH - fadeH + (i * fadeH / steps)
            Menu.DrawRect(
                x + 1 * scale, fy,
                w - 2 * scale, fadeH / steps + 1,
                0, 0, 0, (24 + i * 16) * alpha
            )
        end
    else
        local title = "PLAYER INFO"
        local titleSize = 14
        local titleW = Menu.MeasureText(title, titleSize)
        _DrawTextShadow(x + w / 2 - titleW / 2, y + 9 * scale, title, titleSize, acR, acG, acB, alpha)
    end

    local bodyY = y + bannerH
    Menu.DrawPanelSnow(
        Menu.PlayerInfoParticles,
        x + 5 * scale, bodyY + 2 * scale,
        w - 10 * scale, bodyH - 5 * scale,
        alpha * 0.58, 0.72
    )

    local pad = 10 * scale
    local left = x + pad
    local innerW = w - pad * 2
    local displayName = _CompactText(info.name or "Jugador", 23)

    -- Cabecera compacta, sin recuadro interno adicional.
    Menu.DrawRoundedRect(left, bodyY + 9 * scale, 3 * scale, 22 * scale, acR, acG, acB, 220 * alpha, 2 * scale)
    _DrawTextShadow(left + 10 * scale, bodyY + 8 * scale, displayName, 17, 1, 1, 1, alpha)

    local onlineText = "ONLINE"
    local onlineSize = 9
    local onlineW = Menu.MeasureText(onlineText, onlineSize)
    local onlineX = x + w - onlineW - 14 * scale
    Menu.DrawRoundedRect(onlineX - 8 * scale, bodyY + 11 * scale, onlineW + 12 * scale, 16 * scale, acR, acG, acB, 24 * alpha, 8 * scale)
    Menu.DrawRoundedRect(onlineX - 4 * scale, bodyY + 17 * scale, 3 * scale, 3 * scale, acR, acG, acB, 235 * alpha, 2 * scale)
    Menu.DrawText(onlineX + 2 * scale, bodyY + 13 * scale, onlineText, onlineSize, acR, acG, acB, 225 * alpha)

    -- Línea corta decorativa en lugar de un separador de ancho completo.
    Menu.DrawRect(left + 10 * scale, bodyY + 34 * scale, 64 * scale, 1, acR, acG, acB, 85 * alpha)

    local gap = 6 * scale
    local cardW = (innerW - gap) / 2
    local cardH = 36 * scale
    local row1Y = bodyY + 41 * scale
    local row2Y = row1Y + cardH + 5 * scale

    _DrawCompactStatCard(
        left, row1Y, cardW, cardH,
        "ID servidor", tostring(info.serverId or 0),
        1, 1, 1, alpha
    )
    _DrawCompactStatCard(
        left + cardW + gap, row1Y, cardW, cardH,
        "ID local", tostring(info.localId or 0),
        1, 1, 1, alpha
    )
    _DrawCompactStatCard(
        left, row2Y, cardW, cardH,
        "Distancia", string.format("%.1f m", info.distance or 0),
        1, 1, 1, alpha
    )

    local weaponLabel = "Estado"
    local weaponValue = info.hasWeapon and "ARMADO" or "SIN ARMA"
    if info.hasWeapon then
        local compactHash = tonumber(info.weaponHash) or 0
        weaponLabel = string.format("Arma %04X", compactHash % 65536)
    end
    local wr, wg, wb = 0.55, 1.0, 0.72
    if info.hasWeapon then wr, wg, wb = 1.0, 0.78, 0.28 end

    _DrawCompactStatCard(
        left + cardW + gap, row2Y, cardW, cardH,
        weaponLabel, weaponValue,
        wr, wg, wb, alpha
    )
end

local function _WrapPanelText(text, maxChars, maxLines)
    text = tostring(text or "-")
    maxChars = maxChars or 36
    maxLines = maxLines or 4
    local lines, current = {}, ""
    for word in text:gmatch("%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if #candidate > maxChars and current ~= "" then
            lines[#lines + 1] = current
            current = word
            if #lines >= maxLines then break end
        else
            current = candidate
        end
    end
    if #lines < maxLines and current ~= "" then lines[#lines + 1] = current end
    if #lines == maxLines then
        local consumed = table.concat(lines, " ")
        if #consumed < #text then lines[#lines] = _CompactText(lines[#lines], math.max(4, maxChars - 1)) end
    end
    return lines
end

function Menu.DrawBacaneriasInfoPanel()
    Menu.UpdateHoveredBacaneriasInfo()
    local info = Menu.BacaneriasInfo
    local alpha = Menu.BacaneriasInfoAlpha or 0
    if not info or alpha <= 0.01 then return end

    local p = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x = p.x + p.width + 12 * scale
    local mainBannerH = Menu.GetLayout().headerHeight
    local y = p.y + mainBannerH + 8 * scale
    local w = 310 * scale
    local bannerH = 62 * scale
    local bodyH = 190 * scale
    local totalH = bannerH + bodyH

    local acR = Menu.Colors.Accent.r / 255.0
    local acG = Menu.Colors.Accent.g / 255.0
    local acB = Menu.Colors.Accent.b / 255.0
    local cardAlpha = math.min(225, (Menu.Colors.BgMain.a or 77) + 125) * alpha

    Menu.DrawRoundedRect(x + 4 * scale, y + 5 * scale, w, totalH, 0, 0, 0, 62 * alpha, 9 * scale)
    Menu.DrawRoundedRect(x, y, w, totalH, 0, 0, 0, cardAlpha, 8 * scale)
    Menu.DrawRect(x + 10 * scale, y, 58 * scale, 2 * scale, acR, acG, acB, 235 * alpha)

    if Menu.ShouldDrawBanner(Menu.BacaneriasInfoBanner) and Menu.bacaneriasInfoBannerTexture and Menu.bacaneriasInfoBannerTexture > 0 and Susano.DrawImage then
        Susano.DrawImage(Menu.bacaneriasInfoBannerTexture, x + 1 * scale, y + 1 * scale, w - 2 * scale, bannerH, 1, 1, 1, 0.92 * alpha * (Menu.RenderAlpha or 1.0), 0)
        for i = 0, 7 do
            Menu.DrawRect(x + 1 * scale, y + bannerH - 16 * scale + i * 2 * scale, w - 2 * scale, 3 * scale, 0, 0, 0, (22 + i * 18) * alpha)
        end
    else
        local fallback = "SPAWN BACANERIAS"
        local fw = Menu.MeasureText(fallback, 18)
        _DrawTextShadow(x + w / 2 - fw / 2, y + 21 * scale, fallback, 18, acR, acG, acB, alpha)
    end

    local bodyY = y + bannerH
    Menu.DrawPanelSnow(Menu.BacaneriasInfoParticles, x + 5 * scale, bodyY + 2 * scale, w - 10 * scale, bodyH - 5 * scale, alpha * 0.48, 0.68)

    local left = x + 12 * scale
    local innerW = w - 24 * scale
    Menu.DrawRoundedRect(left, bodyY + 10 * scale, 3 * scale, 25 * scale, acR, acG, acB, 225 * alpha, 2 * scale)
    _DrawTextShadow(left + 10 * scale, bodyY + 9 * scale, _CompactText(info.title, 31), 17, 1, 1, 1, alpha)

    local badge = tostring(info.kind or "PROP")
    local badgeW = Menu.MeasureText(badge, 9)
    local badgeX = x + w - badgeW - 21 * scale
    Menu.DrawRoundedRect(badgeX - 7 * scale, bodyY + 13 * scale, badgeW + 14 * scale, 16 * scale, acR, acG, acB, 32 * alpha, 8 * scale)
    Menu.DrawText(badgeX, bodyY + 15 * scale, badge, 9, acR, acG, acB, 235 * alpha)

    Menu.DrawRect(left + 10 * scale, bodyY + 40 * scale, 78 * scale, 1, acR, acG, acB, 90 * alpha)
    local lines = _WrapPanelText(info.description, 46, 4)
    for i, line in ipairs(lines) do
        Menu.DrawText(left + 2 * scale, bodyY + (48 + (i - 1) * 15) * scale, line, 11, Menu.Colors.TextDim.r / 255.0, Menu.Colors.TextDim.g / 255.0, Menu.Colors.TextDim.b / 255.0, 235 * alpha)
    end

    local cardsY = bodyY + 112 * scale
    local gap = 6 * scale
    local cardW = (innerW - gap) / 2
    _DrawCompactStatCard(left, cardsY, cardW, 36 * scale, info.kind == "PRESET" and "Contenido" or "Modelo", info.model, 1, 1, 1, alpha)
    _DrawCompactStatCard(left + cardW + gap, cardsY, cardW, 36 * scale, info.kind == "PRESET" and "Tipo" or "Alternativo", info.fallback, 1, 1, 1, alpha)

    Menu.DrawRoundedRect(left, bodyY + 155 * scale, innerW, 25 * scale, 255, 255, 255, 8 * alpha, 5 * scale)
    Menu.DrawRect(left + 8 * scale, bodyY + 160 * scale, 18 * scale, 1, acR, acG, acB, 175 * alpha)
    Menu.DrawText(left + 8 * scale, bodyY + 166 * scale, _CompactText(info.details, 49), 10, Menu.Colors.TextDim.r / 255.0, Menu.Colors.TextDim.g / 255.0, Menu.Colors.TextDim.b / 255.0, 225 * alpha)
end

function Menu.DrawLoadedNotice()
    if not Menu.LoadedNoticeActive or not Menu.LoadedNoticeStartTime then return end

    local now = GetGameTimer and GetGameTimer() or 0
    local elapsed = now - Menu.LoadedNoticeStartTime
    local duration = Menu.LoadedNoticeDuration or 5600
    if elapsed >= duration then
        Menu.LoadedNoticeActive = false
        return
    end

    local fadeIn = Menu.ReduceMotion and 1 or 450
    local fadeOut = Menu.ReduceMotion and 1 or 900
    local remaining = duration - elapsed
    local alpha = math.min(1.0, math.max(0.0, elapsed / fadeIn))
    if remaining < fadeOut then alpha = alpha * math.max(0.0, remaining / fadeOut) end
    if alpha <= 0 then return end

    local sw, sh = 1920, 1080
    if Susano.GetScreenWidth then sw = Susano.GetScreenWidth() or sw end
    if Susano.GetScreenHeight then sh = Susano.GetScreenHeight() or sh end

    local w = 620
    local h = 92
    local x = sw / 2 - w / 2
    local targetY = sh - 175
    local slideOffset = Menu.ReduceMotion and 0 or ((1.0 - math.min(1.0, elapsed / 520)) * 24)
    local y = targetY + slideOffset

    local acR = Menu.Colors.Accent.r / 255.0
    local acG = Menu.Colors.Accent.g / 255.0
    local acB = Menu.Colors.Accent.b / 255.0

    if Menu.ShowIntenseGlows then
        Menu.DrawRoundedRect(x - 7, y - 7, w + 14, h + 14, acR, acG, acB, 18 * alpha, 11)
        Menu.DrawRoundedRect(x - 3, y - 3, w + 6, h + 6, acR, acG, acB, 30 * alpha, 9)
    end
    Menu.DrawRoundedRect(x, y, w, h, 0, 0, 0, 220 * alpha, 8)
    Menu.DrawRect(x, y, w, 2, acR, acG, acB, 235 * alpha)
    Menu.DrawRect(x, y + h - 2, w, 2, acR, acG, acB, 100 * alpha)

    Menu.DrawPanelSnow(Menu.LoadedNoticeParticles, x + 4, y + 4, w - 8, h - 8, alpha * 0.75, 0.75)

    local status = "INICIALIZACION COMPLETADA"
    local statusSize = 11
    local statusWidth = Menu.MeasureText(status, statusSize)
    Menu.DrawText(x + w / 2 - statusWidth / 2, y + 13, status, statusSize, acR, acG, acB, 235 * alpha)

    local message = Menu.LoadedNoticeMessage or ("SENTEXMODZ cargado, presiona " .. tostring(Menu.SelectedKeyName or "tu tecla") .. " para abrir")
    local messageSize = 20
    local messageWidth = Menu.MeasureText(message, messageSize)
    _DrawTextShadow(x + w / 2 - messageWidth / 2, y + 38, message, messageSize, 1, 1, 1, alpha)

    -- Línea animada de tiempo restante.
    local progress = math.min(1.0, math.max(0.0, elapsed / duration))
    local lineW = Menu.ReduceMotion and (w - 34) or ((w - 34) * (1.0 - progress))
    Menu.DrawRoundedRect(x + 17, y + h - 10, w - 34, 3, 18, 24, 38, 170 * alpha, 2)
    if lineW > 0 then
        Menu.DrawRoundedRect(x + 17, y + h - 10, lineW, 3, acR, acG, acB, 235 * alpha, 2)
    end
end

function Menu.Render()
    if Menu.TopLevelTabs and (not Menu.Categories or #Menu.Categories <= 1) then Menu.UpdateCategoriesFromTopTab() end

    -- Ajustes visuales pueden ser añadidos por el otro Lua después de cargar
    -- la librería. Revalidamos de forma ligera para que siempre aparezcan.
    local settingsNow = GetGameTimer and GetGameTimer() or 0
    if Menu.EnsureVisualSettings and (not Menu._LastVisualSettingsCheck or settingsNow - Menu._LastVisualSettingsCheck >= 750) then
        Menu._LastVisualSettingsCheck = settingsNow
        pcall(Menu.EnsureVisualSettings)
    end

    if Menu.UpdateMenuInteractionLock then Menu.UpdateMenuInteractionLock() end
    if not Susano.BeginFrame then return end
    local dt = GetFrameTime and GetFrameTime() or 0.016
    Menu.FrameDelta = math.max(0.001, math.min(0.05, dt))
    local anim = 5.0 * Menu.FrameDelta

    Menu.MenuAlpha = Menu.ExpApproach(Menu.MenuAlpha or 0.0, Menu.Visible and 1.0 or 0.0, Menu.Visible and 12.0 or 15.0)
    local contentState = tostring(Menu.CurrentTopTab or 1) .. ":" .. tostring(Menu.OpenedCategory or 0) .. ":" .. tostring(Menu.CurrentTab or 1)
    if Menu.LastContentState ~= contentState then
        Menu.LastContentState = contentState
        Menu.ContentAlpha = Menu.ReduceMotion and 1.0 or 0.30
        Menu.ContentSlideY = Menu.ReduceMotion and 0.0 or (6.0 * (Menu.Scale or 1.0))
    end
    Menu.ContentAlpha = Menu.ExpApproach(Menu.ContentAlpha or 1.0, 1.0, 13.0)
    Menu.ContentSlideY = Menu.ExpApproach(Menu.ContentSlideY or 0.0, 0.0, 12.0)
    if Menu.ReduceMotion then
        Menu.LoadingBarAlpha = Menu.IsLoading and 1 or 0
        Menu.KeySelectorAlpha = (Menu.SelectingKey or Menu.SelectingBind) and 1 or 0
        Menu.KeybindsInterfaceAlpha = Menu.ShowKeybinds and 1 or 0
    else
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
    end
    Susano.BeginFrame()
    if Menu.KeybindsInterfaceAlpha > 0 then Menu.DrawKeybindsInterface(Menu.KeybindsInterfaceAlpha) end
    if (Menu.MenuAlpha or 0) > 0.01 then
        local originalY = Menu.Position.y
        Menu.Position.y = originalY + (Menu.ReduceMotion and 0 or ((1.0 - Menu.MenuAlpha) * 7.0))
        Menu.RenderAlpha = Menu.MenuAlpha
        Menu.DrawBackground()
        Menu.DrawHeader()

        local baseAlpha = Menu.RenderAlpha
        Menu.RenderAlpha = baseAlpha * (Menu.ContentAlpha or 1.0)
        Menu.DrawCategories()
        Menu.RenderAlpha = baseAlpha

        Menu.DrawFooter()
        Menu.DrawPlayerInfoPanel()
        Menu.DrawBacaneriasInfoPanel()
        Menu.DrawAnticheatPanel()
        Menu.RenderAlpha = 1.0
        Menu.Position.y = originalY
    end
    Menu.RenderAlpha = 1.0
    if Menu.InputOpen then Menu.DrawInputWindow() end
    if Menu.LoadingBarAlpha > 0 then Menu.DrawLoadingBar(Menu.LoadingBarAlpha) end
    Menu.DrawLoadedNotice()
    if Menu.KeySelectorAlpha > 0 then Menu.DrawKeySelector(Menu.KeySelectorAlpha) end
    if Menu.OnRender then pcall(Menu.OnRender) end
    if Susano.SubmitFrame then Susano.SubmitFrame() end
    if (Menu.MenuAlpha or 0) <= 0.01 and not Menu.ShowKeybinds and Menu.LoadingBarAlpha<=0 and Menu.KeySelectorAlpha<=0 and not Menu.LoadedNoticeActive then
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
        if Menu.InputCallback then SafeInvoke(Menu.InputCallback, Menu.InputText) end
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

-- Inicialización: al completar la barra se exige seleccionar una tecla.
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
            Menu.LoadedNoticeActive = false
            Menu.LoadedNoticeStartTime = nil
            Menu.BeginMenuKeySelection(true)
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

Menu.ApplyTheme("BlackGlass")
if Menu.ShowBanners then Menu.SetBannersEnabled(true) end

local function _IsSettingsCategory(cat)
    local id = tostring(cat and (cat.id or Menu.NormalizeIdentifier(cat.name)) or "")
    return id:find("ajust", 1, true)
        or id:find("config", 1, true)
        or id:find("setting", 1, true)
        or id:find("opcion", 1, true)
end

local function _FindVisualSettingsTab(cat)
    if not cat then return nil end
    cat.tabs = type(cat.tabs) == "table" and cat.tabs or {}

    local fallback = nil
    for _, tab in SafeIpairs(cat.tabs) do
        if type(tab.items) == "table" then
            fallback = fallback or tab
            local id = tostring(tab.id or Menu.NormalizeIdentifier(tab.name))
            if id:find("general", 1, true)
                or id:find("visual", 1, true)
                or id:find("apariencia", 1, true)
                or id:find("menu", 1, true)
                or id:find("tema", 1, true) then
                return tab
            end
        end
    end

    if fallback then return fallback end

    local created = {
        id = (cat.id or "settings") .. "_tab_accessibility",
        name = "Accesibilidad",
        items = {}
    }
    table.insert(cat.tabs, created)
    cat.hasTabs = true
    return created
end

local function _FindItemById(items, id)
    for _, item in SafeIpairs(items) do
        if Menu.GetItemId(item) == id then return item end
    end
    return nil
end

local function _UpsertVisualItem(items, spec)
    local item = _FindItemById(items, spec.id)
    if not item then
        item = {}
        table.insert(items, item)
    end
    for key, value in pairs(spec) do item[key] = value end
    return item
end

local function _AttachVisualSettings(categories, prefix)
    Menu.EnsureStableIds(categories, prefix or "settings")

    for _, cat in SafeIpairs(categories) do
        if _IsSettingsCategory(cat) then
            local tab = _FindVisualSettingsTab(cat)
            if tab and type(tab.items) == "table" then
                local items = tab.items

                -- Normaliza controles heredados sin depender de su nombre en tiempo de ejecución.
                for _, item in SafeIpairs(items) do
                    local id = Menu.GetItemId(item)
                    if id == Menu.Ids.EditorMode and item.type == "toggle" then
                        item.value = Menu.EditorMode
                    elseif id == Menu.Ids.ShowKeybinds and item.type == "toggle" then
                        item.value = Menu.ShowKeybinds
                    elseif id == Menu.Ids.Particles and item.type == "toggle" then
                        item.value = Menu.ShowParticles
                        item.onClick = function(value) Menu.SetParticlesEnabled(value) end
                    elseif id == Menu.Ids.MenuScale and item.type == "slider" then
                        item.value = math.floor((Menu.Scale or 1.0) * 100 + 0.5)
                        item.onClick = function(value)
                            Menu.Scale = _Clamp((tonumber(value) or 100) / 100, 0.70, 1.50)
                        end
                    elseif id == Menu.Ids.Theme and item.type == "selector" then
                        item.onClick = function(index, option)
                            Menu.ApplyTheme(option or item.options[index])
                        end
                    end
                end

                if not _FindItemById(items, "ui_accessibility_separator") then
                    table.insert(items, {
                        id = "ui_accessibility_separator",
                        isSeparator = true,
                        separatorText = "ACCESIBILIDAD Y EFECTOS"
                    })
                end

                _UpsertVisualItem(items, {
                    id = Menu.Ids.ReduceMotion,
                    name = "Reducir animaciones",
                    type = "toggle",
                    value = Menu.ReduceMotion,
                    onClick = function(value) Menu.ReduceMotion = value == true end
                })

                _UpsertVisualItem(items, {
                    id = Menu.Ids.Particles,
                    name = "Partículas",
                    type = "toggle",
                    value = Menu.ShowParticles,
                    onClick = function(value) Menu.SetParticlesEnabled(value) end
                })

                _UpsertVisualItem(items, {
                    id = Menu.Ids.TextScale,
                    name = "Escala de texto",
                    type = "slider",
                    min = 85,
                    max = 135,
                    step = 5,
                    value = math.floor((Menu.TextScale or 1.0) * 100 + 0.5),
                    onClick = function(value) Menu.SetTextScale(value) end
                })

                _UpsertVisualItem(items, {
                    id = Menu.Ids.BackgroundOpacity,
                    name = "Opacidad del fondo",
                    type = "slider",
                    min = 60,
                    max = 95,
                    step = 5,
                    value = math.floor((Menu.BackgroundOpacity or 0.80) * 100 + 0.5),
                    onClick = function(value) Menu.SetBackgroundOpacity(value) end
                })

                _UpsertVisualItem(items, {
                    id = Menu.Ids.HighContrast,
                    name = "Contraste alto",
                    type = "toggle",
                    value = Menu.HighContrast,
                    onClick = function(value) Menu.SetHighContrast(value) end
                })

                _UpsertVisualItem(items, {
                    id = Menu.Ids.Banners,
                    name = "Mostrar banners",
                    type = "toggle",
                    value = Menu.ShowBanners,
                    onClick = function(value) Menu.SetBannersEnabled(value) end
                })

                _UpsertVisualItem(items, {
                    id = Menu.Ids.IntenseGlows,
                    name = "Glows intensos",
                    type = "toggle",
                    value = Menu.ShowIntenseGlows,
                    onClick = function(value) Menu.ShowIntenseGlows = value == true end
                })

                local selectedColor = 1
                for index, colorName in ipairs(Menu.AccentPresetOrder) do
                    if colorName == Menu.CurrentAccentName then
                        selectedColor = index
                        break
                    end
                end

                local colorItem = _UpsertVisualItem(items, {
                    id = Menu.Ids.Accent,
                    name = "Color del menú",
                    type = "selector",
                    options = Menu.AccentPresetOrder,
                    selected = selectedColor
                })
                colorItem.onClick = function(index, option)
                    local chosen = option or Menu.AccentPresetOrder[index] or "Cian"
                    Menu.ApplyAccentPreset(chosen)
                    colorItem.selected = index or colorItem.selected
                end
            end
        end
    end
end

function Menu.EnsureVisualSettings()
    for topIndex, topTab in SafeIpairs(Menu.TopLevelTabs) do
        _AttachVisualSettings(topTab.categories, "top_" .. tostring(topIndex))
    end
    _AttachVisualSettings(Menu.Categories, "current")
    Menu.RefreshVisualTokens()
end

-- Inserta y mantiene el selector aunque Ajustes sea cargado más tarde
-- o reconstruido al cambiar de pestaña superior.
CreateThread(function()
    while true do
        if Menu.EnsureVisualSettings then pcall(Menu.EnsureVisualSettings) end
        Wait(1000)
    end
end)

return Menu
