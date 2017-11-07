return {
  name = "Save all files on app switch",
  description = "Saves all modified files when app focus is lost.",
  author = "Paul Kulchenko",
  version = 0.11,

  onAppFocusLost = function() SaveAll(true) end,
}
