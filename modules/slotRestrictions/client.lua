if not lib then return end

local function fetchSlotRestrictions()
    return lib.callback.await('ox_inventory:fetchSlotRestrictions', false)
end

return {
    fetch = fetchSlotRestrictions,
}
