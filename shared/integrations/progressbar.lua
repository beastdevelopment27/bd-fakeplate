BdIntegrations = BdIntegrations or {}
BdIntegrations.Progressbar = BdIntegrations.Progressbar or {}

local function ResolveProvider()
    local custom = BdIntegrations.GetCustom('Progressbar')
    if custom then return 'custom' end

    local provider = BdIntegrations.GetProvider('Progressbar', 'auto')
    if provider ~= 'auto' then return provider end

    return BdIntegrations.ResolveAutoProvider({
        { id = 'ox_lib', when = function() return lib ~= nil and lib.progressBar ~= nil end },
        { id = 'qb', when = function() return BdIntegrations.ResourceStarted('qb-core') end },
        { id = 'none', when = function() return true end },
    })
end

function BdIntegrations.Progressbar.GetProvider()
    return ResolveProvider()
end

local function StartOxLib(options)
    return lib.progressBar(options)
end

local function StartQb(options)
    local completed = nil
    local QBCore = exports['qb-core']:GetCoreObject()
    QBCore.Functions.Progressbar(
        'bd_fakeplate_action',
        options.label or 'Working...',
        options.duration or 5000,
        false,
        true,
        {
            disableMovement = options.disable and options.disable.move,
            disableCarMovement = options.disable and options.disable.car,
            disableCombat = options.disable and options.disable.combat,
        },
        {},
        {},
        {},
        function()
            completed = true
        end,
        function()
            completed = false
        end
    )

    while completed == nil do
        Wait(0)
    end

    return completed
end

function BdIntegrations.Progressbar.Start(options)
    local custom = BdIntegrations.GetCustom('Progressbar')
    if custom then
        if custom.Start then return custom:Start(options) end
        if type(custom) == 'function' then return custom(options) end
    end

    local provider = ResolveProvider()
    if provider == 'ox_lib' and lib and lib.progressBar then
        return StartOxLib(options)
    end
    if provider == 'qb' and BdIntegrations.ResourceStarted('qb-core') then
        return StartQb(options)
    end

    return false
end
