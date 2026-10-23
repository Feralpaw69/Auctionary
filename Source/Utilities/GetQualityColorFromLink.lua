local Auctionator = Auctionary

-- Returns the 8 hex digits (aarrggbb) of the link colour
function Auctionator.Utilities.GetQualityColorFromLink(itemLink)
  return string.match(itemLink, "|c(%x%x%x%x%x%x%x%x)|") or "ffffffff"
end
