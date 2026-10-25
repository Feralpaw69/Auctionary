local Auctionary = Auctionary

function Auctionary.Shopping.Lists.GetBatchExportString(listName)
  local items = Auctionary.Shopping.ListManager:GetByName(listName):GetAllItems()

  local result = listName
  for _, item in ipairs(items) do
    result = result .. "^" .. item
  end

  return result
end

--Import multiple instance of lists in the format
--  list name^item 1^item 2\n
function Auctionary.Shopping.Lists.BatchImportFromString(importString)
  -- Remove blank lines
  importString = gsub(importString, "%s+\n", "\n")
  importString = gsub(importString, "\n+", "\n")

  local lists = {strsplit("\n", importString)}

  for index, list in ipairs(lists) do
    local name, items = strsplit("^", list, 2)

    if Auctionary.Shopping.ListManager:GetIndexForName(name) == nil and name ~= nil and name:len() > 0 then
      Auctionary.Shopping.ListManager:Create(name)
    end

    Auctionary.Shopping.Lists.OneImportFromString(name, items)

    if name ~= nil and name:len() > 0 then
      Auctionary.EventBus
        :RegisterSource(Auctionary.Shopping.Lists.BatchImportFromString, "BatchImportFromString")
        :Fire(Auctionary.Shopping.Lists.BatchImportFromString, Auctionary.Shopping.Events.ListImportFinished, name)
        :UnregisterSource(Auctionary.Shopping.Lists.BatchImportFromString)
    end
  end
end

function Auctionary.Shopping.Lists.OneImportFromString(listName, importString)
  Auctionary.Debug.Message("Auctionary.Shopping.Lists.OneImportFromString()", listName, importString)

  if importString == nil then
    -- Otherwise import throws when there are not items in a list
    return
  end

  local list = Auctionary.Shopping.ListManager:GetByName(listName)

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
function Auctionary.Shopping.Lists.OldBatchImportFromString(importString)
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

    if Auctionary.Shopping.ListManager:GetIndexForName(name) == nil then
      Auctionary.Shopping.ListManager:Create(name)
    end

    Auctionary.Shopping.Lists.OldOneImportFromString(name, items)

    Auctionary.EventBus
      :RegisterSource(Auctionary.Shopping.Lists.OldBatchImportFromString, "OldBatchImportFromString")
      :Fire(Auctionary.Shopping.Lists.OldBatchImportFromString, Auctionary.Shopping.Events.ListImportFinished, name)
      :UnregisterSource(Auctionary.Shopping.Lists.OldBatchImportFromString)
  end
end

function Auctionary.Shopping.Lists.OldOneImportFromString(listName, importString)
  local list = Auctionary.Shopping.ListManager:GetByName(listName)

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
function Auctionary.Shopping.Lists.TSMImportFromString(importString)
  -- Remove line breaks
  importString = gsub(importString, "%s", "")

  local items = {}

  local function OnFinish()
    if Auctionary.Shopping.ListManager:GetIndexForName(TSMImportName) ~= nil then
      Auctionary.Shopping.ListManager:Delete(TSMImportName)
    end

    Auctionary.Shopping.ListManager:Create(TSMImportName, true)

    local list = Auctionary.Shopping.ListManager:GetByName(TSMImportName)

    list:ClearItems()
    for _, i in ipairs(items) do
      list:InsertItem(i)
    end

    Auctionary.EventBus
      :RegisterSource(Auctionary.Shopping.Lists.TSMImportFromString, "TSMImportFromString")
      :Fire(Auctionary.Shopping.Lists.TSMImportFromString, Auctionary.Shopping.Events.ListImportFinished, list:GetName())
      :UnregisterSource(Auctionary.Shopping.Lists.TSMImportFromString)
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
    Auctionary.Compat.LoadItem(itemID, function(success)
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
