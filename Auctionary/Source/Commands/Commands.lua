-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Chat commands: /aury, /a2 or /auctionary2, and /goldtracker

local Message = function(text) Auctionary.Utilities.Message(text) end
local Config = Auctionary.Config
local commands, help = {}, {}

-- names: "x, long"; run(args, wholeInput)
local function Command(names, description, run)
  help[#help + 1] = names .. ": " .. description
  for name in names:gmatch("[^,%s]+") do
    commands[name] = run
  end
end

local function NeedsDebug(run)
  return function(...)
    if not Auctionary.Debug.IsOn() then
      Message("Turn on debug mode first (/aury debug).")
      return
    end
    run(...)
  end
end

local function ResetTimer()
  Auctionary.SavedState.LastGetAllAt = nil
  Message("Scan timer reset.")
end

local function ResetDatabase()
  AUCTIONARY2_PRICE_DATABASE = nil
  Auctionary.Variables.OpenPriceDatabase()
  Message("Price database reset.")
end

Command("sales", "Show the sales summary.", function()
  Auctionary.Components.ShowSales()
end)
Command("gold", "Show the gold tracker.", function()
  Auctionary.Components.ShowGoldTracker()
end)
Command("rt, resettimer", "Reset the full scan timer (debug mode).", NeedsDebug(ResetTimer))
Command("rdb, resetdatabase", "Reset the price database (debug mode).", NeedsDebug(ResetDatabase))
Command("ra, resetall", "Reset the price database and the scan timer (debug mode).", NeedsDebug(function()
  ResetTimer()
  ResetDatabase()
end))
Command("rc, resetconfig", "Reset all settings (debug mode).", NeedsDebug(function()
  Config.Reset()
  Message("Settings reset.")
end))
Command("npd, nopricedb", "Stop recording auction prices.", function()
  Config.Set(Config.Options.NO_PRICE_DATABASE, true)
  AUCTIONARY2_PRICE_DATABASE = nil
  Auctionary.Variables.OpenPriceDatabase()
  Message("Auction prices are not recorded any more.")
end)
Command("d, debug", "Switch debug mode on or off.", function()
  Auctionary.Debug.Toggle()
  Message(Auctionary.Debug.IsOn() and "Debug mode on" or "Debug mode off")
end)
Command("c, config", "Show all settings, or show/change one: config <name> [value].", function(args)
  local name, value = args[1], args[2]
  if name == nil then
    for _, optionName in pairs(Config.Options) do
      Message(optionName .. ": " .. tostring(Config.Get(optionName)))
    end
    return
  end
  local current = Config.Get(name)
  if current == nil then
    Message("Unknown setting: " .. name)
  elseif value == nil then
    Message(name .. ": " .. tostring(current))
  elseif type(current) == "boolean" and (value == "true" or value == "false") then
    Config.Set(name, value == "true")
  elseif type(current) == "number" and tonumber(value) then
    Config.Set(name, tonumber(value))
  elseif type(current) == "string" then
    Config.Set(name, table.concat(args, " ", 2))
  else
    Message("This value does not fit " .. name .. " (" .. type(current) .. ").")
    return
  end
  if value ~= nil then
    Message(name .. " is now " .. tostring(Config.Get(name)))
  end
end)
Command("mem, memory", "Show the memory the addon uses and free what is not needed.", function()
  local before = Auctionary.Memory.GetUsage()
  Auctionary.Memory.CleanUpNow()
  local after = Auctionary.Memory.GetUsage()
  Message(string.format("Memory: %.1f MB (%.1f MB before the cleanup).", after, before))
end)
Command("v, version", "Show the version.", function()
  local author = GetAddOnMetadata(Auctionary.Constants.AddonName, "Author")
  Message("Version " .. tostring(Auctionary.State.CurrentVersion) .. (author and (", made by " .. author) or ""))
end)
Command("test", "Run the self test (optionally with an item link).", function(_, input)
  if Auctionary.Commands.Test ~= nil then
    -- Item links contain upper case letters, so the original text is passed
    Auctionary.Commands.Test(input)
  end
end)
Command("h, help", "Show this list.", function()
  for _, line in ipairs(help) do
    Message(line)
  end
end)

function Auctionary.Commands.Run(input)
  input = input or ""
  local args = Auctionary.Utilities.SplitCommand(input)
  local name = table.remove(args, 1)
  local run = name and commands[name]
  if run == nil then
    if name ~= nil then
      Message("Unknown command '" .. name .. "'")
    end
    commands.help()
    return
  end
  run(args, input)
end

function Auctionary.Commands.Register()
  SlashCmdList["AUCTIONARY2"] = Auctionary.Commands.Run
  SLASH_AUCTIONARY21 = "/aury"
  SLASH_AUCTIONARY22 = "/auctionary"
  SLASH_AUCTIONARY23 = "/auctionary2"
  SlashCmdList["AUCTIONARY2GOLD"] = function()
    Auctionary.Components.ShowGoldTracker()
  end
  SLASH_AUCTIONARY2GOLD1 = "/goldtracker"
end
