local G = ...
local id = G.ID("remoteedit.openremotefile")
local lastfile, menuid, debugger = ""
local editors = {}
local function reportErr(err) return(err:gsub('.-:%d+:%s*','')) end

local mobdebug = require("mobdebug")
local copas = require("copas")

return {
  name = "Remote edit",
  description = "Allows to edit files remotely while debugging is in progress.",
  author = "Paul Kulchenko",
  version = 0.11,

  onRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&File")))
    menuid = menu:Insert(2, id, "Open Remotely...")
    debugger = ide.debugger

    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
      function()
        local file = wx.wxGetTextFromUser("Enter name (with path) of the remote file",
          "Open remote file", lastfile)
        if file and #file > 0 then
          self:loadFile(file)
          lastfile = file
        end
      end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI,
      function (event) event:Enable(debugger.server and not debugger.running) end)

    -- this is a workaround for an API call missing in v0.39
    if tonumber(ide.VERSION) and tonumber(ide.VERSION) <= 0.39 then
      local sf = SaveFile
      SaveFile = function(...)
        if PackageEventHandle("onEditorPreSave", ...) ~= false then sf(...) end
      end
    end
  end,

  onUnRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&File")))
    ide:GetMainFrame():Disconnect(id, wx.wxID_ANY, wx.wxEVT_COMMAND_MENU_SELECTED)
    if menuid then menu:Destroy(menuid) end
  end,

  onEditorClose = function(self, editor)
    editors[editor] = nil
  end,

  onEditorPreSave = function(self, editor, filepath)
    local remote = editors[editor]
    if remote and ide:GetDocument(editor):IsModified() then
      self:saveFile(remote, editor)
      return false
    end
  end,

  loadFile = function(self, remote)
    if not debugger then return end
    if not debugger.server or debugger.running then return end
    local code = ([[(function() local f, err = io.open(%s); if not f then error(err) end; local c = f:read('*a'); f:close(); return c end)()]])
      :format(mobdebug.line(remote))
    copas.addthread(function()
      local res, _, err = debugger.evaluate(code)
      if err then
        DisplayOutputLn(("Failed to load file '%s': %s.")
          :format(remote, reportErr(err)))
        return
      end

      local ok, content = LoadSafe("return "..res)
      if ok then
        DisplayOutputLn(("Loaded file '%s'."):format(remote))
        self.onIdleOnce = function()
          local editor = NewFile("remote: "..remote)
          editor:SetText(content)
          editor:SetSavePoint()
          editors[editor] = remote
        end
      else
        DisplayOutputLn(("Failed to load file '%s': %s.")
          :format(remote, content))
      end
    end)
  end,

  saveFile = function(self, remote, editor)
    if not debugger then return end
    if not debugger.server or debugger.running then return end
    local content = editor:GetText()
    local code = ([[local f, err = io.open(%s, 'w'); if not f then error(err) end; f:write(%s); f:close()]])
      :format(mobdebug.line(remote), mobdebug.line(content))
    copas.addthread(function()
      local err = select(3, debugger.execute(code))
      if not err then
        editor:SetSavePoint()
        DisplayOutputLn(("Saved file '%s'."):format(remote))
      else
        DisplayOutputLn(("Failed to save file '%s': %s.")
          :format(remote, reportErr(err)))
      end
    end)
  end,
}
