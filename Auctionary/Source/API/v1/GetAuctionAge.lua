local Auctionary = Auctionary

-- Returns the number of days since the item was seen in the auction house,
-- except if the number of days exceeds 21, then it returns nil. It will return
-- nil if there is no auction ever seen in the auction house for the item.
function Auctionary.API.v1.GetAuctionAgeByItemID(callerID, itemID)
  Auctionary.API.InternalVerifyID(callerID)

  if type(itemID) ~= "number" then
    Auctionary.API.ComposeError(
      callerID,
      "Usage Auctionary.API.v1.GetAuctionAgeByItemID(string, number)"
    )
  end

  if Auctionary.Database == nil then
    return nil
  end

  return Auctionary.Database:GetPriceAge(tostring(itemID))
end

function Auctionary.API.v1.GetAuctionAgeByItemLink(callerID, itemLink)
  Auctionary.API.InternalVerifyID(callerID)

  if type(itemLink) ~= "string" then
    Auctionary.API.ComposeError(
      callerID,
      "Usage Auctionary.API.v1.GetAuctionAgeByItemLink(string, string)"
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
    if #dbKeys > 2 then
      return Auctionary.Database:GetPriceAge(dbKeys[1]) or Auctionary.Database:GetPriceAge(dbKeys[2])
    else
      return Auctionary.Database:GetPriceAge(dbKeys[1])
    end
  else
    return Auctionary.Database:GetPriceAge(
      Auctionary.Utilities.BasicDBKeyFromLink(itemLink)
    )
  end
end
