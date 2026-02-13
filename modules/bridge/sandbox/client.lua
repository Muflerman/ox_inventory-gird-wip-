local Inventory = require 'modules.inventory.client'
local Items = require 'modules.items.client'

function HandleItemState(state, count, item)
    TriggerServerEvent('Inventory:handleItemState', state, count, item)
end

RegisterNetEvent('handleWeaponTint', function(hash)
    if not cache.weapon then return end

    local weapon = exports.ox_inventory:getCurrentWeapon()

    SetPedWeaponTintIndex(cache.ped, cache.weapon, weapon.metadata.tint)
end)

AddEventHandler("onClientResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    exports.ox_inventory:displayMetadata({ -- For new metadata options, they need to be added here for them to show in-game.
        Quality = 'Grade',
        Count = 'Count',
        CryptoCoin = 'Crypto Coin',
        Quantity = 'Quantity',
        Reputation = 'Reputation',
        Amount = 'Amount',
        VpnName = 'VPN Name',
        hiddenGemQuality = 'Gem Quality',
        hiddenLabel = 'Label',
        hiddenDescription = 'Description',
        Owner = 'Owner',
        Finished = 'Cleans In',
        CustomAmt = 'Amount',
        MethTable = 'Meth Table',
        Zone = 'Zone',
        Still = 'Still',
        Brew = 'Brew',
        Inviter = 'Inviter',
        Officer = 'Officer',
        Nitrous = 'Nitrous',
    })
end)

RegisterNetEvent("Characters:Client:Logout", client.onLogout)

RegisterNetEvent("Characters:Client:Spawn", function()
    local data = LocalPlayer.state.Character:GetData('Jobs') or {}
    local newGroups = {}
    local workplaces = {}
    for i = 1, #data do
        local job = data[i]
        newGroups[job.Id] = job.Grade.Level

        if job.Workplace then
            workplaces[job.Id] = job.Workplace
        end
    end
    client.setPlayerData("groups", newGroups)
    client.setPlayerData("workplaces", workplaces)
end)

RegisterNetEvent("Characters:Client:SetData", function(key, data)
    if key == 'Jobs' then
        local newGroups = {}
        local workplaces = {}
        for i = 1, #data do
            local job = data[i]
            newGroups[job.Id] = job.Grade.Level

            if job.Workplace then
                workplaces[job.Id] = job.Workplace
            end
        end
        client.setPlayerData("groups", newGroups)
        client.setPlayerData("workplaces", workplaces)
    else
        client.setPlayerData(key, data)
    end
end)

---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    for type, statuses in pairs(values) do
        if type == 'Add' then
            for status, value in pairs(statuses) do
                exports['sandbox-status']:Add(status, tonumber(value or 0), 2)
            end
        elseif type == 'Remove' then
            for status, value in pairs(statuses) do
                exports['sandbox-status']:Remove(status, tonumber(value or 0))
            end
        end
    end
end

local Weapon = require 'modules.weapon.client'

AddStateBagChangeHandler('isCuffed', ('player:%s'):format(cache.serverId), function(_, _, value)
    PlayerData.cuffed = value
    LocalPlayer.state:set('invBusy', value, false)
    if not PlayerData.cuffed then return end
    Weapon.Disarm()
end)

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_, _, value)
    PlayerData.dead = value
    LocalPlayer.state:set('invBusy', value, false)
    if not PlayerData.dead then return end
    Weapon.Disarm()
end)

exports('IsEnabled', function()
    return _startup and not _openCd and not _timedCd and not exports['sandbox-hud']:IsDisabled()
end)

exports('CloseAll', function()
    client.closeInventory()
end)

exports('ItemsHas', function(item, count, bundleWeapons)
    return exports.ox_inventory:Search('count', item) >= count
end)

exports('ItemsHasType', function(itemType, count)
    return (exports.ox_inventory:GetTypeCounts()[itemType] or 0) >= count
end)

exports('ItemsGetData', function(name)
    if name ~= nil then
        return Items(name)
    else
        return Items()
    end
end)

exports('ItemsGetWithStaticMetadata', function(masterKey, mainIdName, textureIdName, gender, data)
    for k, v in pairs(Items) do
        if
            v.staticMetadata ~= nil
            and v.staticMetadata[masterKey] ~= nil
            and v.staticMetadata[masterKey][gender][mainIdName] == data[mainIdName]
            and v.staticMetadata[masterKey][gender][textureIdName] == data[textureIdName]
        then
            return k
        end
    end

    return nil
end)

