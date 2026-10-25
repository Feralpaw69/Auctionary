-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Keys of items in the price database
-- Most items are stored under their item ID ("36913"). Weapons and armour
-- with a random suffix ("... of the Bear") also get their own key
-- "gr:<itemID>:<suffix name>", because each suffix sells for its own price.

local U = Auctionary.Utilities

-- Item ID as a string from an item link or "item:..." string
function U.BasicDBKeyFromLink(itemLink)
  if type(itemLink) ~= "string" then
    return nil
  end
  return itemLink:match("|Hitem:(%-?%d+)") or itemLink:match("^item:(%-?%d+)")
end

local function IsGear(itemLink)
  local classID = Auctionary.Compat.GetItemClassID(itemLink)
  local classes = Auctionary.Constants.ItemClass
  return classID ~= nil and (classID == classes.Weapon or classID == classes.Armor)
end

-- 7th number after "item:" (item:id:enchant:gem:gem:gem:gem:suffix:...)
local function SuffixOf(itemLink)
  local suffix = tonumber(itemLink:match("item:%-?%d+:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*:(%-?%d+)"))
  if suffix ~= nil and suffix ~= 0 then
    return suffix
  end
end

-- "of the Bear": the link shows the full name ("Lord's Crest of the Bear"),
-- the client's item info only the base name ("Lord's Crest"); the suffix is
-- what the link adds. Without a name in the link the suffix number is used.
local function SuffixName(itemLink, itemID, suffix)
  local full = itemLink:match("|h%[(.-)%]|h")
  local base = GetItemInfo(tonumber(itemID))
  if full ~= nil and base ~= nil and #full > #base and full:sub(1, #base) == base then
    local name = full:sub(#base + 1):gsub("^%s+", "")
    if name ~= "" then
      return name
    end
  end
  return suffix
end

local function KeysOf(itemLink, itemID)
  local suffix = IsGear(itemLink) and SuffixOf(itemLink)
  if not suffix then
    return { itemID }
  end
  local name = SuffixName(itemLink, itemID, suffix)
  local key = "gr:" .. itemID .. ":" .. name
  -- Earlier versions saved some suffixes under their number ("gr:123:-9");
  -- those prices move to the named key the first time the item is seen
  if name ~= suffix and Auctionary.Database ~= nil then
    Auctionary.Database:MoveEntry("gr:" .. itemID .. ":" .. suffix, key)
  end
  return { key, itemID }
end

-- callback(keys): most specific key first. Runs at once when the client
-- knows the item, otherwise as soon as its data has arrived.
function U.DBKeyFromLink(itemLink, callback)
  local itemID = U.BasicDBKeyFromLink(itemLink)
  if itemID == nil then
    callback({})
  elseif Auctionary.Compat.IsItemCached(itemID) then
    callback(KeysOf(itemLink, itemID))
  else
    Auctionary.Compat.LoadItem(itemID, function(loaded)
      callback(loaded and KeysOf(itemLink, itemID) or { itemID })
    end)
  end
end
