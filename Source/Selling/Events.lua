local Auctionator = Auctionary

Auctionator.Selling.Events = {
  BagItemClicked = "bag_item_clicked",
  BagItemRequest = "bag_item_request",
  ClearBagItem = "clear_bag_item",
  BagReady = "bag_ready",
  BagRefresh = "bag_refresh",
  RequestPost = "selling_request_post",
  ConfirmPost = "selling_confirm_post",
  SkipItem = "selling_skip_item",
  AuctionCreated = "selling_auction_created",
  ItemIconCallback = "selling_item_icon_callback",
}

Auctionator.Selling.Events.RefreshHistory = "selling_refresh_history"
Auctionator.Selling.Events.SellSearchStart = "sell_search_start"
Auctionator.Selling.Events.PriceSelected = "price_selected"
Auctionator.Selling.Events.RefreshSearch = "selling_refresh_search"
Auctionator.Selling.Events.ShowConfirmPurchase = "selling_confirm_commodity_callback"
