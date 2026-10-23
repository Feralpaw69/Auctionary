local Auctionator = Auctionary

function Auctionator.Utilities.CreateCountString(count)
    return Auctionator.Compat.Colors.LIGHTBLUE_FONT_COLOR:WrapTextInColorCode(" x" .. count)
end
