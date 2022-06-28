addon.name    = 'AutoNIN'
addon.author  = 'zach2good w/ atom0s & Thorny'
addon.version = '1.0'
addon.desc    = 'Takes care of the less exciting housekeeping so you can concentrate on hitting your elemental wheel and self-skillchains.'
addon.link    = ''

-- Toggle Shadows on/off with: '/shadows' or 'CTRL+G'
-- Toggle between Yonin/Innin with: '/stance' or 'SHIFT+G'

require('common')
local imgui = require('imgui')

local state =
{
    -- Running state
    enabled          = true,
    loop_interval    = 0.25,
    last_tick        = 0,
    next_action      = 0,
    keys_down        = {},
    last_cancel      = 0,
    player_x         = 0,
    player_y         = 0,
    player_z         = 0,
    is_moving        = false,

    -- Starting state
    handle_shadows    = true,
    stance            = "Yonin",
    handle_kakka      = false,
    handle_gekka      = false,
    handle_migawari   = false,
    handle_food       = true,
    handle_tools      = true,
    handle_ws         = false,
    shadow_recast_num = 1,
    tool_threshold    = 10,
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
    weaponskill       = "Blade: Hi",
}

local VK_SHIFT     = 0x10
local VK_CONTROL   = 0x11
local VK_G_KEY     = 0x47

local SPELL_UTSUSEMI_ICHI = 338
local SPELL_UTSUSEMI_NI   = 339
local SPELL_UTSUSEMI_SAN  = 340
local SPELL_GEKKA         = 505
local SPELL_KAKKA         = 509
local SPELL_MIGAWARI      = 510

local BUFF_COPY_IMAGE_1 = 66
local BUFF_COPY_IMAGE_2 = 444
local BUFF_COPY_IMAGE_3 = 445
local BUFF_COPY_IMAGE_4 = 446

local BUFF_YONIN    = 420
local BUFF_INNIN    = 421
local BUFF_STORE_TP = 227
local BUFF_MIGAWARI = 471
local BUFF_FOOD     = 251
local BUFF_MOUNTED  = 252

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

local get_buff_count = function(matchBuff)
    local count = 0
    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    if type(matchBuff) == 'string' then
        local matchText = string.lower(matchBuff)
        for _, buff in pairs(buffs) do
            local buffString = AshitaCore:GetResourceManager():GetString("buffs.names", buff)
			if buffString ~= nil and string.lower(buffString) == matchText then
                count = count + 1
            end
        end
    elseif type(matchBuff) == 'number' then
        for _, buff in pairs(buffs) do
            if buff == matchBuff then
                count = count + 1
            end
        end
    end
    return count
end

-- /cancel logic taken from atom0s's 'debuff' addon
local cancel_buff = function(id)
    -- Make sure we only send one cancel packet every 2 seconds
    local now  = os.clock()
    if state.last_cancel + 2 > now then
        return
    end

    -- Handle invalid status id/name
    if id == nil or id <= 0 then
        return
    end

    -- Inject the status cancel packet
    local p = struct.pack("bbbbhbb", 0xF1, 0x04, 0x00, 0x00, id, 0x00, 0x00):totable()
    AshitaCore:GetPacketManager():AddOutgoingPacket(0xF1, p)
    state.last_cancel = now
end

local cancel_shadows = function(id)
    local delay = 0.0

    if id == SPELL_UTSUSEMI_ICHI then delay = 1.0
    elseif id == SPELL_UTSUSEMI_NI then delay = 0.0
    else return end

    ashita.tasks.once(delay, function()
        cancel_buff(BUFF_COPY_IMAGE_1)
        cancel_buff(BUFF_COPY_IMAGE_2)
        cancel_buff(BUFF_COPY_IMAGE_3)
        cancel_buff(BUFF_COPY_IMAGE_4)
    end)
end

local send = function(command)
    AshitaCore:GetChatManager():QueueCommand(1, command)
end

local is_logged_in = function()
    return AshitaCore:GetMemoryManager():GetPlayer():GetLoginStatus() == 2
end

local is_zoning = function()
    return AshitaCore:GetMemoryManager():GetPlayer():GetIsZoning() > 0
end

local get_zone_id = function()
    return AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
end

local in_inactive_zone = function()
    for _, zone_id in pairs(INACTIVE_ZONES) do
        if get_zone_id() == zone_id then
            return true
        end
    end
    return false
end

local is_nin_main = function()
    return AshitaCore:GetMemoryManager():GetPlayer():GetMainJob() == 13
end

local is_valid_state = function()
    local player_index  = AshitaCore:GetMemoryManager():GetParty():GetMemberIndex(0)
    local player_status = AshitaCore:GetMemoryManager():GetEntity():GetStatus(player_index)
    return true
    -- TODO: return player_status == 1 or player_status == 2 -- Idle or Combat, anything else is invalid
end

local toggle_enabled = function()
    state.enabled = not state.enabled
    print(string.format("AutoNIN Enabled: %s", state.enabled))
end

local toggle_shadows = function()
    state.handle_shadows = not state.handle_shadows
    print(string.format("AutoNIN Auto-Shadows: %s", state.handle_shadows))
