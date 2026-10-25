local Auctionary = Auctionary

function Auctionary.Debug.IsOn()
  return Auctionary.Config.Get(Auctionary.Config.Options.DEBUG)
end

function Auctionary.Debug.Toggle()
  Auctionary.Config.Set(Auctionary.Config.Options.DEBUG,
    not Auctionary.Config.Get(Auctionary.Config.Options.DEBUG))
end

function Auctionary.Debug.Message(message, ...)
  if Auctionary.Debug.IsOn() then
    print(Auctionary.Compat.Colors.GREEN_FONT_COLOR:WrapTextInColorCode(message), ...)
  end
end
