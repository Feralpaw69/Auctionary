local Auctionary = Auctionary


function Auctionary.Utilities.ValidatePercentage(value)
  if value < 0 then
    Auctionary.Utilities.Message(
      Auctionary.Locales.Apply("TOO_SMALL_PERCENTAGE", value)
    )
    return 0
  elseif value > 100 then
    Auctionary.Utilities.Message(
      Auctionary.Locales.Apply("TOO_BIG_PERCENTAGE", value)
    )
    return 100
  else
    return value
  end
end
