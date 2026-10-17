-- Aureole Cursor: Kern. Namespace, Einstellungen (mit Defaults), Event-Verteiler, Module, Slash-Befehle.
local ADDON, ns = ...

ns.modules = {}
ns.inCombat = false

ns.defaults = {
    scale = 1.0,
    alpha = 1.0,
    strata = "TOOLTIP",
    combatOnly = false,
    idleAlpha = 1.0,          -- Anteil der Deckkraft ausserhalb des Kampfes
    hideOnMouselook = false,  -- ausblenden, solange die Kamera per Maus gedreht wird
    main = { enabled = true, size = 40, thickness = 4, classColor = false, color = { 1, 1, 1, 0.85 },
             combatTint = true, combatColor = { 1, 0.1, 0.1, 1 } }, -- im Kampf andere Farbe (Deckkraft bleibt)
    gcd  = { enabled = true, size = 28, thickness = 4, classColor = false, color = { 1, 0.82, 0, 1 }, track = true, trackAlpha = 0.25 },
    cast = { enabled = true, size = 40, thickness = 4, classColor = false, color = { 0.4, 0.8, 1, 1 }, track = true, trackAlpha = 0.25 },
    dot  = { enabled = true, size = 8, shape = "dot", classColor = false, color = { 1, 1, 1, 0.9 } },
    trail = { enabled = true, size = 16, duration = 0.45, spacing = 6, shrink = true, shape = "dot", colorMode = "rainbow", color = { 1, 1, 1, 0.5 } },
}

-- Ring-Dicke in Stufen 1..8 (Prozent vom Radius, siehe make_media.py im Tools-Ordner)
ns.MAX_THICKNESS = 8
local MEDIA = "Interface\\AddOns\\AureoleCursor\\Media\\"

-- Texturen gibt es in mehreren Aufloesungen, damit verkleinerte Ringe nicht verpixeln.
-- Gewaehlt wird nach der Groesse in Bildschirm-Pixeln (siehe ns:ScreenPixels).
local RING_RES = { { 80, 64 }, { 160, 128 }, { math.huge, 256 } } -- { bis Pixel, Textur-Aufloesung }
local DOT_RES = { { 20, 16 }, { 40, 32 }, { math.huge, 64 } }

local function pickResolution(list, pixels)
    for _, r in ipairs(list) do
        if pixels <= r[1] then return r[2] end
    end
end

-- Groesse eines Elements in echten Bildschirm-Pixeln (UI-Skalierung und Aufloesung eingerechnet).
function ns:ScreenPixels(size)
    local scale = self.anchor and self.anchor:GetEffectiveScale() or 1
    local height = 768
    if GetPhysicalScreenSize then
        local _, h = GetPhysicalScreenSize()
        if h and h > 0 then height = h end
    end
    return size * scale * height / 768
end

function ns:RingTexture(level, size)
    level = math.max(1, math.min(ns.MAX_THICKNESS, math.floor(level or 4)))
    return MEDIA .. "Ring" .. level .. "_" .. pickResolution(RING_RES, self:ScreenPixels(size or 40)) .. ".tga"
end

function ns:DotTexture(size)
    return MEDIA .. "Dot_" .. pickResolution(DOT_RES, self:ScreenPixels(size or 8)) .. ".tga"
end

-- Formen der Mauspur (Blatt, Flocke, Stern) und des Mittelpunkts (Fadenkreuz, Punkt mit Ring, Funkeln); "dot" ist der normale Punkt.
local SHAPE_RES = { { 30, 32 }, { 60, 64 }, { math.huge, 128 } }
local SHAPE_FILE = { leaf = "Leaf", snow = "Snow", star = "Star", gap = "Gap", ring = "DotRing", spark = "Spark" }

function ns:ShapeTexture(shape, size)
    local file = SHAPE_FILE[shape]
    if not file then return self:DotTexture(size) end
    return MEDIA .. file .. "_" .. pickResolution(SHAPE_RES, self:ScreenPixels(size or 16)) .. ".tga"
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

-- Fehlende Schluessel aus den Defaults ergaenzen, vorhandene Werte nie anfassen.
local function fillDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = copy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            fillDefaults(dst[k], v)
        end
    end
end

