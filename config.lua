--[[
    bd-fakeplate | Main configuration loader
    Additional settings live in config/*.lua (loaded via fxmanifest).
]]

Config = {}

-- 'esx' | 'qb' | 'auto' (auto-detect first available framework)
Config.Framework = 'auto'

-- Item names (must match ox_inventory item definitions)
Config.Items = {
    FakePlate = 'fakeplate',
    Screwdriver = 'screwdriver',
}