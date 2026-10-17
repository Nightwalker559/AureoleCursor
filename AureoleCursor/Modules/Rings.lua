-- Aureole Cursor: die drei Ringe. Main = fester Ring, GCD und Cast = Cooldown-Ringe
-- (Swipe mit Ring-Textur). Zeiten kommen als Duration-Objekte, es wird nie mit Secret-Werten gerechnet.
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

-- Hintergrund-Spur: schwacher Vollring hinter dem Fortschritts-Ring (liegt unter den Cooldown-Frames).
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

-- Laeuft der GCD, den Swipe aus dem Duration-Objekt des GCD-Spells setzen.
-- Ist er vorbei, endet der Swipe von selbst.
local function updateGCD()
    if not ns.cfg or not ns.cfg.gcd.enabled then return end
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

-- Zustand immer frisch lesen: laeuft etwas, Swipe setzen, sonst loeschen.
-- Cast fuellt sich auf, Channel leert sich.
local function updateCast()
    if not ns.cfg or not ns.cfg.cast.enabled then return end
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
-- Einstellungen anwenden
------------------------------------------------------------------------

local Rings = {}
ns:RegisterModule(Rings)

-- Aendert sich die Pixelgroesse (UI-Skalierung, Aufloesung), passt die Textur-Aufloesung neu.
local function reapply()
    if ns.cfg then ns:Apply() end
end
ns:On("UI_SCALE_CHANGED", reapply)
ns:On("DISPLAY_SIZE_CHANGED", reapply)

-- Main Ring: im Kampf (wenn eingestellt) in der Kampffarbe, mit der Deckkraft des Rings.
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

    for _, trio in ipairs({ { gcdCD, cfg.gcd, gcdTrack }, { castCD, cfg.cast, castTrack } }) do
        local cd, ring, track = trio[1], trio[2], trio[3]
        track:SetTexture(ns:RingTexture(ring.thickness, ring.size))
        track:SetSize(ring.size, ring.size)
        local r, g, b = ns:GetRingColor(ring)
        track:SetVertexColor(r, g, b, ring.trackAlpha)
        track:SetShown(ring.enabled and ring.track)
        cd:SetFrameStrata(strata)
        cd:SetSwipeTexture(ns:RingTexture(ring.thickness, ring.size))
        cd:SetSize(ring.size, ring.size)
        cd:SetSwipeColor(ns:GetRingColor(ring))
        if ring.enabled then cd:Show() else cd:Clear(); cd:Hide() end
    end
    gcdCD:SetReverse(false)

    updateGCD()
    updateCast()
end
