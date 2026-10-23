local Auctionator = Auctionary

local function CreateInternal(name, mixin)
  local frame = CreateFrame("Frame", name, UIParent)
  Auctionator.Compat.Mixin(frame, mixin)
  frame:OnLoad()
  return frame
end

function Auctionator.AH.Initialize()
  if Auctionator.AH.Internals ~= nil then
    return
  end
  Auctionator.AH.Internals = {}

  Auctionator.AH.Internals.throttling = CreateInternal(
    "AuctionaryAHThrottlingFrame", AuctionaryAHThrottlingFrameMixin
  )
  Auctionator.AH.Queue = Auctionator.Compat.CreateAndInitFromMixin(Auctionator.AH.QueueMixin)
  Auctionator.AH.Internals.scan = CreateInternal(
    "AuctionaryAHScanFrame", AuctionaryAHScanFrameMixin
  )
  Auctionator.AH.Internals.owned = CreateInternal(
    "AuctionaryAHOwnedFrame", AuctionaryAHOwnedFrameMixin
  )
end

-- Follows the auction house window being opened and closed
local core = CreateFrame("Frame", "AuctionaryAHCoreFrame")
core:RegisterEvent("AUCTION_HOUSE_SHOW")
core:RegisterEvent("AUCTION_HOUSE_CLOSED")
core:SetScript("OnEvent", function(self, eventName)
  if not Auctionator.State.Loaded then
    return
  end
  if not self.registered then
    self.registered = true
    Auctionator.EventBus:RegisterSource(self, "AuctionaryAHCoreFrame")
  end

  if eventName == "AUCTION_HOUSE_SHOW" then
    Auctionator.State.AHOpen = true
    Auctionator.AH.Initialize()
    Auctionator.FullScan.Initialize()
    -- Loads the list of own auctions; it is needed to tell them apart in scans
    GetOwnerAuctionItems()
    Auctionator.EventBus:Fire(self, Auctionator.AH.Events.Opened)
  elseif Auctionator.State.AHOpen then
    -- AUCTION_HOUSE_CLOSED is sent twice by the client
    Auctionator.State.AHOpen = false
    Auctionator.EventBus:Fire(self, Auctionator.AH.Events.Closed)
  end
end)
