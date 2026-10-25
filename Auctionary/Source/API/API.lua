-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Prices for other addons
--   Auctionary2.API.v1.GetAuctionPriceByItemID("MyAddon", 36912)
-- The first argument names the calling addon (for error messages).

local API = Auctionary.API.v1

local function Check(callerID, value, kind, usage)
  if type(callerID) ~= "string" or callerID == "" then
    error("Auctionary 2.0 API: give the name of your addon as the first argument", 3)
  end
  if type(value) ~= kind then
    error("Auctionary 2.0 API (" .. callerID .. "): usage " .. usage, 3)
  end
end

-- Price keys of a link (most specific first), when the item data is there
local function KeysOf(itemLink)
  local keys
  Auctionary.Utilities.DBKeyFromLink(itemLink, function(found)
    keys = found
  end)
  return keys or { Auctionary.Utilities.BasicDBKeyFromLink(itemLink) }
end

local function FirstOf(keys, lookup)
  for _, key in ipairs(keys) do
    local value = lookup(key)
    if value ~= nil then
      return value
    end
  end
end

local function Price(key) return Auctionary.Database and Auctionary.Database:GetPrice(key) or nil end
local function Age(key) return Auctionary.Database and Auctionary.Database:GetPriceAge(key) or nil end
local function Vendor(key) return (AUCTIONARY2_VENDOR_PRICE_CACHE or {})[key] end

function API.GetAuctionPriceByItemID(callerID, itemID)
  Check(callerID, itemID, "number", "GetAuctionPriceByItemID(addonName, itemID)")
  return Price(tostring(itemID))
end

function API.GetAuctionPriceByItemLink(callerID, itemLink)
  Check(callerID, itemLink, "string", "GetAuctionPriceByItemLink(addonName, itemLink)")
  return FirstOf(KeysOf(itemLink), Price)
end

-- Days since the item was last seen on the auction house
function API.GetAuctionAgeByItemID(callerID, itemID)
  Check(callerID, itemID, "number", "GetAuctionAgeByItemID(addonName, itemID)")
  return Age(tostring(itemID))
end

function API.GetAuctionAgeByItemLink(callerID, itemLink)
  Check(callerID, itemLink, "string", "GetAuctionAgeByItemLink(addonName, itemLink)")
  return FirstOf(KeysOf(itemLink), Age)
end

function API.IsAuctionDataExactByItemID(callerID, itemID)
  return API.GetAuctionPriceByItemID(callerID, itemID) ~= nil
end

function API.IsAuctionDataExactByItemLink(callerID, itemLink)
  return API.GetAuctionPriceByItemLink(callerID, itemLink) ~= nil
end

function API.GetVendorPriceByItemID(callerID, itemID)
  Check(callerID, itemID, "number", "GetVendorPriceByItemID(addonName, itemID)")
  return Vendor(tostring(itemID))
end

function API.GetVendorPriceByItemLink(callerID, itemLink)
  Check(callerID, itemLink, "string", "GetVendorPriceByItemLink(addonName, itemLink)")
  return FirstOf(KeysOf(itemLink), Vendor)
end

function API.GetDisenchantPriceByItemID(callerID, itemID)
  Check(callerID, itemID, "number", "GetDisenchantPriceByItemID(addonName, itemID)")
  local _, itemLink = GetItemInfo(itemID)
  if itemLink == nil then
    return nil
  end
  return Auctionary.Enchant.GetDisenchantAuctionPrice(itemLink)
end

function API.GetDisenchantPriceByItemLink(callerID, itemLink)
  Check(callerID, itemLink, "string", "GetDisenchantPriceByItemLink(addonName, itemLink)")
  if GetItemInfo(itemLink) == nil then
    return nil
  end
  return Auctionary.Enchant.GetDisenchantAuctionPrice(itemLink)
end

-- Average of the daily prices over the last days (default: tooltip setting)
function API.GetAuctionAverageByItemID(callerID, itemID, days)
  Check(callerID, itemID, "number", "GetAuctionAverageByItemID(addonName, itemID[, days])")
  if Auctionary.Database == nil then
    return nil
  end
  return Auctionary.Database:GetScanAverage(
    tostring(itemID), days or Auctionary.Config.Get(Auctionary.Config.Options.AUCTION_MEAN_DAYS_LIMIT))
end

-- Cost of the reagents of a crafted item; second value: reagents without a price
function API.GetMatsCostByItemID(callerID, itemID)
  Check(callerID, itemID, "number", "GetMatsCostByItemID(addonName, itemID)")
  return Auctionary.CraftingInfo.GetMatsCost(itemID)
end
