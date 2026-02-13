local Inventory = require 'modules.inventory.server'
local ItemList = require 'modules.items.shared'
local Items = require 'modules.items.server'

AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    RegisterRandomItems()
    RegisterOXINVMiddleware()

    TriggerEvent('ox_inventory:ready')

    exports["sandbox-chat"]:RegisterAdminCommand("giveitem", function(source, args, rawCommand)
        local item = Items(args[2])
        if not item then
            exports['sandbox-hud']:Notification(source, "error", "Item not found")
            return
        end

        if item then
            local targetChar = exports['sandbox-characters']:FetchBySID(tonumber(args[1]))

            if not targetChar then
                exports['sandbox-hud']:Notification(source, "error", "Player with SID " .. args[1] .. " not found online")
                return
            end

            local targetPlayer = targetChar:GetData("Source")

            local inventory = Inventory(targetPlayer) --[[@as OxInventory]]
            local count = tonumber(args[3]) and math.max(tonumber(args[3]), 1) or 1

            local success, response = Inventory.AddItem(inventory, item.name, count,
                args[4] and { type = tonumber(args[4]) or args[4] })

            if success then
                exports['sandbox-hud']:Notification(source, "success",
                    string.format("You gave %sx %s to SID: %s", count, item.name, args[1]))
            end

            if not success then
                exports['sandbox-hud']:Notification(source, "error",
                    string.format("Failed to give %sx %s to SID: %s (%s)", count, item.name, args[1], response))
                return Citizen.Trace(('Failed to give %sx %s to SID %s (%s)'):format(count, item.name, args[1],
                    response))
            end

            local sourceInventory = Inventory(source) or { label = 'console', owner = 'console' }

            if server.loglevel > 0 then
                lib.logger(sourceInventory.owner, 'admin',
                    ('"%s" gave %sx %s to SID "%s"'):format(sourceInventory.label, count, item.name, args[1]))
            end
        end
    end, {
        help = "Gives an item to a player with the given SID",
        params = {
            { name = 'SID',   help = 'The SID of the player to receive the item' },
            { name = 'Item',  help = 'The name of the item' },
            { name = 'Count', help = 'The amount of the item to add' },
            { name = 'Type',  help = 'Sets the "type" metadata to the value' },
        },
    }, -1)

    exports["sandbox-chat"]:RegisterAdminCommand("removeitem", function(source, args, rawCommand)
        local item = Items(args[2])
        if item then
            local targetChar = exports['sandbox-characters']:FetchBySID(tonumber(args[1]))

            if not targetChar then
                exports['sandbox-hud']:Notification(source, "error", "Player with SID " .. args[1] .. " not found online")
                return
            end

            local targetPlayer = targetChar:GetData("Source")

            local inventory = Inventory(targetPlayer) --[[@as OxInventory]]
            local count = tonumber(args[3]) and math.max(tonumber(args[3]), 1) or 1

            local success, response = Inventory.RemoveItem(inventory, item.name, count,
                args[4] and { type = tonumber(args[4]) or args[4] }, nil, true)

            if not success then
                return Citizen.Trace(('Failed to remove %sx %s from SID %s (%s)'):format(count, item.name, args[1],
                    response))
            end

            local sourceInventory = Inventory(source) or { label = 'console', owner = 'console' }

            if server.loglevel > 0 then
                lib.logger(sourceInventory.owner, 'admin',
                    ('"%s" removed %sx %s from SID "%s"'):format(sourceInventory.label, count, item.name, args[1]))
            end
        end
    end, {
        help = "Removes an item from a player with the given SID",
        params = {
            { name = 'SID',   help = 'The SID of the player to remove the item from' },
            { name = 'Item',  help = 'The name of the item' },
            { name = 'Count', help = 'The amount of the item to remove' },
            { name = 'Type',  help = 'Only remove items with a matching metadata "type"' },
        },
    }, -1)

    exports["sandbox-chat"]:RegisterAdminCommand("setitem", function(source, args, rawCommand)
        local item = Items(args[2])
        local count = args[3] or 1
        local type = args[4]

        if item then
            local targetChar = exports['sandbox-characters']:FetchBySID(tonumber(args[1]))

            if not targetChar then
                exports['sandbox-hud']:Notification(source, "error", "Player with SID " .. args[1] .. " not found online")
                return
            end

            local targetPlayer = targetChar:GetData("Source")

            local inventory = Inventory(targetPlayer) --[[@as OxInventory]]
            local success, response = exports.ox_inventory:SetItem(inventory, item.name, count or 0,
                type and { type = tonumber(type) or type })

            if not success then
                return Trace(('Failed to set %s count to %sx for SID %s (%s)'):format(item.name, count,
                    args[1], response))
            end

            local sourceInventory = Inventory(source) or { label = 'console', owner = 'console' }

            if server.loglevel > 0 then
                lib.logger(sourceInventory.owner, 'admin',
                    ('"%s" set SID "%s" %s count to %sx'):format(sourceInventory.label, args[1], item.name, count))
            end
        end
    end, {
        help = "Sets the item count for a player with the given SID, removing or adding as needed",
        params = {
            { name = 'SID',   help = 'The SID of the player to set the items for' },
            { name = 'Item',  help = 'The name of the item' },
            { name = 'Count', help = 'The amount of the item to set' },
            { name = 'Type',  help = 'Sets the "type" metadata to the value' },
        },
    }, -1)

    exports["sandbox-chat"]:RegisterAdminCommand("clearevidence", function(source, args, rawCommand)
        local locker = args[1]
        if not server.isPlayerBoss then return end

        local inventory = Inventory(source)
        local group, grade = server.hasGroup(inventory, shared.police)
        local hasPermission = group and server.isPlayerBoss(source, group, grade)

        if hasPermission then
            MySQL.query('DELETE FROM ox_inventory WHERE name = ?', { ('evidence-%s'):format(locker) })
        end
    end, {
        help = "Clears a police evidence locker with the given id",
        params = {
            { name = 'locker', help = 'The locker id to clear' },
        },
    }, 1)

    exports["sandbox-chat"]:RegisterAdminCommand("confiscateinv", function(source, args, rawCommand)
        local targetChar = exports['sandbox-characters']:FetchBySID(tonumber(args[1]))

        if not targetChar then
            exports['sandbox-hud']:Notification(source, "error", "Player with SID " .. args[1] .. " not found online")
            return
        end

        local targetPlayer = targetChar:GetData("Source")

        exports.ox_inventory:ConfiscateInventory(targetPlayer)
        exports['sandbox-hud']:Notification(source, "success", "Confiscated inventory for SID: " .. args[1])
    end, {
        help = "Confiscates the target inventory by SID, to restore with /returninv",
        params = {
            { name = 'SID', help = 'The SID of the player to confiscate items from' },
        },
    }, 1)

    exports["sandbox-chat"]:RegisterAdminCommand("returninv", function(source, args, rawCommand)
        local targetChar = exports['sandbox-characters']:FetchBySID(tonumber(args[1]))

        if not targetChar then
            exports['sandbox-hud']:Notification(source, "error", "Player with SID " .. args[1] .. " not found online")
            return
        end

        local targetPlayer = targetChar:GetData("Source")

        exports.ox_inventory:ReturnInventory(targetPlayer)
        exports['sandbox-hud']:Notification(source, "success", "Returned inventory for SID: " .. args[1])
    end, {
        help = 'Restores a previously confiscated inventory for the target by SID',
        params = {
            { name = 'SID', help = 'The SID of the player to return items to' },
        },
    }, 1)

    RegisterServerEvent('Jobs:Server:JobUpdate', function(source)
        local playerInventory = Inventory(source)
        if playerInventory then
            local newPlayerData = server.setPlayerData({ source = source })
            
            if newPlayerData.groups then
                playerInventory.player.groups = newPlayerData.groups
            end
            
            if newPlayerData.workplaces then
                playerInventory.player.workplaces = newPlayerData.workplaces
            end
            
            if server.syncInventory then
                server.syncInventory(playerInventory)
            end
        end
    end)

    exports["sandbox-chat"]:RegisterAdminCommand("clearinv", function(source, args, rawCommand)
        if args[1] == 'me' then
            exports.ox_inventory:ClearInventory(source)
            exports['sandbox-hud']:Notification(source, "success", "Cleared your inventory")
            return
        end

        local targetChar = exports['sandbox-characters']:FetchBySID(tonumber(args[1]))

        if not targetChar then
            exports['sandbox-hud']:Notification(source, "error", "Player with SID " .. args[1] .. " not found online")
            return
        end

        local targetPlayer = targetChar:GetData("Source")

        exports.ox_inventory:ClearInventory(targetPlayer)
        exports['sandbox-hud']:Notification(source, "success", "Cleared inventory for SID: " .. args[1])
    end, {
        help = 'Wipes all items from the target inventory (supports SID or "me")',
        params = {
            { name = 'SID', help = 'The SID or "me" to wipe items from' },
        },
    }, 1)

    exports["sandbox-chat"]:RegisterAdminCommand("saveinv", function(source, args, rawCommand)
        local lock = args[1]
        exports.ox_inventory:SaveInventories(lock == 'true', false)
    end, {
        help = 'Save all pending inventory changes to the database',
        params = {
            { name = 'lock', help = 'Lock inventory access, until restart or saved without a lock', optional = true },
        },
    }, -1)

    exports["sandbox-chat"]:RegisterAdminCommand("viewinv", function(source, args, rawCommand)
        if args[1] == 'me' then
            exports.ox_inventory:InspectInventory(source, source)
            return
        end

        local targetChar = exports['sandbox-characters']:FetchBySID(tonumber(args[1]))

        if not targetChar then
            exports['sandbox-hud']:Notification(source, "error", "Player with SID " .. args[1] .. " not found online")
            return
        end

        local targetPlayer = targetChar:GetData("Source")

        exports.ox_inventory:InspectInventory(source, targetPlayer)
    end, {
        help = 'Inspect the target inventory without allowing interactions (supports SID or "me")',
        params = {
            { name = 'SID', help = 'The SID or "me" to inspect' },
        },
    }, 1)
