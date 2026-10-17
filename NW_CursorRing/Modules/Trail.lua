-- NW_CursorRing: Mauspur. Beim Bewegen der Maus entstehen in festem Abstand Punkte, die ausblenden
-- (und schrumpfen). Ein Pool aus Texturen mit Animationsgruppen: Position wird nur beim Erzeugen
-- gesetzt, Ausblenden und Schrumpfen macht die Engine, es laeuft kein Lua pro Punkt und Frame.
local ADDON, ns = ...

local GetCursorPosition = GetCursorPosition
local POOL = 256           -- Punkte, die gleichzeitig sichtbar sein koennen
local MAX_PER_FRAME = 40   -- Obergrenze je Frame; schnelle Mausbewegungen bleiben so lueckenlos, nur Spruenge werden gekappt
local SHRINK_TO = 0.2
local RAINBOW_LENGTH = 400   -- Strecke in Pixeln fuer einmal durch alle Farben

local frame = CreateFrame("Frame", "NW_CursorRingTrail", UIParent)
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
local rainbow, rainbowAlpha = false, 1
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

local function stopAll()
    for _, d in ipairs(dots) do
        d.group:Stop()
        d.tex:Hide()
    end
end

local function spawn(x, y)
    local d = dots[nextDot]
    nextDot = nextDot % POOL + 1
    d.group:Stop()
    if rainbow then
        local r, g, b = hue(travelled / RAINBOW_LENGTH)
        d.tex:SetVertexColor(r, g, b, rainbowAlpha)
    end
    d.tex:ClearAllPoints()
    d.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    d.tex:Show()
    d.group:Play()
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

    local texture = ns:DotTexture(t.size)
    -- Farbmodus: bunt (Farbton pro Punkt in spawn), Klassenfarbe oder eigene Farbe
    local r, g, b, a = ns:GetRingColor({ classColor = t.colorMode == "class", color = t.color })
    rainbow, rainbowAlpha = t.colorMode == "rainbow", a
    local target = t.shrink and SHRINK_TO or 1
    for _, d in ipairs(dots) do
        d.tex:SetTexture(texture)
        d.tex:SetSize(t.size, t.size)
        d.tex:SetVertexColor(r, g, b, a)
        d.fade:SetDuration(t.duration)
        d.shrink:SetDuration(t.duration)
        d.shrink:SetScaleTo(target, target)
    end
    lastX, lastY = nil, nil
    self:UpdateVisibility()
end
