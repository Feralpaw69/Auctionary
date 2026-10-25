-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Saved data
-- Everything the addon keeps between sessions is set up here at login.
-- Tables that carry a "__dbversion" are started fresh when the stored
-- version is a different one.

local Variables = Auctionary.Variables

-- A table of the saved variable `name` with this version, new if needed
local function Versioned(name, version)
  local saved = _G[name]
  if type(saved) ~= "table" or saved.__dbversion ~= version then
    saved = { __dbversion = version }
    _G[name] = saved
  end
  return saved
end

-- Each faction has its own auction house on 3.3.5, so prices are kept per
-- realm and faction
function Variables.GetConnectedRealmRoot()
  return GetRealmName() .. " - " .. (UnitFactionGroup("player") or "Neutral")
end

function Variables.OpenPriceDatabase()
  local all = Versioned("AUCTIONARY2_PRICE_DATABASE", 1)
  local realm = Variables.GetConnectedRealmRoot()
  Auctionary.State.CurrentRealm = realm
  all[realm] = type(all[realm]) == "table" and all[realm] or {}

  -- With price recording switched off the prices only live until logout
  local store = Auctionary.Config.Get(Auctionary.Config.Options.NO_PRICE_DATABASE) and {} or all[realm]
  Auctionary.Database = Auctionary.CreatePriceDatabase(store)
end

function Variables.Initialize()
  if type(AUCTIONARY2_SAVEDVARS) ~= "table" then
    AUCTIONARY2_SAVEDVARS = {}
  end
  Auctionary.SavedState = AUCTIONARY2_SAVEDVARS

  Auctionary.Config.InitializeData()
  Auctionary.Config.InitializeFrames()
  Auctionary.State.CurrentVersion = GetAddOnMetadata(Auctionary.Constants.AddonName, "Version") or "?"

  Variables.OpenPriceDatabase()
  Auctionary.Shopping.ListManager = Auctionary.Shopping.CreateListManager()
  Auctionary.PostingHistory = Auctionary.CreatePostingHistory(Versioned("AUCTIONARY2_POSTING_HISTORY", 1))
  Versioned("AUCTIONARY2_VENDOR_PRICE_CACHE", 1)
  Auctionary.CraftingInfo.InitializeRecipes()

  Auctionary.State.Loaded = true
end

-- Logging out: prices that still wait are written into the saved data
function Variables.Commit()
  if Auctionary.Database ~= nil then
    Auctionary.Database:Flush()
  end
end
