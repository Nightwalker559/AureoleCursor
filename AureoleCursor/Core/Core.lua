-- Aureole Cursor: core. Namespace, settings (with defaults), event dispatcher, modules, slash commands.
local ADDON, ns = ...

ns.modules = {}
ns.inCombat = false

-- Config version: 1 = up to 1.0.x (colors and opacity inside every element), 2 = colors in cfg.colors, one overall opacity
ns.CFG_VERSION = 2

ns.defaults = {
    cfgVersion = ns.CFG_VERSION,
    scale = 1.0,
    alpha = 0.8,              -- the only opacity setting: overall opacity of everything at the cursor
    strata = "TOOLTIP",
    combatOnly = false,
    idleAlpha = 1.0,          -- share of the opacity applied out of combat
    hideOnMouselook = false,  -- hide while the camera is being turned with the mouse
    ringLayout = "individual", -- "individual" (every ring on its own), "maincast" (Main + Cast Ring) or "maingcd" (Main + GCD Ring)
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
    main = { enabled = true, size = 40, thickness = 6 },
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
              } },
}

-- Ring thickness in levels 1..8 (percent of the radius, see make_media.py in the tools folder)
ns.MAX_THICKNESS = 8
local MEDIA = "Interface\\AddOns\\AureoleCursor\\Media\\"

-- Textures exist in several resolutions so that shrunken rings do not turn pixelated.
-- The choice depends on the size in screen pixels (see ns:ScreenPixels).
local RING_RES = { { 80, 64 }, { 160, 128 }, { math.huge, 256 } } -- { up to pixels, texture resolution }
local DOT_RES = { { 20, 16 }, { 40, 32 }, { math.huge, 64 } }

local function pickResolution(list, pixels)
    for _, r in ipairs(list) do
        if pixels <= r[1] then return r[2] end
    end
end

-- Size of an element in real screen pixels (UI scale and resolution included).
function ns:ScreenPixels(size)
    local scale = self.anchor and self.anchor:GetEffectiveScale() or 1
    local height = 768
    if GetPhysicalScreenSize then
        local _, h = GetPhysicalScreenSize()
        if h and h > 0 then height = h end
    end
    return size * scale * height / 768
end

function ns:RingTexture(level, size)
    level = math.max(1, math.min(ns.MAX_THICKNESS, math.floor(level or 4)))
    return MEDIA .. "Rings\\Ring" .. level .. "_" .. pickResolution(RING_RES, self:ScreenPixels(size or 40)) .. ".png"
end

function ns:DotTexture(size)
    return MEDIA .. "Dot\\Dot_" .. pickResolution(DOT_RES, self:ScreenPixels(size or 8)) .. ".png"
end

-- Texture file per shape of the mouse trail and of the center dot ("dot" is the plain dot, "energy" a texture of the game).
-- The files exist in several resolutions (see ns:ShapeTexture); linecore is the core of the line.
local SHAPE_RES = { { 30, 32 }, { 60, 64 }, { math.huge, 128 } }
local SHAPE_FILE = { leaf = "Trail\\Leaf", snow = "Trail\\Snow", star = "Trail\\Star", mist = "Trail\\Mist",
    flame = "Trail\\Flame", heart = "Trail\\Heart", bubble = "Trail\\Bubble", glitter = "Trail\\Glitter",
    blossom = "Trail\\Blossom", butterfly = "Trail\\Butterfly", ember = "Trail\\Ember", drop = "Trail\\Drop",
    feather = "Trail\\Feather", bolt = "Trail\\Bolt", crystal = "Trail\\Crystal", coin = "Trail\\Coin",
    rune = "Trail\\Rune", confetti = "Trail\\Confetti", line = "Trail\\Line", linecore = "Trail\\LineCore", pumpkin = "Trail\\Pumpkin", balloon = "Trail\\Balloon",
    gap = "Dot\\Gap", ring = "Dot\\DotRing", spark = "Dot\\Spark", diamond = "Dot\\Diamond", arrow = "Dot\\Arrow",
    crossdot = "Dot\\CrossDot", doublering = "Dot\\DoubleRing", corners = "Dot\\Corners", hexagon = "Dot\\Hexagon" }

-- "Energy": Blizzard texture from the game (FileID, not shipped with the addon), seamless tile with alpha channel.
ns.ENERGY_FILE_ID = 6735695
-- Soft round mask, cuts a round dot out of the tile.
ns.TRAIL_MASK = MEDIA .. "Trail\\Mask_64.png"

