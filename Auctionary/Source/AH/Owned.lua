local Auctionary = Auctionary

-- The player's own auctions
AuctionaryAHOwnedFrameMixin = {}

function AuctionaryAHOwnedFrameMixin:OnLoad()
  self:SetScript("OnEvent", self.OnEvent)
  self:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
  Auctionary.EventBus:RegisterSource(self, "AuctionaryAHOwnedFrameMixin")
end

-- The client only sends AUCTION_OWNED_LIST_UPDATE when something changed, so
-- the list it already has is reported right away as well.
function AuctionaryAHOwnedFrameMixin:Query()
  GetOwnerAuctionItems()
  Auctionary.Compat.After(0, function()
    self:OnEvent()
  end)
end

function AuctionaryAHOwnedFrameMixin:OnEvent()
  if Auctionary.State.AHOpen then
    Auctionary.EventBus:Fire(
      self, Auctionary.AH.Events.OwnedAuctionsUpdate, Auctionary.AH.DumpAuctions("owner")
    )
  end
end
