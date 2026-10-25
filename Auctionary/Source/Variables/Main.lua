local Auctionary = Auctionary

local PRICE_DATABASE_VERSION = 1
local POSTING_HISTORY_DB_VERSION = 1
local VENDOR_PRICE_CACHE_DB_VERSION = 1

function Auctionary.Variables.Initialize()
  Auctionary.Variables.InitializeSavedState()

  Auctionary.Config.InitializeData()
  Auctionary.Config.InitializeFrames()

  Auctionary.State.CurrentVersion = GetAddOnMetadata(Auctionary.Constants.AddonName, "Version") or "?"

  Auctionary.Variables.InitializeDatabase()
  Auctionary.Variables.InitializeShoppingLists()
  Auctionary.Variables.InitializePostingHistory()
  Auctionary.Variables.InitializeVendorPriceCache()
  Auctionary.CraftingInfo.InitializeRecipes()

  Auctionary.Groups.Initialize()

  Auctionary.State.Loaded = true
end

-- Called on logout so queued scan prices are written into the saved variables
function Auctionary.Variables.Commit()
  if Auctionary.Database ~= nil then
    Auctionary.Database:Flush()
  end
end

function Auctionary.Variables.InitializeSavedState()
  if AUCTIONARY_SAVEDVARS == nil then
    AUCTIONARY_SAVEDVARS = {}
  end
  Auctionary.SavedState = AUCTIONARY_SAVEDVARS
end

-- In 3.3.5 each faction has its own auction house (plus the neutral one), so
-- prices are stored per realm and faction. There are no connected realms.
function Auctionary.Variables.GetConnectedRealmRoot()
  local faction = UnitFactionGroup("player") or "Neutral"
  return GetRealmName() .. " - " .. faction
end

function Auctionary.Variables.InitializeDatabase()
  Auctionary.Debug.Message("Auctionary.Database.Initialize()")

  -- First time users need the price database initialized, and if we changed
  -- how we record item info we need to reset the DB
  if type(AUCTIONARY_PRICE_DATABASE) ~= "table" or
     AUCTIONARY_PRICE_DATABASE["__dbversion"] ~= PRICE_DATABASE_VERSION then
    AUCTIONARY_PRICE_DATABASE = {
      ["__dbversion"] = PRICE_DATABASE_VERSION
    }
  end

  local realm = Auctionary.Variables.GetConnectedRealmRoot()
  Auctionary.State.CurrentRealm = realm

  if type(AUCTIONARY_PRICE_DATABASE[realm]) ~= "table" then
    AUCTIONARY_PRICE_DATABASE[realm] = {}
  end

  if Auctionary.Config.Get(Auctionary.Config.Options.NO_PRICE_DATABASE) then
    Auctionary.Database = Auctionary.Compat.CreateAndInitFromMixin(Auctionary.DatabaseMixin, {})
  else
    Auctionary.Database = Auctionary.Compat.CreateAndInitFromMixin(Auctionary.DatabaseMixin, AUCTIONARY_PRICE_DATABASE[realm])
  end
end

function Auctionary.Variables.InitializePostingHistory()
  Auctionary.Debug.Message("Auctionary.Variables.InitializePostingHistory()")

  if AUCTIONARY_POSTING_HISTORY == nil  or
     AUCTIONARY_POSTING_HISTORY["__dbversion"] ~= POSTING_HISTORY_DB_VERSION then
    AUCTIONARY_POSTING_HISTORY = {
      ["__dbversion"] = POSTING_HISTORY_DB_VERSION
    }
  end

  Auctionary.PostingHistory = Auctionary.Compat.CreateAndInitFromMixin(Auctionary.PostingHistoryMixin, AUCTIONARY_POSTING_HISTORY)
end

function Auctionary.Variables.InitializeShoppingLists()
  Auctionary.Shopping.ListManager = Auctionary.Compat.CreateAndInitFromMixin(
    AuctionaryShoppingListManagerMixin,
    function() return AUCTIONARY_SHOPPING_LISTS end,
    function(newVal) AUCTIONARY_SHOPPING_LISTS = newVal end
  )

  AUCTIONARY_RECENT_SEARCHES = AUCTIONARY_RECENT_SEARCHES or {}
end

function Auctionary.Variables.InitializeVendorPriceCache()
  Auctionary.Debug.Message("Auctionary.Variables.InitializeVendorPriceCache()")

  if AUCTIONARY_VENDOR_PRICE_CACHE == nil  or
     AUCTIONARY_VENDOR_PRICE_CACHE["__dbversion"] ~= VENDOR_PRICE_CACHE_DB_VERSION then
    AUCTIONARY_VENDOR_PRICE_CACHE = {
      ["__dbversion"] = VENDOR_PRICE_CACHE_DB_VERSION
    }
  end
end
