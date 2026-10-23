local Auctionary = Auctionary

-- What a crafted item costs to make ("Mats Cost" in tooltips).
--
-- The 3.3.5 client has no list of all recipes, so recipes are learned from
-- the profession windows the player opens: their own professions on every
-- character, and professions other players link in chat. Each recipe is kept
-- as crafted item -> reagents in the saved variables. For everything else the
-- recipe list shipped in Data/Recipes.lua is used.
--
-- AUCTIONARY_RECIPES[craftedItemID][recipeSpellID] = {
--   made = number of items one craft makes,
--   r = { [reagentItemID] = count, ... },
-- }
local RECIPES_DB_VERSION = 1

function Auctionary.CraftingInfo.InitializeRecipes()
  if AUCTIONARY_RECIPES == nil or AUCTIONARY_RECIPES["__dbversion"] ~= RECIPES_DB_VERSION then
    AUCTIONARY_RECIPES = { ["__dbversion"] = RECIPES_DB_VERSION }
  end
end

local function IDFromLink(link, linkType)
  if link == nil then
    return nil
  end
  return link:match(linkType .. ":(%d+)")
end

-- Reads the profession window that is open right now
function Auctionary.CraftingInfo.ScanTradeSkill()
  if AUCTIONARY_RECIPES == nil then
    return
  end

  local learned = 0
  for index = 1, GetNumTradeSkills() do
    local _, skillType = GetTradeSkillInfo(index)
    if skillType ~= "header" then
      local itemID = IDFromLink(GetTradeSkillItemLink(index), "item")
      local recipeID = IDFromLink(GetTradeSkillRecipeLink(index), "enchant")
      -- Enchants have no item, they are not something to sell on their own
      if itemID ~= nil and recipeID ~= nil then
        local minMade, maxMade = GetTradeSkillNumMade(index)
        local recipe = {
          made = math.max(((minMade or 1) + (maxMade or minMade or 1)) / 2, 1),
          r = {},
        }
        local complete = true
        for reagentIndex = 1, GetTradeSkillNumReagents(index) do
          local reagentID = IDFromLink(GetTradeSkillReagentItemLink(index, reagentIndex), "item")
          local _, _, count = GetTradeSkillReagentInfo(index, reagentIndex)
          if reagentID == nil or count == nil then
            complete = false -- reagent not loaded yet, next update has it
            break
          end
          recipe.r[reagentID] = (recipe.r[reagentID] or 0) + count
        end

        if complete and next(recipe.r) ~= nil then
          local forItem = AUCTIONARY_RECIPES[itemID]
          if forItem == nil then
            forItem = {}
            AUCTIONARY_RECIPES[itemID] = forItem
          end
          if forItem[recipeID] == nil then
            learned = learned + 1
          end
          forItem[recipeID] = recipe
        end
      end
    end
  end

  if learned > 0 then
    Auctionary.Debug.Message("recipes learned", learned)
  end
end

-- Price of one reagent: what a vendor sells it for if a vendor was seen
-- selling it (vials, thread, ...), else the last auction price. nil if unknown.
function Auctionary.CraftingInfo.GetReagentPrice(reagentID)
  local vendorPrice = AUCTIONARY_VENDOR_PRICE_CACHE and AUCTIONARY_VENDOR_PRICE_CACHE[reagentID]
  if vendorPrice ~= nil then
    return vendorPrice
  end
  if Auctionary.Database ~= nil then
    return Auctionary.Database:GetPrice(reagentID)
  end
  return nil
end

-- Cost of the reagents for one of the item, from the cheapest known recipe.
-- Returns cost, number of reagents without a known price (their cost is not
-- in the first value). nil if no recipe for the item is known.
-- Enchanting scrolls are written on a vellum. The shipped list only knows
-- its rank ("v1" to "v3"); weapon or armor is told from the scroll's name.
local WEAPON_VELLUMS = { v1 = "39349", v2 = "39350", v3 = "43146" }
local ARMOR_VELLUMS = { v1 = "38682", v2 = "37602", v3 = "43145" }

