-- Aureole Cursor: Mauspur. Beim Bewegen der Maus entstehen in festem Abstand Punkte, die ausblenden
-- (und schrumpfen). Ein Pool aus Texturen mit Animationsgruppen: Position wird nur beim Erzeugen
-- gesetzt, Ausblenden und Schrumpfen macht die Engine, es laeuft kein Lua pro Punkt und Frame.
local ADDON, ns = ...

local GetCursorPosition = GetCursorPosition
local POOL = 256           -- Punkte, die gleichzeitig sichtbar sein koennen
local MAX_PER_FRAME = 40   -- Obergrenze je Frame; schnelle Mausbewegungen bleiben so lueckenlos, nur Spruenge werden gekappt
local SHRINK_TO = 0.2
local RAINBOW_LENGTH = 400   -- Strecke in Pixeln fuer einmal durch alle Farben
local MIST_SIZE = 3            -- Nebel-Wolken sind so viel groesser als die eingestellte Groesse (sie sollen sich ueberlappen)
local ENERGY_SPAN = 0.5      -- Energie-Form: Anteil der Kachel, den ein Punkt zeigt (Ausschnitt zufaellig)

-- Jahreszeiten-Paletten: jeder Punkt bekommt zufaellig eine der Farben
local PALETTES = {
    autumn = { { 0.85, 0.33, 0.10 }, { 0.95, 0.60, 0.12 }, { 0.70, 0.15, 0.10 }, { 0.90, 0.75, 0.20 }, { 0.50, 0.28, 0.10 } },
    winter = { { 1, 1, 1 }, { 0.85, 0.95, 1 }, { 0.70, 0.86, 1 }, { 0.55, 0.78, 1 } },
    christmas = { { 0.85, 0.10, 0.10 }, { 0.10, 0.60, 0.20 }, { 1, 0.85, 0.30 }, { 1, 1, 1 } },
}

local frame = CreateFrame("Frame", "AureoleCursorTrail", UIParent)
frame:SetSize(1, 1)
frame:EnableMouse(false)
frame:Hide()
ns.trailFrame = frame

local dots, nextDot = {}, 1
ns.trailDots = dots

for i = 1, POOL do
    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:Hide()
    local group = tex:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    local shrink = group:CreateAnimation("Scale")
    shrink:SetScaleFrom(1, 1)
    group:SetScript("OnFinished", function() tex:Hide() end)
    dots[i] = { tex = tex, group = group, fade = fade, shrink = shrink }
end

local lastX, lastY
local rainbow, palette, spin, energy, colorAlpha = false, nil, false, false, 1
local travelled = 0

-- Farbton (0..1) bei voller Saettigung und Helligkeit in RGB
local function hue(h)
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    if i == 0 then return 1, f, 0
    elseif i == 1 then return 1 - f, 1, 0
    elseif i == 2 then return 0, 1, f
    elseif i == 3 then return 0, 1 - f, 1
    elseif i == 4 then return f, 0, 1
    else return 1, 0, 1 - f end
end

