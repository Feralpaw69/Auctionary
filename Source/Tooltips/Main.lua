local Auctionator = Auctionary

local L = Auctionator.Locales.Apply
local WHITE = Auctionator.Compat.Colors.WHITE_FONT_COLOR

-- Auctionator.Config.Options.VENDOR_TOOLTIPS: true if should show vendor tips
-- Auctionator.Config.Options.SHIFT_STACK_TOOLTIPS: true to show stack price when [shift] is down
-- Auctionator.Config.Options.AUCTION_TOOLTIPS: true if should show auction tips
function Auctionator.Tooltip.ShowTipWithPricing(tooltipFrame, itemLink, itemCount)
  if Auctionator.Database == nil or itemLink == nil then
    return
  end

  -- Not cached items are skipped: the tooltip would be gone (or showing
  -- something else) by the time the item data arrives
  local basicKey = Auctionator.Utilities.BasicDBKeyFromLink(itemLink)
  if basicKey == nil or not Auctionator.Compat.IsItemCached(basicKey) then
    return
  end

  Auctionator.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
    Auctionator.Tooltip.ShowTipWithPricingDBKey(tooltipFrame, dbKeys, itemLink, itemCount)
  end)
end

function Auctionator.Tooltip.ShowTipWithPricingDBKey(tooltipFrame, dbKeys, itemLink, itemCount)
  if #dbKeys == 0 then
    return
  end
  itemCount = tonumber(itemCount) or 1
  if itemCount < 1 then
    itemCount = 1
  end

  local showStackPrices = IsShiftKeyDown()
  if not Auctionator.Config.Get(Auctionator.Config.Options.SHIFT_STACK_TOOLTIPS) then
    showStackPrices = not IsShiftKeyDown()
  end
  local multiplier = showStackPrices and itemCount or 1

  local countString = ""
  if showStackPrices and itemCount > 1 then
    countString = Auctionator.Utilities.CreateCountString(itemCount)
  end

  local auctionPrice = Auctionator.Database:GetFirstPrice(dbKeys)
  local auctionAge, showAgeUnknown = nil, false
  if auctionPrice ~= nil then
    auctionPrice = auctionPrice * multiplier
    auctionAge = Auctionator.Database:GetPriceAge(dbKeys[1])
    if auctionAge == nil then
      showAgeUnknown = Auctionator.Database:GetPrice(dbKeys[1]) ~= nil
    end
  end

  local auctionMean
  if Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_MEAN_TOOLTIPS) then
    auctionMean = Auctionator.Database:GetScanAverage(
      dbKeys[1], Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_MEAN_DAYS_LIMIT)
    )
    if auctionMean ~= nil then
      auctionMean = auctionMean * multiplier
    end
  end

  local vendorPrice
  local cannotAuction = false
  local itemInfo = { GetItemInfo(itemLink) }
  if #itemInfo ~= 0 then
    cannotAuction = Auctionator.Utilities.IsBound(itemLink)
    if Auctionator.Utilities.IsVendorable(itemInfo) then
      vendorPrice = itemInfo[Auctionator.Constants.ITEM_INFO.SELL_PRICE] * multiplier
    end
  end

  if Auctionator.Debug.IsOn() then
    tooltipFrame:AddDoubleLine("DBKey", dbKeys[1])
  end

  if vendorPrice ~= nil then
    Auctionator.Tooltip.AddVendorTip(tooltipFrame, vendorPrice, countString)
  end
  Auctionator.Tooltip.AddAuctionTip(tooltipFrame, auctionPrice, countString, cannotAuction)
  if not cannotAuction then
    Auctionator.Tooltip.AddAuctionMeanTip(tooltipFrame, auctionMean, countString)
    Auctionator.Tooltip.AddAuctionAgeTip(tooltipFrame, auctionAge, auctionPrice, showAgeUnknown)
  end

  Auctionator.Tooltip.AddMatsCostTip(tooltipFrame, dbKeys[#dbKeys], countString, multiplier)
  Auctionator.Tooltip.AddReagentTips(tooltipFrame, itemLink, dbKeys[#dbKeys], countString, multiplier,
    Auctionator.Database:GetFirstPrice(dbKeys))
  pcall(Auctionator.Tooltip.AddOwnedTip, tooltipFrame, itemLink)

  tooltipFrame:Show()
end

local function ValueText(value, missing)
  local text = Auctionator.Utilities.CreatePaddedMoneyString(value)
  if missing then
    text = text .. " + ?"
  end
  return WHITE:WrapTextInColorCode(text)
end

-- How the destroy value compares to what the item costs on the auction
-- house: green when destroying brings more than buying costs, red when less
local function PercentText(value, missing, buyPrice)
  if buyPrice == nil or buyPrice <= 0 or value == nil or value <= 0 then
    return ""
  end
  local percent = math.floor(value / buyPrice * 100 + 0.5)
  local color = percent >= 100 and "ff20ff20" or "ffff4040"
  return " |c" .. color .. "(" .. (missing and ">" or "") .. percent .. "%)|r"
end

-- What the item brings when disenchanted, prospected or milled
-- unitBuyPrice is the current auction price of one item, if known
function Auctionator.Tooltip.AddReagentTips(tooltipFrame, itemLink, itemID, countString, multiplier, unitBuyPrice)
  local Options = Auctionator.Config.Options
  if Auctionator.Config.Get(Options.DISENCHANT_TOOLTIPS) then
    -- The tooltip itself may say that the item cannot be disenchanted
    Auctionator.Enchant.LearnFromTooltip(tooltipFrame, itemLink)
    local value, missing = Auctionator.Enchant.GetDisenchantAuctionPrice(itemLink)
    if value ~= nil then
      if value == 0 and missing then
        tooltipFrame:AddDoubleLine("Disenchant", WHITE:WrapTextInColorCode(L("UNKNOWN") .. "  "))
      else
        tooltipFrame:AddDoubleLine("Disenchant", ValueText(value, missing) .. PercentText(value, missing, unitBuyPrice))
      end
      if IsShiftKeyDown() then
        for _, line in ipairs(Auctionator.Enchant.GetDisenchantBreakdown(itemLink)) do
          tooltipFrame:AddLine(line, 0.8, 0.8, 0.8)
        end
      end
    end
  end
  if Auctionator.Config.Get(Options.PROSPECT_TOOLTIPS) then
    local value, missing = Auctionator.Prospect.GetProspectAuctionPrice(itemID)
    if value ~= nil and (value > 0 or missing) then
      tooltipFrame:AddDoubleLine("Prospect" .. countString, ValueText(value * multiplier, missing) .. PercentText(value, missing, unitBuyPrice))
    end
  end
  if Auctionator.Config.Get(Options.MILL_TOOLTIPS) then
    local value, missing = Auctionator.Mill.GetMillAuctionPrice(itemID)
    if value ~= nil and (value > 0 or missing) then
      tooltipFrame:AddDoubleLine("Mill" .. countString, ValueText(value * multiplier, missing) .. PercentText(value, missing, unitBuyPrice))
    end
  end
end

-- For crafted items whose recipe is known: what the reagents cost
function Auctionator.Tooltip.AddMatsCostTip(tooltipFrame, itemID, countString, multiplier)
  if not Auctionator.Config.Get(Auctionator.Config.Options.MATS_COST_TOOLTIPS) then
    return
  end
  local cost, missing, note = Auctionator.CraftingInfo.GetMatsCost(itemID)
  if cost == nil then
    return
  end

  local text
  if missing > 0 and cost == 0 then
    text = L("UNKNOWN") .. "  "
  else
    text = Auctionator.Utilities.CreatePaddedMoneyString(cost * multiplier)
    if missing > 0 then
      -- Some reagents have no known price; the real cost is higher
      text = text .. " + ?"
    end
  end
  tooltipFrame:AddDoubleLine("Mats Cost" .. countString, WHITE:WrapTextInColorCode(text))
  if note ~= nil then
    tooltipFrame:AddLine(note, 0.7, 0.7, 0.7)
  end
end

function Auctionator.Tooltip.AddVendorTip(tooltipFrame, vendorPrice, countString)
  if Auctionator.Config.Get(Auctionator.Config.Options.VENDOR_TOOLTIPS) and vendorPrice > 0 then
    -- Replaces the client's own sell price line (shown at merchants)
    if GameTooltip_ClearMoney and tooltipFrame == GameTooltip then
      GameTooltip_ClearMoney(tooltipFrame)
    end

    tooltipFrame:AddDoubleLine(
      L("VENDOR") .. countString,
      WHITE:WrapTextInColorCode(Auctionator.Utilities.CreatePaddedMoneyString(vendorPrice))
    )
  end
end

function Auctionator.Tooltip.AddAuctionTip(tooltipFrame, auctionPrice, countString, cannotAuction)
  if cannotAuction then
    return
  end
  if Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_TOOLTIPS) then
    if auctionPrice ~= nil then
      tooltipFrame:AddDoubleLine(
        L("AUCTION") .. countString,
        WHITE:WrapTextInColorCode(Auctionator.Utilities.CreatePaddedMoneyString(auctionPrice))
      )
    else
      tooltipFrame:AddDoubleLine(
        L("AUCTION") .. countString,
        WHITE:WrapTextInColorCode(L("UNKNOWN") .. "  ")
      )
    end
  end
end

function Auctionator.Tooltip.AddAuctionMeanTip(tooltipFrame, auctionMean, countString)
  if not Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_MEAN_TOOLTIPS) then
    return
  end

  if auctionMean ~= nil then
    tooltipFrame:AddDoubleLine(
      L("AUCTION_MEAN") .. countString,
      WHITE:WrapTextInColorCode(Auctionator.Utilities.CreatePaddedMoneyString(auctionMean))
    )
  end
end

function Auctionator.Tooltip.AddAuctionAgeTip(tooltipFrame, auctionAge, auctionPrice, showUnknown)
  if not Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_AGE_TOOLTIPS) then
    return
  end

  if auctionAge ~= nil then
    tooltipFrame:AddDoubleLine(
      AUCTIONARY_L_AUCTION_AGE,
      WHITE:WrapTextInColorCode(AUCTIONARY_L_X_DAYS:format(tostring(auctionAge)))
    )
  elseif auctionPrice ~= nil and showUnknown then
    tooltipFrame:AddDoubleLine(AUCTIONARY_L_AUCTION_AGE, AUCTIONARY_L_UNKNOWN)
  end
