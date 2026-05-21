BdIntegrations = BdIntegrations or {}
BdIntegrations.Dialogue = BdIntegrations.Dialogue or {}

local function ResolveProvider()
    local custom = BdIntegrations.GetCustom('Dialogue')
    if custom then return 'custom' end

    local provider = BdIntegrations.GetProvider('Dialogue', 'auto')
    if provider ~= 'auto' then return provider end

    return BdIntegrations.ResolveAutoProvider({
        { id = 'ox_lib', when = function() return lib ~= nil and lib.inputDialog ~= nil end },
        { id = 'none', when = function() return true end },
    })
end

function BdIntegrations.Dialogue.GetProvider()
    return ResolveProvider()
end

function BdIntegrations.Dialogue.Input(data)
    local custom = BdIntegrations.GetCustom('Dialogue')
    if custom then
        if custom.Input then return custom:Input(data) end
        if type(custom) == 'function' then return custom(data) end
    end

    if ResolveProvider() == 'ox_lib' and lib and lib.inputDialog then
        return lib.inputDialog(data.title, data.inputs)
    end

    return nil
end
