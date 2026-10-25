-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

-- Options that the original keeps in its auction-house specific source
-- folders, adjusted for the 3.3.5 auction house.
Auctionary.Config.ItemMatching = {
  ITEM_ID_AND_LEVEL = "item level only",
  ITEM_ID = "item id",
  ITEM_NAME_AND_LEVEL = "item name and level",
  ITEM_NAME_ONLY = "item name only",
}

local Options = Auctionary.Config.Options
local Defaults = Auctionary.Config.Defaults

Options.SMALL_TABS = "small_tabs"
Options.AUTOSCAN = "autoscan_2"
Options.AUTOSCAN_INTERVAL = "autoscan_interval"
Options.SELLING_CANCEL_SHORTCUT = "selling_cancel_shortcut"
Options.SELLING_BUY_SHORTCUT = "selling_buy_shortcut"
Options.SELLING_SPLIT_PANELS = "selling_split_panels"
Options.COLUMNS_SHOPPING_BUY_ITEM = "columns_shopping_buy_item"
Options.COLUMNS_SHOPPING_BUY_COMMODITY = "columns_shopping_buy_commodity"
Options.SHOPPING_ALWAYS_CONFIRM_COMMODITY_QUANTITY = "shopping_always_confirm_commodity_quantity"
Options.AUCTION_DURATION = "auction_duration"
Options.AUCTION_SALES_PREFERENCE = "auction_sales_preference"
Options.UNDERCUT_PERCENTAGE = "undercut_percentage"
Options.UNDERCUT_STATIC_VALUE = "undercut_static_value"
Options.SELLING_ITEM_MATCHING = "selling_item_matching"
Options.DEFAULT_QUANTITIES = "default_quantities"
Options.UNDERCUT_SCAN_NOT_LIFO = "undercut_scan_not_lifo"
Options.PROSPECT_TOOLTIPS = "prospect_tooltips"
Options.MILL_TOOLTIPS = "mill_tooltips"

Options.SNIPING_VENDOR = "sniping_vendor"
Options.SNIPING_AVERAGE = "sniping_average"
Options.SNIPING_AVERAGE_PERCENT = "sniping_average_percent"
Options.SNIPING_AVERAGE_DAYS = "sniping_average_days"
Options.SNIPING_MIN_PROFIT = "sniping_min_profit"
Options.SNIPING_EXCLUDED_CLASSES = "sniping_excluded_classes"
Options.SNIPING_REQUIRE_GAP = "sniping_require_gap"
Options.SNIPING_MIN_SCANS = "sniping_min_scans"
Options.SNIPING_HIDDEN_ITEMS = "sniping_hidden_items"
Options.SNIPING_AUTO_SWITCH = "sniping_auto_switch"
Options.MATS_COST_TOOLTIPS = "mats_cost_tooltips"
Options.TAB_BACKGROUND = "tab_background"
Options.SNIPING_CATEGORY = "sniping_category"
Options.SNIPING_DISENCHANT = "sniping_disenchant"
Options.DOUBLE_CLICK_ACTIONS = "double_click_actions"
Options.SELLING_POST_ON_ENTER = "selling_post_on_enter"
Options.SNIPING_DE_EXCLUDED_QUALITIES = "sniping_de_excluded_qualities"
Options.SNIPING_DE_EXCLUDED_LEVELS = "sniping_de_excluded_levels"
Options.DISENCHANT_TOOLTIPS = "disenchant_tooltips"
Options.SHOPPING_CONFIRM_HIGH_PRICE = "shopping_confirm_high_price"
Options.SELLING_WARN_LOW_PRICE = "selling_warn_low_price"
Options.SELLING_BARGAIN_PERCENT = "selling_bargain_percent"
Options.SELLING_SCAM_PROTECTION = "selling_scam_protection"
Options.SELLING_SCAM_PERCENT = "selling_scam_percent"

