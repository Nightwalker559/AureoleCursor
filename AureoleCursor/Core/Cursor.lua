-- Aureole Cursor: cursor anchor. One frame follows the mouse; the rings hang off it.
local _, ns = ...

local GetCursorPosition = GetCursorPosition

local anchor = CreateFrame("Frame", "AureoleCursorAnchor", UIParent)
anchor:SetSize(1, 1)
anchor:EnableMouse(false)
anchor:Hide()
ns.anchor = anchor

-- Only re-anchor when position or scale changed.
local lastX, lastY, lastScale

-- Pointer glow: the game draws its pointer at the very end of the frame, while the glow shows the position read at the start
-- of it, so the glow trails the pointer. lead (milliseconds, glow option) places it ahead by that much of the current
-- mouse speed. prevX/prevY: last raw position, nil after a pause.
local lead = 0
local prevX, prevY
local MAX_STEP = 600 -- a jump of more than this many pixels in one frame is no mouse movement (no prediction)

-- The game reports when it starts and stops hiding the pointer (looking = mouselook, turning = right mouse button), so
-- nothing is polled per frame. ns.mouselooking is read by the opacity and the ghost.
local looking, turning = false, false

local function mouseChanged(isLooking, isTurning)
    return function()
        if isLooking ~= nil then looking = isLooking end
        if isTurning ~= nil then turning = isTurning end
        local state = looking or turning
        if state ~= ns.mouselooking then
            ns.mouselooking = state
            if ns.cfg and ns.cfg.hideOnMouselook then ns:UpdateAlpha() end
        end
    end
end
ns:On("PLAYER_STARTED_LOOKING", mouseChanged(true, nil))
ns:On("PLAYER_STOPPED_LOOKING", mouseChanged(false, nil))
ns:On("PLAYER_STARTED_TURNING", mouseChanged(nil, true))
ns:On("PLAYER_STOPPED_TURNING", mouseChanged(nil, false))
ns:On("PLAYER_ENTERING_WORLD", mouseChanged(false, false))

anchor:SetScript("OnUpdate", function(self, elapsed)
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    local px, py = x, y
    if lead > 0 then
        if prevX and elapsed > 0 and math.abs(x - prevX) < MAX_STEP and math.abs(y - prevY) < MAX_STEP then
            local k = lead / 1000 / math.max(elapsed, 0.002) -- seconds ahead, as a multiple of this frame's movement
            px, py = x + (x - prevX) * k, y + (y - prevY) * k
        end
        prevX, prevY = x, y
    end
    if px ~= lastX or py ~= lastY or scale ~= lastScale then
        lastX, lastY, lastScale = px, py, scale
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px / scale, py / scale)
    end
end)

-- On show, jump to the current position immediately.
anchor:SetScript("OnShow", function()
    lastX, lastY, lastScale = nil, nil, nil
    prevX, prevY = nil, nil
end)

local Cursor = {}
ns:RegisterModule(Cursor)

function Cursor:UpdateVisibility()
    local cfg = ns.cfg
    anchor:SetShown(not cfg.combatOnly or ns.inCombat)
    ns:UpdateAlpha()
end

function Cursor:Apply()
    local cfg = ns.cfg
    anchor:SetScale(cfg.scale)
    anchor:SetFrameStrata(cfg.strata)
    lastX, lastY, lastScale = nil, nil, nil
    prevX, prevY = nil, nil
    lead = ns:RingActive("glow") and cfg.glow.lead or 0
    self:UpdateVisibility()
end
