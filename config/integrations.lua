--[[
    Third-party integrations (garage, SQL, Discord)
]]

Config.UseCommunityBridge = true

Config.GarageIntegration = {
    Enabled = true,
}

Config.SQL = {
    Enabled = false,
    TableName = 'bd_fakeplates',
    AutoCreateTable = true,
}

Config.Discord = {
    Enabled = false,
    Webhook = '',
    BotName = 'bd-fakeplate',
    Color = 3447003,
    Footer = 'Beast Development • Fake Plate System',
}
