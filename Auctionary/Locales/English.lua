-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
-- English texts of Auctionary 2.0 (the base for every other language)
AUCTIONARY2_LOCALES.enUS = function()
  return {
    -- Tabs
    TAB_SHOPPING = "Shopping",
    TAB_SHOPPING_TITLE = "Auctionary - Shopping",
    TAB_SELLING = "Selling",
    TAB_SELLING_TITLE = "Auctionary - Selling",
    TAB_CANCELLING = "Cancelling",
    TAB_CANCELLING_TITLE = "Auctionary - Cancelling",

    -- Full scan
    SCAN_BUTTON = "Full Scan",
    SCAN_START_ALL = "Full scan started: everything in one request.",
    SCAN_START_PAGES = "Full scan started: page by page.",
    SCAN_BUSY = "A full scan is already running.",
    SCAN_FAILED = "The full scan did not finish.",
    SCAN_WAIT = "The quick full scan is possible again in %s min %s s.",
    SCAN_DONE = "Prices saved for %s items.",

    -- Tooltips
    TIP_VENDOR = "Vendor",
    TIP_AUCTION = "Auction",
    TIP_AVERAGE = "Auction average",
    TIP_AGE = "Price age",
    DAYS = "%s days",
    UNKNOWN = "unknown",
    TODAY = "Today",

    -- Table columns
    COL_NAME = "Name",
    COL_PRICE = "Price",
    COL_UNIT_PRICE = "Price Each",
    COL_BUYOUT = "Buyout",
    COL_AVAILABLE = "Available",
    COL_SELLER = "Seller",
    COL_OWN = "Yours?",
    COL_TIME_LEFT = "Time Left",
    ITEM_LEVEL = "Item Level",
    LEVEL = "Level",
    QUANTITY = "Quantity",
    YES = "Yes",
    ANY = "Any",
    MAX = "max",
    NO_RESULTS = "Nothing found.",

    -- Shopping lists
    SEARCH = "Search",
    CANCEL = "Cancel",
    RENAME = "Rename",
    DELETE = "Delete",
    EDIT = "Edit",
    LISTS = "Shopping Lists",
    RECENTS = "Recent Searches",
    LIST_NEW = "New List",
    LIST_ADD = "Add to List",
    LIST_SEARCH_ALL = "Search All",
    LIST_KEEP = "Keep List",
    LIST_NEW_ASK = "Name of the new shopping list:",
    LIST_RENAME_ASK = "New name for '%s':",
    LIST_KEEP_ASK = "Keep '%s' for good under this name:",
    LIST_DELETE_ASK = "Delete the shopping list '%s'?",
    TEMPORARY = "temporary",
    IMPORTED = "Imported",

    -- Extended search
    EDITOR_SEARCH_TITLE = "Extended Search",
    EDITOR_EDIT_TITLE = "Edit List Entry",
    EDITOR_NAME = "Search Term",
    EDITOR_EXACT = "Exact name",
    EDITOR_CATEGORY = "Category",
    EDITOR_CLEAR = "Clear All",
    EDITOR_EMPTY = "Nothing to search for was entered.",

    -- Buying and selling
    BUY_NOW = "Buy Now",
    BUY_STACK = "Buy Stack",
    BUYING = "Buying",
    BUYING_FOR = "Buying %s for %s",
    POST = "Post",
    DURATION = "Duration",
    DEPOSIT = "Deposit:",
    TOTAL = "Total:",
  }
end
