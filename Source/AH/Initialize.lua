local Auctionary = Auctionary

local function CreateInternal(name, mixin)
  local frame = CreateFrame("Frame", name, UIParent)
  Auctionary.Compat.Mixin(frame, mixin)
  frame:OnLoad()
  return frame
end

function Auctionary.AH.Initialize()
  if Auctionary.AH.Internals ~= nil then
    return
  end
  Auctionary.AH.Internals = {}

  Auctionary.AH.Internals.throttling = CreateInternal(
    "AuctionaryAHThrottlingFrame", AuctionaryAHThrottlingFrameMixin
  )
  Auctionary.AH.Queue = Auctionary.Compat.CreateAndInitFromMixin(Auctionary.AH.QueueMixin)
  Auctionary.AH.Internals.scan = CreateInternal(
    "AuctionaryAHScanFrame", AuctionaryAHScanFrameMixin
  )
  Auctionary.AH.Internals.owned = CreateInternal(
    "AuctionaryAHOwnedFrame", AuctionaryAHOwnedFrameMixin
  )
end

-- Follows the auction house window being opened and closed
local core = CreateFrame("Frame", "AuctionaryAHCoreFrame")
core:RegisterEvent("AUCTION_HOUSE_SHOW")
core:RegisterEvent("AUCTION_HOUSE_CLOSED")
core:SetScript("OnEvent", function(self, eventName)
  if not Auctionary.State.Loaded then
    return
  end
  if not self.registered then
    self.registered = true
    Auctionary.EventBus:RegisterSource(self, "AuctionaryAHCoreFrame")
  end

  if eventName == "AUCTION_HOUSE_SHOW" then
    Auctionary.State.AHOpen = true
    Auctionary.AH.Initialize()
    Auctionary.FullScan.Initialize()
    -- Loads the list of own auctions; it is needed to tell them apart in scans
    GetOwnerAuctionItems()
    Auctionary.EventBus:Fire(self, Auctionary.AH.Events.Opened)
  elseif Auctionary.State.AHOpen then
    -- AUCTION_HOUSE_CLOSED is sent twice by the client
    Auctionary.State.AHOpen = false
    Auctionary.EventBus:Fire(self, Auctionary.AH.Events.Closed)
  end
end)
