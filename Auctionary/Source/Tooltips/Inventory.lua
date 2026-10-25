-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

local WHITE = Auctionary.Compat.Colors.WHITE_FONT_COLOR

---- How many of an item the characters of this account own (bags and bank)

-- Items of this character: SavedState.Inventory[realm][character][itemID] = count
local function OwnInventory()
  local state = Auctionary.SavedState
  local realm, character = GetRealmName(), UnitName("player")
  if state == nil or realm == nil or character == nil then
    return nil
  end
  state.Inventory = state.Inventory or {}
  state.Inventory[realm] = state.Inventory[realm] or {}
  state.Inventory[realm][character] = state.Inventory[realm][character] or {}
  return state.Inventory[realm][character], state.Inventory[realm], character
end

-- The bank bags only answer while the bank is open; what was seen there
-- before is kept and counted with GetItemCount, which knows the bank anyway
local function UpdateInventory()
  local own = OwnInventory()
  if own == nil then
    return
  end
  local ids = {}
  for itemID in pairs(own) do
    ids[itemID] = true
  end
  for bag = -1, 11 do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      local itemID = link and tonumber(link:match("item:(%d+)"))
      if itemID ~= nil then
        ids[itemID] = true
      end
    end
  end
  for itemID in pairs(ids) do
    local count = GetItemCount(itemID, true) or 0
    own[itemID] = count > 0 and count or nil
  end
end

local inventoryFrame = CreateFrame("Frame")
local pending
inventoryFrame:RegisterEvent("BAG_UPDATE")
inventoryFrame:RegisterEvent("BANKFRAME_OPENED")
inventoryFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
inventoryFrame:RegisterEvent("PLAYER_LOGOUT")
inventoryFrame:SetScript("OnEvent", function(_, eventName)
  if eventName == "PLAYER_LOGOUT" then
    pcall(UpdateInventory)
  else
    -- Bag events come often (looting, fighting): one update at most every
    -- few seconds, never during a fight. Only then the frame counts down.
    if pending == nil then
      pending = 5
      inventoryFrame:Show()
    end
  end
end)
inventoryFrame:SetScript("OnUpdate", function(_, elapsed)
  if pending == nil then
    inventoryFrame:Hide()
    return
  end
  pending = pending - (elapsed or 0)
  if pending <= 0 then
    if InCombatLockdown ~= nil and InCombatLockdown() then
      pending = 2
      return
    end
    pending = nil
    inventoryFrame:Hide()
    pcall(UpdateInventory)
  end
end)
inventoryFrame:Hide()

-- Shown when the account owns more than one of the item (on this realm)
-- Altoholic shows the same information; with it enabled ours stays away
local function AltoholicActive()
  if IsAddOnLoaded ~= nil and IsAddOnLoaded("Altoholic") then
    return true
  end
  if GetAddOnInfo ~= nil then
    local name, _, _, enabled = GetAddOnInfo("Altoholic")
    return name ~= nil and enabled ~= nil and enabled ~= false and enabled ~= 0
  end
  return false
end

-- add(left, right, r, g, b) adds one line
function Auctionary.Tooltip.AddOwnedLines(add, itemLink)
  if AltoholicActive() then
    return
  end
  local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
  local _, realmData, character = OwnInventory()
  if itemID == nil or realmData == nil then
    return
  end
  local total, owners = 0, {}
  for name, items in pairs(realmData) do
    local count
    if name == character then
      count = GetItemCount(itemID, true) or 0
    else
      count = type(items) == "table" and tonumber(items[itemID]) or 0
    end
    if count > 0 then
      total = total + count
      table.insert(owners, { name = name, count = count })
    end
  end
  if total <= 1 then
    return
  end
  add("You own", WHITE:WrapTextInColorCode(total .. "  "))
  if #owners > 1 or owners[1].name ~= character then
    table.sort(owners, function(a, b)
      return a.count > b.count
    end)
    for _, owner in ipairs(owners) do
      add("  " .. owner.name, WHITE:WrapTextInColorCode(owner.count .. "  "), 0.6, 0.6, 0.6)
    end
  end
end
