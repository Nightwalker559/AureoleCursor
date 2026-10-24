-- Aureole Cursor: mouse trail. Moving the mouse spawns dots at a fixed spacing that fade out
-- (and shrink). A pool of textures with animation groups: the position is only set on spawn,
-- fading, shrinking and the motion of the themed shapes are done by the engine, no Lua runs per dot and frame.
local _, ns = ...

local GetCursorPosition = GetCursorPosition
local GetFramerate = GetFramerate
local FPS_FULL = 45        -- from this frame rate up the trail is drawn as configured
local FPS_OFF = 20         -- below this it is paused; in between it gets sparser (up to twice the spacing, half the dots per frame)
local POOL = 256          -- dots that can be visible at the same time
local MAX_PER_FRAME = 40   -- upper limit per frame; fast mouse movement stays gap-free, only jumps are clipped
local STRETCH = 0.5        -- when the limit is hit, the dots of the frame are spread out up to this share of their size apart
local SHRINK_TO = 0.2
local RAINBOW_LENGTH = 400   -- distance in pixels for one pass through all colors
local MIST_SIZE = 3            -- mist clouds are this many times larger than the configured size (so they overlap)
local ENERGY_SPAN = 0.5      -- energy shape: share of the tile one dot shows (random section)
local GRADIENT_SEGMENT = 200   -- distance in pixels to blend from one custom color to the next

-- Seasonal palettes: each dot gets one of the colors at random
local PALETTES = {
    spring = { { 1, 0.75, 0.82 }, { 1, 0.88, 0.92 }, { 1, 1, 1 }, { 0.95, 0.60, 0.75 }, { 0.80, 0.92, 0.55 } },
    summer = { { 1, 0.80, 0.20 }, { 1, 0.55, 0.15 }, { 0.35, 0.75, 1 }, { 0.55, 0.85, 0.45 } },
    autumn = { { 0.85, 0.33, 0.10 }, { 0.95, 0.60, 0.12 }, { 0.70, 0.15, 0.10 }, { 0.90, 0.75, 0.20 }, { 0.50, 0.28, 0.10 } },
    winter = { { 1, 1, 1 }, { 0.85, 0.95, 1 }, { 0.70, 0.86, 1 }, { 0.55, 0.78, 1 } },
    christmas = { { 0.85, 0.10, 0.10 }, { 0.10, 0.60, 0.20 }, { 1, 0.85, 0.30 }, { 1, 1, 1 } },
    -- default palettes of the themed shapes (blossom, butterfly, flame, heart, bubble, glitter, ember, drop, feather, bolt, crystal, coin, rune)
    fire = { { 1, 0.85, 0.20 }, { 1, 0.55, 0.10 }, { 0.95, 0.30, 0.08 }, { 0.80, 0.12, 0.05 } },
    love = { { 1, 0.35, 0.50 }, { 0.95, 0.15, 0.30 }, { 1, 0.60, 0.75 }, { 0.85, 0.10, 0.25 } },
    ocean = { { 0.55, 0.85, 1 }, { 0.30, 0.65, 1 }, { 0.75, 0.95, 1 }, { 0.40, 0.80, 0.90 } },
    gold = { { 1, 0.90, 0.50 }, { 1, 0.80, 0.25 }, { 1, 1, 0.85 }, { 1, 0.70, 0.20 } },
    arcane = { { 0.75, 0.45, 1 }, { 0.55, 0.40, 1 }, { 0.90, 0.60, 1 }, { 0.40, 0.55, 1 } },
    storm = { { 1, 1, 0.75 }, { 1, 0.95, 0.40 }, { 0.60, 0.90, 1 }, { 1, 1, 1 } },
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
    blossom = { rise = -1.8, sway = 0.9, jitter = 0.3, spin = 100 },
    butterfly = { rise = 1.4, sway = 1.4, jitter = 0.3, tilt = 0.6 },
    ember = { rise = 4, sway = 0.9, jitter = 0.4, add = true },
    drop = { rise = -3, sway = 0.15, jitter = 0.2, tilt = 0 },
    feather = { rise = -1.4, sway = 1.3, jitter = 0.3, spin = 80 },
    bolt = { jitter = 0.6, tilt = 0.5, add = true },
    crystal = { rise = 0.8, sway = 0.6, jitter = 0.5, spin = 70 },
    coin = { rise = 1.2, sway = 0.5, jitter = 0.3, tilt = 0.4 },
    rune = { jitter = 0.2, spin = 90, add = true },
    confetti = { rise = -2.2, sway = 1.4, jitter = 0.7, spin = 300 },
    pumpkin = { rise = -1.5, sway = 1.0, jitter = 0.3, tilt = 0.5 },
    balloon = { rise = 2, sway = 0.8, jitter = 0.3, tilt = 0.3 },
}

