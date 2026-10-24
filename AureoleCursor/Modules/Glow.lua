-- Aureole Cursor: pointer glow. A soft halo and/or a crisp border in the shape of the game's mouse pointer, drawn behind the
-- rings. It takes the place of the Main Ring (General > Main style). cfg.glow.look chooses halo, border or both.
-- The textures (Media\Glow, see make_glow.py in the tools folder) are the silhouette of Blizzard's pointer, blurred, one
-- per cursor size of the game (Accessibility > Cursor Size); the border textures are the same silhouette as a frame in
-- four widths, at scale 1 so that it hugs the pointer. The halo is only visible around the real pointer, which the
-- game draws on top of everything. It always has the shape of the normal pointer (the game does not tell us when it
-- changes to a sword, bag etc.).
-- While the game hides the pointer (right mouse button held, camera turned with the mouse) a copy of it is drawn at the same
-- spot, so the glow does not hang around an invisible pointer.
local _, ns = ...

local MEDIA = "Interface\\AddOns\\AureoleCursor\\Media\\Glow\\"

-- Cursor size in screen pixels -> edge length of its glow texture (the pointer sits in the middle of it)
local CANVAS = { [32] = 64, [48] = 128, [64] = 128, [96] = 256, [128] = 256 }
-- cursorSizePreferred CVar: -1 = game default, 0..4 = the sizes above
local CVAR_SIZES = { [0] = 32, [1] = 48, [2] = 64, [3] = 96, [4] = 128 }
local DEFAULT_SIZE = 32
-- The glow is this much larger than the pointer (the texture is scaled around the center of the pointer), so the halo is
-- clearly visible. Fixed, it always follows the pointer size.
local GLOW_SCALE = 1.25
ns.GLOW_SCALE = GLOW_SCALE
-- Upper limit of how far the lead may shift the glow, as a share of the pointer size
local LEAD_LIMIT = 0.75

-- The pointer itself: Blizzard's cursor atlas (512 x 256), top left corner of the sprite per cursor size
local ATLAS = "Interface/cursor/UICursor2x"
local SPRITE = { [32] = { 261, 67 }, [48] = { 393, 1 }, [64] = { 261, 1 }, [96] = { 1, 131 }, [128] = { 1, 1 } }

-- The halo and the border are each one texture, or two textures side by side along the gradient direction for two hard-edged
-- color halves (every part shows its slice of the texture, see paint). parts[1] is the halo itself. The border is above it.
local glow = ns.anchor:CreateTexture(nil, "BACKGROUND", nil, -8)
glow:Hide()
ns.glow = glow
local parts = { glow }
ns.glowParts = parts
parts[2] = ns.anchor:CreateTexture(nil, "BACKGROUND", nil, -8)
parts[2]:Hide()
local borderParts = { ns.anchor:CreateTexture(nil, "BACKGROUND", nil, -7), ns.anchor:CreateTexture(nil, "BACKGROUND", nil, -7) }
borderParts[1]:Hide()
borderParts[2]:Hide()
ns.borderParts = borderParts
local COLOR_FIELDS = { "color", "color2" }
local BORDER_LEVELS = 4
-- What is drawn: parts and position (units of the anchor: top left corner relative to the anchor's center, width and height,
-- set in Apply; nil = not drawn)
local layers = { halo = { parts = parts }, border = { parts = borderParts } }

-- The pointer copy is always fully opaque: it ignores the overall opacity of the anchor (only the glow is faded by it).
local icon = ns.anchor:CreateTexture(nil, "OVERLAY", nil, 7)
icon:SetIgnoreParentAlpha(true)
icon:Hide()
ns.pointerIcon = icon

-- Pointer size in screen pixels: the one the game uses (Accessibility > Cursor Size).
local function cursorPixels()
    local cvar = C_CVar and C_CVar.GetCVar and tonumber(C_CVar.GetCVar("cursorSizePreferred"))
    return CVAR_SIZES[cvar] or DEFAULT_SIZE
end

local Glow = {}
ns:RegisterModule(Glow)

-- The copy shows while the game hides the pointer (ns.mouselooking, see Cursor.lua). Since it ignores the anchor's opacity, it
-- is hidden by hand when everything else is invisible (overall opacity 0, e.g. hidden while mouselooking or out of combat).
-- ns:UpdateAlpha calls this on every change of either.
local function updateIcon()
    local cfg = ns.cfg and ns.cfg.glow
    icon:SetShown(cfg and cfg.showWhileLooking and ns:RingActive("glow") and ns.mouselooking
        and ns:CurrentAlpha() > 0 or false)
end
ns.UpdatePointerIcon = updateIcon