exports('CheckPlayerHasItem', function(item, count)
    return exports.ox_inventory:Search('count', item) >= count
end)

exports('CheckPlayerHasItems', function(items)
    for k, v in ipairs(items) do
        if not exports.ox_inventory:Search('count', v.item) >= v.count then
            return false
        end
    end
    return true
end)

exports('CheckPlayerHasAnyItems', function(items)
    for k, v in ipairs(items) do
        if exports.ox_inventory:Search('count', v.item) >= v.count then
            return true
        end
    end

    return false
end)

exports('Enable', function()
    LocalPlayer.state.invBusy = false
end)

exports('Disable', function()
    LocalPlayer.state.invBusy = true
end)

exports('Toggle', function()
    if not LocalPlayer.state.invBusy then
        LocalPlayer.state.invBusy = true
    else
        LocalPlayer.state.invBusy = false
    end
end)

exports('DumbfuckOpen', function(type, id)
    exports.ox_inventory:openInventory(type, id)
end)

exports('SearchCharacter', function(serverId)
    exports.ox_inventory:openInventory('player', serverId)
end)

exports('GetEquippedHash', function()
    return cache.weapon
end)

exports('UnequipIfEquipped', function()
    if cache.weapon then
        TriggerEvent('ox_inventory:disarm')
    end
end)

exports('UnequipIfEquippedNoAnim', function()
    if cache.weapon then
        TriggerEvent('ox_inventory:disarm', true)
    end
end)

exports('AmmoAdd', function(item)
    if _equipped ~= nil then
        local ped = PlayerPedId()
        local hash = GetHashKey(Items[_equipped.Name].weapon or _equipped.Name)
        AddAmmoToPed(ped, hash, item.bulletCount or 10)
    end
end)

local _energyCd = false

function RegisterRandomItems() end

local _runSpeed = false
function RunSpeed(modifier, duration, cd, ss)
    if _runSpeed then
        return
    end
    _runSpeed = true
    CreateThread(function()
        local c = 0
        if not ss then
            AnimpostfxPlay("DrugsTrevorClownsFight", 0, true)
        end
        exports['sandbox-hud']:ApplyUniqueBuff("speed", duration / 1000, false)
        SetTimeout(duration, function()
            _runSpeed = false
        end)

        while LocalPlayer.state.loggedIn and _runSpeed and not LocalPlayer.state.drugsRunSpeed do
            SetPedMoveRateOverride(PlayerPedId(), modifier)
            Wait(1)
        end
        exports['sandbox-hud']:RemoveBuffType("speed")
        SetPedMoveRateOverride(PlayerPedId(), 0.0)
        AnimpostfxStop("DrugsTrevorClownsFight")
        Wait(cd)
        _energyCd = false
    end)
end

RegisterNetEvent("Inventory:Client:UseVanityItem", function(sender, action, itemData)
    if not LocalPlayer.state.loggedIn then
        return
    end
    local senderClient = GetPlayerFromServerId(sender)

    local isMe = false
    if sender == LocalPlayer.state.ID then
        isMe = true
    end

    if action == "overlay" then
        exports['sandbox-hud']:OverlayShow(itemData)
    elseif action == "overlayall" then
        if senderClient < 0 and not isMe then
            return
        end

        if not senderClient then
            return
        end
        local myPed = LocalPlayer.state.ped
        local senderPed = GetPlayerPed(senderClient)
        if DoesEntityExist(senderPed) then
            local dist = #(GetEntityCoords(senderPed) - GetEntityCoords(myPed))

            if dist <= 4.0 and HasEntityClearLosToEntity(myPed, senderPed, 17) then
                exports['sandbox-hud']:OverlayShow(itemData)
            end
        end
    end
    SetTimeout(10000, function()
        exports['sandbox-hud']:OverlayHide()
    end)
end)

RegisterNetEvent("Inventory:Client:SpeedyBoi", function(modifier, duration, cd, skipScreenEffects)
    if not _energyCd then
        _energyCd = true
        RunSpeed(modifier, duration, cd, skipScreenEffects)
    end
end)

RegisterNetEvent("Inventory:Client:ProgressModifier", function(modifier, duration)
    exports['sandbox-hud']:ProgressModifier(modifier, duration)
end)

