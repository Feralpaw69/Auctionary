local Auctionary = Auctionary

Auctionary.Shopping.Recents = {}

function Auctionary.Shopping.Recents.Save(searchText)
  local prevIndex = Auctionary.Compat.tIndexOf(AUCTIONARY_RECENT_SEARCHES, searchText)
  if prevIndex ~= nil then
    table.remove(AUCTIONARY_RECENT_SEARCHES, prevIndex)
  end

  table.insert(AUCTIONARY_RECENT_SEARCHES, 1, searchText)

  while #AUCTIONARY_RECENT_SEARCHES > Auctionary.Constants.RecentsListLimit do
    table.remove(AUCTIONARY_RECENT_SEARCHES)
  end

  Auctionary.EventBus
    :RegisterSource(Auctionary.Shopping.Recents.Save, "save recents entry")
    :Fire(Auctionary.Shopping.Recents.Save, Auctionary.Shopping.Events.RecentSearchesUpdate)
    :UnregisterSource(Auctionary.Shopping.Recents.Save)
end

function Auctionary.Shopping.Recents.DeleteEntry(searchTerm)
  local index = Auctionary.Compat.tIndexOf(AUCTIONARY_RECENT_SEARCHES, searchTerm)

  if index ~= nil then
    table.remove(AUCTIONARY_RECENT_SEARCHES, index)
    Auctionary.EventBus
      :RegisterSource(Auctionary.Shopping.Recents.DeleteEntry, "delete recents entry")
      :Fire(Auctionary.Shopping.Recents.DeleteEntry, Auctionary.Shopping.Events.RecentSearchesUpdate)
      :UnregisterSource(Auctionary.Shopping.Recents.DeleteEntry)
  end
end

function Auctionary.Shopping.Recents.GetAll()
  return AUCTIONARY_RECENT_SEARCHES
end
