local Auctionary = Auctionary

function Auctionary.API.v1.GetDisenchantPriceByItemID(callerID, itemID)
  Auctionary.API.InternalVerifyID(callerID)

  if type(itemID) ~= "number" then
    Auctionary.API.ComposeError(
      callerID,
      "Usage Auctionary.API.v1.GetAuctionPriceByItemID(string, number)"
    )
  end

  local itemInfo = { GetItemInfo(itemID) }
  local itemLink = itemInfo[2]

  if itemLink ~= nil then
    return Auctionary.Enchant.GetDisenchantAuctionPrice(itemLink)
  else
    return nil
  end
end

function Auctionary.API.v1.GetDisenchantPriceByItemLink(callerID, itemLink)
  Auctionary.API.InternalVerifyID(callerID)

  if type(itemLink) ~= "string" then
    Auctionary.API.ComposeError(
      callerID,
      "Usage Auctionary.API.v1.GetAuctionPriceByItemLink(string, string)"
    )
  end

  local itemInfo = { GetItemInfo(itemLink) }

  if #itemInfo > 0 then
    return Auctionary.Enchant.GetDisenchantAuctionPrice(itemLink)
  else
    return nil
  end
end
