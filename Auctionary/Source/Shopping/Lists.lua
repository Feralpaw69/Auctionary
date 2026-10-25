-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Shopping lists
-- Saved in AUCTIONARY2_SHOPPING_LISTS as an array of
--   { name = "...", items = { "search term", ... }, isTemporary = bool }
-- sorted by name. Every change is announced on the event bus with the name
-- of the list (ListsChanged for lists, ListItemsChanged for their items).

local Events = Auctionary.Shopping.Events
local manager = {}
local listMethods = {}
local wrappers = setmetatable({}, { __mode = "k" })
Auctionary.EventBus:RegisterSource(manager, "shopping lists")

local function Data()
  if type(AUCTIONARY2_SHOPPING_LISTS) ~= "table" then
    AUCTIONARY2_SHOPPING_LISTS = {}
  end
  return AUCTIONARY2_SHOPPING_LISTS
end

local function Announce(eventName, listName)
  Auctionary.EventBus:Fire(manager, eventName, listName)
end

local function Wrap(data)
  local list = wrappers[data]
  if list == nil then
    list = setmetatable({ data = data }, { __index = listMethods })
    wrappers[data] = list
  end
  return list
end

---- One list

function listMethods:GetName()
  return self.data.name
end

function listMethods:Rename(newName)
  assert(type(newName) == "string" and manager:GetIndexForName(newName) == nil, "name already used")
  self.data.name = newName
  manager:Sort()
  Announce(Events.ListsChanged, newName)
end

function listMethods:IsTemporary()
  return self.data.isTemporary == true
end

function listMethods:MakePermanent()
  self.data.isTemporary = false
  Announce(Events.ListsChanged, self.data.name)
end

function listMethods:GetItemCount()
  return #self.data.items
end

function listMethods:GetItemByIndex(index)
  return self.data.items[index]
end

function listMethods:GetAllItems()
  local copy = {}
  for index, item in ipairs(self.data.items) do
    copy[index] = item
  end
  return copy
end

function listMethods:DeleteItem(index)
  assert(self.data.items[index] ~= nil, "no such item")
  table.remove(self.data.items, index)
  Announce(Events.ListItemsChanged, self.data.name)
end

function listMethods:AlterItem(index, newItem)
  assert(self.data.items[index] ~= nil and type(newItem) == "string")
  self.data.items[index] = newItem
  Announce(Events.ListItemsChanged, self.data.name)
end

