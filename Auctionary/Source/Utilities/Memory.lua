-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Memory cleanup
-- Lua frees memory that is no longer used only now and then; until then the
-- addon list shows it as used. The addon cleans up at calm moments:
--   * behind every loading screen (login, entering a raid or dungeon):
--     one full cleanup, hidden by the loading screen
--   * after a full scan and after closing the auction house: in small steps
--     over a few frames, so nothing stutters
-- Never during a fight.

local Memory = {}
Auctionary.Memory = Memory

local STEP_SIZE = 200        -- per frame
local MAX_STEP_TIME = 5      -- seconds of stepping at most

local stepper = CreateFrame("Frame")
stepper:Hide()
stepper.left = 0
stepper:SetScript("OnUpdate", function(self, elapsed)
  if self.left <= 0 then
    self:Hide()
    return
  end
  if InCombatLockdown() then
    return
  end
  self.left = self.left - elapsed
  -- true: a whole cleanup cycle is done
  if collectgarbage("step", STEP_SIZE) or self.left <= 0 then
    self:Hide()
  end
end)

-- Drops what the addon keeps only to be quicker (it is built again when needed)
local function ReleaseCaches()
  if Auctionary.Database ~= nil and Auctionary.Database.ReleaseCache ~= nil then
    Auctionary.Database:ReleaseCache()
  end
  if Auctionary.Search.ClearNameIndex ~= nil then
    Auctionary.Search.ClearNameIndex()
  end
end

-- In small steps over the next frames
function Memory.CleanUpSoon()
  ReleaseCaches()
  stepper.left = MAX_STEP_TIME
  stepper:Show()
end

-- At once; only where a short stop is not noticed
function Memory.CleanUpNow()
  if InCombatLockdown() then
    Memory.CleanUpSoon()
    return
  end
  ReleaseCaches()
  stepper.left = 0
  stepper:Hide()
  collectgarbage("collect")
end

-- Memory of this addon in MB
function Memory.GetUsage()
  UpdateAddOnMemoryUsage()
  return (GetAddOnMemoryUsage(Auctionary.Constants.AddonName) or 0) / 1024
end

local loadingScreen = CreateFrame("Frame")
loadingScreen:RegisterEvent("PLAYER_ENTERING_WORLD")
loadingScreen:SetScript("OnEvent", function()
  Memory.CleanUpNow()
end)

local listener = {}
function listener:ReceiveEvent()
  Memory.CleanUpSoon()
end
Auctionary.EventBus:Register(listener, {
  Auctionary.AH.Events.Closed,
  Auctionary.FullScan.Events.ScanComplete,
})
