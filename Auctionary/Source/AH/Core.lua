-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Talking to the 3.3.5 auction house
-- Messages on the event bus:
--   Ready                          a new request may be sent
--   ScanResultsUpdate(results, gotAll, progress)   a page of a search arrived
--   ScanAborted()                  a search stopped (window closed, other search)
--   CurrentPage(results, total)    answer to AH.QueryAndFocusPage
--   OwnedAuctionsUpdate(auctions)  the player's own auctions
--   Opened() / Closed()            the auction house window
local AH = Auctionary.AH

AH.Events = {}
for _, name in ipairs({ "Ready", "ScanResultsUpdate", "ScanAborted", "CurrentPage",
                        "OwnedAuctionsUpdate", "Opened", "Closed" }) do
  AH.Events[name] = "ah." .. name
end

-- What GetAuctionItemInfo returns, by position
Auctionary.Constants.AuctionItemInfo = {
  Name = 1, Texture = 2, Quantity = 3, Quality = 4, CanUse = 5, Level = 6,
  MinBid = 7, MinIncrement = 8, Buyout = 9, BidAmount = 10, HighBidder = 11,
  Owner = 12, SaleStatus = 13,
}

---- When may the next request go out?
-- The server answers CanSendAuctionQuery() with "not yet" for a while after
-- every request; there is no event for it, so it is looked at every frame,
-- but only while the auction house is open. A request without an answer
-- stops blocking after ANSWER_TIMEOUT seconds.

local ANSWER_TIMEOUT = 10

local gate = CreateFrame("Frame")
gate:Hide()
gate.waiting = false
gate.sentAt = 0
gate.wasReady = false
Auctionary.EventBus:RegisterSource(gate, "auction house gate")

function gate:IsReady()
  return Auctionary.State.AHOpen == true and not self.waiting and CanSendAuctionQuery("list") and true or false
end

-- Right before a request is sent
function gate:SearchQueried()
  self.waiting = true
  self.sentAt = GetTime()
  self.wasReady = false
end

gate:SetScript("OnUpdate", function(self)
  if self.waiting and GetTime() - self.sentAt > ANSWER_TIMEOUT then
    self.waiting = false
  end
  local ready = self:IsReady()
  if ready and not self.wasReady then
    self.wasReady = true
    Auctionary.EventBus:Fire(self, AH.Events.Ready)
  elseif not ready then
    self.wasReady = false
  end
end)
gate:SetScript("OnEvent", function(self)
  self.waiting = false
end)
gate:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")

---- The player's own auctions
local owned = CreateFrame("Frame")
Auctionary.EventBus:RegisterSource(owned, "own auctions")

local function ReportOwned()
  if Auctionary.State.AHOpen then
    Auctionary.EventBus:Fire(owned, AH.Events.OwnedAuctionsUpdate, AH.DumpAuctions("owner"))
  end
end
owned:SetScript("OnEvent", ReportOwned)
owned:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")

-- The client only sends an update when something changed, so what it
-- already knows is reported on the next frame as well
function owned:Query()
  GetOwnerAuctionItems()
  Auctionary.Compat.After(0, ReportOwned)
end

---- Set up on the first visit
function AH.Initialize()
  if AH.Internals ~= nil then
    return
  end
  local scan = CreateFrame("Frame", "Auctionary2AHScanFrame", UIParent)
  Auctionary.Compat.Mixin(scan, Auctionary.AH.ScanFrameMethods)
  scan:OnLoad()
  AH.Internals = { throttling = gate, owned = owned, scan = scan }
  AH.Queue = Auctionary.Compat.CreateAndInitFromMixin(AH.QueueMixin)
end

---- Opening and closing the window
local window = CreateFrame("Frame")
Auctionary.EventBus:RegisterSource(window, "auction house window")
window:RegisterEvent("AUCTION_HOUSE_SHOW")
window:RegisterEvent("AUCTION_HOUSE_CLOSED")
window:SetScript("OnEvent", function(_, eventName)
  if not Auctionary.State.Loaded then
    return
  end
  if eventName == "AUCTION_HOUSE_SHOW" then
    Auctionary.State.AHOpen = true
    AH.Initialize()
    gate.waiting = false
    gate:Show()
    Auctionary.FullScan.Initialize()
    GetOwnerAuctionItems()
    Auctionary.EventBus:Fire(window, AH.Events.Opened)
  elseif Auctionary.State.AHOpen then
    -- The client sends AUCTION_HOUSE_CLOSED twice
    Auctionary.State.AHOpen = false
    gate:Hide()
    gate.waiting = false
    Auctionary.EventBus:Fire(window, AH.Events.Closed)
  end
end)
