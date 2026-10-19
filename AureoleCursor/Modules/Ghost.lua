-- Aureole Cursor: ghost. While the player is dead (corpse or spirit) a ghost floats above the cursor.
-- It is a child of the cursor anchor, so scale, overall opacity, "show in combat only" and the frame layer apply to it.
local _, ns = ...

local FLOAT_TIME = 0.9
local FLOAT_RISE = 6 -- pixels the ghost bobs up and down

local ghost = ns.anchor:CreateTexture(nil, "OVERLAY", nil, 6)
ghost:Hide()
ns.ghost = ghost

-- The bobbing runs in the engine: one translation that bounces back and forth.
local bob = ghost:CreateAnimationGroup()
bob:SetLooping("BOUNCE")
local rise = bob:CreateAnimation("Translation")
rise:SetOffset(0, FLOAT_RISE)
rise:SetDuration(FLOAT_TIME)
rise:SetSmoothing("IN_OUT")
ns.ghostBob = bob

local Ghost = {}
ns:RegisterModule(Ghost)

local function isDead()
    return UnitIsDeadOrGhost("player") and true or false
end

local function update()
    local cfg = ns.cfg and ns.cfg.ghost
    local show = cfg and cfg.enabled and isDead() or false
    ghost:SetShown(show)
    if show and cfg.float then
        if not bob:IsPlaying() then bob:Play() end
    else
        bob:Stop()
    end
end

function Ghost:UpdateVisibility()
    local cfg = ns.cfg.ghost
    local r, g, b, a = ns:GetRingColor(cfg)
    ghost:SetVertexColor(r, g, b, a)
end

function Ghost:Apply()
    local cfg = ns.cfg.ghost
    ghost:SetTexture(ns:ShapeTexture("ghost", cfg.size))
    ghost:SetSize(cfg.size, cfg.size)
    ghost:ClearAllPoints()
    ghost:SetPoint("BOTTOM", ns.anchor, "CENTER", 0, cfg.height)
    self:UpdateVisibility()
    update()
end

ns:On("PLAYER_DEAD", update)
ns:On("PLAYER_ALIVE", update)
ns:On("PLAYER_UNGHOST", update)
ns:On("PLAYER_ENTERING_WORLD", update)
