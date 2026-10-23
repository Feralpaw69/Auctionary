local Auctionator = Auctionary

Auctionator.Groups.Constants = {
  IsWrath = true,
  IsCata = false,
  IsVanilla = false,
  IsRetail = false,
}

Auctionator.Groups.Constants.Events = {
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
Auctionator.Groups.Constants.BagIDs = {0, 1, 2, 3, 4}

Auctionator.Groups.Constants.ValidItemClassIDs = Auctionator.Constants.ValidItemClassIDs

Auctionator.Groups.Constants.GroupType = {
  List = 1,
  ClassID = 2,
}

-- Filled by Auctionator.Groups.Initialize, the class names aren't available
-- until the player has logged in
Auctionator.Groups.Constants.DefaultGroups = {}
