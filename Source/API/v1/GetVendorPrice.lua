local Auctionator = Auctionary

function Auctionator.API.v1.GetVendorPriceByItemID(callerID, itemID)
  Auctionator.API.InternalVerifyID(callerID)

  if type(itemID) ~= "number" then
    Auctionator.API.ComposeError(
      callerID,
      "Usage Auctionator.API.v1.GetVendorPriceByItemID(string, number)"
    )
  end

  return (AUCTIONARY_VENDOR_PRICE_CACHE or {})[tostring(itemID)]
end

function Auctionator.API.v1.GetVendorPriceByItemLink(callerID, itemLink)
  Auctionator.API.InternalVerifyID(callerID)

  if type(itemLink) ~= "string" then
    Auctionator.API.ComposeError(
      callerID,
      "Usage Auctionator.API.v1.GetVendorPriceByItemLink(string, string)"
    )
  end

  local dbKeys = nil
  -- Use that the callback is called immediately (and populates dbKeys) if the
  -- item info for item levels is available now.
  Auctionator.Utilities.DBKeyFromLink(itemLink, function(dbKeysCallback)
    dbKeys = dbKeysCallback
  end)

  if dbKeys then
    for _, key in ipairs(dbKeys) do
      if (AUCTIONARY_VENDOR_PRICE_CACHE or {})[key] then
        return (AUCTIONARY_VENDOR_PRICE_CACHE or {})[key]
      end
    end
  else
    return (AUCTIONARY_VENDOR_PRICE_CACHE or {})[Auctionator.Utilities.BasicDBKeyFromLink(itemLink)]
  end
end
