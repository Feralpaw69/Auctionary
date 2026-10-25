local Auctionary = Auctionary

local Codec = Auctionary.DatabaseCodec

local function GetScanDay()
  return (math.floor ((time() - Auctionary.Constants.SCAN_DAY_0) / (86400)));
end

Auctionary.DatabaseMixin = {}
function Auctionary.DatabaseMixin:Init(db)
  self.db = db
  self.cutoffDay = GetScanDay() - Auctionary.Config.Get(Auctionary.Config.Options.PRICE_HISTORY_DAYS)

  -- Prices set during a scan are queued and written a few per frame so that a
  -- big scan doesn't freeze the client
  self.processor = CreateFrame("Frame")
  self.processor.queue = {}
  self.processor.running = false
  self.processor.index = 1
  self.processor.UpdateScript = function()
    self.processor:SetScript("OnUpdate", nil)
    local count = 50
    while count > 0 and self.processor.index <= #self.processor.queue do
      count = count - 1
      local dbKey = self.processor.queue[self.processor.index]
      local data = self.db[dbKey]
      if type(data) == "table" and data.pending then
        self.db[dbKey] = data.old
        self:_SetPrice(dbKey, data.buyoutPrice, data.available)
      end
      self.processor.index = self.processor.index + 1
    end
    if self.processor.index > #self.processor.queue then
      self.processor.index = 1
      self.processor.running = false
      self.processor.queue = {}
    else
      self.processor:SetScript("OnUpdate", self.processor.UpdateScript)
    end
  end

  -- Anything left pending by a logout in the middle of processing
  for dbKey, data in pairs(self.db) do
    if type(data) == "table" and data.pending then
      self:_Queue(dbKey)
    end
  end
end

-- Writes any queued prices immediately (used before logout)
function Auctionary.DatabaseMixin:Flush()
  for dbKey, data in pairs(self.db) do
    if type(data) == "table" and data.pending then
      self.db[dbKey] = data.old
      self:_SetPrice(dbKey, data.buyoutPrice, data.available)
    end
  end
  self.processor:SetScript("OnUpdate", nil)
  self.processor.index = 1
  self.processor.running = false
  self.processor.queue = {}
end

function Auctionary.DatabaseMixin:_Get(dbKey)
  if type(self.db[dbKey]) == "table" and self.db[dbKey].pending then
    local data = self.db[dbKey]
    self.db[dbKey] = self.db[dbKey].old
    self:_SetPrice(dbKey, data.buyoutPrice, data.available)
  end

  local data = self.db[dbKey]
  if type(data) == "string" then
    return Codec.Deserialize(data)
  else
    return data
  end
end

function Auctionary.DatabaseMixin:_Queue(dbKey)
  table.insert(self.processor.queue, dbKey)
  if not self.processor.running then
    self.processor.running = true
    self.processor:SetScript("OnUpdate", self.processor.UpdateScript)
  end
end

function Auctionary.DatabaseMixin:SetPrice(dbKey, buyoutPrice, available)
  if type(self.db[dbKey]) == "table" and self.db[dbKey].pending then
    self.db[dbKey].buyoutPrice = buyoutPrice
    self.db[dbKey].available = available
  else
    local old = self.db[dbKey]
    self.db[dbKey] = { pending = true, old = old, buyoutPrice = buyoutPrice, available = available }
    self:_Queue(dbKey)
  end
end

function Auctionary.DatabaseMixin:_SetPrice(dbKey, buyoutPrice, available)
  -- Tells the tooltips that prices changed
  self.revision = (self.revision or 0) + 1
  local daysSinceZero = tostring(GetScanDay())

  local priceData = self.db[dbKey]
  if type(priceData) == "string" then
    priceData = Codec.Deserialize(priceData)
  elseif type(priceData) ~= "table" then
    priceData = {
      l={}, -- Lowest low price on a given day
      h={}, -- Highest low price on a given day
      a={}, -- Highest quantity seen on a given day
      s={}, -- Sum of the prices of all scans on a given day
      n={}, -- Number of scans on a given day
      m=0   -- Last seen minimum price
    }
  end

  priceData.m = buyoutPrice

  -- Every scan counts for the average, also several on the same day
  priceData.s = priceData.s or {}
  priceData.n = priceData.n or {}
  if priceData.n[daysSinceZero] == nil then
    -- Day recorded by an older version: its known prices count as scans
    local known = priceData.l[daysSinceZero] or priceData.h[daysSinceZero]
    if known ~= nil then
      priceData.s[daysSinceZero] = known
      priceData.n[daysSinceZero] = 1
    end
  end
  priceData.s[daysSinceZero] = (priceData.s[daysSinceZero] or 0) + buyoutPrice
  priceData.n[daysSinceZero] = (priceData.n[daysSinceZero] or 0) + 1

  -- Record price history
  local lowestLow  = priceData.l[daysSinceZero]
  local highestLow = priceData.h[daysSinceZero]

  if highestLow == nil or buyoutPrice > highestLow then
    priceData.h[daysSinceZero] = buyoutPrice
    highestLow = buyoutPrice
  end

  -- save memory by only saving lowestLow when different from highestLow
  if buyoutPrice < highestLow and (lowestLow == nil or buyoutPrice < lowestLow) then
    priceData.l[daysSinceZero] = buyoutPrice
  end

  if available ~= nil then
    if priceData.a == nil then
      priceData.a = {}
    end

    local prevAvailable = priceData.a[daysSinceZero]
    if prevAvailable ~= nil then
      priceData.a[daysSinceZero] = math.max(prevAvailable, available)
    else
      priceData.a[daysSinceZero] = available
    end
  end

  local cutoffDay = self.cutoffDay

  -- Prune old days
  for _, field in ipairs({"h", "l", "a", "s", "n"}) do
    local toRemove = {}
    for day, _ in pairs(priceData[field]) do
      if tonumber(day) <= cutoffDay then
        table.insert(toRemove, day)
      end
    end
    for _, day in ipairs(toRemove) do
      priceData[field][day] = nil
    end
  end

  self.db[dbKey] = Codec.Serialize(priceData)
