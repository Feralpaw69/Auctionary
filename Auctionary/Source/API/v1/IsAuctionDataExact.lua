local Auctionary = Auctionary

function Auctionary.API.v1.IsAuctionDataExactByItemID(callerID, itemID)
  Auctionary.API.InternalVerifyID(callerID)

  if type(itemID) ~= "number" then
    Auctionary.API.ComposeError(
      callerID,
      "Usage Auctionary.API.v1.IsAuctionDataExactByItemID(string, number)"
    )
  end

  if Auctionary.Database == nil then
    return nil
  end

  return Auctionary.Database:GetPrice(tostring(itemID)) ~= nil
end

function Auctionary.API.v1.IsAuctionDataExactByItemLink(callerID, itemLink)
  Auctionary.API.InternalVerifyID(callerID)

  if type(itemLink) ~= "string" then
    Auctionary.API.ComposeError(
      callerID,
      "Usage Auctionary.API.v1.IsAuctionDataExactByItemLink(string, string)"
    )
  end

  if Auctionary.Database == nil then
    return false
  end

  local dbKeys = nil
  -- Use that the callback is called immediately (and populates dbKeys) if the
  -- item info for item levels is available now.
  Auctionary.Utilities.DBKeyFromLink(itemLink, function(dbKeysCallback)
    dbKeys = dbKeysCallback
  end)

  if dbKeys then
    if #dbKeys > 2 then
      return Auctionary.Database:GetPrice(dbKeys[1]) ~= nil or Auctionary.Database:GetPrice(dbKeys[2]) ~= nil
    else
      return Auctionary.Database:GetPrice(dbKeys[1]) ~= nil
    end
  else
    return Auctionary.Database:GetPrice(
      Auctionary.Utilities.BasicDBKeyFromLink(itemLink)
    ) ~= nil
  end
end
