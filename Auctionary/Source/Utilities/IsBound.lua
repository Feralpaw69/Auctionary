-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

-- GetItemInfo has no bind type in 3.3.5, so the item's tooltip is read with a
-- hidden tooltip instead. Results are cached per item ID.
local boundTexts = {}
for _, globalName in ipairs({
  "ITEM_BIND_ON_PICKUP", "ITEM_BIND_QUEST", "ITEM_SOULBOUND",
  "ITEM_BIND_TO_ACCOUNT", "ITEM_ACCOUNTBOUND", "ITEM_CONJURED",
}) do
  -- Not every global exists on every client build
  if _G[globalName] ~= nil then
    table.insert(boundTexts, _G[globalName])
  end
end
local cache = {}

-- Is this kind of item bound when you obtain it (so it can never be auctioned)?
-- Returns false for items that are not in the item cache yet.
function Auctionary.Utilities.IsBound(itemLinkOrID)
  local itemID = Auctionary.Compat.GetItemIDFromLink(itemLinkOrID)
  if itemID == nil then
    return true
  end
  if cache[itemID] ~= nil then
    return cache[itemID]
  end
  if GetItemInfo(itemID) == nil then
    return false
  end
  local tooltip = Auctionary.Compat.GetScanTooltip()
  tooltip:SetHyperlink("item:" .. itemID .. ":0:0:0:0:0:0:0")
  local result = Auctionary.Compat.ScanTooltipHasLine(tooltip, boundTexts)
  cache[itemID] = result
  return result
end
