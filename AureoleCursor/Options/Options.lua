-- Aureole Cursor: settings in the Blizzard options UI (vertical layout, proxy settings).
-- Everything is on one page; sections (General, one per ring, center dot) have headers
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

-- Some options hang off a different setting than the one they really depend on (the Blizzard panel only re-evaluates
-- children of the setting that changed). After a change, tell that intermediate setting to refresh its children.
local function notifyDependents(key, field)
    if key == "trail" and (field == "enabled" or field == "colorMode") then
        Settings.NotifyUpdate(varName(key, "colorCount")) -- the extra trail colors follow the color count
    elseif key == "cast" and (field == "enabled" or field == "gradient") then
        if field == "enabled" then Settings.NotifyUpdate(varName(key, "gradient")) end -- class color follows the gradient switch
        Settings.NotifyUpdate(varName(key, "classColor")) -- the color row follows the class color switch
    end
end

-- Proxy setting: always reads from and writes to the current ns.cfg (which is replaced on reset).
local function proxy(category, key, field, vtype, label)
    local function get() return section(key)[field] end
    local function set(value)
        section(key)[field] = value
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

-- Color swatch: the setting value is an ARGB hex string, the config holds {r, g, b, a}.
-- Opacity has its own slider, so a stays untouched when the color changes.
local function colorSetting(category, key, label, field)
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

local function colorRow(layout, name, tip, entries, count)
    local row = Settings.CreateElementInitializer("AureoleCursorColorRowTemplate", {
        name = name, tooltip = tip, entries = entries, count = count,
    })
    layout:AddInitializer(row)
    return track(row)
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
    return track(Settings.CreateSlider(category, s, options, tip))
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
    checkbox(category, nil, "combatOnly", L.combatOnly, L.combatOnlyTip)
    checkbox(category, nil, "hideOnMouselook", L.hideOnMouselook, L.hideOnMouselookTip)

    -- Combat color: choose whether the Main Ring or the center dot switches to the combat color in combat
    local tint = checkbox(category, nil, "combatTint", L.combatTint, L.combatTintTip)
    local function tintOn() return ns.cfg.combatTint end
    -- With the pointer glow the glow always takes the combat color, so there is nothing to choose
    local target = dropdown(category, nil, "combatTarget", L.combatTarget, L.combatTargetTip, {
        { "main", L.main }, { "dot", L.targetDot },
    })
    target:SetParentInitializer(tint, tintOn)
    target:AddShownPredicate(function() return ns.cfg.mainStyle ~= "glow" end)
    colorSwatch(category, nil, L.combatColor, L.combatColorTip, "combatColor"):SetParentInitializer(tint, tintOn)

    dropdown(category, nil, "strata", L.strata, L.strataTip, STRATA)
end

