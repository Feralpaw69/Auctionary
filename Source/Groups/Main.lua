local Auctionator = Auctionary

Auctionator.Groups.CallbackRegistry = Auctionator.Compat.CreateFromMixins(Auctionator.Compat.CallbackRegistryMixin)
Auctionator.Groups.CallbackRegistry:OnLoad()
Auctionator.Groups.CallbackRegistry:GenerateCallbackEvents(Auctionator.Groups.Constants.Events)

local function InitializeDefaultGroups()
  local defaultGroups = {}
  for _, classID in ipairs(Auctionator.Groups.Constants.ValidItemClassIDs) do
    local name = Auctionator.Compat.GetAuctionClassName(classID)
    if name ~= nil then
      table.insert(defaultGroups, {
        name = name,
        type = Auctionator.Groups.Constants.GroupType.ClassID,
        classID = classID,
      })
    end
  end
  Auctionator.Groups.Constants.DefaultGroups = defaultGroups
end

function Auctionator.Groups.Initialize()
  InitializeDefaultGroups()

  if type(AUCTIONARY_SELLING_GROUPS) ~= "table" or
     type(AUCTIONARY_SELLING_GROUPS.CustomGroups) ~= "table" or
     AUCTIONARY_SELLING_GROUPS.CustomGroups[1] == nil then
    AUCTIONARY_SELLING_GROUPS = {
      Version = 1,
      CustomGroups = {},
      HiddenItems = {},
    }
    Auctionator.Groups.AddGroup("FAVOURITES")
  end

  if type(AUCTIONARY_SELLING_GROUPS.HiddenItems) ~= "table" then
    AUCTIONARY_SELLING_GROUPS.HiddenItems = {}
  end
end

function Auctionator.Groups.OnAHOpen()
  -- The bag cache frame is created here in the Selling tab stage of the port
end
