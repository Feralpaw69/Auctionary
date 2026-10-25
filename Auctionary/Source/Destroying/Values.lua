-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- What an item is worth destroyed: disenchanted, milled or prospected
-- Results come from Destroying/Data.lua, prices from the last scans.
--   Auctionary.Enchant.GetDisenchantAuctionPrice(itemLink) -> copper, priceMissing
--   Auctionary.Enchant.GetDisenchantBreakdown(itemLink)    -> lines "75%  1-3 Infinite Dust"
--   Auctionary.Enchant.GetDustBrackets()                   -> item level ranges by dust
--   Auctionary.Mill.GetMillAuctionPrice(itemID)            -> copper per herb, priceMissing
--   Auctionary.Prospect.GetProspectAuctionPrice(itemID)    -> copper per ore, priceMissing

local Data = Auctionary.Destroying.Data
local WEAPON_CLASS, ARMOR_CLASS = GetAuctionItemClasses()
WEAPON_CLASS, ARMOR_CLASS = WEAPON_CLASS or "Weapon", ARMOR_CLASS or "Armor"

local function Price(itemID)
  if Auctionary.Database == nil then
    return nil
  end
  return Auctionary.Database:GetPrice(tostring(itemID))
end

-- A lesser essence never counts for more than a third of a greater one
local function MaterialPrice(itemID)
  local price = Price(itemID)
  local greater = Data.LesserToGreater[itemID]
  local greaterPrice = greater and Price(greater)
  if price ~= nil and greaterPrice ~= nil then
    return math.min(price, math.floor(greaterPrice / 3))
  end
  return price
end

local function MaterialName(itemID)
  return GetItemInfo(itemID) or Data.MaterialNames[itemID] or "?"
end

---- Items that cannot be disenchanted
-- The client says so in the tooltip ("Cannot be disenchanted"), but only to
-- characters with Enchanting. So: a few known ones, plus every item a
-- tooltip has shown that line for, remembered for all characters.
local KNOWN_NOT_DISENCHANTABLE = {
  [11287] = true, [11288] = true, [11289] = true, [11290] = true, -- enchanter-made wands
  [20406] = true, [20407] = true, [20408] = true,                 -- Twilight Cultist set
  [3295] = true, [10587] = true, [7506] = true, [33012] = true,
}
local NOT_DISENCHANTABLE_LINE = ITEM_DISENCHANT_NOT_DISENCHANTABLE or "Cannot be disenchanted"

local function ItemID(itemLink)
  return tonumber(type(itemLink) == "string" and itemLink:match("item:(%d+)") or itemLink)
end

local function Remembered()
  local state = Auctionary.SavedState
  if state == nil then
    return nil
  end
  state.NotDisenchantable = state.NotDisenchantable or {}
  return state.NotDisenchantable
end

function Auctionary.Enchant.IsNotDisenchantable(itemLink)
  local itemID = ItemID(itemLink)
  if itemID == nil then
    return false
  end
  local remembered = Remembered()
  return KNOWN_NOT_DISENCHANTABLE[itemID] == true or (remembered ~= nil and remembered[itemID] == true)
end

-- Reads a tooltip that shows the item; true if it says "Cannot be disenchanted"
function Auctionary.Enchant.LearnFromTooltip(tooltip, itemLink)
  local itemID = ItemID(itemLink)
  local name = tooltip and tooltip:GetName()
  if itemID == nil or name == nil then
    return false
  end
  for line = 2, tooltip:NumLines() do
    local text = _G[name .. "TextLeft" .. line]
    if text ~= nil and text:GetText() == NOT_DISENCHANTABLE_LINE then
      local remembered = Remembered()
      if remembered ~= nil then
        remembered[itemID] = true
      end
      return true
    end
  end
  return false
end

-- Asks the client with a hidden tooltip
function Auctionary.Enchant.CheckNotDisenchantable(itemLink)
  if Auctionary.Enchant.IsNotDisenchantable(itemLink) then
    return true
  end
  local tooltip = Auctionary.Compat.GetScanTooltip()
  tooltip:SetHyperlink(itemLink)
  return Auctionary.Enchant.LearnFromTooltip(tooltip, itemLink)
end

---- Disenchanting

local function InRange(rows, level)
  for _, row in ipairs(rows) do
    if level >= row[1] and level <= row[2] then
      return row
    end
  end
end

