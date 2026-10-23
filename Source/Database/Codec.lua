local Auctionator = Auctionary

-- Price history of one item is kept as one printable string in the saved
-- variables (the original uses binary CBOR, which is not safe to store with
-- the 3.3.5 client). One string per item keeps the saved variables file small
-- enough for the client to load.
--
-- Format:  m;day:high:low:available:sum:count,day:high:low:available:sum:count,...
--   m          last seen minimum price
--   day        days since Auctionator.Constants.SCAN_DAY_0
--   high       highest minimum price seen that day
--   low        lowest minimum price seen that day (empty if same as high)
--   available  highest quantity seen that day (empty if unknown)
--   sum, count sum of the minimum prices of all scans of that day and how
--              many scans that were (missing in data of older versions)
Auctionator.DatabaseCodec = {}

local function Num(value)
  if value == nil then
    return ""
  elseif value == math.floor(value) and value < 1e15 and value > -1e15 then
    return string.format("%d", value)
  else
    return tostring(value)
  end
end

function Auctionator.DatabaseCodec.Serialize(itemData)
  local days = {}
  for day, high in pairs(itemData.h) do
    table.insert(days,
      day .. ":" .. Num(high) .. ":" .. Num(itemData.l[day]) .. ":" .. Num(itemData.a and itemData.a[day])
        .. ":" .. Num(itemData.s and itemData.s[day]) .. ":" .. Num(itemData.n and itemData.n[day])
    )
  end
  return Num(itemData.m or 0) .. ";" .. table.concat(days, ",")
end

function Auctionator.DatabaseCodec.Deserialize(text)
  local itemData = { m = 0, h = {}, l = {}, a = {}, s = {}, n = {} }
  local minPrice, rest = strsplit(";", text, 2)
  itemData.m = tonumber(minPrice) or 0
  if rest ~= nil and rest ~= "" then
    for entry in string.gmatch(rest, "[^,]+") do
      local day, high, low, available, sum, count = strsplit(":", entry)
      high = tonumber(high)
      if day ~= nil and day ~= "" and high ~= nil then
        itemData.h[day] = high
        itemData.l[day] = tonumber(low)
        itemData.a[day] = tonumber(available)
        itemData.s[day] = tonumber(sum)
        itemData.n[day] = tonumber(count)
      end
    end
  end
  return itemData
end