function listMethods:InsertItem(newItem, index)
  assert(type(newItem) == "string")
  if index ~= nil then
    table.insert(self.data.items, index, newItem)
  else
    self.data.items[#self.data.items + 1] = newItem
  end
  Announce(Events.ListItemsChanged, self.data.name)
end

function listMethods:ClearItems()
  self.data.items = {}
end

function listMethods:AppendItems(newItems)
  for _, item in ipairs(newItems) do
    self.data.items[#self.data.items + 1] = item
  end
  Announce(Events.ListItemsChanged, self.data.name)
end

-- Alphabetical, ignoring case and the quotes of exact searches
local function SortKey(text)
  return (text:lower():gsub("\"", ""))
end

function listMethods:Sort()
  table.sort(self.data.items, function(a, b)
    return SortKey(a) < SortKey(b)
  end)
  Announce(Events.ListItemsChanged, self.data.name)
end

---- All lists

function manager:Sort()
  table.sort(Data(), function(a, b)
    local left, right = a.name:lower(), b.name:lower()
    if left == right then
      return a.name < b.name
    end
    return left < right
  end)
  Announce(Events.ListsChanged)
end

function manager:Create(name, isTemporary)
  assert(type(name) == "string")
  local lists = Data()
  lists[#lists + 1] = { name = name, items = {}, isTemporary = isTemporary == true }
  self:Sort()
  Announce(Events.ListsChanged, name)
end

function manager:GetIndexForName(name)
  for index, data in ipairs(Data()) do
    if data.name == name then
      return index
    end
  end
end

function manager:GetCount()
  return #Data()
end

function manager:GetByIndex(index)
  local data = Data()[index]
  assert(data ~= nil, "no such list")
  return Wrap(data)
end

function manager:GetByName(name)
  return self:GetByIndex(self:GetIndexForName(name))
end

function manager:Delete(name)
  local index = self:GetIndexForName(name)
  assert(index ~= nil, "no such list")
  table.remove(Data(), index)
  Announce(Events.ListsChanged, name)
end

-- prefix, or prefix 2, prefix 3 ... whatever is still free
function manager:GetUnusedName(prefix)
  local name, number = prefix, 1
  while self:GetIndexForName(name) ~= nil do
    number = number + 1
    name = prefix .. " " .. number
  end
  return name
end

function Auctionary.Shopping.CreateListManager()
  -- Temporary lists (from imports) do not survive a reload
  local kept = {}
  for _, data in ipairs(Data()) do
    if not data.isTemporary and type(data.name) == "string" and type(data.items) == "table" then
      kept[#kept + 1] = data
    end
  end
  AUCTIONARY2_SHOPPING_LISTS = kept
  manager:Sort()
  return manager
end

---- Export and import
-- Export: one line per list, "name^item^item".
-- Import also understands an older form ("*name" followed by one item per
-- line) and item IDs separated by commas ("i:123,i:456" or "123,456"),
-- which go into a temporary list.

Auctionary.Shopping.Lists = Auctionary.Shopping.Lists or {}

function Auctionary.Shopping.Lists.GetBatchExportString(name)
  local items = manager:GetByName(name):GetAllItems()
  table.insert(items, 1, name)
  return table.concat(items, "^")
end

-- Parts of "a^b^c"
local function SplitCarets(text)
  local parts = {}
  for part in (text .. "^"):gmatch("(.-)%^") do
    parts[#parts + 1] = part
  end
  return parts
end

local function Finished(name)
  Auctionary.EventBus:Fire(manager, Events.ListsImported, name)
end

local function Fill(name, items, isTemporary)
  if manager:GetIndexForName(name) == nil then
    manager:Create(name, isTemporary)
  end
  local list = manager:GetByName(name)
  list:ClearItems()
  list:AppendItems(items)
  Finished(name)
end

local function ImportIDs(text)
  local ids = {}
  for kind, id in text:gmatch("(%a?):?(%d+)") do
    if kind ~= "p" then
      ids[#ids + 1] = tonumber(id)
    end
  end
  local name = (AUCTIONARY2_L_IMPORTED or "Imported") .. " (" .. (AUCTIONARY2_L_TEMPORARY or "temporary") .. ")"
  local items, left = {}, #ids
  local function Done()
    if manager:GetIndexForName(name) ~= nil then
      manager:Delete(name)
    end
    Fill(name, items, true)
  end
  if left == 0 then
    Done()
    return
  end
  for index, itemID in ipairs(ids) do
    Auctionary.Compat.LoadItem(itemID, function(success)
      local itemName = success and GetItemInfo(itemID)
      items[index] = itemName and ("\"" .. itemName .. "\"") or "IMPORT ERROR"
      left = left - 1
      if left == 0 then
        Done()
      end
    end)
  end
end

function Auctionary.Shopping.Lists.BatchImportFromString(text)
  text = text:gsub("\r", "")
  if not text:find("[%^%*\n]") and text:find("%d") and not text:find("[^%s%d,:ip]") then
    ImportIDs(text)
    return
  end

  if text:match("^%s*%*") then
    -- *name, then one item per line
    for block in text:gmatch("%*+([^%*]+)") do
      local lines = {}
      for line in block:gmatch("[^\n]+") do
        line = strtrim(line)
        if line ~= "" then
          lines[#lines + 1] = line
        end
      end
      local name = table.remove(lines, 1)
      if name ~= nil then
        Fill(name, lines)
      end
    end
    return
  end

  for line in text:gmatch("[^\n]+") do
    local parts = SplitCarets(strtrim(line))
    local name = table.remove(parts, 1)
    if name ~= nil and name ~= "" then
      Fill(name, parts)
    end
  end
end

---- Recent searches of the Shopping tab, newest first

Auctionary.Shopping.Recents = {}

local function Recents()
  if type(AUCTIONARY2_RECENT_SEARCHES) ~= "table" then
    AUCTIONARY2_RECENT_SEARCHES = {}
  end
  return AUCTIONARY2_RECENT_SEARCHES
end

local function RemoveRecent(text)
  local recents = Recents()
  for index = #recents, 1, -1 do
    if recents[index] == text then
      table.remove(recents, index)
      return true
    end
  end
  return false
end

function Auctionary.Shopping.Recents.Save(text)
  RemoveRecent(text)
  local recents = Recents()
  table.insert(recents, 1, text)
  while #recents > Auctionary.Constants.RecentsListLimit do
    table.remove(recents)
  end
  Auctionary.EventBus:Fire(manager, Events.RecentsChanged)
end

function Auctionary.Shopping.Recents.DeleteEntry(text)
  if RemoveRecent(text) then
    Auctionary.EventBus:Fire(manager, Events.RecentsChanged)
  end
end

function Auctionary.Shopping.Recents.GetAll()
  return Recents()
end
