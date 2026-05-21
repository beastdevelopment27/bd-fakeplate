local function GetStyle(notifyType)
    return Config.Notifications[notifyType] or Config.Notifications.info
end

function Notify(data)
    BdIntegrations.Notify.Client(
        data.description or '',
        data.type or 'info',
        data.duration or 5000
    )
end

function NotifyLocale(message, notifyType)
    local style = GetStyle(notifyType)
    Notify({
        description = message,
        type = notifyType,
        duration = style.duration,
    })
end

RegisterNetEvent('bd-fakeplate:client:notify', function(message, notifyType)
    NotifyLocale(message, notifyType or 'info')
end)
