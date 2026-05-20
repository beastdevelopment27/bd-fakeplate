--[[
    Core gameplay tuning
]]

Config.ConsumeFakePlate = true
Config.ConsumeScrewdriver = false

Config.UseCustomPlate = true
Config.PlateMinLength = 1
Config.PlateMaxLength = 8

Config.InstallDuration = 8000
Config.RemoveDuration = 6000
Config.InteractDistance = 3.0

Config.RandomPlate = {
    Enabled = false,
    Charset = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789',
    Length = 8,
}

Config.CrashDetach = true
Config.MinimumBodyHealth = 250.0
Config.CrashCheckInterval = 2000

-- https://docs.fivem.net/natives/?_0x29439776AAA00A62
Config.BlacklistedVehicleClasses = {
    14, -- Boats
    15, -- Helicopters
    16, -- Planes
    21, -- Trains
}

Config.WhitelistJobsInstall = {}

Config.AllowedJobsCheckPlate = {
    'police',
    'sheriff',
    'state',
    'fib',
}

Config.EnableCommands = true
Config.CheckPlateCommand = 'checkplate'

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

Config.SaveMetadata = true

-- State bag key on vehicles (change only if you know what you are doing)
Config.StateBagKey = 'bd_fakeplate'
