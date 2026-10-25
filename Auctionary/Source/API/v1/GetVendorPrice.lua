local Auctionary = Auctionary

function Auctionary.API.v1.GetVendorPriceByItemID(callerID, itemID)
  Auctionary.API.InternalVerifyID(callerID)

  if type(itemID) ~= "number" then
    Auctionary.API.ComposeError(
      callerID,
      "Usage Auctionary.API.v1.GetVendorPriceByItemID(string, number)"
    )
  end

  return (AUCTIONARY_VENDOR_PRICE_CACHE or {})[tostring(itemID)]
end

function Auctionary.API.v1.GetVendorPriceByItemLink(callerID, itemLink)
  Auctionary.API.InternalVerifyID(callerID)

  if type(itemLink) ~= "string" then
    Auctionary.API.ComposeError(
      callerID,
      "Usage Auctionary.API.v1.GetVendorPriceByItemLink(string, string)"
    )
  end

  local dbKeys = nil
  -- Use that the callback is called immediately (and populates dbKeys) if the
  -- item info for item levels is available now.
  Auctionary.Utilities.DBKeyFromLink(itemLink, function(dbKeysCallback)
    dbKeys = dbKeysCallback
  end)

  if dbKeys then
    for _, key in ipairs(dbKeys) do
      if (AUCTIONARY_VENDOR_PRICE_CACHE or {})[key] then
        return (AUCTIONARY_VENDOR_PRICE_CACHE or {})[key]
      end
    end
  else
    return (AUCTIONARY_VENDOR_PRICE_CACHE or {})[Auctionary.Utilities.BasicDBKeyFromLink(itemLink)]
  end
end