end

-- The original addon ships with the average price and the price age switched
-- off. Here both start switched on; done once so later changes by the user
-- are kept. (/aury config auction_mean_tooltips toggles it.)
function Auctionator.Tooltip.Initialize()
  if Auctionator.SavedState ~= nil and not Auctionator.SavedState.TooltipDefaultsApplied then
    Auctionator.SavedState.TooltipDefaultsApplied = true
    Auctionator.Config.Set(Auctionator.Config.Options.AUCTION_MEAN_TOOLTIPS, true)
    Auctionator.Config.Set(Auctionator.Config.Options.AUCTION_AGE_TOOLTIPS, true)
  end
end


---- How many of an item the characters of this account own (bags and bank)

-- Items of this character: SavedState.Inventory[realm][character][itemID] = count
local function OwnInventory()
  local state = Auctionator.SavedState
  local realm, character = GetRealmName(), UnitName("player")
  if state == nil or realm == nil or character == nil then
    return nil
  end
  state.Inventory = state.Inventory or {}
  state.Inventory[realm] = state.Inventory[realm] or {}
  state.Inventory[realm][character] = state.Inventory[realm][character] or {}
  return state.Inventory[realm][character], state.Inventory[realm], character
end

-- The bank bags only answer while the bank is open; what was seen there
-- before is kept and counted with GetItemCount, which knows the bank anyway
local function UpdateInventory()
  local own = OwnInventory()
  if own == nil then
    return
  end
  local ids = {}
  for itemID in pairs(own) do
    ids[itemID] = true
  end
  for bag = -1, 11 do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      local itemID = link and tonumber(link:match("item:(%d+)"))
      if itemID ~= nil then
        ids[itemID] = true
      end
    end
  end
  for itemID in pairs(ids) do
    local count = GetItemCount(itemID, true) or 0
    own[itemID] = count > 0 and count or nil
  end
