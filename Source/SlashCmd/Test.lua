local Auctionator = Auctionary

-- /aury test [item link]
-- Checks the parts of the addon that work without the auction house window.
-- Nothing is written to the real price database or shopping lists.
local function Report(name, ok, detail)
  local status
  if ok then
    status = Auctionator.Compat.Colors.GREEN_FONT_COLOR:WrapTextInColorCode("OK")
  else
    status = Auctionator.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode("FAILED")
  end
  Auctionator.Utilities.Message(status .. "  " .. name .. (detail and (" - " .. tostring(detail)) or ""))
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

function Auctionator.SlashCmd.Test(input)
  if input and Auctionator.SlashCmd.TestAH(input) then
    return
  end

  local itemLink = input and input:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")

  Auctionator.Utilities.Message("Self test, version " .. tostring(Auctionator.State.CurrentVersion)
    .. ", locale " .. GetLocale() .. ", database \"" .. tostring(Auctionator.State.CurrentRealm) .. "\"")

  Check("Locale texts", function()
    return type(AUCTIONARY_L_SHOPPING_TAB) == "string", AUCTIONARY_L_SHOPPING_TAB
  end)

  Check("Settings", function()
    local option = Auctionator.Config.Options.AUCTION_DURATION
    return type(AUCTIONARY_CONFIG) == "table" and Auctionator.Config.Get(option) ~= nil,
      "auction_duration = " .. tostring(Auctionator.Config.Get(option))
  end)

  Check("Price database", function()
    local db = Auctionator.Compat.CreateAndInitFromMixin(Auctionator.DatabaseMixin, {})
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
    local data
    local manager = Auctionator.Compat.CreateAndInitFromMixin(
      AuctionaryShoppingListManagerMixin,
      function() return data end,
      function(newVal) data = newVal end
    )
    manager:Create("Test B")
    manager:Create("Test A")
    local list = manager:GetByName("Test A")
    list:InsertItem("\"Saronitbarren\";;;;;;;;;;;;;20")
    local search = Auctionator.Search.SplitAdvancedSearch(list:GetItemByIndex(1))
    return manager:GetCount() == 2 and manager:GetByIndex(1):GetName() == "Test A"
      and search.isExact and search.searchString == "Saronitbarren" and search.quantity == 20,
      Auctionator.Search.PrettifySearchString(list:GetItemByIndex(1))
  end)

  Check("Money display", function()
    local text = Auctionator.Compat.GetMoneyString(1234567, true)
    return text:find("123") ~= nil, text .. "   " .. Auctionator.Utilities.CreatePaddedMoneyString(1234567)
  end)

  Check("Timer", function()
    Auctionator.Compat.After(0.5, function()
      Report("Timer (0.5 s)", true)
    end)
    return true, "started, a second line follows"
  end)

  Check("Auction house categories", function()
    local classes = { GetAuctionItemClasses() }
    local constants = Auctionator.Constants.ItemClass
    return #classes >= 12, #classes .. ": 1=" .. tostring(classes[constants.Weapon])
      .. ", 2=" .. tostring(classes[constants.Armor])
      .. ", 6=" .. tostring(classes[constants.Tradegoods])
      .. ", 10=" .. tostring(classes[constants.Gem])
      .. ", 12=" .. tostring(classes[constants.Questitem])
  end)

  Check("Hidden tooltip", function()
    local tooltip = Auctionator.Compat.GetScanTooltip()
    tooltip:SetHyperlink("item:6948:0:0:0:0:0:0:0") -- Ruhestein
    return tooltip:NumLines() > 0, tooltip:NumLines() .. " lines, Hearthstone bound: " .. tostring(Auctionator.Utilities.IsBound(6948))
  end)

  if itemLink then
    Check("Item " .. itemLink, function()
      local info = { GetItemInfo(itemLink) }
      local keys
      Auctionator.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
        keys = dbKeys
      end)
      return #info >= 11 and keys ~= nil and #keys > 0,
        "Keys: " .. (keys and table.concat(keys, ", ") or "?")
        .. "; class: " .. tostring(Auctionator.Compat.GetItemClassID(itemLink))
        .. " (" .. tostring(info[Auctionator.Constants.ITEM_INFO.TYPE]) .. ")"
        .. "; vendor: " .. Auctionator.Compat.GetMoneyString(info[Auctionator.Constants.ITEM_INFO.SELL_PRICE] or 0)
        .. "; bound: " .. tostring(Auctionator.Utilities.IsBound(itemLink))
    end)
  else
    Auctionator.Utilities.Message("Tip: type /aury test and shift-click an item to check it as well.")
    Auctionator.Utilities.Message("At the auction house: /aury test ah, /aury test search <name>, /aury test scan, /aury test stop, /aury test owned, /aury test price <item>")
  end
end
