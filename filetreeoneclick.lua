return {
  name = "Filetree one-click activation",
  description = "Changes filetree to activate items on one-click (as in Sublime Text).",
  author = "Paul Kulchenko",
  version = 0.2,
  dependencies = "0.51",

  onFiletreeLDown = function(self, tree, event, item_id)
    if not item_id then return end
    if tree:IsDirectory(item_id) then
      tree:Toggle(item_id)
      return false
    else
      tree:ActivateItem(item_id)
    end
  end,
  onMenuFiletree = function(self, menu, tree, event)
    local item_id = event:GetItem()
    if not item_id then return end
    if tree:IsDirectory(item_id) then
      tree:Toggle(item_id)
    else
      tree:ActivateItem(item_id)
    end
  end,
}
