if not lib then return end

local function fetchSlotRestrictions()
    local restrictions = {
        [1] = { name = "WEAPON SLOT 1", restrictions = { type = "weapon_prefix", prefix = "WEAPON_", exclude = false } },
        [2] = { name = "WEAPON SLOT 2", restrictions = { type = "weapon_prefix", prefix = "WEAPON_", exclude = false } },
        [3] = {
            name = "HOTKEY SLOT 3",
            exclude_items = { "backpack", "large_backpack", "military_backpack", "armor", "heavyarmor", "pdarmor", "phone", "parachute" },
            restrictions = {
                type = "weapon_prefix",
                prefix = "WEAPON_",
                exclude = true
            },
        },
        [4] = {
            name = "HOTKEY SLOT 4",
            exclude_items = { "backpack", "large_backpack", "military_backpack", "armor", "heavyarmor", "pdarmor", "phone", "parachute" },
            restrictions = {
                type = "weapon_prefix",
                prefix = "WEAPON_",
                exclude = true
            },
        },
        [5] = {
            name = "HOTKEY SLOT 5",
            exclude_items = { "backpack", "large_backpack", "military_backpack", "armor", "heavyarmor", "pdarmor", "phone", "parachute" },
            restrictions = {
                type = "weapon_prefix",
                prefix = "WEAPON_",
                exclude = true
            },
        },
        [6] = { name = "BACKPACK", restrictions = { type = "allowed_items", items = { "backpack", "large_backpack", "military_backpack" } } },
        [7] = { name = "BODY ARMOR", restrictions = { type = "allowed_items", items = { "armor", "heavyarmor", "pdarmor" } } },
        [8] = { name = "PHONE", restrictions = { type = "allowed_items", items = { "phone" } } },
        [9] = { name = "PARACHUTE", restrictions = { type = "allowed_items", items = { "parachute" } } }
    }

    local formattedRestrictions = {}
    for i = 1, 9 do
        formattedRestrictions[tostring(i)] = restrictions[i]
    end

    return formattedRestrictions
end

---@param itemName string
---@param slot number
---@return boolean
local function canItemBePlacedInSlot(itemName, slot)
    local restrictions = fetchSlotRestrictions()
    local slotConfig = restrictions[tostring(slot)]
    
    if not slotConfig or not slotConfig.restrictions then
        return true
    end
    
    if slotConfig.exclude_items and slotConfig.exclude_items[itemName] then
        return false
    end
    
    local restrictionsConfig = slotConfig.restrictions
    
    if restrictionsConfig.type == 'weapon_prefix' then
        local startsWithPrefix = itemName:sub(1, #restrictionsConfig.prefix) == (restrictionsConfig.prefix or '')
        return restrictionsConfig.exclude and not startsWithPrefix or startsWithPrefix
    elseif restrictionsConfig.type == 'allowed_items' then
        for _, allowedItem in ipairs(restrictionsConfig.items) do
            if itemName == allowedItem then
                return true
            end
        end
        return false
    end
    
    return true
end

lib.callback.register('ox_inventory:fetchSlotRestrictions', function(source)
    return fetchSlotRestrictions()
end)


RegisterCommand('testcontainer', function(source, args)
    local targetId = tonumber(args[1]) or source
    print("Checking containers for player:", targetId)

    -- Loop through the player's inventory to find container items
    for slot = 1, 60 do
        local slotData = exports.ox_inventory:GetSlot(targetId, slot)

        -- Containers are identified by: metadata.container
        if slotData and slotData.metadata and slotData.metadata.container then
            local containerId = slotData.metadata.container

            print(("Found container item '%s' in slot %d -> container ID: %s")
                :format(slotData.name, slot, containerId))

            print("Items inside container:")

            local foundSomething = false

            -- Loop container inventory slots
            for cslot = 1, 60 do
                local item = exports.ox_inventory:GetSlot(containerId, cslot)
                if item then
                    foundSomething = true
                    print(("[Slot %d] %s x%d"):format(cslot, item.name, item.count))
                end
            end

            if not foundSomething then
                print("      (empty)")
            end

            print("-----------------------------")
        end
    end
end, false)





return {
    fetch = fetchSlotRestrictions,
    canItemBePlacedInSlot = canItemBePlacedInSlot,
}
