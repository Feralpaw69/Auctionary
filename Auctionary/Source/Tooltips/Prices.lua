-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Price lines in item tooltips
-- For an item the lines are put together once (vendor price, auction price,
-- average, age, mats cost, disenchant/prospect/mill value, owned count) and
-- kept for a moment: the client fills the tooltip of a bag item several
-- times a second while the mouse rests on it.

local Tooltip = Auctionary.Tooltip
local Options = Auctionary.Config.Options
local L = Auctionary.Locales.Apply
local WHITE = Auctionary.Compat.Colors.WHITE_FONT_COLOR
local Get = Auctionary.Config.Get

local KEEP_SECONDS = 1
local lastShown = {}   -- [tooltip] = { key, time, lines }

local function White(text)
  return WHITE:WrapTextInColorCode(text)
end

local function Money(copper)
  return White(Auctionary.Utilities.CreatePaddedMoneyString(copper))
end

-- Value of a destroyed item, "+ ?" when some materials have no price
local function Value(copper, incomplete)
  local text = Auctionary.Utilities.CreatePaddedMoneyString(copper)
  return White(incomplete and (text .. " + ?") or text)
end

-- " (140%)" green when destroying is worth more than buying, red otherwise
local function Share(value, incomplete, buyPrice)
  if buyPrice == nil or buyPrice <= 0 or value == nil or value <= 0 then
    return ""
  end
  local percent = math.floor(value / buyPrice * 100 + 0.5)
  return (percent >= 100 and " |cff20ff20(" or " |cffff4040(") .. (incomplete and ">" or "") .. percent .. "%)|r"
end