-- Shows the glow in its colors: in combat one color, the combat color, if it is switched on (Colors); otherwise
-- one or two colors across the texture, top to bottom or left to right. With the gradient (blend) the two colors are blended
-- (one part), without it each color gets one half (two parts). The border has the same colors as the halo.
local function paintLayer(layer, cfg, r, g, b)
    local geometry = layer.geometry
    local active = geometry and ns:RingActive("glow")
    local combat = ns.cfg.colors.combat.enabled and ns.inCombat
    local count = combat and 1 or math.max(1, math.min(2, cfg.colorCount or 1))
    local n = count == 1 and 1 or (cfg.blend and count - 1 or count)
    local horizontal = cfg.gradientDir == "horizontal"
    local colors = { { r, g, b } }
    for i = 2, count do colors[i] = cfg[COLOR_FIELDS[i]] end

    for i, part in ipairs(layer.parts) do
        if active and i <= n then
            local from, to = (i - 1) / n, i / n -- slice of the texture
            part:ClearAllPoints()
            if horizontal then
                part:SetSize(geometry.w / n, geometry.h)
                part:SetPoint("TOPLEFT", ns.anchor, "CENTER", geometry.x + geometry.w * from, geometry.y)
                part:SetTexCoord(from, to, 0, 1)
            else
                part:SetSize(geometry.w, geometry.h / n)
                part:SetPoint("TOPLEFT", ns.anchor, "CENTER", geometry.x, geometry.y - geometry.h * from)
                part:SetTexCoord(0, 1, from, to)
            end
            local c1, c2 = colors[i], colors[i + 1]
            if cfg.blend and count > 1 then
                local first, second = CreateColor(c1[1], c1[2], c1[3], 1), CreateColor(c2[1], c2[2], c2[3], 1)
                if horizontal then
                    part:SetGradient("HORIZONTAL", first, second) -- the first color is the left one
                else
                    part:SetGradient("VERTICAL", second, first) -- the first color is the top one
                end
            else
                part:SetVertexColor(c1[1], c1[2], c1[3], 1) -- also removes a gradient
            end
            part:Show()
        else
            part:Hide()
        end
    end
end

local function paint()
    local cfg = ns:Palette().glow
    local r, g, b = ns:ElementColor("glow")
    paintLayer(layers.halo, cfg, r, g, b)
    paintLayer(layers.border, cfg, r, g, b)
end

function Glow:UpdateVisibility()
    paint()
end

function Glow:Apply()
    local cfg = ns.cfg.glow
    if not ns:RingActive("glow") then
        layers.halo.geometry, layers.border.geometry = nil, nil
        paint()
        updateIcon()
        return
    end

    local px = cursorPixels()
    local unit = 1 / ns:ScreenPixels(1) -- one screen pixel in units of the anchor
    ns.leadLimit = px * LEAD_LIMIT * unit -- the lead (Cursor.lua) never pulls the glow much farther ahead than this
    -- The pointer's tip is the cursor position (the center of the anchor); its image starts at the top left of the
    -- sprite. The textures have the pointer in their middle, so they are centered on the sprite and grow from there:
    -- the halo larger by GLOW_SCALE, the border at scale 1 (it has to sit right at the pointer's edge).
    local function place(scale)
        local size = CANVAS[px] * scale -- edge length of the texture in pixels
        return {
            x = (cfg.offsetX + (px - size) / 2) * unit, y = (cfg.offsetY - (px - size) / 2) * unit,
            w = size * unit, h = size * unit,
        }
    end
    local look = cfg.look
    layers.halo.geometry = look ~= "border" and place(GLOW_SCALE) or nil
    layers.border.geometry = look ~= "halo" and place(1) or nil
    for _, part in ipairs(parts) do part:SetTexture(MEDIA .. "Glow_" .. px .. ".png") end
    local width = math.max(1, math.min(BORDER_LEVELS, math.floor(cfg.borderWidth or 2)))
    for _, part in ipairs(borderParts) do part:SetTexture(MEDIA .. "Border" .. width .. "_" .. px .. ".png") end
    paint()

    -- Pointer copy: the sprite's top left corner is the cursor position
    local x, y = SPRITE[px][1], SPRITE[px][2]
    icon:SetTexture(ATLAS)
    icon:SetTexCoord(x / 512, (x + px) / 512, y / 256, (y + px) / 256)
    icon:SetSize(px * unit, px * unit)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", ns.anchor, "CENTER", cfg.offsetX * unit, cfg.offsetY * unit)
    updateIcon()
end

-- A change of the game's cursor size picks another texture.
ns:On("CVAR_UPDATE", function(_, name)
    if name == "cursorSizePreferred" and ns.cfg then Glow:Apply() end
end)
