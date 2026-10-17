-- Aureole Cursor: Glow, ein weicher Lichtschein hinter dem Mauszeiger. Er haengt nur an der Mausposition,
-- wirkt also bei jeder Cursor-Form (Pfeil, Schwert, Zahnrad ...). Der echte Cursor liegt immer darueber.
local ADDON, ns = ...

local GLOW_TEXTURE = "Interface\\AddOns\\AureoleCursor\\Media\\Glow_128.tga"

-- Unterste Ebene des Ankers: der Glow liegt hinter Spuren, Ringen und Mittelpunkt.
local glow = ns.anchor:CreateTexture(nil, "BACKGROUND", nil, -8)
glow:SetTexture(GLOW_TEXTURE)
ns.glow = glow

local Glow = {}
ns:RegisterModule(Glow)

function Glow:Apply()
    local cfg = ns.cfg.glow
    glow:SetSize(cfg.size, cfg.size)
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", ns.anchor, "CENTER", cfg.offsetX, cfg.offsetY)
    glow:SetVertexColor(ns:GetRingColor(cfg))
    glow:SetShown(cfg.enabled)
end
