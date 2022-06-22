addon.name    = 'AutoNIN'
addon.author  = 'zach2good'
addon.version = '1.0'
addon.desc    = 'Takes care of the less exciting housekeeping so you can concentrate on hitting your elemental wheel and self-skillchains.'
addon.link    = ''

-- Toggle Shadows on/off with: '/shadows' or 'CTRL+G'
-- Toggle between Yonin/Innin with: '/stance' or 'SHIFT+G'

--[[
NOTE:
Shadow recasting relies on you using this block in your LuAshitacast

local cancelShadows = function()
    local action = gData.GetAction()

    if action.Name == 'Utsusemi: Ichi' then
        local delay = 1.5
        if gData.GetBuffCount(66) == 1 then
            (function() AshitaCore:GetChatManager():QueueCommand(-1, '/cancel 66') end):once(delay)
        elseif gData.GetBuffCount(444) == 1 then
            (function() AshitaCore:GetChatManager():QueueCommand(-1, '/cancel 444') end):once(delay)
        elseif gData.GetBuffCount(445) == 1 then
            (function() AshitaCore:GetChatManager():QueueCommand(-1, '/cancel 445') end):once(delay)
        elseif gData.GetBuffCount(446) == 1 then
            (function() AshitaCore:GetChatManager():QueueCommand(-1, '/cancel 446') end):once(delay)
        end
    end

    if action.Name == 'Utsusemi: Ni' then
        local delay = 0.5
        if gData.GetBuffCount(66) == 1 then
            (function() AshitaCore:GetChatManager():QueueCommand(-1, '/cancel 66') end):once(delay)
        elseif gData.GetBuffCount(444) == 1 then
            (function() AshitaCore:GetChatManager():QueueCommand(-1, '/cancel 444') end):once(delay)
        elseif gData.GetBuffCount(445) == 1 then
            (function() AshitaCore:GetChatManager():QueueCommand(-1, '/cancel 445') end):once(delay)
        elseif gData.GetBuffCount(446) == 1 then
            (function() AshitaCore:GetChatManager():QueueCommand(-1, '/cancel 446') end):once(delay)
        end
    end
end
]]

require('common')
local imgui = require('imgui')

local state =
{
    -- Running state
    loop_interval = 0.1,
    last_tick     = 0,
    next_action   = 0,
    keys_down     = {},

    -- Starting state
    shadow_recast_num = 1,
    tool_threshold    = 10,
    handle_shadows    = true,
    stance            = "Yonin",
    shihei_count      = 0,
    ino_count         = 0,
    shika_count       = 0,
    cho_count         = 0,
    shihei_bag_count  = 0,
    ino_bag_count     = 0,
    shika_bag_count   = 0,
    cho_bag_count     = 0,
    food              = "Sole Sushi",
    food_count        = 0,
}

local VK_SHIFT     = 0x10
local VK_CONTROL   = 0x11
local VK_G_KEY     = 0x47

local ITEM_SHIHEI          = 1179
local ITEM_INOSHISHINOFUDA = 2971
local ITEM_SHIKANOFUDA     = 2972
local ITEM_CHONOFUDA       = 2973
local ITEM_TOOLBAG_SHIHE   = 5314
local ITEM_TOOLBAG_INO     = 5867
local ITEM_TOOLBAG_SHIKA   = 5868
local ITEM_TOOLBAG_CHO     = 5869
local ITEM_SOLE_SUSHI      = 5149

