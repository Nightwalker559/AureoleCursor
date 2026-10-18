-- Aureole Cursor: the three rings. Main = fixed ring, GCD and Cast = cooldown rings
-- (swipe with ring texture). Times come as duration objects, secret values are never used in calculations.
local _, ns = ...

local DEFAULT_RING_TEXTURE = ns:RingTexture(4)
local GCD_SPELL = 61304

local anchor = ns.anchor

local function createCooldown(level)
    local cd = CreateFrame("Cooldown", nil, anchor)
    cd:SetPoint("CENTER", anchor, "CENTER")
    cd:SetFrameLevel(anchor:GetFrameLevel() + level)
    cd:SetSwipeTexture(DEFAULT_RING_TEXTURE)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd:SetHideCountdownNumbers(true)
    cd.noCooldownCount = true
    cd:EnableMouse(false)
    return cd
end

local mainRing = anchor:CreateTexture(nil, "ARTWORK")
mainRing:SetTexture(DEFAULT_RING_TEXTURE)
mainRing:SetPoint("CENTER", anchor, "CENTER")
ns.mainRing = mainRing

-- Background track: faint full ring behind the progress ring (sits below the cooldown frames).
local function createTrack()
    local t = anchor:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(DEFAULT_RING_TEXTURE)
    t:SetPoint("CENTER", anchor, "CENTER")
    return t
end

local gcdTrack = createTrack()
local castTrack = createTrack()
ns.gcdTrack, ns.castTrack = gcdTrack, castTrack

local gcdCD = createCooldown(1)
local castCD = createCooldown(2)
ns.gcdCooldown, ns.castCooldown = gcdCD, castCD

------------------------------------------------------------------------
-- GCD
------------------------------------------------------------------------

-- While the GCD is running, set the swipe from the duration object of the GCD spell.
-- Once it is over, the swipe ends by itself.
local function updateGCD()
    if not ns.cfg or not ns.cfg.gcd.enabled or not ns:RingActive("gcd") then return end
    local info = C_Spell.GetSpellCooldown(GCD_SPELL)
    if info and info.isActive then
        local d = C_Spell.GetSpellCooldownDuration(GCD_SPELL)
        if d then gcdCD:SetCooldownFromDurationObject(d) end
    end
end

ns:On("UNIT_SPELLCAST_SENT", updateGCD, "player")
ns:On("SPELL_UPDATE_COOLDOWN", updateGCD)

------------------------------------------------------------------------
-- Cast / Channel / Empower
------------------------------------------------------------------------

-- Gradient (cast ring): the swipe color moves from color to color2 while the cast progresses. The color comes from a
-- color curve evaluated against the cast's duration object, so no secret values are ever read or calculated with.
local castCurve, castDuration

local castDriver = CreateFrame("Frame", nil, anchor)
castDriver:Hide()
ns.castDriver = castDriver

-- The result may be a color object or plain r, g, b, a values.
local function unpackColor(c, g, b, a)
    if g == nil and c ~= nil and type(c) ~= "number" then
        if c.GetRGBA then return c:GetRGBA() end
        return c.r, c.g, c.b, c.a
    end
    return c, g, b, a
end

local function tickCast()
    if not (castDuration and castCurve) then return end
    local ok, c, g, b, a = pcall(castDuration.EvaluateElapsedPercent, castDuration, castCurve)
    if not ok then -- the API does not behave as expected: keep the static start color, do not retry every frame
        castCurve = nil
        castDriver:Hide()
        return
    end
    local r, g2, b2, a2 = unpackColor(c, g, b, a)
    if r then castCD:SetSwipeColor(r, g2, b2, a2) end
end
castDriver:SetScript("OnUpdate", tickCast)

-- Always read the state fresh: if something is running, set the swipe, otherwise clear it.
-- A cast fills up, a channel drains.
local function updateCast()
    if not ns.cfg or not ns.cfg.cast.enabled or not ns:RingActive("cast") then
        castDuration = nil
        castDriver:Hide()
        return
    end
    local d = UnitCastingDuration("player")
    local channel = false
    if not d then
        d = UnitChannelDuration("player")
        channel = d ~= nil
    end
    if not d and UnitEmpoweredChannelDuration then
        d = UnitEmpoweredChannelDuration("player")
        channel = d ~= nil
    end
    if d then
        castCD:SetReverse(not channel)
        castCD:SetCooldownFromDurationObject(d)
        castDuration = d
        if castCurve then
            castDriver:Show()
            tickCast()
        end
    else
        castCD:Clear()
        castDuration = nil
        castDriver:Hide()
    end
end

local function buildCastCurve(ring)
    if not (ring.gradient and C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local c1, c2, a = ring.color, ring.color2, ring.color[4] or 1
    local curve = C_CurveUtil.CreateColorCurve()
    if Enum and Enum.LuaCurveType and curve.SetType then curve:SetType(Enum.LuaCurveType.Linear) end
    curve:AddPoint(0, CreateColor(c1[1], c1[2], c1[3], a))
    curve:AddPoint(1, CreateColor(c2[1], c2[2], c2[3], a))
    return curve
end

for _, event in ipairs({
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP",
}) do
    ns:On(event, updateCast, "player")
end

------------------------------------------------------------------------
-- Apply settings
------------------------------------------------------------------------

local Rings = {}
ns:RegisterModule(Rings)

-- If the pixel size changes (UI scale, resolution), the texture resolution has to be re-picked.
local function reapply()
    if ns.cfg then ns:Apply() end
end
ns:On("UI_SCALE_CHANGED", reapply)
ns:On("DISPLAY_SIZE_CHANGED", reapply)

-- Main Ring: in combat it uses the combat color if that is switched on for the ring (General), with the ring's opacity.
local function applyMainColor()
    mainRing:SetVertexColor(ns:ElementColor("main"))
end

function Rings:UpdateVisibility()
    applyMainColor()
end

function Rings:Apply()
    local cfg = ns.cfg
    local strata = cfg.strata

    local m = cfg.main
    mainRing:SetTexture(ns:RingTexture(m.thickness, m.size))
    mainRing:SetSize(m.size, m.size)
    applyMainColor()
    mainRing:SetShown(m.enabled)

    for _, trio in ipairs({ { gcdCD, cfg.gcd, gcdTrack, "gcd" }, { castCD, cfg.cast, castTrack, "cast" } }) do
        local cd, ring, track = trio[1], trio[2], trio[3]
        local active = ring.enabled and ns:RingActive(trio[4]) -- the ring layout can switch a ring off
        track:SetTexture(ns:RingTexture(ring.thickness, ring.size))
        track:SetSize(ring.size, ring.size)
        local r, g, b, a = ns:GetRingColor(ring)
        track:SetVertexColor(r, g, b, ring.trackAlpha)
        track:SetShown(active and ring.track)
        cd:SetFrameStrata(strata)
        cd:SetSwipeTexture(ns:RingTexture(ring.thickness, ring.size))
        cd:SetSize(ring.size, ring.size)
        cd:SetSwipeColor(r, g, b, a)
        if active then cd:Show() else cd:Clear(); cd:Hide() end
    end
    gcdCD:SetReverse(false)

    castCurve = buildCastCurve(cfg.cast)
    if not castCurve then castDriver:Hide() end
    updateGCD()
    updateCast()
end