-- Section for one element; the options below are only active while "Show" is on.
-- opts: size = { min, max, step } (false: no size slider), noEnable (no "Show" switch), thickness (ring thickness), track (background track),
--       extra = function(category, key, child) for element-specific options.
local function buildElement(category, layout, key, title, opts)
    sectionItems = opts.ring and {} or nil
    header(layout, title)
    -- opts.noEnable: the element has no switch of its own (the pointer glow follows the main style in General)
    local enable = not opts.noEnable and checkbox(category, key, "enabled", L.enabled, L[key .. "Tip"]) or nil
    local function on() return opts.noEnable or ns.cfg[key].enabled end
    local function child(initializer)
        if enable then initializer:SetParentInitializer(enable, on) end
    end

    if opts.size ~= false then
        local size = opts.size or { 8, 400, 2 }
        child(slider(category, key, "size", L.size, L.sizeTip, size[1], size[2], size[3]))
    end
    if opts.thickness then
        child(slider(category, key, "thickness", L.thickness, L.thicknessTip, 1, ns.MAX_THICKNESS, 1))
    end
    if opts.extra then opts.extra(category, key, child) end
    if opts.colorMode then
        -- The energy shape has fixed original colors: color mode and color are greyed out
        local function colorable()
            return on() and ns.cfg[key].shape ~= "energy"
        end
        local function custom()
            return colorable() and ns.cfg[key].colorMode == "custom"
        end
        -- Color mode as a dropdown; the colors are only active for "Custom color"
        local modeDD = dropdown(category, key, "colorMode", L.colorMode, L.colorModeTip, {
            { "rainbow", L.modeRainbow }, { "class", L.modeClass }, { "autumn", L.modeAutumn },
            { "winter", L.modeWinter }, { "christmas", L.modeChristmas }, { "custom", L.modeCustom },
        })
        modeDD:SetParentInitializer(enable, colorable)
        -- Custom color: 1-4 colors, blended along the trail (gradient) or picked at random per dot.
        -- The colors share one row (ColorRow.xml) that hangs off the color count and shows as many swatches as the
        -- count says; the count itself reports changes of the enable switch and the color mode (see proxy).
        local count = slider(category, key, "colorCount", L.colorCount, L.colorCountTip, 1, 4, 1)
        count:SetParentInitializer(modeDD, custom)
        local entries = { colorEntry(category, key, "color", L.color) }
        for i = 2, 4 do entries[i] = colorEntry(category, key, "color" .. i, L["color" .. i]) end
        colorRow(layout, L.colors, L.colorsTip, entries, function() return ns.cfg[key].colorCount end)
            :SetParentInitializer(count, custom)
        local blend = checkbox(category, key, "gradient", L.gradient, L.gradientTip)
        blend:SetParentInitializer(count, function()
            return custom() and ns.cfg[key].colorCount > 1
        end)
    elseif opts.gradient then
        -- Gradient (cast ring): the ring moves from color 1 to color 2 while the cast progresses. Class color is
        -- ignored then, so it hangs off the gradient switch. The color row shows one swatch, or two with a gradient.
        -- The row hangs off the class color switch; changes of the enable and gradient switches are reported to
        -- it through the proxy (see notifyDependents).
        local blend = checkbox(category, key, "gradient", L.castGradient, L.castGradientTip)
        child(blend)
        local class = checkbox(category, key, "classColor", L.classColor, L.classColorTip)
        class:SetParentInitializer(blend, function()
            return on() and not ns.cfg[key].gradient
        end)
        local entries = { colorEntry(category, key, "color", L.color), colorEntry(category, key, "color2", L.color2) }
        colorRow(layout, L.colors, L.castColorsTip, entries, function() return ns.cfg[key].gradient and 2 or 1 end)
            :SetParentInitializer(class, function()
                return on() and (ns.cfg[key].gradient or not ns.cfg[key].classColor)
            end)
    else
        -- The color picker is greyed out while class color is active
        local class = checkbox(category, key, "classColor", L.classColor, L.classColorTip)
        child(class)
        local swatch = colorSwatch(category, key, L.color, L.colorTip)
        swatch:SetParentInitializer(class, function()
            return on() and not ns.cfg[key].classColor
        end)
    end
    child(opacitySlider(category, key, L.opacity, L.opacityTip))
    if opts.track then
        child(checkbox(category, key, "track", L.track, L.trackTip))
        child(slider(category, key, "trackAlpha", L.trackAlpha, L.trackAlphaTip, 0.05, 1, 0.05, percent))
    end
    if sectionItems then
        -- ring sections disappear completely when the ring layout does not use the ring; the panel
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
            section(key).shape = value
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
        defaultOf(key, "shape"), function() return section(key).shape end, setShape)
    child(track(Settings.CreateDropdown(category, shape, choiceList(choices), tip)))
end

local function dotOptions(category, key, child)
    shapeDropdown(category, key, child, L.dotShapeTip, {
        { "dot", L.shapeDot }, { "gap", L.shapeGap }, { "ring", L.shapeRing }, { "spark", L.shapeSpark },
    })

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

-- Pointer glow: pointer size (the game's own setting or fixed), a copy of the pointer while the game hides it and a pixel offset
-- for the alignment.
local function glowOptions(category, key, child)
    local sizes = { { "auto", L.cursorSizeAuto } }
    for _, px in ipairs({ 32, 48, 64, 96, 128 }) do
        sizes[#sizes + 1] = { tostring(px), px .. "x" .. px }
    end
    child(dropdown(category, key, "cursorSize", L.glowCursorSize, L.glowCursorSizeTip, sizes))
    child(checkbox(category, key, "showWhileLooking", L.glowLooking, L.glowLookingTip))
    child(slider(category, key, "offsetX", L.glowOffsetX, L.glowOffsetXTip, -20, 20, 1))
    child(slider(category, key, "offsetY", L.glowOffsetY, L.glowOffsetYTip, -20, 20, 1))
end

local function trailOptions(category, key, child)
    shapeDropdown(category, key, child, L.shapeTip, {
        { "dot", L.shapeDot }, { "leaf", L.shapeLeaf }, { "snow", L.shapeSnow }, { "star", L.shapeStar },
        { "mist", L.shapeMist }, { "energy", L.shapeEnergy },
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
    buildElement(category, layout, "main", L.main, { thickness = true, ring = true })
    buildElement(category, layout, "gcd", L.gcd, { thickness = true, track = true, ring = true })
    buildElement(category, layout, "cast", L.cast, { thickness = true, track = true, ring = true, gradient = true })
    buildElement(category, layout, "dot", L.dot, { extra = dotOptions, ring = true })
    buildElement(category, layout, "glow", L.glow, { size = false, noEnable = true, ring = true, extra = glowOptions })
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
