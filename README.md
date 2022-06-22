# AshitaAddons

## AutoNIN

Takes care of the less exciting housekeeping so you can concentrate on hitting your elemental wheel and self-skillchains.

![AutoNIN menu image](_images/autonin.png)

**NOTE**:

Shadow recasting relies on you using this block in your LuAshitacast:

```lua
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
```

## targetinfo

On-screen info about your current target.

![targetinfo menu image](_images/targetinfo.png)

### TODO

Movement speed, and other stats from Windower's targetinfo panel

## watcher

Watch for names of nearby mobs.

You can search for multiple terms with '|', eg: `Battering|Lumbering|Bloodtear` will match `Battering Ram`, `Lumbering Lambert`, and `Bloodtear Baldurf`.

![watcher menu image](_images/watcher.png)