end

local toggle_stance = function()
    if state.stance == "Yonin" then
        state.stance = "Innin"
    elseif state.stance == "Innin" then
        state.stance = "None"
    elseif state.stance == "None" then
        state.stance = "Yonin"
    end
    print(string.format("AutoNIN Auto-Stance: %s", state.stance))
end

local toggle_kakka = function()
    state.handle_kakka = not state.handle_kakka
    print(string.format("AutoNIN Auto-Kakka: %s", state.handle_kakka))
end

local toggle_gekka = function()
    state.handle_gekka = not state.handle_gekka
    print(string.format("AutoNIN Auto-Gekka: %s", state.handle_gekka))
end

local toggle_migawari = function()
    state.handle_migawari = not state.handle_migawari
    print(string.format("AutoNIN Auto-Migawari: %s", state.handle_migawari))
end

local toggle_food = function()
    state.handle_food = not state.handle_food
    print(string.format("AutoNIN Auto-Food: %s", state.handle_food))
end

local toggle_tools = function()
    state.handle_tools = not state.handle_tools
    print(string.format("AutoNIN Auto-Tools: %s", state.handle_tools))
end

local toggle_ws = function()
    state.handle_ws = not state.handle_ws
    print(string.format("AutoNIN Auto-WS: %s", state.handle_ws))
end

local tick = function()
    local player       = AshitaCore:GetMemoryManager():GetPlayer()
    local party        = AshitaCore:GetMemoryManager():GetParty()
    local player_index = party:GetMemberTargetIndex(0)
    local player_hpp   = AshitaCore:GetMemoryManager():GetParty():GetMemberHPPercent(0)
    local player_tp    = AshitaCore:GetMemoryManager():GetParty():GetMemberTP(0)
    local player_level = AshitaCore:GetMemoryManager():GetPlayer():GetMainJobLevel()

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
        if buff_id == BUFF_COPY_IMAGE_1 then shadows_left = 1 end
        if buff_id == BUFF_COPY_IMAGE_2 then shadows_left = 2 end
        if buff_id == BUFF_COPY_IMAGE_3 then shadows_left = 3 end
        if buff_id == BUFF_COPY_IMAGE_4 then shadows_left = 4 end

        -- Yonin
        if buff_id == BUFF_YONIN then has_yonin = true end

        -- Innin
        if buff_id == BUFF_INNIN then has_innin = true end

        -- Store TP
        if buff_id == BUFF_STORE_TP then has_store_tp = true end

        -- Store TP
        if buff_id == BUFF_MIGAWARI then has_migawari = true end

        -- Food
        if buff_id == BUFF_FOOD then has_food = true end

        -- Mounted
        if buff_id == BUFF_MOUNTED then is_mounted = true end
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

    state.is_moving = false

    local player_x = AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionX(player_index)
    local player_y = AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionY(player_index)
    local player_z = AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionZ(player_index)

    if
        state.player_x ~= player_x or
        state.player_y ~= player_y or
        state.player_z ~= player_z
    then
        state.is_moving = true
    end

    state.player_x = player_x
    state.player_y = player_y
    state.player_z = player_z

    -- Look for reasons to bail out now
    if
        not state.enabled or
        in_inactive_zone() or
        not is_valid_state() or
        is_mounted or
        player_hpp == 0 or
        state.is_moving
    then
        state.next_action = now + 2.0
        return
    end

    -- Take actions
    if now > state.next_action then
        -- Shadows
        if state.handle_shadows and shadows_left <= state.shadow_recast_num then
            local can_cast_san = player:GetJobPointsSpent(13) >= 100 and is_nin_main() and player:HasSpell(SPELL_UTSUSEMI_SAN)
            if can_cast_san and spell_recasts[SPELL_UTSUSEMI_SAN] == nil then
                send('/ma "Utsusemi: San" <me>')
                state.next_action = now + 3.0
                return
            elseif player:HasSpell(SPELL_UTSUSEMI_NI) and spell_recasts[SPELL_UTSUSEMI_NI] == nil then
                send('/ma "Utsusemi: Ni" <me>')
                state.next_action = now + 5.0
                return
            elseif player:HasSpell(SPELL_UTSUSEMI_ICHI) and spell_recasts[SPELL_UTSUSEMI_ICHI] == nil then
                send('/ma "Utsusemi: Ichi" <me>')
                state.next_action = now + 7.0
                return
            end
        end

        if state.handle_ws and state.weaponskill and player_tp > 1000 then
            send(string.format('/ws "%s" <t>', state.weaponskill))
            return
        end

        -- Stances (lv40)
        if player_level >= 40 and is_nin_main() and state.stance == "Yonin" and not has_yonin and ability_recasts[1] == 0 then
            send('/ja "Yonin" <me>')
            state.next_action = now + 2.0
            return
        elseif player_level >= 40 and is_nin_main() and state.stance == "Innin" and not has_innin and ability_recasts[2] == 0 then
            send('/ja "Innin" <me>')
            state.next_action = now + 2.0
            return
        end

        -- Migawari: Ichi (lv88)
        if state.handle_migawari then
            if player_level >= 88 and player:HasSpell(SPELL_MIGAWARI) and is_nin_main() and not has_migawari and spell_recasts[SPELL_MIGAWARI] == nil then
                send('/ma "Migawari: Ichi" <me>')
                state.next_action = now + 4.0
                return
            end
        end

        -- Kakka: Ichi (lv93)
        if state.handle_kakka then
            if player_level >= 93 and player:HasSpell(SPELL_KAKKA) and is_nin_main() and not has_store_tp and spell_recasts[SPELL_KAKKA] == nil then
                send('/ma "Kakka: Ichi" <me>')
                state.next_action = now + 4.0
                return
            end
        end

        -- Gekka: Ichi (lv88)
        if state.handle_gekka then
            if player_level >= 88 and player:HasSpell(SPELL_GEKKA) and is_nin_main() and not has_store_tp and spell_recasts[SPELL_GEKKA] == nil then
                send('/ma "Kakka: Ichi" <me>')
                state.next_action = now + 4.0
                return
            end
        end

        -- Items
        if state.handle_tools then
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
        end

        -- Food
        if state.handle_food then
            if not has_food and state.food_count > 0 then
                send(string.format('/item "%s" <me>', state.food))
                state.next_action = now + 5.0
                return
            end
        end
    end
