local Auctionator = Auctionary

AuctionaryShoppingListManagerMixin = {}

-- getData: function() -> table. Returns raw shopping list data storage
-- setData: function(newVal) newVal: table -> nil. Used to overwrite the
--  shopping list data storage with new data
function AuctionaryShoppingListManagerMixin:Init(getData, setData)
  assert(type(getData) == "function" and type(setData) == "function")
  self.getData = getData
  self.setData = setData

  if self.getData() == nil then
    self.setData({})
  end

  Auctionator.EventBus:RegisterSource(self, "shopping list manager")

  self:Prune()
  self:Sort()
end

function AuctionaryShoppingListManagerMixin:Create(listName, isTemporary)
  isTemporary = isTemporary or false

  assert(type(listName) == "string")
  assert(type(isTemporary) == "boolean")

  table.insert(self.getData(), {
    name = listName,
    items = {},
    isTemporary = isTemporary,
  })

  self:Sort()

  self:FireMetaChangeEvent(listName)
end

function AuctionaryShoppingListManagerMixin:Sort()
  table.sort(self.getData(), function(left, right)
    local lowerLeft = string.lower(left.name)
    local lowerRight = string.lower(right.name)

    -- Handle case where names are the same, when ignoring lettercase
    if lowerLeft == lowerRight then
      return left.name < right.name
    else
      return lowerLeft < lowerRight
    end
  end)

  self:FireMetaChangeEvent()
end

function AuctionaryShoppingListManagerMixin:Prune()
  local lists = {}

  for _, list in ipairs(self.getData()) do
    if not list.isTemporary then
      table.insert(lists, list)
    end
  end

  self.setData(lists)

  self:FireMetaChangeEvent()
end

function AuctionaryShoppingListManagerMixin:GetIndexForName(listName)
  for index, list in ipairs(self.getData()) do
    if list.name == listName then
      return index
    end
  end

  return nil
end

function AuctionaryShoppingListManagerMixin:GetCount()
  return #self.getData()
end

function AuctionaryShoppingListManagerMixin:GetByIndex(listIndex)
  local data =  self.getData()[listIndex]
  assert(data, "List index doesn't exist")

  return Auctionator.Compat.CreateAndInitFromMixin(AuctionaryShoppingListMixin, data, self)
end

function AuctionaryShoppingListManagerMixin:GetByName(listName)
  return self:GetByIndex(self:GetIndexForName(listName))
end

function AuctionaryShoppingListManagerMixin:Delete(listName)
  local listIndex = self:GetIndexForName(listName)
  assert(listIndex ~= nil, "List doesn't exist")

  table.remove(self.getData(), listIndex)

  self:FireMetaChangeEvent(listName)
end

function AuctionaryShoppingListManagerMixin:GetUnusedName(prefix)
  local currentIndex = 1
  local newName = prefix

  while self:GetIndexForName(newName) ~= nil do
    currentIndex = currentIndex + 1
    newName = prefix .. " " .. currentIndex
  end

  return newName
end

function AuctionaryShoppingListManagerMixin:FireItemChangeEvent(listName)
  Auctionator.EventBus:Fire(self, Auctionator.Shopping.Events.ListItemChange, listName)
end

function AuctionaryShoppingListManagerMixin:FireMetaChangeEvent(listName)
  Auctionator.EventBus:Fire(self, Auctionator.Shopping.Events.ListMetaChange, listName)
end
