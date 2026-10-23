local Auctionary = Auctionary

local frame = CreateFrame("Frame", "AuctionaryInitializeFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, addonName)
  if event == "PLAYER_LOGIN" then
    Auctionary.Debug.Message("Auctionary: PLAYER_LOGIN")
    Auctionary.Variables.Initialize()
    Auctionary.Tooltip.Initialize()

    Auctionary.SlashCmd.Initialize()
  elseif event == "PLAYER_LOGOUT" then
    Auctionary.Variables.Commit()
  end
end)