-- What the item gives: { { material, percent, min, max }, ... } or nil
local function Outcomes(itemLink)
  if Auctionary.Enchant.IsNotDisenchantable(itemLink) then
    return nil
  end
  local _, _, quality, level, _, itemType, _, _, equipLoc = GetItemInfo(itemLink)
  if quality == nil or level == nil or quality < 2 or quality > 4 then
    return nil
  end
  local kind
  if itemType == WEAPON_CLASS then
    kind = "WEAPON"
  elseif itemType == ARMOR_CLASS then
    kind = "ARMOR"
  end
  -- Only weapons and armour; shirts and tabards cannot be disenchanted
  if kind == nil or equipLoc == nil or equipLoc == "" or equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" then
    return nil
  end

  if quality == 2 then
    local row = InRange(Data.Uncommon, level)
    if row == nil then
      return nil
    end
    local split = Data.UncommonSplit[kind][row[10] or "normal"]
    local result = {
      { row[3], split[1], row[4], row[5] },
      { row[6], split[2], row[7], row[8] },
    }
    if row[9] and split[3] > 0 then
      result[3] = { row[9], split[3], 1, 1 }
    end
    return result
  elseif quality == 3 then
    local row = InRange(Data.Rare, level)
    if row == nil then
      return nil
    elseif row[4] == nil then
      return { { row[3], 100, 1, 1 } }
    end
    local crystal = Data.RareCrystalPercent
    return { { row[3], 100 - crystal, 1, 1 }, { row[4], crystal, 1, 1 } }
  end
  local row = InRange(Data.Epic, level)
  if row == nil then
    return nil
  elseif row[6] == "mostlyMax" then
    return { { row[3], 100 / 3, row[4], row[4] }, { row[3], 200 / 3, row[5], row[5] } }
  end
  return { { row[3], 100, row[4], row[5] } }
end

function Auctionary.Enchant.GetDisenchantAuctionPrice(itemLink)
  local outcomes = Outcomes(itemLink)
  if outcomes == nil then
    return nil
  end
  local total, missing = 0, false
  for _, outcome in ipairs(outcomes) do
    local price = MaterialPrice(outcome[1])
    if price ~= nil then
      total = total + outcome[2] / 100 * (outcome[3] + outcome[4]) / 2 * price
    elseif outcome[2] >= 1 then
      missing = true
    end
  end
  return math.floor(total), missing
end

function Auctionary.Enchant.GetDisenchantBreakdown(itemLink)
  -- One line per material, even when its amounts have different chances
  local order, byMaterial = {}, {}
  for _, outcome in ipairs(Outcomes(itemLink) or {}) do
    local entry = byMaterial[outcome[1]]
    if entry == nil then
      entry = { outcome[1], 0, outcome[3], outcome[4] }
      byMaterial[outcome[1]] = entry
      order[#order + 1] = entry
    end
    entry[2] = entry[2] + outcome[2]
    entry[3], entry[4] = math.min(entry[3], outcome[3]), math.max(entry[4], outcome[4])
  end
  local lines = {}
  for _, entry in ipairs(order) do
    local amount = entry[3] == entry[4] and tostring(entry[3]) or (entry[3] .. "-" .. entry[4])
    local percent = math.floor(entry[2] * 10 + 0.5) / 10
    lines[#lines + 1] = "  " .. percent .. "%  " .. amount .. " " .. MaterialName(entry[1])
  end
  return lines
end

-- Item level ranges by the dust a green item gives (Sniping filter menu):
-- { low, high, dustID, key }; no gaps, the last one open-ended
local brackets
function Auctionary.Enchant.GetDustBrackets()
  if brackets ~= nil then
    return brackets
  end
  brackets = {}
  for _, row in ipairs(Data.Uncommon) do
    local last = brackets[#brackets]
    if last ~= nil and last.dustID == row[3] then
      last.high = row[2]
    else
      brackets[#brackets + 1] = { low = row[1], high = row[2], dustID = row[3] }
    end
  end
  for index, bracket in ipairs(brackets) do
    if index == 1 then
      bracket.low = 1
    end
    local following = brackets[index + 1]
    bracket.high = following and (following.low - 1) or math.max(bracket.high, 300)
    bracket.key = bracket.low .. "-" .. bracket.high
  end
  return brackets
end

---- Milling and prospecting

-- [herb] = { [pigment] = expected number per 5 herbs }
local millResults
local function MillResults()
  if millResults ~= nil then
    return millResults
  end
  millResults = {}
  for _, tier in ipairs(Data.MillTiers) do
    local function Add(herbs, rule, amounts)
      for _, herb in ipairs(herbs) do
        local low, high = amounts[1], amounts[2]
        local result = { [tier.pigment] = (low + high) / 2 }
        if tier.rare ~= nil then
          result[tier.rare] = rule.rare
        end
        millResults[herb] = result
      end
    end
    Add(tier.lower, Data.MillLower, Data.MillLower.amounts)
    Add(tier.higher, Data.MillHigher, tier.higherAmounts or Data.MillHigher.amounts)
  end
  return millResults
end

-- Value of one item from what 5 of them give
local function ValuePerItem(results)
  if results == nil then
    return nil
  end
  local total, missing = 0, false
  for material, expected in pairs(results) do
    local price = Price(material)
    if price == nil then
      missing = true
    else
      total = total + expected * price
    end
  end
  return math.floor(total / 5), missing
end

function Auctionary.Mill.GetMillAuctionPrice(itemID)
  return ValuePerItem(MillResults()[tonumber(itemID)])
end

function Auctionary.Prospect.GetProspectAuctionPrice(itemID)
  return ValuePerItem(Data.Prospect[tonumber(itemID)])
end