-- Shapes with a look of their own and no motion. add = additive blending, core = the shape can have a core (setting "core"):
-- a second, smaller copy of the dot in its own color (palette field coreColor) on top of it, so the edge has the color of the
-- trail and the middle another one.
local LOOK = {
    line = { add = true, core = true },
}
local CORE_SHARE = 0.4 -- size of the core relative to the dot

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
    -- The motion of the themed shapes is a second group that only plays for those shapes. The plain shapes would otherwise
    -- pay for a translation and a rotation of zero on every dot and every frame.
    local motionGroup = tex:CreateAnimationGroup()
    local move = motionGroup:CreateAnimation("Translation")
    move:SetOffset(0, 0)
    local turn = motionGroup:CreateAnimation("Rotation")
    turn:SetDegrees(0)
    dots[i] = { tex = tex, group = group, fade = fade, shrink = shrink, motionGroup = motionGroup, move = move, turn = turn }
end

local lastX, lastY
local rainbow, palette, gradient, spin, energy = false, nil, nil, false, false
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

local function shrinkTarget(t)
    return t.shrink and SHRINK_TO or 1
end

-- Stops the animations of a dot (also the motion of an earlier shape, and the mask, see applyMask).
local function stopDot(d)
    d.group:Stop()
    d.motionGroup:Stop()
    if d.maskGroup then d.maskGroup:Stop() end
    if d.coreGroup then d.coreGroup:Stop() end
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
    local target = shrinkTarget(t)
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

-- Core: a second texture in the middle of the dot with its own fade and shrink. It is anchored to the center of the dot's
-- texture, so it follows every spawn without a position of its own.
local function applyCore(d, t, texture, size)
    if not d.core then
        local core = frame:CreateTexture(nil, "ARTWORK", nil, 1)
        core:Hide()
        core:SetPoint("CENTER", d.tex, "CENTER")
        d.core = core
        d.coreGroup = core:CreateAnimationGroup()
        d.coreFade = d.coreGroup:CreateAnimation("Alpha")
        d.coreFade:SetFromAlpha(1)
        d.coreFade:SetToAlpha(0)
        d.coreShrink = d.coreGroup:CreateAnimation("Scale")
        d.coreShrink:SetScaleFrom(1, 1)
        d.coreGroup:SetScript("OnFinished", function() core:Hide() end)
    end
    d.coreOn = true
    d.core:SetTexture(texture)
    d.core:SetTexCoord(0, 1, 0, 1)
    d.core:SetSize(size * CORE_SHARE, size * CORE_SHARE)
    d.coreFade:SetDuration(t.duration)
    d.coreShrink:SetDuration(t.duration)
    local target = shrinkTarget(t)
    d.coreShrink:SetScaleTo(target, target)
end

local function removeCore(d)
    if d.coreOn then
        d.coreOn = false
        d.coreGroup:Stop()
        d.core:Hide()
    end
end

local function stopAll()
    for _, d in ipairs(dots) do
        stopDot(d)
        d.tex:Hide()
        if d.core then d.core:Hide() end
    end
end

