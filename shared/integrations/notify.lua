BdIntegrations = BdIntegrations or {}
BdIntegrations.Notify = BdIntegrations.Notify or {}

local function MapNotifyType(notifyType)
    local style = Config.Notifications[notifyType] or Config.Notifications.info
    if style.type == 'info' then return 'inform' end
    return style.type
end

local function ResolveProvider()
    local custom = BdIntegrations.GetCustom('Notify')
    if custom then return 'custom' end

    local provider = BdIntegrations.GetProvider('Notify', 'auto')
    if provider ~= 'auto' then return provider end

    return BdIntegrations.ResolveAutoProvider({
        { id = 'ox_lib', when = function() return lib ~= nil and lib.notify ~= nil end },
        { id = 'qb', when = function() return BdIntegrations.ResourceStarted('qb-core') end },
        { id = 'esx', when = function() return BdIntegrations.ResourceStarted('es_extended') end },
        { id = 'native', when = function() return true end },
    })
end

function BdIntegrations.Notify.GetProvider()
    return ResolveProvider()
end

-- Client -----------------------------------------------------------------------

local function ClientOxLib(message, notifyType, duration)
    lib.notify({
        title = Config.Notifications.Title,
        description = message,
        type = notifyType,
        duration = duration,
    })
end

local function ClientQb(message, notifyType, duration)
    local QBCore = exports['qb-core']:GetCoreObject()
    QBCore.Functions.Notify(message, notifyType, duration)
end

local function ClientEsx(message)
    local ESX = exports['es_extended']:getSharedObject()
    ESX.ShowNotification(message)
end

local function ClientNative(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end

function BdIntegrations.Notify.Client(message, notifyType, duration)
    duration = duration or 5000
    local mapped = MapNotifyType(notifyType or 'info')

    local custom = BdIntegrations.GetCustom('Notify')
    if custom and custom.Client then
        if custom:Client(message, mapped, duration) ~= false then return end
    elseif type(custom) == 'function' then
        if custom(message, mapped, duration) ~= false then return end
    end

    local provider = ResolveProvider()
    if provider == 'ox_lib' and lib and lib.notify then
        ClientOxLib(message, mapped, duration)
    elseif provider == 'qb' then
        ClientQb(message, mapped, duration)
    elseif provider == 'esx' then
        ClientEsx(message)
    else
        ClientNative(message)
    end
end

-- Server -----------------------------------------------------------------------

function BdIntegrations.Notify.Server(src, message, notifyType, duration)
    local style = Config.Notifications[notifyType] or Config.Notifications.info
    duration = duration or style.duration
    local mapped = MapNotifyType(notifyType or 'info')

    local custom = BdIntegrations.GetCustom('Notify')
    if custom and custom.Server then
        if custom:Server(src, message, mapped, duration) ~= false then return end
    elseif type(custom) == 'function' then
        if custom(src, message, mapped, duration) ~= false then return end
    end

    local provider = ResolveProvider()
    if provider == 'ox_lib' and lib and lib.notify then
        TriggerClientEvent('ox_lib:notify', src, {
            title = Config.Notifications.Title,
            description = message,
            type = mapped,
            duration = duration,
        })
        return
    end

    if provider == 'qb' then
        TriggerClientEvent('QBCore:Notify', src, message, mapped, duration)
        return
    end

    if provider == 'esx' then
        TriggerClientEvent('esx:showNotification', src, message)
        return
    end

    TriggerClientEvent('bd-fakeplate:client:notify', src, message, notifyType or 'info')
end
