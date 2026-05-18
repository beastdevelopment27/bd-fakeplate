--[[
    bd-fakeplate | Client
    Handles animations, progress UI, plate visuals, crash detach, and commands.
]]

local isBusy = false
local Framework = nil
local PlayerData = {}

-- ---------------------------------------------------------------------------
-- Framework bootstrap
-- ---------------------------------------------------------------------------

local function InitFramework()
    if Config.Framework == 'qb' or (Config.Framework == 'auto' and GetResourceState('qb-core') == 'started') then
        Framework = 'qb'
        local QBCore = exports['qb-core']:GetCoreObject()
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = QBCore.Functions.GetPlayerData()
        end)
        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
            PlayerData.job = job
        end)
        RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
            PlayerData = {}
        end)
        CreateThread(function()
            if LocalPlayer.state.isLoggedIn then
                PlayerData = QBCore.Functions.GetPlayerData()
            end
        end)
        return
    end

    if Config.Framework == 'esx' or (Config.Framework == 'auto' and GetResourceState('es_extended') == 'started') then
        Framework = 'esx'
        local ESX = exports['es_extended']:getSharedObject()
        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
        end)
        RegisterNetEvent('esx:setJob', function(job)
            PlayerData.job = job
        end)
        CreateThread(function()
            while not ESX.IsPlayerLoaded() do Wait(200) end
            PlayerData = ESX.GetPlayerData()
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Utility helpers
-- ---------------------------------------------------------------------------

---@param data table
local function Notify(data)
    lib.notify({
        title = 'Fake Plate',
        description = data.description,
        type = data.type or 'inform',
        duration = data.duration or 5000,
    })
end

---@param message string
---@param notifyType string
local function NotifyLocale(message, notifyType)
    local style = Config.Notifications[notifyType] or Config.Notifications.info
    Notify({
        description = message,
        type = style.type,
        duration = style.duration,
    })
end

---@return string|nil
local function GetPlayerJobName()
    if Framework == 'qb' and PlayerData.job then
        return PlayerData.job.name
    end
    if Framework == 'esx' and PlayerData.job then
        return PlayerData.job.name
    end
    return nil
end

---@param allowedJobs table
---@return boolean
local function HasAllowedJob(allowedJobs)
    if not allowedJobs or #allowedJobs == 0 then return true end
    local job = GetPlayerJobName()
    if not job then return false end
    for i = 1, #allowedJobs do
        if allowedJobs[i] == job then return true end
    end
    return false
end

---@param dict string
local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return end
        Wait(10)
    end
end

---@param vehicle number
---@return boolean
local function IsVehicleClassBlacklisted(vehicle)
    if not vehicle or vehicle == 0 then return true end
    local class = GetVehicleClass(vehicle)
    for i = 1, #Config.BlacklistedVehicleClasses do
        if Config.BlacklistedVehicleClasses[i] == class then
            return true
        end
    end
    return false
end

--- Get closest vehicle within interaction distance.
---@param coords vector3|nil
---@return number|nil vehicle
---@return number|nil netId
local function GetNearestVehicle(coords)
    coords = coords or GetEntityCoords(cache.ped)
    local vehicle = lib.getClosestVehicle(coords, Config.InteractDistance, false)
    if not vehicle or vehicle == 0 then return nil, nil end
    if IsVehicleClassBlacklisted(vehicle) then return nil, nil end
    return vehicle, NetworkGetNetworkIdFromEntity(vehicle)
end

---@param plate string
---@return string
local function TrimPlate(plate)
    return (plate:gsub('^%s+', ''):gsub('%s+$', '')):upper()
end

--- Apply visible plate text on a vehicle entity.
---@param vehicle number
---@param plate string
local function ApplyPlateText(vehicle, plate)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    SetVehicleNumberPlateText(vehicle, plate)
end

--- Read fake plate state from entity state bag.
---@param vehicle number
---@return table|nil
local function GetFakePlateState(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    return Entity(vehicle).state[Config.StateBagKey]
end

--- Sync plate visuals from state bag data.
---@param vehicle number
---@param state table|nil
local function SyncVehiclePlateFromState(vehicle, state)
    if not vehicle or vehicle == 0 then return end
    if state and state.active and state.fakePlate then
        ApplyPlateText(vehicle, state.fakePlate)
    elseif state and state.originalPlate then
        ApplyPlateText(vehicle, state.originalPlate)
    end
end

-- ---------------------------------------------------------------------------
-- State bag listener (global sync for all players)
-- ---------------------------------------------------------------------------

AddStateBagChangeHandler(Config.StateBagKey, nil, function(bagName, _key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    if not IsEntityAVehicle(entity) then return end
    SyncVehiclePlateFromState(entity, value)
end)

-- Apply synced state when vehicles stream in (state bag may already be set)
AddEventHandler('entityStreamIn', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    local state = Entity(entity).state[Config.StateBagKey]
    if state then
        SyncVehiclePlateFromState(entity, state)
    end
end)

-- Re-sync when entering a vehicle
lib.onCache('vehicle', function(vehicle)
    if not vehicle then return end
    SyncVehiclePlateFromState(vehicle, GetFakePlateState(vehicle))
end)

-- ---------------------------------------------------------------------------
-- Progress + animation flow
-- ---------------------------------------------------------------------------

---@param label string
---@param duration number
---@param anim table
---@return boolean success
local function RunTimedAction(label, duration, anim)
    LoadAnimDict(anim.dict)

    local success = lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = anim.dict,
            clip = anim.clip,
            flag = anim.flag or 49,
        },
    })

    StopAnimTask(cache.ped, anim.dict, anim.clip, 1.0)
    RemoveAnimDict(anim.dict)
    return success
