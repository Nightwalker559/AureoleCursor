-- Aureole Cursor: pointer glow. A soft halo in the shape of the game's mouse pointer, drawn behind the rings. It takes
-- the place of the Main Ring (General > Main style).
-- The textures (Media\Glow, see make_glow.py in the tools folder) are the silhouette of Blizzard's pointer, blurred, one
-- per cursor size of the game (Accessibility > Cursor Size). The halo is only visible around the real pointer, which the
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

-- The pointer itself: Blizzard's cursor atlas (512 x 256), top left corner of the sprite per cursor size
local ATLAS = "Interface/cursor/UICursor2x"
local SPRITE = { [32] = { 261, 67 }, [48] = { 393, 1 }, [64] = { 261, 1 }, [96] = { 1, 131 }, [128] = { 1, 1 } }

local glow = ns.anchor:CreateTexture(nil, "BACKGROUND", nil, -8)
glow:Hide()
ns.glow = glow

local icon = ns.anchor:CreateTexture(nil, "OVERLAY", nil, 7)
icon:Hide()
ns.pointerIcon = icon

-- Pointer size in screen pixels: the configured one, or the one the game uses.
local function cursorPixels()
    local choice = tonumber(ns.cfg.glow.cursorSize)
    if choice and CANVAS[choice] then return choice end
    local cvar = C_CVar and C_CVar.GetCVar and tonumber(C_CVar.GetCVar("cursorSizePreferred"))
    return CVAR_SIZES[cvar] or DEFAULT_SIZE
end

local Glow = {}
ns:RegisterModule(Glow)

-- The game reports when it starts and stops hiding the pointer (looking = mouselook, turning = right mouse button).
local looking, turning = false, false

local function updateIcon()
    local cfg = ns.cfg and ns.cfg.glow
    icon:SetShown(cfg and cfg.showWhileLooking and ns:RingActive("glow") and (looking or turning) or false)
end

-- Color of the glow: in combat the combat color if it is switched on for the glow (General).
local function applyColor()
    glow:SetVertexColor(ns:ElementColor("glow"))
end

function Glow:UpdateVisibility()
    applyColor()
end

function Glow:Apply()
    local cfg = ns.cfg.glow
    local active = ns:RingActive("glow")
    glow:SetShown(active)
    if not active then
        updateIcon()
        return
    end

    local px = cursorPixels()
    local canvas = CANVAS[px]
    local pad = (canvas - px) / 2
    local unit = 1 / ns:ScreenPixels(1) -- one screen pixel in units of the anchor
    glow:SetTexture(MEDIA .. "Glow_" .. px .. ".tga")
    glow:SetSize(canvas * unit, canvas * unit)
    -- The pointer's tip is the cursor position (the center of the anchor); its image starts at the top left of the
    -- sprite, so the texture reaches pad pixels further to the left and up.
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", ns.anchor, "CENTER", (cfg.offsetX - pad) * unit, (cfg.offsetY + pad) * unit)
    applyColor()

    -- Pointer copy: the sprite's top left corner is the cursor position
    local x, y = SPRITE[px][1], SPRITE[px][2]
    icon:SetTexture(ATLAS)
    icon:SetTexCoord(x / 512, (x + px) / 512, y / 256, (y + px) / 256)
    icon:SetSize(px * unit, px * unit)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", ns.anchor, "CENTER", cfg.offsetX * unit, cfg.offsetY * unit)
    updateIcon()
end

local function lookChanged(isLooking, isTurning)
    return function()
        if isLooking ~= nil then looking = isLooking end
        if isTurning ~= nil then turning = isTurning end
        updateIcon()
    end
end
ns:On("PLAYER_STARTED_LOOKING", lookChanged(true, nil))
ns:On("PLAYER_STOPPED_LOOKING", lookChanged(false, nil))
ns:On("PLAYER_STARTED_TURNING", lookChanged(nil, true))
ns:On("PLAYER_STOPPED_TURNING", lookChanged(nil, false))
ns:On("PLAYER_ENTERING_WORLD", lookChanged(false, false))

-- A change of the game's cursor size picks another texture.
ns:On("CVAR_UPDATE", function(_, name)
    if name == "cursorSizePreferred" and ns.cfg then Glow:Apply() end
end)
