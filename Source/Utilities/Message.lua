local Auctionator = Auctionary

function Auctionator.Utilities.Message(message)
  print(
    Auctionator.Compat.Colors.LIGHTBLUE_FONT_COLOR:WrapTextInColorCode("Auctionary: ")
    .. tostring(message)
  )
end