end

-- ---------------------------------------------------------------------------
-- Police alert (client hook for dispatch scripts)
-- ---------------------------------------------------------------------------

RegisterNetEvent('bd-fakeplate:client:policeAlert', function(coords)
    NotifyLocale(Config.Locale.police_alert, 'info')

    local mode = Config.PoliceAlert.Mode
    if mode == 'export' and Config.PoliceAlert.ExportResource ~= '' and Config.PoliceAlert.ExportFunction ~= '' then
        local res = Config.PoliceAlert.ExportResource
        local fn = Config.PoliceAlert.ExportFunction
        if GetResourceState(res) == 'started' then
            exports[res][fn](coords)
        end
    elseif mode == 'event' and Config.PoliceAlert.Event ~= '' then
        TriggerEvent(Config.PoliceAlert.Event, coords)
    end
end)

-- ---------------------------------------------------------------------------
-- Install flow
-- ---------------------------------------------------------------------------

local function RequestCustomPlate()
    if not Config.UseCustomPlate then return nil end

    local input = lib.inputDialog(Config.Locale.custom_plate_title, {
        {
            type = 'input',
            label = Config.Locale.custom_plate_label,
            required = true,
            min = Config.PlateMinLength,
            max = Config.PlateMaxLength,
        },
    })

    if not input or not input[1] then return false end -- cancelled
    local plate = TrimPlate(input[1])
    if #plate < Config.PlateMinLength or #plate > Config.PlateMaxLength then
        NotifyLocale(Config.Locale.invalid_plate, 'error')
        return false
    end
    return plate
end

RegisterNetEvent('bd-fakeplate:client:beginInstall', function()
    if isBusy then return end
    if not HasAllowedJob(Config.WhitelistJobsInstall) then
        NotifyLocale(Config.Locale.job_denied, 'error')
        return
    end

    local vehicle, netId = GetNearestVehicle()
    if not vehicle or not netId then
        NotifyLocale(Config.Locale.no_vehicle, 'error')
        return
    end

    local existing = GetFakePlateState(vehicle)
    if existing and existing.active then
        NotifyLocale(Config.Locale.already_fake, 'error')
        return
    end

    local customPlate = RequestCustomPlate()
    if customPlate == false then return end -- validation failed or cancelled dialog

    isBusy = true

    local completed = RunTimedAction(
        Config.Locale.install_label,
        Config.InstallDuration,
        Config.Animations.Install
    )

    if not completed then
        NotifyLocale(Config.Locale.install_cancelled, 'error')
        isBusy = false
        return
    end

    -- Re-validate vehicle after progress bar
    vehicle, netId = GetNearestVehicle()
    if not vehicle or not netId then
        NotifyLocale(Config.Locale.no_vehicle, 'error')
        isBusy = false
        return
    end

    TriggerServerEvent('bd-fakeplate:server:installFakePlate', netId, customPlate)
    isBusy = false
end)

