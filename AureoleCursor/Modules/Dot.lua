-- Aureole Cursor: center dot in the middle of the rings.
local _, ns = ...

local dot = ns.anchor:CreateTexture(nil, "OVERLAY")
dot:SetTexture(ns:DotTexture(8))
dot:SetPoint("CENTER", ns.anchor, "CENTER")
ns.dot = dot

-- Click pulse: a ring grows out of the center dot and fades out.
local pulse, pulseGroup, pulseScale = ns:CreateBurst(0.3)
ns.pulse, ns.pulseGroup, ns.pulseScale = pulse, pulseGroup, pulseScale

ns:On("GLOBAL_MOUSE_DOWN", function(_, button)
    local cfg = ns.cfg and ns.cfg.dot
    if not cfg or not cfg.enabled or not ns:RingActive("dot") or not cfg.pulse or not ns:ClickButton(cfg.pulseButton, button) then return end
    if not ns.anchor:IsShown() then return end
    ns:PlayBurst(pulse, pulseGroup)
end)

-- Each shape has its own size: on a change the current size is remembered for the old shape and the
-- remembered one (initially the default size from cfg.dot.sizes) is applied for the new shape.
function ns:SetDotShape(shape)
    local cfg = self.cfg.dot
    if cfg.shape == shape then return end
    cfg.sizes[cfg.shape] = cfg.size
    cfg.shape = shape
    cfg.size = cfg.sizes[shape] or cfg.size
end

local Dot = {}
ns:RegisterModule(Dot)

-- GCD in the ring (shape "ring", see ns:GcdOnDot): the dot texture is split into the plain center dot, a ring (background
-- track, faint) and a cooldown swipe on the ring (the GCD). Sizes as a share of the shape's size, taken from the geometry of
-- DotRing (make_shapes.py: dot radius 0.11, ring 0.30 to 0.43 of the edge); RING_LEVEL is the ring thickness level whose
-- inner radius is about 70 % of the outer one (like 0.30 / 0.43).
local CORE_SIZE, RING_SIZE, RING_LEVEL = 0.22, 0.86, 7

-- Dot and click pulse: in combat they use the combat color if that is switched on for the dot (Colors).
local function applyColor()
    local r, g, b = ns:ElementColor("dot")
    dot:SetVertexColor(r, g, b, 1)
    pulse:SetVertexColor(r, g, b, 1)
    ns.dotCooldown:SetSwipeColor(r, g, b, 1)
    ns.dotTrack:SetVertexColor(r, g, b, ns.cfg.trackAlpha)
end

function Dot:UpdateVisibility()
    applyColor()
end

function Dot:Apply()
    local cfg = ns.cfg.dot
    local active = cfg.enabled and ns:RingActive("dot") -- the pointer glow replaces the rings and the center dot
    local onDot = active and ns:GcdOnDot()
    local cd, track = ns.dotCooldown, ns.dotTrack
    if onDot then
        local core, ring = cfg.size * CORE_SIZE, cfg.size * RING_SIZE
        dot:SetTexture(ns:DotTexture(core))
        dot:SetSize(core, core)
        track:SetTexture(ns:RingTexture(RING_LEVEL, ring))
        track:SetSize(ring, ring)
        track:Show()
        cd:SetFrameStrata(ns.cfg.strata)
        cd:SetSwipeTexture(ns:RingTexture(RING_LEVEL, ring))
        cd:SetSize(ring, ring)
        cd:SetReverse(false)
        cd:Show()
    else
        dot:SetTexture(ns:ShapeTexture(cfg.shape, cfg.size))
        dot:SetSize(cfg.size, cfg.size)
        track:Hide()
        cd:Clear()
        cd:Hide()
    end
    dot:SetShown(active)

    -- Pulse: the ring ends at dot size * pulseSize and grows from the dot to that size
    local final = cfg.size * cfg.pulseSize
    pulse:SetTexture(ns:RingTexture(3, final))
    pulse:SetSize(final, final)
    applyColor()
    pulseScale:SetScaleFrom(1 / cfg.pulseSize, 1 / cfg.pulseSize)
    pulseScale:SetScaleTo(1, 1)
    if not active then
        pulseGroup:Stop()
        pulse:Hide()
    end
end