local INACTIVE_ZONES =
{
    ZONE_RESIDENTIAL_AREA          = 0,
    ZONE_TAVNAZIAN_SAFEHOLD        = 26,
    ZONE_AL_ZAHBI                  = 48,
    ZONE_AHT_URHGAN_WHITEGATE      = 50,
    ZONE_NASHMAU                   = 53,
    ZONE_CHOCOBO_CIRCUIT           = 70,
    ZONE_THE_COLOSSEUM             = 71,
    ZONE_SOUTHERN_SAN_DORIA_S      = 80,
    ZONE_BASTOK_MARKETS_S          = 87,
    ZONE_WINDURST_WATERS_S         = 94,
    ZONE_MORDION_GAOL              = 131,
    ZONE_SOUTHERN_SANDORIA         = 230,
    ZONE_NORTHERN_SANDORIA         = 231,
    ZONE_PORT_SANDORIA             = 232,
    ZONE_CHATEAU_DORAGUILLE        = 233,
    ZONE_BASTOK_MINES              = 234,
    ZONE_BASTOK_MARKETS            = 235,
    ZONE_PORT_BASTOK               = 236,
    ZONE_METALWORKS                = 237,
    ZONE_WINDURST_WATERS           = 238,
    ZONE_WINDURST_WALLS            = 239,
    ZONE_PORT_WINDURST             = 240,
    ZONE_WINDURST_WOODS            = 241,
    ZONE_HEAVENS_TOWER             = 242,
    ZONE_RULUDE_GARDENS            = 243,
    ZONE_UPPER_JEUNO               = 244,
    ZONE_LOWER_JEUNO               = 245,
    ZONE_PORT_JEUNO                = 246,
    ZONE_RABAO                     = 247,
    ZONE_SELBINA                   = 248,
    ZONE_MHAURA                    = 249,
    ZONE_KAZHAM                    = 250,
    ZONE_HALL_OF_THE_GODS          = 251,
    ZONE_NORG                      = 252,
    ZONE_WESTERN_ADOULIN           = 256,
    ZONE_EASTERN_ADOULIN           = 257,
    ZONE_MOG_GARDEN                = 280,
    ZONE_LEAFALLIA                 = 281,
    ZONE_CELENNIA_MEMORIAL_LIBRARY = 284,
    ZONE_FERETORY                  = 285,
}

local function btos(b)
    if b then
        return "True"
    end
    return "False"
end

local function send(command)
    AshitaCore:GetChatManager():QueueCommand(1, command)
end

local function is_logged_in()
    return AshitaCore:GetMemoryManager():GetPlayer():GetLoginStatus() == 2
end

local function is_zoning()
    return AshitaCore:GetMemoryManager():GetPlayer():GetIsZoning() > 0
end

local function get_zone_id()
    return AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
end

local function in_inactive_zone()
    for _, zone_id in pairs(INACTIVE_ZONES) do
        if get_zone_id() == zone_id then
            return true
        end
    end
    return false
end

local function is_nin_main()
    return AshitaCore:GetMemoryManager():GetPlayer():GetMainJob() == 13
end

local function is_valid_state()
    local player_index  = AshitaCore:GetMemoryManager():GetParty():GetMemberIndex(0)
    local player_status = AshitaCore:GetMemoryManager():GetEntity():GetStatus(player_index)
    return true
    -- TODO: return player_status == 1 or player_status == 2 -- Idle or Combat, anything else is invalid
    -- TODO: Handle movement do you don't cast on the run
end

local function toggle_shadows()
    state.handle_shadows = not state.handle_shadows
    print(string.format("AutoNIN Auto-Shadows: %s", btos(state.handle_shadows)))
end

local function toggle_stance()
    if state.stance == "Yonin" then
        state.stance = "Innin"
    else
        state.stance = "Yonin"
    end
    print(string.format("AutoNIN Auto-Stance: %s", state.stance))
end

