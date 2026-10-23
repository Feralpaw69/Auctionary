local Auctionator = Auctionary

-- itemInfo: table of the GetItemInfo return values
function Auctionator.Utilities.IsVendorable(itemInfo)
  local sellPrice = itemInfo[Auctionator.Constants.ITEM_INFO.SELL_PRICE]
  local rarity = itemInfo[Auctionator.Constants.ITEM_INFO.RARITY]
  local isArtifact = rarity == Auctionator.Constants.ItemQuality.Artifact
  local isLegendary = rarity == Auctionator.Constants.ItemQuality.Legendary

  return sellPrice ~= nil and sellPrice > 0 and not isArtifact and not isLegendary
end
