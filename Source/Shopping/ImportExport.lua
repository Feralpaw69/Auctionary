local Auctionator = Auctionary

function Auctionator.Shopping.Lists.GetBatchExportString(listName)
  local items = Auctionator.Shopping.ListManager:GetByName(listName):GetAllItems()

  local result = listName
  for _, item in ipairs(items) do
    result = result .. "^" .. item
  end

  return result
end

--Import multiple instance of lists in the format
--  list name^item 1^item 2\n
function Auctionator.Shopping.Lists.BatchImportFromString(importString)
  -- Remove blank lines
  importString = gsub(importString, "%s+\n", "\n")
  importString = gsub(importString, "\n+", "\n")

  local lists = {strsplit("\n", importString)}

  for index, list in ipairs(lists) do
    local name, items = strsplit("^", list, 2)

    if Auctionator.Shopping.ListManager:GetIndexForName(name) == nil and name ~= nil and name:len() > 0 then
      Auctionator.Shopping.ListManager:Create(name)
    end

    Auctionator.Shopping.Lists.OneImportFromString(name, items)

    if name ~= nil and name:len() > 0 then
      Auctionator.EventBus
        :RegisterSource(Auctionator.Shopping.Lists.BatchImportFromString, "BatchImportFromString")
        :Fire(Auctionator.Shopping.Lists.BatchImportFromString, Auctionator.Shopping.Events.ListImportFinished, name)
        :UnregisterSource(Auctionator.Shopping.Lists.BatchImportFromString)
    end
  end
end

function Auctionator.Shopping.Lists.OneImportFromString(listName, importString)
  Auctionator.Debug.Message("Auctionator.Shopping.Lists.OneImportFromString()", listName, importString)

  if importString == nil then
    -- Otherwise import throws when there are not items in a list
    return
  end

  local list = Auctionator.Shopping.ListManager:GetByName(listName)

  local items = {}
  for _, item in ipairs({strsplit("^", importString)}) do
    table.insert(items, item)
  end
  list:ClearItems()
  list:AppendItems(items)
end

--Import multiple instances of lists in the format
-- **List Name\n
-- Item 1\n
-- Item 2\n
function Auctionator.Shopping.Lists.OldBatchImportFromString(importString)
  -- Remove trailing and leading spaces
  importString = gsub(importString, "%s+\n", "\n")
  importString = gsub(importString, "\n%s+", "\n")
  -- Remove blank lines
  importString = gsub(importString, "\n\n", "\n")
  importString = gsub(importString, "^\n", "")
  -- Simplify *** to *
  importString = gsub(importString, "*+%s*", "*")
  -- Remove first *
  importString = gsub(importString, "^*", "")

  local lists = {strsplit("*", importString)}

  for index, list in ipairs(lists) do
    local name, items = strsplit("\n", list, 2)

    if Auctionator.Shopping.ListManager:GetIndexForName(name) == nil then
      Auctionator.Shopping.ListManager:Create(name)
    end

    Auctionator.Shopping.Lists.OldOneImportFromString(name, items)

    Auctionator.EventBus
      :RegisterSource(Auctionator.Shopping.Lists.OldBatchImportFromString, "OldBatchImportFromString")
      :Fire(Auctionator.Shopping.Lists.OldBatchImportFromString, Auctionator.Shopping.Events.ListImportFinished, name)
      :UnregisterSource(Auctionator.Shopping.Lists.OldBatchImportFromString)
  end
end

function Auctionator.Shopping.Lists.OldOneImportFromString(listName, importString)
  local list = Auctionator.Shopping.ListManager:GetByName(listName)

  importString = gsub(importString, "\n$", "")

  list:ClearItems()
  for _, item in ipairs({strsplit("\n", importString)}) do
    list:InsertItem(item)
  end
end

local TSMImportName = AUCTIONARY_L_IMPORTED .. " (" .. AUCTIONARY_L_TEMPORARY_LOWER_CASE .. ")"
local IMPORT_ERROR = "IMPORT ERROR"

--Import a TSM group in the format
--  i:itemID 1,i:itemID 2 OR
--  itemID 1,itemID 2
--
--Saves the result in a temporary list and fires a list creation event.
--Item names that the server doesn't supply are imported as "IMPORT ERROR".
function Auctionator.Shopping.Lists.TSMImportFromString(importString)
  -- Remove line breaks
  importString = gsub(importString, "%s", "")

  local items = {}

  local function OnFinish()
    if Auctionator.Shopping.ListManager:GetIndexForName(TSMImportName) ~= nil then
      Auctionator.Shopping.ListManager:Delete(TSMImportName)
    end

    Auctionator.Shopping.ListManager:Create(TSMImportName, true)

    local list = Auctionator.Shopping.ListManager:GetByName(TSMImportName)

    list:ClearItems()
    for _, i in ipairs(items) do
      list:InsertItem(i)
    end

    Auctionator.EventBus
      :RegisterSource(Auctionator.Shopping.Lists.TSMImportFromString, "TSMImportFromString")
      :Fire(Auctionator.Shopping.Lists.TSMImportFromString, Auctionator.Shopping.Events.ListImportFinished, list:GetName())
      :UnregisterSource(Auctionator.Shopping.Lists.TSMImportFromString)
  end

  local entries = {}
  for itemType, stringID in importString:gmatch("([ip]?):?(%d+)") do
    -- "p:" entries are battle pets, which don't exist in this client
    if itemType ~= "p" then
      table.insert(entries, tonumber(stringID))
    end
  end

  local left = #entries
  if left == 0 then
    OnFinish()
    return
  end

  for index, itemID in ipairs(entries) do
    Auctionator.Compat.LoadItem(itemID, function(success)
      if success then
        items[index] = "\"" .. (GetItemInfo(itemID)) .. "\""
      else
        items[index] = IMPORT_ERROR
      end
      left = left - 1
      if left == 0 then
        OnFinish()
      end
    end)
  end
end
