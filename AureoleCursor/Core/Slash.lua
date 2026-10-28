-- Aureole Cursor: slash commands (the settings page is the main UI; these are shortcuts).
local _, ns = ...

local L = ns.L
local PREFIX = "|cff66ccffAureole Cursor|r "
local RINGS = { main = true, gcd = true, cast = true, dot = true, trail = true }
-- Limits of the shortcuts: the same ranges as the sliders on the settings page (Options.lua)
local MIN_SCALE, MAX_SCALE, MIN_ALPHA = 0.5, 3, 0.1
local SIZE_LIMITS = { trail = { 4, 64 } }
local DEFAULT_SIZE_LIMITS = { 8, 400 }

local function say(...)
    print(PREFIX .. string.format(...))
end

local function onOff(s)
    if s == "on" then return true end
    if s == "off" then return false end
end

SLASH_AUREOLECURSOR1 = "/aureole"
SLASH_AUREOLECURSOR2 = "/aureolecursor"
SLASH_AUREOLECURSOR3 = "/ac"
SlashCmdList["AUREOLECURSOR"] = function(msg)
    local cfg = ns.cfg
    if not cfg then return end
    local args = {}
    for w in string.gmatch(strlower(msg or ""), "%S+") do args[#args + 1] = w end
    local cmd = args[1]

    if cmd == "scale" and tonumber(args[2]) then
        cfg.scale = math.max(MIN_SCALE, math.min(MAX_SCALE, tonumber(args[2])))
        ns:Apply()
    elseif cmd == "alpha" and tonumber(args[2]) then
        cfg.alpha = math.max(MIN_ALPHA, math.min(1, tonumber(args[2])))
        ns:Apply()
    elseif cmd == "combat" and onOff(args[2]) ~= nil then
        cfg.combatOnly = onOff(args[2])
        ns:Apply()
    elseif cmd == "ring" and RINGS[args[2]] then
        local ring = cfg[args[2]]
        if onOff(args[3]) ~= nil then
            ring.enabled = onOff(args[3])
        elseif args[3] == "size" and tonumber(args[4]) then
            local limits = SIZE_LIMITS[args[2]] or DEFAULT_SIZE_LIMITS
            ring.size = math.max(limits[1], math.min(limits[2], tonumber(args[4])))
        else
            say(L.slashRingUsage, args[2])
            return
        end
        ns:Apply()
    elseif cmd == nil or cmd == "config" or cmd == "options" then
        -- without arguments, open the settings directly (shortcut: /ac)
        if ns.OpenSettings then ns:OpenSettings() end
        return
    elseif cmd == "reset" then
        ns:ResetSettings()
        say(L.slashReset)
        return
    else
        say(L.slashStatus, cfg.scale, cfg.alpha, cfg.combatOnly and L.yes or L.no)
        for _, name in ipairs({ "main", "gcd", "cast", "dot", "trail" }) do
            say(L.slashElement, name, cfg[name].enabled and L.stateOn or L.stateOff, cfg[name].size)
        end
        say(L.slashHelp)
    end
end
