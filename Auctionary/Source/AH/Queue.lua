local Auctionary = Auctionary

Auctionary.AH.QueueMixin = {}

function Auctionary.AH.QueueMixin:Init()
  self.queue = {}
  Auctionary.EventBus:Register(self, {
    Auctionary.AH.Events.Ready
  })
end

local function Dequeue(self)
  if #self.queue > 0 then
    Auctionary.AH.Internals.throttling:SearchQueried()
    self.queue[1]()
    table.remove(self.queue, 1)
  end
end

function Auctionary.AH.QueueMixin:Enqueue(func)
  table.insert(self.queue, func)

  if Auctionary.AH.Internals.throttling:IsReady() then
    Dequeue(self)
  end
end

function Auctionary.AH.QueueMixin:Remove(func)
  local index = Auctionary.Compat.tIndexOf(self.queue, func)
  if index ~= nil then
    table.remove(self.queue, index)
  end
end

function Auctionary.AH.QueueMixin:ReceiveEvent(event)
  Dequeue(self)
end
