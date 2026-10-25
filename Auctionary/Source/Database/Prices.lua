-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Price database
-- One entry per item (per realm and faction), stored as a string (see
-- Codec.lua) in AUCTIONARY2_PRICE_DATABASE. Per day it keeps the highest and
-- lowest minimum price seen, the most auctions seen, and the sum and number
-- of scans (for the average). Days older than the history setting are
-- dropped whenever an item gets a new price, and for all items a few seconds
-- after login and whenever the setting changes (a few hundred per frame).
--
-- New prices are not written right away: a big scan delivers thousands, so
-- they wait in a queue and are written a few dozen per frame. Reading an
-- item that is still waiting writes it first. Logging out writes the rest.

local Codec = Auctionary.DatabaseCodec
local WRITES_PER_FRAME = 50
local PRUNES_PER_FRAME = 250
-- Decoded histories kept for reading again; a decoded history takes about
-- 2 KB, so keeping every item read (a scan reads them all) grew to 40 MB
local DECODED_LIMIT = 300
local PRUNE_DELAY = 10
local FIELDS = { "h", "l", "a", "s", "n" }

local function Today()
  return math.floor((time() - Auctionary.Constants.SCAN_DAY_0) / 86400)
end

-- Days up to this one are dropped
local function OldestDay()
  local keep = tonumber(Auctionary.Config.Get(Auctionary.Config.Options.PRICE_HISTORY_DAYS)) or 21
  return Today() - math.max(1, keep)
end

local Prices = {}
local PricesMeta = { __index = Prices }

function Auctionary.CreatePriceDatabase(db)
  local object = setmetatable({
    db = db,
    waiting = {},      -- [dbKey] = { price, available }
    order = {},        -- keys in the order they arrived
    decoded = {},      -- [dbKey] = { raw = stored string, data = table }
    decodedCount = 0,
    revision = 0,      -- goes up with every written price (tooltips use it)
  }, PricesMeta)
  object.writer = CreateFrame("Frame")
  object.writer:Hide()
  object.writer:SetScript("OnUpdate", function()
    object:WriteSome(WRITES_PER_FRAME)
  end)

  -- Older versions kept unwritten prices inside the entry itself
  for dbKey, value in pairs(db) do
    if type(value) == "table" and value.pending then
      db[dbKey] = value.old
      object:SetPrice(dbKey, value.buyoutPrice, value.available)
    end
  end
  object:StartPruning(PRUNE_DELAY)
  return object
end

-- Forgets the decoded histories (they are decoded again when needed)
function Prices:ReleaseCache()
  self.decoded = {}
  self.decodedCount = 0
end

-- The item's history as a table (nil if unknown). The decoded table is kept
-- until the stored string changes.
function Prices:Read(dbKey)
  if self.waiting[dbKey] ~= nil then
    self:Write(dbKey)
  end
  local raw = self.db[dbKey]
  if type(raw) ~= "string" then
    return type(raw) == "table" and raw or nil
  end
  local cached = self.decoded[dbKey]
  if cached ~= nil and cached.raw == raw then
    return cached.data
  end
  local data = Codec.Deserialize(raw)
  if cached == nil then
    if self.decodedCount >= DECODED_LIMIT then
      self:ReleaseCache()
    end
    self.decodedCount = self.decodedCount + 1
  end
  self.decoded[dbKey] = { raw = raw, data = data }
  return data
end

