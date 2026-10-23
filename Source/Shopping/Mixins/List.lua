local Auctionator = Auctionary

AuctionaryShoppingListMixin = {}

function AuctionaryShoppingListMixin:Init(data, manager)
  assert(data)
  self.data = data
  self.manager = manager
end

function AuctionaryShoppingListMixin:GetName()
  return self.data.name
end

function AuctionaryShoppingListMixin:Rename(newName)
  assert(type(newName) == "string")
  assert(self.manager:GetIndexForName(newName) == nil, "New name already in use")

  self.data.name = newName

  self.manager:FireMetaChangeEvent(self:GetName())
end

function AuctionaryShoppingListMixin:IsTemporary()
  return self.data.isTemporary
end

function AuctionaryShoppingListMixin:MakePermanent()
  self.data.isTemporary = false

  self.manager:FireMetaChangeEvent(self:GetName())
end

function AuctionaryShoppingListMixin:GetItemCount()
  return #self.data.items
end

function AuctionaryShoppingListMixin:GetItemByIndex(index)
  return self.data.items[index]
end

function AuctionaryShoppingListMixin:GetIndexForItem(item)
  return Auctionator.Compat.tIndexOf(self.data.items, item)
end

function AuctionaryShoppingListMixin:GetAllItems()
  return Auctionator.Compat.CopyTable(self.data.items)
end

function AuctionaryShoppingListMixin:DeleteItem(index)
  assert(self.data.items[index], "Nonexistent item")
  table.remove(self.data.items, index)

  self.manager:FireItemChangeEvent(self:GetName())
end

function AuctionaryShoppingListMixin:AlterItem(index, newItem)
  assert(self.data.items[index], "Nonexistent item")
  assert(type(newItem) == "string")

  self.data.items[index] = newItem

  self.manager:FireItemChangeEvent(self:GetName())
end

function AuctionaryShoppingListMixin:InsertItem(newItem, index)
  assert(type(newItem) == "string")
  if index ~= nil then
    table.insert(self.data.items, index, newItem)
  else
    table.insert(self.data.items, newItem)
  end

  self.manager:FireItemChangeEvent(self:GetName())
end

function AuctionaryShoppingListMixin:ClearItems()
  self.data.items = {}
end

function AuctionaryShoppingListMixin:AppendItems(newItems)
  for _, i in ipairs(newItems) do
    assert(type(i) == "string")
    table.insert(self.data.items, i)
  end

  self.manager:FireItemChangeEvent(self:GetName())
end

function AuctionaryShoppingListMixin:Sort()
  table.sort(self.data.items, function(a, b)
    return a:lower():gsub("\"", "") < b:lower():gsub("\"", "")
  end)
  self.manager:FireItemChangeEvent(self:GetName())
end