end

function Auctionary.DatabaseMixin:GetPrice(dbKey)
  if self.db[dbKey] ~= nil then
    return self:_Get(dbKey).m
  else
    return nil
  end
end

function Auctionary.DatabaseMixin:GetFirstPrice(dbKeys)
  for _, dbKey in ipairs(dbKeys) do
    local price = self:GetPrice(dbKey)
    if price then
      return price
    end
  end
  return nil
end

--Takes all the items with a list of their prices, and determines the minimum
--price.
--  itemIndexes: { [dbKey] = { {price = number, available = number}, ... } }
function Auctionary.DatabaseMixin:ProcessScan(itemIndexes)
  Auctionary.Debug.Message("Auctionary.DatabaseMixin.ProcessScan")
  local startTime = Auctionary.Compat.ProfileStop()

  local count = 0

  for dbKey, info in pairs(itemIndexes) do
    count = count + 1

    local minPrice = info[1].price
    local available = 0

    for i = 1, #info do
      available = available + info[i].available
      if info[i].price < minPrice then
        minPrice = info[i].price
      end
    end

    self:SetPrice(dbKey, minPrice, available)
  end

  Auctionary.Debug.Message("Auctionary.DatabaseMixin: Processing time: " .. tostring(Auctionary.Compat.ProfileStop() - startTime))
  return count
end

function Auctionary.DatabaseMixin:GetItemCount()
  local count = 0
  for _, _ in pairs(self.db) do
    count = count + 1
  end

  return count
end

function Auctionary.DatabaseMixin:GetPriceHistory(dbKey)
  if self.db[dbKey] == nil then
    return {}
  end

  local itemData = self:_Get(dbKey)

  local results = {}

  local sortedDays = Auctionary.Utilities.TableKeys(itemData.h)
  table.sort(sortedDays, function(a, b) return tonumber(b) < tonumber(a) end)

  for _, day in ipairs(sortedDays) do
    table.insert(results, {
     date = Auctionary.Utilities.PrettyDate(
        tonumber(day) * 86400 + Auctionary.Constants.SCAN_DAY_0
     ),
     rawDay = tonumber(day),
     minSeen = itemData.l[day] or itemData.h[day],
     maxSeen = itemData.h[day],
     available = itemData.a and itemData.a[day],
   })
 end

 return results
end

-- Days since the item was last seen, nil if never
function Auctionary.DatabaseMixin:GetPriceAge(dbKey)
  local itemData = self.db[dbKey] and self:_Get(dbKey)

  if itemData == nil then
    return
  end

  local newest = nil
  for day in pairs(itemData.h) do
    local dayNumber = tonumber(day)
    if newest == nil or dayNumber > newest then
      newest = dayNumber
    end
  end

  if newest == nil then
    return nil
  end

  return GetScanDay() - newest
end

-- Average of the lowest price over all scans of the last given number of
-- days, today included. Several scans on one day all count. Returns the
-- average and the number of scans, or nil without any scan on record.
function Auctionary.DatabaseMixin:GetScanAverage(dbKey, days)
  local entry = self.db[dbKey] and self:_Get(dbKey)
  if entry == nil then
    return nil
  end

  local today = GetScanDay()
  local total, count = 0, 0
  for i = today - days + 1, today do
    local day = tostring(i)
    if entry.n and entry.n[day] then
      total = total + entry.s[day]
      count = count + entry.n[day]
    else
      -- Recorded by an older version: one scan at the day's lowest price
      local price = entry.l[day] or entry.h[day]
      if price then
        total = total + price
        count = count + 1
      end
    end
  end

  if count > 0 then
    return math.floor(total / count), count
  end
  return nil
end

-- Median of the daily prices of the last days (one value per day: the
-- day's average scan price). A few boosted days hardly move it.
function Auctionary.DatabaseMixin:GetScanMedian(dbKey, days)
  local entry = self.db[dbKey] and self:_Get(dbKey)
  if entry == nil then
    return nil
  end
  local today = GetScanDay()
  local values = {}
  for i = today - days + 1, today do
    local day = tostring(i)
    if entry.n and entry.n[day] and entry.n[day] > 0 then
      table.insert(values, entry.s[day] / entry.n[day])
    else
      local price = entry.l[day] or entry.h[day]
      if price then
        table.insert(values, price)
      end
    end
  end
  if #values == 0 then
    return nil
  end
  table.sort(values)
  local middle = math.floor((#values + 1) / 2)
  local median = (#values % 2 == 1) and values[middle] or (values[middle] + values[middle + 1]) / 2
  return math.floor(median), #values
end

function Auctionary.DatabaseMixin:GetMeanPrice(dbKey, days)
  local entry = self.db[dbKey] and self:_Get(dbKey)

  if entry == nil or days < 0 then
    return nil
  end

  local today = GetScanDay()
  local total = 0
  local count = days

  for i = today - days + 1, today do
    local day = tostring(i)
    if entry.l[day] then
      total = total + entry.l[day]
    elseif entry.h[day] then
      total = total + entry.h[day]
    else
      count = count - 1
    end
  end

  if count ~= 0 then
    return math.floor(total / count)
  else
    return nil
  end
end
