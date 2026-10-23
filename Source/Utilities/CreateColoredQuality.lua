local Auctionator = Auctionary

function Auctionator.Utilities.CreateColoredQuality(quality)
  local text = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
  return Auctionator.Compat.GetQualityColor(quality):WrapTextInColorCode(text)
end
