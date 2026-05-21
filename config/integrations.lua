-- Pick a provider per feature, or use 'auto' to detect what is running.
-- Providers:
--   Notify:      auto | ox_lib | qb | esx | native | custom
--   Inventory:   auto | ox_inventory | qb-inventory | qs-inventory | esx | none | custom
--   Progressbar: auto | ox_lib | qb | custom
--   Dialogue:    auto | ox_lib | custom
Config.Integrations = {
    Notify = 'auto',
    Inventory = 'auto',
    Progressbar = 'auto',
    Dialogue = 'auto',

    -- Add your own handlers (return false from Client/Server to fall through to built-ins).
    Custom = {
        -- Notify = {
        --     Client = function(self, message, notifyType, duration) end,
        --     Server = function(self, src, message, notifyType, duration) end,
        -- },
        -- Inventory = {
        --     HasItem = function(self, src, item, amount) return true end,
        --     RemoveItem = function(self, src, item, amount) return true end,
        -- },
        -- Progressbar = {
        --     Start = function(self, options) return lib.progressBar(options) end,
        -- },
        -- Dialogue = {
        --     Input = function(self, data) return lib.inputDialog(data.title, data.inputs) end,
        -- },
    },
}

Config.Discord = {
    Enabled = true,
    Webhook = 'https://discord.com/api/webhooks/1376498942312972320/FedJTIi63cWKVQOqTmdGxvuJaqnScl49xx5R4WVNgsQ-ZBSYiha9VinL5H9Np7kx45B6',
    BotName = 'bd-fakeplate',
    Color = 3447003,
    Footer = 'Beast Development • Fake Plate System',
}