function ns:ShapeTexture(shape, size)
    if shape == "energy" then return self.ENERGY_FILE_ID end
    local file = SHAPE_FILE[shape]
    if not file then return self:DotTexture(size) end
    return MEDIA .. file .. "_" .. pickResolution(SHAPE_RES, self:ScreenPixels(size or 16)) .. ".png"
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

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
    self.modules[#self.modules + 1] = m
end

function ns:Apply()
    for _, m in ipairs(self.modules) do
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
    for _, m in ipairs(self.modules) do
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

-- Config version 1 -> 2: every element held its own colors (with opacity as the 4th value), class color switches, track
-- opacities and so on. The colors move into cfg.colors.custom (RGB only), the opacity of the Main Ring (of the pointer glow
-- with that main style) goes into the overall opacity, and the track opacities become the single trackAlpha.
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

    -- combat color: top-level fields up to 1.0.x
    if cfg.combatTint ~= nil or cfg.combatTarget ~= nil or cfg.combatColor ~= nil then
        colors.combat = colors.combat or {}
        colors.combat.enabled, colors.combat.target = cfg.combatTint, cfg.combatTarget
        colors.combat.color = cfg.combatColor and rgb(cfg.combatColor) or nil
        cfg.combatTint, cfg.combatTarget, cfg.combatColor = nil, nil, nil
    end
end

-- The class color switches (and the trail color mode "class") are gone: the class color is a theme now. Whoever used one
-- gets that theme, unless a theme was chosen already.
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

ns:On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    AureoleCursorDB = AureoleCursorDB or {}
    local db = AureoleCursorDB
    db.cfg = db.cfg or {}
    local main = db.cfg.main
    if main then
        -- up to 1.0.1 the combat color belonged to the Main Ring; it is a general option now
        if main.combatTint ~= nil and db.cfg.combatTint == nil then
            db.cfg.combatTint, db.cfg.combatColor, db.cfg.combatTarget = main.combatTint, main.combatColor, "main"
        end
        main.combatTint, main.combatColor = nil, nil
    end
    migrateColors(db.cfg)
    dropClassColors(db.cfg)
    -- the ghost was removed in 1.1.0: drop its settings (also its colors, in configs that were already converted)
    db.cfg.ghost = nil
    if type(db.cfg.colors) == "table" and type(db.cfg.colors.custom) == "table" then db.cfg.colors.custom.ghost = nil end
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

------------------------------------------------------------------------
-- Slash commands (the settings page is the main UI; these are shortcuts)
------------------------------------------------------------------------

local L = ns.L
local PREFIX = "|cff66ccffAureole Cursor|r "
local RINGS = { main = true, gcd = true, cast = true, dot = true, trail = true }
-- Limits of the shortcuts: the same ranges as the sliders on the settings page (Options.lua)
local MIN_SCALE, MAX_SCALE, MIN_ALPHA = 0.5, 3, 0.1
local SIZE_LIMITS = { trail = { 4, 64 } }
local DEFAULT_SIZE_LIMITS = { 8, 400 }

local function say(...)
    print(PREFIX .. string.format(...))
end

local function onOff(s)
    if s == "on" then return true end
    if s == "off" then return false end
end

SLASH_AUREOLECURSOR1 = "/aureole"
SLASH_AUREOLECURSOR2 = "/aureolecursor"
SLASH_AUREOLECURSOR3 = "/ac"
SlashCmdList["AUREOLECURSOR"] = function(msg)
    local cfg = ns.cfg
    if not cfg then return end
    local args = {}
    for w in string.gmatch(strlower(msg or ""), "%S+") do args[#args + 1] = w end
    local cmd = args[1]

    if cmd == "scale" and tonumber(args[2]) then
        cfg.scale = math.max(MIN_SCALE, math.min(MAX_SCALE, tonumber(args[2])))
        ns:Apply()
    elseif cmd == "alpha" and tonumber(args[2]) then
        cfg.alpha = math.max(MIN_ALPHA, math.min(1, tonumber(args[2])))
        ns:Apply()
    elseif cmd == "combat" and onOff(args[2]) ~= nil then
        cfg.combatOnly = onOff(args[2])
        ns:Apply()
    elseif cmd == "ring" and RINGS[args[2]] then
        local ring = cfg[args[2]]
        if onOff(args[3]) ~= nil then
            ring.enabled = onOff(args[3])
        elseif args[3] == "size" and tonumber(args[4]) then
            local limits = SIZE_LIMITS[args[2]] or DEFAULT_SIZE_LIMITS
            ring.size = math.max(limits[1], math.min(limits[2], tonumber(args[4])))
        else
            say(L.slashRingUsage, args[2])
            return
        end
        ns:Apply()
    elseif cmd == nil or cmd == "config" or cmd == "options" then
        -- without arguments, open the settings directly (shortcut: /ac)
        if ns.OpenSettings then ns:OpenSettings() end
        return
    elseif cmd == "reset" then
        ns:ResetSettings()
        say(L.slashReset)
        return
    else
        say(L.slashStatus, cfg.scale, cfg.alpha, cfg.combatOnly and L.yes or L.no)
        for _, name in ipairs({ "main", "gcd", "cast", "dot", "trail" }) do
            say(L.slashElement, name, cfg[name].enabled and L.stateOn or L.stateOff, cfg[name].size)
        end
        say(L.slashHelp)
    end
end
