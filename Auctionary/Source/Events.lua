-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

-- Names of the messages the parts of the addon send each other over the
-- event bus. Only the value has to be unique.
local function Names(prefix, list)
  local names = {}
  for _, name in ipairs(list) do
    names[name] = prefix .. "." .. name
  end
  return names
end

Auctionary.FullScan.Events = Names("fullscan", {
  "ScanStart", "ScanProgress", "ScanComplete", "ScanFailed",
})

Auctionary.Selling.Events = Names("selling", {
  "AuctionCreated",
})

Auctionary.Shopping.Events = Names("shopping", {
  "ListsChanged", "ListItemsChanged", "ListsImported", "RecentsChanged",
})
