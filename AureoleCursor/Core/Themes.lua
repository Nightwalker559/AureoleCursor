-- Aureole Cursor: color themes. A theme is three colors; every element derives its colors from them, so a theme can fill the
-- same palette slots as the custom colors (cfg.colors.custom, see Core.lua): ns:Palette() returns the palette of the active
-- theme instead of the custom one. The themes are data of the addon, not of the saved settings, so they can be improved in
-- an update. Only the id of the chosen theme is saved (cfg.colors.theme, "custom" = the player's own colors).
local _, ns = ...

-- id, name (key in the locale) and three colors { r, g, b }: 1 = main color, 2 = second color, 3 = accent. core = the
-- color of the core of the line (setting trail.core), a light shade that suits the theme.
-- "class" and "faction" have no fixed colors, they come from the class color / the faction of the player (see classColors,
-- factionColors).
-- trailShape: the theme brings a trail shape that can only be used with it (see THEME_SHAPES).
ns.THEMES = {
    { id = "class", name = "themeClass" },
    { id = "faction", name = "themeFaction" },
    { id = "fire", name = "themeFire", { 1, 0.85, 0.2 }, { 1, 0.45, 0.08 }, { 0.85, 0.12, 0.05 }, core = { 1, 0.97, 0.75 } },
    { id = "ice", name = "themeIce", { 0.8, 0.95, 1 }, { 0.35, 0.7, 1 }, { 0.15, 0.4, 0.95 }, core = { 0.95, 1, 1 } },
    { id = "nature", name = "themeNature", { 0.75, 1, 0.5 }, { 0.3, 0.8, 0.35 }, { 0.95, 0.85, 0.3 }, core = { 0.95, 1, 0.85 } },
    { id = "arcane", name = "themeArcane", { 0.85, 0.55, 1 }, { 0.55, 0.3, 1 }, { 0.3, 0.75, 1 }, core = { 0.96, 0.88, 1 } },
    { id = "shadow", name = "themeShadow", { 0.75, 0.35, 0.95 }, { 0.45, 0.15, 0.6 }, { 0.95, 0.3, 0.6 }, core = { 1, 0.82, 0.95 } },
    { id = "void", name = "themeVoid", { 0.45, 0.3, 1 }, { 0.85, 0.2, 0.8 }, { 0.3, 0.9, 1 }, core = { 0.9, 0.88, 1 } },
    { id = "holy", name = "themeHoly", { 1, 0.95, 0.7 }, { 1, 0.8, 0.3 }, { 1, 1, 1 }, core = { 1, 1, 1 } },
    { id = "fel", name = "themeFel", { 0.55, 1, 0.1 }, { 0.2, 0.75, 0.15 }, { 0.65, 0.3, 0.9 }, core = { 0.9, 1, 0.7 } },
    { id = "blood", name = "themeBlood", { 0.9, 0.12, 0.15 }, { 0.6, 0.06, 0.1 }, { 1, 0.78, 0.3 }, core = { 1, 0.85, 0.8 } },
    { id = "aurora", name = "themeAurora", { 0.4, 1, 0.6 }, { 0.2, 0.85, 0.85 }, { 0.65, 0.4, 1 }, core = { 0.9, 1, 0.95 } },
    { id = "sunset", name = "themeSunset", { 1, 0.8, 0.4 }, { 1, 0.4, 0.5 }, { 0.6, 0.3, 0.8 }, core = { 1, 0.95, 0.82 } },
    { id = "silver", name = "themeSilver", { 1, 1, 1 }, { 0.7, 0.7, 0.75 }, { 0.45, 0.45, 0.5 }, core = { 1, 1, 1 } },
    { id = "lagoon", name = "themeLagoon", { 0.25, 0.9, 0.8 }, { 0.15, 0.55, 0.95 }, { 0.45, 0.35, 1 }, core = { 0.85, 1, 0.97 } },
    { id = "halloween", name = "themeHalloween", { 1, 0.55, 0.1 }, { 0.9, 0.3, 0.05 }, { 0.6, 0.3, 0.9 }, core = { 1, 0.9, 0.5 }, trailShape = "pumpkin" },
    { id = "anniversary", name = "themeAnniversary", { 0.5, 0.65, 1 }, { 1, 0.6, 0.2 }, { 0.25, 0.4, 0.9 }, core = { 1, 0.95, 0.8 }, trailShape = "balloon" },
}

-- Trail shapes that belong to a theme: shape = id of the theme. They are in the shape list only while that theme is active,
-- the theme selects its shape when it is chosen, and the shape goes back to the earlier one when the theme is left.
ns.THEME_SHAPES = { pumpkin = "halloween", balloon = "anniversary" }

local byId = {}
for _, theme in ipairs(ns.THEMES) do byId[theme.id] = theme end

-- The class theme: the class color, a darker shade (color 2) and a lighter one (color 3, the accent).
local function classColors()
    local _, class = UnitClass("player")
    local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
    local r, g, b = 1, 1, 1
    if c then r, g, b = c.r, c.g, c.b end
    return { r, g, b }, { r * 0.6, g * 0.6, b * 0.6 }, { r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5 }
end

-- The faction theme: blue and gold for the Alliance, red and amber for the Horde, gold for a player who has not chosen yet.
local FACTIONS = {
    Alliance = { { 0.3, 0.55, 1 }, { 0.15, 0.3, 0.8 }, { 1, 0.82, 0.3 } },
    Horde = { { 0.9, 0.15, 0.1 }, { 0.55, 0.05, 0.05 }, { 1, 0.65, 0.25 } },
}
local NEUTRAL = { { 1, 0.82, 0.3 }, { 0.7, 0.6, 0.35 }, { 1, 1, 1 } }

local function factionColors()
    local f = FACTIONS[UnitFactionGroup("player")] or NEUTRAL
    return f[1], f[2], f[3]
end

-- The palette of a theme, in the form of cfg.colors.custom (every field the settings page shows is there): the Main Ring and
-- the center dot are plain colors (main color, accent), the GCD Ring runs from color 1 to 2 and the Cast Ring from 1 to 3 over
-- its time, the pointer glow blends from 1 (top) to 2, the trail runs through all three. nil for an unknown id.
function ns:ThemePalette(id)
    local theme = byId[id]
    if not theme then return nil end
    local c1, c2, c3
    if id == "class" then c1, c2, c3 = classColors()
    elseif id == "faction" then c1, c2, c3 = factionColors()
    else c1, c2, c3 = theme[1], theme[2], theme[3] end
    -- core of the line: the theme's own light color, the dynamic themes (and a theme without one) take the main color mostly white
    local core = theme.core or { c1[1] + (1 - c1[1]) * 0.75, c1[2] + (1 - c1[2]) * 0.75, c1[3] + (1 - c1[3]) * 0.75 }
    return {
        main = { color = c1 },
        gcd = { color = c1, gradient = true, color2 = c2 },
        cast = { color = c1, gradient = true, color2 = c3 },
        dot = { color = c3 },
        glow = { color = c1, color2 = c2, colorCount = 2, blend = true, gradientDir = "vertical" },
        trail = { colorMode = "custom", color = c1, color2 = c2, color3 = c3, color4 = c3, colorCount = 3, gradient = true,
                  coreColor = { core[1], core[2], core[3] } },
    }
end

local function copyValue(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copyValue(x) end
    return t
end

-- The trail shape the active theme brings (and locks the shape setting to), nil for themes without one.
function ns:ThemeShape()
    local theme = byId[self.cfg.colors.theme]
    return theme and theme.trailShape
end

-- Can this trail shape be used with the theme in use? (Shapes without a theme always can.)
function ns:ShapeAvailable(shape)
    local theme = ns.THEME_SHAPES[shape]
    return theme == nil or self.cfg.colors.theme == theme
end

-- A theme-only shape without its theme goes back to the shape from before (or the plain dot).
function ns:FixThemeShape()
    local trail = self.cfg.trail
    if self:ShapeAvailable(trail.shape) then return end
    local before = trail.shapeBefore
    trail.shapeBefore = nil
    self:SetTrailShape(before and self:ShapeAvailable(before) and before or "dot")
end

-- Choose a theme ("custom" = own colors). A theme with a trail shape of its own switches the trail to it and remembers the
-- shape it replaced; leaving the theme brings that shape back.
function ns:SetTheme(id)
    local cfg = self.cfg
    cfg.colors.theme = id
    local theme = byId[id]
    local shape = theme and theme.trailShape
    if shape and cfg.trail.shape ~= shape then
        -- from one themed shape to another the shape from before stays the one remembered
        if not ns.THEME_SHAPES[cfg.trail.shape] then cfg.trail.shapeBefore = cfg.trail.shape end
        self:SetTrailShape(shape)
    end
    self:FixThemeShape()
end

-- Take over the colors of the active theme as the player's own colors and switch to them, so a theme can be adjusted.
function ns:UseThemeAsCustom()
    local colors = self.cfg.colors
    local palette = colors.theme ~= "custom" and self:ThemePalette(colors.theme)
    if not palette then return end
    for key, slot in pairs(palette) do
        local custom = colors.custom[key]
        for field, value in pairs(slot) do custom[field] = copyValue(value) end
    end
    self:SetTheme("custom")
    self:Apply()
end
