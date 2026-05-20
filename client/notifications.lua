--[[
    bd-fakeplate | Multi-provider notifications
]]

local cachedProvider = nil

---@param notifyType string
---@return table
local function GetStyle(notifyType)
    return Config.Notifications[notifyType] or Config.Notifications.info
end

---@param notifyType string
---@return string
local function MapType(provider, notifyType)
    local style = GetStyle(notifyType)
    local maps = Config.Notifications.TypeMap
    if maps and maps[provider] and maps[provider][notifyType] then
        return maps[provider][notifyType]
    end
    return style.type
end

---@param message string
---@return string
local function BuildMessage(message)
    local cfg = Config.Notifications
    if cfg.UseTitle and cfg.Title and cfg.Title ~= '' then
        return ('%s\n%s'):format(cfg.Title, message)
    end
    return message
end

---@return string
local function GetProvider()
    if cachedProvider then return cachedProvider end

    local provider = Config.Notifications.Provider or 'ox_lib'
    if provider == 'community_bridge' and not BdBridge.IsEnabled() then
        print('^3[bd-fakeplate]^7 community_bridge not started; falling back to ox_lib notifications.')
        provider = 'ox_lib'
    end

    cachedProvider = provider
    return cachedProvider
end

---@param message string
---@param ntype string
---@param duration number
local function DispatchNotify(message, ntype, duration)
    local provider = GetProvider()
    local cfg = Config.Notifications
    local mappedType = MapType(provider, ntype)
    local text = BuildMessage(message)

    if provider == 'community_bridge' then
        local NotifyMod = BdBridge.Notify()
        if NotifyMod and NotifyMod.SendNotification then
            NotifyMod.SendNotification(cfg.Title, message, mappedType, duration)
            return
        end
    end

    if provider == 'ox_lib' then
        lib.notify({
            title = cfg.Title,
            description = message,
            type = mappedType,
            duration = duration,
        })
        return
    end

    if provider == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        if ESX and ESX.ShowNotification then
            local ok = pcall(function()
                ESX.ShowNotification(message, mappedType, duration)
            end)
            if not ok then
                ESX.ShowNotification(text)
            end
            return
        end
    end

    if provider == 'esx_notify' then
        local ok = pcall(function()
            exports['esx_notify']:Notify(mappedType, duration, message, cfg.Title)
        end)
        if not ok then
            pcall(function()
                exports['esx_notify']:Notify(message, duration, mappedType)
            end)
        end
        return
    end

    if provider == 'qb' then
        local QBCore = exports['qb-core']:GetCoreObject()
        if QBCore and QBCore.Functions and QBCore.Functions.Notify then
            QBCore.Functions.Notify(message, mappedType, duration)
            return
        end
    end

    if provider == 'okokNotify' then
        exports['okokNotify']:Alert(cfg.Title, message, duration, mappedType, false)
        return
    end

    if provider == 'mythic_notify' then
        exports['mythic_notify']:SendAlert({
            type = mappedType,
            text = message,
            length = duration,
        })
        return
    end

    if provider == 'codem-notification' then
        local ok = pcall(function()
            exports['codem-notification']:Notify(message, duration, mappedType)
        end)
        if not ok then
            pcall(function()
                exports['codem-notification']:CreateNotification(mappedType, message, cfg.Title, duration)
            end)
        end
        return
    end

    if provider == 'brutal_notify' then
        pcall(function()
            exports['brutal_notify']:SendAlert(cfg.Title, message, mappedType, duration)
        end)
        return
    end

    if provider == 't-notify' then
        pcall(function()
            exports['t-notify']:Alert({
                style = mappedType,
                message = message,
                title = cfg.Title,
                duration = duration,
            })
        end)
        return
    end

    if provider == 'pNotify' then
        pcall(function()
            exports.pNotify:SendNotification({
                text = text,
                type = mappedType,
                timeout = duration,
                layout = 'centerRight',
            })
        end)
        return
    end

    if provider == 'custom' then
        local custom = cfg.Custom
        if custom.Mode == 'export' and custom.ExportResource ~= '' and custom.ExportFunction ~= '' then
            if GetResourceState(custom.ExportResource) == 'started' then
                exports[custom.ExportResource][custom.ExportFunction](message, mappedType, duration, cfg.Title)
                return
            end
        elseif custom.Mode == 'event' and custom.Event ~= '' then
            TriggerEvent(custom.Event, message, mappedType, duration, cfg.Title)
            return
        end
    end

    -- native fallback (GTA feed)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, true)
end

---@param data table
function Notify(data)
    DispatchNotify(data.description or '', data.type or 'info', data.duration or 5000)
end

---@param message string
---@param notifyType string
function NotifyLocale(message, notifyType)
    local style = GetStyle(notifyType)
    Notify({
        description = message,
        type = style.type,
        duration = style.duration,
    })
end

RegisterNetEvent('bd-fakeplate:client:customNotify', function(message, notifyType, duration, title)
    if title and title ~= '' then
        Config.Notifications.Title = title
    end
    Notify({
        description = message,
        type = notifyType or 'info',
        duration = duration or 5000,
    })
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    cachedProvider = nil
end)
