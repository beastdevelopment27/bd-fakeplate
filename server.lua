--[[
    bd-fakeplate | Server
    Authoritative validation, state bags, inventory, SQL, and Discord logging.
]]

local Framework = nil
local ESX, QBCore = nil, nil

-- Active fake plates cache: netId -> state table (mirrors state bags for quick lookup)
local ActivePlates = {}
local CrashDetachCooldown = {}
local ActionCooldown = {}
local ACTION_COOLDOWN_SEC = 2

-- ---------------------------------------------------------------------------
-- Framework bootstrap (fallback when community_bridge is unavailable)
-- ---------------------------------------------------------------------------

local function InitFramework()
    if BdBridge.IsEnabled() then return end

    if Config.Framework == 'qb' or (Config.Framework == 'auto' and GetResourceState('qb-core') == 'started') then
        Framework = 'qb'
        QBCore = exports['qb-core']:GetCoreObject()
        return
    end

    if Config.Framework == 'esx' or (Config.Framework == 'auto' and GetResourceState('es_extended') == 'started') then
        Framework = 'esx'
        ESX = exports['es_extended']:getSharedObject()
    end
end

---@param src number
---@param message string
---@param notifyType string
local function NotifyPlayer(src, message, notifyType)
    local style = Config.Notifications[notifyType] or Config.Notifications.info
    local NotifyMod = BdBridge.Notify()
    if NotifyMod and NotifyMod.SendNotification then
        NotifyMod.SendNotification(src, Config.Notifications.Title, message, style.type, style.duration)
        return
    end
    TriggerClientEvent('bd-fakeplate:client:notify', src, message, notifyType)
end

CreateThread(function()
    InitFramework()
    if Config.SQL.Enabled and Config.SQL.AutoCreateTable then
        CreateSQLTable()
    end
end)

-- ---------------------------------------------------------------------------
-- Utility helpers
-- ---------------------------------------------------------------------------

---@param src number
---@return table|nil player
local function GetPlayer(src)
    if Framework == 'qb' then
        return QBCore.Functions.GetPlayer(src)
    end
    if Framework == 'esx' then
        return ESX.GetPlayerFromId(src)
    end
    return nil
end

---@param src number
---@return string|nil
local function GetPlayerJobName(src)
    local BridgeFramework = BdBridge.Framework()
    if BridgeFramework and BridgeFramework.GetPlayerJobData then
        local job = BridgeFramework.GetPlayerJobData(src)
        return job and job.jobName or nil
    end

    local player = GetPlayer(src)
    if not player then return nil end

    if Framework == 'qb' then
        return player.PlayerData.job and player.PlayerData.job.name or nil
    end

    if Framework == 'esx' then
        return player.job and player.job.name or nil
    end

    return nil
end

---@param src number
---@return string|nil
local function GetInstallerId(src)
    local BridgeFramework = BdBridge.Framework()
    if BridgeFramework and BridgeFramework.GetPlayerIdentifier then
        return BridgeFramework.GetPlayerIdentifier(src)
    end

    local player = GetPlayer(src)
    if not player then return nil end

    if Framework == 'qb' then
        return player.PlayerData.citizenid or player.PlayerData.license
    end

    if Framework == 'esx' then
        return player.identifier
    end

    return ('license:%s'):format(GetPlayerIdentifierByType(src, 'license') or 'unknown')
end

---@param allowedJobs table
---@param job string|nil
---@return boolean
local function HasAllowedJob(allowedJobs, job)
    if not allowedJobs or #allowedJobs == 0 then return true end
    if not job then return false end
    for i = 1, #allowedJobs do
        if allowedJobs[i] == job then return true end
    end
    return false
end

---@param plate string
---@return string
local function TrimPlate(plate)
    if not plate then return '' end
    return (plate:gsub('^%s+', ''):gsub('%s+$', '')):upper()
end

--- Strip invalid characters from plate input (anti-exploit).
---@param plate string
---@return string
local function SanitizePlate(plate)
    plate = TrimPlate(plate)
    plate = plate:gsub('[^%w]', '')
    return plate:sub(1, Config.PlateMaxLength)
end

---@param src number
---@return boolean
local function IsOnCooldown(src)
    if ActionCooldown[src] and ActionCooldown[src] > os.time() then
        return true
    end
    ActionCooldown[src] = os.time() + ACTION_COOLDOWN_SEC
    return false
end

