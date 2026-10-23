local Auctionary = Auctionary

Auctionary.Constants = {
  AddonName = "Auctionary",

  History = {
    NUMBER_OF_LINES = 20
  },
  RESULTS_DISPLAY_LIMIT = 100,

  AdvancedSearchDivider = ';',

  -- Neither exists in 3.3.5, kept so shared code can compare against them
  PET_CAGE_ID = 82800,
  WOW_TOKEN_ID = 122270,

  SCAN_DAY_0 = time({year=2020, month=1, day=1, hour=0}),

  SORT = {
    ASCENDING = 1,
    DESCENDING = 0
  },
  ITEM_TYPES = {
    ITEM = 1,
    COMMODITY = 2
  },
  EXPORT_TYPES = {
    STRING = 0,
    WHISPER = 1
  },
  NO_LIST = "",
  ITEM_LEVEL_THRESHOLD = 168,

  ShoppingListViews = {
    Lists = 1,
    Recents = 2,
  },

  RecentsListLimit = 30,

  -- Hours, as shown to the user
  Durations = {
    Short = 12,
    Medium = 24,
    Long = 48,
  },
  -- StartAuction run time codes of the 3.3.5 client
  DurationToRunTime = {
    [12] = 1,
    [24] = 2,
    [48] = 3,
  },

  AfterAHCut = 0.95,
  IsLegacyAH = true,
  IsRetail = false,
  IsVanilla = false,
  IsWrath = true,

  -- Number of auctions on one page of a legacy auction house query
  PageSize = 50,

  EnchantingVellumID = 38682,
}

-- Item quality numbers (same values on every client version)
Auctionary.Constants.ItemQuality = {
  Poor = 0,
  Standard = 1, Common = 1,
  Good = 2, Uncommon = 2,
  Rare = 3,
  Epic = 4,
  Legendary = 5,
  Artifact = 6,
  Heirloom = 7,
}

Auctionary.Constants.QualityIDs = {
  Auctionary.Constants.ItemQuality.Poor,
  Auctionary.Constants.ItemQuality.Standard,
  Auctionary.Constants.ItemQuality.Good,
  Auctionary.Constants.ItemQuality.Rare,
  Auctionary.Constants.ItemQuality.Epic,
}

-- Item classes are the positions returned by GetAuctionItemClasses() in the
-- 3.3.5 client. The same numbers are passed to QueryAuctionItems.
Auctionary.Constants.ItemClass = {
  Weapon = 1,
  Armor = 2,
  Container = 3,
  Consumable = 4,
  Glyph = 5,
  Tradegoods = 6,
  Projectile = 7,
  Quiver = 8,
  Recipe = 9,
  Gem = 10,
  Miscellaneous = 11,
  Questitem = 12,
}

Auctionary.Constants.ValidItemClassIDs = {
  Auctionary.Constants.ItemClass.Weapon,
  Auctionary.Constants.ItemClass.Armor,
  Auctionary.Constants.ItemClass.Container,
  Auctionary.Constants.ItemClass.Consumable,
  Auctionary.Constants.ItemClass.Glyph,
  Auctionary.Constants.ItemClass.Tradegoods,
  Auctionary.Constants.ItemClass.Projectile,
  Auctionary.Constants.ItemClass.Quiver,
  Auctionary.Constants.ItemClass.Recipe,
  Auctionary.Constants.ItemClass.Gem,
  Auctionary.Constants.ItemClass.Miscellaneous,
  Auctionary.Constants.ItemClass.Questitem,
}

-- GetAuctionItemTimeLeft bands
Auctionary.Constants.TimeLeftBand = {
  Short = 1,    -- less than 30 minutes
  Medium = 2,   -- 30 minutes to 2 hours
  Long = 3,     -- 2 to 12 hours
  VeryLong = 4, -- 12 to 48 hours
}
