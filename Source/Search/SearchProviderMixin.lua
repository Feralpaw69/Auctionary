local Auctionator = Auctionary

AuctionarySearchProviderMixin = {}

-- Derive
function AuctionarySearchProviderMixin:OnSearchEventReceived(eventName, ...)
end

-- Derive
function AuctionarySearchProviderMixin:CreateSearchTerm(term)
end

-- Derive
function AuctionarySearchProviderMixin:GetSearchProvider()
end

-- Derive
function AuctionarySearchProviderMixin:RegisterProviderEvents()
end

-- Derive
function AuctionarySearchProviderMixin:UnregisterProviderEvents()
end

-- Derive
function AuctionarySearchProviderMixin:HasCompleteTermResults()
end

-- Derive
function AuctionarySearchProviderMixin:GetCurrentEmptyResult()
end

function AuctionarySearchProviderMixin:RegisterEvents(events)
  Auctionator.Debug.Message("AuctionarySearchProviderMixin:RegisterEvents()", events)

  Auctionator.Compat.RegisterFrameForEvents(self, events)
end

function AuctionarySearchProviderMixin:UnregisterEvents(events)
  Auctionator.Debug.Message("AuctionarySearchProviderMixin:UnregisterEvents()", events)

  Auctionator.Compat.UnregisterFrameForEvents(self, events)
end

function AuctionarySearchProviderMixin:SetTerms(terms, config)
  Auctionator.Debug.Message("AuctionarySearchProviderMixin:SetTerms()", terms, config)

  self.terms = terms
  self.config = config or {}
  self.index = 1
end

function AuctionarySearchProviderMixin:GetCurrentSearchIndex()
  return self.index
end

function AuctionarySearchProviderMixin:GetSearchTermCount()
  return #self.terms
end

function AuctionarySearchProviderMixin:HasMoreTerms()
  Auctionator.Debug.Message("AuctionarySearchProviderMixin:HasMoreTerms()")

  return
    self.terms ~= nil and
    #self.terms > 0 and
    self.index ~= nil and
    self.index <= #self.terms
end

function AuctionarySearchProviderMixin:GetNextSearchParameter()
  Auctionator.Debug.Message("AuctionarySearchProviderMixin:GetNextSearchParameter()")

  if self:HasMoreTerms() then
    self.index = self.index + 1

    return self:CreateSearchTerm(self.terms[self.index - 1], self.config)
  else
    error("You requested a term that does not exist: " .. (self.index == nil and "nil" or self.index))
  end
end

function AuctionarySearchProviderMixin:GetCurrentSearchParameter()
  return self.terms[self.index - 1]
end
