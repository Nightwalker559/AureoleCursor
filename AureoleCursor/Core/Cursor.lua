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
-- of it, so the glow trails the pointer by a frame or so. lead (glow option, in frames) places the glow ahead along the
-- movement of the last frame by that many frames. The shift is limited softly (ns.leadLimit, set by the glow: about the size
-- of the pointer), otherwise a fast flick would pull the glow far ahead. The delay does not shrink in step with the frame
-- time, so with "by frame rate" on, the lead is picked from a table (leads) by the smoothed frame rate: leads[1] from
-- LEAD_FPS[1] on, leads[2] from LEAD_FPS[2] on, ... and the last one below the last threshold.
-- prevX/prevY: last raw position, nil after a pause.
local lead = 0
local leads, leadOn -- leads: per frame rate step, nil without the frame rate option; leadOn: the glow uses a lead at all
local step, frameTime = 1, nil
local prevX, prevY
local MAX_STEP = 600 -- a jump of more than this many pixels in one frame is no mouse movement (no prediction)
local LEAD_FPS = { 90, 60, 40 } -- step thresholds (frames per second)
local LEAD_MARGIN = 3 -- a step changes only this far past its threshold, so the lead does not flip at the edge
local FRAME_TIME_MAX = 0.1 -- a longer frame (loading screen, hitch) is no measure of the frame rate
local sqrt, abs = math.sqrt, math.abs

-- The game reports when it starts and stops hiding the pointer (looking = mouselook, turning = right mouse button), so
-- nothing is polled per frame. ns.mouselooking is read by the opacity.
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

-- Frame rate step from the smoothed frame time (with a margin, so it stays put near a threshold).
local function updateStep(elapsed)
    if elapsed > FRAME_TIME_MAX then elapsed = FRAME_TIME_MAX end
    frameTime = frameTime and (frameTime + (elapsed - frameTime) * 0.05) or elapsed
    if frameTime <= 0 then return end
    local fps, count = 1 / frameTime, #LEAD_FPS
    while step <= count and fps < LEAD_FPS[step] - LEAD_MARGIN do step = step + 1 end
    while step > 1 and fps >= LEAD_FPS[step - 1] + LEAD_MARGIN do step = step - 1 end
    lead = leads[step]
end

anchor:SetScript("OnUpdate", function(self, elapsed)
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    local px, py = x, y
    if leadOn then
        if leads then updateStep(elapsed or 0) end
        if lead > 0 and prevX and abs(x - prevX) < MAX_STEP and abs(y - prevY) < MAX_STEP then
            local ox, oy = (x - prevX) * lead, (y - prevY) * lead
            local limit = (ns.leadLimit or 0) * scale -- in the units of GetCursorPosition
            if limit > 0 then
                -- soft limit: nearly unchanged for small shifts, approaches `limit` for large ones
                local f = 1 / sqrt(1 + (ox * ox + oy * oy) / (limit * limit))
                ox, oy = ox * f, oy * f
            end
            px, py = x + ox, y + oy
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
    local glow = cfg.glow
    leads, step, frameTime = nil, 1, nil
    if not ns:RingActive("glow") then
        lead = 0
    elseif glow.leadByFps then
        leads = { glow.leadFrames, glow.leadFrames60, glow.leadFrames40, glow.leadFramesLow }
        lead = leads[1]
    else
        lead = glow.leadFrames
    end
    leadOn = lead > 0 or (leads ~= nil and (leads[2] > 0 or leads[3] > 0 or leads[4] > 0))
    self:UpdateVisibility()
end
