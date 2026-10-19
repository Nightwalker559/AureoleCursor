-- Aureole Cursor: core. Namespace, settings (with defaults), event dispatcher, modules, slash commands.
local ADDON, ns = ...

ns.modules = {}
ns.inCombat = false

ns.defaults = {
    scale = 1.0,
    alpha = 1.0,
    strata = "TOOLTIP",
    combatOnly = false,
    idleAlpha = 1.0,          -- share of the opacity applied out of combat
    hideOnMouselook = false,  -- hide while the camera is being turned with the mouse
    ringLayout = "individual", -- "individual" (every ring on its own), "maincast" (Main + Cast Ring) or "maingcd" (Main + GCD Ring)
    mainStyle = "ring",       -- what surrounds the cursor: the Main Ring ("ring") or the pointer glow ("glow")
    -- combat color: in combat combatTarget ("main" ring or center "dot") switches to combatColor, its opacity is kept;
    -- with the pointer glow the glow always switches
    combatTint = false, combatTarget = "main", combatColor = { 1, 0.1, 0.1, 1 },
    main = { enabled = true, size = 40, thickness = 6, classColor = false, color = { 1, 1, 1, 0.8 } },
    gcd  = { enabled = true, size = 28, thickness = 6, classColor = false, color = { 1, 0.82, 0, 1 }, track = true, trackAlpha = 0.5 },
    -- gradient: the swipe color moves from color to color2 while the cast progresses (class color is ignored then)
    cast = { enabled = true, size = 54, thickness = 6, classColor = false, color = { 1, 1, 1, 1 }, track = true, trackAlpha = 0.5,
             gradient = false, color2 = { 0.3, 0.8, 1, 1 } },
    dot  = { enabled = true, size = 10, shape = "dot", sizes = { dot = 10, gap = 22, ring = 24, spark = 24 }, pulse = true, pulseButton = "both", pulseSize = 4, classColor = false, color = { 1, 1, 1, 0.9 },
             -- gcd: with the shape "ring" the GCD runs as progress in the ring of the dot (the GCD ring is off then);
             -- gcdTrackAlpha: opacity of the ring at rest, as a share of the dot's opacity
             gcd = false, gcdTrackAlpha = 0.5 },
    -- ghost: while the player is dead a ghost floats above the cursor; height = pixels above the cursor position,
    -- float = it bobs up and down
    ghost = { enabled = false, size = 28, height = 4, float = true, classColor = false, color = { 1, 1, 1, 0.9 } },
    -- glow: halo in the shape of the game's mouse pointer, replaces the rings (see mainStyle) and follows the game's cursor size;
    -- showWhileLooking draws a copy of the pointer while the game hides it (right mouse button, mouselook);
    -- offsetX/offsetY (screen pixels) fine-tune the alignment with the pointer;
    -- leadFrames places the glow ahead along the mouse movement (movement of the last frame times this), to make up for the
    -- pointer being drawn later; it follows the frame rate by itself
    glow = { showWhileLooking = true, offsetX = 0, offsetY = 0, leadFrames = 0.8, classColor = false, color = { 0.35, 0.7, 1, 0.8 },
             -- one color or two (colorCount, color and color2) from top to bottom ("vertical") or left to right ("horizontal"):
             -- blend = smooth gradient, otherwise two hard halves. The opacity comes from color[4] for both.
             colorCount = 1, blend = true, gradientDir = "vertical", color2 = { 0.75, 0.3, 1, 0.8 } },
    -- presets: default size, duration and spacing per shape (and a color mode for the themed shapes); on a shape change the
    -- current values (including the color mode) are remembered for the old shape and the remembered ones (initially these
    -- defaults) are applied for the new shape.
    trail = { enabled = true, size = 16, duration = 0.45, spacing = 6, shrink = true, shape = "dot", colorMode = "rainbow", color = { 1, 1, 1, 0.5 },
              -- custom color mode: colorCount colors (color, color2..color4); gradient blends between them along the
              -- trail, otherwise every dot picks one of them at random. Opacity comes from color[4] for all of them.
              colorCount = 1, gradient = true,
              color2 = { 0.3, 0.6, 1, 0.5 }, color3 = { 0.8, 0.3, 1, 0.5 }, color4 = { 1, 0.4, 0.3, 0.5 },
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
    return MEDIA .. "Rings\\Ring" .. level .. "_" .. pickResolution(RING_RES, self:ScreenPixels(size or 40)) .. ".tga"
end

function ns:DotTexture(size)
    return MEDIA .. "Dot\\Dot_" .. pickResolution(DOT_RES, self:ScreenPixels(size or 8)) .. ".tga"
end

-- Shapes of the mouse trail (leaf, snowflake, star, mist, flame, heart, bubble, glitter, blossom, butterfly), of the center dot
-- (crosshair, dot with ring, sparkle) and the ghost; "dot" is the plain dot.
local SHAPE_RES = { { 30, 32 }, { 60, 64 }, { math.huge, 128 } }
local SHAPE_FILE = { leaf = "Trail\\Leaf", snow = "Trail\\Snow", star = "Trail\\Star", mist = "Trail\\Mist",
    flame = "Trail\\Flame", heart = "Trail\\Heart", bubble = "Trail\\Bubble", glitter = "Trail\\Glitter",
    blossom = "Trail\\Blossom", butterfly = "Trail\\Butterfly",
    gap = "Dot\\Gap", ring = "Dot\\DotRing", spark = "Dot\\Spark", ghost = "Ghost\\Ghost" }

-- "Energy": Blizzard texture from the game (FileID, not shipped with the addon), seamless tile with alpha channel.
ns.ENERGY_FILE_ID = 6735695
-- Soft round mask, cuts a round dot out of the tile.
ns.TRAIL_MASK = MEDIA .. "Trail\\Mask_64.tga"

function ns:ShapeTexture(shape, size)
    if shape == "energy" then return self.ENERGY_FILE_ID end
    local file = SHAPE_FILE[shape]
    if not file then return self:DotTexture(size) end
    return MEDIA .. file .. "_" .. pickResolution(SHAPE_RES, self:ScreenPixels(size or 16)) .. ".tga"
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
-- and its options are hidden; color and opacity come from the center dot.
function ns:GcdOnDot()
    local dot = self.cfg.dot
    return dot.gcd and dot.enabled and dot.shape == "ring" and self.cfg.mainStyle ~= "glow" or false
end

function ns:UpdateVisibility()
    for _, m in ipairs(self.modules) do
        if m.UpdateVisibility then m:UpdateVisibility() end
    end
end

-- Color of the Main Ring, the center dot or the pointer glow ("main" / "dot" / "glow"): its own color, or the combat color
-- while in combat if the combat color (General) is switched on for that element (the pointer glow always follows it, the
-- target setting only chooses between Main Ring and center dot). The opacity always comes from the element itself.
function ns:ElementColor(key)
    local cfg = self.cfg
    local element = cfg[key]
    if cfg.combatTint and (key == "glow" or cfg.combatTarget == key) and self.inCombat then
        local c = cfg.combatColor
        return c[1], c[2], c[3], element.color[4] or 1
    end
    return self:GetRingColor(element)
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

-- Color of a ring: class color or the configured color (r, g, b, a). A gradient ring uses its own colors instead.
function ns:GetRingColor(ringCfg)
    if ringCfg.classColor and not ringCfg.gradient and UnitClass then
        local _, class = UnitClass("player")
        local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
        if c then return c.r, c.g, c.b, ringCfg.color[4] or 1 end
    end
    local col = ringCfg.color
    return col[1], col[2], col[3], col[4] or 1
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
    local main = db.cfg.main
    if main then
        -- up to 1.0.1 the combat color belonged to the Main Ring; it is a general option now
        if main.combatTint ~= nil and db.cfg.combatTint == nil then
            db.cfg.combatTint, db.cfg.combatColor, db.cfg.combatTarget = main.combatTint, main.combatColor, "main"
        end
        main.combatTint, main.combatColor = nil, nil
    end
    fillDefaults(db.cfg, ns.defaults)
    ns.cfg = db.cfg
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
