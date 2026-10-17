-- Aureole Cursor: settings row with several color swatches side by side (the Blizzard color row holds only one).
-- Template: ColorRow.xml. Row data (Settings.CreateElementInitializer):
--   name, tooltip  = label and tooltip of the row
--   entries        = { { setting = <proxy setting with an ARGB hex string>, name = ..., tooltip = ... }, ... }
--   count          = function() -> number of swatches to show (the others are hidden)
-- Modeled on SettingsColorSwatchControlMixin in Blizzard_SettingControls.lua.
if not (SettingsListElementMixin and SettingsColorSwatchMixin and CreateFromMixins) then return end

local SWATCH_SPACING = 26

AureoleCursorColorRowMixin = CreateFromMixins(SettingsListElementMixin)

function AureoleCursorColorRowMixin:OnLoad()
    SettingsListElementMixin.OnLoad(self)
    self.swatches = {}
end

function AureoleCursorColorRowMixin:Init(initializer)
    SettingsListElementMixin.Init(self, initializer)
    for i, entry in ipairs(self.data.entries) do
        local swatch = self.swatches[i]
        if not swatch then
            swatch = CreateFrame("Button", nil, self, "SettingsColorSwatchTemplate")
            swatch:SetPoint("LEFT", self, "CENTER", -73 + (i - 1) * SWATCH_SPACING, 0)
            self.swatches[i] = swatch
        end
        local setting = entry.setting
        local function currentColor() return CreateColorFromHexString(setting:GetValue()) end
        swatch:Init(setting:GetValue(), function() Settings.InitTooltip(entry.name, entry.tooltip) end, currentColor)
        self.cbrHandles:RegisterCallback(swatch, SettingsColorSwatchMixin.Event.OnValueChanged,
            function(_, value) setting:SetValue(value) end, self)
        -- e.g. after "Defaults" the setting changes from outside: show the new color
        self.cbrHandles:SetOnValueChangedCallback(setting:GetVariable(), function(_, _, value) swatch:SetValue(value) end, self)
    end
    self:EvaluateState()
end

function AureoleCursorColorRowMixin:Release()
    for _, swatch in ipairs(self.swatches) do swatch:Release() end
    SettingsListElementMixin.Release(self)
end

function AureoleCursorColorRowMixin:EvaluateState()
    SettingsListElementMixin.EvaluateState(self)
    local initializer = self:GetElementData()
    self:DisplayEnabled(initializer:EvaluateModifyPredicates())
    local count = self.data.count()
    for i, swatch in ipairs(self.swatches) do swatch:SetShown(i <= count) end
end