end

local inventoryFrame = CreateFrame("Frame")
local pending
inventoryFrame:RegisterEvent("BAG_UPDATE")
inventoryFrame:RegisterEvent("BANKFRAME_OPENED")
inventoryFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
inventoryFrame:RegisterEvent("PLAYER_LOGOUT")
inventoryFrame:SetScript("OnEvent", function(_, eventName)
  if eventName == "PLAYER_LOGOUT" then
    pcall(UpdateInventory)
  else
    -- Bag events come often (looting, fighting): one update at most every
    -- few seconds, never during a fight
    pending = pending or 5
  end
end)
inventoryFrame:SetScript("OnUpdate", function(_, elapsed)
  if pending ~= nil then
    pending = pending - (elapsed or 0)
    if pending <= 0 then
      if InCombatLockdown ~= nil and InCombatLockdown() then
        pending = 2
        return
      end
      pending = nil
      pcall(UpdateInventory)
    end
  end
end)

-- Shown when the account owns more than one of the item (on this realm)
-- Altoholic shows the same information; with it enabled ours stays away
local function AltoholicActive()
  if IsAddOnLoaded ~= nil and IsAddOnLoaded("Altoholic") then
    return true
  end
  if GetAddOnInfo ~= nil then
    local name, _, _, enabled = GetAddOnInfo("Altoholic")
    return name ~= nil and enabled ~= nil and enabled ~= false and enabled ~= 0
  end
  return false
end

function Auctionator.Tooltip.AddOwnedTip(tooltipFrame, itemLink)
  if AltoholicActive() then
    return
  end
  -- Altoholic shows the same counts (and more) in the tooltip itself
  if IsAddOnLoaded ~= nil and IsAddOnLoaded("Altoholic") then
    return
  end
  local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
  local _, realmData, character = OwnInventory()
  if itemID == nil or realmData == nil then
    return
  end
  local total, owners = 0, {}
  for name, items in pairs(realmData) do
    local count
    if name == character then
      count = GetItemCount(itemID, true) or 0
    else
      count = type(items) == "table" and tonumber(items[itemID]) or 0
    end
    if count > 0 then
      total = total + count
      table.insert(owners, { name = name, count = count })
    end
  end
  if total <= 1 then
    return
  end
  tooltipFrame:AddDoubleLine("You own", WHITE:WrapTextInColorCode(total .. "  "))
  if #owners > 1 or owners[1].name ~= character then
    table.sort(owners, function(a, b)
      return a.count > b.count
    end)
    for _, owner in ipairs(owners) do
      tooltipFrame:AddDoubleLine("  " .. owner.name, WHITE:WrapTextInColorCode(owner.count .. "  "), 0.6, 0.6, 0.6)
    end
  end
end
