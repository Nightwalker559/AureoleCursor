-- Aureole Cursor: core. Namespace, settings (with defaults), modules, shared state, event dispatcher, loading of the saved settings.
local ADDON, ns = ...

local modules = {}
ns.inCombat = false

-- Version of the saved settings: 1 = colors and opacity inside every element (1.0.x), 2 = colors in cfg.colors, one overall
-- opacity (the step from 1 to 2 is in Migrate.lua)
local CFG_VERSION = 2

ns.defaults = {
    cfgVersion = CFG_VERSION,
    scale = 1.0,
    alpha = 0.8,              -- the only opacity setting: overall opacity of everything at the cursor
    strata = "TOOLTIP",
    combatOnly = false,
    idleAlpha = 1.0,          -- share of the opacity applied out of combat
    hideOnMouselook = false,  -- hide while the camera is being turned with the mouse
    ringLayout = "individual", -- "individual" (every ring on its own), "maincast" (Main + Cast Ring) or "maingcd" (Main + GCD Ring)
    ringStyle = "solid",      -- line style of the three rings: "solid", "dash", "dots", "ticks" or "segments" (see RING_STYLES)
    mainStyle = "ring",       -- what surrounds the cursor: the Main Ring ("ring") or the pointer glow ("glow")
    trackAlpha = 0.5,         -- opacity of the background tracks of the GCD and Cast Ring (and of the ring of the center dot)
    -- All colors live here. The elements read them through ns:Palette(): the custom colors below, or the colors of a theme
    -- (Themes.lua) while one is chosen. Colors are plain { r, g, b }, the opacity is the overall one (alpha).
    colors = {
        theme = "custom",         -- "custom" = the colors below, otherwise the id of a theme (ns.THEMES), which then replaces them
        -- combat color: in combat target ("main" ring or center "dot") switches to color; with the pointer glow the glow always switches
        combat = { enabled = false, target = "main", color = { 1, 0.1, 0.1 } },
        custom = {
            main = { color = { 1, 1, 1 } },
            -- gradient (GCD and Cast Ring): the swipe color moves from color to color2 while the GCD runs or the cast progresses
            gcd = { color = { 1, 0.82, 0 }, gradient = false, color2 = { 1, 0.45, 0.1 } },
            cast = { color = { 1, 1, 1 }, gradient = false, color2 = { 0.3, 0.8, 1 } },
            dot = { color = { 1, 1, 1 } },
            -- one color or two (colorCount, color and color2) from top to bottom ("vertical") or left to right ("horizontal"):
            -- blend = smooth gradient, otherwise two hard halves
            glow = { color = { 0.35, 0.7, 1 }, colorCount = 1, blend = true, gradientDir = "vertical",
                     color2 = { 0.75, 0.3, 1 } },
            -- colorMode "custom": colorCount colors (color, color2..color4); gradient blends between them along the
            -- trail, otherwise every dot picks one of them at random
            trail = { colorMode = "rainbow", color = { 1, 1, 1 }, colorCount = 1, gradient = true,
                      color2 = { 0.3, 0.6, 1 }, color3 = { 0.8, 0.3, 1 }, color4 = { 1, 0.4, 0.3 },
                      coreColor = { 1, 1, 1 } }, -- coreColor: color of the core of the line (setting trail.core)
        },
    },
    -- wave: a click sends a thin ring out from the Main Ring and fades it (waveButton: "left", "right" or "both")
    main = { enabled = true, size = 40, thickness = 6, wave = false, waveButton = "both" },
    gcd  = { enabled = true, size = 28, thickness = 6, track = true },
    cast = { enabled = true, size = 54, thickness = 6, track = true },
    dot  = { enabled = true, size = 10, shape = "dot", sizes = { dot = 10, gap = 22, ring = 24, spark = 24, diamond = 14, arrow = 16, crossdot = 22, doublering = 26, corners = 26, hexagon = 24 }, pulse = true, pulseButton = "both", pulseSize = 4,
             -- gcd: with the shape "ring" the GCD runs as progress in the ring of the dot (the GCD ring is off then)
             gcd = false },
    -- glow: halo in the shape of the game's mouse pointer, replaces the rings (see mainStyle) and follows the game's cursor size;
    -- showWhileLooking draws a copy of the pointer while the game hides it (right mouse button, mouselook);
    -- offsetX/offsetY (screen pixels) fine-tune the alignment with the pointer;
    -- leadFrames places the glow ahead along the mouse movement (movement of the last frame times this), to make up for the
    -- pointer being drawn later
    -- look: "halo" (soft glow), "border" (crisp frame right at the pointer's edge) or "both"; borderWidth: 1 to 4
    glow = { look = "halo", borderWidth = 2, showWhileLooking = true, offsetX = 0, offsetY = 0, leadFrames = 1 },
    -- presets: default size, duration and spacing per shape (and a color mode for the themed shapes); on a shape change the
    -- current values (including the color mode, which lives in colors.custom.trail) are remembered for the old shape and the
    -- remembered ones (initially these defaults) are applied for the new shape.
    -- core: the line (shape "line") gets a smaller copy of every dot in the middle in its own color (colors.custom.trail.coreColor)
    trail = { enabled = true, size = 16, duration = 0.45, spacing = 6, shrink = true, shape = "dot", core = true,
              presets = {
                  dot = { size = 16, duration = 0.45, spacing = 6 },
                  leaf = { size = 20, duration = 0.9, spacing = 22 },
                  snow = { size = 18, duration = 0.9, spacing = 16 },
                  star = { size = 18, duration = 0.7, spacing = 14 },
                  mist = { size = 14, duration = 1.0, spacing = 5 },
                  energy = { size = 28, duration = 0.55, spacing = 5 },
                  flame = { size = 22, duration = 0.6, spacing = 7, colorMode = "fire" },
                  heart = { size = 20, duration = 1.0, spacing = 18, colorMode = "love" },
                  bubble = { size = 22, duration = 1.2, spacing = 14, colorMode = "ocean" },
                  glitter = { size = 16, duration = 0.7, spacing = 8, colorMode = "gold" },
                  blossom = { size = 20, duration = 1.0, spacing = 18, colorMode = "spring" },
                  butterfly = { size = 24, duration = 1.1, spacing = 22, colorMode = "summer" },
                  ember = { size = 12, duration = 0.9, spacing = 8, colorMode = "fire" },
                  drop = { size = 16, duration = 0.8, spacing = 16, colorMode = "ocean" },
                  feather = { size = 22, duration = 1.3, spacing = 22, colorMode = "spring" },
                  bolt = { size = 20, duration = 0.4, spacing = 16, colorMode = "storm" },
                  crystal = { size = 18, duration = 0.9, spacing = 16, colorMode = "winter" },
                  coin = { size = 18, duration = 0.9, spacing = 20, colorMode = "gold" },
                  rune = { size = 24, duration = 1.0, spacing = 22, colorMode = "arcane" },
                  confetti = { size = 12, duration = 0.9, spacing = 10, colorMode = "rainbow" },
                  line = { size = 22, duration = 0.5, spacing = 3, colorMode = "rainbow" },
                  pumpkin = { size = 22, duration = 1.0, spacing = 22 },
                  balloon = { size = 22, duration = 1.2, spacing = 24 },
                  paw = { size = 20, duration = 1.4, spacing = 26 },
                  bat = { size = 24, duration = 1.1, spacing = 22, colorMode = "arcane" },
                  smoke = { size = 18, duration = 1.0, spacing = 10, colorMode = "custom" },
                  ripple = { size = 14, duration = 0.9, spacing = 18, colorMode = "ocean" },
              } },
}

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end
ns.Copy = copy

-- Fill missing keys from the defaults, never touch existing values.
local function fillDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = copy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            fillDefaults(dst[k], v)
        end
    end
end

function ns:RegisterModule(m)
    modules[#modules + 1] = m
end

function ns:Apply()
    for _, m in ipairs(modules) do
        if m.Apply then m:Apply() end
    end
end

-- Is this element in use? The settings of an element that is off stay untouched, its options are hidden.
-- Main style (General): the rings (with the center dot) and the pointer glow take turns. With "glow" there are no rings at all
-- (Main, GCD and Cast Ring and the center dot are off, the ring layout is hidden), with "ring" the glow is off.
-- Ring layout (General): "individual" = every ring has its own switch, "maincast" / "maingcd" = Main Ring plus only
-- the Cast or only the GCD ring.
function ns:RingActive(key)
    local layout = self.cfg.ringLayout
    local glow = self.cfg.mainStyle == "glow"
    if key == "glow" then return glow end
    if glow then return false end
    if key == "gcd" then return layout ~= "maincast" and not self:GcdOnDot() end
    if key == "cast" then return layout ~= "maingcd" end
    return true
end

-- Does the GCD run in the ring of the center dot (shape "ring") instead of on its own GCD ring? Then the GCD ring is off
-- and its options are hidden; the color comes from the center dot.
function ns:GcdOnDot()
    local dot = self.cfg.dot
    return dot.gcd and dot.enabled and dot.shape == "ring" and self.cfg.mainStyle ~= "glow" or false
end

function ns:UpdateVisibility()
    for _, m in ipairs(modules) do
        if m.UpdateVisibility then m:UpdateVisibility() end
    end
end

-- The colors in use: { main, gcd, cast, dot, glow, trail }, each with its color fields (see defaults.colors.custom): the
-- palette of the chosen theme (Themes.lua), or the custom colors. Everything that needs a color asks here, never cfg.colors
-- directly. The tables of a theme are only read, never changed.
function ns:Palette()
    local colors = self.cfg.colors
    if colors.theme ~= "custom" then
        local palette = self:ThemePalette(colors.theme)
        if palette then return palette end
    end
    return colors.custom
end

-- Color of the Main Ring, the center dot or the pointer glow ("main" / "dot" / "glow"): its own color, or the combat color
-- while in combat if the combat color (Colors) is switched on for that element (the pointer glow always follows it, the
-- target setting only chooses between Main Ring and center dot).
function ns:ElementColor(key)
    local combat = self.cfg.colors.combat
    if combat.enabled and (key == "glow" or combat.target == key) and self.inCombat then
        local c = combat.color
        return c[1], c[2], c[3]
    end
    return self:GetRingColor(self:Palette()[key])
end

-- Overall opacity: base value, multiplied by idleAlpha out of combat, 0 while mouselooking if configured.
function ns:CurrentAlpha()
    local cfg = self.cfg
    if cfg.hideOnMouselook and self.mouselooking then return 0 end
    local a = cfg.alpha
    if not self.inCombat then a = a * cfg.idleAlpha end
    return a
end

function ns:UpdateAlpha()
    local a = self:CurrentAlpha()
    self.anchor:SetAlpha(a)
    if self.trailFrame then self.trailFrame:SetAlpha(a) end
    if self.UpdatePointerIcon then self.UpdatePointerIcon() end -- the pointer copy ignores the anchor's alpha
end

function ns:ResetSettings()
    AureoleCursorDB.cfg = copy(self.defaults)
    self.cfg = AureoleCursorDB.cfg
    self:Apply()
end

-- Color of a palette entry (r, g, b); a gradient ring starts with it.
function ns:GetRingColor(slot)
    local col = slot.color
    return col[1], col[2], col[3]
end

------------------------------------------------------------------------
-- Event dispatcher: ns:On(event, fn [, unit]); with unit, RegisterUnitEvent is used.
------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

function ns:On(event, fn, unit)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        if unit then frame:RegisterUnitEvent(event, unit) else frame:RegisterEvent(event) end
    end
    list[#list + 1] = fn
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if list then
        for i = 1, #list do list[i](event, ...) end
    end
end)

ns:On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    AureoleCursorDB = AureoleCursorDB or {}
    local db = AureoleCursorDB
    db.cfg = db.cfg or {}
    ns:MigrateConfig(db.cfg)
    fillDefaults(db.cfg, ns.defaults)
    ns.cfg = db.cfg
    ns:FixThemeShape() -- a shape that belongs to a theme is only kept while that theme is on
end)

ns:On("PLAYER_ENTERING_WORLD", function()
    ns.inCombat = InCombatLockdown() and true or false
    ns:Apply()
end)

-- If the pixel size changes (UI scale, resolution), the texture resolutions and sizes have to be recalculated.
local function reapply()
    if ns.cfg then ns:Apply() end
end
ns:On("UI_SCALE_CHANGED", reapply)
ns:On("DISPLAY_SIZE_CHANGED", reapply)

ns:On("PLAYER_REGEN_DISABLED", function()
    ns.inCombat = true
    ns:UpdateVisibility()
end)

ns:On("PLAYER_REGEN_ENABLED", function()
    ns.inCombat = false
    ns:UpdateVisibility()
end)
