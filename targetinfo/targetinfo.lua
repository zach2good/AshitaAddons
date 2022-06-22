addon.name      = 'targetinfo'
addon.author    = 'zach2good'
addon.version   = '1.0'
addon.desc      = 'On-screen info about your current target.'
addon.link      = ''

require('common')
local imgui = require('imgui')

local state =
{
    running       = true,
    loop_interval = 0.1,
    last_tick     = 0,

    target = nil,
}

local WHITE = { 1.0,  1.0,  1.0, 1.0 }
local CORAL = { 1.0, 0.65, 0.26, 1.0 }

local function tick()
    state.target = GetEntity(AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0))
end

local function draw_ui()
    if state.target == nil then
        return
    end

    local flags = bit.bor(
     ImGuiWindowFlags_NoDecoration,
    ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav)

    imgui.SetNextWindowBgAlpha(0.6)
    imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always)
    imgui.SetNextWindowSizeConstraints({ -1, -1, }, { FLT_MAX, FLT_MAX, })

    local index     = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0)
    local name      = AshitaCore:GetMemoryManager():GetEntity():GetName(index)
    local id        = AshitaCore:GetMemoryManager():GetEntity():GetServerId(index)
    local distance  = AshitaCore:GetMemoryManager():GetEntity():GetDistance(index)
    local hpp       = AshitaCore:GetMemoryManager():GetEntity():GetHPPercent(index)
    local x         = AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionX(index)
    local y         = AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionY(index)
    local z         = AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionZ(index)

    if imgui.Begin('TargetInfo', true, flags) then
        imgui.TextColored(CORAL, "Target Info")
        imgui.Separator()
        imgui.TextColored(WHITE, string.format("Name            : %-s", name))
        imgui.TextColored(WHITE, string.format("ServerId        : %-i", id))
        imgui.TextColored(WHITE, string.format("Index           : %-i", index))
        imgui.TextColored(WHITE, string.format("HPP             : %-i", hpp))
        imgui.TextColored(WHITE, string.format("Distance        : %-.3f", math.sqrt(distance)))
        imgui.TextColored(WHITE, string.format("X               : %-.3f", x))
        imgui.TextColored(WHITE, string.format("Y               : %-.3f", z)) -- NOTE: P.Servers have these Z and Y swapped.
        imgui.TextColored(WHITE, string.format("Z               : %-.3f", y))
    end
    imgui.End()
end

ashita.events.register('load', 'load_cb', function ()
end)

ashita.events.register('d3d_present', 'present_cb', function()
    -- Driver Loop
    local now = os.clock()
    if now - state.last_tick > state.loop_interval then
        tick()
        state.last_tick = now
    end
    draw_ui()
end)