local function tick()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    local player_index  = AshitaCore:GetMemoryManager():GetParty():GetMemberIndex(0)
    local player_hpp    = AshitaCore:GetMemoryManager():GetParty():GetMemberHPPercent(0)
    local player_tp     = AshitaCore:GetMemoryManager():GetParty():GetMemberTP(player_index)

    local now  = os.clock()
    local shadows_left = 0
    local has_yonin    = false
    local has_innin    = false
    local has_store_tp = false
    local has_migawari = false
    local has_food     = false
    local is_mounted   = false

    -- Abilities
    local ability_recasts = {}
    for i = 0, 256  do
        ability_recasts[i] = 0
        local timer_id = AshitaCore:GetMemoryManager():GetPlayer():GetAbilityRecastTimerId(i)
        local recast = AshitaCore:GetMemoryManager():GetPlayer():GetAbilityRecast(timer_id)
        if timer_id > 0 and recast > 0 then
            ability_recasts[timer_id] = recast
        end
    end

    -- Spells
    local spell_recasts = {}
    local recasts = AshitaCore:GetMemoryManager():GetRecast()
    for i = 0, 1024 do
        local timer = recasts:GetSpellTimer(i)
        if timer > 0 then
            spell_recasts[i] = timer
        end
    end

    -- Buffs
    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    for i = 1, 32 do
        local buff_id = buffs[i]

        -- Copy Image
        if buff_id == 66 then shadows_left = 1 end
        if buff_id == 444 then shadows_left = 2 end
        if buff_id == 445 then shadows_left = 3 end
        if buff_id == 446 then shadows_left = 4 end

        -- Yonin
        if buff_id == 420 then has_yonin = true end

        -- Innin
        if buff_id == 421 then has_innin = true end

        -- Store TP
        if buff_id == 227 then has_store_tp = true end

        -- Store TP
        if buff_id == 471 then has_migawari = true end

        -- Food
        if buff_id == 251 then has_food = true end

        -- Mounted
        if buff_id == 252 then is_mounted = true end
    end

    -- Items
    local items = {}
    for i = 1, 81 do
		local item = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, i)
		if item ~= nil and item.Id > 0 and item.Count > 0 then
            items[item.Id] = items[item.Id] or 0
			items[item.Id] = items[item.Id] + item.Count
		end
	end

    -- TODO: Do a lookup by name instead of hard-coded item id
    state.food_count = items[ITEM_SOLE_SUSHI] or 0

    state.shihei_count     = items[ITEM_SHIHEI] or 0
    state.ino_count        = items[ITEM_INOSHISHINOFUDA] or 0
    state.shika_count      = items[ITEM_SHIKANOFUDA] or 0
    state.cho_count        = items[ITEM_CHONOFUDA] or 0
    state.shihei_bag_count = items[ITEM_TOOLBAG_SHIHE] or 0
    state.ino_bag_count    = items[ITEM_TOOLBAG_INO] or 0
    state.shika_bag_count  = items[ITEM_TOOLBAG_SHIKA] or 0
    state.cho_bag_count    = items[ITEM_TOOLBAG_CHO] or 0

    -- Look for reasons to bail out now
    if
        in_inactive_zone() or
        not is_valid_state() or
        is_mounted or
        player_hpp == 0
    then
        return
    end

    -- Take actions
    if now > state.next_action then
        -- Shadows
        -- TODO: Watch incoming packets and count when we get to 1 shadow remaining.
        -- Thats when we should start casting (required pre-cancelling in luashitacast)
        if state.handle_shadows and not shadows_left <= state.shadow_recast_num then
            local can_cast_san = player:GetJobPointsSpent(13) >= 100 and is_nin_main() and player:HasSpell(340)
            if can_cast_san and spell_recasts[340] == nil then
                send('/ma "Utsusemi: San" <me>')
                state.next_action = now + 2.0
                return
            elseif player:HasSpell(339) and spell_recasts[339] == nil then
                send('/ma "Utsusemi: Ni" <me>')
                state.next_action = now + 5.0
                return
            elseif player:HasSpell(338) and spell_recasts[338] == nil then
                send('/ma "Utsusemi: Ichi" <me>')
                state.next_action = now + 7.5
                return
            end
        end

        -- Stances
        if is_nin_main() and state.stance == "Yonin" and not has_yonin and ability_recasts[1] == 0 then
            send('/ja "Yonin" <me>')
            state.next_action = now + 2.0
            return
        elseif is_nin_main() and state.stance == "Innin" and not has_innin and ability_recasts[2] == 0 then
            send('/ja "Innin" <me>')
            state.next_action = now + 2.0
            return
        end

        -- Kakka: Ichi
        if is_nin_main() and not has_store_tp and spell_recasts[509] == nil then
            send('/ma "Kakka: Ichi" <me>')
            state.next_action = now + 4.0
            return
        end

        -- Migawari: Ichi
        if is_nin_main() and not has_migawari and spell_recasts[510] == nil then
            send('/ma "Migawari: Ichi" <me>')
            state.next_action = now + 4.0
            return
        end

        -- Items
        if is_nin_main() and state.ino_count < state.tool_threshold and state.ino_bag_count > 0 then
            send('/item "Toolbag (Ino)" <me>')
            state.next_action = now + 5.0
            return
        elseif is_nin_main() and state.shika_count < state.tool_threshold and state.shika_bag_count > 0 then
            send('/item "Toolbag (Shika)" <me>')
            state.next_action = now + 5.0
            return
        elseif is_nin_main() and state.cho_count < state.tool_threshold and state.cho_bag_count >0 then
            send('/item "Toolbag (Cho)" <me>')
            state.next_action = now + 5.0
            return
        elseif not is_nin_main() and state.shihei_count < state.tool_threshold and state.shihei_bag_count > 0 then
            send('/item "Toolbag (Shihei)" <me>')
            state.next_action = now + 5.0
            return
        end

        -- Food
        if not has_food and state.food_count > 0 then
            send(string.format('/item "%s" <me>', state.food))
            state.next_action = now + 5.0
            return
        end
    end
