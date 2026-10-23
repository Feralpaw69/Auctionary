local Auctionator = Auctionary

-- Positions in the return values of the 3.3.5 GetItemInfo:
--   name, link, quality, itemLevel, requiredLevel, type, subType, maxStack,
--   equipSlot, texture, vendorPrice
-- There is no class ID, bind type or expansion in this client. Use
-- Auctionator.Compat.GetItemClassID and Auctionator.Utilities.IsBound instead.
Auctionator.Constants.ITEM_INFO = {
  NAME = 1,
  LINK = 2,
  RARITY = 3,
  ITEM_LEVEL = 4,
  REQUIRED_LEVEL = 5,
  TYPE = 6,
  SUB_TYPE = 7,
  MAX_STACK = 8,
  EQUIP_SLOT = 9,
  TEXTURE = 10,
  SELL_PRICE = 11,
}
