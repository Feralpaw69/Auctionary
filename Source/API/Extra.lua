local Auctionary = Auctionary

-- Additions to the original API. Other addons use them like this:
--   Auctionary.API.v1.GetAuctionPriceByItemID("MyAddon", 36912)

-- Average over all scans of the last days (default: the tooltip setting)
function Auctionary.API.v1.GetAuctionAverageByItemID(callerID, itemID, days)
  Auctionary.API.InternalVerifyID(callerID)
  if type(itemID) ~= "number" then
    Auctionary.API.ComposeError(callerID, "Usage Auctionary.API.v1.GetAuctionAverageByItemID(string, number[, number])")
  end
  if Auctionary.Database == nil then
    return nil
  end
  return Auctionary.Database:GetScanAverage(
    tostring(itemID), days or Auctionary.Config.Get(Auctionary.Config.Options.AUCTION_MEAN_DAYS_LIMIT)
  )
end

-- Cost of the reagents of a crafted item; second value: reagents without a price
function Auctionary.API.v1.GetMatsCostByItemID(callerID, itemID)
  Auctionary.API.InternalVerifyID(callerID)
  if type(itemID) ~= "number" then
    Auctionary.API.ComposeError(callerID, "Usage Auctionary.API.v1.GetMatsCostByItemID(string, number)")
  end
  local cost, missing = Auctionary.CraftingInfo.GetMatsCost(itemID)
  return cost, missing
end