function Prices:SetPrice(dbKey, price, available)
  if self.waiting[dbKey] == nil then
    self.order[#self.order + 1] = dbKey
  end
  self.waiting[dbKey] = { price, available }
  self.writer:Show()
end

function Prices:WriteSome(count)
  local written = 0
  while written < count and #self.order > 0 do
    local dbKey = table.remove(self.order)
    if self.waiting[dbKey] ~= nil then
      self:Write(dbKey)
      written = written + 1
    end
  end
  if #self.order == 0 then
    self.writer:Hide()
  end
end

-- Everything that waits (logging out)
function Prices:Flush()
  self:WriteSome(math.huge)
end

function Prices:Write(dbKey)
  local new = self.waiting[dbKey]
  self.waiting[dbKey] = nil
  if new == nil then
    return
  end
  local price, available = new[1], new[2]

  local raw = self.db[dbKey]
  local data = type(raw) == "string" and Codec.Deserialize(raw) or { h = {}, l = {}, a = {}, s = {}, n = {} }
  for _, field in ipairs(FIELDS) do
    data[field] = data[field] or {}
  end

  local day = tostring(Today())
  data.m = price
  -- A day of an older version without scan counts: its price is one scan
  if data.n[day] == nil and (data.l[day] or data.h[day]) then
    data.s[day], data.n[day] = data.l[day] or data.h[day], 1
  end
  data.s[day] = (data.s[day] or 0) + price
  data.n[day] = (data.n[day] or 0) + 1

  local high = data.h[day]
  if high == nil or price > high then
    data.h[day] = price
    high = price
  end
  -- The low is only stored when it differs from the high
  if price < high and (data.l[day] == nil or price < data.l[day]) then
    data.l[day] = price
  end
  if available ~= nil then
    data.a[day] = math.max(data.a[day] or 0, available)
  end

  local oldest = OldestDay()
  for _, field in ipairs(FIELDS) do
    for oldDay in pairs(data[field]) do
      if (tonumber(oldDay) or 0) <= oldest then
        data[field][oldDay] = nil
      end
    end
  end

  self.db[dbKey] = Codec.Serialize(data)
  self.decoded[dbKey] = nil
  self.revision = self.revision + 1
end

-- Moves an entry to a new key, unless the new key has one already
function Prices:MoveEntry(oldKey, newKey)
  local db = self.db
  if db[oldKey] == nil or db[newKey] ~= nil or self.waiting[newKey] ~= nil then
    return
  end
  if self.waiting[oldKey] ~= nil then
    self:Write(oldKey)
  end
  db[newKey], db[oldKey] = db[oldKey], nil
  self.decoded[oldKey] = nil
  self.revision = self.revision + 1
end

---- Dropping old days of every item
-- Runs in the background, a few hundred items per frame. Only items that
-- have a day older than the setting are decoded and written again.

local function HasOldDay(raw, oldest)
  for day in raw:gmatch("[;,](%d+):") do
    if tonumber(day) <= oldest then
      return true
    end
  end
  return false
end

function Prices:PruneSome(count)
  local keys, oldest, db = self.pruneKeys, OldestDay(), self.db
  local done = 0
  while done < count and self.prunePosition <= #keys do
    local dbKey = keys[self.prunePosition]
    self.prunePosition = self.prunePosition + 1
    local raw = db[dbKey]
    if type(raw) == "string" and self.waiting[dbKey] == nil and HasOldDay(raw, oldest) then
      local data = Codec.Deserialize(raw)
      for _, field in ipairs(FIELDS) do
        for day in pairs(data[field]) do
          if (tonumber(day) or 0) <= oldest then
            data[field][day] = nil
          end
        end
      end
      if next(data.h) == nil then
        -- Nothing seen within the kept days: only the last price stays
        db[dbKey] = Codec.Serialize({ m = data.m, h = {} })
      else
        db[dbKey] = Codec.Serialize(data)
      end
      self.decoded[dbKey] = nil
      self.pruned = self.pruned + 1
    end
    done = done + 1
  end
  if self.prunePosition > #keys then
    self.pruneKeys = nil
    self.pruner:Hide()
    if self.pruned > 0 then
      self.revision = self.revision + 1
    end
  end
end

-- delay: seconds to wait first (nil: start now)
function Prices:StartPruning(delay)
  local keys = {}
  for dbKey, raw in pairs(self.db) do
    if type(raw) == "string" then
      keys[#keys + 1] = dbKey
    end
  end
  self.pruneKeys, self.prunePosition, self.pruned = keys, 1, 0
  if self.pruner == nil then
    self.pruner = CreateFrame("Frame")
    self.pruner:Hide()
    self.pruner:SetScript("OnUpdate", function(frame, elapsed)
      if frame.wait > 0 then
        frame.wait = frame.wait - elapsed
        return
      end
      -- Not while fighting
      if InCombatLockdown() or self.pruneKeys == nil then
        return
      end
      self:PruneSome(PRUNES_PER_FRAME)
    end)
  end
  self.pruner.wait = delay or 0
  self.pruner:Show()
end

---- Reading

-- The last price is the start of the stored string, so it is read without
-- decoding the whole history
function Prices:GetPrice(dbKey)
  if self.waiting[dbKey] ~= nil then
    self:Write(dbKey)
  end
  local raw = self.db[dbKey]
  if type(raw) == "string" then
    return tonumber(raw:match("^([^;]*)")) or 0
  end
  return type(raw) == "table" and raw.m or nil
end

function Prices:GetFirstPrice(dbKeys)
  for _, dbKey in ipairs(dbKeys) do
    local price = self:GetPrice(dbKey)
    if price ~= nil then
      return price
    end
  end
end

-- prices: { [dbKey] = { {price = p, available = n}, ... } }; the lowest
-- price and the total quantity of each item are stored
function Prices:ProcessScan(prices)
  local count = 0
  for dbKey, list in pairs(prices) do
    local lowest, total = nil, 0
    for _, entry in ipairs(list) do
      total = total + (entry.available or 0)
      if lowest == nil or entry.price < lowest then
        lowest = entry.price
      end
    end
    if lowest ~= nil then
      self:SetPrice(dbKey, lowest, total)
      count = count + 1
    end
  end
  return count
end

-- Items with a price, also those whose first price is still waiting
function Prices:GetItemCount()
  local count = 0
  for _ in pairs(self.db) do
    count = count + 1
  end
  for dbKey in pairs(self.waiting) do
    if self.db[dbKey] == nil then
      count = count + 1
    end
  end
  return count
end

-- One row per day, newest first
function Prices:GetPriceHistory(dbKey)
  local data = self:Read(dbKey)
  if data == nil then
    return {}
  end
  local days = {}
  for day in pairs(data.h) do
    days[#days + 1] = tonumber(day)
  end
  table.sort(days, function(a, b) return a > b end)
  local rows = {}
  for _, number in ipairs(days) do
    local day = tostring(number)
    rows[#rows + 1] = {
      date = Auctionary.Utilities.PrettyDate(number * 86400 + Auctionary.Constants.SCAN_DAY_0),
      rawDay = number,
      minSeen = data.l[day] or data.h[day],
      maxSeen = data.h[day],
      available = data.a and data.a[day],
    }
  end
  return rows
end

-- Days since the item was last seen (nil: never)
function Prices:GetPriceAge(dbKey)
  local data = self:Read(dbKey)
  if data == nil then
    return nil
  end
  local newest
  for day in pairs(data.h) do
    newest = math.max(newest or 0, tonumber(day))
  end
  return newest and (Today() - newest)
end

-- Per day of the last `days` days (today included): the sum and number of
-- the scans. Days of older versions count as one scan at their low.
local function EachDay(data, days, visit)
  local today = Today()
  for number = today - days + 1, today do
    local day = tostring(number)
    local scans = data.n and data.n[day]
    if scans and scans > 0 then
      visit(data.s[day], scans)
    elseif data.l[day] or data.h[day] then
      visit(data.l[day] or data.h[day], 1)
    end
  end
end

-- Average over every scan; second value: number of scans
function Prices:GetScanAverage(dbKey, days)
  local data = self:Read(dbKey)
  if data == nil then
    return nil
  end
  local sum, scans = 0, 0
  EachDay(data, days, function(daySum, dayScans)
    sum, scans = sum + daySum, scans + dayScans
  end)
  if scans == 0 then
    return nil
  end
  return math.floor(sum / scans), scans
end

-- Median of the daily averages: a few days with pushed prices hardly move it.
-- Second value: number of days.
function Prices:GetScanMedian(dbKey, days)
  local data = self:Read(dbKey)
  if data == nil then
    return nil
  end
  local values = {}
  EachDay(data, days, function(daySum, dayScans)
    values[#values + 1] = daySum / dayScans
  end)
  local count = #values
  if count == 0 then
    return nil
  end
  table.sort(values)
  local median
  if count % 2 == 1 then
    median = values[(count + 1) / 2]
  else
    median = (values[count / 2] + values[count / 2 + 1]) / 2
  end
  return math.floor(median), count
end
