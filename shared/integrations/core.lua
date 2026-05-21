BdIntegrations = BdIntegrations or {}

function BdIntegrations.ResourceStarted(name)
    return GetResourceState(name) == 'started'
end

function BdIntegrations.GetProvider(key, defaultProvider)
    local integrations = Config.Integrations
    if not integrations then return defaultProvider or 'auto' end
    return integrations[key] or defaultProvider or 'auto'
end

function BdIntegrations.ResolveAutoProvider(candidates)
    for i = 1, #candidates do
        local entry = candidates[i]
        if entry.when() then return entry.id end
    end
    return candidates[#candidates].id
end

function BdIntegrations.GetCustom(key)
    local custom = Config.Integrations and Config.Integrations.Custom
    return custom and custom[key] or nil
end
