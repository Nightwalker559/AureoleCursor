-- Aureole Cursor: ghost. While the player is really dead (corpse or spirit, not feigning death) a ghost floats above the
-- cursor.
-- The ghost has a frame of its own that follows the cursor, so it does not depend on the cursor anchor: you are not in
-- combat when you are dead, and "show in combat only" or the opacity out of combat must not hide it. It follows the
-- overall scale, opacity, frame layer and "hide while mouse-looking".
local _, ns = ...

local GetCursorPosition = GetCursorPosition

local FLOAT_TIME = 0.9
local FLOAT_RISE = 6 -- pixels the ghost bobs up and down

local frame = CreateFrame("Frame", "AureoleCursorGhost", UIParent)
frame:SetSize(1, 1)
frame:EnableMouse(false)
frame:Hide()
ns.ghostFrame = frame

local ghost = frame:CreateTexture(nil, "OVERLAY")
ns.ghost = ghost

-- The bobbing runs in the engine: up, then down, in a loop.
local bob = ghost:CreateAnimationGroup()
bob:SetLooping("REPEAT")
local up = bob:CreateAnimation("Translation")
up:SetOrder(1)
up:SetOffset(0, FLOAT_RISE)
up:SetDuration(FLOAT_TIME)
up:SetSmoothing("IN_OUT")
local down = bob:CreateAnimation("Translation")
down:SetOrder(2)
down:SetOffset(0, -FLOAT_RISE)
down:SetDuration(FLOAT_TIME)
down:SetSmoothing("IN_OUT")
ns.ghostBob = bob

-- Follow the cursor (only while the ghost is shown) and hide while mouse-looking if that is switched on.
local lastX, lastY, lastScale, hidden
frame:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    if x ~= lastX or y ~= lastY or scale ~= lastScale then
        lastX, lastY, lastScale = x, y, scale
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end
    local hide = ns.cfg.hideOnMouselook and IsMouselooking and IsMouselooking() and true or false
    if hide ~= hidden then
        hidden = hide
        self:SetAlpha(hide and 0 or ns.cfg.alpha)
    end
end)
frame:SetScript("OnShow", function()
    lastX, lastY, lastScale, hidden = nil, nil, nil, nil
end)

local Ghost = {}
ns:RegisterModule(Ghost)

local function isDead()
    return UnitIsDeadOrGhost("player") and not UnitIsFeignDeath("player") and true or false
end

local function update()
    local cfg = ns.cfg and ns.cfg.ghost
    local show = cfg and cfg.enabled and isDead() or false
    frame:SetShown(show)
    if show and cfg.float then
        if not bob:IsPlaying() then bob:Play() end
    else
        bob:Stop()
    end
end

function Ghost:Apply()
    local cfg = ns.cfg.ghost
    frame:SetScale(ns.cfg.scale)
    frame:SetFrameStrata(ns.cfg.strata)
    frame:SetAlpha(ns.cfg.alpha)
    hidden = nil
    local r, g, b, a = ns:GetRingColor(cfg)
    ghost:SetVertexColor(r, g, b, a)
    ghost:SetTexture(ns:ShapeTexture("ghost", cfg.size))
    ghost:SetSize(cfg.size, cfg.size)
    ghost:ClearAllPoints()
    ghost:SetPoint("BOTTOM", frame, "CENTER", 0, cfg.height)
    update()
end

ns:On("PLAYER_DEAD", update)
ns:On("PLAYER_ALIVE", update)
ns:On("PLAYER_UNGHOST", update)
ns:On("PLAYER_ENTERING_WORLD", update)
