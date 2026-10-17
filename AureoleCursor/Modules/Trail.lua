-- Aureole Cursor: mouse trail. Moving the mouse spawns dots at a fixed spacing that fade out
-- (and shrink). A pool of textures with animation groups: the position is only set on spawn,
-- fading and shrinking are done by the engine, no Lua runs per dot and frame.
local ADDON, ns = ...

local GetCursorPosition = GetCursorPosition
local POOL = 256           -- dots that can be visible at the same time
local MAX_PER_FRAME = 40   -- upper limit per frame; fast mouse movement stays gap-free, only jumps are clipped
local SHRINK_TO = 0.2
local RAINBOW_LENGTH = 400   -- distance in pixels for one pass through all colors
local MIST_SIZE = 3            -- mist clouds are this many times larger than the configured size (so they overlap)
local ENERGY_SPAN = 0.5      -- energy shape: share of the tile one dot shows (random section)

-- Seasonal palettes: each dot gets one of the colors at random
local PALETTES = {
    autumn = { { 0.85, 0.33, 0.10 }, { 0.95, 0.60, 0.12 }, { 0.70, 0.15, 0.10 }, { 0.90, 0.75, 0.20 }, { 0.50, 0.28, 0.10 } },
    winter = { { 1, 1, 1 }, { 0.85, 0.95, 1 }, { 0.70, 0.86, 1 }, { 0.55, 0.78, 1 } },
    christmas = { { 0.85, 0.10, 0.10 }, { 0.10, 0.60, 0.20 }, { 1, 0.85, 0.30 }, { 1, 1, 1 } },
}

local frame = CreateFrame("Frame", "AureoleCursorTrail", UIParent)
frame:SetSize(1, 1)
frame:EnableMouse(false)
frame:Hide()
ns.trailFrame = frame

local dots, nextDot = {}, 1
ns.trailDots = dots

for i = 1, POOL do
    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:Hide()
    local group = tex:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    local shrink = group:CreateAnimation("Scale")
    shrink:SetScaleFrom(1, 1)
    group:SetScript("OnFinished", function() tex:Hide() end)
    dots[i] = { tex = tex, group = group, fade = fade, shrink = shrink }
end

local lastX, lastY
local rainbow, palette, spin, energy, colorAlpha = false, nil, false, false, 1
local travelled = 0

-- Hue (0..1) at full saturation and brightness, as RGB
local function hue(h)
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    if i == 0 then return 1, f, 0
    elseif i == 1 then return 1 - f, 1, 0
    elseif i == 2 then return 0, 1, f
    elseif i == 3 then return 0, 1 - f, 1
    elseif i == 4 then return f, 0, 1
    else return 1, 0, 1 - f end
end

