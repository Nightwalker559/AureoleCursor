-- Aureole Cursor: the three rings. Main = fixed ring, GCD and Cast = cooldown rings
-- (swipe with ring texture). Times come as duration objects, secret values are never used in calculations.
local ADDON, ns = ...

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

-- Always read the state fresh: if something is running, set the swipe, otherwise clear it.
-- A cast fills up, a channel drains.
local function updateCast()
    if not ns.cfg or not ns.cfg.cast.enabled or not ns:RingActive("cast") then return end
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
    else
        castCD:Clear()
    end
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

-- Main Ring: in combat (if enabled) uses the combat color, with the ring's opacity.
local function applyMainColor()
    local m = ns.cfg.main
    if m.combatTint and ns.inCombat then
        local c = m.combatColor
        mainRing:SetVertexColor(c[1], c[2], c[3], m.color[4] or 1)
    else
        mainRing:SetVertexColor(ns:GetRingColor(m))
    end
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
        local r, g, b = ns:GetRingColor(ring)
        track:SetVertexColor(r, g, b, ring.trackAlpha)
        track:SetShown(active and ring.track)
        cd:SetFrameStrata(strata)
        cd:SetSwipeTexture(ns:RingTexture(ring.thickness, ring.size))
        cd:SetSize(ring.size, ring.size)
        cd:SetSwipeColor(ns:GetRingColor(ring))
        if active then cd:Show() else cd:Clear(); cd:Hide() end
    end
    gcdCD:SetReverse(false)

    updateGCD()
    updateCast()
end
