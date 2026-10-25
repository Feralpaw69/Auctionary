-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Posting history
-- What the player posted, per item: db[dbKey] = { {price, quantity, time}, ... }
-- oldest first. Posts of one item at the same price on the same day are
-- added up into one entry; only the newest KEEP entries stay.

local KEEP = 10

local history = {}

local function SameDay(a, b)
  return date("%Y-%m-%d", a) == date("%Y-%m-%d", b)
end

function history:AddEntry(dbKey, price, quantity)
  local entries = self.db[dbKey]
  if entries == nil then
    entries = {}
    self.db[dbKey] = entries
  end
  local now = time()
  for index = #entries, 1, -1 do
    local entry = entries[index]
    if entry.price == price and SameDay(entry.time, now) then
      quantity = quantity + (entry.quantity or 0)
      table.remove(entries, index)
    end
  end
  entries[#entries + 1] = { price = price, quantity = quantity, time = now }
  while #entries > KEEP do
    table.remove(entries, 1)
  end
end

function history:GetPriceHistory(dbKey)
  local result = {}
  for _, entry in ipairs(self.db[dbKey] or {}) do
    result[#result + 1] = {
      date = Auctionary.Utilities.PrettyDate(entry.time),
      rawDay = entry.time,
      price = entry.price,
      quantity = entry.quantity,
    }
  end
  return result
end

function history:ReceiveEvent(_, auction)
  Auctionary.Utilities.DBKeyFromLink(auction.itemLink, function(dbKeys)
    for _, dbKey in ipairs(dbKeys) do
      self:AddEntry(dbKey, auction.buyoutAmount, auction.quantity)
    end
  end)
end

function Auctionary.CreatePostingHistory(db)
  local object = setmetatable({ db = db }, { __index = history })
  Auctionary.EventBus:Register(object, { Auctionary.Selling.Events.AuctionCreated })
  return object
end
