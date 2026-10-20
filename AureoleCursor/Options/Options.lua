-- Aureole Cursor: settings in the Blizzard options UI (vertical layout, proxy settings).
-- Everything is on one page; sections (General, Colors, one per element) have headers
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
-- cfg.colors.combat. holder() gives the table that holds the value and the real name of the field in it.
local PALETTE_FIELDS = {
    classColor = true, color = true, color2 = true, color3 = true, color4 = true, gradient = true, blend = true,
    gradientDir = true, colorCount = true, colorMode = true,
}
local COMBAT_FIELDS = { combatTint = "enabled", combatTarget = "target", combatColor = "color" }

local function holder(root, key, field)
    if key == nil then
        if COMBAT_FIELDS[field] then return root.colors.combat, COMBAT_FIELDS[field] end
        return root, field
    end
    if PALETTE_FIELDS[field] then return root.colors.custom[key], field end
    return root[key], field
end

local function valueOf(key, field)
    local t, f = holder(ns.cfg, key, field)
    return t[f]
end

local function defaultOf(key, field)
    local t, f = holder(ns.defaults, key, field)
    return t[f]
end

local function varName(key, field)
    return string.upper("AUREOLECURSOR_" .. (key or "GENERAL") .. "_" .. field)
end

-- An option that depends on a setting somewhere else in the page (not its parent in the layout): it is evaluated again
-- whenever that setting reports a change.
local function dependsOn(initializer, variable, predicate)
    initializer:AddModifyPredicate(predicate)
    initializer:AddEvaluateStateCVar(variable)
    return initializer
end

-- Some options hang off a different setting than the one they really depend on (the Blizzard panel only re-evaluates
-- children of the setting that changed). After a change, tell that intermediate setting to refresh its children.
local function notifyDependents(key, field)
    if key == "trail" and field == "colorMode" then
        Settings.NotifyUpdate(varName(key, "colorCount")) -- the extra trail colors follow the color count
    elseif key == "cast" and field == "gradient" then
        Settings.NotifyUpdate(varName(key, "classColor")) -- the color row follows the class color switch
    end
end

-- Proxy setting: always reads from and writes to the current ns.cfg (which is replaced on reset).
local function proxy(category, key, field, vtype, label)
    local function get() return valueOf(key, field) end
    local function set(value)
        local t, f = holder(ns.cfg, key, field)
        t[f] = value
        ns:Apply()
        notifyDependents(key, field)
    end
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
        for _, choice in ipairs(choices) do c:Add(choice[1], choice[2]) end
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
        local col = valueOf(key, field)
        col[1], col[2], col[3] = c.r, c.g, c.b
        ns:Apply()
    end
    return Settings.RegisterProxySetting(category, varName(key, field), Settings.VarType.String, label,
        hexOf(defaultOf(key, field)), get, set)
end

local function colorSwatch(category, key, label, tip, field)
    return track(Settings.CreateColorSwatch(category, colorSetting(category, key, label, field), tip))
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

    slider(category, nil, "scale", L.scale, L.scaleTip, 0.5, 3, 0.05, twoDecimals)
    slider(category, nil, "alpha", L.alpha, L.alphaTip, 0.1, 1, 0.05, percent)
    slider(category, nil, "idleAlpha", L.idleAlpha, L.idleAlphaTip, 0, 1, 0.05, percent)
    slider(category, nil, "trackAlpha", L.trackAlpha, L.trackAlphaTip, 0.05, 1, 0.05, percent)
    checkbox(category, nil, "combatOnly", L.combatOnly, L.combatOnlyTip)
    checkbox(category, nil, "hideOnMouselook", L.hideOnMouselook, L.hideOnMouselookTip)
    dropdown(category, nil, "strata", L.strata, L.strataTip, STRATA)
end

-- Colors: all of them on one place, one group per element (plus the combat color). The groups of elements that are not in
-- use (see ns:RingActive) are hidden. They edit the palette "custom" (cfg.colors.custom).
local function colorGroup(layout, key, title, build)
    sectionItems = key and {} or nil
    header(layout, string.format(L.colorsFor, title))
    build()
    if sectionItems then
        for _, item in ipairs(sectionItems) do
            item:AddShownPredicate(function() return ns:RingActive(key) end)
        end
        sectionItems = nil
    end
