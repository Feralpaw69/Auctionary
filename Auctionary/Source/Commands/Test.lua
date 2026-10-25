-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

-- /aury test [item link]
-- Checks the parts of the addon that work without the auction house window.
-- Nothing is written to the real price database or shopping lists.
local function Report(name, ok, detail)
  local status
  if ok then
    status = Auctionary.Compat.Colors.GREEN_FONT_COLOR:WrapTextInColorCode("OK")
  else
    status = Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode("FAILED")
  end
  Auctionary.Utilities.Message(status .. "  " .. name .. (detail and (" - " .. tostring(detail)) or ""))
end

local function Check(name, func)
  local ok, result, detail = pcall(func)
  if not ok then
    Report(name, false, result)
  else
    Report(name, result, detail)
  end
  return ok and result
end

function Auctionary.Commands.Test(input)
  if input and Auctionary.Commands.TestAH(input) then
    return
  end

  local itemLink = input and input:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")

  Auctionary.Utilities.Message("Self test, version " .. tostring(Auctionary.State.CurrentVersion)
    .. ", locale " .. GetLocale() .. ", database \"" .. tostring(Auctionary.State.CurrentRealm) .. "\"")

  Check("Locale texts", function()
    return type(AUCTIONARY2_L_TAB_SHOPPING) == "string", AUCTIONARY2_L_TAB_SHOPPING
  end)

  Check("Settings", function()
    local option = Auctionary.Config.Options.AUCTION_DURATION
    return type(AUCTIONARY2_CONFIG) == "table" and Auctionary.Config.Get(option) ~= nil,
      "auction_duration = " .. tostring(Auctionary.Config.Get(option))
  end)

  Check("Price database", function()
    local db = Auctionary.CreatePriceDatabase({})
    db:SetPrice("test", 12345, 7)
    -- reading applies the queued price, as the next frame would
    local first = db:GetPrice("test")
    db:SetPrice("test", 12000, 9)
    local price = db:GetPrice("test")
    local history = db:GetPriceHistory("test")
    local stored = db.db["test"]
    return first == 12345 and price == 12000 and #history == 1 and history[1].maxSeen == 12345
      and history[1].minSeen == 12000 and history[1].available == 9
      and type(stored) == "string" and db:GetPriceAge("test") == 0,
      tostring(stored)
  end)

  Check("Shopping lists", function()
    local manager = Auctionary.Shopping.ListManager
    local name = manager:GetUnusedName("Selftest")
    manager:Create(name, true)
    local list = manager:GetByName(name)
    list:InsertItem("\"Saronitbarren\";;;;;;;;;;;;;20")
    local search = Auctionary.Search.SplitAdvancedSearch(list:GetItemByIndex(1))
    local text = Auctionary.Search.PrettifySearchString(list:GetItemByIndex(1))
    local found = manager:GetIndexForName(name) ~= nil
    manager:Delete(name)
    return found and manager:GetIndexForName(name) == nil
      and search.isExact and search.searchString == "Saronitbarren" and search.quantity == 20, text
  end)

  Check("Money display", function()
    local text = Auctionary.Compat.GetMoneyString(1234567, true)
    return text:find("123") ~= nil, text .. "   " .. Auctionary.Utilities.CreatePaddedMoneyString(1234567)
  end)

  Check("Timer", function()
    Auctionary.Compat.After(0.5, function()
      Report("Timer (0.5 s)", true)
    end)
    return true, "started, a second line follows"
  end)

  Check("Auction house categories", function()
    local classes = { GetAuctionItemClasses() }
    local constants = Auctionary.Constants.ItemClass
    return #classes >= 12, #classes .. ": 1=" .. tostring(classes[constants.Weapon])
      .. ", 2=" .. tostring(classes[constants.Armor])
      .. ", 6=" .. tostring(classes[constants.Tradegoods])
      .. ", 10=" .. tostring(classes[constants.Gem])
      .. ", 12=" .. tostring(classes[constants.Questitem])
  end)

  Check("Hidden tooltip", function()
    local tooltip = Auctionary.Compat.GetScanTooltip()
    tooltip:SetHyperlink("item:6948:0:0:0:0:0:0:0") -- Ruhestein
    return tooltip:NumLines() > 0, tooltip:NumLines() .. " lines, Hearthstone bound: " .. tostring(Auctionary.Utilities.IsBound(6948))
  end)

  if itemLink then
    Check("Item " .. itemLink, function()
      local info = { GetItemInfo(itemLink) }
      local keys
      Auctionary.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
        keys = dbKeys
      end)
      return #info >= 11 and keys ~= nil and #keys > 0,
        "Keys: " .. (keys and table.concat(keys, ", ") or "?")
        .. "; class: " .. tostring(Auctionary.Compat.GetItemClassID(itemLink))
        .. " (" .. tostring(info[Auctionary.Constants.ITEM_INFO.TYPE]) .. ")"
        .. "; vendor: " .. Auctionary.Compat.GetMoneyString(info[Auctionary.Constants.ITEM_INFO.SELL_PRICE] or 0)
        .. "; bound: " .. tostring(Auctionary.Utilities.IsBound(itemLink))
    end)
  else
    Auctionary.Utilities.Message("Tip: type /aury test and shift-click an item to check it as well.")
    Auctionary.Utilities.Message("At the auction house: /aury test ah, /aury test search <name>, /aury test scan, /aury test stop, /aury test owned, /aury test price <item>")
  end
end
