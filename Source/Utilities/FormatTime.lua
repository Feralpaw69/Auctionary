local Auctionator = Auctionary

local function Short(seconds)
  if seconds >= 3600 then
    return math.floor(seconds / 3600 + 0.5) .. "h"
  else
    return math.max(1, math.ceil(seconds / 60)) .. "m"
  end
end

function Auctionator.Utilities.FormatTimeLeft(seconds)
  if seconds == nil then
    return ""
  end
  local color = Auctionator.Compat.Colors.WHITE_FONT_COLOR
  if math.ceil(seconds / 60) < 60 then
    color = Auctionator.Compat.Colors.RED_FONT_COLOR
  end
  return color:WrapTextInColorCode(Short(seconds))
end

local hour = 60 * 60
local SHORT     = "<" .. Short(hour/2)                              -- <30m
local MEDIUM    = Short(hour/2) .. " - " .. Short(hour * 2)         -- 30m - 2h
local LONG      = Short(hour * 2) .. " - " .. Short(hour * 12)      -- 2h - 12h
local VERY_LONG = Short(hour * 12) .. " - " .. Short(hour * 48)     -- 12h - 48h

-- timeLeftBand: return value of GetAuctionItemTimeLeft (1 to 4)
function Auctionator.Utilities.FormatTimeLeftBand(timeLeftBand)
  local bands = Auctionator.Constants.TimeLeftBand
  if timeLeftBand == bands.Short then
    return Auctionator.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode(SHORT)
  elseif timeLeftBand == bands.Medium then
    return MEDIUM
  elseif timeLeftBand == bands.Long then
    return LONG
  elseif timeLeftBand == bands.VeryLong then
    return VERY_LONG
  end
  return ""
end
