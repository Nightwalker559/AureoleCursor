-- Aureole Cursor: preview row of the mouse trail on the settings page: a short line of dots in the shape, size and colors the
-- trail uses with the current settings (ns:TrailPreview in Trail.lua). The newest dot is on the right, the way the trail
-- runs when the cursor moves to the right. The row redraws on every settings change (Trail:Apply calls ns:RefreshTrailPreview).
-- Template: TrailPreview.xml. Row data (Settings.CreateElementInitializer): name, tooltip = label and tooltip of the row.
if not (SettingsListElementMixin and CreateFromMixins) then return end

local _, ns = ...

local STEP = 24          -- distance between two dots in pixels
local MAX_SIZE = 36      -- largest dot in the preview (bigger trail sizes are scaled down)
local RIGHT_EDGE = 140   -- position of the newest dot, in pixels right of the middle of the row

AureoleCursorTrailPreviewMixin = CreateFromMixins(SettingsListElementMixin)

-- The rows that are on screen right now (the list reuses a few frames)
local active = {}

function AureoleCursorTrailPreviewMixin:OnLoad()
    SettingsListElementMixin.OnLoad(self)
    self.dots, self.masks, self.masked = {}, {}, {}
end

function AureoleCursorTrailPreviewMixin:Init(initializer)
    SettingsListElementMixin.Init(self, initializer)
    active[self] = true
    self:EvaluateState()
end

function AureoleCursorTrailPreviewMixin:Release()
    active[self] = nil
    SettingsListElementMixin.Release(self)
end

function AureoleCursorTrailPreviewMixin:EvaluateState()
    SettingsListElementMixin.EvaluateState(self)
    local initializer = self:GetElementData()
    local enabled = initializer:EvaluateModifyPredicates()
    self:DisplayEnabled(enabled)
    self.enabled = enabled
    self:Refresh()
end

function AureoleCursorTrailPreviewMixin:Refresh()
    local preview = ns:TrailPreview()
    local shown = math.min(preview.size, MAX_SIZE)
    local k = shown / preview.size -- everything that depends on the size is scaled by the same factor
    for i, d in ipairs(preview.dots) do
        local tex = self.dots[i]
        if not tex then
            tex = self:CreateTexture(nil, "ARTWORK")
            self.dots[i] = tex
        end
        local x = RIGHT_EDGE - (i - 1) * STEP + d.x * k
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", self, "CENTER", x, d.y * k)
        tex:SetSize(shown * d.scale, shown * d.scale)
        if preview.energy then
            tex:SetTexture(preview.texture, "REPEAT", "REPEAT")
            if not self.masks[i] then
                self.masks[i] = self:CreateMaskTexture()
                self.masks[i]:SetTexture(ns.TRAIL_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                self.masks[i]:SetAllPoints(tex)
            end
            if not self.masked[i] then
                tex:AddMaskTexture(self.masks[i])
                self.masked[i] = true
            end
            tex:SetTexCoord(0, 0.5, 0, 0.5)
        else
            tex:SetTexture(preview.texture)
            tex:SetTexCoord(0, 1, 0, 1)
            if self.masked[i] then
                tex:RemoveMaskTexture(self.masks[i])
                self.masked[i] = false
            end
        end
        tex:SetRotation(d.rotation)
        tex:SetBlendMode(preview.add and "ADD" or "BLEND")
        tex:SetVertexColor(d.r, d.g, d.b, d.alpha * (self.enabled and 1 or 0.35))
        tex:Show()
    end
end

-- Called after every settings change
function ns:RefreshTrailPreview()
    for row in pairs(active) do row:Refresh() end
end
