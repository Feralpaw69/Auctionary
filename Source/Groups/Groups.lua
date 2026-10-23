local Auctionator = Auctionary

function Auctionator.Groups.DoesGroupExist(name)
  return Auctionator.Groups.Utilities.IsContainedPredicate(AUCTIONARY_SELLING_GROUPS.CustomGroups, function(item) return item.name == name end)
end
function Auctionator.Groups.AddGroup(name)
  assert(not Auctionator.Groups.DoesGroupExist(name), "Group already exists")

  table.insert(AUCTIONARY_SELLING_GROUPS.CustomGroups, {
    name = name,
    type = Auctionator.Groups.Constants.GroupType.List,
    list = {},
    hidden = false,
  })
end

function Auctionator.Groups.GetGroupIndex(name)
  for index, s in ipairs(AUCTIONARY_SELLING_GROUPS.CustomGroups) do
    if s.name == name then
      return index
    end
  end
  return nil
end

function Auctionator.Groups.GetGroupNameByIndex(index)
  return AUCTIONARY_SELLING_GROUPS.CustomGroups[index] and AUCTIONARY_SELLING_GROUPS.CustomGroups[index].name
end

function Auctionator.Groups.GetGroupList(name)
  return AUCTIONARY_SELLING_GROUPS.CustomGroups[Auctionator.Groups.GetGroupIndex(name)].list
end

function Auctionator.Groups.HideItemLink(itemLink)
  table.insert(AUCTIONARY_SELLING_GROUPS.HiddenItems, itemLink)
end

function Auctionator.Groups.UnhideItemLink(itemLink)
  local index = Auctionator.Compat.tIndexOf(AUCTIONARY_SELLING_GROUPS.HiddenItems, itemLink)
  if index ~= nil then
    table.remove(AUCTIONARY_SELLING_GROUPS.HiddenItems, index)
  end
end

function Auctionator.Groups.UnhideAll()
  AUCTIONARY_SELLING_GROUPS.HiddenItems = {}
end

function Auctionator.Groups.GetHiddenItemLinks()
  return AUCTIONARY_SELLING_GROUPS.HiddenItems
end
