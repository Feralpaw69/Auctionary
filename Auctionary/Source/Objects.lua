-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
-- Everything of the addon lives in this one global table
Auctionary2 = {
  State = { Loaded = false },
  SavedState = {},
  Tabs = {},
  API = { v1 = {} },
  Shopping = { Lists = {} },
  Search = { CategoryLookup = {} },
}
for _, part in ipairs({
  "Debug", "Constants", "Utilities", "Commands", "Tooltip", "Locales", "Config",
  "Variables", "Cancelling", "Enchant", "Mill", "Prospect", "Selling", "Buying",
  "Components", "CraftingInfo", "FullScan", "AH", "Sniping",
}) do
  Auctionary2[part] = {}
end
