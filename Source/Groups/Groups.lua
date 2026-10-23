local Auctionary = Auctionary

function Auctionary.Groups.DoesGroupExist(name)
  return Auctionary.Groups.Utilities.IsContainedPredicate(AUCTIONARY_SELLING_GROUPS.CustomGroups, function(item) return item.name == name end)
end
function Auctionary.Groups.AddGroup(name)
  assert(not Auctionary.Groups.DoesGroupExist(name), "Group already exists")

  table.insert(AUCTIONARY_SELLING_GROUPS.CustomGroups, {
    name = name,
    type = Auctionary.Groups.Constants.GroupType.List,
    list = {},
    hidden = false,
  })
end

function Auctionary.Groups.GetGroupIndex(name)
  for index, s in ipairs(AUCTIONARY_SELLING_GROUPS.CustomGroups) do
    if s.name == name then
      return index
    end
  end
  return nil
end

function Auctionary.Groups.GetGroupNameByIndex(index)
  return AUCTIONARY_SELLING_GROUPS.CustomGroups[index] and AUCTIONARY_SELLING_GROUPS.CustomGroups[index].name
end

function Auctionary.Groups.GetGroupList(name)
  return AUCTIONARY_SELLING_GROUPS.CustomGroups[Auctionary.Groups.GetGroupIndex(name)].list
end

function Auctionary.Groups.HideItemLink(itemLink)
  table.insert(AUCTIONARY_SELLING_GROUPS.HiddenItems, itemLink)
end

function Auctionary.Groups.UnhideItemLink(itemLink)
  local index = Auctionary.Compat.tIndexOf(AUCTIONARY_SELLING_GROUPS.HiddenItems, itemLink)
  if index ~= nil then
    table.remove(AUCTIONARY_SELLING_GROUPS.HiddenItems, index)
  end
end

function Auctionary.Groups.UnhideAll()
  AUCTIONARY_SELLING_GROUPS.HiddenItems = {}
end

function Auctionary.Groups.GetHiddenItemLinks()
  return AUCTIONARY_SELLING_GROUPS.HiddenItems
end
