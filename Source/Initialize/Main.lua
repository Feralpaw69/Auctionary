local Auctionator = Auctionary

local frame = CreateFrame("Frame", "AuctionaryInitializeFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    Auctionator.Debug.Message("Auctionary: PLAYER_LOGIN")
    Auctionator.Variables.Initialize()
    Auctionator.Tooltip.Initialize()

    Auctionator.SlashCmd.Initialize()
  elseif event == "PLAYER_LOGOUT" then
    Auctionator.Variables.Commit()
  end
end)
