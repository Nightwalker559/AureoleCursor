-- NW_CursorRing: Cursor-Anker. Ein Frame folgt der Maus; die Ringe haengen daran.
local ADDON, ns = ...

local GetCursorPosition = GetCursorPosition

local anchor = CreateFrame("Frame", "NW_CursorRingAnchor", UIParent)
anchor:SetSize(1, 1)
anchor:EnableMouse(false)
anchor:Hide()
ns.anchor = anchor

-- Nur neu setzen, wenn sich Position oder Skalierung geaendert haben.
local lastX, lastY, lastScale

anchor:SetScript("OnUpdate", function(self)
    if ns.cfg.hideOnMouselook then
        local looking = IsMouselooking() and true or false
        if looking ~= ns.mouselooking then
            ns.mouselooking = looking
            ns:UpdateAlpha()
        end
    end
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    if x ~= lastX or y ~= lastY or scale ~= lastScale then
        lastX, lastY, lastScale = x, y, scale
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end
end)

-- Beim Einblenden sofort an die aktuelle Position springen.
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
    if not cfg.hideOnMouselook then ns.mouselooking = false end
    anchor:SetFrameStrata(cfg.strata)
    lastX, lastY, lastScale = nil, nil, nil
    self:UpdateVisibility()
end
