-- Aureole Cursor: color themes. A theme is three colors; every element derives its colors from them, so a theme can fill the
-- same palette slots as the custom colors (cfg.colors.custom, see Core.lua): ns:Palette() returns the palette of the active
-- theme instead of the custom one. The themes are data of the addon, not of the saved settings, so they can be improved in
-- an update. Only the id of the chosen theme is saved (cfg.colors.theme, "custom" = the player's own colors).
local _, ns = ...

-- id, name (key in the locale) and three colors { r, g, b }: 1 = main color, 2 = second color, 3 = accent.
-- "class" has no fixed colors, they come from the class color of the player (see classColors).
ns.THEMES = {
    { id = "class", name = "themeClass" },
    { id = "fire", name = "themeFire", { 1, 0.85, 0.2 }, { 1, 0.45, 0.08 }, { 0.85, 0.12, 0.05 } },
    { id = "ice", name = "themeIce", { 0.8, 0.95, 1 }, { 0.35, 0.7, 1 }, { 0.15, 0.4, 0.95 } },
    { id = "nature", name = "themeNature", { 0.75, 1, 0.5 }, { 0.3, 0.8, 0.35 }, { 0.95, 0.85, 0.3 } },
    { id = "arcane", name = "themeArcane", { 0.85, 0.55, 1 }, { 0.55, 0.3, 1 }, { 0.3, 0.75, 1 } },
    { id = "shadow", name = "themeShadow", { 0.75, 0.35, 0.95 }, { 0.45, 0.15, 0.6 }, { 0.95, 0.3, 0.6 } },
    { id = "holy", name = "themeHoly", { 1, 0.95, 0.7 }, { 1, 0.8, 0.3 }, { 1, 1, 1 } },
    { id = "sunset", name = "themeSunset", { 1, 0.8, 0.4 }, { 1, 0.4, 0.5 }, { 0.6, 0.3, 0.8 } },
    { id = "silver", name = "themeSilver", { 1, 1, 1 }, { 0.7, 0.7, 0.75 }, { 0.45, 0.45, 0.5 } },
}

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

-- The palette of a theme, in the form of cfg.colors.custom (every field the settings page shows is there): the Main Ring and
-- the center dot are plain colors (main color, accent), the GCD Ring runs from color 1 to 2 and the Cast Ring from 1 to 3 over
-- its time, the pointer glow blends from 1 (top) to 2, the trail runs through all three. nil for an unknown id.
function ns:ThemePalette(id)
    local theme = byId[id]
    if not theme then return nil end
    local c1, c2, c3
    if id == "class" then c1, c2, c3 = classColors() else c1, c2, c3 = theme[1], theme[2], theme[3] end
    return {
        main = { color = c1 },
        gcd = { color = c1, gradient = true, color2 = c2 },
        cast = { color = c1, gradient = true, color2 = c3 },
        dot = { color = c3 },
        glow = { color = c1, color2 = c2, colorCount = 2, blend = true, gradientDir = "vertical" },
        trail = { colorMode = "custom", color = c1, color2 = c2, color3 = c3, color4 = c3, colorCount = 3, gradient = true },
    }
end

local function copyValue(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copyValue(x) end
    return t
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
    colors.theme = "custom"
    self:Apply()
end
