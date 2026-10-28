-- Aureole Cursor: animation helpers shared by the mouse trail and the click effects (pulse of the center dot, wave of the
-- Main Ring). All animations run in the engine, Lua only starts them.
local _, ns = ...

-- Animation group of a region that fades it out and scales it (the end scale is set by the caller) and hides it when done.
-- Returns the group, its alpha animation and its scale animation.
function ns:FadeGroup(region)
    local group = region:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    local scale = group:CreateAnimation("Scale")
    scale:SetScaleFrom(1, 1)
    group:SetScript("OnFinished", function() region:Hide() end)
    return group, fade, scale
end

-- Mouse buttons a click effect reacts to: "left", "right" or "both" (the setting) against the button name of the event.
local CLICK_BUTTONS = {
    left = { LeftButton = true },
    right = { RightButton = true },
    both = { LeftButton = true, RightButton = true },
}

-- A ring that grows and fades out for `time` seconds on a click; the caller sets texture, size and the scale from/to. The
-- switch and the button of the effect are cfg[key][field] and cfg[key][buttonField]; it only plays while the element is
-- in use (ns:RingActive) and the cursor is shown. Returns the texture, the animation group and the scale animation.
function ns:CreateBurst(time, key, field, buttonField)
    local anchor = self.anchor
    local tex = anchor:CreateTexture(nil, "OVERLAY")
    tex:SetPoint("CENTER", anchor, "CENTER")
    tex:Hide()
    local group, fade, scale = self:FadeGroup(tex)
    fade:SetDuration(time)
    scale:SetDuration(time)
    self:On("GLOBAL_MOUSE_DOWN", function(_, button)
        local cfg = self.cfg and self.cfg[key]
        if not cfg or not cfg.enabled or not cfg[field] or not self:RingActive(key) then return end
        local buttons = CLICK_BUTTONS[cfg[buttonField]]
        if not (buttons and buttons[button]) or not anchor:IsShown() then return end
        group:Stop()
        tex:Show()
        group:Play()
    end)
    return tex, group, scale
end