end

local function draw_ui()
    local WHITE_OR_GREY = { 1.0,  1.0,  1.0, 1.0 }
    local CORAL_OR_GREY = { 1.0, 0.65, 0.26, 1.0 }

    if in_inactive_zone() then
        WHITE_OR_GREY = { 0.7,  0.7,  0.7, 0.7 }
        CORAL_OR_GREY = { 0.7,  0.7,  0.7, 0.7 }
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

    if imgui.Begin('AutoNIN', true, flags) then
        if not in_inactive_zone() then
            imgui.TextColored(CORAL_OR_GREY, 'AutoNIN (active)')
        else
            imgui.TextColored(CORAL_OR_GREY, 'AutoNIN (inactive zone)')
        end

        imgui.Separator()

        imgui.BeginGroup()
            imgui.Spacing()
            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()

            if imgui.Button('Shadows') then
                toggle_shadows()
            end

            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()

            if imgui.Button('Stance') then
                toggle_stance()
            end

            imgui.SameLine()
            imgui.Spacing()
        imgui.EndGroup()

        imgui.Separator()

        imgui.BeginGroup()
            imgui.TextColored(WHITE_OR_GREY, string.format("Shadows: %s (CTRL+G)", btos(state.handle_shadows)))
            imgui.TextColored(WHITE_OR_GREY, string.format("Stance: %s (SHIFT+G)", state.stance))
            imgui.TextColored(WHITE_OR_GREY, string.format("Ino: %i (bags: %i)", state.ino_count, state.ino_bag_count * 99))
            imgui.TextColored(WHITE_OR_GREY, string.format("Shika: %i (bags: %i)", state.shika_count, state.shika_bag_count * 99))
            imgui.TextColored(WHITE_OR_GREY, string.format("Cho: %i (bags: %i)", state.cho_count, state.cho_bag_count * 99))
            imgui.TextColored(WHITE_OR_GREY, string.format("Shihei: %i (bags: %i)", state.shihei_count, state.shihei_bag_count * 99))
            imgui.TextColored(WHITE_OR_GREY, string.format("Food: %i (%s)", state.food_count, "Sole Sushi"))
        imgui.EndGroup()
    end
    imgui.End()
end

ashita.events.register('load', 'load_cb', function ()
end)

ashita.events.register('key', 'key_callback', function(e)
    local res = bit.band(e.lparam, bit.lshift(0x8000, 0x10)) == bit.lshift(0x8000, 0x10)
    state.keys_down[e.wparam] = not res
end)

-- TODO: Move with SHIFT+CLICK only
ashita.events.register('mouse', 'mouse_cb', function(e)
end)

ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args()

    if (#args > 0 and args[1] == '/shadows') then
        toggle_shadows()
        e.blocked = true
        return
    end

    if (#args > 0 and args[1] == '/stance') then
        toggle_stance()
        e.blocked = true
        return
    end
end)

ashita.events.register('d3d_present', 'present_cb', function()
    -- Driver Loop
    local now = os.clock()
    if now - state.last_tick > state.loop_interval then
        tick()

        state.last_tick = now

        if state.keys_down[VK_CONTROL] and state.keys_down[VK_G_KEY] then
            toggle_shadows()
        end

        if state.keys_down[VK_SHIFT] and state.keys_down[VK_G_KEY] then
            toggle_stance()
        end
    end

    -- UI
    if is_logged_in() and not is_zoning() then
        draw_ui()
    end
end)
