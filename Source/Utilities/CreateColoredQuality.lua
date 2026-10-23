local Auctionary = Auctionary

function Auctionary.Utilities.CreateColoredQuality(quality)
  local text = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
  return Auctionary.Compat.GetQualityColor(quality):WrapTextInColorCode(text)
end