end)

AddEventHandler("Characters:Server:PlayerLoggedOut", function(source)
    server.playerDropped(source)

    if GetNumPlayerIndices() == 0 then
        Inventory.SaveInventories(false, true)
    end
end)

AddEventHandler("Characters:Server:PlayerDropped", function(source)
    server.playerDropped(source)

    if GetNumPlayerIndices() == 0 then
        Inventory.SaveInventories(false, true)
    end
end)

local function loadPlayerInv(src, newPlayer)
    local char = exports['sandbox-characters']:FetchCharacterSource(src)
    local id = char:GetData('SID')
    local cash = char:GetData('Cash')
    local name = string.format('%s %s', char:GetData("First"), char:GetData("Last"))
    server.setPlayerInventory({ identifier = id, name = name, source = src })

    --Wait(3000)

    exports.ox_inventory:SetItem(src, 'money', cash)
    if newPlayer then
        Inventory.AddItem(src, 'phone', 1)
        Inventory.AddItem(src, 'bandage', 10)
        Inventory.AddItem(src, 'burger', 5)
        Inventory.AddItem(src, 'water', 5)
        Inventory.AddItem(src, 'rep_voucher', 2, { Reputation = "Salvaging", Amount = 6000 })
    end
end

---@diagnostic disable-next-line: duplicate-set-field
server.syncInventory = function(inv)
    local accounts = Inventory.GetAccountItemCounts(inv)
    local char = exports['sandbox-characters']:FetchCharacterSource(inv.id)

    if accounts then
        if accounts.money and accounts.money ~= char:GetData('Cash') then
            char:SetData('Cash', accounts.money)
        end
    end
end

RegisterServerEvent('Characters:Server:Spawning', function(newCharacter)
    local char = exports['sandbox-characters']:FetchCharacterSource(source)
    local isNewCharacter = false

    if char then
        isNewCharacter = char:GetData("New") or false
    end

    loadPlayerInv(source, isNewCharacter)
end)

SetTimeout(500, function()
    for _, serverId in ipairs(GetPlayers()) do
        loadPlayerInv(tonumber(serverId))
    end
end)

-- ---@diagnostic disable-next-line: duplicate-set-field
-- function server.syncInventory(inv)
-- 	local accounts = Inventory.GetAccountItemCounts(inv)

-- 	if accounts then
-- 		local char = exports['sandbox-characters']:FetchCharacterSource(inv.id)

-- 		if accounts.money and accounts.money ~= char:GetData('Cash') then
-- 			char:SetData('Cash', accounts.money)
-- 		end
-- 	end
-- end

RegisterNetEvent("Characters:Server:SetData", function(source, key, data)
    if key == 'Cash' then
        Inventory.SetItem(source, 'money', data)
    elseif key == 'Jobs' then
        local jobs = exports['sandbox-characters']:FetchCharacterSource(source):GetData('Jobs')
        local newGroups = {}
        for i = 1, #jobs do
            local job = jobs[i]
            newGroups[job.Id] = job.Grade.Level
        end
        local inventory = Inventory(source)
        inventory.player.groups = newGroups
    end
end)

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    local jobs = exports['sandbox-characters']:FetchCharacterSource(player.source):GetData('Jobs')
    local newGroups = {}
    local workplaces = {}
    for i = 1, #jobs do
        local job = jobs[i]
        newGroups[job.Id] = job.Grade.Level

        if job.Workplace then
            workplaces[job.Id] = job.Workplace
        end
    end
    return {
        identifier = player.identifier,
        source = player.source,
        groups = newGroups,
        workplaces = workplaces,
    }
end

function server.hasWorkplace(inv, workplace)
    if not inv.player.workplaces then return false end

    if type(workplace) == 'table' then
        for _, wp in pairs(workplace) do
            for jobId, playerWorkplace in pairs(inv.player.workplaces) do
                if playerWorkplace == wp then
                    return true, jobId, playerWorkplace
                end
            end
        end
    else
        for jobId, playerWorkplace in pairs(inv.player.workplaces) do
            if playerWorkplace == workplace then
                return true, jobId, playerWorkplace
            end
        end
    end

    return false
end

