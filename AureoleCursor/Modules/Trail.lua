-- Aureole Cursor: mouse trail. Moving the mouse spawns dots at a fixed spacing that fade out
-- (and shrink). A pool of textures with animation groups: the position is only set on spawn,
-- fading and shrinking are done by the engine, no Lua runs per dot and frame.
local _, ns = ...

local GetCursorPosition = GetCursorPosition
local POOL = 256           -- dots that can be visible at the same time
local MAX_PER_FRAME = 40   -- upper limit per frame; fast mouse movement stays gap-free, only jumps are clipped
local SHRINK_TO = 0.2
local RAINBOW_LENGTH = 400   -- distance in pixels for one pass through all colors
local MIST_SIZE = 3            -- mist clouds are this many times larger than the configured size (so they overlap)
local ENERGY_SPAN = 0.5      -- energy shape: share of the tile one dot shows (random section)
local GRADIENT_SEGMENT = 200   -- distance in pixels to blend from one custom color to the next

-- Seasonal palettes: each dot gets one of the colors at random
local PALETTES = {
    autumn = { { 0.85, 0.33, 0.10 }, { 0.95, 0.60, 0.12 }, { 0.70, 0.15, 0.10 }, { 0.90, 0.75, 0.20 }, { 0.50, 0.28, 0.10 } },
    winter = { { 1, 1, 1 }, { 0.85, 0.95, 1 }, { 0.70, 0.86, 1 }, { 0.55, 0.78, 1 } },
    christmas = { { 0.85, 0.10, 0.10 }, { 0.10, 0.60, 0.20 }, { 1, 0.85, 0.30 }, { 1, 1, 1 } },
    -- default palettes of the themed shapes (flame, heart, bubble, glitter)
    fire = { { 1, 0.85, 0.20 }, { 1, 0.55, 0.10 }, { 0.95, 0.30, 0.08 }, { 0.80, 0.12, 0.05 } },
    love = { { 1, 0.35, 0.50 }, { 0.95, 0.15, 0.30 }, { 1, 0.60, 0.75 }, { 0.85, 0.10, 0.25 } },
    ocean = { { 0.55, 0.85, 1 }, { 0.30, 0.65, 1 }, { 0.75, 0.95, 1 }, { 0.40, 0.80, 0.90 } },
    gold = { { 1, 0.90, 0.50 }, { 1, 0.80, 0.25 }, { 1, 1, 0.85 }, { 1, 0.70, 0.20 } },
}

-- Motion of the themed shapes, in multiples of the dot size. All of it is played by the engine (animations), Lua only sets
-- random values when a dot is spawned. rise = distance the dot floats up while it fades (negative: falls), sway = random
-- sideways drift, jitter = random offset of the start position around the cursor, spin = degrees the dot turns while it
-- fades (random direction), tilt = largest random angle in radians (default: any angle), add = additive blending (glows).
local MOTION = {
    flame = { rise = 2.2, sway = 0.5, jitter = 0.3, tilt = 0.35, add = true },
    heart = { rise = 1.6, sway = 0.6, tilt = 0.45 },
    bubble = { rise = 1.8, sway = 0.8, jitter = 0.2, tilt = 0 },
    glitter = { jitter = 0.8, spin = 120, add = true },
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
    local move = group:CreateAnimation("Translation")
    move:SetOffset(0, 0)
    local turn = group:CreateAnimation("Rotation")
    turn:SetDegrees(0)
    group:SetScript("OnFinished", function() tex:Hide() end)
    dots[i] = { tex = tex, group = group, fade = fade, shrink = shrink, move = move, turn = turn }
end

local lastX, lastY
local rainbow, palette, gradient, spin, energy, colorAlpha = false, nil, nil, false, false, 1
local motion, tilt, dotSize -- MOTION of the current shape, its tilt limit and the dot size in pixels
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

-- Color along a closed gradient through the list: blends from each color to the next, the last one back to the first.
local function gradientColor(list, distance)
    local pos = distance / GRADIENT_SEGMENT
    local i = math.floor(pos)
    local f = pos - i
    local n = #list
    local a, b = list[i % n + 1], list[(i + 1) % n + 1]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
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
    elseif gradient then
        local r, g, b = gradientColor(gradient, travelled)
        d.tex:SetVertexColor(r, g, b, colorAlpha)
    elseif rainbow then
        local r, g, b = hue(travelled / RAINBOW_LENGTH)
        d.tex:SetVertexColor(r, g, b, colorAlpha)
    end
    if spin then d.tex:SetRotation(tilt and (math.random() * 2 - 1) * tilt or math.random() * 2 * math.pi) end
    if motion then
        local s = dotSize
        if motion.jitter then
            x = x + (math.random() * 2 - 1) * motion.jitter * s
            y = y + (math.random() * 2 - 1) * motion.jitter * s
        end
        d.move:SetOffset((math.random() * 2 - 1) * (motion.sway or 0) * s, (motion.rise or 0) * s * (0.7 + 0.6 * math.random()))
        if motion.spin then d.turn:SetDegrees((math.random() < 0.5 and -1 or 1) * motion.spin * (0.5 + math.random())) end
    end
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
    t.presets[t.shape] = { size = t.size, duration = t.duration, spacing = t.spacing, colorMode = t.colorMode }
    t.shape = shape
    local p = t.presets[shape]
    if p then
        t.size, t.duration, t.spacing = p.size, p.duration, p.spacing
        if p.colorMode then t.colorMode = p.colorMode end -- themed shapes start with their palette, every shape remembers its mode
    end
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
    rainbow, palette, gradient, colorAlpha = t.colorMode == "rainbow", PALETTES[t.colorMode], nil, a
    if t.colorMode == "custom" and (t.colorCount or 1) > 1 then
        -- several custom colors: blended along the trail, or one picked at random per dot
        local list = { { r, g, b } }
        for i = 2, t.colorCount do
            local c = t["color" .. i]
            list[i] = { c[1], c[2], c[3] }
        end
        if t.gradient then gradient = list else palette = list end
    end
    spin = t.shape ~= "dot" -- every shape except the plain dot is randomly rotated
    motion = MOTION[t.shape]
    tilt = motion and motion.tilt
    dotSize = size
    energy = t.shape == "energy"
    if energy then -- energy keeps its original colors: color mode and color do not apply, only the opacity
        rainbow, palette, gradient, r, g, b = false, nil, nil, 1, 1, 1
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
        d.move:SetDuration(t.duration)
        d.turn:SetDuration(t.duration)
        d.tex:SetBlendMode(motion and motion.add and "ADD" or "BLEND")
        if not motion then
            d.move:SetOffset(0, 0)
            d.turn:SetDegrees(0)
        end
    end
    lastX, lastY = nil, nil
    self:UpdateVisibility()
end
