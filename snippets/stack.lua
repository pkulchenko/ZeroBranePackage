local log     = package_require 'snippets.log'
local Snippet = package_require 'snippets.snippet'

local Stack = {} do
  Stack.__index = Stack

  function Stack.new(class, editor)
    local self = setmetatable({}, class)

    self._stack  = {}

    return self
  end

  function Stack:top()
    local snippet = self._stack[#self._stack]
    return snippet
  end

  function Stack:push(snippet)
    table.insert(self._stack, snippet)
  end

  function Stack:pop()
    return table.remove(self._stack)
  end
end

local SnippetStack = {} do
  SnippetStack.__index = SnippetStack

  function SnippetStack.new(class, editor)
    local self = setmetatable({}, class)

    self._stack = Stack:new()
    self.editor = editor

    return self
  end

  function SnippetStack:push(...)
    local snippet = Snippet:new(self.editor, ...)
    self._stack:push(snippet)
    snippet:start()
  end

  function SnippetStack:next()
    local snippet = self._stack:top()
    if not snippet then return end

    local log = log:get('SnippetStack:next')

    if not snippet:next_placeholder() then
      log:debug('Snippet cancel')
      return self:cancel_current()
    end

    if not snippet:active() then
      log:debug('Snippet finished')
      assert(snippet == self._stack:pop())
    end
  end

  function SnippetStack:prev()
    local snippet = self._stack:top()
    if not snippet then return end

    if snippet:prev_placeholder() then
      self:next()
    end
  end

  function SnippetStack:cancel_current()
    local snippet = self._stack:pop()
    if not snippet then return end

    snippet:cancel()
  end

  function SnippetStack:cancel_all()
    while true do
      local snippet = self._stack:pop()
      if not snippet then return end
      snippet:cancel()
    end
  end

  function SnippetStack:active()
    local snippet = self._stack:top()
    return snippet and true or false
  end

  function SnippetStack:allow_new_snippet()
    local snippet = self._stack:top()
    if not snippet then
      return true
    end
    return snippet:support_nested()
  end

  function SnippetStack:finish_current()
    local snippet = self._stack:top()
    if not snippet then return end

    local log = log:get('SnippetStack:finish_current')

    local s_start, s_end, s_text = snippet:get_text()

    -- If something went wrong and the snippet has been 'messed' up
    -- (e.g. by undo/redo commands).
    if not s_text then
      log:debug('Cancel snippet')
      return self:cancel_current()
    end

    s_text = snippet:mirror(s_text)
    log:debug('mirrored:\n%s\n============', s_text)

    snippet:finish(s_text)

    if not snippet.index then
        assert(snippet == self._stack:pop())
    end
  end
end

return SnippetStack
