local Auctionary = Auctionary

function Auctionary.Utilities.CreateCountString(count)
    return Auctionary.Compat.Colors.LIGHTBLUE_FONT_COLOR:WrapTextInColorCode(" x" .. count)
end
