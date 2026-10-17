-- Aureole Cursor: Einstellungen in der Blizzard-Optionsoberflaeche (Vertical-Layout, Proxy-Settings).
-- Alles liegt auf einer Seite; Abschnitte (Allgemein, je ein Ring, Mittelpunkt) haben Ueberschriften
-- und werden in eigenen Funktionen aufgebaut, damit sich Optionen Schritt fuer Schritt ergaenzen lassen.
local ADDON, ns = ...

local L = ns.L

local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

local function section(key)
    if key == nil then return ns.cfg end
    return ns.cfg[key]
end

local function defaultOf(key, field)
    local src = key == nil and ns.defaults or ns.defaults[key]
    return src[field]
end

local function varName(key, field)
    return string.upper("AUREOLECURSOR_" .. (key or "GENERAL") .. "_" .. field)
end

-- Proxy-Setting: liest und schreibt immer in die aktuelle ns.cfg (die beim Reset ersetzt wird).
local function proxy(category, key, field, vtype, label)
    local function get() return section(key)[field] end
    local function set(value)
        section(key)[field] = value
        ns:Apply()
    end
    return Settings.RegisterProxySetting(category, varName(key, field), vtype, label, defaultOf(key, field), get, set)
end

local function checkbox(category, key, field, label, tip)
    local s = proxy(category, key, field, Settings.VarType.Boolean, label)
    return Settings.CreateCheckbox(category, s, tip)
end

local function slider(category, key, field, label, tip, min, max, step, formatter)
    local s = proxy(category, key, field, Settings.VarType.Number, label)
    local options = Settings.CreateSliderOptions(min, max, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
    return Settings.CreateSlider(category, s, options, tip)
end

local function percent(v)
    return string.format("%d%%", math.floor(v * 100 + 0.5))
end

local function twoDecimals(v)
    return string.format("%.2f", v)
end

local function seconds(v)
    return string.format("%.2f s", v)
end

-- Farb-Swatch: der Setting-Wert ist ein ARGB-Hexstring, in der Config liegt {r, g, b, a}.
-- Die Deckkraft hat einen eigenen Regler, deshalb bleibt a beim Farbwechsel unberuehrt.
local function colorSwatch(category, key, label, tip, field)
    field = field or "color"
    local function hexOf(col)
        return CreateColor(col[1], col[2], col[3], 1):GenerateHexColor()
    end
    local function get() return hexOf(section(key)[field]) end
    local function set(hex)
        local c = CreateColorFromHexString(hex)
        local col = section(key)[field]
        col[1], col[2], col[3] = c.r, c.g, c.b
        ns:Apply()
    end
    local s = Settings.RegisterProxySetting(category, varName(key, field), Settings.VarType.String, label,
        hexOf(ns.defaults[key][field]), get, set)
    return Settings.CreateColorSwatch(category, s, tip)
end

local function opacitySlider(category, key, label, tip)
    local function get() return section(key).color[4] end
    local function set(value)
        section(key).color[4] = value
        ns:Apply()
    end
    local s = Settings.RegisterProxySetting(category, varName(key, "OPACITY"), Settings.VarType.Number, label,
        ns.defaults[key].color[4], get, set)
    local options = Settings.CreateSliderOptions(0.05, 1, 0.05)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, percent)
    return Settings.CreateSlider(category, s, options, tip)
end

------------------------------------------------------------------------
-- Seiten
------------------------------------------------------------------------

local function header(layout, title)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title))
end

local function buildGeneral(category, layout)
    header(layout, L.general)
    slider(category, nil, "scale", L.scale, L.scaleTip, 0.5, 3, 0.05, twoDecimals)
    slider(category, nil, "alpha", L.alpha, L.alphaTip, 0.1, 1, 0.05, percent)
    slider(category, nil, "idleAlpha", L.idleAlpha, L.idleAlphaTip, 0, 1, 0.05, percent)
    checkbox(category, nil, "combatOnly", L.combatOnly, L.combatOnlyTip)
    checkbox(category, nil, "hideOnMouselook", L.hideOnMouselook, L.hideOnMouselookTip)

    local s = proxy(category, nil, "strata", Settings.VarType.String, L.strata)
    local function options()
        local c = Settings.CreateControlTextContainer()
        for _, name in ipairs(STRATA) do c:Add(name, name) end
        return c:GetData()
    end
    Settings.CreateDropdown(category, s, options, L.strataTip)
end

