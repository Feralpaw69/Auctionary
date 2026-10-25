-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Fixed values
local C = Auctionary.Constants

C.AddonName = "Auctionary"

-- Price history days are counted from this moment. Stored days depend on it,
-- so it must never change.
C.SCAN_DAY_0 = time({ year = 2020, month = 1, day = 1, hour = 0 })

C.SORT = { ASCENDING = 1, DESCENDING = 0 }
C.AdvancedSearchDivider = ";"
C.RecentsListLimit = 30
C.ShoppingListViews = { Lists = 1, Recents = 2 }

-- What the seller keeps after the auction house cut
C.AfterAHCut = 0.95
-- Auctions per page of an auction house search
C.PageSize = 50
-- Hours of an auction -> number StartAuction expects
C.DurationToRunTime = { [12] = 1, [24] = 2, [48] = 3 }
-- GetAuctionItemTimeLeft: under 30 minutes, under 2 hours, under 12 hours, more
C.TimeLeftBand = { Short = 1, Medium = 2, Long = 3, VeryLong = 4 }

C.ItemQuality = {
  Poor = 0, Standard = 1, Common = 1, Good = 2, Uncommon = 2, Rare = 3,
  Epic = 4, Legendary = 5, Artifact = 6, Heirloom = 7,
}
C.QualityIDs = { 0, 1, 2, 3, 4 }

-- Positions in GetAuctionItemClasses() (also used by QueryAuctionItems)
C.ItemClass = {
  Weapon = 1, Armor = 2, Container = 3, Consumable = 4, Glyph = 5, Tradegoods = 6,
  Projectile = 7, Quiver = 8, Recipe = 9, Gem = 10, Miscellaneous = 11, Questitem = 12,
}
C.ValidItemClassIDs = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

-- Positions in what GetItemInfo returns on 3.3.5
C.ITEM_INFO = {
  NAME = 1, LINK = 2, RARITY = 3, ITEM_LEVEL = 4, REQUIRED_LEVEL = 5, TYPE = 6,
  SUB_TYPE = 7, MAX_STACK = 8, EQUIP_SLOT = 9, TEXTURE = 10, SELL_PRICE = 11,
}

-- Names of the addon's popup windows (StaticPopupDialogs)
C.DialogNames = {}
for _, name in ipairs({ "CreateShoppingList", "DeleteShoppingList", "RenameShoppingList",
                        "MakePermanentShoppingList" }) do
  C.DialogNames[name] = "AUCTIONARY2_" .. name:upper()
end
