local Auctionary = Auctionary

-- "1234" for |Hitem:1234:...|h links or plain "item:1234" strings
function Auctionary.Utilities.BasicDBKeyFromLink(itemLink)
  if itemLink ~= nil then
    local _, _, itemString = string.find(itemLink, "^|c%x+|H(.+)|h%[.*%]")
    if itemString == nil and string.find(itemLink, "^item") then
      itemString = itemLink
    end
    if itemString ~= nil then
      local linkType, itemId = strsplit(":", itemString)
      if linkType == "item" then
        return itemId;
      end
    end
  end
  return nil
end

-- Random suffix ("of the Bear") from a 3.3.5 item link:
-- item:itemID:enchant:gem1:gem2:gem3:gem4:suffixID:uniqueID:linkLevel
function Auctionary.Utilities.GetSuffixIDFromLink(itemLink)
  local suffix = tonumber((itemLink:match("item:%-?%d+:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*:(%-?%d+)")))
  if suffix == 0 then
    return nil
  end
  return suffix
end

local function GetKeys(itemLink, basicKey)
  local classID = Auctionary.Compat.GetItemClassID(itemLink)
  if classID ~= nil and Auctionary.Utilities.IsEquipment(classID) then
    local suffix = Auctionary.Utilities.GetSuffixIDFromLink(itemLink)
    if suffix ~= nil then
      local suffixStringID = Auctionary.Utilities.SuffixIDToSuffixStringID[suffix]
      local suffixString = Auctionary.Utilities.SuffixStringIDTOSuffixString[suffixStringID]
      if suffixString then
        return {"gr:" .. basicKey .. ":" .. suffixString, basicKey}
      else
        -- Suffix not in the data table: still keep it apart from other suffixes
        return {"gr:" .. basicKey .. ":" .. suffix, basicKey}
      end
    end
  end
  return {basicKey}
end

-- Calls callback with a list of database keys, most specific first. The
-- callback runs immediately when the item is in the client's item cache.
function Auctionary.Utilities.DBKeyFromLink(itemLink, callback)
  local basicKey = Auctionary.Utilities.BasicDBKeyFromLink(itemLink)

  if basicKey == nil then
    callback({})
    return
  end

  if Auctionary.Compat.IsItemCached(basicKey) then
    callback(GetKeys(itemLink, basicKey))
  else
    Auctionary.Compat.LoadItem(basicKey, function(success)
      if success then
        callback(GetKeys(itemLink, basicKey))
      else
        callback({basicKey})
      end
    end)
  end
end

function Auctionary.Utilities.DBKeysFromMultipleLinks(itemLinks, callback)
  local result = {}
  if #itemLinks == 0 then
    callback(result)
    return
  end
  local finished = false
  for index, link in ipairs(itemLinks) do
    Auctionary.Utilities.DBKeyFromLink(link, function(dbKeys)
      result[index] = dbKeys
      if finished then
        return
      end
      for i = 1, #itemLinks do
        if result[i] == nil then
          return
        end
      end
      finished = true
      callback(result)
    end)
  end
end
