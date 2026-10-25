-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

local function Short(seconds)
  if seconds >= 3600 then
    return math.floor(seconds / 3600 + 0.5) .. "h"
  else
    return math.max(1, math.ceil(seconds / 60)) .. "m"
  end
end

function Auctionary.Utilities.FormatTimeLeft(seconds)
  if seconds == nil then
    return ""
  end
  local color = Auctionary.Compat.Colors.WHITE_FONT_COLOR
  if math.ceil(seconds / 60) < 60 then
    color = Auctionary.Compat.Colors.RED_FONT_COLOR
  end
  return color:WrapTextInColorCode(Short(seconds))
end

local hour = 60 * 60
local SHORT     = "<" .. Short(hour/2)                              -- <30m
local MEDIUM    = Short(hour/2) .. " - " .. Short(hour * 2)         -- 30m - 2h
local LONG      = Short(hour * 2) .. " - " .. Short(hour * 12)      -- 2h - 12h
local VERY_LONG = Short(hour * 12) .. " - " .. Short(hour * 48)     -- 12h - 48h

-- timeLeftBand: return value of GetAuctionItemTimeLeft (1 to 4)
function Auctionary.Utilities.FormatTimeLeftBand(timeLeftBand)
  local bands = Auctionary.Constants.TimeLeftBand
  if timeLeftBand == bands.Short then
    return Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode(SHORT)
  elseif timeLeftBand == bands.Medium then
    return MEDIUM
  elseif timeLeftBand == bands.Long then
    return LONG
  elseif timeLeftBand == bands.VeryLong then
    return VERY_LONG
  end
  return ""
end
