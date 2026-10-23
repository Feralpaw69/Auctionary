local Auctionator = Auctionary

local PRICE_DATABASE_VERSION = 1
local POSTING_HISTORY_DB_VERSION = 1
local VENDOR_PRICE_CACHE_DB_VERSION = 1

function Auctionator.Variables.Initialize()
  Auctionator.Variables.InitializeSavedState()

  Auctionator.Config.InitializeData()
  Auctionator.Config.InitializeFrames()

  Auctionator.State.CurrentVersion = GetAddOnMetadata(Auctionator.Constants.AddonName, "Version") or "?"

  Auctionator.Variables.InitializeDatabase()
  Auctionator.Variables.InitializeShoppingLists()
  Auctionator.Variables.InitializePostingHistory()
  Auctionator.Variables.InitializeVendorPriceCache()
  Auctionator.CraftingInfo.InitializeRecipes()

  Auctionator.Groups.Initialize()

  Auctionator.State.Loaded = true
end

-- Called on logout so queued scan prices are written into the saved variables
function Auctionator.Variables.Commit()
  if Auctionator.Database ~= nil then
    Auctionator.Database:Flush()
  end
end

function Auctionator.Variables.InitializeSavedState()
  if AUCTIONARY_SAVEDVARS == nil then
    AUCTIONARY_SAVEDVARS = {}
  end
  Auctionator.SavedState = AUCTIONARY_SAVEDVARS
end

-- In 3.3.5 each faction has its own auction house (plus the neutral one), so
-- prices are stored per realm and faction. There are no connected realms.
function Auctionator.Variables.GetConnectedRealmRoot()
  local faction = UnitFactionGroup("player") or "Neutral"
  return GetRealmName() .. " - " .. faction
end

function Auctionator.Variables.InitializeDatabase()
  Auctionator.Debug.Message("Auctionator.Database.Initialize()")

  -- First time users need the price database initialized, and if we changed
  -- how we record item info we need to reset the DB
  if type(AUCTIONARY_PRICE_DATABASE) ~= "table" or
     AUCTIONARY_PRICE_DATABASE["__dbversion"] ~= PRICE_DATABASE_VERSION then
    AUCTIONARY_PRICE_DATABASE = {
      ["__dbversion"] = PRICE_DATABASE_VERSION
    }
  end

  local realm = Auctionator.Variables.GetConnectedRealmRoot()
  Auctionator.State.CurrentRealm = realm

  if type(AUCTIONARY_PRICE_DATABASE[realm]) ~= "table" then
    AUCTIONARY_PRICE_DATABASE[realm] = {}
  end

  if Auctionator.Config.Get(Auctionator.Config.Options.NO_PRICE_DATABASE) then
    Auctionator.Database = Auctionator.Compat.CreateAndInitFromMixin(Auctionator.DatabaseMixin, {})
  else
    Auctionator.Database = Auctionator.Compat.CreateAndInitFromMixin(Auctionator.DatabaseMixin, AUCTIONARY_PRICE_DATABASE[realm])
  end
end

function Auctionator.Variables.InitializePostingHistory()
  Auctionator.Debug.Message("Auctionator.Variables.InitializePostingHistory()")

  if AUCTIONARY_POSTING_HISTORY == nil  or
     AUCTIONARY_POSTING_HISTORY["__dbversion"] ~= POSTING_HISTORY_DB_VERSION then
    AUCTIONARY_POSTING_HISTORY = {
      ["__dbversion"] = POSTING_HISTORY_DB_VERSION
    }
  end

  Auctionator.PostingHistory = Auctionator.Compat.CreateAndInitFromMixin(Auctionator.PostingHistoryMixin, AUCTIONARY_POSTING_HISTORY)
end

function Auctionator.Variables.InitializeShoppingLists()
  Auctionator.Shopping.ListManager = Auctionator.Compat.CreateAndInitFromMixin(
    AuctionaryShoppingListManagerMixin,
    function() return AUCTIONARY_SHOPPING_LISTS end,
    function(newVal) AUCTIONARY_SHOPPING_LISTS = newVal end
  )

  AUCTIONARY_RECENT_SEARCHES = AUCTIONARY_RECENT_SEARCHES or {}
end

function Auctionator.Variables.InitializeVendorPriceCache()
  Auctionator.Debug.Message("Auctionator.Variables.InitializeVendorPriceCache()")

  if AUCTIONARY_VENDOR_PRICE_CACHE == nil  or
     AUCTIONARY_VENDOR_PRICE_CACHE["__dbversion"] ~= VENDOR_PRICE_CACHE_DB_VERSION then
    AUCTIONARY_VENDOR_PRICE_CACHE = {
      ["__dbversion"] = VENDOR_PRICE_CACHE_DB_VERSION
    }
  end
end
