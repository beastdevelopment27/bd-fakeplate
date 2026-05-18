--[[
    bd-fakeplate | Configuration
    Adjust all gameplay, framework, and integration settings here.
]]

Config = {}

-- 'esx' | 'qb' | 'auto' (auto-detect first available framework)
Config.Framework = 'auto'

-- Item names (must match ox_inventory item definitions)
Config.Items = {
    FakePlate = 'fakeplate',
    Screwdriver = 'screwdriver',
}

-- Consume fake plate item on successful install
Config.ConsumeFakePlate = true

-- Screwdriver stays in inventory after removal
Config.ConsumeScrewdriver = false

-- Allow custom plate text via ox_lib input dialog
Config.UseCustomPlate = true

-- Custom plate length limits (GTA plates are max 8 chars)
Config.PlateMinLength = 1
Config.PlateMaxLength = 8

-- Progress durations (milliseconds)
Config.InstallDuration = 8000
Config.RemoveDuration = 6000

-- Max distance to interact with a vehicle (meters)
Config.InteractDistance = 3.0

-- Random plate generation
Config.RandomPlate = {
  Enabled = true,
  -- Character set for random plates (letters + numbers)
  Charset = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789',
  Length = 8,
}

-- Police alert while installing (0.0 - 1.0)
Config.PoliceAlertChance = 0.15

-- Fingerprint / evidence left on vehicle (0.0 - 1.0)
Config.EvidenceChance = 0.25

-- Fake plate falls off when body health drops below threshold
Config.CrashDetach = true
Config.MinimumBodyHealth = 250.0
Config.CrashCheckInterval = 2000 -- ms between body health checks (client)

-- Vehicle class blacklist (see https://docs.fivem.net/natives/?_0x29439776AAA00A62)
-- Example: 15 = Helicopters, 16 = Planes, 14 = Boats
Config.BlacklistedVehicleClasses = {
    14, -- Boats
    15, -- Helicopters
    16, -- Planes
    21, -- Trains
}

-- Jobs allowed to install fake plates (empty = everyone)
Config.WhitelistJobsInstall = {}

-- Jobs allowed to use /checkplate (police, etc.)
Config.AllowedJobsCheckPlate = {
    'police',
    'sheriff',
    'state',
    'fib',
}

-- Enable /checkplate command
Config.EnableCommands = true
Config.CheckPlateCommand = 'checkplate'

-- Animations during install / remove
Config.Animations = {
    Install = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        clip = 'machinic_loop_mechandplayer',
        flag = 49,
    },
    Remove = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        clip = 'machinic_loop_mechandplayer',
        flag = 49,
    },
}

-- ox_lib notification styling
Config.Notifications = {
    success = { type = 'success', duration = 5000 },
    error = { type = 'error', duration = 6000 },
    info = { type = 'inform', duration = 5000 },
}

-- State bag key used on vehicles (do not change unless you know what you are doing)
Config.StateBagKey = 'bd_fakeplate'

-- Optional SQL persistence (requires oxmysql)
Config.SQL = {
    Enabled = false,
    TableName = 'bd_fakeplates',
    AutoCreateTable = true,
}

-- Optional Discord webhook logging
Config.Discord = {
    Enabled = false,
    Webhook = '', -- paste webhook URL here
    BotName = 'bd-fakeplate',
    Color = 3447003, -- decimal embed color
    Footer = 'Beast Development • Fake Plate System',
}

-- Save install metadata to state (installedBy, timestamp)
Config.SaveMetadata = true

-- Police alert integration
-- 'event' = TriggerEvent on client | 'export' = call export | 'none' = notification only
Config.PoliceAlert = {
    Mode = 'event',
    Event = 'bd-fakeplate:client:policeAlert', -- replace with your dispatch event
    ExportResource = '', -- e.g. 'ps-dispatch'
    ExportFunction = '', -- e.g. 'VehicleTheft'
}

-- Evidence integration (fingerprint systems, etc.)
Config.Evidence = {
    Mode = 'event', -- 'event' | 'export' | 'none'
    Event = 'bd-fakeplate:server:leaveEvidence',
    ExportResource = '',
    ExportFunction = '',
}

-- Locale strings (RP-friendly)
--[[
    ox_inventory item setup (data/items.lua or items/*.lua):

    ['fakeplate'] = {
        label = 'Fake License Plate',
        weight = 1200,
        stack = false,
        close = true,
        consume = 0, -- consumption handled by bd-fakeplate when Config.ConsumeFakePlate = true
        description = 'A counterfeit plate kit for discreet vehicle identity changes.',
        server = { export = 'bd-fakeplate.useFakePlate' },
    },

    ['screwdriver'] = {
        label = 'Screwdriver',
        weight = 250,
        stack = true,
        close = true,
        consume = 0,
        description = 'Used to remove installed fake plates.',
        server = { export = 'bd-fakeplate.useScrewdriver' },
    },

    server.cfg:
    ensure ox_lib
    ensure ox_inventory
    ensure bd-fakeplate
]]

Config.Locale = {
    no_vehicle = 'No vehicle nearby.',
    not_in_vehicle_zone = 'Move closer to the vehicle.',
    already_fake = 'This vehicle already has a fake plate installed.',
    no_fake_plate = 'This vehicle does not have a fake plate.',
    blacklisted_class = 'You cannot install a fake plate on this type of vehicle.',
    job_denied = 'Your job cannot use this item.',
    install_cancelled = 'Installation cancelled.',
    remove_cancelled = 'Removal cancelled.',
    install_success = 'Fake plate installed: %s',
    remove_success = 'Original plate restored: %s',
    police_alert = 'Someone reported suspicious activity near a vehicle.',
    evidence_left = 'You may have left evidence on the vehicle.',
    plate_fell_off = 'The fake plate fell off due to vehicle damage.',
    checkplate_header = 'Plate Inspection',
    checkplate_original = 'Original Plate: %s',
    checkplate_fake = 'Fake Plate: %s',
    checkplate_status_active = 'Status: Fake plate ACTIVE',
    checkplate_status_none = 'Status: No fake plate',
    checkplate_denied = 'You are not authorized to inspect plates.',
    invalid_plate = 'Invalid plate text.',
    exploit = 'Action blocked.',
    custom_plate_title = 'Custom Fake Plate',
    custom_plate_label = 'Plate Text (max 8 characters)',
    install_label = 'Installing fake plate...',
    remove_label = 'Removing fake plate...',
}