---@return string
local function GenerateRandomPlate()
    if not Config.RandomPlate.Enabled then
        return 'FAKE0001'
    end

    local charset = Config.RandomPlate.Charset
    local length = Config.RandomPlate.Length
    local chars = {}
    for i = 1, #charset do
        chars[i] = charset:sub(i, i)
    end

    local plate = {}
    for i = 1, length do
        plate[i] = chars[math.random(1, #chars)]
    end
    return table.concat(plate)
end

---@param entity number
---@return string
local function GetVehiclePlate(entity)
    return TrimPlate(GetVehicleNumberPlateText(entity))
end

---@param netId number
---@return number|nil entity
local function GetVehicleFromNetId(netId)
    if not netId or netId == 0 then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    if GetEntityType(entity) ~= 2 then return nil end -- vehicle
    return entity
end

---@param src number
---@param entity number
---@return boolean
local function IsPlayerNearEntity(src, entity)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pCoords = GetEntityCoords(ped)
    local eCoords = GetEntityCoords(entity)
    return #(pCoords - eCoords) <= (Config.InteractDistance + 1.5)
end

---@param src number
---@param netId number
---@return boolean
local function IsVehicleClassBlacklisted(src, netId)
    local class = lib.callback.await('bd-fakeplate:client:getVehicleClass', src, netId)
    if class == nil then return true end
    for i = 1, #Config.BlacklistedVehicleClasses do
        if Config.BlacklistedVehicleClasses[i] == class then
            return true
        end
    end
    return false
end

---@param entity number
---@param state table|nil
local function SetVehicleFakePlateState(entity, state)
    local ent = Entity(entity)
    ent.state:set(Config.StateBagKey, state, true)

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if state and state.active then
        ActivePlates[netId] = state
    else
        ActivePlates[netId] = nil
    end
end

---@param entity number
---@return table|nil
local function GetVehicleFakePlateState(entity)
    return Entity(entity).state[Config.StateBagKey]
end

-- ---------------------------------------------------------------------------
-- SQL persistence (optional, requires oxmysql)
-- ---------------------------------------------------------------------------

function CreateSQLTable()
    if GetResourceState('oxmysql') ~= 'started' then
        print('^1[bd-fakeplate]^7 SQL enabled but oxmysql is not started.')
        return
    end

    local tableName = Config.SQL.TableName
    exports.oxmysql:execute(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `original_plate` VARCHAR(12) NOT NULL,
            `fake_plate` VARCHAR(12) NOT NULL,
            `installed_by` VARCHAR(64) DEFAULT NULL,
            `metadata` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `original_plate` (`original_plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(tableName))
end

---@param originalPlate string
---@param fakePlate string
---@param installedBy string|nil
---@param metadata table|nil
local function SavePlateToSQL(originalPlate, fakePlate, installedBy, metadata)
    if not Config.SQL.Enabled or GetResourceState('oxmysql') ~= 'started' then return end

    exports.oxmysql:insert(
        ('INSERT INTO `%s` (original_plate, fake_plate, installed_by, metadata) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE fake_plate = VALUES(fake_plate), installed_by = VALUES(installed_by), metadata = VALUES(metadata)'):format(Config.SQL.TableName),
        { originalPlate, fakePlate, installedBy, metadata and json.encode(metadata) or nil }
    )
end

---@param originalPlate string
local function DeletePlateFromSQL(originalPlate)
    if not Config.SQL.Enabled or GetResourceState('oxmysql') ~= 'started' then return end
    exports.oxmysql:execute(('DELETE FROM `%s` WHERE original_plate = ?'):format(Config.SQL.TableName), { originalPlate })
end

---@param originalPlate string
---@return table|nil row
local function LoadPlateFromSQL(originalPlate)
    if not Config.SQL.Enabled or GetResourceState('oxmysql') ~= 'started' then return nil end
    local result = exports.oxmysql:executeSync(
        ('SELECT * FROM `%s` WHERE original_plate = ? LIMIT 1'):format(Config.SQL.TableName),
        { originalPlate }
    )
    return result and result[1] or nil
end

---@param fakePlate string
---@return table|nil row
local function LoadPlateFromSQLByFake(fakePlate)
    if not Config.SQL.Enabled or GetResourceState('oxmysql') ~= 'started' then return nil end
    local result = exports.oxmysql:executeSync(
        ('SELECT * FROM `%s` WHERE fake_plate = ? LIMIT 1'):format(Config.SQL.TableName),
        { TrimPlate(fakePlate) }
    )
    return result and result[1] or nil
end

---@param entity number
---@return boolean
local function VehicleHasActiveFakePlate(entity)
    local state = GetVehicleFakePlateState(entity)
    return state ~= nil and state.active == true
end

---@param plate string
---@return boolean
local function PlateIsActiveFake(plate)
    plate = TrimPlate(plate)
    if plate == '' then return false end

    for _, state in pairs(ActivePlates) do
        if state.active and TrimPlate(state.fakePlate) == plate then
            return true
        end
    end

    return LoadPlateFromSQLByFake(plate) ~= nil
end

---@param identifier number|string netId or plate text
---@param src number|nil player to notify
---@return boolean canStore
local function CanStoreInGarage(identifier, src)
    if not Config.GarageIntegration.Enabled then return true end

    local blocked = false
    if type(identifier) == 'number' then
        local entity = GetVehicleFromNetId(identifier)
        blocked = entity ~= nil and VehicleHasActiveFakePlate(entity)
    elseif type(identifier) == 'string' then
        blocked = PlateIsActiveFake(identifier)
    end

    if blocked and src then
        NotifyPlayer(src, Config.Locale.remove_before_garage, 'error')
    end

    return not blocked
end

lib.callback.register('bd-fakeplate:canStoreVehicle', function(source, netId)
    if type(netId) ~= 'number' then return true end
    return CanStoreInGarage(netId, source)
end)

-- ---------------------------------------------------------------------------
-- Discord webhook
-- ---------------------------------------------------------------------------

---@param title string
---@param description string
local function SendDiscordLog(title, description)
    if not Config.Discord.Enabled or Config.Discord.Webhook == '' then return end

    local payload = json.encode({
        username = Config.Discord.BotName,
        embeds = {
            {
                title = title,
                description = description,
                color = Config.Discord.Color,
                footer = { text = Config.Discord.Footer },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            },
        },
    })

    PerformHttpRequest(Config.Discord.Webhook, function() end, 'POST', payload, {
        ['Content-Type'] = 'application/json',
    })
end

-- ---------------------------------------------------------------------------
-- Inventory helpers (community_bridge or ox_inventory fallback)
-- ---------------------------------------------------------------------------

---@param src number
---@param item string
---@param amount number
---@return boolean
local function HasItem(src, item, amount)
    amount = amount or 1
    local Inventory = BdBridge.Inventory()
    if Inventory and Inventory.HasItem then
        return Inventory.HasItem(src, item, amount)
    end
    if GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:Search(src, 'count', item)
        return count and count >= amount
    end
    return false
end

---@param src number
---@param item string
---@param amount number
---@return boolean
local function RemoveItem(src, item, amount)
    amount = amount or 1
    local Inventory = BdBridge.Inventory()
    if Inventory and Inventory.RemoveItem then
        return Inventory.RemoveItem(src, item, amount)
    end
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:RemoveItem(src, item, amount)
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Core install / remove
-- ---------------------------------------------------------------------------

---@param src number
---@param netId number
---@param customPlate string|nil
local function InstallFakePlate(src, netId, customPlate)
    if IsOnCooldown(src) then
        TriggerClientEvent('bd-fakeplate:client:installResult', src, false, Config.Locale.exploit, nil)
        return
    end

    local entity = GetVehicleFromNetId(netId)
    if not entity then
        TriggerClientEvent('bd-fakeplate:client:installResult', src, false, Config.Locale.exploit)
        return
    end

    if not IsPlayerNearEntity(src, entity) then
        TriggerClientEvent('bd-fakeplate:client:installResult', src, false, Config.Locale.not_in_vehicle_zone)
        return
    end

    if IsVehicleClassBlacklisted(src, netId) then
        TriggerClientEvent('bd-fakeplate:client:installResult', src, false, Config.Locale.blacklisted_class)
        return
    end

    local job = GetPlayerJobName(src)
    if not HasAllowedJob(Config.WhitelistJobsInstall, job) then
        TriggerClientEvent('bd-fakeplate:client:installResult', src, false, Config.Locale.job_denied)
        return
    end

    if not HasItem(src, Config.Items.FakePlate, 1) then
        TriggerClientEvent('bd-fakeplate:client:installResult', src, false, Config.Locale.exploit, nil)
        return
    end

    local currentState = GetVehicleFakePlateState(entity)
    if currentState and currentState.active then
        TriggerClientEvent('bd-fakeplate:client:installResult', src, false, Config.Locale.already_fake)
        return
    end

    local originalPlate = GetVehiclePlate(entity)
    if originalPlate == '' then
        TriggerClientEvent('bd-fakeplate:client:installResult', src, false, Config.Locale.exploit)
        return
    end

    local fakePlate
    if customPlate and customPlate ~= '' then
        fakePlate = SanitizePlate(customPlate)
        if #fakePlate < Config.PlateMinLength or #fakePlate > Config.PlateMaxLength then
            TriggerClientEvent('bd-fakeplate:client:installResult', src, false, Config.Locale.invalid_plate)
            return
        end
    else
        fakePlate = GenerateRandomPlate()
    end

    if fakePlate == originalPlate then
        fakePlate = GenerateRandomPlate()
    end

    local metadata = nil
    if Config.SaveMetadata then
        metadata = {
            installedBy = GetInstallerId(src),
            installedAt = os.time(),
            source = src,
        }
    end

    local state = {
        active = true,
        originalPlate = originalPlate,
        fakePlate = fakePlate,
        metadata = metadata,
    }

    SetVehicleFakePlateState(entity, state)
    SetVehicleNumberPlateText(entity, fakePlate)

    if Config.ConsumeFakePlate then
        RemoveItem(src, Config.Items.FakePlate, 1)
    end

    SavePlateToSQL(originalPlate, fakePlate, metadata and metadata.installedBy or nil, metadata)

    SendDiscordLog('Fake Plate Installed', ('**Player:** %s\n**Original:** %s\n**Fake:** %s'):format(src, originalPlate, fakePlate))

    TriggerClientEvent('bd-fakeplate:client:installResult', src, true, string.format(Config.Locale.install_success, fakePlate), fakePlate)
end

---@param src number
---@param netId number
local function RemoveFakePlate(src, netId)
    if IsOnCooldown(src) then
        TriggerClientEvent('bd-fakeplate:client:removeResult', src, false, Config.Locale.exploit, nil)
        return
    end

    local entity = GetVehicleFromNetId(netId)
    if not entity then
        TriggerClientEvent('bd-fakeplate:client:removeResult', src, false, Config.Locale.exploit)
        return
    end

    if not IsPlayerNearEntity(src, entity) then
        TriggerClientEvent('bd-fakeplate:client:removeResult', src, false, Config.Locale.not_in_vehicle_zone)
        return
    end

    if not HasItem(src, Config.Items.Screwdriver, 1) then
        TriggerClientEvent('bd-fakeplate:client:removeResult', src, false, Config.Locale.exploit)
        return
    end

    local currentState = GetVehicleFakePlateState(entity)
    if not currentState or not currentState.active then
        TriggerClientEvent('bd-fakeplate:client:removeResult', src, false, Config.Locale.no_fake_plate)
        return
    end

    local originalPlate = currentState.originalPlate
    SetVehicleFakePlateState(entity, nil)
    SetVehicleNumberPlateText(entity, originalPlate)

    if Config.ConsumeScrewdriver then
        RemoveItem(src, Config.Items.Screwdriver, 1)
    end

    DeletePlateFromSQL(originalPlate)

    SendDiscordLog('Fake Plate Removed', ('**Player:** %s\n**Restored:** %s'):format(src, originalPlate))

    TriggerClientEvent('bd-fakeplate:client:removeResult', src, true, string.format(Config.Locale.remove_success, originalPlate), originalPlate)
end

-- ---------------------------------------------------------------------------
-- Net events (validated server-side)
-- ---------------------------------------------------------------------------

RegisterNetEvent('bd-fakeplate:server:installFakePlate', function(netId, customPlate)
    local src = source
    if type(netId) ~= 'number' then return end
    if customPlate ~= nil and type(customPlate) ~= 'string' then return end
    InstallFakePlate(src, netId, customPlate)
end)

RegisterNetEvent('bd-fakeplate:server:removeFakePlate', function(netId)
    local src = source
    if type(netId) ~= 'number' then return end
    RemoveFakePlate(src, netId)
end)

RegisterNetEvent('bd-fakeplate:server:crashDetach', function(netId)
    local src = source
    if not Config.CrashDetach or type(netId) ~= 'number' then return end

    if CrashDetachCooldown[netId] and CrashDetachCooldown[netId] > os.time() then return end
    CrashDetachCooldown[netId] = os.time() + 10

    local entity = GetVehicleFromNetId(netId)
    if not entity then return end

    -- Player must be in or near the damaged vehicle
    local ped = GetPlayerPed(src)
    local inVehicle = GetVehiclePedIsIn(ped, false) == entity
    if not inVehicle and not IsPlayerNearEntity(src, entity) then return end

    local state = GetVehicleFakePlateState(entity)
    if not state or not state.active then return end

    local bodyHealth = GetVehicleBodyHealth(entity)
    if bodyHealth > Config.MinimumBodyHealth then return end

    local originalPlate = state.originalPlate
    SetVehicleFakePlateState(entity, nil)
    SetVehicleNumberPlateText(entity, originalPlate)
    DeletePlateFromSQL(originalPlate)

    TriggerClientEvent('bd-fakeplate:client:plateFellOff', -1, originalPlate)
end)

RegisterNetEvent('bd-fakeplate:server:checkPlate', function(netId)
    local src = source
    if type(netId) ~= 'number' then return end

    local job = GetPlayerJobName(src)
    if not HasAllowedJob(Config.AllowedJobsCheckPlate, job) then
        NotifyPlayer(src, Config.Locale.checkplate_denied, 'error')
        return
    end

    local entity = GetVehicleFromNetId(netId)
    if not entity or not IsPlayerNearEntity(src, entity) then return end

    local state = GetVehicleFakePlateState(entity)
    local originalPlate = state and state.originalPlate or GetVehiclePlate(entity)

    -- Fallback: SQL record if state bag empty
    if (not state or not state.active) and Config.SQL.Enabled then
        local row = LoadPlateFromSQL(originalPlate)
        if row then
            state = {
                active = true,
                originalPlate = row.original_plate,
                fakePlate = row.fake_plate,
            }
        end
    end

    TriggerClientEvent('bd-fakeplate:client:showPlateCheck', src, {
        active = state and state.active or false,
        originalPlate = state and state.originalPlate or originalPlate,
        fakePlate = state and state.fakePlate or 'N/A',
    })
end)

-- ---------------------------------------------------------------------------
-- ox_inventory item hooks (server exports)
-- Add to ox_inventory items.lua:
-- ['fakeplate'] = { ..., server = { export = 'bd-fakeplate.useFakePlate' } }
-- ['screwdriver'] = { ..., server = { export = 'bd-fakeplate.useScrewdriver' } }
-- ---------------------------------------------------------------------------

---@param event string
---@param item table
---@param inventory table
---@param slot number
exports('useFakePlate', function(event, item, inventory, slot)
    if event ~= 'usingItem' then return end
    TriggerClientEvent('bd-fakeplate:client:beginInstall', inventory.id)
end)

---@param event string
---@param item table
---@param inventory table
---@param slot number
exports('useScrewdriver', function(event, item, inventory, slot)
    if event ~= 'usingItem' then return end
    TriggerClientEvent('bd-fakeplate:client:beginRemove', inventory.id)
end)

exports('CanStoreInGarage', CanStoreInGarage)

-- ---------------------------------------------------------------------------
-- Restore SQL plates when vehicles spawn (optional persistence)
-- ---------------------------------------------------------------------------

if Config.SQL.Enabled then
    AddEventHandler('entityCreated', function(entity)
        if not entity or entity == 0 then return end
        if GetEntityType(entity) ~= 2 then return end

        SetTimeout(1500, function()
            if not DoesEntityExist(entity) then return end
            local plate = GetVehiclePlate(entity)
            if plate == '' then return end

            local existing = GetVehicleFakePlateState(entity)
            if existing and existing.active then return end

            local row = LoadPlateFromSQL(plate)
            if not row then return end

            local state = {
                active = true,
                originalPlate = row.original_plate,
                fakePlate = row.fake_plate,
                metadata = row.metadata and json.decode(row.metadata) or nil,
            }

            SetVehicleFakePlateState(entity, state)
            SetVehicleNumberPlateText(entity, row.fake_plate)
        end)
    end)
end

AddEventHandler('playerDropped', function()
    ActionCooldown[source] = nil
end)

-- Cleanup cache when entity is removed
AddEventHandler('entityRemoved', function(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and ActivePlates[netId] then
        ActivePlates[netId] = nil
    end
end)
