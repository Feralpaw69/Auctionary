-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Waiting line for auction house requests
-- The server only takes a new request every so often. Requests are run
-- right away when allowed, otherwise in order as soon as the throttle says
-- the auction house is ready again.

local Queue = {}
Auctionary.AH.QueueMixin = Queue

function Queue:Init()
  self.queue = {}
  Auctionary.EventBus:Register(self, { Auctionary.AH.Events.Ready })
end

local function RunNext(self)
  local request = table.remove(self.queue, 1)
  if request ~= nil then
    Auctionary.AH.Internals.throttling:SearchQueried()
    request()
  end
end

function Queue:Enqueue(request)
  self.queue[#self.queue + 1] = request
  if Auctionary.AH.Internals.throttling:IsReady() then
    RunNext(self)
  end
end

function Queue:Remove(request)
  for index = #self.queue, 1, -1 do
    if self.queue[index] == request then
      table.remove(self.queue, index)
    end
  end
end

function Queue:ReceiveEvent()
  RunNext(self)
end
