local Auctionary = Auctionary

-- Decides when the next request may be sent to the auction house.
-- The 3.3.5 client has no throttle events, so CanSendAuctionQuery is polled
-- while the auction house is open. Call the matching method right before
-- doing the action:
-- :SearchQueried()
AuctionaryAHThrottlingFrameMixin = {}

local QUERY_TIMEOUT = 10

function AuctionaryAHThrottlingFrameMixin:OnLoad()
  Auctionary.Debug.Message("AuctionaryAHThrottlingFrameMixin:OnLoad")
  self.oldReady = false
  self.waitingOnQuery = false
  self.queryTime = 0

  self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
  self:RegisterEvent("AUCTION_HOUSE_CLOSED")
  self:SetScript("OnEvent", self.OnEvent)
  self:SetScript("OnUpdate", self.OnUpdate)

  Auctionary.EventBus:RegisterSource(self, "AuctionaryAHThrottlingFrameMixin")
end

function AuctionaryAHThrottlingFrameMixin:OnEvent(eventName)
  if eventName == "AUCTION_ITEM_LIST_UPDATE" then
    self.waitingOnQuery = false
  elseif eventName == "AUCTION_HOUSE_CLOSED" then
    self.waitingOnQuery = false
    self:Check()
  end
end

function AuctionaryAHThrottlingFrameMixin:OnUpdate()
  if self.waitingOnQuery and GetTime() - self.queryTime > QUERY_TIMEOUT then
    Auctionary.Debug.Message("throttling: query timed out")
    self.waitingOnQuery = false
  end
  self:Check()
end

function AuctionaryAHThrottlingFrameMixin:Check()
  local ready = self:IsReady()

  if self.reportNotReady then
    self.reportNotReady = false
    if not ready then
      Auctionary.EventBus:Fire(self, Auctionary.AH.Events.ThrottleUpdate, false)
    end
  end

  if self.oldReady ~= ready then
    self.oldReady = ready
    if ready then
      Auctionary.EventBus:Fire(self, Auctionary.AH.Events.Ready)
    end
    Auctionary.EventBus:Fire(self, Auctionary.AH.Events.ThrottleUpdate, ready)
  end
end

function AuctionaryAHThrottlingFrameMixin:SearchQueried()
  self.waitingOnQuery = true
  self.queryTime = GetTime()
  -- Not ready any more. No events fired from here, the queue is in the middle
  -- of sending; the change is reported on the next frame.
  self.oldReady = false
  self.reportNotReady = true
end

function AuctionaryAHThrottlingFrameMixin:IsReady()
  if not Auctionary.State.AHOpen or self.waitingOnQuery then
    return false
  end
  return (CanSendAuctionQuery("list")) and true or false
end