-- Returns the item ID to price, nil if the reagent does not apply to this
-- item, or false if it cannot be told yet (item not in the client's cache)
local function ResolveReagent(reagentID, craftedItemID)
  if WEAPON_VELLUMS[reagentID] == nil then
    return reagentID
  end
  local name = GetItemInfo(craftedItemID)
  if name == nil then
    return false
  end
  if not name:find("^Scroll of Enchant") then
    return nil -- a rod, oil or wand: made without vellum
  end
  if name:find("Weapon", 1, true) or name:find("Staff", 1, true) then
    return WEAPON_VELLUMS[reagentID]
  end
  return ARMOR_VELLUMS[reagentID]
end

-- Recipes shipped with the addon (Data/Recipes.lua), unpacked when first asked for
local staticCache = {}
local function GetStaticRecipes(itemID)
  local cached = staticCache[itemID]
  if cached ~= nil then
    return cached or nil
  end
  local packed = Auctionary.CraftingInfo.StaticRecipes and Auctionary.CraftingInfo.StaticRecipes[itemID]
  if packed == nil then
    staticCache[itemID] = false
    return nil
  end
  local recipes = {}
  for part in string.gmatch(packed, "[^|]+") do
    local made, reagents = part:match("^(%d+):(.+)$")
    if made ~= nil then
      local recipe = { made = math.max(tonumber(made), 1), r = {} }
      for reagentID, count in string.gmatch(reagents, "(%w+)%*(%d+)") do
        recipe.r[reagentID] = tonumber(count)
      end
      table.insert(recipes, recipe)
    end
  end
  staticCache[itemID] = recipes
  return recipes
end

---- Darkmoon decks
-- A deck is put together from its cards (Ace and Two to Eight; the small
-- decks need fewer). The cards are recognised by their English names when
-- they show up in a scan, so nothing has to be known in advance.
local CARD_RANKS = {
  Ace = 1, Two = 2, Three = 3, Four = 4, Five = 5, Six = 6, Seven = 7, Eight = 8,
}
local SMALL_DECKS = { Rogues = 3, Swords = 4, Mages = 5, Demons = 6 }

-- Called for auctions seen in scans and searches
function Auctionary.CraftingInfo.NoteItemName(name, itemLink)
  -- Every name seen is also kept for the search's spelling help
  Auctionary.Search.NoteItemName(name, itemLink and itemLink:match("|Hitem:(%d+)"))
  if name == nil or AUCTIONARY_RECIPES == nil then
    return
  end
  local rankName, suit = name:match("^(%a+) of (.+)$")
  local rank = rankName and CARD_RANKS[rankName]
  if rank == nil then
    return
  end
  local itemID = IDFromLink(itemLink, "item")
  if itemID == nil then
    return
  end
  local cards = AUCTIONARY_RECIPES["__cards"]
  if cards == nil then
    cards = {}
    AUCTIONARY_RECIPES["__cards"] = cards
  end
  cards[suit] = cards[suit] or {}
  cards[suit][rank] = itemID
end

local function GetDeckCost(itemID)
  local name = GetItemInfo(itemID)
  local suit = name and name:match("^(.+) Deck$")
  local cards = suit and AUCTIONARY_RECIPES["__cards"] and AUCTIONARY_RECIPES["__cards"][suit]
  if cards == nil then
    return nil
  end

  local cost, missing = 0, 0
  for rank = 1, SMALL_DECKS[suit] or 8 do
    local price = cards[rank] and Auctionary.CraftingInfo.GetReagentPrice(cards[rank])
    if price ~= nil then
      cost = cost + price
    else
      missing = missing + 1
    end
  end
  return cost, missing
end

local NORTH_CARD_ID = "44318"
local NORTHREND_SUITS = { Nobles = true, Prisms = true, Chaos = true, Undeath = true }

-- Returns the cost, the number of reagents without a known price, and
-- optionally a note to show with it
function Auctionary.CraftingInfo.GetMatsCost(itemID)
  itemID = tostring(itemID)
  -- What was read from a profession window on this server is trusted over
  -- the shipped list
  local forItem = AUCTIONARY_RECIPES and AUCTIONARY_RECIPES[itemID]
  if type(forItem) ~= "table" then
    forItem = GetStaticRecipes(itemID)
  end
  if forItem == nil then
    -- The Northrend cards all come from "Darkmoon Card of the North", which
    -- turns into a random one of them
    local name = GetItemInfo(itemID)
    local suit = name and name:match("^%a+ of (%a+)$")
    if suit ~= nil and NORTHREND_SUITS[suit] and itemID ~= NORTH_CARD_ID then
      local cost, missing = Auctionary.CraftingInfo.GetMatsCost(NORTH_CARD_ID)
      return cost, missing, "3% chance"
    end
    if AUCTIONARY_RECIPES ~= nil then
      return GetDeckCost(itemID)
    end
    return nil
  end

  local bestCost, bestMissing
  for _, recipe in pairs(forItem) do
    local cost, missing = 0, 0
    for reagentID, count in pairs(recipe.r) do
      local resolvedID = ResolveReagent(reagentID, itemID)
      if resolvedID ~= nil then
        local price = resolvedID and Auctionary.CraftingInfo.GetReagentPrice(resolvedID)
        if price then
          cost = cost + price * count
        else
          missing = missing + 1
        end
      end
    end
    cost = cost / recipe.made

    -- Fully priced recipes win over partly priced ones, then the cheaper one
    if bestCost == nil or missing < bestMissing or (missing == bestMissing and cost < bestCost) then
      bestCost, bestMissing = cost, missing
    end
  end

  if bestCost == nil then
    return nil
  end
  return math.floor(bestCost), bestMissing
end

---- Learning

local frame = CreateFrame("Frame", "AuctionaryRecipesFrame")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_UPDATE")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_UPDATE")

local scanPending = false

-- Prices of what vendors sell in unlimited supply for gold
local function ScanMerchant()
  if AUCTIONARY_VENDOR_PRICE_CACHE == nil then
    return
  end
  for index = 1, GetMerchantNumItems() do
    local _, _, price, quantity, numAvailable, _, extendedCost = GetMerchantItemInfo(index)
    local itemID = IDFromLink(GetMerchantItemLink(index), "item")
    if itemID ~= nil and price ~= nil and price > 0 and numAvailable == -1 and
       not extendedCost and quantity ~= nil and quantity > 0 then
      AUCTIONARY_VENDOR_PRICE_CACHE[itemID] = math.ceil(price / quantity)
    end
  end
end

frame:SetScript("OnEvent", function(_, eventName)
  if not Auctionary.State.Loaded then
    return
  end
  if eventName == "MERCHANT_SHOW" or eventName == "MERCHANT_UPDATE" then
    ScanMerchant()
  elseif not scanPending then
    -- The window sends several updates while it fills; read it once after
    scanPending = true
    Auctionary.Compat.After(0.5, function()
      scanPending = false
      local ok, message = pcall(Auctionary.CraftingInfo.ScanTradeSkill)
      if not ok then
        Auctionary.Debug.Message("recipe scan failed", message)
      end
    end)
  end
end)
