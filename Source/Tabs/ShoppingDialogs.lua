local Auctionator = Auctionary

-- Popups for creating, renaming and deleting shopping lists.
-- data = { view = the Shopping tab frame, listName = name of the list }

local function EditBoxAccept(which)
  return function(editBox)
    local dialog = editBox:GetParent()
    StaticPopupDialogs[which].OnAccept(dialog, dialog.data)
    dialog:Hide()
  end
end

local function EditBoxEscape(editBox)
  editBox:GetParent():Hide()
end

StaticPopupDialogs[Auctionator.Constants.DialogNames.CreateShoppingList] = {
  text = AUCTIONARY_L_CREATE_LIST_DIALOG,
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = 1,
  maxLetters = 32,
  OnShow = function(self)
    self.editBox:SetText("")
    self.editBox:SetFocus()
  end,
  OnAccept = function(self, data)
    local text = strtrim(self.editBox:GetText())
    if text == "" then
      return
    end
    local name = Auctionator.Shopping.ListManager:GetUnusedName(text)
    Auctionator.Shopping.ListManager:Create(name)
    data.view:ExpandList(name)
  end,
  EditBoxOnEnterPressed = EditBoxAccept(Auctionator.Constants.DialogNames.CreateShoppingList),
  EditBoxOnEscapePressed = EditBoxEscape,
  timeout = 0,
  exclusive = 1,
  whileDead = 1,
  hideOnEscape = 1,
}

StaticPopupDialogs[Auctionator.Constants.DialogNames.DeleteShoppingList] = {
  text = AUCTIONARY_L_DELETE_LIST_CONFIRM,
  button1 = ACCEPT,
  button2 = CANCEL,
  timeout = 0,
  exclusive = 1,
  whileDead = 1,
  hideOnEscape = 1,
  OnAccept = function(self, data)
    if Auctionator.Shopping.ListManager:GetIndexForName(data.listName) ~= nil then
      Auctionator.Shopping.ListManager:Delete(data.listName)
    end
  end,
}

local function RenameAccept(makePermanent)
  return function(self, data)
    local text = strtrim(self.editBox:GetText())
    local list = Auctionator.Shopping.ListManager:GetByName(data.listName)
    if text == "" or list == nil then
      return
    end
    if text ~= data.listName then
      text = Auctionator.Shopping.ListManager:GetUnusedName(text)
      list:Rename(text)
    end
    if makePermanent then
      list:MakePermanent()
    end
    Auctionator.Shopping.ListManager:Sort()
    data.view:ListRenamed(data.listName, text)
  end
end

StaticPopupDialogs[Auctionator.Constants.DialogNames.RenameShoppingList] = {
  text = AUCTIONARY_L_RENAME_LIST_CONFIRM,
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = 1,
  maxLetters = 32,
  OnShow = function(self)
    self.editBox:SetText(self.data.listName or "")
    self.editBox:HighlightText()
    self.editBox:SetFocus()
  end,
  OnAccept = RenameAccept(false),
  EditBoxOnEnterPressed = EditBoxAccept(Auctionator.Constants.DialogNames.RenameShoppingList),
  EditBoxOnEscapePressed = EditBoxEscape,
  timeout = 0,
  exclusive = 1,
  whileDead = 1,
  hideOnEscape = 1,
}

StaticPopupDialogs[Auctionator.Constants.DialogNames.MakePermanentShoppingList] = {
  text = AUCTIONARY_L_MAKE_PERMANENT_CONFIRM,
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = 1,
  maxLetters = 32,
  OnShow = function(self)
    self.editBox:SetText("")
    self.editBox:SetFocus()
  end,
  OnAccept = RenameAccept(true),
  EditBoxOnEnterPressed = EditBoxAccept(Auctionator.Constants.DialogNames.MakePermanentShoppingList),
  EditBoxOnEscapePressed = EditBoxEscape,
  timeout = 0,
  exclusive = 1,
  whileDead = 1,
  hideOnEscape = 1,
}
