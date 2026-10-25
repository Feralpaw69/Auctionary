-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2
local U = Auctionary.Utilities

---- Small helpers used all over the addon

-- Debug output (chat), switched with /aury debug
function Auctionary.Debug.IsOn()
  return Auctionary.Config.Get(Auctionary.Config.Options.DEBUG) == true
end

function Auctionary.Debug.Toggle()
  Auctionary.Config.Set(Auctionary.Config.Options.DEBUG, not Auctionary.Debug.IsOn())
end

function Auctionary.Debug.Message(message, ...)
  if Auctionary.Debug.IsOn() then
    print("|cff20ff20" .. tostring(message) .. "|r", ...)
  end
end

-- count entries of list, beginning at first
function U.Slice(list, first, count)
  local part = {}
  local last = math.min(#list, first + count - 1)
  for index = first, last do
    part[#part + 1] = list[index]
  end
  return part
end

function U.TableKeys(map)
  local keys = {}
  for key in pairs(map) do
    keys[#keys + 1] = key
  end
  return keys
end

-- Words of a chat command, lower case
function U.SplitCommand(text)
  local words = {}
  for word in string.gmatch(string.lower(text or ""), "%S+") do
    words[#words + 1] = word
  end
  return words
end

function U.GetNameFromLink(itemLink)
  return itemLink and itemLink:match("%[(.-)%]")
end

-- " x20" in light blue, after prices for a whole stack
function U.CreateCountString(count)
  return "|cff87abff x" .. count .. "|r"
end

local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"

-- Money with coin icons where silver and copper always take two digits once
-- a bigger coin is shown, so prices in a column line up
function U.CreatePaddedMoneyString(copper)
  copper = math.floor(copper or 0)
  local gold = math.floor(copper / 10000)
  local silver = math.floor(copper / 100) % 100
  local rest = copper % 100
  if gold > 0 then
    return string.format("%d %s %02d %s %02d %s", gold, GOLD, silver, SILVER, rest, COPPER)
  elseif silver > 0 then
    return string.format("%d %s %02d %s", silver, SILVER, rest, COPPER)
  end
  return string.format("%d %s", rest, COPPER)
end

-- Day and month names in the client's language (the game's own strings)
local WEEKDAYS = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }
local MONTHS = { "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY",
  "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER" }

local function GameName(prefix, english)
  local name = _G[prefix .. english]
  if type(name) == "string" and name ~= "" then
    return name
  end
  return english:sub(1, 1) .. english:sub(2):lower()
end

-- "Today", or the weekday and date of a moment
function U.PrettyDate(moment)
  local when, today = date("*t", moment), date("*t")
  if when.year == today.year and when.yday == today.yday then
    return AUCTIONARY2_L_TODAY or "Today"
  end
  return GameName("WEEKDAY_", WEEKDAYS[when.wday]) .. ", " .. GameName("MONTH_", MONTHS[when.month]) .. " " .. when.day
end

-- Below this unit price a new auction is most likely a typo: 70% of the
-- reference for cheap items, sliding down to 30% for expensive ones
function U.PriceWarningThreshold(reference)
  if reference == nil or reference <= 0 then
    return 0
  end
  local share = 0.3 + 0.4 * math.min(1, 10000 / reference)
  return reference * share
end

---- Sorting of table rows
-- Equal values keep the order in which the rows arrived (sortingIndex), so
-- the list does not jump around when it is sorted again.

local function Comparator(order, field, empty)
  local ascending = order == Auctionary.Constants.SORT.ASCENDING
  return function(left, right)
    local a, b = left and left[field], right and right[field]
    if a == nil then a = empty end
    if b == nil then b = empty end
    if a ~= b then
      if ascending then
        return a < b
      end
      return a > b
    end
    return ((left and left.sortingIndex) or 0) < ((right and right.sortingIndex) or 0)
  end
end

function U.NumberComparator(order, field)
  return Comparator(order, field, 0)
end

function U.StringComparator(order, field)
  return Comparator(order, field, "")
end

---- Chat and item helpers

-- A line in the chat, marked with the addon's name
function U.Message(text)
  print("|cff87abffAuctionary 2.0:|r " .. tostring(text))
end

-- "aarrggbb" colour of an item link (white if it has none)
function U.GetQualityColorFromLink(itemLink)
  return itemLink:match("|c(%x%x%x%x%x%x%x%x)") or "ffffffff"
end

-- "Rare" in the colour of rare items
function U.CreateColoredQuality(quality)
  local name = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
  return Auctionary.Compat.GetQualityColor(quality):WrapTextInColorCode(name)
end

-- itemInfo: the values of GetItemInfo in a table. Legendary and artifact
-- items cannot be sold to a vendor even when they list a price.
function U.IsVendorable(itemInfo)
  local price = itemInfo[Auctionary.Constants.ITEM_INFO.SELL_PRICE]
  local quality = itemInfo[Auctionary.Constants.ITEM_INFO.RARITY]
  return price ~= nil and price > 0 and quality ~= 5 and quality ~= 6
end
