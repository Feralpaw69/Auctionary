-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Search terms of the Shopping tab
-- A term is one line with the fields separated by ";":
--   name;category;min item level;max item level;min level;max level;
--   min crafted level;max crafted level;min price;max price;quality;
--   tier;expansion;quantity
-- Prices are in gold. A name in quotes is searched exactly. Empty or 0
-- means "no limit". Saved shopping lists use this form, so it stays as is.

local FIELDS = {
  "query", "categoryKey", "minItemLevel", "maxItemLevel", "minLevel", "maxLevel",
  "minCraftedLevel", "maxCraftedLevel", "minPrice", "maxPrice", "quality",
  "tier", "expansion", "quantity",
}

local function Number(text)
  local value = tonumber(text)
  if value == nil or value == 0 then
    return nil
  end
  return value
end

function Auctionary.Search.SplitAdvancedSearch(term)
  local raw = {}
  local position = 1
  for value in ((term or "") .. ";"):gmatch("(.-);") do
    raw[FIELDS[position] or position] = value
    position = position + 1
  end

  local query = raw.query or ""
  local exact = query:match('^"(.*)"$')
  local search = {
    searchString = exact or query,
    isExact = exact ~= nil,
    categoryKey = raw.categoryKey or "",
  }
  for index = 3, #FIELDS do
    local name = FIELDS[index]
    search[name] = Number(raw[name])
  end
  -- Prices are written in gold, used in copper
  if search.minPrice then search.minPrice = search.minPrice * 10000 end
  if search.maxPrice then search.maxPrice = search.maxPrice * 10000 end
  return search
end

-- 0 means "no limit" as well, so it is left empty
local function Text(value)
  if value == nil or value == 0 then
    return ""
  end
  return tostring(value)
end

function Auctionary.Search.ReconstituteAdvancedSearch(search)
  local query = search.searchString or ""
  if search.isExact then
    query = '"' .. query .. '"'
  end
  return table.concat({
    query,
    search.categoryKey or "",
    Text(search.minItemLevel), Text(search.maxItemLevel),
    Text(search.minLevel), Text(search.maxLevel),
    Text(search.minCraftedLevel), Text(search.maxCraftedLevel),
    Text(search.minPrice and search.minPrice / 10000), Text(search.maxPrice and search.maxPrice / 10000),
    Text(search.quality), Text(search.tier), Text(search.expansion),
    Text(search.quantity),
  }, ";")
end

-- "lvl 70-80", "lvl >= 70", "lvl = 80" ...
local function Range(label, low, high)
  if low ~= nil and low == high then
    return label .. " = " .. low
  elseif low ~= nil and high ~= nil then
    return label .. " " .. low .. "-" .. high
  elseif low ~= nil then
    return label .. " >= " .. low
  elseif high ~= nil then
    return label .. " <= " .. high
  end
end

local function Money(copper)
  return copper and Auctionary.Compat.GetMoneyString(copper, true)
end

-- Readable form for lists: name [category, price ..., lvl ..., x20, quality]
function Auctionary.Search.PrettifySearchString(term)
  local search = Auctionary.Search.SplitAdvancedSearch(term)
  local parts = {}
  local function Add(text)
    if text ~= nil and text ~= "" then
      parts[#parts + 1] = text
    end
  end
  Add(search.categoryKey)
  Add(Range("price", Money(search.minPrice), Money(search.maxPrice)))
  Add(Range("lvl", search.minLevel, search.maxLevel))
  Add(Range("ilvl", search.minItemLevel, search.maxItemLevel))
  if search.quantity then
    Add("|cff87abffx" .. search.quantity .. "|r")
  end
  Add(Range("clvl", search.minCraftedLevel, search.maxCraftedLevel))
  if search.quality and ITEM_QUALITY_COLORS[search.quality] then
    Add(Auctionary.Utilities.CreateColoredQuality(search.quality))
  end

  local name = search.isExact and ('"' .. search.searchString .. '"') or search.searchString
  if #parts == 0 then
    return name
  end
  if name == "" then
    return "[" .. table.concat(parts, ", ") .. "]"
  end
  return name .. " [" .. table.concat(parts, ", ") .. "]"
end