end

local draw_ui = function()
    local enabled = state.enabled and not in_inactive_zone() and not state.is_moving

    local WHITE_OR_GREY = { 1.0,  1.0,  1.0, 1.0 }
    local CORAL_OR_GREY = { 1.0, 0.65, 0.26, 1.0 }

    if not enabled then
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
        if enabled then
            imgui.TextColored(CORAL_OR_GREY, 'AutoNIN (active)')
        else
            imgui.TextColored(CORAL_OR_GREY, 'AutoNIN (inactive)')
        end

        imgui.SameLine()
        local icon = '+'
        if state.enabled then icon = '-' end
        if imgui.Button(icon) then
            toggle_enabled()
        end

        if not enabled then
            imgui.End()
            return
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
            imgui.SameLine()

            if imgui.Button('Tools') then
                toggle_tools()
            end

            -- New Line

            imgui.Spacing()
            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()

            if imgui.Button('Kakka') then
                toggle_kakka()
            end

            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()

            if imgui.Button('Gekka') then
                toggle_gekka()
            end

            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()

            if imgui.Button('Food') then
                toggle_food()
            end

            imgui.SameLine()
            imgui.Spacing()

            -- New Line

            imgui.Spacing()
            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()

            if imgui.Button('Migawari') then
                toggle_migawari()
            end

            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()
            imgui.Spacing()
            imgui.SameLine()

            if imgui.Button('WS') then
                toggle_ws()
            end

            imgui.SameLine()
            imgui.Spacing()
        imgui.EndGroup()

        imgui.Separator()

        imgui.BeginGroup()
            imgui.TextColored(WHITE_OR_GREY, string.format("Shadows  : %s", state.handle_shadows))
            imgui.TextColored(WHITE_OR_GREY, string.format("Stance   : %s (SHIFT+G)", state.stance))
            imgui.TextColored(WHITE_OR_GREY, string.format("Tools    : %s", state.handle_tools))
            imgui.TextColored(WHITE_OR_GREY, string.format("Kakka    : %s", state.handle_kakka))
            imgui.TextColored(WHITE_OR_GREY, string.format("Gekka    : %s", state.handle_gekka))
            imgui.TextColored(WHITE_OR_GREY, string.format("Food     : %s", state.handle_food))
            imgui.TextColored(WHITE_OR_GREY, string.format("Migawari : %s", state.handle_migawari))
            imgui.TextColored(WHITE_OR_GREY, string.format("WS       : %s", state.handle_ws))

            imgui.Separator()

            imgui.TextColored(WHITE_OR_GREY, string.format("Ino      : %i (bags: %i)", state.ino_count, state.ino_bag_count * 99))
            imgui.TextColored(WHITE_OR_GREY, string.format("Shika    : %i (bags: %i)", state.shika_count, state.shika_bag_count * 99))
            imgui.TextColored(WHITE_OR_GREY, string.format("Cho      : %i (bags: %i)", state.cho_count, state.cho_bag_count * 99))
            imgui.TextColored(WHITE_OR_GREY, string.format("Shihei   : %i (bags: %i)", state.shihei_count, state.shihei_bag_count * 99))
            imgui.TextColored(WHITE_OR_GREY, string.format("Food     : %i (%s)", state.food_count, state.food))
        imgui.EndGroup()
    end
    imgui.End()
end

ashita.events.register('load', 'load_cb', function()
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

-- Action packet logic from Thorny's luashitacast
ashita.events.register('packet_out', 'packet_out_cb', function(e)
    if e.id == 0x1A then
        local packet   = struct.unpack('c' .. e.size, e.data, 1)
        local category = struct.unpack('H', packet, 0x0A + 0x01)

        if category == 0x03 then -- Spell
            local spellId = struct.unpack('H', packet, 0x0C + 0x01)
            cancel_shadows(spellId)
        end
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