function server.isOnDuty(source, jobName)
    if jobName then
        if type(jobName) == 'table' then
            for _, job in ipairs(jobName) do
                if exports['sandbox-jobs']:DutyGet(source, job) ~= false then
                    return true
                end
            end
            return false
        else
            return exports['sandbox-jobs']:DutyGet(source, jobName) ~= false
        end
    else
        return exports['sandbox-jobs']:DutyGet(source) ~= false
    end
end

function server.hasBalance(source, amt)
    local char = exports['sandbox-characters']:FetchCharacterSource(source)
    if char ~= nil then
        local sid = char:GetData("SID")
        local f = exports['sandbox-finance']:AccountsGetPersonal(sid)

        if f ~= nil then
            if exports['sandbox-finance']:BalanceHas(f.Account, amt) then
                return true
            end

            return false
        end

        return false
    end

    return false
end

function server.withdrawMoney(source, amt, itemLabel, count)
    local char = exports['sandbox-characters']:FetchCharacterSource(source)
    if char ~= nil then
        local sid = char:GetData("SID")
        local f = exports['sandbox-finance']:AccountsGetPersonal(sid)

        if f ~= nil then
            if exports['sandbox-finance']:BalanceWithdraw(f.Account, amt, {
                    type = "withdraw",
                    title = "Shop Purchase",
                    description = string.format("Bought %s $%s", count, itemLabel),
                    transactionAccount = false,
                    data = {
                        character = sid,
                    },
                }) then
                return true
            end

            return false
        end

        return false
    end

    return false
end

local function hasValue(tbl, value)
    if not tbl then return false end
    for k, v in ipairs(tbl) do
        if v == value or (type(v) == "table" and hasValue(v, value)) then
            return true
        end
    end
    return false
end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(source, name)
    local char = exports['sandbox-characters']:FetchCharacterSource(source)

    if not char then return end

    return char:GetData("Licenses")?[name]?.Active
end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasQualification(source, name)
    local char = exports['sandbox-characters']:FetchCharacterSource(source)

    if not char then return end

    return hasValue(char:GetData("Qualifications"), name)
end

function server.hasRep(source, rep)
    if rep then
        return exports["sandbox-characters"]:RepHasLevel(source, rep.id, rep.level)
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group)
    return exports["sandbox-jobs"]:IsOwner(playerId, group)
end

---@param entityId number
---@return number | string | nil
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    local VIN = Entity(entityId).state.VIN

    if exports["sandbox-vehicles"]:OwnedGetActive(VIN) then
        return VIN
    end
end

local function Item(name, cb)
    local item = ItemList[name]

    if item and not item.cb then
        item.cb = cb
    end
end

local function convertItemSlotOxToOld(item, inventoryId)
    return item and {
        Slot = item.slot,
        Name = item.name,
        Label = item.label,
        Owner = inventoryId,
        Quality = item.metadata?.Quality,
        MetaData = item.metadata,
        CreateDate = item.metadata.degrade and item.metadata.durability - item.metadata.degrade
    } or nil
end

local function convertItemDataOxToOld(item)
    return item and {
        name = item.name,
        label = item.label,
        isStackable = item.stack,
        type = item.legacy?.type,
        closeUi = item.close,
        weight = item.weight,
        isDestroyed = item.decay,
        durability = item.degrade,
    } or nil
end

local function formatDateToAmerican(date_string)
    local year, month, day = date_string:match("^(%d+)%-(%d+)%-(%d+)T")

    local timestamp = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day)
    })

    local formatted_date = os.date("%m/%d/%Y", timestamp)
    return formatted_date
end

local id_template = [[
	Sex: %s
	DOB: %s
	State ID: %s
]]

local methRunRouteOptions = {
    "ballas", "gsf", "vagos", "armenian"
}

local cokeRunRouteOptions = {
    "southside", "mirror_park", "vespucci_beach", "blvd_hills"
}

local UnnamedDiamondOptions = {
    {
        label = "Emissarius", --Stallion
        description = "\"The Stallion pushes forward through all forms of terrain.\" - _Inscribed_ ",
    },
    {
        label = "Fides", --Loyalty
        description = "\"Loyalty beyond death is an oathswearers purpose. I pledge my life to you.\" - _Inscribed_ ",
    },
    {
        label = "Peccator", --Sin
        description = "\"We are all sinners...  Shall I begin?\" - _Inscribed_",
    },
}

