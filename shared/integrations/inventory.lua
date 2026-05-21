BdIntegrations = BdIntegrations or {}
BdIntegrations.Inventory = BdIntegrations.Inventory or {}

local function OxInventoryStarted()
    return BdIntegrations.ResourceStarted('ox_inventory')
end

local function ResolveProvider()
    local custom = BdIntegrations.GetCustom('Inventory')
    if custom then return 'custom' end

    local provider = BdIntegrations.GetProvider('Inventory', 'auto')
    if provider ~= 'auto' then return provider end

    return BdIntegrations.ResolveAutoProvider({
        { id = 'ox_inventory', when = OxInventoryStarted },
        { id = 'qb-inventory', when = function() return BdIntegrations.ResourceStarted('qb-inventory') end },
        { id = 'qs-inventory', when = function() return BdIntegrations.ResourceStarted('qs-inventory') end },
        { id = 'esx', when = function() return BdIntegrations.ResourceStarted('es_extended') end },
        { id = 'none', when = function() return true end },
    })
end

function BdIntegrations.Inventory.GetProvider()
    return ResolveProvider()
end

local function CustomHasItem(src, item, amount)
    local custom = BdIntegrations.GetCustom('Inventory')
    if not custom then return nil end
    if custom.HasItem then return custom:HasItem(src, item, amount) end
    if type(custom) == 'function' then return custom(src, item, amount, 'has') end
    return nil
end

local function CustomRemoveItem(src, item, amount)
    local custom = BdIntegrations.GetCustom('Inventory')
    if not custom then return nil end
    if custom.RemoveItem then return custom:RemoveItem(src, item, amount) end
    if type(custom) == 'function' then return custom(src, item, amount, 'remove') end
    return nil
end

local function OxHasItem(src, item, amount)
    local count = exports.ox_inventory:Search(src, 'count', item)
    return count and count >= amount
end

local function OxRemoveItem(src, item, amount, slot)
    return exports.ox_inventory:RemoveItem(src, item, amount, nil, slot)
end

local function QbHasItem(src, item, amount)
    local ok, result = pcall(function()
        return exports['qb-inventory']:HasItem(src, item, amount)
    end)
    if ok then return result end

    local QBCore = exports['qb-core']:GetCoreObject()
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    local invItem = player.Functions.GetItemByName(item)
    return invItem ~= nil and (invItem.amount or invItem.count or 0) >= amount
end

local function QbRemoveItem(src, item, amount)
    local ok, result = pcall(function()
        return exports['qb-inventory']:RemoveItem(src, item, amount)
    end)
    if ok then return result end

    local QBCore = exports['qb-core']:GetCoreObject()
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    return player.Functions.RemoveItem(item, amount)
end

local function QsHasItem(src, item, amount)
    local ok, result = pcall(function()
        return exports['qs-inventory']:GetItemTotalAmount(src, item) >= amount
    end)
    return ok and result or false
end

local function QsRemoveItem(src, item, amount)
    local ok, result = pcall(function()
        return exports['qs-inventory']:RemoveItem(src, item, amount)
    end)
    return ok and result or false
end

local function EsxHasItem(src, item, amount)
    local ESX = exports['es_extended']:getSharedObject()
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local invItem = xPlayer.getInventoryItem(item)
    return invItem ~= nil and invItem.count >= amount
end

local function EsxRemoveItem(src, item, amount)
    local ESX = exports['es_extended']:getSharedObject()
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    xPlayer.removeInventoryItem(item, amount)
    return true
end

function BdIntegrations.Inventory.HasItem(src, item, amount)
    amount = amount or 1

    local custom = CustomHasItem(src, item, amount)
    if custom ~= nil then return custom end

    local provider = ResolveProvider()
    if provider == 'ox_inventory' and OxInventoryStarted() then
        return OxHasItem(src, item, amount)
    end
    if provider == 'qb-inventory' then
        return QbHasItem(src, item, amount)
    end
    if provider == 'qs-inventory' then
        return QsHasItem(src, item, amount)
    end
    if provider == 'esx' then
        return EsxHasItem(src, item, amount)
    end

    return false
end

function BdIntegrations.Inventory.RemoveItem(src, item, amount, slot)
    amount = amount or 1

    local custom = CustomRemoveItem(src, item, amount)
    if custom ~= nil then return custom end

    local provider = ResolveProvider()
    if provider == 'ox_inventory' and OxInventoryStarted() then
        return OxRemoveItem(src, item, amount, slot)
    end
    if provider == 'qb-inventory' then
        return QbRemoveItem(src, item, amount)
    end
    if provider == 'qs-inventory' then
        return QsRemoveItem(src, item, amount)
    end
    if provider == 'esx' then
        return EsxRemoveItem(src, item, amount)
    end

    return false
end
