-- Aureole Cursor: center dot in the middle of the rings.
local _, ns = ...

local dot = ns.anchor:CreateTexture(nil, "OVERLAY")
dot:SetTexture(ns:DotTexture(8))
dot:SetPoint("CENTER", ns.anchor, "CENTER")
ns.dot = dot

-- Click pulse: a ring grows out of the center dot and fades out. The animation runs in the engine,
-- Lua is only needed on the click.
local PULSE_TIME = 0.3
local PULSE_BUTTONS = {
    left = { LeftButton = true },
    right = { RightButton = true },
    both = { LeftButton = true, RightButton = true },
}

local pulse = ns.anchor:CreateTexture(nil, "OVERLAY")
pulse:SetPoint("CENTER", ns.anchor, "CENTER")
pulse:Hide()
local pulseGroup = pulse:CreateAnimationGroup()
local pulseFade = pulseGroup:CreateAnimation("Alpha")
pulseFade:SetFromAlpha(1)
pulseFade:SetToAlpha(0)
pulseFade:SetDuration(PULSE_TIME)
local pulseScale = pulseGroup:CreateAnimation("Scale")
pulseScale:SetDuration(PULSE_TIME)
pulseGroup:SetScript("OnFinished", function() pulse:Hide() end)
ns.pulse, ns.pulseGroup, ns.pulseScale = pulse, pulseGroup, pulseScale

ns:On("GLOBAL_MOUSE_DOWN", function(_, button)
    local cfg = ns.cfg and ns.cfg.dot
    if not cfg or not cfg.enabled or not cfg.pulse or not PULSE_BUTTONS[cfg.pulseButton][button] then return end
    if not ns.anchor:IsShown() then return end
    pulseGroup:Stop()
    pulse:Show()
    pulseGroup:Play()
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

-- Dot and click pulse: in combat they use the combat color if that is switched on for the dot (General).
local function applyColor()
    local r, g, b, a = ns:ElementColor("dot")
    dot:SetVertexColor(r, g, b, a)
    pulse:SetVertexColor(r, g, b, a)
end

function Dot:UpdateVisibility()
    applyColor()
end

function Dot:Apply()
    local cfg = ns.cfg.dot
    dot:SetTexture(ns:ShapeTexture(cfg.shape, cfg.size))
    dot:SetSize(cfg.size, cfg.size)
    dot:SetShown(cfg.enabled)

    -- Pulse: the ring ends at dot size * pulseSize and grows from the dot to that size
    local final = cfg.size * cfg.pulseSize
    pulse:SetTexture(ns:RingTexture(3, final))
    pulse:SetSize(final, final)
    applyColor()
    pulseScale:SetScaleFrom(1 / cfg.pulseSize, 1 / cfg.pulseSize)
    pulseScale:SetScaleTo(1, 1)
    if not cfg.enabled then
        pulseGroup:Stop()
        pulse:Hide()
    end
end
