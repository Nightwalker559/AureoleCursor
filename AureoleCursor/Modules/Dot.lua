-- Aureole Cursor: Mittelpunkt (Dot) im Zentrum der Ringe.
local ADDON, ns = ...

local dot = ns.anchor:CreateTexture(nil, "OVERLAY")
dot:SetTexture(ns:DotTexture(8))
dot:SetPoint("CENTER", ns.anchor, "CENTER")
ns.dot = dot

local Dot = {}
ns:RegisterModule(Dot)

function Dot:Apply()
    local cfg = ns.cfg.dot
    dot:SetTexture(ns:DotTexture(cfg.size))
    dot:SetSize(cfg.size, cfg.size)
    dot:SetVertexColor(ns:GetRingColor(cfg))
    dot:SetShown(cfg.enabled)
end
