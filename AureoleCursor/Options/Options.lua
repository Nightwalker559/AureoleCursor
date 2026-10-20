-- Aureole Cursor: settings in the Blizzard options UI (vertical layout, proxy settings).
-- Everything is on one page; sections (General, one per element) have headers
-- and are built in separate functions so options can be added step by step.
local ADDON, ns = ...

local L = ns.L

-- Frame strata as dropdown choices ({ value, text })
local STRATA = {}
for _, name in ipairs({ "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }) do
    STRATA[#STRATA + 1] = { name, name }
end

-- While a section is being built, the helpers below collect their initializers here, so the whole section
-- (header included) can get a shown predicate afterwards (see buildElement).
local sectionItems

local function track(initializer)
    if sectionItems then sectionItems[#sectionItems + 1] = initializer end
    return initializer
end

-- Where a setting lives in the config. Settings are named after the element they belong to (key, nil = General) and the
-- field. The colors are not part of the element: they are in the palette (cfg.colors.custom[key]), the combat color in
-- cfg.colors.combat, the theme in cfg.colors. holder() gives the table that holds the value and the real name of the
-- field in it. Settings change the custom colors; what a setting shows is the palette in use (a theme's, see valueOf).
local PALETTE_FIELDS = {
    color = true, color2 = true, color3 = true, color4 = true, gradient = true, blend = true,
    gradientDir = true, colorCount = true, colorMode = true,
}
local COMBAT_FIELDS = { combatTint = "enabled", combatTarget = "target", combatColor = "color" }

local function holder(root, key, field, shown)
    if key == nil then
        if COMBAT_FIELDS[field] then return root.colors.combat, COMBAT_FIELDS[field] end
        if field == "theme" then return root.colors, "theme" end
        return root, field
    end
    if PALETTE_FIELDS[field] then return (shown and ns:Palette() or root.colors.custom)[key], field end
    return root[key], field
end

local function valueOf(key, field)
    local t, f = holder(ns.cfg, key, field, true)
    return t[f]
end

-- Variables of the settings that show a palette value (colors, gradients, counts ...): they show the colors of a theme
-- while one is active, so they are told to show their value again when the theme changes.
local paletteVars = {}

local function notifyPalette()
    for _, var in ipairs(paletteVars) do Settings.NotifyUpdate(var) end
end

local function defaultOf(key, field)
    local t, f = holder(ns.defaults, key, field)
    return t[f]
end

local function varName(key, field)
    return string.upper("AUREOLECURSOR_" .. (key or "GENERAL") .. "_" .. field)
end

-- After a theme change: the palette, and the trail settings that follow its shape (a theme can bring a shape of its own)
local function notifyTheme()
    notifyPalette()
    for _, field in ipairs({ "shape", "size", "duration", "spacing", "colorMode" }) do
        Settings.NotifyUpdate(varName("trail", field))
    end
end

-- Color settings are greyed out while a theme is active (they show its colors, but cannot be changed). Every one of them
-- is evaluated again when the theme setting reports a change.
local THEME_VAR = varName(nil, "theme")

local function editable()
    return ns.cfg.colors.theme == "custom"
end

local function themed(initializer)
    initializer:AddModifyPredicate(editable)
    initializer:AddEvaluateStateCVar(THEME_VAR)
    return initializer
end

-- Some options hang off a different setting than the one they really depend on (the Blizzard panel only re-evaluates
-- children of the setting that changed). After a change, tell that intermediate setting to refresh its children.
local function notifyDependents(key, field)
    if key == nil and field == "theme" then
        notifyTheme() -- the color settings show the colors of the theme, the trail may have changed its shape
    elseif key == "trail" and (field == "enabled" or field == "colorMode") then
        Settings.NotifyUpdate(varName(key, "colorCount")) -- the extra trail colors follow the color count
    elseif (key == "cast" or key == "gcd") and field == "enabled" then
        Settings.NotifyUpdate(varName(key, "gradient")) -- the color row follows the gradient switch
    end
end

-- Proxy setting: always reads from and writes to the current ns.cfg (which is replaced on reset).
local function proxy(category, key, field, vtype, label)
    local function get() return valueOf(key, field) end
    local function set(value)
        if key == nil and field == "theme" then
            ns:SetTheme(value) -- a theme may bring its own trail shape
        else
            local t, f = holder(ns.cfg, key, field)
            t[f] = value
        end
        ns:Apply()
        notifyDependents(key, field)
    end
    if key and PALETTE_FIELDS[field] then paletteVars[#paletteVars + 1] = varName(key, field) end
    return Settings.RegisterProxySetting(category, varName(key, field), vtype, label, defaultOf(key, field), get, set)
end

local function checkbox(category, key, field, label, tip)
    local s = proxy(category, key, field, Settings.VarType.Boolean, label)
    return track(Settings.CreateCheckbox(category, s, tip))
end

-- Dropdown options from a list of { value, text } choices.
local function choiceList(choices)
    return function()
        local c = Settings.CreateControlTextContainer()
        for _, choice in ipairs(choices) do
            if not choice[3] or choice[3]() then c:Add(choice[1], choice[2]) end -- 3rd entry: is the choice offered right now?
        end
        return c:GetData()
    end
end

local function dropdown(category, key, field, label, tip, choices)
    local s = proxy(category, key, field, Settings.VarType.String, label)
    return track(Settings.CreateDropdown(category, s, choiceList(choices), tip))
end

local function slider(category, key, field, label, tip, min, max, step, formatter)
    local s = proxy(category, key, field, Settings.VarType.Number, label)
    local options = Settings.CreateSliderOptions(min, max, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
    return track(Settings.CreateSlider(category, s, options, tip))
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

-- Color swatch: the setting value is an ARGB hex string, the config holds {r, g, b} (the opacity is the overall one).
local function colorSetting(category, key, label, field)
    field = field or "color"
    local function hexOf(col)
        return CreateColor(col[1], col[2], col[3], 1):GenerateHexColor()
    end
    local function get() return hexOf(valueOf(key, field)) end
    local function set(hex)
        local c = CreateColorFromHexString(hex)
        local t, f = holder(ns.cfg, key, field) -- the custom color, never a color of a theme
        t[f][1], t[f][2], t[f][3] = c.r, c.g, c.b
        ns:Apply()
    end
    if key then paletteVars[#paletteVars + 1] = varName(key, field) end
    return Settings.RegisterProxySetting(category, varName(key, field), Settings.VarType.String, label,
        hexOf(defaultOf(key, field)), get, set)
end

-- Several swatches side by side in one row (ColorRow.xml); count() says how many of the entries are shown.
local function colorEntry(category, key, field, name)
    return { setting = colorSetting(category, key, name, field), name = name, tooltip = L.colorTip }
end

-- The swatches of a color row: color, color2 ... up to the given number.
local function colorEntries(category, key, number)
    local entries = { colorEntry(category, key, "color", L.color) }
    for i = 2, number do entries[i] = colorEntry(category, key, "color" .. i, L["color" .. i]) end
    return entries
end

local function colorRow(layout, name, tip, entries, count)
    local row = Settings.CreateElementInitializer("AureoleCursorColorRowTemplate", {
        name = name, tooltip = tip, entries = entries, count = count,
    })
    layout:AddInitializer(row)
    return track(row)
end

------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------

local function header(layout, title)
    local initializer = CreateSettingsListSectionHeaderInitializer(title)
    layout:AddInitializer(initializer)
    track(initializer)
end

local function buildGeneral(category, layout)
    header(layout, L.general)

    -- Main style: the Main Ring or the pointer glow surrounds the cursor; the options of the other one are hidden
    dropdown(category, nil, "mainStyle", L.mainStyle, L.mainStyleTip, {
        { "ring", L.main }, { "glow", L.glow },
    })

    -- Ring layout: which rings are used at all; the options of a ring that is switched off are hidden
    dropdown(category, nil, "ringLayout", L.ringLayout, L.ringLayoutTip, {
        { "individual", L.layoutIndividual }, { "maincast", L.layoutMainCast }, { "maingcd", L.layoutMainGcd },
    }):AddShownPredicate(function() return ns.cfg.mainStyle ~= "glow" end) -- no rings with the pointer glow

    -- Color theme: replaces the colors of all elements at once (they are greyed out and show the theme's colors). The button
    -- takes the colors of the theme over as the own colors, so a theme can be adjusted.
    local choices = { { "custom", L.themeCustom } }
    for _, theme in ipairs(ns.THEMES) do choices[#choices + 1] = { theme.id, L[theme.name] } end
    dropdown(category, nil, "theme", L.theme, L.themeTip, choices)
    local copy = CreateSettingsButtonInitializer(L.themeCopy, L.themeCopyButton, function()
        ns:UseThemeAsCustom()
        Settings.NotifyUpdate(THEME_VAR)
        notifyTheme()
    end, L.themeCopyTip, true)
    layout:AddInitializer(copy)
    copy:AddModifyPredicate(function() return not editable() end)
    copy:AddEvaluateStateCVar(THEME_VAR)

    slider(category, nil, "scale", L.scale, L.scaleTip, 0.5, 3, 0.05, twoDecimals)
    slider(category, nil, "alpha", L.alpha, L.alphaTip, 0.1, 1, 0.05, percent)
    slider(category, nil, "idleAlpha", L.idleAlpha, L.idleAlphaTip, 0, 1, 0.05, percent)
    slider(category, nil, "trackAlpha", L.trackAlpha, L.trackAlphaTip, 0.05, 1, 0.05, percent)
    checkbox(category, nil, "combatOnly", L.combatOnly, L.combatOnlyTip)
    checkbox(category, nil, "hideOnMouselook", L.hideOnMouselook, L.hideOnMouselookTip)

    -- Combat color: choose whether the Main Ring or the center dot switches to the combat color in combat
    local tint = checkbox(category, nil, "combatTint", L.combatTint, L.combatTintTip)
    local function tintOn() return ns.cfg.colors.combat.enabled end
    -- With the pointer glow the glow always takes the combat color, so there is nothing to choose
    local target = dropdown(category, nil, "combatTarget", L.combatTarget, L.combatTargetTip, {
        { "main", L.main }, { "dot", L.targetDot },
    })
    target:SetParentInitializer(tint, tintOn)
    target:AddShownPredicate(function() return ns.cfg.mainStyle ~= "glow" end)
    colorRow(layout, L.combatColor, L.combatColorTip, { colorEntry(category, nil, "combatColor", L.color) }, function() return 1 end)
        :SetParentInitializer(tint, tintOn)

    dropdown(category, nil, "strata", L.strata, L.strataTip, STRATA)
end

-- Section for one element; the options below are only active while "Show" is on.
-- opts: size = { min, max, step } (false: no size slider), noEnable (no "Show" switch), thickness (ring thickness),
--       track (background track switch), colors ("simple": one color, "gradient": with a gradient over the GCD or cast,
--       "glow": one or two colors, "trail": color modes), ringActive (the whole section is hidden while
--       ns:RingActive(key) is false), extra = function(category, key, child) for element-specific options.
-- The colors are edited in the palette (cfg.colors.custom[key], see holder()).
local function buildElement(category, layout, key, title, opts)
    sectionItems = opts.ringActive and {} or nil
    header(layout, title)
    -- opts.noEnable: the element has no switch of its own (the pointer glow follows the main style in General)
    local enable = not opts.noEnable and checkbox(category, key, "enabled", L.enabled, L[key .. "Tip"]) or nil
    local function on() return opts.noEnable or ns.cfg[key].enabled end
    local function child(initializer)
        if enable then initializer:SetParentInitializer(enable, on) end
    end
    local function custom() return ns.cfg.colors.custom[key] end

    if opts.size ~= false then
        local size = opts.size or { 8, 400, 2 }
        child(slider(category, key, "size", L.size, L.sizeTip, size[1], size[2], size[3]))
    end
    if opts.thickness then
        child(slider(category, key, "thickness", L.thickness, L.thicknessTip, 1, ns.MAX_THICKNESS, 1))
    end
    if opts.extra then opts.extra(category, key, child) end
    local mode = opts.colors or "simple"
    if mode == "trail" then
        -- The energy shape has fixed original colors: color mode and colors are greyed out
        local function colorable() return on() and ns.cfg[key].shape ~= "energy" end
        local function customMode() return colorable() and custom().colorMode == "custom" end
        -- Color mode as a dropdown; the colors are only active for "Custom color"
        local modeDD = themed(dropdown(category, key, "colorMode", L.colorMode, L.colorModeTip, {
            { "rainbow", L.modeRainbow }, { "spring", L.modeSpring }, { "summer", L.modeSummer }, { "autumn", L.modeAutumn },
            { "winter", L.modeWinter }, { "christmas", L.modeChristmas }, { "fire", L.modeFire }, { "love", L.modeLove },
            { "ocean", L.modeOcean }, { "gold", L.modeGold }, { "arcane", L.modeArcane }, { "storm", L.modeStorm }, { "custom", L.modeCustom },
        }))
        modeDD:SetParentInitializer(enable, colorable)
        -- Custom color: 1-4 colors, blended along the trail (gradient) or picked at random per dot.
        -- The colors share one row (ColorRow.xml) that hangs off the color count and shows as many swatches as the
        -- count says; the count itself reports changes of the enable switch and the color mode (see proxy).
        local count = themed(slider(category, key, "colorCount", L.colorCount, L.colorCountTip, 1, 4, 1))
        count:SetParentInitializer(modeDD, customMode)
        themed(colorRow(layout, L.colors, L.colorsTip, colorEntries(category, key, 4), function() return custom().colorCount end))
            :SetParentInitializer(count, customMode)
        local blend = themed(checkbox(category, key, "gradient", L.gradient, L.gradientTip))
        blend:SetParentInitializer(count, function()
            return customMode() and custom().colorCount > 1
        end)
    elseif mode == "gradient" then
        -- GCD and Cast Ring: the ring moves from color 1 to color 2 while the GCD runs or the cast progresses. The color row
        -- shows one swatch, or two with the gradient; it hangs off the gradient switch, changes of the enable switch are
        -- reported to the gradient through the proxy (see notifyDependents).
        local blend = themed(checkbox(category, key, "gradient", L.castGradient, L[key .. "GradientTip"]))
        child(blend)
        themed(colorRow(layout, L.colors, L[key .. "ColorsTip"], colorEntries(category, key, 2), function() return custom().gradient and 2 or 1 end))
            :SetParentInitializer(blend, on)
    elseif mode == "glow" then
        -- Pointer glow: one or two colors in one row like the custom colors of the trail.
        -- Two colors are blended (gradient) or shown as two halves, from top to bottom or from left to right.
        local count = themed(slider(category, key, "colorCount", L.colorCount, L.glowColorCountTip, 1, 2, 1))
        child(count)
        themed(colorRow(layout, L.colors, L.glowColorsTip, colorEntries(category, key, 2), function() return custom().colorCount end))
            :SetParentInitializer(count, function() return true end)
        local function two() return custom().colorCount > 1 end
        themed(checkbox(category, key, "blend", L.glowGradient, L.glowGradientTip)):SetParentInitializer(count, two)
        themed(dropdown(category, key, "gradientDir", L.glowDirection, L.glowDirectionTip, {
            { "vertical", L.dirVertical }, { "horizontal", L.dirHorizontal },
        })):SetParentInitializer(count, two)
    else
        child(themed(colorRow(layout, L.color, L.colorTip, colorEntries(category, key, 1), function() return 1 end)))
    end
    if opts.track then
        child(checkbox(category, key, "track", L.track, L.trackTip))
    end
    if sectionItems then
        -- sections of elements that are not in use disappear completely (see ns:RingActive); the panel
        -- re-evaluates shown predicates after every setting change
        for _, item in ipairs(sectionItems) do
            item:AddShownPredicate(function() return ns:RingActive(key) end)
        end
        sectionItems = nil
    end
end

-- Shape dropdown: choices = { { value, text }, ... }
local function shapeDropdown(category, key, child, tip, choices)
    local function setShape(value)
        if key == "dot" then
            ns:SetDotShape(value) -- each center dot shape has its own size
        elseif key == "trail" then
            ns:SetTrailShape(value) -- each trail shape has its own size, duration and spacing
        else
            ns.cfg[key].shape = value
        end
        ns:Apply()
        if key == "dot" then
            Settings.NotifyUpdate(varName(key, "size")) -- size slider shows the size of the new shape
        elseif key == "trail" then
            for _, field in ipairs({ "size", "duration", "spacing" }) do
                Settings.NotifyUpdate(varName(key, field)) -- sliders show the values of the new shape
            end
            -- Energy locks color mode and color: the parent toggle and color mode report the change to their children
            Settings.NotifyUpdate(varName(key, "enabled"))
            Settings.NotifyUpdate(varName(key, "colorMode"))
            Settings.NotifyUpdate(varName(key, "colorCount"))
        end
    end
    local shape = Settings.RegisterProxySetting(category, varName(key, "shape"), Settings.VarType.String, L.shape,
        defaultOf(key, "shape"), function() return ns.cfg[key].shape end, setShape)
    child(track(Settings.CreateDropdown(category, shape, choiceList(choices), tip)))
end

local function dotOptions(category, key, child)
    shapeDropdown(category, key, child, L.dotShapeTip, {
        { "dot", L.shapeDot }, { "gap", L.shapeGap }, { "ring", L.shapeRing }, { "spark", L.shapeSpark },
        { "diamond", L.shapeDiamond }, { "arrow", L.shapeArrow }, { "crossdot", L.shapeCrossDot },
        { "doublering", L.shapeDoubleRing }, { "corners", L.shapeCorners }, { "hexagon", L.shapeHexagon },
    })

    -- GCD in the ring: only for the shape "ring" (the GCD ring is off then and its options are hidden)
    local function ringShape() return ns.cfg[key].shape == "ring" end
    local gcd = checkbox(category, key, "gcd", L.dotGcd, L.dotGcdTip)
    child(gcd)
    gcd:AddShownPredicate(ringShape)

    -- Click pulse: button and size are only usable while the pulse is active
    local pulse = checkbox(category, key, "pulse", L.pulse, L.pulseTip)
    child(pulse)
    local function whenPulse()
        return ns.cfg[key].enabled and ns.cfg[key].pulse
    end
    dropdown(category, key, "pulseButton", L.pulseButton, L.pulseButtonTip, {
        { "left", L.buttonLeft }, { "right", L.buttonRight }, { "both", L.buttonBoth },
    }):SetParentInitializer(pulse, whenPulse)
    slider(category, key, "pulseSize", L.pulseSize, L.pulseSizeTip, 1.5, 6, 0.5, function(v)
        return string.format("%.1fx", v)
    end):SetParentInitializer(pulse, whenPulse)
end

-- Pointer glow: a copy of the pointer while the game hides it and a pixel offset for the alignment.
local function glowOptions(category, key, child)
    child(checkbox(category, key, "showWhileLooking", L.glowLooking, L.glowLookingTip))
    child(slider(category, key, "offsetX", L.glowOffsetX, L.glowOffsetXTip, -20, 20, 1))
    child(slider(category, key, "offsetY", L.glowOffsetY, L.glowOffsetYTip, -20, 20, 1))
    child(slider(category, key, "leadFrames", L.glowLead, L.glowLeadTip, 0, 3, 0.1, function(v)
        return string.format("%.1f", v)
    end))
end

local function trailOptions(category, key, child)
    shapeDropdown(category, key, child, L.shapeTip, {
        { "dot", L.shapeDot }, { "leaf", L.shapeLeaf }, { "snow", L.shapeSnow }, { "star", L.shapeStar },
        { "mist", L.shapeMist }, { "energy", L.shapeEnergy }, { "flame", L.shapeFlame }, { "heart", L.shapeHeart },
        { "bubble", L.shapeBubble }, { "glitter", L.shapeGlitter }, { "blossom", L.shapeBlossom }, { "butterfly", L.shapeButterfly },
        { "ember", L.shapeEmber }, { "drop", L.shapeDrop }, { "feather", L.shapeFeather }, { "bolt", L.shapeBolt },
        { "crystal", L.shapeCrystal }, { "coin", L.shapeCoin }, { "rune", L.shapeRune }, { "confetti", L.shapeConfetti },
        { "pumpkin", L.shapePumpkin, function() return ns:ShapeAvailable("pumpkin") end },
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
    buildElement(category, layout, "main", L.main, { thickness = true, ringActive = true })
    buildElement(category, layout, "gcd", L.gcd, { thickness = true, track = true, ringActive = true, colors = "gradient" })
    buildElement(category, layout, "cast", L.cast, { thickness = true, track = true, ringActive = true, colors = "gradient" })
    buildElement(category, layout, "dot", L.dot, { extra = dotOptions, ringActive = true })
    buildElement(category, layout, "glow", L.glow, { size = false, noEnable = true, ringActive = true, extra = glowOptions, colors = "glow" })
    buildElement(category, layout, "trail", L.trail, { size = { 4, 64, 1 }, extra = trailOptions, colors = "trail" })

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