local function BuildLines(tooltip, itemLink, count, keys)
  local lines = {}
  local function Add(left, right, r, g, b)
    lines[#lines + 1] = { left, right, r, g, b }
  end
  local db = Auctionary.Database

  -- Shift switches between one item and the whole stack
  local wantStack = IsShiftKeyDown() and true or false
  if not Get(Options.SHIFT_STACK_TOOLTIPS) then
    wantStack = not wantStack
  end
  local times = wantStack and count or 1
  local label = (wantStack and count > 1) and Auctionary.Utilities.CreateCountString(count) or ""

  local unitPrice = db:GetFirstPrice(keys)
  local info = { GetItemInfo(itemLink) }
  local bound = #info > 0 and Auctionary.Utilities.IsBound(itemLink)

  if Auctionary.Debug.IsOn() then
    Add("DBKey", keys[1])
  end

  if Get(Options.VENDOR_TOOLTIPS) and #info > 0 and Auctionary.Utilities.IsVendorable(info) then
    local vendor = info[Auctionary.Constants.ITEM_INFO.SELL_PRICE] * times
    if vendor > 0 then
      lines.clearMoney = true
      Add(L("TIP_VENDOR") .. label, Money(vendor))
    end
  end

  if not bound then
    if Get(Options.AUCTION_TOOLTIPS) then
      Add(L("TIP_AUCTION") .. label, unitPrice and Money(unitPrice * times) or White(L("UNKNOWN") .. "  "))
    end
    if Get(Options.AUCTION_MEAN_TOOLTIPS) then
      local average = db:GetScanAverage(keys[1], Get(Options.AUCTION_MEAN_DAYS_LIMIT))
      if average ~= nil then
        Add(L("TIP_AVERAGE") .. label, Money(average * times))
      end
    end
    if Get(Options.AUCTION_AGE_TOOLTIPS) and unitPrice ~= nil then
      local age = db:GetPriceAge(keys[1])
      if age ~= nil then
        Add(AUCTIONARY2_L_TIP_AGE, White(AUCTIONARY2_L_DAYS:format(tostring(age))))
      elseif db:GetPrice(keys[1]) ~= nil then
        Add(AUCTIONARY2_L_TIP_AGE, AUCTIONARY2_L_UNKNOWN)
      end
    end
  end

  local itemID = keys[#keys]
  if Get(Options.MATS_COST_TOOLTIPS) then
    local cost, missing, note = Auctionary.CraftingInfo.GetMatsCost(itemID)
    if cost ~= nil then
      local text
      if missing > 0 and cost == 0 then
        text = White(L("UNKNOWN") .. "  ")
      else
        text = Value(cost * times, missing > 0)
      end
      Add("Mats Cost" .. label, text)
      if note ~= nil then
        Add(note, nil, 0.7, 0.7, 0.7)
      end
    end
  end

  if Get(Options.DISENCHANT_TOOLTIPS) then
    -- The tooltip itself can say that the item cannot be disenchanted
    Auctionary.Enchant.LearnFromTooltip(tooltip, itemLink)
    local value, incomplete = Auctionary.Enchant.GetDisenchantAuctionPrice(itemLink)
    if value ~= nil then
      if value == 0 and incomplete then
        Add("Disenchant", White(L("UNKNOWN") .. "  "))
      else
        Add("Disenchant", Value(value, incomplete) .. Share(value, incomplete, unitPrice))
      end
      if IsShiftKeyDown() then
        for _, text in ipairs(Auctionary.Enchant.GetDisenchantBreakdown(itemLink)) do
          Add(text, nil, 0.8, 0.8, 0.8)
        end
      end
    end
  end
  local destroyed = {
    { "Prospect", Options.PROSPECT_TOOLTIPS, Auctionary.Prospect.GetProspectAuctionPrice },
    { "Mill", Options.MILL_TOOLTIPS, Auctionary.Mill.GetMillAuctionPrice },
  }
  for _, kind in ipairs(destroyed) do
    if Get(kind[2]) then
      local value, incomplete = kind[3](itemID)
      if value ~= nil and (value > 0 or incomplete) then
        Add(kind[1] .. label, Value(value * times, incomplete) .. Share(value, incomplete, unitPrice))
      end
    end
  end

  pcall(Tooltip.AddOwnedLines, Add, itemLink)
  return lines
end

local function Put(tooltip, lines)
  if lines.clearMoney and tooltip == GameTooltip and GameTooltip_ClearMoney then
    GameTooltip_ClearMoney(tooltip)
  end
  for _, line in ipairs(lines) do
    local r, g, b = line[3], line[4], line[5]
    if line[2] ~= nil then
      tooltip:AddDoubleLine(line[1], line[2], r, g, b)
    else
      tooltip:AddLine(line[1], r, g, b)
    end
  end
  if #lines > 0 then
    tooltip:Show()
  end
end

function Tooltip.ShowTipWithPricing(tooltip, itemLink, itemCount)
  if Auctionary.Database == nil or itemLink == nil then
    return
  end
  -- Items the client does not know yet are skipped: by the time their data
  -- arrives the tooltip shows something else
  local itemID = Auctionary.Utilities.BasicDBKeyFromLink(itemLink)
  if itemID == nil or not Auctionary.Compat.IsItemCached(itemID) then
    return
  end
  local count = math.max(1, tonumber(itemCount) or 1)

  local key = itemLink .. "|" .. count .. "|" .. (IsShiftKeyDown() and "s" or "")
    .. (IsControlKeyDown() and "c" or "") .. "|" .. Auctionary.Database.revision
  local now = GetTime()
  local last = lastShown[tooltip]
  if last ~= nil and last.key == key and now - last.time < KEEP_SECONDS then
    Put(tooltip, last.lines)
    return
  end

  Auctionary.Utilities.DBKeyFromLink(itemLink, function(keys)
    if #keys == 0 then
      return
    end
    local lines = BuildLines(tooltip, itemLink, count, keys)
    lastShown[tooltip] = { key = key, time = now, lines = lines }
    Put(tooltip, lines)
  end)
end

-- Average price and price age are shown from the start (once, so a later
-- choice of the player stays)
function Tooltip.Initialize()
  local state = Auctionary.SavedState
  if state ~= nil and not state.TooltipDefaultsApplied then
    state.TooltipDefaultsApplied = true
    Auctionary.Config.Set(Options.AUCTION_MEAN_TOOLTIPS, true)
    Auctionary.Config.Set(Options.AUCTION_AGE_TOOLTIPS, true)
  end
end
