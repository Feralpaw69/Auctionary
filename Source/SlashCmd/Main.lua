local Auctionator = Auctionary

function Auctionator.SlashCmd.Initialize()
  SlashCmdList["AUCTIONARY"] = Auctionator.SlashCmd.Handler
  SLASH_AUCTIONARY1 = "/aury"
  SLASH_AUCTIONARY2 = "/auctionary"
  -- Gold Tracker, also away from the auction house
  SlashCmdList["AUCTIONARYGOLD"] = function()
    Auctionator.Components.ShowGoldTracker()
  end
  SLASH_AUCTIONARYGOLD1 = "/goldtracker"
end

--Update SLASH_COMMAND_DESCRIPTIONS in Commands.lua for new commands
local SLASH_COMMANDS = {
  ["p"] = Auctionator.SlashCmd.Post,
  ["post"] = Auctionator.SlashCmd.Post,
  ["cu"] = Auctionator.SlashCmd.CancelUndercut,
  ["cancelundercut"] = Auctionator.SlashCmd.CancelUndercut,
  ["ra"] = Auctionator.SlashCmd.CleanReset,
  ["resetall"] = Auctionator.SlashCmd.CleanReset,
  ["rt"] = Auctionator.SlashCmd.ResetTimer,
  ["resettimer"] = Auctionator.SlashCmd.ResetTimer,
  ["rdb"] = Auctionator.SlashCmd.ResetDatabase,
  ["resetdatabase"] = Auctionator.SlashCmd.ResetDatabase,
  ["rc"] = Auctionator.SlashCmd.ResetConfig,
  ["resetconfig"] = Auctionator.SlashCmd.ResetConfig,
  ["d"] = Auctionator.SlashCmd.ToggleDebug,
  ["debug"] = Auctionator.SlashCmd.ToggleDebug,
  ["config"] = Auctionator.SlashCmd.Config,
  ["c"] = Auctionator.SlashCmd.Config,
  ["v"] = Auctionator.SlashCmd.Version,
  ["version"] = Auctionator.SlashCmd.Version,
  ["nopricedb"] = Auctionator.SlashCmd.NoPriceDB,
  ["npd"] = Auctionator.SlashCmd.NoPriceDB,
  ["h"] = Auctionator.SlashCmd.Help,
  ["help"] = Auctionator.SlashCmd.Help,
  ["test"] = Auctionator.SlashCmd.Test,
  ["sales"] = function() Auctionator.Components.ShowSales() end,
}

function Auctionator.SlashCmd.Handler(input)
  Auctionator.Debug.Message( 'Auctionator.SlashCmd.Handler', input )
  input = input or ""

  if #input == 0 then
    Auctionator.SlashCmd.Help()
  else
    local command = Auctionator.Utilities.SplitCommand(input);
    local handler = SLASH_COMMANDS[command[1]]
    if handler == nil then
      Auctionator.Utilities.Message("Unrecognized command '" .. tostring(command[1]) .. "'")
      Auctionator.SlashCmd.Help()
    elseif handler == Auctionator.SlashCmd.Test then
      -- Keeps the original text (item links contain upper case letters)
      handler(input)
    else
      handler(unpack(Auctionator.Utilities.Slice(command, 2, #command-1)))
    end
  end
end