RegisterNetEvent("Inventory:Client:HealthModifier", function(healthMod)
    local currentHealth = GetEntityHealth(LocalPlayer.state.ped)
    local maxHp = GetEntityMaxHealth(LocalPlayer.state.ped) - 100
    local newHealth = math.min((100 + (maxHp * 0.8)), currentHealth + healthMod)
    if newHealth > currentHealth then
        SetEntityHealth(LocalPlayer.state.ped, math.floor(newHealth))
    end
end)

RegisterNetEvent("Inventory:Client:ArmourModifier", function(mod)
    if not LocalPlayer.state.armourModCooldown or LocalPlayer.state.armourModCooldown <= GetGameTimer() then
        local currentArmour = GetPedArmour(LocalPlayer.state.ped)
        local newArmour = math.min(60, currentArmour + mod)

        if newArmour > currentArmour then
            SetPedArmour(LocalPlayer.state.ped, math.floor(newArmour))
        end

        LocalPlayer.state.armourModCooldown = GetGameTimer() + ((60 * 1000) * 5)
    end
end)

RegisterNetEvent("Inventory:Client:RandomItems:BirthdayCake", function()
    exports['sandbox-sounds']:PlayDistance(20.0, "birthday.ogg", 0.2)
    exports['sandbox-animations']:EmotesPlay("cake", false, false, false)
end)

RegisterNetEvent("Inventory:Client:RandomItems:BriefcaseCash", function()
    exports['sandbox-animations']:EmotesPlay("suitcase2", false, false, false)
end)

RegisterNetEvent("Inventory:Client:ERP:ButtPlug", function(color)
    exports['sandbox-animations']:EmotesPlay(string.format("erp_buttplug_%s", color), false, false, false)
end)

RegisterNetEvent("Inventory:Client:ERP:Vibrator", function(color)
    exports['sandbox-sounds']:PlayDistance(20.0, "vibrator.ogg", 0.2)
    exports['sandbox-animations']:EmotesPlay(string.format("erp_vibrator_%s", color), false, false, false)
end)

RegisterNetEvent("Inventory:Client:RandomItems:Redlight", function()
    exports['sandbox-animations']:EmotesPlay("redlight", false, false, false)
end)

RegisterNetEvent("Inventory:Client:Halloween:Pumpkin", function(emote)
    exports['sandbox-sounds']:PlayDistance(20.0, "evillaugh.ogg", 0.2)
    exports['sandbox-animations']:EmotesPlay(emote, false, false, false)
end)

RegisterNetEvent("Inventory:Client:Signs:UseSign", function(item)
    if item.Name then
        exports['sandbox-animations']:EmotesPlay(item.Name, false, false, false)
    end
end)






local EARLY_STOP_MULTIPLIER = 0.5
local DEFAULT_GTA_FALL_DISTANCE = 8.3
local DEFAULT_OPTIONS = { waitTime = 0.5, grappleSpeed = 20.0 }

local GRAPPLEHASH = `WEAPON_BULLPUPSHOTGUN`

CAN_GRAPPLE_HERE = true

Grapple = {}

-- CreateThread(function()
-- 	RopeLoadTextures()
-- end)

local function DirectionToRotation(dir, roll)
    local x, y, z
    z = -(math.deg(math.atan(dir.x, dir.y)))
    local rotpos = vector3(dir.z, #vector2(dir.x, dir.y), 0.0)
    x = math.deg(math.atan(rotpos.x, rotpos.y))
    y = roll
    return vector3(x, y, z)
end

local function RotationToDirection(rot)
    local rotZ = math.rad(rot.z)
    local rotX = math.rad(rot.x)
    local cosOfRotX = math.abs(math.cos(rotX))
    return vector3(-(math.sin(rotZ)) * cosOfRotX, math.cos(rotZ) * cosOfRotX, math.sin(rotX))
end

local function RayCastGamePlayCamera(dist)
    local camRot = GetGameplayCamRot()
    local camPos = GetGameplayCamCoord()
    local dir = RotationToDirection(camRot)

    local dest = camPos + (dir * dist)
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, 17, -1, 0)
    local _, hit, endPos, surfaceNormal, entityHit = GetShapeTestResult(ray)
    if hit == 0 then
        endPos = dest
    end
    return hit, endPos, entityHit, surfaceNormal
end

function GrappleCurrentAimPoint(dist)
    return RayCastGamePlayCamera(dist or 40)
end

local function _ensureOptions(options)
    for k, v in pairs(DEFAULT_OPTIONS) do
        if options[k] == nil then
            options[k] = v
        end
    end
end

