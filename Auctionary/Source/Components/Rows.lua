-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Row sets: the rows behind a table
-- A row set keeps the rows a table shows, in the order they are shown.
-- New rows are queued and taken over a few hundred per frame, so a search
-- with thousands of results does not freeze the game; a row whose key is
-- already there is skipped. All row sets share one frame, and it only runs
-- while some set still has queued rows.
--
--   local set = Auctionary.Components.CreateRowSet({
--     columns = { ... },                -- see Components/Table.lua
--     rowKey = function(row) end,       -- optional: rows with the same key
--                                       --   are only taken once
--     sorters = { field = Auctionary.Utilities.NumberComparator, ... },
--   })
--   set:Replace(rows)       everything new (shown right away on the next frame)
--   set:Add(rows, final)    more rows; final: nothing else follows
--   set:Clear()             empty, and waiting for rows ("Searching...")
--   set:MarkBusy()          a search started: the table says "Searching..."
--   set:Count(), set:At(i)  what is shown
--   set:KeepSorted(field, direction)  sorted like that while rows come in
--   set:SortBy(field, direction), set:Unsort()
--
-- The table that shows the set is told through set.watcher:
--   watcher:RowsChanged(), watcher:Busy(), watcher:Done()

local ROWS_PER_FRAME = 200

local RowSet = {}
local RowSetMeta = { __index = RowSet }

---- One frame for every set with work

local working = {}
local driver = CreateFrame("Frame")
driver:Hide()

local function Notify(set, what)
  local watcher = set.watcher
  if watcher ~= nil and watcher[what] ~= nil then
    watcher[what](watcher)
  end
end

local function Step(set)
  local queue = set.queue
  local taken = 0
  while taken < ROWS_PER_FRAME and set.queuePos < #queue do
    set.queuePos = set.queuePos + 1
    local row = queue[set.queuePos]
    local key = set.rowKey and set.rowKey(row)
    if key == nil or not set.known[key] then
      if key ~= nil then
        set.known[key] = true
      end
      set.rows[#set.rows + 1] = row
      row.sortingIndex = #set.rows
      taken = taken + 1
    end
  end
  if set.queuePos >= #queue then
    set.queue, set.queuePos = {}, 0
  end
  if taken > 0 and set.sortField ~= nil then
    set:SortBy(set.sortField, set.sortDirection, true)
  end
  set.shown = set.rows
  Notify(set, "RowsChanged")
  if #set.queue == 0 then
    working[set] = nil
    if set.final and not set.doneSent then
      set.doneSent = true
      Notify(set, "Done")
    end
  end
end

driver:SetScript("OnUpdate", function(self)
  for set in pairs(working) do
    Step(set)
  end
  if next(working) == nil then
    self:Hide()
  end
end)

local function Wake(set)
  working[set] = true
  driver:Show()
end

---- A set

function Auctionary.Components.CreateRowSet(definition)
  return setmetatable({
    columns = definition.columns,
    rowKey = definition.rowKey,
    sorters = definition.sorters or {},
    rows = {}, shown = {}, known = {}, queue = {}, queuePos = 0,
    final = true, doneSent = true,
  }, RowSetMeta)
end

-- What the table shows: the rows as of the last frame
function RowSet:Count()
  return #self.shown
end

function RowSet:At(index)
  return self.shown[index]
end

-- New rows are collected at once, but the table keeps showing the old ones
-- until the next frame, so a row that is clicked right now does not vanish
-- under the mouse
function RowSet:Clear()
  self.rows, self.known = {}, {}
  self.queue, self.queuePos = {}, 0
  self.final, self.doneSent = false, false
  Wake(self)
end

function RowSet:Add(rows, final)
  local queue = self.queue
  for _, row in ipairs(rows) do
    queue[#queue + 1] = row
  end
  self.final = final and true or false
  self.doneSent = false
  Wake(self)
end

function RowSet:Replace(rows)
  self:Clear()
  self:Add(rows, true)
end

function RowSet:MarkBusy()
  Notify(self, "Busy")
end

function RowSet:KeepSorted(field, direction)
  self.sortField, self.sortDirection = field, direction
end

function RowSet:SortBy(field, direction, quiet)
  local make = self.sorters[field] or Auctionary.Utilities.StringComparator
  table.sort(self.rows, make(direction, field))
  if not quiet then
    Wake(self)
  end
end

-- Back to the order the rows came in
function RowSet:Unsort()
  self.sortField, self.sortDirection = nil, nil
  table.sort(self.rows, function(a, b) return a.sortingIndex < b.sortingIndex end)
  Wake(self)
end