function BuildMetaDataTable(cData, item, existing)
    local itemExist = ItemList[item]
    local MetaData = lib.table.deepclone(existing or {})

    if itemExist.staticMetadata ~= nil then
        for k, v in pairs(itemExist.staticMetadata) do
            MetaData[k] = v
        end
    end

    if itemExist.legacy?.type == 11 and not MetaData.hiddenGemQuality and not MetaData.gemQuality then
        MetaData.hiddenGemQuality = math.random(100)
        if itemExist.name == "unnamed_diamond" and not MetaData.hiddenLabel and not MetaData.hiddenDescription then
            local randomMetaOption = UnnamedDiamondOptions[math.random(#UnnamedDiamondOptions)]
            MetaData.hiddenLabel = randomMetaOption.label
            MetaData.hiddenDescription = randomMetaOption.description
        end
    elseif itemExist.name == "choplist" then
        MetaData.Owner = cData.SID
        MetaData.ChopList = exports['sandbox-laptop']:LSUndergroundChoppingGenerateList(math.random(4, 8),
            math.random(3, 5))
        local chopListString = ""
        for i = 1, #MetaData.ChopList do
            chopListString = chopListString .. MetaData.ChopList[i].name .. ((i == #MetaData.ChopList and "") or "  \n")
        end
        MetaData.description = chopListString
    elseif itemExist.name == "moneybag" and not MetaData.Finish then
        MetaData.Finished = os.time() + (60 * 60 * 24 * math.random(1, 3))
        if not MetaData.CustomAmt then
            MetaData.CustomAmt = 30000 + math.random(15000)
        end
    elseif itemExist.name == "briefcase_cash" and not MetaData.Finish then
        if not MetaData.CustomAmt then
            MetaData.CustomAmt = 5000 + math.random(10000)
        end
    elseif itemExist.name == "crypto_voucher" and not MetaData.CryptoCoin and not MetaData.Quantity then
        MetaData.CryptoCoin = "MALD"
        MetaData.Quantity = math.random(25, 50)
    elseif itemExist.name == "rep_voucher" and not MetaData.Reputation and not MetaData.Amount then
        MetaData.Reputation = "Chopping"
        MetaData.Amount = math.random(1000, 5000)
    elseif itemExist.name == "vpn" then
        local firstName = exports['sandbox-base']:GeneratorNameFirst()
        local lastName = exports['sandbox-base']:GeneratorNameLast()
        MetaData.VpnName = firstName .. " " .. lastName
    elseif itemExist.name == "cigarette_pack" then
        MetaData.Count = 30
    elseif itemExist.name == "rusty_strawsprinkbox" then
        MetaData.Count = 10
    elseif itemExist.name == "rusty_ringmixbox" then
        MetaData.Count = 6
    elseif itemExist.name == "rusty_ringbox" then
        MetaData.Count = 12
    elseif itemExist.name == "rusty_pd" then
        MetaData.Count = 12
    elseif itemExist.name == "meth_table" and not MetaData.MethTable then
        MetaData.MethTable = exports['sandbox-drugs']:MethGenerateTable(1)
    elseif itemExist.name == "adv_meth_table" and not MetaData.MethTable then
        MetaData.MethTable = exports['sandbox-drugs']:MethGenerateTable(2)
    elseif itemExist.name == "meth_brick" and not MetaData.Finished then
        MetaData.Finished = os.time() + (60 * 60 * 24)
        if not MetaData.Quality then
            MetaData.Quality = math.random(1, 50)
        end
    elseif itemExist.name == "moonshine" and not MetaData.Quality then
        MetaData.Quality = math.random(1, 50)
    elseif (itemExist.name == "meth_bag" or itemExist.name == "coke_bag" or itemExist.name == "coke_brick") and not MetaData.Quality then
        MetaData.Quality = math.random(1, 50)
    elseif (itemExist.name == "coke_run_map" and not MetaData.Zone) then
        local cokeRouteRandom = cokeRunRouteOptions[math.random(1, #cokeRunRouteOptions)]
        MetaData.Zone = cokeRouteRandom
        MetaData.description = "Route: " .. cokeRouteRandom .. ""
    elseif (itemExist.name == "meth_run_map" and not MetaData.Zone) then
        local methRouteRandom = methRunRouteOptions[math.random(1, #methRunRouteOptions)]
        MetaData.Zone = methRouteRandom
        MetaData.description = "Route: " .. methRouteRandom .. ""
    elseif itemExist.name == "moonshine_still" and not MetaData.Still then
        MetaData.Still = exports['sandbox-drugs']:MoonshineStillGenerate(1)
    elseif itemExist.name == "moonshine_barrel" and not MetaData.Brew then
        MetaData.Brew = exports['sandbox-drugs']:MoonshineBarrelGenerate(1)
    elseif itemExist.name == "lsundg_invite" and cData then
        MetaData.Inviter = {
            SID = cData.SID,
            First = cData.First,
            Last = cData.Last
        }
    elseif (itemExist.name == "pd_panic_button" or itemExist.name == "doc_panic_button" or itemExist.name == "ems_panic_button") and cData then
        MetaData.Officer = {
            Callsign = cData.Callsign or "???",
            First = cData.First,
            Last = cData.Last,
            SID = cData.SID,
        }
    elseif itemExist.name == "shark_card" and not MetaData.Amount then
        MetaData.Amount = math.random(5000, 8000)
    elseif itemExist.name == "nitrous" and not MetaData.Nitrous then
        MetaData.Nitrous = 100
    elseif itemExist.name == "evidence-casing" and not MetaData.CollectedTime then
        MetaData.CollectedTime = os.time()
        if MetaData.EvidenceWeapon and MetaData.EvidenceWeapon.serial then
            local weaponItem = ItemList[MetaData.EvidenceWeapon.name]
            local weaponLabel = (weaponItem and weaponItem.label) or MetaData.EvidenceWeapon.name or "Unknown Weapon"
            
            MetaData.description = string.format(
                "Casing from %s\nSerial: %s\nAmmo: %s",
                weaponLabel,
                MetaData.EvidenceWeapon.serial,
                MetaData.EvidenceAmmoType or "Unknown"
            )
        end
    elseif itemExist.name == "evidence-projectile" and not MetaData.CollectedTime then
        MetaData.CollectedTime = os.time()
        if MetaData.EvidenceDegraded then
            MetaData.description = "⚠️ Evidence too degraded for analysis"
        else
            local weaponLabel = "Unknown Weapon"
            if MetaData.EvidenceWeapon then
                local weaponItem = ItemList[MetaData.EvidenceWeapon.name]
                weaponLabel = (weaponItem and weaponItem.label) or MetaData.EvidenceWeapon.name or "Unknown Weapon"
            end

            MetaData.description = string.format(
                "Evidence ID: %s\nAmmo: %s",
                MetaData.EvidenceId or "N/A",
                MetaData.EvidenceAmmoType or "Unknown"
            )
        end
    elseif itemExist.name == "evidence-dna" and not MetaData.CollectedTime then
        MetaData.CollectedTime = os.time()
        if MetaData.EvidenceDegraded then
            MetaData.description = "⚠️ DNA sample too degraded for analysis"
        elseif MetaData.EvidenceDNA then
            MetaData.description = string.format(
                "%s DNA Sample\nSID: %s",
                MetaData.EvidenceBloodPool and "Blood Pool" or "Blood",
                MetaData.EvidenceDNA
            )
        end
    elseif itemExist.name == "evidence-paint" and not MetaData.CollectedTime then
        MetaData.CollectedTime = os.time()
        if MetaData.EvidenceColor then
            local color = MetaData.EvidenceColor
            MetaData.description = string.format(
                "Paint Fragment\nRGB: (%d, %d, %d)",
                color.r or 0,
                color.g or 0,
                color.b or 0
            )
        end
    elseif itemExist.name == "fakeplates" then
        local updatingMetaData = {
            Plate = exports['sandbox-vehicles']:PlateGenerate(true),
            VIN = exports['sandbox-vehicles']:VINGenerateLocal(),
            OwnerName = exports['sandbox-base']:GeneratorNameFirst() .. " " .. exports['sandbox-base']:GeneratorNameLast(),
            SID = exports['sandbox-base']:SequenceGet("Character"),
            Vehicle = exports['sandbox-vehicles']:RandomName(),
        }
    
        MetaData.metadata = updatingMetaData
    
        MetaData.description = string.format(
            "Fake Plate\nOwner: %s  | Plate: %s",
            updatingMetaData.OwnerName,
            updatingMetaData.Plate
        )
    end


    return MetaData
end

exports('BuildMetaDataTable', BuildMetaDataTable)

local itemUseContext = {}

exports('GetInventory', function(source, owner, invType)
    if tonumber(owner) then
        return exports.ox_inventory:GetInventory(source, false)
    else
        return exports.ox_inventory:GetInventory(owner, false)
    end
end)

exports('OpenSecondary',
    function(_src, invType, Owner, vehClass, vehModel, isRaid, nameOverride, slotOverride, capacityOverride)
        if tonumber(Owner) then -- probably a player?
            local char = exports['sandbox-characters']:FetchBySID(Owner)
            Owner = char:GetData("Source")
        end
        local inventory = exports.ox_inventory:GetInventory(owner, false)
        if inventory then
            Inventory.forceOpenInventory(_src, inventory.type, Owner)
        end
    end)

exports('GetSlots', function(Owner, Type)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    local slots = exports.ox_inventory:GetInventory(Owner, false)?.items
    return slots
end)

exports('GetSlotCount', function(Owner, Type)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    local inventory = exports.ox_inventory:GetInventory(Owner, false)
    return inventory.slots
end)

exports('GetNumberOfFreeSlots', function(id)
    local inv = exports.ox_inventory:GetInventory(id, false)
    local items = inv?.items
    local inventorySlots = inv?.slots

    return inventorySlots - #items
end)

exports('OldGetSlot', function(Owner, Slot, Type)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    return exports.ox_inventory:GetSlot(Owner, Slot)
end)

exports('CountInSlot', function(Owner, Slot, Type)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    return exports.ox_inventory:GetSlot(Owner, Slot)?.count or 0
end)

exports('GetItem',
    function(id) ---@todo used only for placing methtable/moonshine still. may need to rewrite that to cache the propId of the thing. saved in metadata
        return MySQL.prepare.await(
            'SELECT id, count(*) as Count, owner as Owner, type as invType, item_id as Name, price as Price, quality AS Quality, information as MetaData, slot as Slot, creationDate as CreateDate FROM inventory WHERE id = ?',
            {
                id
            })
    end)

exports('AddItem',
    function(Owner, Name, Count, md, invType, vehClass, vehModel, entity, isRecurse, Slot, forceCreateDate, quality,
             skipMetaGen, skipChangeAlert)
        local char = exports['sandbox-characters']:FetchBySID(Owner)

        if tonumber(Owner) then -- probably a player?
            Owner = char:GetData("Source")
        end

        if quality then
            if not md then
                md = {}
            end
            md.Quality = quality
        end

        return Inventory.AddItem(Owner, Name, Count, md, Slot)
    end)

exports('AddSlot', function(Owner, Name, Count, md, Slot, Type, forceCreateDate, quality)
    local char = exports['sandbox-characters']:FetchBySID(Owner)

    if tonumber(Owner) then -- probably a player?
        Owner = char:GetData("Source")
    end

    if quality then
        if not md then
            md = {}
        end
        md.quality = quality
    end

    return Inventory.AddItem(Owner, Name, Count, md, Slot)
end)

exports('SetItemCreateDate', function(source, slot, value)
    local slotData = Inventory.GetSlot(source, slot)
    if not slotData then
        print('no slot data', source, slot)
        return
    end
    local itemData = Items(slotData.name)
    local newValue = value + itemData.degrade
    if os.time() > newValue then
        exports.ox_inventory:RemoveItem(source, itemData.name, 1, nil, slot)
    else
        exports.ox_inventory:SetDurability(source, slot, newValue)
    end
end)

exports('SetMetaDataKey', function(slot, key, value, invId)
    local item = exports.ox_inventory:GetSlot(invId, slot)
    local md = item.metadata
    if md then
        md[key] = value
    end
    exports.ox_inventory:SetMetadata(invId, slot, md)
    return md
end)

exports('UpdateMetaData', function(source, slot, updatingMeta)
    local item = exports.ox_inventory:GetSlot(source, slot)
    local md = item.metadata
    if md then
        for key, value in pairs(updatingMeta) do
            md[key] = value
        end
    end
    exports.ox_inventory:SetMetadata(source, slot, md)
    return md
end)

exports('ItemsGetData', function(item)
    return convertItemDataOxToOld(ItemList[item])
end)

exports('ItemsGetCount', function(Owner, invType, item)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    return exports.ox_inventory:GetItemCount(Owner, item)
end)

exports('ItemsGetFirst', function(Owner, Name, invType)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end

    return convertItemSlotOxToOld(exports.ox_inventory:GetSlotWithItem(Owner, Name), Owner)
end)

exports('ItemsGetAll', function(Owner, Name, invType)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end

    local items = exports.ox_inventory:GetSlotsWithItem(Owner, Name)

    if #items > 0 then
        for k, v in ipairs(items) do
            items[k] = convertItemSlotOxToOld(items[k], Owner)
        end
    end

    return items
end)

exports('ItemsHas', function(Owner, invType, item, count)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    return exports.ox_inventory:GetItemCount(Owner, item) >= count
end)

exports('ItemsHasItems', function(source, items)
    for _, v in ipairs(items) do
        if not exports.ox_inventory:GetItemCount(source, v.item) >= v.count then
            return false
        end
    end
    return true
end)

exports('ItemsHasAnyItems', function(source, items)
    for _, v in ipairs(items) do
        if exports.ox_inventory:GetItemCount(source, v.item) >= v.count then
            return true
        end
    end

    return false
end)

exports('GetAllOfTypeNoStack', function(Owner, invType, itemType)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    local items = exports.ox_inventory:GetInventoryItems(Owner)
    local rightType = {}
    for k, v in pairs(items) do
        local itemData = Items(v.name)
        if itemData?.legacy?.type == itemType then
            table.insert(rightType, convertItemSlotOxToOld(v, Owner))
        end
    end
    return rightType
end)

exports('RegisterUse', function(name, id, cb)
    if not itemUseContext[name] then
        itemUseContext[name] = {}
        itemUseContext[name][id] = cb
        Item(name, function(event, item, inventory, slot, data)
            if event == 'usedItem' then
                item.metadata = inventory.usingItem.metadata
                item.slot = slot
                for _, call in pairs(itemUseContext[name]) do
                    call(inventory.id, convertItemSlotOxToOld(item, inventory.owner),
                        convertItemDataOxToOld(ItemList[name]))
                end
            end
        end)
    else
        itemUseContext[name][id] = cb
    end
end)

exports('Remove', function(Owner, invType, item, count, skipUpdate)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    return exports.ox_inventory:RemoveItem(Owner, item, count)
end)

exports('RemoveId', function(Owner, invType, item)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    return exports.ox_inventory:RemoveItem(Owner, item.Name, 1, nil, item.Slot)
end)

exports('RemoveAll', function(Owner, type, item)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    return exports.ox_inventory:RemoveItem(Owner, item, exports.ox_inventory:GetItemCount(Owner, item))
end)

exports('RemoveSlot', function(Owner, Name, Count, Slot, invType)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end

    local inv = Inventory(Owner)
    if not inv then return false end

    -- This needs to be done because when I used 1 item, but had 3 of the same item within the inventory, it removed all 3 of them
    if inv.items[Slot] and inv.items[Slot].name == Name then
        return Inventory.RemoveItem(inv, Name, Count, nil, Slot)
    else
        return false
    end
end)

exports('RemoveList', function(Owner, invType, items)
    if tonumber(Owner) then -- probably a player?
        local char = exports['sandbox-characters']:FetchBySID(Owner)
        Owner = char:GetData("Source")
    end
    for _, v in ipairs(items) do
        exports.ox_inventory:RemoveItem(Owner, v.name, v.count)
    end
end)

exports('GetWithStaticMetadata', function(masterKey, mainIdName, textureIdName, gender, data)
    for k, v in pairs(ItemList) do
        if v.staticMetadata ~= nil
            and v.staticMetadata[masterKey] ~= nil
            and v.staticMetadata[masterKey][gender] ~= nil
            and v.staticMetadata[masterKey][gender][mainIdName] == data[mainIdName]
            and v.staticMetadata[masterKey][gender][textureIdName] == data[textureIdName]
        then
            return k
        end
    end

    return nil
end)

exports('HoldingPut', function(source)
    exports.ox_inventory:ReturnInventory(source)
    Wait(1000)
    exports.ox_inventory:ConfiscateInventory(source)
end)

exports('HoldingTake', function(source)
    exports.ox_inventory:ReturnInventory(source)
end)

exports('SearchCharacter', function(src, tSrc, id)
    exports.ox_inventory:forceOpenInventory(src, 'player', tSrc)
end)

exports('Rob', function(src, tSrc, id)
    exports.ox_inventory:forceOpenInventory(src, 'player', tSrc)
end)

function RegisterOXINVMiddleware()
    exports['sandbox-base']:MiddlewareAdd('Characters:Logout', function(source)
        Inventory.SaveInventories(false, true)
    end, 1)
end

function RegisterRandomItems()
    exports.ox_inventory:RegisterUse("vanityitem", "VanityItems", function(source, item, itemData)
        if item?.MetaData?.CustomItemAction == "overlay" then
            TriggerClientEvent("Inventory:Client:UseVanityItem", source, source, item.MetaData.CustomItemAction, item)
        elseif item?.MetaData?.CustomItemAction == "overlayall" then
            TriggerClientEvent("Inventory:Client:UseVanityItem", -1, source, item.MetaData.CustomItemAction, item)
        end
    end)

    exports.ox_inventory:RegisterUse("cigarette", "RandomItems", function(source, item)
        Player(source).state.stressTicks = { "3", "3", "3", "3", "3", "3", "3", "3" }
        TriggerClientEvent("Status:Client:Ticks:Stress", source)
    end)

    exports.ox_inventory:RegisterUse("buttplug_black", "ERP", function(source, item)
        TriggerClientEvent('Inventory:Client:ERP:ButtPlug', source, "black")
    end)

    exports.ox_inventory:RegisterUse("carvedpumpkin", "Misc", function(source, item)
        TriggerClientEvent('Inventory:Client:Halloween:Pumpkin', source, "pumpkin1")
    end)

    exports.ox_inventory:RegisterUse("sign_dontblock", "Signs", function(source, item)
        TriggerClientEvent('Inventory:Client:Signs:UseSign', source, item)
    end)

    exports.ox_inventory:RegisterUse("sign_leftturn", "Signs", function(source, item)
        TriggerClientEvent('Inventory:Client:Signs:UseSign', source, item)
    end)

    exports.ox_inventory:RegisterUse("sign_nopark", "Signs", function(source, item)
        TriggerClientEvent('Inventory:Client:Signs:UseSign', source, item)
    end)

    exports.ox_inventory:RegisterUse("sign_notresspass", "Signs", function(source, item)
        TriggerClientEvent('Inventory:Client:Signs:UseSign', source, item)
    end)

    exports.ox_inventory:RegisterUse("sign_rightturn", "Signs", function(source, item)
        TriggerClientEvent('Inventory:Client:Signs:UseSign', source, item)
    end)

    exports.ox_inventory:RegisterUse("sign_stop", "Signs", function(source, item)
        TriggerClientEvent('Inventory:Client:Signs:UseSign', source, item)
    end)

    exports.ox_inventory:RegisterUse("sign_uturn", "Signs", function(source, item)
        TriggerClientEvent('Inventory:Client:Signs:UseSign', source, item)
    end)

    exports.ox_inventory:RegisterUse("sign_walkingman", "Signs", function(source, item)
        TriggerClientEvent('Inventory:Client:Signs:UseSign', source, item)
    end)

    exports.ox_inventory:RegisterUse("sign_yield", "Signs", function(source, item)
        TriggerClientEvent('Inventory:Client:Signs:UseSign', source, item)
    end)

    exports.ox_inventory:RegisterUse("redlight", "RandomItems", function(source, item)
        TriggerClientEvent('Inventory:Client:RandomItems:Redlight', source)
    end)

    exports.ox_inventory:RegisterUse("buttplug_pink", "ERP", function(source, item)
        TriggerClientEvent('Inventory:Client:ERP:ButtPlug', source, "pink")
    end)

    exports.ox_inventory:RegisterUse("vibrator_pink", "ERP", function(source, item)
        TriggerClientEvent('Inventory:Client:ERP:Vibrator', source, "pink")
    end)

    exports.ox_inventory:RegisterUse("briefcase_cash", "RandomItems", function(source, item)
        exports['sandbox-hud']:Notification(source, "error", "No money to be found.")

        -- local Winnings = 25000
        -- local char = exports['sandbox-characters']:FetchCharacterSource(source)
        -- exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
        -- TriggerClientEvent('Inventory:Client:RandomItems:BriefcaseCash', source)
        -- Banking.Balance:Deposit(Banking.Accounts:GetPersonal(char:GetData("SID")).Account, Winnings, {
        -- 	type = "deposit",
        -- 	title = "Lotto Event",
        -- 	description = string.format("Lotto Earnings - $%s", Winnings),
        -- 	data = Winnings
        -- })
        -- exports['sandbox-hud']:Notification(source, "success", "You found a briefcase with $25,000!")
    end)

    exports.ox_inventory:RegisterUse("cigarette_pack", "RandomItems", function(source, item)
        if (item.MetaData.Count and tonumber(item.MetaData.Count) or 0) > 0 then
            Inventory.AddItem(item.Owner, "cigarette", 1,
                { durability = item.MetaData.durability, degrade = item.MetaData.degrade }, 1)
            if tonumber(item.MetaData.Count) - 1 <= 0 then
                exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            else
                exports.ox_inventory:SetMetaDataKey(item.Slot, "Count", tonumber(item.MetaData.Count) - 1,
                    source)
            end
        else
            exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            exports['sandbox-hud']:Notification(source, "error", "Pack Has No More Cigarettes In It")
        end
    end)

    exports.ox_inventory:RegisterUse("rusty_strawsprinkbox", "RustyBrowns", function(source, item)
        if (item.MetaData.Count and tonumber(item.MetaData.Count) or 0) > 0 then
            Inventory.AddItem(item.Owner, "rusty_strawsprinkle", 1, {}, 1)
            if tonumber(item.MetaData.Count) - 1 <= 0 then
                exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            else
                exports.ox_inventory:SetMetaDataKey(item.Slot, "Count", tonumber(item.MetaData.Count) - 1,
                    source)
            end
        else
            exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            exports['sandbox-hud']:Notification(source, "error", "Box Has No More Donuts In It")
        end
    end)

    exports.ox_inventory:RegisterUse("rusty_ringmixbox", "RustyBrowns", function(source, item)
        local _mixedDonuts = {
            [1] = {
                name = 'rusty_blueice'
            },
            [2] = {
                name = 'rusty_lemon'
            },
            [3] = {
                name = 'rusty_cookiecream'
            },
            [4] = {
                name = 'rusty_strawsprinkle'
            },
            [5] = {
                name = 'rusty_chocsprinkle'
            },
            [6] = {
                name = 'rusty_ring'
            },
        }
        if (item.MetaData.Count and tonumber(item.MetaData.Count) or 0) > 0 then
            Inventory.AddItem(item.Owner, _mixedDonuts[math.random(#_mixedDonuts)].name, 1, {}, 1)
            if tonumber(item.MetaData.Count) - 1 <= 0 then
                exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            else
                exports.ox_inventory:SetMetaDataKey(item.Slot, "Count", tonumber(item.MetaData.Count) - 1,
                    source)
            end
        else
            exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            exports['sandbox-hud']:Notification(source, "error", "Box Has No More Donuts In It")
        end
    end)

    exports.ox_inventory:RegisterUse("rusty_ringbox", "RustyBrowns", function(source, item)
        local _mixedDonuts = {
            [1] = {
                name = 'rusty_blueice'
            },
            [2] = {
                name = 'rusty_lemon'
            },
            [3] = {
                name = 'rusty_cookiecream'
            },
            [4] = {
                name = 'rusty_strawsprinkle'
            },
            [5] = {
                name = 'rusty_chocsprinkle'
            },
            [6] = {
                name = 'rusty_ring'
            },
            [7] = {
                name = 'rusty_chocstuff'
            },
            [8] = {
                name = 'rusty_custard'
            },
        }
        if (item.MetaData.Count and tonumber(item.MetaData.Count) or 0) > 0 then
            Inventory.AddItem(item.Owner, _mixedDonuts[math.random(#_mixedDonuts)].name, 1, {}, 1)
            if tonumber(item.MetaData.Count) - 1 <= 0 then
                exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            else
                exports.ox_inventory:SetMetaDataKey(item.Slot, "Count", tonumber(item.MetaData.Count) - 1,
                    source)
            end
        else
            exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            exports['sandbox-hud']:Notification(source, "error", "Box Has No More Donuts In It")
        end
    end)

    exports.ox_inventory:RegisterUse("rusty_pd", "RustyBrowns", function(source, item)
        local _mixedDonuts = {
            [1] = {
                name = 'rusty_strawsprinkle'
            },
            [2] = {
                name = 'rusty_chocsprinkle'
            },
            [3] = {
                name = 'rusty_ring'
            },
        }
        if (item.MetaData.Count and tonumber(item.MetaData.Count) or 0) > 0 then
            Inventory.AddItem(item.Owner, _mixedDonuts[math.random(#_mixedDonuts)].name, 1, {}, 1)
            if tonumber(item.MetaData.Count) - 1 <= 0 then
                exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            else
                exports.ox_inventory:SetMetaDataKey(item.Slot, "Count", tonumber(item.MetaData.Count) - 1,
                    source)
            end
        else
            exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            exports['sandbox-hud']:Notification(source, "error", "Box Has No More Donuts In It")
        end
    end)

    exports.ox_inventory:RegisterUse("armor", "RandomItems", function(source, item)
        exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
        SetPedArmour(GetPlayerPed(source), 50)
    end)

    exports.ox_inventory:RegisterUse("heavyarmor", "RandomItems", function(source, item)
        exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
        SetPedArmour(GetPlayerPed(source), 100)
    end)

    exports.ox_inventory:RegisterUse("pdarmor", "RandomItems", function(source, item)
        exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
        SetPedArmour(GetPlayerPed(source), 100)
    end)

    exports.ox_inventory:RegisterUse("parts_box", "RandomItems", function(source, item)
        local char = exports['sandbox-characters']:FetchCharacterSource(source)
        if char ~= nil then
            exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
            if item.MetaData.Items then
                for k, v in ipairs(item.MetaData.Items) do
                    Inventory.AddItem(item.Owner, v.name, v.count, {}, 1)
                end
            end
        end
    end)

    exports.ox_inventory:RegisterUse("birthday_cake", "RandomItems", function(source, item)
        exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)
        TriggerClientEvent('Inventory:Client:RandomItems:BirthdayCake', source)
    end)

    -- exports.ox_inventory:RegisterUse("parachute", "RandomItems", function(source, item)
    -- 	exports["sandbox-base"]:ClientCallback(source, "Weapons:CanEquipParachute", {}, function(canEquip)
    -- 		if canEquip then
    -- 			local char = exports['sandbox-characters']:FetchCharacterSource(source)
    -- 			if char then
    -- 				local states = char:GetData("States") or {}
    -- 				if not hasValue(states, "SCRIPT_PARACHUTE") then
    -- 					exports.ox_inventory:RemoveSlot(item.Owner, item.Name, 1, item.Slot, item.invType)

    -- 					table.insert(states, "SCRIPT_PARACHUTE")
    -- 					char:SetData("States", states)
    -- 				else
    -- 					exports['sandbox-hud']:Notification(source, "error", "Already Have Parachute Equipped")
    -- 				end
    -- 			end
    -- 		else
    -- 			exports['sandbox-hud']:Notification(source, "error", "Cannot Equip Parachute")
    -- 		end
    -- 	end)
    -- end)

    exports.ox_inventory:RegisterUse("shark_card", "RandomShit", function(source, item)
        local char = exports['sandbox-characters']:FetchCharacterSource(source)
        if char ~= nil then
            local sid = char:GetData("SID")
            local f = exports['sandbox-finance']:AccountsGetPersonal(sid)
            if f ~= nil then
                if exports.ox_inventory:RemoveId(sid, 1, item) then
                    local amt = item.MetaData.Amount
                    if item.MetaData.CustomAmt ~= nil then
                        amt = (item.MetaData.CustomAmt.Min or 0) + math.random(item.MetaData.CustomAmt.Random)
                    end

                    exports['sandbox-finance']:BalanceDeposit(f.Account, amt, {
                        type = "deposit",
                        title = "Shark Card",
                        description = "balance Redemption From A Shark Card",
                        data = {},
                    }, false)
                end
            end
        end
    end)

    exports.ox_inventory:RegisterUse("laptop", "Laptop", function(source)
        TriggerClientEvent("Laptop:Client:Open", source)
    end)

    exports["sandbox-base"]:RegisterServerCallback("Inventory:UsedParachute", function(source, data, cb)
        local char = exports['sandbox-characters']:FetchCharacterSource(source)
        if char then
            local states = char:GetData("States") or {}
            if hasValue(states, "SCRIPT_PARACHUTE") then
                for k, v in ipairs(states) do
                    if v == "SCRIPT_PARACHUTE" then
                        table.remove(states, k)
                        char:SetData("States", states)
                        break
                    end
                end
            end
        end
    end)
end

exports('LootItemClass', function(owner, invType, class, count)
    return Inventory.AddItem(owner, itemClasses[class][math.random(#itemClasses[class])], count, {}, nil)
end)

exports('LootCustomSet', function(set, owner, invType, count)
    return Inventory.AddItem(owner, set[math.random(#set)], count, {}, nil)
end)

exports('LootCustomSetWithCount', function(set, owner, invType)
    local i = set[math.random(#set)]
    local count = math.random(1, i.max)

    -- Call the internal AddItem function directly to avoid circular dependency
    return Inventory.AddItem(owner, i.name, count, {}, nil)
end)

exports('LootCustomWeightedSet', function(set, owner, invType)
    local randomItem = exports['sandbox-base']:UtilsWeightedRandom(set)
    if randomItem then
        return Inventory.AddItem(owner, randomItem, 1, {}, nil)
    end
end)

exports('LootCustomWeightedSetWithCount', function(set, owner, invType, dontAdd)
    local randomItem = exports['sandbox-base']:UtilsWeightedRandom(set)

    while not randomItem do
        randomItem = exports['sandbox-base']:UtilsWeightedRandom(set)
        Wait(300)
    end

    if randomItem?.name and randomItem?.max then
        if dontAdd then
            return {
                name = randomItem.name,
                count = math.random(randomItem.min or 1, randomItem.max),
                metadata = randomItem.metadata
            }
        else
            return Inventory.AddItem(owner, randomItem.name,
                math.random(randomItem.min or 1, randomItem.max),
                randomItem.metadata or {}, nil)
        end
    end
end)

exports('LootCustomWeightedSetWithCountAndModifier', function(set, owner, invType, modifier, dontAdd)
    local randomItem = exports['sandbox-base']:UtilsWeightedRandom(set)
    if randomItem?.name and randomItem?.max then
        if dontAdd then
            return {
                name = randomItem.name,
                count = math.random(randomItem.min or 1, randomItem.max) * modifier
            }
        else
            return Inventory.AddItem(owner, randomItem.name,
                math.random(randomItem.min or 1, randomItem.max) * modifier, randomItem.metadata or {}, nil)
        end
    end
end)

exports('LootGem', function(owner, invType)
    local randomGem = exports['sandbox-base']:UtilsWeightedRandom({
        { 5,  "diamond" },
        { 5,  "emerald" },
        { 5,  "sapphire" },
        { 5,  "ruby" },
        { 25, "amethyst" },
        { 25, "citrine" },
        { 75, "opal" },
    })
    return Inventory.AddItem(owner, randomGem, 1, {}, nil)
end)

exports('LootGemRandom', function(owner, invType, day)
    local randomGem = nil
    if day == 1 then
        randomGem = exports['sandbox-base']:UtilsWeightedRandom({
            { 15, "diamond" },
            { 15, "emerald" },
            { 20, "sapphire" },
            { 20, "ruby" },
            { 25, "amethyst" },
            { 25, "citrine" },
            { 50, "opal" },
        })
    else
        randomGem = exports['sandbox-base']:UtilsWeightedRandom({
            { 5,  "diamond" },
            { 5,  "emerald" },
            { 5,  "sapphire" },
            { 5,  "ruby" },
            { 25, "amethyst" },
            { 25, "citrine" },
            { 75, "opal" },
        })
    end

    return Inventory.AddItem(owner, randomGem, 1, {}, nil)
end)

exports('LootOre', function(owner, invType, count)
    local randomOre = exports['sandbox-base']:UtilsWeightedRandom({
        { 12, "goldore" },
        { 18, "silverore" },
        { 50, "ironore" },
    })
    return Inventory.AddItem(owner, randomOre, count, {}, nil)
end)

CreateThread(function()
    for name, itemData in pairs(ItemList) do
        if itemData.gangChain then
            exports.ox_inventory:RegisterUse(name, "GangChains", function(source, item)
                local char = exports['sandbox-characters']:FetchCharacterSource(source)
                if name ~= char:GetData("GangChain") then
                    TriggerClientEvent("Ped:Client:ChainAnim", source)
                    Wait(3000)
                    char:SetData("GangChain", name)
                else
                    TriggerClientEvent("Ped:Client:ChainAnim", source)
                    Wait(3000)
                    char:SetData("GangChain", "NONE")
                end
            end)
        end
        if itemData.drugState then
            exports.ox_inventory:RegisterUse(name, "DrugStates", function(source, item)
                local char = exports['sandbox-characters']:FetchCharacterSource(source)
                if char ~= nil then
                    local drugStates = char:GetData("DrugStates") or {}
                    drugStates[itemData.drugState.type] = {
                        item = name,
                        expires = os.time() + itemData.drugState.duration,
                    }
                    char:SetData("DrugStates", drugStates)
                end
            end)
        end
        if itemData.energyModifier then
            exports.ox_inventory:RegisterUse(name, "EnergyModifier", function(source, item)
                TriggerClientEvent(
                    "Inventory:Client:SpeedyBoi",
                    source,
                    itemData.energyModifier.modifier,
                    itemData.energyModifier.duration * 1000,
                    itemData.energyModifier.cooldown * 1000,
                    itemData.energyModifier.skipScreenEffects
                )
            end)
        end
        if itemData.progressModifier then
            exports.ox_inventory:RegisterUse(name, "ProgressModifier", function(source, item)
                local modifier = itemData.progressModifier.modifier or 0
                local duration = math.random(itemData.progressModifier.min or 1, itemData.progressModifier.max or 1) * 60 * 1000
                TriggerClientEvent("Inventory:Client:ProgressModifier", source, modifier, duration)
            end)
        end
        if itemData.healthModifier then
            exports.ox_inventory:RegisterUse(name, "HealthModifier", function(source, item)
                TriggerClientEvent("Inventory:Client:HealthModifier", source, itemData.healthModifier)
            end)
        end
        if itemData.armourModifier then
            exports.ox_inventory:RegisterUse(name, "ArmourModifier", function(source, item)
                TriggerClientEvent("Inventory:Client:ArmourModifier", source, itemData.armourModifier)
            end)
        end
        if itemData.stressTicks then
            exports.ox_inventory:RegisterUse(name, "StressTicks", function(source, item)
                local char = exports['sandbox-characters']:FetchCharacterSource(source)
                if char then
                    char.state.stressTicks = itemData.stressTicks
                    TriggerClientEvent("Status:Client:Ticks:Stress", source)
                end
            end)
        end
    end
end)


RegisterNetEvent('Inventory:ClearGangChain', function()
    local src = source
    local char = exports['sandbox-characters']:FetchCharacterSource(src)
    char:SetData('GangChain', "NONE")
end)

exports.ox_inventory:registerHook('swapItems', function(payload)
    if payload.toInventory:find('incinerator_') then
        SetTimeout(0, function()
            exports.ox_inventory:Clear(payload.toInventory)
        end)
    end
end, {
    print = true,
    inventoryFilter = {
        'incinerator_mrpd',
        'incinerator_sast',
        'incinerator_lmpd',
    }
})

exports.ox_inventory:registerHook('swapItems', function(payload)
    local toSlot = payload.toSlot
    local fromSlot = payload.fromSlot
    if type(toSlot) == 'table' and fromSlot?.name and not fromSlot?.name:find('WEAPON_') then
        return false
    elseif type(toSlot) == 'table' and toSlot?.name and not toSlot?.name:find('WEAPON_') then
        return false
    end
end, {
    print = true,
    inventoryFilter = {
        '^polsecuredcompartment[%w]+',
    }
})

RegisterServerEvent('Inventory:Server:Grapple:CreateRope', function(grappleid, dest)
    TriggerClientEvent('Inventory:Client:Grapple:CreateRope', -1, source, grappleid, dest)
end)

RegisterServerEvent('Inventory:Server:Grapple:DestroyRope', function(grappleid)
    TriggerClientEvent(string.format("Inventory:Client:Grapple:DestroyRope:%s", grappleid), -1)
end)

RegisterNetEvent('Inventory:handleItemState', function(state, count, item)
    local src = source
    local char = exports['sandbox-characters']:FetchCharacterSource(src)
    local states = char:GetData('States') or {}
    local update = false
    local hasItem = exports.ox_inventory:GetItemCount(src, item) > 0

    if count > 0 and hasItem and not lib.table.contains(states, state) then
        update = true
        table.insert(states, state)
    elseif (count < 1 or not hasItem) and lib.table.contains(states, state) then
        for i = #states, 1, -1 do
            if state == states[i] then
                update = true
                table.remove(states, i)
            end
        end
    end

    if update then
        char:SetData('States', states)
    end
end)