end

-- Class color switch and the color swatch that is greyed out while it is on
local function simpleColor(category, layout, key)
    local class = checkbox(category, key, "classColor", L.classColor, L.classColorTip)
    colorSwatch(category, key, L.color, L.colorTip):SetParentInitializer(class, function()
        return not ns.cfg.colors.custom[key].classColor
    end)
end

local function buildColors(category, layout)
    local custom = function(key) return ns.cfg.colors.custom[key] end

    colorGroup(layout, "main", L.main, function() simpleColor(category, layout, "main") end)
    colorGroup(layout, "gcd", L.gcd, function() simpleColor(category, layout, "gcd") end)

    -- Cast Ring: the ring moves from color 1 to color 2 while the cast progresses. Class color is ignored then, so it
    -- hangs off the gradient switch. The color row shows one swatch, or two with a gradient; it hangs off the class color
    -- switch, changes of the gradient switch are reported to it through the proxy (see notifyDependents).
    colorGroup(layout, "cast", L.cast, function()
        local blend = checkbox(category, "cast", "gradient", L.castGradient, L.castGradientTip)
        local class = checkbox(category, "cast", "classColor", L.classColor, L.classColorTip)
        class:SetParentInitializer(blend, function() return not custom("cast").gradient end)
        colorRow(layout, L.colors, L.castColorsTip, colorEntries(category, "cast", 2), function() return custom("cast").gradient and 2 or 1 end)
            :SetParentInitializer(class, function()
                return custom("cast").gradient or not custom("cast").classColor
            end)
    end)

    colorGroup(layout, "dot", L.dot, function() simpleColor(category, layout, "dot") end)

    -- Pointer glow: one or two colors in one row like the custom colors of the trail. Class color replaces color 1.
    -- Two colors are blended (gradient) or shown as two halves, from top to bottom or from left to right.
    colorGroup(layout, "glow", L.glow, function()
        checkbox(category, "glow", "classColor", L.classColor, L.glowClassColorTip)
        local count = slider(category, "glow", "colorCount", L.colorCount, L.glowColorCountTip, 1, 2, 1)
        colorRow(layout, L.colors, L.glowColorsTip, colorEntries(category, "glow", 2), function() return custom("glow").colorCount end)
            :SetParentInitializer(count, function() return true end)
        local function two() return custom("glow").colorCount > 1 end
        checkbox(category, "glow", "blend", L.glowGradient, L.glowGradientTip):SetParentInitializer(count, two)
        dropdown(category, "glow", "gradientDir", L.glowDirection, L.glowDirectionTip, {
            { "vertical", L.dirVertical }, { "horizontal", L.dirHorizontal },
        }):SetParentInitializer(count, two)
    end)

    colorGroup(layout, nil, L.ghost, function() simpleColor(category, layout, "ghost") end)

    -- Mouse trail: color mode as a dropdown, the colors are only active for "Custom color": 1-4 colors, blended along the
    -- trail (gradient) or picked at random per dot. The colors share one row (ColorRow.xml) that hangs off the color count
    -- and shows as many swatches as the count says; the count itself reports changes of the color mode (see proxy).
    -- The energy shape has fixed original colors: color mode and colors are greyed out (it follows the shape setting).
    colorGroup(layout, nil, L.trail, function()
        local function colorable() return ns.cfg.trail.shape ~= "energy" end
        local function customMode() return colorable() and custom("trail").colorMode == "custom" end
        local modeDD = dropdown(category, "trail", "colorMode", L.colorMode, L.colorModeTip, {
            { "rainbow", L.modeRainbow }, { "class", L.modeClass }, { "spring", L.modeSpring }, { "summer", L.modeSummer }, { "autumn", L.modeAutumn },
            { "winter", L.modeWinter }, { "christmas", L.modeChristmas }, { "fire", L.modeFire }, { "love", L.modeLove },
            { "ocean", L.modeOcean }, { "gold", L.modeGold }, { "custom", L.modeCustom },
        })
        dependsOn(modeDD, varName("trail", "shape"), colorable)
        local count = slider(category, "trail", "colorCount", L.colorCount, L.colorCountTip, 1, 4, 1)
        count:SetParentInitializer(modeDD, customMode)
        colorRow(layout, L.colors, L.colorsTip, colorEntries(category, "trail", 4), function() return custom("trail").colorCount end)
            :SetParentInitializer(count, customMode)
        local blend = checkbox(category, "trail", "gradient", L.gradient, L.gradientTip)
        blend:SetParentInitializer(count, function()
            return customMode() and custom("trail").colorCount > 1
        end)
    end)

    -- Combat color: choose whether the Main Ring or the center dot switches to the combat color in combat
    colorGroup(layout, nil, L.combat, function()
        local tint = checkbox(category, nil, "combatTint", L.combatTint, L.combatTintTip)
        local function tintOn() return ns.cfg.colors.combat.enabled end
        -- With the pointer glow the glow always takes the combat color, so there is nothing to choose
        local target = dropdown(category, nil, "combatTarget", L.combatTarget, L.combatTargetTip, {
            { "main", L.main }, { "dot", L.targetDot },
        })
        target:SetParentInitializer(tint, tintOn)
        target:AddShownPredicate(function() return ns.cfg.mainStyle ~= "glow" end)
        colorSwatch(category, nil, L.combatColor, L.combatColorTip, "combatColor"):SetParentInitializer(tint, tintOn)
    end)
