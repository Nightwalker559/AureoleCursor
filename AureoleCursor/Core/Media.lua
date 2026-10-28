-- Aureole Cursor: texture files. Which PNG belongs to a ring (thickness level, line style), the center dot and every trail
-- shape, in the resolution that fits the size on screen. The files are made by make_media.py and make_shapes.py (tools folder).
local _, ns = ...

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

-- File name prefix of the ring line styles (same thickness levels and resolutions as the plain ring, see make_media.py)
local RING_STYLES = { solid = "Ring", dash = "Dash", dots = "Dots", ticks = "Ticks", segments = "Segments" }

-- style: line style of the ring (cfg.ringStyle), the plain ring when left out
function ns:RingTexture(level, size, style)
    level = math.max(1, math.min(ns.MAX_THICKNESS, math.floor(level or 4)))
    return MEDIA .. "Rings\\" .. (RING_STYLES[style] or "Ring") .. level .. "_" .. pickResolution(RING_RES, self:ScreenPixels(size or 40)) .. ".png"
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
    paw = "Trail\\Paw", bat = "Trail\\Bat", smoke = "Trail\\Smoke", ripple = "Trail\\Ripple",
    gap = "Dot\\Gap", ring = "Dot\\DotRing", spark = "Dot\\Spark", diamond = "Dot\\Diamond", arrow = "Dot\\Arrow",
    crossdot = "Dot\\CrossDot", doublering = "Dot\\DoubleRing", corners = "Dot\\Corners", hexagon = "Dot\\Hexagon" }

-- "Energy": Blizzard texture from the game (FileID, not shipped with the addon), seamless tile with alpha channel.
local ENERGY_FILE_ID = 6735695
-- Soft round mask, cuts a round dot out of the tile.
ns.TRAIL_MASK = MEDIA .. "Trail\\Mask_64.png"

function ns:ShapeTexture(shape, size)
    if shape == "energy" then return ENERGY_FILE_ID end
    local file = SHAPE_FILE[shape]
    if not file then return self:DotTexture(size) end
    return MEDIA .. file .. "_" .. pickResolution(SHAPE_RES, self:ScreenPixels(size or 16)) .. ".png"
end
