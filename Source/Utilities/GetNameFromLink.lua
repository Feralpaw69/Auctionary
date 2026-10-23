local Auctionary = Auctionary

function Auctionary.Utilities.GetNameFromLink(itemLink)
  return string.match(itemLink, "h%[(.*)%]|h")
end
