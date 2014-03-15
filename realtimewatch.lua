local lastrow, redirect, filter = {}
local stats = {}

return {
  name = "Real-time watches",
  description = "Displays real-time values during debugging.",
  author = "Paul Kulchenko",
  version = 0.1,

  onRegister = function()
    local config = ide:GetConfig()
    redirect = config.debugger.redirect
    filter = config.debugger.outputfilter

    config.debugger.redirect = "r"
    config.debugger.outputfilter = function(s)
      local label, value = s:match('"(.-)%s*=%s*"\t(.+)')
      if not label or not value then return s end

      local watchCtrl = ide.debugger.watchCtrl

      local row = lastrow[label]
      if not row or watchCtrl:GetItemText() ~= label then
        row = nil -- reset in case it's not found in the control
        for idx = 0, watchCtrl:GetItemCount() - 1 do
          if label == watchCtrl:GetItemText(idx) then
            row = idx
            break
          end
        end
      end

      if not row then
        row = watchCtrl:InsertItem(watchCtrl:GetItemCount(), label)
      end

      local num = tonumber(value)
      -- for numbers report min/max/count/avg
      if num then
        stats[label] = stats[label] or {}
        -- count, sum, min, max
        local stat = stats[label]
        stat[1] = (stat[1] or 0) + 1
        stat[2] = (stat[2] or 0) + num
        stat[3] = math.min(stat[3] or math.huge, num)
        stat[4] = math.max(stat[4] or -math.huge, num)
        value = ("%s (min: %s, max: %s, cnt: %s, avg: %s)")
          :format(num, stat[3], stat[4], stat[1], stat[2]/stat[1])
      end

      watchCtrl:SetItem(row, 0, label)
      watchCtrl:SetItem(row, 1, (value:gsub("\t", "; ")))

      return
    end
  end,

  onUnRegister = function(self)
    local config = ide:GetConfig()
    config.debugger.redirect = redirect
    config.debugger.outputfilter = filter
  end,
}
