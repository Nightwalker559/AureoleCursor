-- Aureole Cursor: saved settings of older versions. ns:MigrateConfig(cfg) brings them up to date before the defaults are filled
-- in (Core.lua); every step only touches fields of the older layouts, so a current configuration passes through unchanged.
local _, ns = ...

local function rgb(c)
    return { c[1], c[2], c[3] }
end

-- Fields of an element that belong to the color palette, per element
local PALETTE_FIELDS = {
    main = { "classColor", "color" },
    gcd = { "classColor", "color" },
    cast = { "classColor", "color", "gradient", "color2" },
    dot = { "classColor", "color" },
    glow = { "classColor", "color", "colorCount", "blend", "gradientDir", "color2" },
    trail = { "colorMode", "color", "colorCount", "gradient", "color2", "color3", "color4" },
}

-- Config version 1 -> 2: every element held its own colors (with opacity as the 4th value), class color switches, track
-- opacities and so on. The colors move into cfg.colors.custom (RGB only), the opacity of the Main Ring (of the pointer glow
-- with that main style) goes into the overall opacity, and the track opacities become the single trackAlpha.
local function migrateColors(cfg)
    if (cfg.cfgVersion or 1) >= 2 then return end
    cfg.cfgVersion = 2

    -- overall opacity: what the leading element showed (its own opacity times the overall one)
    local lead = cfg.mainStyle == "glow" and cfg.glow or cfg.main
    local a = lead and type(lead.color) == "table" and lead.color[4]
    if a then
        local alpha = (cfg.alpha or 1) * a
        cfg.alpha = math.max(0.1, math.min(1, math.floor(alpha / 0.05 + 0.5) * 0.05))
    end
    -- one track opacity for all rings
    local cast, gcd = cfg.cast, cfg.gcd
    cfg.trackAlpha = (cast and cast.trackAlpha) or (gcd and gcd.trackAlpha) or cfg.trackAlpha

    local colors = cfg.colors or {}
    cfg.colors = colors
    colors.custom = colors.custom or {}
    for key, fields in pairs(PALETTE_FIELDS) do
        local element = cfg[key]
        if type(element) == "table" then
            local slot = colors.custom[key] or {}
            for _, field in ipairs(fields) do
                local v = element[field]
                if v ~= nil then
                    slot[field] = type(v) == "table" and rgb(v) or v
                    element[field] = nil
                end
            end
            colors.custom[key] = slot
        end
    end
    for _, key in ipairs({ "gcd", "cast" }) do
        if type(cfg[key]) == "table" then cfg[key].trackAlpha = nil end
    end
    if type(cfg.dot) == "table" then cfg.dot.gcdTrackAlpha = nil end

    -- combat color: it lived in top-level fields (1.0.x)
    if cfg.combatTint ~= nil or cfg.combatTarget ~= nil or cfg.combatColor ~= nil then
        colors.combat = colors.combat or {}
        colors.combat.enabled, colors.combat.target = cfg.combatTint, cfg.combatTarget
        colors.combat.color = cfg.combatColor and rgb(cfg.combatColor) or nil
        cfg.combatTint, cfg.combatTarget, cfg.combatColor = nil, nil, nil
    end
end

-- The class color switches (and the trail color mode "class") were replaced by the class theme: whoever used one gets that
-- theme, unless a theme was chosen already.
local function dropClassColors(cfg)
    local colors = cfg.colors
    local custom = type(colors) == "table" and colors.custom
    if type(custom) ~= "table" then return end
    local used = false
    for _, slot in pairs(custom) do
        if type(slot) == "table" then
            if slot.classColor then used = true end
            slot.classColor = nil
            if slot.colorMode == "class" then used, slot.colorMode = true, "rainbow" end
        end
    end
    local presets = type(cfg.trail) == "table" and cfg.trail.presets
    if type(presets) == "table" then
        for _, preset in pairs(presets) do
            if type(preset) == "table" and preset.colorMode == "class" then used, preset.colorMode = true, "rainbow" end
        end
    end
    if used and (colors.theme == nil or colors.theme == "custom") then colors.theme = "class" end
end

function ns:MigrateConfig(cfg)
    -- the combat color belonged to the Main Ring (1.0.1 and earlier), it is a general option
    local main = cfg.main
    if main then
        if main.combatTint ~= nil and cfg.combatTint == nil then
            cfg.combatTint, cfg.combatColor, cfg.combatTarget = main.combatTint, main.combatColor, "main"
        end
        main.combatTint, main.combatColor = nil, nil
    end
    migrateColors(cfg)
    dropClassColors(cfg)
    -- the ghost (a removed element): drop its settings, also its colors in configurations that were converted already
    cfg.ghost = nil
    if type(cfg.colors) == "table" and type(cfg.colors.custom) == "table" then cfg.colors.custom.ghost = nil end
end
