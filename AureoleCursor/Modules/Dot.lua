-- Aureole Cursor: Mittelpunkt (Dot) im Zentrum der Ringe.
local ADDON, ns = ...

local dot = ns.anchor:CreateTexture(nil, "OVERLAY")
dot:SetTexture(ns:DotTexture(8))
dot:SetPoint("CENTER", ns.anchor, "CENTER")
ns.dot = dot

-- Klick-Impuls: ein Ring waechst aus dem Mittelpunkt und blendet aus. Die Animation laeuft in der Engine,
-- Lua wird nur beim Klick gebraucht.
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

-- Jede Form hat ihre eigene Groesse: beim Wechsel wird die aktuelle Groesse fuer die alte Form gemerkt und die
-- gemerkte (zuerst die Standardgroesse aus cfg.dot.sizes) der neuen Form uebernommen.
function ns:SetDotShape(shape)
    local cfg = self.cfg.dot
    if cfg.shape == shape then return end
    cfg.sizes[cfg.shape] = cfg.size
    cfg.shape = shape
    cfg.size = cfg.sizes[shape] or cfg.size
end

local Dot = {}
ns:RegisterModule(Dot)

function Dot:Apply()
    local cfg = ns.cfg.dot
    dot:SetTexture(ns:ShapeTexture(cfg.shape, cfg.size))
    dot:SetSize(cfg.size, cfg.size)
    dot:SetVertexColor(ns:GetRingColor(cfg))
    dot:SetShown(cfg.enabled)

    -- Impuls: der Ring hat am Ende die Groesse Punkt * pulseSize und waechst vom Punkt aus dorthin
    local final = cfg.size * cfg.pulseSize
    pulse:SetTexture(ns:RingTexture(3, final))
    pulse:SetSize(final, final)
    pulse:SetVertexColor(ns:GetRingColor(cfg))
    pulseScale:SetScaleFrom(1 / cfg.pulseSize, 1 / cfg.pulseSize)
    pulseScale:SetScaleTo(1, 1)
    if not cfg.enabled then
        pulseGroup:Stop()
        pulse:Hide()
    end
end
