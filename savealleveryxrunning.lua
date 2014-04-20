local timer
local evthandler
return {
  name = "Save all files every X seconds while running/debugging",
  description = "Saves all modified files every X seconds while running/debugging.",
  author = "Paul Kulchenko",
  version = 0.2,
  dependencies = 0.51,

  onRegister = function(self)
    local handler = function() if ide:GetLaunchedProcess() then SaveAll(true) end end
    evthandler = wx.wxEvtHandler()
    evthandler:Connect(wx.wxEVT_TIMER, handler)
    timer = wx.wxTimer(evthandler)
    timer:Start((self:GetConfig().interval or 3)*1000)
  end,

  onUnRegister = function(self)
    if evthandler then
      timer:Stop()
      evthandler:Disconnect(wx.wxEVT_TIMER, wx.wxID_ANY, wx.wxID_ANY)
      evthandler = nil
    end
  end,
}
