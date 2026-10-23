local Auctionator = Auctionary

function Auctionator.Utilities.IsEquipment(classID)
  return classID == Auctionator.Constants.ItemClass.Weapon or classID == Auctionator.Constants.ItemClass.Armor
end
