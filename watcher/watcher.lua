addon.name      = 'watcher'
addon.author    = 'zach2good'
addon.version   = '1.0'
addon.desc      = 'Watch for names of nearby mobs.'
addon.link      = ''

require('common')
local imgui = require('imgui')

local state =
{
    running       = true,
    loop_interval = 1.0,
    last_tick     = 0,

    search_term = "",
    show_render_flags = false,

    results = {},
}

local function to_bits(num, bits)
    -- returns a table of bits
    local t={} -- will contain the bits
    for b= bits, 1,-1 do
        local rest=math.fmod(num,2)
        t[b]=rest
        num=(num-rest)/2
    end
    if num==0 then
        return table.concat(t)
    else
        return {'Not enough bits to represent this number'}
    end
end

local function ashita_table_to_string(t)
    if not t then return "nil" end
    local str = ""
    for i = 1, #t do
        str = str .. t[i]
    end
    return str
end

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function len(t)
    local count = 0
    for _, _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function tick()
    state.results = {}
    for index = 0, 1023 do
        local ashita_name = AshitaCore:GetMemoryManager():GetEntity():GetName(index)
        local name = ashita_table_to_string(ashita_name)

        local parts = {}
        if string.find(state.search_term, '|') then
            parts = split(state.search_term, '|')
        else
            parts = { state.search_term }
        end

        for _, entry in pairs(parts) do
            if name and string.find(name, entry) then
                state.results[index] = { index }
            end
        end
    end
end

local function draw_ui()
    local WHITE = { 1.0,  1.0,  1.0, 1.0 }
    local CORAL = { 1.0, 0.65, 0.26, 1.0 }

    -- Create a temp copy of the settings usable with ImGui..
    local inner_state = T{
        search_term = T{ state.search_term },
        show_render_flags = T{ state.show_render_flags },
    }

    local flags = bit.bor(
     ImGuiWindowFlags_NoDecoration,
    ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav)

    imgui.SetNextWindowBgAlpha(0.6)
    imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always)
    imgui.SetNextWindowSizeConstraints({ -1, -1, }, { FLT_MAX, FLT_MAX, })

    if imgui.Begin('Watcher', true, flags) then
        imgui.TextColored(CORAL, 'Watcher')

        imgui.Separator()

        imgui.BeginGroup()

        if imgui.InputText("Name", inner_state.search_term, 255) then
            state.search_term = ashita_table_to_string(inner_state.search_term)
        end

        if imgui.Checkbox("Show RenderFlags", inner_state.show_render_flags) then
            state.show_render_flags = inner_state.show_render_flags
        end
        imgui.EndGroup()
    end

    if len(state.results) > 0 then
        imgui.TextColored(CORAL, 'Found:')
        for _, entry in pairs(state.results) do
            local index = entry[1]
            local name      = AshitaCore:GetMemoryManager():GetEntity():GetName(index)
            local hpp = AshitaCore:GetMemoryManager():GetEntity():GetHPPercent(index)
            local distance = math.sqrt(AshitaCore:GetMemoryManager():GetEntity():GetDistance(index))

            local color = WHITE
            if hpp == 100 then color = CORAL end

            imgui.TextColored(color, string.format('%i: %s, hpp: %i%%, dist: %.2f yalms',
                index, name, hpp, distance))

            if state.show_render_flags then
                local rf0 = to_bits(AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags0(index), 32)
                local rf1 = to_bits(AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags1(index), 32)
                local rf2 = to_bits(AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags2(index), 32)
                local rf3 = to_bits(AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags3(index), 32)
                local rf4 = to_bits(AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags4(index), 32)
                local rf5 = to_bits(AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags5(index), 32)
                local rf6 = to_bits(AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags6(index), 32)
                local rf7 = to_bits(AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags7(index), 32)

                imgui.TextColored(WHITE, string.format('\nRender flags:\n%s  %s  %s  %s\n%s  %s  %s  %s\n',
                    rf0, rf1, rf2, rf3, rf4, rf5, rf6, rf7))
            end
        end
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
