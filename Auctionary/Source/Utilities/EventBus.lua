-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Event bus
-- Parts of the addon talk to each other with named messages. A listener is
-- any table with a ReceiveEvent(eventName, ...) method.
-- Senders announce themselves with RegisterSource first; that keeps mistakes
-- (a message sent by something that was never set up) easy to spot.

local bus = { listeners = {}, sources = {} }

function bus:Register(listener, eventNames)
  assert(type(listener.ReceiveEvent) == "function", "listener needs ReceiveEvent")
  for _, eventName in ipairs(eventNames) do
    local list = self.listeners[eventName]
    if list == nil then
      list = {}
      self.listeners[eventName] = list
    end
    list[#list + 1] = listener
  end
  return self
end

function bus:Unregister(listener, eventNames)
  for _, eventName in ipairs(eventNames) do
    local list = self.listeners[eventName]
    if list ~= nil then
      for index = #list, 1, -1 do
        if list[index] == listener then
          table.remove(list, index)
          break
        end
      end
    end
  end
  return self
end

function bus:RegisterSource(source, name)
  self.sources[source] = name or true
  return self
end

function bus:UnregisterSource(source)
  self.sources[source] = nil
  return self
end

function bus:IsSourceRegistered(source)
  return self.sources[source] ~= nil
end

function bus:Fire(source, eventName, ...)
  if self.sources[source] == nil then
    error("Event sent by an unregistered source: " .. tostring(eventName))
  end
  local list = self.listeners[eventName]
  if list == nil or #list == 0 then
    return self
  end
  -- A copy, as listeners may register or unregister while being told
  local copy = {}
  for index = 1, #list do
    copy[index] = list[index]
  end
  for index = 1, #copy do
    copy[index]:ReceiveEvent(eventName, ...)
  end
  return self
end

Auctionary.EventBus = bus
