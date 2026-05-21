Config.ConsumeFakePlate = true
Config.ConsumeScrewdriver = true

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

Config.BlacklistedVehicleClasses = {
    14,
    15,
    16,
    21,
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
Config.StateBagKey = 'bd_fakeplate'
Config.GarageIntegration = {
    Enabled = true,
}

Config.SQL = {
    Enabled = true,
    TableName = 'bd_fakeplates',
    AutoCreateTable = true,
}