function ns:RegisterModule(m)
    self.modules[#self.modules + 1] = m
end

function ns:Apply()
    for _, m in ipairs(self.modules) do
        if m.Apply then m:Apply() end
    end
end

function ns:UpdateVisibility()
    for _, m in ipairs(self.modules) do
        if m.UpdateVisibility then m:UpdateVisibility() end
    end
end

-- Gesamt-Deckkraft: Grundwert, ausserhalb des Kampfes mit idleAlpha, bei Maussteuerung ggf. 0.
function ns:CurrentAlpha()
    local cfg = self.cfg
    if cfg.hideOnMouselook and self.mouselooking then return 0 end
    local a = cfg.alpha
    if not self.inCombat then a = a * cfg.idleAlpha end
    return a
end

function ns:UpdateAlpha()
    local a = self:CurrentAlpha()
    self.anchor:SetAlpha(a)
    if self.trailFrame then self.trailFrame:SetAlpha(a) end
end

function ns:ResetSettings()
    AureoleCursorDB.cfg = copy(self.defaults)
    self.cfg = AureoleCursorDB.cfg
    self:Apply()
end

-- Farbe eines Rings: Klassenfarbe oder eingestellte Farbe (r, g, b, a).
function ns:GetRingColor(ringCfg)
    if ringCfg.classColor and UnitClass then
        local _, class = UnitClass("player")
        local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
        if c then return c.r, c.g, c.b, ringCfg.color[4] or 1 end
    end
    local col = ringCfg.color
    return col[1], col[2], col[3], col[4] or 1
end

------------------------------------------------------------------------
-- Event-Verteiler: ns:On(event, fn [, unit]); mit unit wird RegisterUnitEvent genutzt.
------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

function ns:On(event, fn, unit)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        if unit then frame:RegisterUnitEvent(event, unit) else frame:RegisterEvent(event) end
    end
    list[#list + 1] = fn
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if list then
        for i = 1, #list do list[i](event, ...) end
    end
end)

ns:On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    AureoleCursorDB = AureoleCursorDB or {}
    local db = AureoleCursorDB
    db.runs, db.build = nil, nil -- Reste der Phase-0-Probe
    db.cfg = db.cfg or {}
    local tr = db.cfg.trail
    if tr and tr.colorMode == nil then -- Stand 0.3.x: Haken Klassenfarbe / Bunt
        if tr.classColor then tr.colorMode = "class"
        elseif tr.rainbow == false then tr.colorMode = "custom" end
    end
    if tr then tr.classColor, tr.rainbow = nil, nil end
    fillDefaults(db.cfg, ns.defaults)
    for _, key in ipairs({ "main", "gcd", "cast", "dot" }) do
        db.cfg[key].style = nil -- Rest des entfernten Kantenstils
    end
    ns.cfg = db.cfg
end)

ns:On("PLAYER_ENTERING_WORLD", function()
    ns.inCombat = InCombatLockdown() and true or false
    ns:Apply()
end)

ns:On("PLAYER_REGEN_DISABLED", function()
    ns.inCombat = true
    ns:UpdateVisibility()
end)

ns:On("PLAYER_REGEN_ENABLED", function()
    ns.inCombat = false
    ns:UpdateVisibility()
end)

------------------------------------------------------------------------
-- Slash-Befehle (Zwischenloesung, bis die Config-Oberflaeche Schritt fuer Schritt entsteht)
------------------------------------------------------------------------

local L = ns.L
local PREFIX = "|cff66ccffAureole Cursor|r "
local RINGS = { main = true, gcd = true, cast = true, dot = true, trail = true }

local function say(...)
    print(PREFIX .. string.format(...))
end

local function onOff(s)
    if s == "on" then return true end
    if s == "off" then return false end
end

SLASH_AUREOLECURSOR1 = "/aureole"
SLASH_AUREOLECURSOR2 = "/aureolecursor"
SLASH_AUREOLECURSOR3 = "/ac"
SlashCmdList["AUREOLECURSOR"] = function(msg)
    local cfg = ns.cfg
    if not cfg then return end
    local args = {}
    for w in string.gmatch(strlower(msg or ""), "%S+") do args[#args + 1] = w end
    local cmd = args[1]

    if cmd == "scale" and tonumber(args[2]) then
        cfg.scale = math.max(0.3, math.min(5, tonumber(args[2])))
        ns:Apply()
    elseif cmd == "alpha" and tonumber(args[2]) then
        cfg.alpha = math.max(0.05, math.min(1, tonumber(args[2])))
        ns:Apply()
    elseif cmd == "combat" and onOff(args[2]) ~= nil then
        cfg.combatOnly = onOff(args[2])
        ns:Apply()
    elseif cmd == "ring" and RINGS[args[2]] then
        local ring = cfg[args[2]]
        if onOff(args[3]) ~= nil then
            ring.enabled = onOff(args[3])
        elseif args[3] == "size" and tonumber(args[4]) then
            ring.size = math.max(8, math.min(512, tonumber(args[4])))
        else
            say(L.slashRingUsage, args[2])
            return
        end
        ns:Apply()
    elseif cmd == nil or cmd == "config" or cmd == "options" then
        -- ohne Argument direkt die Einstellungen oeffnen (kurzer Weg: /ac)
        if ns.OpenSettings then ns:OpenSettings() end
        return
    elseif cmd == "reset" then
        ns:ResetSettings()
        say(L.slashReset)
        return
    else
        say(L.slashStatus, cfg.scale, cfg.alpha, cfg.combatOnly and L.yes or L.no)
        for _, name in ipairs({ "main", "gcd", "cast", "dot", "trail" }) do
            say(L.slashElement, name, cfg[name].enabled and L.stateOn or L.stateOff, cfg[name].size)
        end
        say(L.slashHelp)
    end
end
