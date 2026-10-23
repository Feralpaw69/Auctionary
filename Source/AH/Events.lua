local Auctionator = Auctionary

Auctionator.AH.Events = {
  Ready = "AH_READY",
  ThrottleUpdate = "ah_throttle_update",

  -- Legacy (3.3.5) auction house
  -- (results, gotAllResults, progress) progress = { page, totalPages, total }
  ScanResultsUpdate = "ah_scan_results_update",
  -- ()
  ScanAborted = "ah_scan_aborted",
  -- (results, total) answer to Auctionator.AH.QueryAndFocusPage
  CurrentPage = "ah_current_page",
  -- (auctions) answer to Auctionator.AH.QueryOwnedAuctions
  OwnedAuctionsUpdate = "ah_owned_auctions_update",
  -- () auction house window opened/closed
  Opened = "ah_opened",
  Closed = "ah_closed",
}

-- Positions in the values returned by GetAuctionItemInfo in the 3.3.5 client
Auctionator.Constants.AuctionItemInfo = {
  Name = 1,
  Texture = 2,
  Quantity = 3,
  Quality = 4,
  CanUse = 5,
  Level = 6,
  MinBid = 7,
  MinIncrement = 8,
  Buyout = 9,
  BidAmount = 10,
  HighBidder = 11,
  Owner = 12,
  SaleStatus = 13, -- only for the player's own auctions
}
