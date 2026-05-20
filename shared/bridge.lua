--[[
    bd-fakeplate | community_bridge helpers
]]

BdBridge = BdBridge or {}

---@return boolean
function BdBridge.IsEnabled()
    if Config.UseCommunityBridge == false then return false end
    return GetResourceState('community_bridge') == 'started'
end

---@param moduleName string
---@return table|nil
function BdBridge.GetModule(moduleName)
    if not BdBridge.IsEnabled() then return nil end
    local ok, module = pcall(function()
        return exports['community_bridge'][moduleName]()
    end)
    if ok and module then return module end
    return nil
end

function BdBridge.Framework()
    return BdBridge.GetModule('Framework')
end

function BdBridge.Inventory()
    return BdBridge.GetModule('Inventory')
end

function BdBridge.Notify()
    return BdBridge.GetModule('Notify')
end

function BdBridge.ProgressBar()
    return BdBridge.GetModule('ProgressBar')
end

function BdBridge.Input()
    return BdBridge.GetModule('Input')
end
