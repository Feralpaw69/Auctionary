local Auctionary = Auctionary

function Auctionary.Utilities.RemoveTextColor(text)
  return gsub(gsub(text, "|c........", ""), "|r", "")
end
