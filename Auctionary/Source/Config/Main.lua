-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Settings
-- Saved in AUCTIONARY2_CONFIG as [option name] = value. The option names
-- are what is stored, so they must not change once in use.

local Config = Auctionary.Config

Config.Options = {
  DEBUG = "debug",
  NO_PRICE_DATABASE = "no_price_database",
  VENDOR_TOOLTIPS = "vendor_tooltips",
  AUCTION_TOOLTIPS = "auction_tooltips",
  AUCTION_AGE_TOOLTIPS = "auction_age_tooltips",
  AUCTION_MEAN_TOOLTIPS = "auction_mean_tooltips",
  AUCTION_MEAN_DAYS_LIMIT = "auction_mean_days_limit",
  SHIFT_STACK_TOOLTIPS = "shift_stack_tooltips",
  PRICE_HISTORY_DAYS = "price_history_days",
  SELLING_FAVOURITE_KEYS = "selling_favourite_keys_2",
  CRAFTING_INFO_SHOW = "crafting_info_show",
  CRAFTING_INFO_SHOW_PROFIT = "crafting_info_show_profit",
  CRAFTING_INFO_SHOW_COST = "crafting_info_show_cost",
  SHOPPING_LAST_CONTAINER_VIEW = "shopping_last_container_view",
}

Config.SalesTypes = { PERCENTAGE = "percentage", STATIC = "static" }

Config.Shortcuts = {
  LEFT_CLICK = "left click",
  RIGHT_CLICK = "right click",
  ALT_LEFT_CLICK = "alt left click",
  ALT_RIGHT_CLICK = "alt right click",
  SHIFT_LEFT_CLICK = "shift left click",
  SHIFT_RIGHT_CLICK = "shift right click",
  NONE = "none",
}

local Options = Config.Options
Config.Defaults = {
  [Options.DEBUG] = false,
  [Options.NO_PRICE_DATABASE] = false,
  [Options.VENDOR_TOOLTIPS] = true,
  [Options.AUCTION_TOOLTIPS] = true,
  [Options.AUCTION_AGE_TOOLTIPS] = false,
  [Options.AUCTION_MEAN_TOOLTIPS] = false,
  [Options.AUCTION_MEAN_DAYS_LIMIT] = 21,
  [Options.SHIFT_STACK_TOOLTIPS] = true,
  [Options.PRICE_HISTORY_DAYS] = 21,
  [Options.SELLING_FAVOURITE_KEYS] = {},
  [Options.CRAFTING_INFO_SHOW] = true,
  [Options.CRAFTING_INFO_SHOW_PROFIT] = true,
  [Options.CRAFTING_INFO_SHOW_COST] = true,
  [Options.SHOPPING_LAST_CONTAINER_VIEW] = Auctionary.Constants.ShoppingListViews.Lists,
}

local function CopyDefault(value)
  if type(value) == "table" then
    return Auctionary.Compat.CopyTable(value)
  end
  return value
end

-- Fills in every option that has no value yet
function Config.InitializeData()
  if type(AUCTIONARY2_CONFIG) ~= "table" then
    AUCTIONARY2_CONFIG = {}
  end
  for name, value in pairs(Config.Defaults) do
    if AUCTIONARY2_CONFIG[name] == nil then
      AUCTIONARY2_CONFIG[name] = CopyDefault(value)
    end
  end
end

function Config.Reset()
  AUCTIONARY2_CONFIG = nil
  Config.InitializeData()
end

function Config.Get(name)
  local saved = AUCTIONARY2_CONFIG
  if saved == nil or saved[name] == nil then
    return Config.Defaults[name]
  end
  return saved[name]
end

function Config.Set(name, value)
  if AUCTIONARY2_CONFIG == nil then
    Config.InitializeData()
  end
  local known = false
  for _, optionName in pairs(Options) do
    if optionName == name then
      known = true
      break
    end
  end
  if not known then
    error("Unknown option '" .. tostring(name) .. "'")
  end
  AUCTIONARY2_CONFIG[name] = value
end
