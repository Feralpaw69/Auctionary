local Auctionary = Auctionary

-- Adds the price lines to item tooltips. Every way the 3.3.5 client fills an
-- item tooltip is a method of the tooltip; each handler finds the item link
-- and the stack size for that method.
local TooltipHandlers = {}

local function Show(tip, itemLink, itemCount)
  if itemLink == nil then
    local _
    _, itemLink = tip:GetItem()
  end
  if itemLink ~= nil then
    Auctionary.Tooltip.ShowTipWithPricing(tip, itemLink, itemCount or 1)
  end
end

-- Bags
TooltipHandlers["SetBagItem"] = function(tip, bag, slot)
  local _, itemCount = GetContainerItemInfo(bag, slot)
  Show(tip, GetContainerItemLink(bag, slot), itemCount)
end

-- Equipped items, bank slots and the bags themselves
TooltipHandlers["SetInventoryItem"] = function(tip, unit, slot)
  local itemCount = GetInventoryItemCount(unit, slot)
  Show(tip, GetInventoryItemLink(unit, slot), itemCount)
end

TooltipHandlers["SetGuildBankItem"] = function(tip, tab, slot)
  local _, itemCount = GetGuildBankItemInfo(tab, slot)
  Show(tip, GetGuildBankItemLink(tab, slot), itemCount)
end

-- Merchant
TooltipHandlers["SetMerchantItem"] = function(tip, index)
  local _, _, _, itemCount = GetMerchantItemInfo(index)
  Show(tip, GetMerchantItemLink(index), itemCount)
end

TooltipHandlers["SetBuybackItem"] = function(tip, slotIndex)
  local _, _, _, itemCount = GetBuybackItemInfo(slotIndex)
  Show(tip, GetBuybackItemLink(slotIndex), itemCount)
end

-- Auction house
TooltipHandlers["SetAuctionItem"] = function(tip, view, index)
  local _, _, itemCount = GetAuctionItemInfo(view, index)
  Show(tip, GetAuctionItemLink(view, index), itemCount)
end

TooltipHandlers["SetAuctionSellItem"] = function(tip)
  local _, _, itemCount = GetAuctionSellItemInfo()
  Show(tip, nil, itemCount)
end

-- Loot
TooltipHandlers["SetLootItem"] = function(tip, slot)
  if LootSlotIsItem(slot) then
    local _, _, itemCount = GetLootSlotInfo(slot)
    Show(tip, GetLootSlotLink(slot), itemCount)
  end
end

TooltipHandlers["SetLootRollItem"] = function(tip, rollID)
  local _, _, itemCount = GetLootRollItemInfo(rollID)
  Show(tip, GetLootRollItemLink(rollID), itemCount)
end

-- Quests
TooltipHandlers["SetQuestItem"] = function(tip, itemType, index)
  local _, _, itemCount = GetQuestItemInfo(itemType, index)
  Show(tip, GetQuestItemLink(itemType, index), itemCount)
end

TooltipHandlers["SetQuestLogItem"] = function(tip, itemType, index)
  local itemCount, _
  if itemType == "choice" then
    _, _, itemCount = GetQuestLogChoiceInfo(index)
  else
    _, _, itemCount = GetQuestLogRewardInfo(index)
  end
  Show(tip, GetQuestLogItemLink(itemType, index), itemCount)
end

-- Mail
TooltipHandlers["SetInboxItem"] = function(tip, index, attachIndex)
  local _, _, itemCount = GetInboxItem(index, attachIndex or 1)
  Show(tip, GetInboxItemLink(index, attachIndex or 1), itemCount)
end

TooltipHandlers["SetSendMailItem"] = function(tip, index)
  local _, _, itemCount = GetSendMailItem(index)
  Show(tip, nil, itemCount)
end

-- Trade window
TooltipHandlers["SetTradePlayerItem"] = function(tip, index)
  local _, _, itemCount = GetTradePlayerItemInfo(index)
  Show(tip, GetTradePlayerItemLink(index), itemCount)
end

TooltipHandlers["SetTradeTargetItem"] = function(tip, index)
  local _, _, itemCount = GetTradeTargetItemInfo(index)
  Show(tip, GetTradeTargetItemLink(index), itemCount)
end

-- Professions
TooltipHandlers["SetTradeSkillItem"] = function(tip, recipeIndex, reagentIndex)
  if reagentIndex ~= nil then
    local _, _, itemCount = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
    Show(tip, GetTradeSkillReagentItemLink(recipeIndex, reagentIndex), itemCount)
  else
    Show(tip, GetTradeSkillItemLink(recipeIndex), (GetTradeSkillNumMade(recipeIndex)))
  end
end

-- Item links in chat and everything shown by other addons
TooltipHandlers["SetHyperlink"] = function(tip, link)
  if type(link) == "string" and string.find(link, "item:", 1, true) then
    Show(tip, nil, 1)
  end
end

local function Guarded(handler)
  return function(...)
    if Auctionary.State.Loaded then
      local ok, message = pcall(handler, ...)
      if not ok then
        Auctionary.Debug.Message("tooltip handler failed", message)
      end
    end
  end
end

for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
  for method, handler in pairs(TooltipHandlers) do
    if type(tooltip[method]) == "function" then
      hooksecurefunc(tooltip, method, Guarded(handler))
    end
  end
end