local function _waitForFall(pid, ped, stopDistance)
    SetPlayerFallDistance(pid, 10.0)
    while GetEntityHeightAboveGround(ped) > stopDistance do
        SetPedCanRagdoll(ped, false)
        Wait(0)
    end
    SetPlayerFallDistance(pid, DEFAULT_GTA_FALL_DISTANCE)
end

local function PinRope(rope, ped, boneId, dest)
    PinRopeVertex(rope, 0, dest.x, dest.y, dest.z)
    local boneCoords = GetPedBoneCoords(ped, boneId, 0.0, 0.0, 0.0)
    PinRopeVertex(rope, GetRopeVertexCount(rope) - 1, boneCoords.x, boneCoords.y, boneCoords.z)
end

function Grapple.new(dest, options)
    local self = {}
    options = options or {}
    _ensureOptions(options)
    local grappleId = math.random((-2 ^ 32) + 1, 2 ^ 32 - 1)
    if options.grappleId then
        grappleId = options.grappleId
    end
    local pid = PlayerId()
    if options.plyServerId then
        pid = GetPlayerFromServerId(options.plyServerId)
    end

    local ped = GetPlayerPed(pid)
    local oldPedRef = ped
    local heading = GetEntityHeading(ped)
    local start = GetEntityCoords(ped)
    local notMyPed = options.plyServerId and options.plyServerId ~= GetPlayerServerId(PlayerId())
    local fromStartToDest = dest - start
    local dir = fromStartToDest / #fromStartToDest
    local length = #fromStartToDest
    local finished = false
    local rope
    if pid ~= -1 then
        rope = AddRope(dest.x, dest.y, dest.z, 0.0, 0.0, 0.0, 0.0, 4, 0.0, 0.0, 1.0, false, false, false, 5.0, false)
        LoadRopeData(rope, 'ropeFamily3')
        RopeLoadTextures()
        local headingToSet = GetEntityHeading(ped)
        ped = ClonePed(ped, 0, 0, 0)
        SetEntityHeading(ped, headingToSet)
        SetEntityAlpha(oldPedRef, 0, 0)
        local objs = GetGamePool("CObject")
        for k, v in ipairs(objs) do
            if Entity(v).state.backWeapon and IsEntityAttachedToEntity(v, oldPedRef) then
                SetEntityAlpha(v, 0, 0)
            end
        end
    end

    local function _setupDestroyEventHandler()
        local event = nil
        local eventName = string.format("Inventory:Client:Grapple:DestroyRope:%s", grappleId or -1)
        RegisterNetEvent(eventName)
        event = AddEventHandler(eventName, function()
            self.destroy(false)
            RemoveEventHandler(event)
        end)
    end

    function self._handleRope(rope, ped, boneIndex, dest)
        CreateThread(function()
            while not finished do
                PinRope(rope, ped, boneIndex, dest)
                Wait(0)
            end
            DeleteChildRope(rope)
            DeleteRope(rope)
        end)
    end

    function self.activateSync()
        if pid == -1 then
            return
        end
        local distTraveled = 0.0
        local currentPos = start
        local lastPos = currentPos
        local rotationMultiplier = -1
        local rot = DirectionToRotation(-dir * rotationMultiplier, 0.0)
        local lastRot = rot

        rot = rot + vector3(90.0 * rotationMultiplier, 0.0, 0.0)
        Wait(options.waitTime * 1000)
        while not finished and distTraveled < length do
            local fwdPerFrame = dir * options.grappleSpeed * GetFrameTime()
            distTraveled = distTraveled + #fwdPerFrame
            if distTraveled > length then
                distTraveled = length
                currentPos = dest
            else
                currentPos = currentPos + fwdPerFrame
            end
            SetEntityCoords(ped, currentPos.x, currentPos.y, currentPos.z)
            SetEntityRotation(ped, rot.x, rot.y, rot.z)
            if distTraveled > 3 and HasEntityCollidedWithAnything(ped) == 1 then
                local _cords = lastPos - (dir * EARLY_STOP_MULTIPLIER)
                SetEntityCoords(ped, _cords.x, _cords.y, _cords.z)
                SetEntityRotation(ped, lastRot.x, lastRot.y, lastRot.z)
                break
            end
            lastPos = currentPos
            lastRot = rot
            if not notMyPed then
                SetGameplayCamFollowPedThisUpdate(ped)
            end
            Wait(0)
        end
        if not notMyPed then
            local coords = GetEntityCoords(ped)
            local pedrot = GetEntityRotation(ped)
            SetEntityCoords(oldPedRef, coords.x, coords.y, coords.z)
            SetEntityRotation(oldPedRef, pedrot.x, pedrot.y, pedrot.z)
        else
            FreezeEntityPosition(ped, true, true)
        end

        self.destroy()
        _waitForFall(pid, ped, 3.0)

        CreateThread(function()
            Wait(200)
            local objs = GetGamePool("CObject")
            for k, v in ipairs(objs) do
                if Entity(v).state.backWeapon and IsEntityAttachedToEntity(v, oldPedRef) then
                    SetEntityAlpha(v, 255, 0)
                end
            end
        end)
    end

    function self.activate()
        CreateThread(self.activateSync)
    end

    function self.destroy(shouldTriggerDestroyEvent)
        finished = true
        if shouldTriggerDestroyEvent or shouldTriggerDestroyEvent == nil then
            if pid ~= -1 then
                CreateThread(function()
                    if notMyPed then
                        loopCount = 0
                        while #(GetEntityCoords(ped) - GetEntityCoords(oldPedRef)) > 2 and (loopCount < 20) do
                            loopCount = loopCount + 1
                            Wait(32)
                        end
                    end

                    DeleteEntity(ped)
                    SetEntityAlpha(oldPedRef, 255, 0)
                end)
            end
            TriggerServerEvent("Inventory:Server:Grapple:DestroyRope", grappleId)
        end
    end

    if pid ~= -1 then
        self._handleRope(rope, ped, 0x49D9, dest)
        if notMyPed then
            self.activate()
        end
    end
    if options.plyServerId == nil then
        TriggerServerEvent("Inventory:Server:Grapple:CreateRope", grappleId, dest)
    else
        _setupDestroyEventHandler()
    end
    return self
