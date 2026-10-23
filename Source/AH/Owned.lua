local Auctionator = Auctionary

-- The player's own auctions
AuctionaryAHOwnedFrameMixin = {}

function AuctionaryAHOwnedFrameMixin:OnLoad()
  self:SetScript("OnEvent", self.OnEvent)
  self:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
  Auctionator.EventBus:RegisterSource(self, "AuctionaryAHOwnedFrameMixin")
end

-- The client only sends AUCTION_OWNED_LIST_UPDATE when something changed, so
-- the list it already has is reported right away as well.
function AuctionaryAHOwnedFrameMixin:Query()
  GetOwnerAuctionItems()
  Auctionator.Compat.After(0, function()
    self:OnEvent()
  end)
end

function AuctionaryAHOwnedFrameMixin:OnEvent()
  if Auctionator.State.AHOpen then
    Auctionator.EventBus:Fire(
      self, Auctionator.AH.Events.OwnedAuctionsUpdate, Auctionator.AH.DumpAuctions("owner")
    )
  end
end
