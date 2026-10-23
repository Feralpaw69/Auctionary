local Auctionator = Auctionary

AuctionaryMultiSearchMixin = {}

function AuctionaryMultiSearchMixin:InitSearch(completionCallback, incrementCallback)
  Auctionator.Debug.Message("AuctionaryMultiSearchMixin:InitSearch()")

  self.complete = true
  self.onSearchComplete = completionCallback or function()
    Auctionator.Debug.Message("Search completed.")
  end
  self.onNextSearch = incrementCallback or function()
    Auctionator.Debug.Message("Next search.")
  end
end

function AuctionaryMultiSearchMixin:OnEvent(event, ...)
  self:OnSearchEventReceived(event, ...)
end

function AuctionaryMultiSearchMixin:Search(terms, config)
  Auctionator.Debug.Message("AuctionaryMultiSearchMixin:Search()", terms)

  self.complete = false
  self.partialResults = {}
  self.fullResults = {}
  self.anyResultsForThisTerm = false

  self:RegisterProviderEvents()

  self:SetTerms(terms, config)
  self:NextSearch()
end

function AuctionaryMultiSearchMixin:AbortSearch()
  self:UnregisterProviderEvents()
  local isComplete = self.complete
  self.complete = true
  if not isComplete then
    self.onSearchComplete(self.fullResults)
  end
end

function AuctionaryMultiSearchMixin:AddResults(results)
  Auctionator.Debug.Message("AuctionarySearchProviderMixin:AddResults()")

  if #results > 0 then
    self.anyResultsForThisTerm = true
  end

  for index = 1, #results do
    table.insert(self.partialResults, results[index])
    table.insert(self.fullResults, results[index])
  end

  if self:HasCompleteTermResults() then
    self:NextSearch()
  end
end

function AuctionaryMultiSearchMixin:NoResultsForTermCheck()
  if not Auctionator.Config.Get(Auctionator.Config.Options.SHOPPING_LIST_MISSING_TERMS) then
    return
  end

  if self:GetCurrentSearchParameter() and not self.anyResultsForThisTerm then
    local emptyResult = self:GetCurrentEmptyResult()
    table.insert(self.partialResults, emptyResult)
    table.insert(self.fullResults, emptyResult)
  end
end

function AuctionaryMultiSearchMixin:NextSearch()
  if self:HasMoreTerms() then
    self:NoResultsForTermCheck()
    self.anyResultsForThisTerm = false

    self.onNextSearch(
      self:GetCurrentSearchIndex(),
      self:GetSearchTermCount(),
      self.partialResults
    )
    self.partialResults = {}
    self:GetSearchProvider()(self:GetNextSearchParameter())
  else
    Auctionator.Debug.Message("AuctionaryMultiSearchMixin:NextSearch Complete")

    self:NoResultsForTermCheck()

    self:UnregisterProviderEvents()

    self.complete = true
    self.onSearchComplete(self.fullResults)
  end
end
