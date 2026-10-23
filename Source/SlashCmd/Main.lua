local Auctionary = Auctionary

function Auctionary.SlashCmd.Initialize()
  SlashCmdList["AUCTIONARY"] = Auctionary.SlashCmd.Handler
  SLASH_AUCTIONARY1 = "/aury"
  SLASH_AUCTIONARY2 = "/auctionary"
  -- Gold Tracker, also away from the auction house
  SlashCmdList["AUCTIONARYGOLD"] = function()
    Auctionary.Components.ShowGoldTracker()
  end
  SLASH_AUCTIONARYGOLD1 = "/goldtracker"
end

--Update SLASH_COMMAND_DESCRIPTIONS in Commands.lua for new commands
local SLASH_COMMANDS = {
  ["p"] = Auctionary.SlashCmd.Post,
  ["post"] = Auctionary.SlashCmd.Post,
  ["cu"] = Auctionary.SlashCmd.CancelUndercut,
  ["cancelundercut"] = Auctionary.SlashCmd.CancelUndercut,
  ["ra"] = Auctionary.SlashCmd.CleanReset,
  ["resetall"] = Auctionary.SlashCmd.CleanReset,
  ["rt"] = Auctionary.SlashCmd.ResetTimer,
  ["resettimer"] = Auctionary.SlashCmd.ResetTimer,
  ["rdb"] = Auctionary.SlashCmd.ResetDatabase,
  ["resetdatabase"] = Auctionary.SlashCmd.ResetDatabase,
  ["rc"] = Auctionary.SlashCmd.ResetConfig,
  ["resetconfig"] = Auctionary.SlashCmd.ResetConfig,
  ["d"] = Auctionary.SlashCmd.ToggleDebug,
  ["debug"] = Auctionary.SlashCmd.ToggleDebug,
  ["config"] = Auctionary.SlashCmd.Config,
  ["c"] = Auctionary.SlashCmd.Config,
  ["v"] = Auctionary.SlashCmd.Version,
  ["version"] = Auctionary.SlashCmd.Version,
  ["nopricedb"] = Auctionary.SlashCmd.NoPriceDB,
  ["npd"] = Auctionary.SlashCmd.NoPriceDB,
  ["h"] = Auctionary.SlashCmd.Help,
  ["help"] = Auctionary.SlashCmd.Help,
  ["test"] = Auctionary.SlashCmd.Test,
  ["sales"] = function() Auctionary.Components.ShowSales() end,
}

function Auctionary.SlashCmd.Handler(input)
  Auctionary.Debug.Message( 'Auctionary.SlashCmd.Handler', input )
  input = input or ""

  if #input == 0 then
    Auctionary.SlashCmd.Help()
  else
    local command = Auctionary.Utilities.SplitCommand(input);
    local handler = SLASH_COMMANDS[command[1]]
    if handler == nil then
      Auctionary.Utilities.Message("Unrecognized command '" .. tostring(command[1]) .. "'")
      Auctionary.SlashCmd.Help()
    elseif handler == Auctionary.SlashCmd.Test then
      -- Keeps the original text (item links contain upper case letters)
      handler(input)
    else
      handler(unpack(Auctionary.Utilities.Slice(command, 2, #command-1)))
    end
  end
end
