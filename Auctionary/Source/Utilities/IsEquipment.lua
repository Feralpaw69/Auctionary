local Auctionary = Auctionary

function Auctionary.Utilities.IsEquipment(classID)
  return classID == Auctionary.Constants.ItemClass.Weapon or classID == Auctionary.Constants.ItemClass.Armor
end
