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
-- Framework bootstrap
-- ---------------------------------------------------------------------------

local function InitFramework()
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

---@param entity number
---@return boolean
local function IsVehicleClassBlacklisted(entity)
    local class = GetVehicleClass(entity)
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
-- Inventory helpers (ox_inventory)
-- ---------------------------------------------------------------------------

---@param src number
---@param item string
---@param amount number
---@return boolean
local function HasItem(src, item, amount)
    amount = amount or 1
    local count = exports.ox_inventory:Search(src, 'count', item)
    return count and count >= amount
end

---@param src number
---@param item string
---@param amount number
---@return boolean
local function RemoveItem(src, item, amount)
    return exports.ox_inventory:RemoveItem(src, item, amount or 1)
end

-- ---------------------------------------------------------------------------
-- Evidence & police alert
-- ---------------------------------------------------------------------------

---@param src number
---@param entity number
local function TryLeaveEvidence(src, entity)
    if math.random() > Config.EvidenceChance then return end

    TriggerClientEvent('bd-fakeplate:client:notify', src, Config.Locale.evidence_left, 'info')

    local mode = Config.Evidence.Mode
    if mode == 'export' and Config.Evidence.ExportResource ~= '' and Config.Evidence.ExportFunction ~= '' then
        if GetResourceState(Config.Evidence.ExportResource) == 'started' then
            exports[Config.Evidence.ExportResource][Config.Evidence.ExportFunction](src, entity)
        end
    elseif mode == 'event' and Config.Evidence.Event ~= '' then
        TriggerEvent(Config.Evidence.Event, src, NetworkGetNetworkIdFromEntity(entity))
    end
end

---@param src number
---@param entity number
local function TryPoliceAlert(src, entity)
    if math.random() > Config.PoliceAlertChance then return end
    local coords = GetEntityCoords(entity)
    TriggerClientEvent('bd-fakeplate:client:policeAlert', src, coords)
    -- Broadcast to police jobs could be added here per framework
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

    if IsVehicleClassBlacklisted(entity) then
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

    TryPoliceAlert(src, entity)
    TryLeaveEvidence(src, entity)

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
        TriggerClientEvent('bd-fakeplate:client:notify', src, Config.Locale.checkplate_denied, 'error') -- client handler
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