-- Abschnitt fuer ein Element; die Optionen darunter sind nur aktiv, solange "Anzeigen" an ist.
-- opts: size = { min, max, step }, thickness (Ring-Dicke), track (Hintergrund-Spur),
--       extra = function(category, key, child) fuer elementspezifische Optionen.
local function buildElement(category, layout, key, title, opts)
    header(layout, title)
    local enable = checkbox(category, key, "enabled", L.enabled, L[key .. "Tip"])
    local function child(initializer)
        initializer:SetParentInitializer(enable, function() return ns.cfg[key].enabled end)
    end

    local size = opts.size or { 8, 400, 2 }
    child(slider(category, key, "size", L.size, L.sizeTip, size[1], size[2], size[3]))
    if opts.thickness then
        child(slider(category, key, "thickness", L.thickness, L.thicknessTip, 1, ns.MAX_THICKNESS, 1))
    end
    if opts.extra then opts.extra(category, key, child) end
    if opts.colorMode then
        -- Farbmodus als Dropdown; die Farbwahl ist nur bei "Eigene Farbe" aktiv
        local mode = proxy(category, key, "colorMode", Settings.VarType.String, L.colorMode)
        local function modes()
            local c = Settings.CreateControlTextContainer()
            c:Add("rainbow", L.modeRainbow)
            c:Add("class", L.modeClass)
            c:Add("autumn", L.modeAutumn)
            c:Add("winter", L.modeWinter)
            c:Add("christmas", L.modeChristmas)
            c:Add("custom", L.modeCustom)
            return c:GetData()
        end
        local dropdown = Settings.CreateDropdown(category, mode, modes, L.colorModeTip)
        child(dropdown)
        local swatch = colorSwatch(category, key, L.color, L.colorTip)
        swatch:SetParentInitializer(dropdown, function()
            return ns.cfg[key].enabled and ns.cfg[key].colorMode == "custom"
        end)
    else
        -- Die Farbwahl ist bei aktiver Klassenfarbe ausgegraut
        local class = checkbox(category, key, "classColor", L.classColor, L.classColorTip)
        child(class)
        local swatch = colorSwatch(category, key, L.color, L.colorTip)
        swatch:SetParentInitializer(class, function()
            return ns.cfg[key].enabled and not ns.cfg[key].classColor
        end)
    end
    child(opacitySlider(category, key, L.opacity, L.opacityTip))
    if opts.combatTint then
        local tint = checkbox(category, key, "combatTint", L.combatTint, L.combatTintTip)
        child(tint)
        local swatch = colorSwatch(category, key, L.combatColor, L.combatColorTip, "combatColor")
        swatch:SetParentInitializer(tint, function()
            return ns.cfg[key].enabled and ns.cfg[key].combatTint
        end)
    end
    if opts.track then
        child(checkbox(category, key, "track", L.track, L.trackTip))
        child(slider(category, key, "trackAlpha", L.trackAlpha, L.trackAlphaTip, 0.05, 1, 0.05, percent))
    end
end

-- Form-Dropdown: choices = { { Wert, Text }, ... }
local function shapeDropdown(category, key, child, tip, choices)
    local shape = proxy(category, key, "shape", Settings.VarType.String, L.shape)
    local function shapes()
        local c = Settings.CreateControlTextContainer()
        for _, choice in ipairs(choices) do c:Add(choice[1], choice[2]) end
        return c:GetData()
    end
    child(Settings.CreateDropdown(category, shape, shapes, tip))
end

local function dotOptions(category, key, child)
    shapeDropdown(category, key, child, L.dotShapeTip, {
        { "dot", L.shapeDot }, { "gap", L.shapeGap }, { "ring", L.shapeRing }, { "spark", L.shapeSpark },
    })

    -- Klick-Impuls: Taste und Groesse sind nur bei aktivem Impuls bedienbar
    local pulse = checkbox(category, key, "pulse", L.pulse, L.pulseTip)
    child(pulse)
    local function whenPulse()
        return ns.cfg[key].enabled and ns.cfg[key].pulse
    end
    local button = proxy(category, key, "pulseButton", Settings.VarType.String, L.pulseButton)
    local function buttons()
        local c = Settings.CreateControlTextContainer()
        c:Add("left", L.buttonLeft)
        c:Add("right", L.buttonRight)
        c:Add("both", L.buttonBoth)
        return c:GetData()
    end
    Settings.CreateDropdown(category, button, buttons, L.pulseButtonTip):SetParentInitializer(pulse, whenPulse)
    slider(category, key, "pulseSize", L.pulseSize, L.pulseSizeTip, 1.5, 6, 0.5, function(v)
        return string.format("%.1fx", v)
    end):SetParentInitializer(pulse, whenPulse)
end

local function trailOptions(category, key, child)
    shapeDropdown(category, key, child, L.shapeTip, {
        { "dot", L.shapeDot }, { "leaf", L.shapeLeaf }, { "snow", L.shapeSnow }, { "star", L.shapeStar },
    })
    child(slider(category, key, "duration", L.duration, L.durationTip, 0.1, 1.5, 0.05, seconds))
    child(slider(category, key, "spacing", L.spacing, L.spacingTip, 2, 40, 1))
    child(checkbox(category, key, "shrink", L.shrink, L.shrinkTip))
end

local function build()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

    local category, layout = Settings.RegisterVerticalLayoutCategory("Aureole Cursor")
    ns.settingsCategory = category

    buildGeneral(category, layout)
    buildElement(category, layout, "main", L.main, { thickness = true, combatTint = true })
    buildElement(category, layout, "gcd", L.gcd, { thickness = true, track = true })
    buildElement(category, layout, "cast", L.cast, { thickness = true, track = true })
    buildElement(category, layout, "dot", L.dot, { extra = dotOptions })
    buildElement(category, layout, "trail", L.trail, { size = { 4, 64, 1 }, colorMode = true, extra = trailOptions })

    Settings.RegisterAddOnCategory(category)
end

function ns:OpenSettings()
    if self.settingsCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    end
end

ns:On("ADDON_LOADED", function(_, name)
    if name == ADDON then build() end
end)