-- Energy shape: round mask per dot, created on first use. The mask is attached to the dot and gets
-- the same shrink animation so it scales with the dot (the alpha fade only affects the texture).
local function applyMask(d, t)
    if not d.mask then
        d.mask = frame:CreateMaskTexture()
        d.mask:SetTexture(ns.TRAIL_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        d.mask:SetAllPoints(d.tex)
        d.maskGroup = d.mask:CreateAnimationGroup()
        d.maskShrink = d.maskGroup:CreateAnimation("Scale")
        d.maskShrink:SetScaleFrom(1, 1)
    end
    if not d.masked then
        d.tex:AddMaskTexture(d.mask)
        d.masked = true
    end
    local target = t.shrink and SHRINK_TO or 1
    d.maskShrink:SetDuration(t.duration)
    d.maskShrink:SetScaleTo(target, target)
end

local function removeMask(d)
    if d.masked then
        d.tex:RemoveMaskTexture(d.mask)
        d.masked = false
        d.maskGroup:Stop()
    end
end

local function stopAll()
    for _, d in ipairs(dots) do
        d.group:Stop()
        if d.maskGroup then d.maskGroup:Stop() end
        d.tex:Hide()
    end
end

local function spawn(x, y)
    local d = dots[nextDot]
    nextDot = nextDot % POOL + 1
    d.group:Stop()
    if d.maskGroup then d.maskGroup:Stop() end
    if palette then
        local c = palette[math.random(#palette)]
        d.tex:SetVertexColor(c[1], c[2], c[3], colorAlpha)
    elseif rainbow then
        local r, g, b = hue(travelled / RAINBOW_LENGTH)
        d.tex:SetVertexColor(r, g, b, colorAlpha)
    end
    if spin then d.tex:SetRotation(math.random() * 2 * math.pi) end
    if energy then
        local u, v = math.random(), math.random() -- tile is seamless (REPEAT), each dot shows a different section
        d.tex:SetTexCoord(u, u + ENERGY_SPAN, v, v + ENERGY_SPAN)
    end
    d.tex:ClearAllPoints()
    d.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    d.tex:Show()
    d.group:Play()
    if energy and d.maskGroup then d.maskGroup:Play() end
end

frame:SetScript("OnUpdate", function()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    if not lastX then
        lastX, lastY = x, y
        return
    end

    local dx, dy = x - lastX, y - lastY
    local dist = math.sqrt(dx * dx + dy * dy)
    local spacing = ns.cfg.trail.spacing
    if dist < spacing then return end

    local ux, uy = dx / dist, dy / dist
    local n = math.floor(dist / spacing)
    if n > MAX_PER_FRAME then
        -- Very fast or a jump (e.g. Alt-Tab): only draw the last dots of the path
        local skip = (n - MAX_PER_FRAME) * spacing
        lastX, lastY = lastX + ux * skip, lastY + uy * skip
        n = MAX_PER_FRAME
    end
    for i = 1, n do
        travelled = travelled + spacing
        spawn(lastX + ux * spacing * i, lastY + uy * spacing * i)
    end
    lastX, lastY = lastX + ux * spacing * n, lastY + uy * spacing * n
end)

-- On show, start over (no streak from the old position); on hide, clean up.
frame:SetScript("OnShow", function() lastX, lastY = nil, nil end)
frame:SetScript("OnHide", stopAll)

-- Each shape has its own size, duration and spacing: on a change the current values are remembered
-- for the old shape and the remembered ones (initially the defaults from cfg.trail.presets) are applied.
function ns:SetTrailShape(shape)
    local t = self.cfg.trail
    if t.shape == shape then return end
    t.presets[t.shape] = { size = t.size, duration = t.duration, spacing = t.spacing }
    t.shape = shape
    local p = t.presets[shape]
    if p then t.size, t.duration, t.spacing = p.size, p.duration, p.spacing end
end

local Trail = {}
ns:RegisterModule(Trail)

function Trail:UpdateVisibility()
    local cfg = ns.cfg
    frame:SetShown(cfg.trail.enabled and (not cfg.combatOnly or ns.inCombat))
end

function Trail:Apply()
    local cfg = ns.cfg
    local t = cfg.trail
    frame:SetFrameStrata(cfg.strata)
    ns:UpdateAlpha()

    local size = t.shape == "mist" and t.size * MIST_SIZE or t.size
    local texture = ns:ShapeTexture(t.shape, size)
    -- Color mode: rainbow or season (color per dot in spawn), class color or custom color
    local r, g, b, a = ns:GetRingColor({ classColor = t.colorMode == "class", color = t.color })
    rainbow, palette, colorAlpha = t.colorMode == "rainbow", PALETTES[t.colorMode], a
    spin = t.shape ~= "dot" and t.shape ~= nil -- leaves, snowflakes and stars are randomly rotated
    energy = t.shape == "energy"
    if energy then -- energy keeps its original colors: color mode and color do not apply, only the opacity
        rainbow, palette, r, g, b = false, nil, 1, 1, 1
    end
    local target = t.shrink and SHRINK_TO or 1
    for _, d in ipairs(dots) do
        if energy then
            d.tex:SetTexture(texture, "REPEAT", "REPEAT")
            applyMask(d, t)
        else
            d.tex:SetTexture(texture)
            d.tex:SetTexCoord(0, 1, 0, 1)
            removeMask(d)
        end
        d.tex:SetSize(size, size)
        d.tex:SetVertexColor(r, g, b, a)
        d.tex:SetRotation(0)
        d.fade:SetDuration(t.duration)
        d.shrink:SetDuration(t.duration)
        d.shrink:SetScaleTo(target, target)
    end
    lastX, lastY = nil, nil
    self:UpdateVisibility()
end
