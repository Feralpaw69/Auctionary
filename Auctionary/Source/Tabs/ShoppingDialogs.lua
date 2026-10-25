-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Small windows for the shopping lists (new, rename, keep, delete)
-- They get data = { view = Shopping tab, listName = the list }.

local Names = Auctionary.Constants.DialogNames
local function Lists() return Auctionary.Shopping.ListManager end

local function Base(text)
  return {
    text = text,
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1,
  }
end

-- A window with a text box; onName(dialogData, enteredName) on Accept or Enter
local function NameWindow(key, text, startText, onName)
  local window = Base(text)
  window.hasEditBox = 1
  window.maxLetters = 32
  window.OnShow = function(self)
    self.editBox:SetText(startText(self.data) or "")
    self.editBox:HighlightText()
    self.editBox:SetFocus()
  end
  window.OnAccept = function(self, data)
    local name = strtrim(self.editBox:GetText() or "")
    if name ~= "" then
      onName(data, name)
    end
  end
  window.EditBoxOnEnterPressed = function(editBox)
    local dialog = editBox:GetParent()
    window.OnAccept(dialog, dialog.data)
    dialog:Hide()
  end
  window.EditBoxOnEscapePressed = function(editBox)
    editBox:GetParent():Hide()
  end
  StaticPopupDialogs[key] = window
end

local function Empty() return "" end

NameWindow(Names.CreateShoppingList, AUCTIONARY2_L_LIST_NEW_ASK, Empty, function(data, name)
  name = Lists():GetUnusedName(name)
  Lists():Create(name)
  data.view:ExpandList(name)
end)

-- Renames (and for a temporary list: keeps it for good)
local function Rename(keep)
  return function(data, name)
    if Lists():GetIndexForName(data.listName) == nil then
      return
    end
    local list = Lists():GetByName(data.listName)
    if name ~= data.listName then
      name = Lists():GetUnusedName(name)
      list:Rename(name)
    end
    if keep then
      list:MakePermanent()
    end
    data.view:ListRenamed(data.listName, name)
  end
end

NameWindow(Names.RenameShoppingList, AUCTIONARY2_L_LIST_RENAME_ASK,
  function(data) return data and data.listName end, Rename(false))
NameWindow(Names.MakePermanentShoppingList, AUCTIONARY2_L_LIST_KEEP_ASK, Empty, Rename(true))

local delete = Base(AUCTIONARY2_L_LIST_DELETE_ASK)
delete.OnAccept = function(_, data)
  if Lists():GetIndexForName(data.listName) ~= nil then
    Lists():Delete(data.listName)
  end
end
StaticPopupDialogs[Names.DeleteShoppingList] = delete
