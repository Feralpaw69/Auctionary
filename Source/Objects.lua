-- Global namespace of the 3.3.5a backport. Deliberately NOT "Auctionator" so
-- the addon can run next to the original Auctionator 2.6.8.
Auctionary = {
  Debug = {},
  Constants = {},
  Utilities = {},
  Events = {},
  SlashCmd = {},

  State = {
    Loaded = false,
    CurrentVersion = nil,
  },

  SavedState = {},
  Search = {
    CategoryLookup = {},
    Filters = {},
  },
  Tooltip = {},
  Locales = {},
  Config = {},
  Variables = {},
  Shopping = { Tab = {}, Lists = {} },
  Cancelling = {},
  Enchant = {},
  Mill = {},
  Prospect = {},
  Selling = {},
  Buying = {},
  Components = {},
  CraftingInfo = {},
  IncrementalScan = {},
  FullScan = {},
  PostingHistory = {},
  Groups = {},

  Tabs = {
    State = {
      knownTabs= {}
    },
  },

  API = {
    v1 = {}
  },

  AH = {}
}
