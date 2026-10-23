local Auctionary = Auctionary

function Auctionary.Utilities.IsPetLink(itemLink)
  return itemLink:match("battlepet:") ~= nil
end
