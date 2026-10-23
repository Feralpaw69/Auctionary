local Auctionary = Auctionary

function Auctionary.Utilities.Message(message)
  print(
    Auctionary.Compat.Colors.LIGHTBLUE_FONT_COLOR:WrapTextInColorCode("Auctionary: ")
    .. tostring(message)
  )
end