end

local _grappleEquipped = false
local shownGrappleButton = false
local function GrappleThreads()
    local ply = PlayerId()

    CreateThread(function()
        while _grappleEquipped and cache.weapon == GRAPPLEHASH do
            local freeAiming = IsPlayerFreeAiming(ply)
            local hit, pos, _, _ = GrappleCurrentAimPoint(40)
            print(shownGrappleButton, freeAiming, hit, CAN_GRAPPLE_HERE)
            if not shownGrappleButton and freeAiming and hit and CAN_GRAPPLE_HERE then
                shownGrappleButton = true
                exports['sandbox-hud']:ActionShow("grapple", "{key}Shoot{/key} To Grapple")
                print('show?')
            elseif shownGrappleButton and ((not freeAiming) or not hit or not CAN_GRAPPLE_HERE) then
                shownGrappleButton = false
                exports['sandbox-hud']:ActionHide("grapple")
            end
            Wait(250)
        end
    end)

    CreateThread(function()
        while _grappleEquipped and cache.weapon == GRAPPLEHASH do
            local freeAiming = IsPlayerFreeAiming(ply)
            if IsControlJustReleased(0, 257) and freeAiming and _grappleEquipped and CAN_GRAPPLE_HERE then
                local hit, pos, _, _ = GrappleCurrentAimPoint(40)
                if hit then
                    _grappleEquipped = false
                    exports['sandbox-hud']:ActionHide("grapple")
                    shownGrappleButton = false
                    local grapple = Grapple.new(pos)
                    grapple.activate()
                    TriggerServerEvent("Inventory:Server:DegradeLastUsed", 25)
                    Wait(1000)
                    Weapon.Disarm()
                end
            end
            Wait(0)
        end
    end)
end

lib.onCache('weapon', function(weapon)
    if weapon == GRAPPLEHASH then
        _grappleEquipped = true
        SetTimeout(100, GrappleThreads)
    else
        _grappleEquipped = false
    end
end)

-- RegisterNetEvent("Weapons:Client:Changed", function(item)
-- 	if not item then
-- 		_grappleEquipped = false
-- 	else
-- 		if GetHashKey(Items[item.Name].weapon or item.Name) == GRAPPLEHASH then
-- 			_grappleEquipped = true
-- 			GrappleThreads()
-- 		end
-- 	end
-- end)

RegisterNetEvent("Inventory:Client:Grapple:CreateRope", function(plyServerId, grappleId, dest)
    if plyServerId == GetPlayerServerId(PlayerId()) then
        return
    end
    Grapple.new(dest, { plyServerId = plyServerId, grappleId = grappleId })
end)
