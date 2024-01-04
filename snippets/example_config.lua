-- TODO
-- * shell_executes - currently run only real applications - not shell commands (like `cd` on Windows)
-- * regex transformatioin - currently uses original implementation based on ruby script. 
--                           Need to rewrite it using another engine. But need to support features like
--                           `\u$1` to upper case transformation.
-- * Improve scope detection

---
-- Snippet settings
-- `activation` - { `type`, `activator` }
--   `type` - can be either `tab` or `key`
--   `activator` - for `key` type it is shortcut like `Ctrl+B`, for `tab` type it is string without any space chars.
-- `scope` - <LANG>.<TYPE> 
--    `LANG` - Language name like it defined for lexer (e.g. `lua`, `perl`). `*` - means any language (default value)
--    `TYPE` - can be either `text`, `comment` or `string`. `*` - means any type (default value)
-- `nested` - does it snippet support nested activation
-- `text` - snippet text.
--     Macros syntax   - `$(name)` (e.g. `$(SelectedText)`)
--     Tab stoppers    - `${<NUM>:default}` (note - colon is mandatory)
--     Shell commands  - ``command`` (e.g. `ls`)
--     Transformation  - `${<NUM>/pat/rep/flags}` - replace using regex replacement
--     Mirror `${<NUM>}` - just copy value form tab stopper

snippets = {
  settings = {
    nested         = true,
    tab_activation = true,
    keys = {
      ['Alt+J'           ] = 'list',
      ['Ctrl+J'          ] = 'cancel',
      ['Ctrl+Shift+J'    ] = 'cancel_all',
      ['Ctrl+Shift+Alt+J'] = 'show_scope',
      -- In case of `tab_activation = true`
      -- ['Ctrl+J'          ] = 'insert', -- `<TAB>`
      -- ['Ctrl+Shift+J'    ] = 'prev',   -- `Shift+<TAB>`
    },
  },
  { -- shell execute example
    scope      = '*.*',
    activation = {'tab', 'ls'},
    nested     = true,
    text       = "`ls`",
  },
  { -- Variables
    scope      = '*.*',
    activation = {'tab', 'variables'},
    nested     = true,
    text       = "Indent: <$(I)>\nLineComment: <$(LineComment)>\nLineNumber: <$(LineNumber)>\nFilePath: $(FilePath)\nFileName: $(FileName)\nDateTime: $(DateTime)\n",
  },
  { -- nested tab stoppers
    scope      = 'lua',
    activation = {'tab', 'key'},
    nested     = true,
    text       = "['${1:}'] = { ${2:func}${3:, ${4:arg}} }",
  },
  { -- mirror
    scope      = 'lua.text',
    activation = {'tab', 'tab'},
    nested     = true,
    text       = "${3:three} ${1:one} ${2:two} ${3} ${4:four}",
  },
  { -- transformation
      scope      = 'lua',
      activation = {'tab', 'one'},
      nested     = true,
      text       = "${1:two} ${1/two/three/}",
  },
  { -- shortcut activator (lang 1)
      activation = {'key', 'Ctrl+Shift+B'},
      scope      = 'lua',
      nested     = true,
      text       = "<b>$(SelectedText)${0}</b>",
  },
  { -- shortcut activator (lang 2)
      activation = {'key', 'Ctrl+Shift+B'},
      scope      = 'perl',
      nested     = true,
      text       = "document.Write(<b>$(SelectedText)${0}</b>)",
  },
  { -- tab activator (lang 1)
      scope      = 'lua',
      activation = {'tab', 'f'},
      nested     = false,
      text       = "function ${1:name}(${2:})\n$(I)${0}\nend",
  },
  { -- tab activator (lang 1)
        scope      = 'perl',
        activation = {'tab', 'f'},
        nested     = false,
        text       = "sub ${1:name}${2:(${3:arg})}{\n$(I)${0}\n}",
    },
}
