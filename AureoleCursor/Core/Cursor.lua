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

anchor:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    if x ~= lastX or y ~= lastY or scale ~= lastScale then
        lastX, lastY, lastScale = x, y, scale
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end
end)

-- On show, jump to the current position immediately.
anchor:SetScript("OnShow", function()
    lastX, lastY, lastScale = nil, nil, nil
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
    self:UpdateVisibility()
end