local function spawn(x, y)
    local d = dots[nextDot]
    nextDot = nextDot % POOL + 1
    stopDot(d)
    if palette then
        local c = palette[math.random(#palette)]
        d.tex:SetVertexColor(c[1], c[2], c[3], 1)
    elseif gradient then
        local r, g, b = gradientColor(gradient, travelled)
        d.tex:SetVertexColor(r, g, b, 1)
    elseif rainbow then
        local r, g, b = hue(travelled / RAINBOW_LENGTH)
        d.tex:SetVertexColor(r, g, b, 1)
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
    if d.coreOn then
        d.core:Show()
        d.coreGroup:Play()
    end
    if motion then d.motionGroup:Play() end
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

    -- Low frame rate (many players around): every frame covers a longer stretch, so it would spawn more dots exactly when
    -- the game is struggling. Thin the trail out, and pause it when the game is really slow (no streak when it resumes).
    local fps = GetFramerate()
    local load = 1
    if fps < FPS_FULL then
        if fps < FPS_OFF then
            lastX, lastY = x, y
            return
        end
        load = (fps - FPS_OFF) / (FPS_FULL - FPS_OFF)
        spacing = spacing * (2 - load)
    end
    local maxPerFrame = math.ceil(MAX_PER_FRAME * (0.5 + 0.5 * load))
    if dist < spacing then return end

    local ux, uy = dx / dist, dy / dist
    local n = math.floor(dist / spacing)
    if n > maxPerFrame then
        if dist <= maxPerFrame * math.max(spacing, STRETCH * dotSize) then
            -- Fast stroke (dense shapes like the line reach the limit at a few hundred pixels per frame): spread the dots
            -- of this frame over the whole stretch, they still overlap, so the trail has no gaps
            spacing = dist / maxPerFrame
        else
            -- Very fast or a jump (e.g. Alt-Tab): only draw the last dots of the path
            local skip = (n - maxPerFrame) * spacing
            lastX, lastY = lastX + ux * skip, lastY + uy * skip
        end
        n = maxPerFrame
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
-- The color mode (cfg.colors.custom.trail) goes along: every shape remembers its mode, the themed shapes start with their palette.
function ns:SetTrailShape(shape)
    local t = self.cfg.trail
    if t.shape == shape then return end
    local colors = self.cfg.colors.custom.trail
    t.presets[t.shape] = { size = t.size, duration = t.duration, spacing = t.spacing, colorMode = colors.colorMode }
    t.shape = shape
    local p = t.presets[shape]
    if p then
        t.size, t.duration, t.spacing = p.size, p.duration, p.spacing
        if p.colorMode then colors.colorMode = p.colorMode end
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
    local colors = ns:Palette().trail
    frame:SetFrameStrata(cfg.strata)
    ns:UpdateAlpha()

    local size = t.shape == "mist" and t.size * MIST_SIZE or t.size
    local texture = ns:ShapeTexture(t.shape, size)
    -- Color mode: rainbow or season (color per dot in spawn) or custom colors (also what a theme sets)
    local r, g, b = ns:GetRingColor(colors)
    rainbow, palette, gradient = colors.colorMode == "rainbow", PALETTES[colors.colorMode], nil
    if colors.colorMode == "custom" and (colors.colorCount or 1) > 1 then
        -- several custom colors: blended along the trail, or one picked at random per dot
        local list = { { r, g, b } }
        for i = 2, colors.colorCount do
            local c = colors["color" .. i]
            list[i] = { c[1], c[2], c[3] }
        end
        if colors.gradient then gradient = list else palette = list end
    end
    spin = t.shape ~= "dot" -- every shape except the plain dot is randomly rotated
    motion = MOTION[t.shape]
    local look = LOOK[t.shape]
    tilt = motion and motion.tilt
    dotSize = size
    energy = t.shape == "energy"
    if energy then -- energy keeps its original colors: color mode and color do not apply
        rainbow, palette, gradient, r, g, b = false, nil, nil, 1, 1, 1
    end
    local target = shrinkTarget(t)
    local coreOn = t.core and look and look.core
    local cc = colors.coreColor or { 1, 1, 1 }
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
        d.tex:SetVertexColor(r, g, b, 1)
        if coreOn then
            applyCore(d, t, texture, size)
            d.core:SetVertexColor(cc[1], cc[2], cc[3], 1)
        else
            removeCore(d)
        end
        d.tex:SetRotation(0)
        d.fade:SetDuration(t.duration)
        d.shrink:SetDuration(t.duration)
        d.shrink:SetScaleTo(target, target)
        d.move:SetDuration(t.duration)
        d.turn:SetDuration(t.duration)
        local blend = ((motion and motion.add) or (look and look.add)) and "ADD" or "BLEND"
        d.tex:SetBlendMode(blend)
        if d.coreOn then d.core:SetBlendMode(blend) end
        if not motion then
            d.move:SetOffset(0, 0)
        end
        if not (motion and motion.spin) then d.turn:SetDegrees(0) end
    end
    lastX, lastY = nil, nil
    self:UpdateVisibility()
end
