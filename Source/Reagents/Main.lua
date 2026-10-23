local Auctionary = Auctionary

-- What an item is worth when it is disenchanted, prospected or milled, from
-- the prices of the last scans. The drop tables come from the original addon.
local Mats = Auctionary.Constants.DisenchantMats
local weaponClassName, armorClassName = GetAuctionItemClasses()

local function GetPrice(itemID)
  if Auctionary.Database == nil then
    return nil
  end
  return Auctionary.Database:GetPrice(tostring(itemID))
end

-- Lesser essences can be made from greater ones (3 for 1)
local function GetDisenchantMatPrice(itemID)
  local price = GetPrice(itemID)
  local greater = Auctionary.Constants.DisenchantingMatMapping[itemID]
  if greater ~= nil then
    local greaterPrice = GetPrice(greater)
    if price ~= nil and greaterPrice ~= nil and price * 3 > greaterPrice then
      return math.floor(greaterPrice / 3)
    end
  end
  return price
end

---- Items that cannot be disenchanted
-- The client marks them in the tooltip ("Cannot be disenchanted"), but only
-- for characters that know Enchanting. So: a short built-in list, plus
-- everything a tooltip has ever shown as not disenchantable, remembered for
-- all characters.
local NOT_DISENCHANTABLE = {
  [11287] = true, [11288] = true, [11289] = true, [11290] = true, -- wands made by enchanters
  [20406] = true, [20407] = true, [20408] = true,                 -- Twilight Cultist set
  [3295] = true,                                                  -- Deadman Blade
  [10587] = true,                                                 -- Goblin Bomb Dispenser
  [7506] = true,                                                  -- Gnomish Universal Remote
  [33012] = true,                                                 -- Terokkar Lilac (ID as given by the user)
}
local NOT_DISENCHANTABLE_TEXT = ITEM_DISENCHANT_NOT_DISENCHANTABLE or "Cannot be disenchanted"

local function IDFromLink(itemLink)
  return tonumber(type(itemLink) == "string" and itemLink:match("item:(%d+)") or itemLink)
end

local function Learned()
  if Auctionary.SavedState == nil then
    return nil
  end
  Auctionary.SavedState.NotDisenchantable = Auctionary.SavedState.NotDisenchantable or {}
  return Auctionary.SavedState.NotDisenchantable
end

function Auctionary.Enchant.IsNotDisenchantable(itemLink)
  local itemID = IDFromLink(itemLink)
  if itemID == nil then
    return false
  end
  local learned = Learned()
  return NOT_DISENCHANTABLE[itemID] == true or (learned ~= nil and learned[itemID] == true)
end

-- Looks through the lines of a tooltip that shows the item; remembers the
-- item if the client says it cannot be disenchanted. Returns true in that case.
function Auctionary.Enchant.LearnFromTooltip(tooltip, itemLink)
  local itemID = IDFromLink(itemLink)
  local name = tooltip and tooltip:GetName()
  if itemID == nil or name == nil then
    return false
  end
  for line = 2, tooltip:NumLines() do
    local fontString = _G[name .. "TextLeft" .. line]
    if fontString ~= nil and fontString:GetText() == NOT_DISENCHANTABLE_TEXT then
      local learned = Learned()
      if learned ~= nil then
        learned[itemID] = true
      end
      return true
    end
  end
  return false
end

-- Asks the client through a hidden tooltip (used before an item is offered
-- as worth disenchanting)
function Auctionary.Enchant.CheckNotDisenchantable(itemLink)
  if Auctionary.Enchant.IsNotDisenchantable(itemLink) then
    return true
  end
  local tooltip = Auctionary.Compat.GetScanTooltip()
  tooltip:SetHyperlink(itemLink)
  return Auctionary.Enchant.LearnFromTooltip(tooltip, itemLink)
end

local function FindEntry(itemLink)
  if Auctionary.Enchant.IsNotDisenchantable(itemLink) then
    return nil
  end
  local _, _, quality, itemLevel, _, itemType, _, _, equipLoc = GetItemInfo(itemLink)
  if quality == nil or quality < 2 or quality > 4 or itemLevel == nil then
    return nil
  end
  local class
  if itemType == weaponClassName then
    class = "WEAPON"
  elseif itemType == armorClassName then
    class = "ARMOR"
  else
    return nil
  end
  -- Shirts, tabards and bags-like things cannot be disenchanted
  if equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" or equipLoc == "" then
    return nil
  end
  local entries = Auctionary.Constants.DisenchantingProbability[class][quality] or {}
  for _, entry in ipairs(entries) do
    if itemLevel >= entry[1] and itemLevel <= entry[2] then
      return entry
    end
  end
end

-- Returns the expected value (nil if the item cannot be disenchanted) and
-- whether a material had no known price
function Auctionary.Enchant.GetDisenchantAuctionPrice(itemLink)
  local entry = FindEntry(itemLink)
  if entry == nil then
    return nil
  end
  local total, missing = 0, false
  for x = 3, #entry, 3 do
    local price = GetDisenchantMatPrice(entry[x + 2])
    if price ~= nil then
      total = total + entry[x] * entry[x + 1] * price
    elseif entry[x] >= 1 then
      missing = true
    end
  end
  return math.floor(total / 100), missing
end

-- Lines like "75% 1-3 Infinite Dust"
function Auctionary.Enchant.GetDisenchantBreakdown(itemLink)
  local entry = FindEntry(itemLink)
  local results = {}
  if entry == nil then
    return results
  end
  local order, byMat = {}, {}
  for x = 3, #entry, 3 do
    local matID = entry[x + 2]
    local mat = byMat[matID]
    if mat == nil then
      mat = { id = matID, percent = 0, low = entry[x + 1], high = entry[x + 1] }
      byMat[matID] = mat
      table.insert(order, mat)
    end
    mat.percent = mat.percent + entry[x]
    mat.low = math.min(mat.low, entry[x + 1])
    mat.high = math.max(mat.high, entry[x + 1])
  end
  for _, mat in ipairs(order) do
    local name = GetItemInfo(mat.id) or Auctionary.Constants.DisenchantingItemName[mat.id] or "?"
    local amount = mat.low == mat.high and tostring(mat.low) or (mat.low .. "-" .. mat.high)
    local percent = math.floor(mat.percent * 10 + 0.5) / 10
    table.insert(results, "  " .. percent .. "%  " .. amount .. " " .. name)
  end
  return results
end

-- tableOfDrops[reagent] = { chance of 1, chance of 2, ... } per 5 items
local function GetTableValue(dropTable, itemID)
  local results = dropTable[tostring(itemID)]
  if results == nil then
    return nil
  end
  local total, missing = 0, false
  for reagentKey, allDrops in pairs(results) do
    local price = GetPrice(reagentKey)
    if price == nil then
      missing = true
    else
      for count, chance in ipairs(allDrops) do
        total = total + price * count * chance
      end
    end
  end
  return math.floor(total / 5), missing
end

function Auctionary.Mill.GetMillAuctionPrice(itemID)
  return GetTableValue(Auctionary.Mill.MILL_TABLE, itemID)
end

function Auctionary.Prospect.GetProspectAuctionPrice(itemID)
  return GetTableValue(Auctionary.Prospect.PROSPECT_TABLE, itemID)
end
