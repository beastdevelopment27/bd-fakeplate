--[[
    Notifications (manual provider only)
    Set Provider to the notify system your server uses.
    If Config.UseCommunityBridge = true, use 'community_bridge' (recommended).
]]

Config.Notifications = {
    -- community_bridge | ox_lib | esx | esx_notify | qb | okokNotify | mythic_notify
    -- codem-notification | brutal_notify | t-notify | pNotify | custom | native
    Provider = 'community_bridge',

    Title = 'Fake Plate',
    UseTitle = true,

    success = { type = 'success', duration = 5000 },
    error = { type = 'error', duration = 6000 },
    info = { type = 'inform', duration = 5000 },

    TypeMap = {
        qb = { success = 'success', error = 'error', info = 'primary' },
        okokNotify = { success = 'success', error = 'error', info = 'info' },
        mythic_notify = { success = 'success', error = 'error', info = 'inform' },
        ['codem-notification'] = { success = 'success', error = 'error', info = 'info' },
        brutal_notify = { success = 'success', error = 'error', info = 'info' },
        ['t-notify'] = { success = 'success', error = 'error', info = 'info' },
        pNotify = { success = 'success', error = 'error', info = 'info' },
        esx_notify = { success = 'success', error = 'error', info = 'info' },
    },

    Custom = {
        Mode = 'event',
        Event = 'bd-fakeplate:client:customNotify',
        ExportResource = '',
        ExportFunction = '',
    },
}
