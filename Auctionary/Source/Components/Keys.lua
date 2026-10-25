-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

-- Keyboard shortcuts of the tabs (arrow keys, Enter). Each key is bound to a
-- hidden button while it is wanted, so the action runs as a real key press
-- (buying and posting are only allowed then). Text boxes with the cursor in
-- them still get their keys first.
Auctionary.Keys = {}

local count = 0

-- handlers: { UP = function() end, ... }; isWanted(key) says per key whether
-- it should be bound right now
function Auctionary.Keys.Create(handlers, isWanted)
  count = count + 1
  local owner = CreateFrame("Frame", nil, UIParent)
  local buttons, bound = {}, {}
  for key, handler in pairs(handlers) do
    local name = "Auctionary2Key" .. count .. key
    local button = CreateFrame("Button", name, owner)
    button:Hide()
    button:SetScript("OnClick", function()
      pcall(handler)
    end)
    buttons[key] = name
  end

  local function Update()
    if InCombatLockdown ~= nil and InCombatLockdown() then
      return
    end
    for key, name in pairs(buttons) do
      local ok, wanted = pcall(isWanted, key)
      wanted = ok and wanted and true or false
      if wanted ~= (bound[key] == true) then
        if wanted then
          SetOverrideBindingClick(owner, true, key, name)
        else
          SetOverrideBinding(owner, true, key, nil)
        end
        bound[key] = wanted
      end
    end
  end

  -- Checked only while the auction house is open; on closing, the keys
  -- are released once and the checks stop
  local elapsed = 0
  owner:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed >= 0.15 then
      elapsed = 0
      Update()
      if AuctionFrame == nil or not AuctionFrame:IsShown() then
        owner:Hide()
      end
    end
  end)
  owner:RegisterEvent("AUCTION_HOUSE_SHOW")
  owner:SetScript("OnEvent", function()
    owner:Show()
  end)
  return { Update = Update }
end
