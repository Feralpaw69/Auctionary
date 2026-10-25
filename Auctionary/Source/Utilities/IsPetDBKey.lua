local Auctionary = Auctionary

function Auctionary.Utilities.IsPetDBKey(itemKey)
  return string.sub(itemKey,1,1) == "p"
end
