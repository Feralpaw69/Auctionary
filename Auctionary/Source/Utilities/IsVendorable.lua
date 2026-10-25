local Auctionary = Auctionary

-- itemInfo: table of the GetItemInfo return values
function Auctionary.Utilities.IsVendorable(itemInfo)
  local sellPrice = itemInfo[Auctionary.Constants.ITEM_INFO.SELL_PRICE]
  local rarity = itemInfo[Auctionary.Constants.ITEM_INFO.RARITY]
  local isArtifact = rarity == Auctionary.Constants.ItemQuality.Artifact
  local isLegendary = rarity == Auctionary.Constants.ItemQuality.Legendary

  return sellPrice ~= nil and sellPrice > 0 and not isArtifact and not isLegendary
end
