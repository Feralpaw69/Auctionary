local Auctionary = Auctionary

Auctionary.Groups.CallbackRegistry = Auctionary.Compat.CreateFromMixins(Auctionary.Compat.CallbackRegistryMixin)
Auctionary.Groups.CallbackRegistry:OnLoad()
Auctionary.Groups.CallbackRegistry:GenerateCallbackEvents(Auctionary.Groups.Constants.Events)

local function InitializeDefaultGroups()
  local defaultGroups = {}
  for _, classID in ipairs(Auctionary.Groups.Constants.ValidItemClassIDs) do
    local name = Auctionary.Compat.GetAuctionClassName(classID)
    if name ~= nil then
      table.insert(defaultGroups, {
        name = name,
        type = Auctionary.Groups.Constants.GroupType.ClassID,
        classID = classID,
      })
    end
  end
  Auctionary.Groups.Constants.DefaultGroups = defaultGroups
end

function Auctionary.Groups.Initialize()
  InitializeDefaultGroups()

  if type(AUCTIONARY_SELLING_GROUPS) ~= "table" or
     type(AUCTIONARY_SELLING_GROUPS.CustomGroups) ~= "table" or
     AUCTIONARY_SELLING_GROUPS.CustomGroups[1] == nil then
    AUCTIONARY_SELLING_GROUPS = {
      Version = 1,
      CustomGroups = {},
      HiddenItems = {},
    }
    Auctionary.Groups.AddGroup("FAVOURITES")
  end

  if type(AUCTIONARY_SELLING_GROUPS.HiddenItems) ~= "table" then
    AUCTIONARY_SELLING_GROUPS.HiddenItems = {}
  end
end

function Auctionary.Groups.OnAHOpen()
  -- The bag cache frame is created here in the Selling tab stage of the port
end
