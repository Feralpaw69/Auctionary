local Auctionary = Auctionary

Auctionary.Groups.Constants = {
  IsWrath = true,
  IsCata = false,
  IsVanilla = false,
  IsRetail = false,
}

Auctionary.Groups.Constants.Events = {
  "BagCacheUpdated",
  "ViewGroupToggled",
  "ViewComplete",
  "BagCacheOff",
  "BagCacheOn",
  "BagUse.BagItemClicked",
  "BagUse.AddToDefaultGroup",
  "Customise.EditMade",
}

-- Backpack and the four bag slots (the keyring, -2, can't hold auctionable items)
Auctionary.Groups.Constants.BagIDs = {0, 1, 2, 3, 4}

Auctionary.Groups.Constants.ValidItemClassIDs = Auctionary.Constants.ValidItemClassIDs

Auctionary.Groups.Constants.GroupType = {
  List = 1,
  ClassID = 2,
}

-- Filled by Auctionary.Groups.Initialize, the class names aren't available
-- until the player has logged in
Auctionary.Groups.Constants.DefaultGroups = {}
