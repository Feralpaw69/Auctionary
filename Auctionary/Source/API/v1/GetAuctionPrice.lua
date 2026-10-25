local Auctionary = Auctionary

function Auctionary.API.v1.GetAuctionPriceByItemID(callerID, itemID)
  Auctionary.API.InternalVerifyID(callerID)

  if type(itemID) ~= "number" then
    Auctionary.API.ComposeError(
      callerID,
      "Usage Auctionary.API.v1.GetAuctionPriceByItemID(string, number)"
    )
  end

  if Auctionary.Database == nil then
    return nil
  end

  return Auctionary.Database:GetPrice(tostring(itemID))
end

function Auctionary.API.v1.GetAuctionPriceByItemLink(callerID, itemLink)
  Auctionary.API.InternalVerifyID(callerID)

  if type(itemLink) ~= "string" then
    Auctionary.API.ComposeError(
      callerID,
      "Usage Auctionary.API.v1.GetAuctionPriceByItemLink(string, string)"
    )
  end

  if Auctionary.Database == nil then
    return nil
  end

  local dbKeys = nil
  -- Use that the callback is called immediately (and populates dbKeys) if the
  -- item info for item levels is available now.
  Auctionary.Utilities.DBKeyFromLink(itemLink, function(dbKeysCallback)
    dbKeys = dbKeysCallback
  end)

  if dbKeys then
    return Auctionary.Database:GetFirstPrice(dbKeys)
  else
    return Auctionary.Database:GetPrice(
      Auctionary.Utilities.BasicDBKeyFromLink(itemLink)
    )
  end
end
