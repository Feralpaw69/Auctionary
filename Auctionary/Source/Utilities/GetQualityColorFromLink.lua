local Auctionary = Auctionary

-- Returns the 8 hex digits (aarrggbb) of the link colour
function Auctionary.Utilities.GetQualityColorFromLink(itemLink)
  return string.match(itemLink, "|c(%x%x%x%x%x%x%x%x)|") or "ffffffff"
end