-- Energie-Form: Rundmaske je Punkt, erst beim ersten Bedarf angelegt. Die Maske haengt am Punkt und bekommt
-- dieselbe Schrumpf-Animation, damit sie mit dem Punkt mitwaechst (Alpha-Ausblenden betrifft nur die Textur).
local function applyMask(d, t)
    if not d.mask then
        d.mask = frame:CreateMaskTexture()
        d.mask:SetTexture(ns.TRAIL_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        d.mask:SetAllPoints(d.tex)
        d.maskGroup = d.mask:CreateAnimationGroup()
        d.maskShrink = d.maskGroup:CreateAnimation("Scale")
        d.maskShrink:SetScaleFrom(1, 1)
    end
    if not d.masked then
        d.tex:AddMaskTexture(d.mask)
        d.masked = true
    end
    local target = t.shrink and SHRINK_TO or 1
    d.maskShrink:SetDuration(t.duration)
    d.maskShrink:SetScaleTo(target, target)
end

local function removeMask(d)
    if d.masked then
        d.tex:RemoveMaskTexture(d.mask)
        d.masked = false
        d.maskGroup:Stop()
    end
end

local function stopAll()
    for _, d in ipairs(dots) do
        d.group:Stop()
        if d.maskGroup then d.maskGroup:Stop() end
        d.tex:Hide()
    end
end

local function spawn(x, y)
    local d = dots[nextDot]
    nextDot = nextDot % POOL + 1
    d.group:Stop()
    if d.maskGroup then d.maskGroup:Stop() end
    if palette then
        local c = palette[math.random(#palette)]
        d.tex:SetVertexColor(c[1], c[2], c[3], colorAlpha)
    elseif rainbow then
        local r, g, b = hue(travelled / RAINBOW_LENGTH)
        d.tex:SetVertexColor(r, g, b, colorAlpha)
    end
    if spin then d.tex:SetRotation(math.random() * 2 * math.pi) end
    if energy then
        local u, v = math.random(), math.random() -- Kachel ist nahtlos (REPEAT), jeder Punkt zeigt einen anderen Ausschnitt
        d.tex:SetTexCoord(u, u + ENERGY_SPAN, v, v + ENERGY_SPAN)
    end
    d.tex:ClearAllPoints()
    d.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    d.tex:Show()
    d.group:Play()
    if energy and d.maskGroup then d.maskGroup:Play() end
end

frame:SetScript("OnUpdate", function()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    if not lastX then
        lastX, lastY = x, y
        return
    end

    local dx, dy = x - lastX, y - lastY
    local dist = math.sqrt(dx * dx + dy * dy)
    local spacing = ns.cfg.trail.spacing
    if dist < spacing then return end

    local ux, uy = dx / dist, dy / dist
    local n = math.floor(dist / spacing)
    if n > MAX_PER_FRAME then
        -- Sehr schnell oder Sprung (z.B. Alt-Tab): nur die letzten Punkte der Strecke zeichnen
        local skip = (n - MAX_PER_FRAME) * spacing
        lastX, lastY = lastX + ux * skip, lastY + uy * skip
        n = MAX_PER_FRAME
    end
    for i = 1, n do
        travelled = travelled + spacing
        spawn(lastX + ux * spacing * i, lastY + uy * spacing * i)
    end
    lastX, lastY = lastX + ux * spacing * n, lastY + uy * spacing * n
end)

-- Beim Einblenden neu ansetzen (kein Strich von der alten Position), beim Ausblenden aufraeumen.
frame:SetScript("OnShow", function() lastX, lastY = nil, nil end)
frame:SetScript("OnHide", stopAll)

-- Jede Form hat ihre eigene Groesse, Dauer und ihren eigenen Abstand: beim Wechsel werden die aktuellen Werte
-- fuer die alte Form gemerkt und die gemerkten (zuerst die Standardwerte aus cfg.trail.presets) uebernommen.
function ns:SetTrailShape(shape)
    local t = self.cfg.trail
    if t.shape == shape then return end
    t.presets[t.shape] = { size = t.size, duration = t.duration, spacing = t.spacing }
    t.shape = shape
    local p = t.presets[shape]
    if p then t.size, t.duration, t.spacing = p.size, p.duration, p.spacing end
end

local Trail = {}
ns:RegisterModule(Trail)

function Trail:UpdateVisibility()
    local cfg = ns.cfg
    frame:SetShown(cfg.trail.enabled and (not cfg.combatOnly or ns.inCombat))
end

function Trail:Apply()
    local cfg = ns.cfg
    local t = cfg.trail
    frame:SetFrameStrata(cfg.strata)
    ns:UpdateAlpha()

    local size = t.shape == "mist" and t.size * MIST_SIZE or t.size
    local texture = ns:ShapeTexture(t.shape, size)
    -- Farbmodus: bunt oder Jahreszeit (Farbe pro Punkt in spawn), Klassenfarbe oder eigene Farbe
    local r, g, b, a = ns:GetRingColor({ classColor = t.colorMode == "class", color = t.color })
    rainbow, palette, colorAlpha = t.colorMode == "rainbow", PALETTES[t.colorMode], a
    spin = t.shape ~= "dot" and t.shape ~= nil -- Blaetter, Flocken und Sterne liegen zufaellig gedreht
    energy = t.shape == "energy"
    if energy then -- Energie behaelt ihre Originalfarben: Farbmodus und Farbe gelten nicht, nur die Deckkraft
        rainbow, palette, r, g, b = false, nil, 1, 1, 1
    end
    local target = t.shrink and SHRINK_TO or 1
    for _, d in ipairs(dots) do
        if energy then
            d.tex:SetTexture(texture, "REPEAT", "REPEAT")
            applyMask(d, t)
        else
            d.tex:SetTexture(texture)
            d.tex:SetTexCoord(0, 1, 0, 1)
            removeMask(d)
        end
        d.tex:SetSize(size, size)
        d.tex:SetVertexColor(r, g, b, a)
        d.tex:SetRotation(0)
        d.fade:SetDuration(t.duration)
        d.shrink:SetDuration(t.duration)
        d.shrink:SetScaleTo(target, target)
    end
    lastX, lastY = nil, nil
    self:UpdateVisibility()
end