RegisterNetEvent('bd-fakeplate:client:installResult', function(success, message, fakePlate)
    if success then
        NotifyLocale(message or string.format(Config.Locale.install_success, fakePlate or ''), 'success')
    else
        NotifyLocale(message or Config.Locale.exploit, 'error')
    end
end)

-- ---------------------------------------------------------------------------
-- Remove flow
-- ---------------------------------------------------------------------------

RegisterNetEvent('bd-fakeplate:client:beginRemove', function()
    if isBusy then return end

    local vehicle, netId = GetNearestVehicle()
    if not vehicle or not netId then
        NotifyLocale(Config.Locale.no_vehicle, 'error')
        return
    end

    local state = GetFakePlateState(vehicle)
    if not state or not state.active then
        NotifyLocale(Config.Locale.no_fake_plate, 'error')
        return
    end

    isBusy = true

    local completed = RunTimedAction(
        Config.Locale.remove_label,
        Config.RemoveDuration,
        Config.Animations.Remove
    )

    if not completed then
        NotifyLocale(Config.Locale.remove_cancelled, 'error')
        isBusy = false
        return
    end

    vehicle, netId = GetNearestVehicle()
    if not vehicle or not netId then
        NotifyLocale(Config.Locale.no_vehicle, 'error')
        isBusy = false
        return
    end

    TriggerServerEvent('bd-fakeplate:server:removeFakePlate', netId)
    isBusy = false
end)

RegisterNetEvent('bd-fakeplate:client:removeResult', function(success, message, originalPlate)
    if success then
        NotifyLocale(message or string.format(Config.Locale.remove_success, originalPlate or ''), 'success')
    else
        NotifyLocale(message or Config.Locale.exploit, 'error')
    end
end)

-- ---------------------------------------------------------------------------
-- Crash detach monitor
-- ---------------------------------------------------------------------------

if Config.CrashDetach then
    CreateThread(function()
        while true do
            Wait(Config.CrashCheckInterval)
            local ped = cache.ped
            if not IsPedInAnyVehicle(ped, false) then goto continue end

            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle == 0 then goto continue end

            local state = GetFakePlateState(vehicle)
            if not state or not state.active then goto continue end

            local bodyHealth = GetVehicleBodyHealth(vehicle)
            if bodyHealth > 0.0 and bodyHealth <= Config.MinimumBodyHealth then
                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                if netId and netId ~= 0 then
                    TriggerServerEvent('bd-fakeplate:server:crashDetach', netId)
                end
            end

            ::continue::
        end
    end)
end

RegisterNetEvent('bd-fakeplate:client:notify', function(message, notifyType)
    NotifyLocale(message, notifyType or 'info')
end)

RegisterNetEvent('bd-fakeplate:client:plateFellOff', function(originalPlate)
    NotifyLocale(Config.Locale.plate_fell_off, 'info')
    if originalPlate then
        local vehicle = cache.vehicle
        if vehicle and vehicle ~= 0 then
            ApplyPlateText(vehicle, originalPlate)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- /checkplate command
-- ---------------------------------------------------------------------------

if Config.EnableCommands then
    RegisterCommand(Config.CheckPlateCommand, function()
        if not HasAllowedJob(Config.AllowedJobsCheckPlate) then
            NotifyLocale(Config.Locale.checkplate_denied, 'error')
            return
        end

        local vehicle, netId = GetNearestVehicle()
        if not vehicle or not netId then
            NotifyLocale(Config.Locale.no_vehicle, 'error')
            return
        end

        TriggerServerEvent('bd-fakeplate:server:checkPlate', netId)
    end, false)

    TriggerEvent('chat:addSuggestion', '/' .. Config.CheckPlateCommand, 'Inspect vehicle plate records (LEO)')
end

RegisterNetEvent('bd-fakeplate:client:showPlateCheck', function(data)
    if not data then return end

    local status = data.active and Config.Locale.checkplate_status_active or Config.Locale.checkplate_status_none

    lib.alertDialog({
        header = Config.Locale.checkplate_header,
        content = string.format(
            '%s\n%s\n%s',
            string.format(Config.Locale.checkplate_original, data.originalPlate or 'N/A'),
            string.format(Config.Locale.checkplate_fake, data.fakePlate or 'N/A'),
            status
        ),
        centered = true,
        cancel = false,
        labels = { confirm = 'Close' },
    })
end)

-- ---------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------

CreateThread(function()
    InitFramework()
end)