end

-- Section for one element; the options below are only active while "Show" is on. The colors are not here (see buildColors).
-- opts: size = { min, max, step } (false: no size slider), noEnable (no "Show" switch), thickness (ring thickness),
--       track (background track switch), ringActive (the whole section is hidden while ns:RingActive(key) is false),
--       extra = function(category, key, child) for element-specific options.
local function buildElement(category, layout, key, title, opts)
    sectionItems = opts.ringActive and {} or nil
    header(layout, title)
    -- opts.noEnable: the element has no switch of its own (the pointer glow follows the main style in General)
    local enable = not opts.noEnable and checkbox(category, key, "enabled", L.enabled, L[key .. "Tip"]) or nil
    local function child(initializer)
        if enable then initializer:SetParentInitializer(enable, function() return ns.cfg[key].enabled end) end
    end

    if opts.size ~= false then
        local size = opts.size or { 8, 400, 2 }
        child(slider(category, key, "size", L.size, L.sizeTip, size[1], size[2], size[3]))
    end
    if opts.thickness then
        child(slider(category, key, "thickness", L.thickness, L.thicknessTip, 1, ns.MAX_THICKNESS, 1))
    end
    if opts.extra then opts.extra(category, key, child) end
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
            -- Energy locks color mode and color (Colors): the color mode (it follows the shape) and the colors below it
            -- report the change to their children; the mode of the new shape is shown
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

-- Ghost: height above the cursor and the floating motion.
local function ghostOptions(category, key, child)
    child(slider(category, key, "height", L.ghostHeight, L.ghostHeightTip, -20, 60, 1))
    child(checkbox(category, key, "float", L.ghostFloat, L.ghostFloatTip))
end

local function trailOptions(category, key, child)
    shapeDropdown(category, key, child, L.shapeTip, {
        { "dot", L.shapeDot }, { "leaf", L.shapeLeaf }, { "snow", L.shapeSnow }, { "star", L.shapeStar },
        { "mist", L.shapeMist }, { "energy", L.shapeEnergy }, { "flame", L.shapeFlame }, { "heart", L.shapeHeart },
        { "bubble", L.shapeBubble }, { "glitter", L.shapeGlitter }, { "blossom", L.shapeBlossom }, { "butterfly", L.shapeButterfly },
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
    buildColors(category, layout)
    buildElement(category, layout, "main", L.main, { thickness = true, ringActive = true })
    buildElement(category, layout, "gcd", L.gcd, { thickness = true, track = true, ringActive = true })
    buildElement(category, layout, "cast", L.cast, { thickness = true, track = true, ringActive = true })
    buildElement(category, layout, "dot", L.dot, { extra = dotOptions, ringActive = true })
    buildElement(category, layout, "glow", L.glow, { size = false, noEnable = true, ringActive = true, extra = glowOptions })
    buildElement(category, layout, "ghost", L.ghost, { size = { 8, 128, 1 }, extra = ghostOptions })
    buildElement(category, layout, "trail", L.trail, { size = { 4, 64, 1 }, extra = trailOptions })

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
