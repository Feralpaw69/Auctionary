local Auctionary = Auctionary

local SLASH_COMMAND_DESCRIPTIONS = {
  {commands = "p, post", message = "Posts the chosen item from the \"Selling\" tab." },
  {commands = "cu, cancelundercut", message = "Cancels the next undercut auction in the \"Cancelling\" tab." },
  {commands = "ra, resetall", message = "Reset database and full scan timer." },
  {commands = "rdb, resetdatabase", message = "Reset Auctionary database."},
  {commands = "rt, resettimer", message = "Reset full scan timer."},
  {commands = "rc, resetconfig", message = "Reset configuration to defaults."},
  {commands = "npd, nopricedb", message = "Disable recording auction prices."},
  {commands = "d, debug", message = "Toggle debug mode."},
  {commands = "c, config", message = "Show current configuration values."},
  {commands = "c [toggle-name], config [toggle-name]", message = "Toggle the value of the configuration value [toggle-name]."},
  {commands = "v, version", message = "Show current version."},
  
  {commands = "h, help", message = "Show this help message."},
}

function Auctionary.SlashCmd.Post()
  Auctionary.EventBus
    :RegisterSource(Auctionary.SlashCmd.Post, "Auctionary.SlashCmd.Post")
    :Fire(Auctionary.SlashCmd.Post, Auctionary.Selling.Events.RequestPost)
    :UnregisterSource(Auctionary.SlashCmd.Post)
end

function Auctionary.SlashCmd.CancelUndercut()
  Auctionary.EventBus
    :RegisterSource(Auctionary.SlashCmd.CancelUndercut, "Auctionary.SlashCmd.CancelUndercut")
    :Fire(Auctionary.SlashCmd.CancelUndercut, Auctionary.Cancelling.Events.RequestCancelUndercut)
    :UnregisterSource(Auctionary.SlashCmd.CancelUndercut)
end

function Auctionary.SlashCmd.ToggleDebug()
  Auctionary.Debug.Toggle()
  if Auctionary.Debug.IsOn() then
    Auctionary.Utilities.Message("Debug mode on")
  else
    Auctionary.Utilities.Message("Debug mode off")
  end
end

function Auctionary.SlashCmd.ResetDatabase()
  if Auctionary.Debug.IsOn() then
    -- See Source/Variables/Main.lua for variable usage
    AUCTIONARY_PRICE_DATABASE = nil
    Auctionary.Utilities.Message("Price database reset")
    Auctionary.Variables.InitializeDatabase()
  else
    Auctionary.Utilities.Message("Requires debug mode.")
  end
end

function Auctionary.SlashCmd.ResetTimer()
  if Auctionary.Debug.IsOn() then
    Auctionary.SavedState.TimeOfLastReplicateScan = nil
    Auctionary.SavedState.TimeOfLastGetAllScan = nil
    Auctionary.Utilities.Message("Scan timer reset.")
  else
    Auctionary.Utilities.Message("Requires debug mode.")
  end
end

function Auctionary.SlashCmd.CleanReset()
  Auctionary.SlashCmd.ResetTimer()
  Auctionary.SlashCmd.ResetDatabase()
end

function Auctionary.SlashCmd.NoPriceDB()
  Auctionary.Config.Set(Auctionary.Config.Options.NO_PRICE_DATABASE, true)

  AUCTIONARY_PRICE_DATABASE = nil
  Auctionary.Variables.InitializeDatabase()

  Auctionary.Utilities.Message("Disabled recording auction prices in the price database.")
end

function Auctionary.SlashCmd.ResetConfig()
  if Auctionary.Debug.IsOn() then
    Auctionary.Config.Reset()
    Auctionary.Utilities.Message("Config reset.")
  else
    Auctionary.Utilities.Message("Requires debug mode.")
  end
end

local INVALID_OPTION_VALUE = "Wrong config value type %s (required %s)"
function Auctionary.SlashCmd.Config(optionName, value1, ...)
  if optionName == nil then
    Auctionary.Utilities.Message("No config option name supplied")
    for _, name in pairs(Auctionary.Config.Options) do
      Auctionary.Utilities.Message(name .. ": " .. tostring(Auctionary.Config.Get(name)))
    end
    return
  end

  local currentValue = Auctionary.Config.Get(optionName)
  if currentValue == nil then
    Auctionary.Utilities.Message("Unknown config: " .. optionName)
    return
  end

  if value1 == nil then
    Auctionary.Utilities.Message("Config " .. optionName .. ": " .. tostring(currentValue))
    return
  end

  if type(currentValue) == "boolean" then
    if value1 ~= "true" and value1 ~= "false" then
      Auctionary.Utilities.Message(INVALID_OPTION_VALUE:format(type(value1), type(currentValue)))
      return
    end
    Auctionary.Config.Set(optionName, value1 == "true")
  elseif type(currentValue) == "number" then
    if tonumber(value1) == nil then
      Auctionary.Utilities.Message(INVALID_OPTION_VALUE:format(type(value1), type(currentValue)))
      return
    end
    Auctionary.Config.Set(optionName, tonumber(value1))
  elseif type(currentValue) == "string" then
    Auctionary.Config.Set(optionName, strjoin(" ", value1, ...))
  else
    Auctionary.Utilities.Message("Unable to edit option type " .. type(currentValue))
    return
  end
  Auctionary.Utilities.Message("Now set " .. optionName .. ": " .. tostring(Auctionary.Config.Get(optionName)))
end

function Auctionary.SlashCmd.Version()
  Auctionary.Utilities.Message(AUCTIONARY_L_VERSION_HEADER .. " " .. Auctionary.State.CurrentVersion)
end

function Auctionary.SlashCmd.Help()
  for index = 1, #SLASH_COMMAND_DESCRIPTIONS do
    local description = SLASH_COMMAND_DESCRIPTIONS[index]
    Auctionary.Utilities.Message(description.commands .. ": " .. description.message)
  end
end
