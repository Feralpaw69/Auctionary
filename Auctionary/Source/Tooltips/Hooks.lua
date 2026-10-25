-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Where item tooltips come from
-- Every way the client fills an item tooltip is a method of the tooltip.
-- For each of them: which item (link) and how many of it. After the client
-- has filled the tooltip, the price lines are added.

local function Second(_, value) return value end
local function Third(_, _, value) return value end
local function Fourth(_, _, _, value) return value end

local sources = {
  SetBagItem = function(bag, slot)
    return GetContainerItemLink(bag, slot), Second(GetContainerItemInfo(bag, slot))
  end,
  SetInventoryItem = function(unit, slot)
    return GetInventoryItemLink(unit, slot), GetInventoryItemCount(unit, slot)
  end,
  SetGuildBankItem = function(tab, slot)
    return GetGuildBankItemLink(tab, slot), Second(GetGuildBankItemInfo(tab, slot))
  end,
  SetMerchantItem = function(index)
    return GetMerchantItemLink(index), Fourth(GetMerchantItemInfo(index))
  end,
  SetBuybackItem = function(index)
    return GetBuybackItemLink(index), Fourth(GetBuybackItemInfo(index))
  end,
  SetAuctionItem = function(view, index)
    return GetAuctionItemLink(view, index), Third(GetAuctionItemInfo(view, index))
  end,
  SetAuctionSellItem = function()
    return nil, Third(GetAuctionSellItemInfo())
  end,
  SetLootItem = function(slot)
    if LootSlotIsItem(slot) then
      return GetLootSlotLink(slot), Third(GetLootSlotInfo(slot))
    end
    return false
  end,
  SetLootRollItem = function(rollID)
    return GetLootRollItemLink(rollID), Third(GetLootRollItemInfo(rollID))
  end,
  SetQuestItem = function(kind, index)
    return GetQuestItemLink(kind, index), Third(GetQuestItemInfo(kind, index))
  end,
  SetQuestLogItem = function(kind, index)
    local count = kind == "choice" and Third(GetQuestLogChoiceInfo(index)) or Third(GetQuestLogRewardInfo(index))
    return GetQuestLogItemLink(kind, index), count
  end,
  SetInboxItem = function(index, attachment)
    return GetInboxItemLink(index, attachment or 1), Third(GetInboxItem(index, attachment or 1))
  end,
  SetSendMailItem = function(index)
    return nil, Third(GetSendMailItem(index))
  end,
  SetTradePlayerItem = function(index)
    return GetTradePlayerItemLink(index), Third(GetTradePlayerItemInfo(index))
  end,
  SetTradeTargetItem = function(index)
    return GetTradeTargetItemLink(index), Third(GetTradeTargetItemInfo(index))
  end,
  SetTradeSkillItem = function(recipe, reagent)
    if reagent ~= nil then
      return GetTradeSkillReagentItemLink(recipe, reagent), Third(GetTradeSkillReagentInfo(recipe, reagent))
    end
    return GetTradeSkillItemLink(recipe), (GetTradeSkillNumMade(recipe))
  end,
  -- Links in chat and whatever other addons show
  SetHyperlink = function(link)
    if type(link) == "string" and link:find("item:", 1, true) then
      return nil, 1
    end
    return false
  end,
}

for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
  for method, source in pairs(sources) do
    if type(tooltip[method]) == "function" then
      hooksecurefunc(tooltip, method, function(self, ...)
        if not Auctionary.State.Loaded then
          return
        end
        local ok, message = pcall(function(...)
          local itemLink, count = source(...)
          if itemLink == false then
            return
          end
          -- nil: the tooltip knows the item itself
          itemLink = itemLink or select(2, self:GetItem())
          if itemLink ~= nil then
            Auctionary.Tooltip.ShowTipWithPricing(self, itemLink, count or 1)
          end
        end, ...)
        if not ok then
          Auctionary.Debug.Message("tooltip: " .. tostring(message))
        end
      end)
    end
  end
end
