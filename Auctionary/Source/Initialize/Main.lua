-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

local ADDON_NAME = ...

local frame = CreateFrame("Frame", "Auctionary2InitializeFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

-- Saved data of earlier versions (only the Pro build names them):
--   move:  everything of that version is taken over (when this addon has
--          nothing of its own yet) and removed there
--   merge: what is missing here is added from that version, once; its own
--          data stays as it is
local EARLIER = { move = "AUCTIONARY" .. "_" }
local OWN_PREFIX = "AUCTIONARY2_"
local SAVED = { "CONFIG", "SAVEDVARS", "SHOPPING_LISTS", "PRICE_DATABASE", "POSTING_HISTORY",
  "VENDOR_PRICE_CACHE", "RECENT_SEARCHES", "RECIPES" }

-- A record as text, to recognise the same record in both versions
local function Signature(value)
  if type(value) ~= "table" then
    return type(value) .. ":" .. tostring(value)
  end
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = tostring(key) .. "=" .. Signature(value[key])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function IsRecordList(list)
  return type(list) == "table" and #list > 0 and type(list[1]) == "table"
end

local function RecordTime(record)
  return tonumber(record.t or record.time or record[1]) or 0
end

-- Adds the records only the earlier list has, then sorts by time
local function MergeRecords(own, earlier)
  local known = {}
  for _, record in ipairs(own) do
    known[Signature(record)] = true
  end
  local added = 0
  for _, record in ipairs(earlier) do
    if not known[Signature(record)] then
      own[#own + 1] = record
      added = added + 1
    end
  end
  if added > 0 then
    table.sort(own, function(a, b) return RecordTime(a) < RecordTime(b) end)
  end
end

-- Keys only the earlier table has are added; tables found in both are
-- merged the same way; for single values this version wins
local function MergeMaps(own, earlier)
  for key, value in pairs(earlier) do
    local mine = own[key]
    if mine == nil then
      own[key] = value
    elseif type(mine) == "table" and type(value) == "table" then
      if IsRecordList(mine) and IsRecordList(value) then
        MergeRecords(mine, value)
      elseif #mine == 0 and #value == 0 then
        MergeMaps(mine, value)
      end
    end
  end
end

-- Price history of one item from both versions: every day either knows
local function MergeHistory(ownText, earlierText)
  local Codec = Auctionary.DatabaseCodec
  local mine, other = Codec.Deserialize(ownText), Codec.Deserialize(earlierText)
  if type(mine) ~= "table" or type(other) ~= "table" then
    return ownText
  end
  local function Newest(data)
    local newest = -1
    for day in pairs(data.h or {}) do
      newest = math.max(newest, tonumber(day) or -1)
    end
    return newest
  end
  if Newest(other) > Newest(mine) then
    mine.m = other.m
  end
  for _, field in ipairs({ "h", "l", "a", "s", "n" }) do
    mine[field] = mine[field] or {}
    for day, value in pairs(other[field] or {}) do
      if mine[field][day] == nil then
        mine[field][day] = value
      end
    end
  end
  return Codec.Serialize(mine)
end

local Merge = {
  PRICE_DATABASE = function(own, earlier)
    for realm, items in pairs(earlier) do
      if type(items) == "table" then
        local mine = own[realm]
        if type(mine) ~= "table" then
          own[realm] = items
        else
          for key, text in pairs(items) do
            local present = mine[key]
            if present == nil then
              mine[key] = text
            elseif present ~= text and type(present) == "string" and type(text) == "string" then
              mine[key] = MergeHistory(present, text)
            end
          end
        end
      end
    end
  end,
  SHOPPING_LISTS = function(own, earlier)
    local names = {}
    for _, list in ipairs(own) do
      names[list.name or ""] = true
    end
    for _, list in ipairs(earlier) do
      if type(list) == "table" and not names[list.name or ""] then
        own[#own + 1] = list
      end
    end
  end,
  SAVEDVARS = function(own, earlier)
    for key, value in pairs(earlier) do
      -- Sniping finds belong to one scan; the newer version's are kept
      if key ~= "SnipingFinds" then
        MergeMaps(own, { [key] = value })
      end
    end
  end,
}

local function TakeOverEarlierData()
  if EARLIER == nil then
    return
  end
  local note = false
  if EARLIER.move ~= nil then
    for _, part in ipairs(SAVED) do
      local earlier = _G[EARLIER.move .. part]
      if earlier ~= nil then
        if _G[OWN_PREFIX .. part] == nil then
          _G[OWN_PREFIX .. part] = earlier
          note = true
        end
        _G[EARLIER.move .. part] = nil
      end
    end
  end
  if EARLIER.merge ~= nil then
    local state = _G[OWN_PREFIX .. "SAVEDVARS"] or {}
    _G[OWN_PREFIX .. "SAVEDVARS"] = state
    state.MergedEarlier = state.MergedEarlier or {}
    if not state.MergedEarlier[EARLIER.merge] and _G[EARLIER.merge .. "SAVEDVARS"] ~= nil then
      for _, part in ipairs(SAVED) do
        local earlier, own = _G[EARLIER.merge .. part], _G[OWN_PREFIX .. part]
        if type(earlier) == "table" then
          if own == nil then
            _G[OWN_PREFIX .. part] = earlier
          elseif part == "CONFIG" or part == "RECENT_SEARCHES" then
            -- Settings and recent searches of this version stay as they are
          elseif Merge[part] ~= nil then
            Merge[part](own, earlier)
          else
            MergeMaps(own, earlier)
          end
        end
      end
      state.MergedEarlier[EARLIER.merge] = true
      note = true
    end
  end
  if note then
    print("|cff87abffAuctionary 2.0:|r Prices, lists, Gold Tracker and settings of the earlier versions were taken over.")
  end
end

-- WoW reads an addon's file list only when the game starts. After an update
-- that adds files, a /reload still runs the old list and the new files are
-- missing: then say so plainly instead of failing with Lua errors.
local function NewFilesMissing()
  return Auctionary.Commands.Register == nil or Auctionary.Components.CreateRowSet == nil
    or Auctionary.Components.CreateTable == nil or Auctionary.Keys == nil
    or Auctionary.Destroying == nil or Auctionary.Destroying.Data == nil
    or Auctionary.Enchant.GetDustBrackets == nil or AUCTIONARY2_L_SEARCH == nil
end

frame:SetScript("OnEvent", function(self, event, addonName)
  if event == "ADDON_LOADED" then
    if addonName == ADDON_NAME then
      self:UnregisterEvent("ADDON_LOADED")
      TakeOverEarlierData()
    end
    return
  end
  if event == "PLAYER_LOGIN" and NewFilesMissing() then
    self:UnregisterAllEvents()
    print("|cffff4040Auctionary 2.0 was updated with new files. Please close WoW completely "
      .. "and start it again (/reload is not enough).|r")
    return
  end
  if event == "PLAYER_LOGIN" then
    Auctionary.Debug.Message("Auctionary 2.0: PLAYER_LOGIN")
    Auctionary.Variables.Initialize()
    Auctionary.Tooltip.Initialize()

    Auctionary.Commands.Register()
  elseif event == "PLAYER_LOGOUT" then
    Auctionary.Variables.Commit()
  end
end)
