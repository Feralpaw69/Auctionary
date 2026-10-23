local Auctionator = Auctionary

function Auctionator.Utilities.RemoveTextColor(text)
  return gsub(gsub(text, "|c........", ""), "|r", "")
end