-- Sniping tab: which auctions count as cheap
Defaults[Options.SNIPING_VENDOR] = true             -- buyout below the vendor sell price
Defaults[Options.SNIPING_AVERAGE] = true            -- buyout far below the average price
Defaults[Options.SNIPING_AVERAGE_PERCENT] = 90      -- at most this share of the average
Defaults[Options.SNIPING_AVERAGE_DAYS] = 14         -- days the average is taken over
Defaults[Options.SNIPING_MIN_PROFIT] = 0            -- copper, per auction
Defaults[Options.SNIPING_EXCLUDED_CLASSES] = {}     -- [item class index] = true
-- Safeguards for the average rule: the auction also has to stand out among
-- the auctions that are up right now, and the average needs enough scans
Defaults[Options.SNIPING_REQUIRE_GAP] = true
Defaults[Options.SNIPING_MIN_SCANS] = 3
-- Items the user does not want to see in the Sniping tab: [item ID] = name
Defaults[Options.SNIPING_HIDDEN_ITEMS] = {}
Defaults[Options.SNIPING_AUTO_SWITCH] = true
Defaults[Options.MATS_COST_TOOLTIPS] = true
Defaults[Options.TAB_BACKGROUND] = "crimson"
Defaults[Options.SNIPING_CATEGORY] = "Everything"
Defaults[Options.SNIPING_DISENCHANT] = true
Defaults[Options.DOUBLE_CLICK_ACTIONS] = false
Defaults[Options.SELLING_POST_ON_ENTER] = true
Options.KEYS_SELLING = "keys_selling"
Options.KEYS_SHOPPING = "keys_shopping"
Options.KEYS_SNIPING = "keys_sniping"
Options.SHOPPING_BUY_ON_ENTER = "shopping_buy_on_enter"
Options.SNIPING_BUY_ON_ENTER = "sniping_buy_on_enter"
Options.SNIPING_AUTO_NEXT = "sniping_auto_next"
Defaults[Options.KEYS_SELLING] = true
Defaults[Options.KEYS_SHOPPING] = true
Defaults[Options.KEYS_SNIPING] = true
Defaults[Options.SHOPPING_BUY_ON_ENTER] = false
Defaults[Options.SNIPING_BUY_ON_ENTER] = false
Defaults[Options.SNIPING_AUTO_NEXT] = true
Options.SNIPING_BUDGET = "sniping_budget"
Defaults[Options.SNIPING_BUDGET] = 0  -- gold; 0 = no limit
Options.GOLD_TRACKER_BUTTON = "gold_tracker_button"
Options.GOLD_TRACKER_RECORD = "gold_tracker_record"
Options.GOLD_TRACKER_VENDOR = "gold_tracker_vendor"
Options.GOLD_TRACKER_SNIPING = "gold_tracker_sniping"
Defaults[Options.GOLD_TRACKER_BUTTON] = true
Defaults[Options.GOLD_TRACKER_RECORD] = true
Defaults[Options.GOLD_TRACKER_VENDOR] = true
Defaults[Options.GOLD_TRACKER_SNIPING] = true
Defaults[Options.SNIPING_DE_EXCLUDED_QUALITIES] = {}  -- [quality 2/3/4] = true
Defaults[Options.SNIPING_DE_EXCLUDED_LEVELS] = {}     -- ["low-high"] = true
Defaults[Options.DISENCHANT_TOOLTIPS] = true
Defaults[Options.SHOPPING_CONFIRM_HIGH_PRICE] = true
Defaults[Options.SELLING_WARN_LOW_PRICE] = true
-- Gold coin in the Selling tab: buys the cheapest auction at or below this share of the average
Defaults[Options.SELLING_BARGAIN_PERCENT] = 70
Defaults[Options.SELLING_SCAM_PROTECTION] = true
Defaults[Options.SELLING_SCAM_PERCENT] = 50

Defaults[Options.SMALL_TABS] = false
Defaults[Options.AUTOSCAN] = false
Defaults[Options.AUTOSCAN_INTERVAL] = 15
Defaults[Options.UNDERCUT_SCAN_NOT_LIFO] = true
Defaults[Options.SELLING_CANCEL_SHORTCUT] = Auctionary.Config.Shortcuts.RIGHT_CLICK
Defaults[Options.SELLING_BUY_SHORTCUT] = Auctionary.Config.Shortcuts.ALT_RIGHT_CLICK
Defaults[Options.SELLING_SPLIT_PANELS] = false
Defaults[Options.COLUMNS_SHOPPING_BUY_ITEM] = {}
Defaults[Options.COLUMNS_SHOPPING_BUY_COMMODITY] = {}
Defaults[Options.SHOPPING_ALWAYS_CONFIRM_COMMODITY_QUANTITY] = false
Defaults[Options.AUCTION_DURATION] = 24
Defaults[Options.AUCTION_SALES_PREFERENCE] = Auctionary.Config.SalesTypes.PERCENTAGE
Defaults[Options.UNDERCUT_PERCENTAGE] = 0
Defaults[Options.UNDERCUT_STATIC_VALUE] = 0
Defaults[Options.SELLING_ITEM_MATCHING] = Auctionary.Config.ItemMatching.ITEM_NAME_AND_LEVEL
Defaults[Options.PROSPECT_TOOLTIPS] = true
Defaults[Options.MILL_TOOLTIPS] = true

-- Default number of items per posted stack, by auction house item class.
-- 0 means "everything you have of the item".
local ItemClass = Auctionary.Constants.ItemClass
Defaults[Options.DEFAULT_QUANTITIES] = {
  [ItemClass.Weapon]        = 1,
  [ItemClass.Armor]         = 1,
  [ItemClass.Container]     = 0,
  [ItemClass.Consumable]    = 0,
  [ItemClass.Glyph]         = 0,
  [ItemClass.Tradegoods]    = 0,
  [ItemClass.Projectile]    = 0,
  [ItemClass.Quiver]        = 0,
  [ItemClass.Recipe]        = 0,
  [ItemClass.Gem]           = 0,
  [ItemClass.Miscellaneous] = 0,
  [ItemClass.Questitem]     = 0,
}

-- The options panels are built in a later stage of the port
function Auctionary.Config.InitializeFrames()
end
