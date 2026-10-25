-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

-- Item categories of the 3.3.5 auction house as used by extended searches.
-- A category key is "Class", "Class/Subclass" or "Class/Subclass/Slot" using
-- the names the client shows (so keys depend on the client language, as in
-- the original addon).
local tree = nil
local lookup = nil

local function Build()
  tree = {}
  lookup = {}

  local classes = { GetAuctionItemClasses() }
  for classIndex, className in ipairs(classes) do
    local classEntry = {
      name = className,
      key = className,
      classIndex = classIndex,
      subCategories = {},
    }
    lookup[classEntry.key] = classEntry
    table.insert(tree, classEntry)

    local subClasses = { GetAuctionItemSubClasses(classIndex) }
    for subclassIndex, subClassName in ipairs(subClasses) do
      local subEntry = {
        name = subClassName,
        key = className .. "/" .. subClassName,
        classIndex = classIndex,
        subclassIndex = subclassIndex,
        subCategories = {},
      }
      lookup[subEntry.key] = subEntry
      table.insert(classEntry.subCategories, subEntry)

      -- Pairs of (global name of the slot text, shown in the list)
      local invTypes = { GetAuctionInvTypes(classIndex, subclassIndex) }
      for i = 1, #invTypes, 2 do
        local slotName = _G[invTypes[i]]
        if slotName ~= nil and invTypes[i + 1] then
          local slotEntry = {
            name = slotName,
            key = subEntry.key .. "/" .. slotName,
            classIndex = classIndex,
            subclassIndex = subclassIndex,
            invTypeIndex = (i + 1) / 2,
          }
          lookup[slotEntry.key] = slotEntry
          table.insert(subEntry.subCategories, slotEntry)
        end
      end
    end
  end
end

function Auctionary.Search.GetLegacyCategoryTree()
  if tree == nil then
    Build()
  end
  return tree
end

-- nil for an empty or unknown key
function Auctionary.Search.GetLegacyCategory(categoryKey)
  if categoryKey == nil or categoryKey == "" then
    return nil
  end
  if lookup == nil then
    Build()
  end
  return lookup[categoryKey]
end
