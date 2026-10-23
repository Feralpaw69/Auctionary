local Auctionator = Auctionary

-- Additions to the original API. Other addons use them like this:
--   Auctionary.API.v1.GetAuctionPriceByItemID("MyAddon", 36912)

-- Average over all scans of the last days (default: the tooltip setting)
function Auctionator.API.v1.GetAuctionAverageByItemID(callerID, itemID, days)
  Auctionator.API.InternalVerifyID(callerID)
  if type(itemID) ~= "number" then
    Auctionator.API.ComposeError(callerID, "Usage Auctionary.API.v1.GetAuctionAverageByItemID(string, number[, number])")
  end
  if Auctionator.Database == nil then
    return nil
  end
  return Auctionator.Database:GetScanAverage(
    tostring(itemID), days or Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_MEAN_DAYS_LIMIT)
  )
end

-- Cost of the reagents of a crafted item; second value: reagents without a price
function Auctionator.API.v1.GetMatsCostByItemID(callerID, itemID)
  Auctionator.API.InternalVerifyID(callerID)
  if type(itemID) ~= "number" then
    Auctionator.API.ComposeError(callerID, "Usage Auctionary.API.v1.GetMatsCostByItemID(string, number)")
  end
  local cost, missing = Auctionator.CraftingInfo.GetMatsCost(itemID)
  return cost, missing
end
