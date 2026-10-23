local Auctionator = Auctionary

-- Finds item names close to a mistyped search ("etrnl life" -> "Eternal
-- Life"). The server only matches exact parts of names, so the names of all
-- items ever seen in the auction house are remembered and compared here.

local function Names()
  if Auctionator.SavedState == nil then
    return nil
  end
  Auctionator.SavedState.ItemNames = Auctionator.SavedState.ItemNames or {}
  return Auctionator.SavedState.ItemNames
end

-- The value is the item's id when it is known (true for names noted by
-- older versions)
local lowerIndex
function Auctionator.Search.NoteItemName(name, itemID)
  local names = Names()
  if names ~= nil and name ~= nil and name ~= "" then
    names[name] = tonumber(itemID) or names[name] or true
    if lowerIndex ~= nil then
      lowerIndex[name:lower()] = names[name]
    end
  end
end

-- Drops the lower-case name index; it is rebuilt the next time it is needed
function Auctionator.Search.ClearNameIndex()
  lowerIndex = nil
end

-- Item id for an exact item name (upper/lower case does not matter), or nil
function Auctionator.Search.GetItemIDByName(name)
  local names = Names()
  if names == nil or name == nil or name == "" then
    return nil
  end
  if lowerIndex == nil then
    lowerIndex = {}
    for known, value in pairs(names) do
      lowerIndex[known:lower()] = value
    end
  end
  local value = lowerIndex[name:lower()]
  return type(value) == "number" and value or nil
end

-- Number of single-letter changes that turn a into b, given up on (nil) as
-- soon as it must be more than limit
local function EditDistance(a, b, limit)
  local lenA, lenB = #a, #b
  if math.abs(lenA - lenB) > limit then
    return nil
  end
  local previous, current = {}, {}
  for j = 0, lenB do
    previous[j] = j
  end
  for i = 1, lenA do
    current[0] = i
    local best = i
    local charA = a:byte(i)
    for j = 1, lenB do
      local cost = (charA == b:byte(j)) and 0 or 1
      local value = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
      -- two neighbouring letters swapped count as one change
      if i > 1 and j > 1 and charA == b:byte(j - 1) and a:byte(i - 1) == b:byte(j) then
        value = math.min(value, (previous.before and previous.before[j - 2] or value) + 1)
      end
      current[j] = value
      if value < best then
        best = value
      end
    end
    if best > limit then
      return nil
    end
    current.before = previous
    previous, current = current, {}
  end
  local result = previous[lenB]
  return result <= limit and result or nil
end

local function Words(text)
  local words = {}
  for word in text:lower():gmatch("[^%s]+") do
    table.insert(words, word)
  end
  return words
end

-- How many mistakes a word of this length may have
local function Allowed(word)
  local length = #word
  if length <= 3 then
    return 0
  elseif length == 4 then
    return 1
  elseif length == 5 then
    return 2
  end
  return math.max(2, math.floor(length * 0.4))
end

-- Lower is closer; nil when the name does not fit
local function Score(queryWords, name)
  local nameWords = Words(name)
  if #nameWords < #queryWords then
    return nil
  end
  local used, total = {}, 0
  for _, queryWord in ipairs(queryWords) do
    local limit = Allowed(queryWord)
    local best, bestIndex
    for index, nameWord in ipairs(nameWords) do
      if not used[index] then
        local distance
        if nameWord == queryWord then
          distance = 0
        elseif limit == 0 then
          -- short words only as the start of a word
          distance = (nameWord:sub(1, #queryWord) == queryWord) and 0.5 or nil
        else
          distance = EditDistance(queryWord, nameWord, limit)
        end
        if distance ~= nil and (best == nil or distance < best) then
          best, bestIndex = distance, index
        end
      end
    end
    if best == nil then
      return nil
    end
    used[bestIndex] = true
    total = total + best
  end
  -- Names with fewer extra words are the more likely ones
  return total + (#nameWords - #queryWords) * 0.3
end

-- Up to maxResults names, closest first. Exact matches of the text are left
-- out: the normal search has found nothing for them already.
function Auctionator.Search.FindSimilarNames(text, maxResults)
  local names = Names()
  local queryWords = Words(text or "")
  if names == nil or #queryWords == 0 then
    return {}
  end
  local lowerText = text:lower()
  local found = {}
  for name in pairs(names) do
    if not name:lower():find(lowerText, 1, true) then
      local score = Score(queryWords, name)
      if score ~= nil then
        table.insert(found, { name = name, score = score })
      end
    end
  end
  table.sort(found, function(a, b)
    if a.score ~= b.score then
      return a.score < b.score
    end
    return a.name < b.name
  end)
  local results = {}
  for index = 1, math.min(maxResults or 3, #found) do
    results[index] = found[index].name
  end
  return results
end
