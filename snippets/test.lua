-- Test suite for snippets.lua
local SnippetManager = package_require 'snippets.manager'
local Config         = package_require 'snippets.config'
local Editor         = package_require 'snippets.editor'

-- BUG
--   cancel tab activation with selected text

-- TODO
--   snippets.scivar = "$(FilePath)"

local manager = SnippetManager:new()

local function print(...)
  ide:Print(...)
end

local function test_snippets(editor)
  manager:load_config {
    {activation = "tabs",     text = "${3:three} ${1:one} ${2:two}"               },
    {activation = "etabs",    text = "${2:one ${1:two} ${3:three}} ${4:four}"     },
    {activation = "mirrors",  text = "${1:one} ${2:two} ${1} ${2}"                },
    {activation = "rmirrors", text = "${1:one} ${1/one/two/}"                     },
    {activation = "rgroups",  text = [[Ordered pair: ${1:(2, 8)} so ${1/(\d), (\d)/x = $1, y = $2/}]]},
    {activation = "trans",    text = "${1:one} ${1/o(ne)?/O$1/}"                  },
    {activation = "esc1",     text = [[\${1:fake one} ${1:real one} {${2:\} two}]]},
    {activation = "esc2",     text = [[\${1:fake one} ${1:real one} {${2:\} two}${0}]]},
    {activation = "eruby",    text = "${1:one} ${1/.+/#{$0.capitalize}/}"         },
    {activation = "cursor",   text = "begin${0}end"                               },
    {activation = "dcursor",  text = "begin${0: hello}end"                        },
    {activation = "skip",     text = "${1:one} ${3:three}"                        },
    {activation = "popup",    text = "${0|one,two,three} ${1|hello,world}"        }, -- TODO test it
  }
  manager:release(editor)

  local eol = Editor.GetEOL(editor)

  do -- Tab stops
    editor:ClearAll()
    print('testing tab stops')
    editor:AddText("tabs"); manager:insert(editor)
    assert( Editor.GetSelText(editor) == "one" )
    assert( editor:GetText(editor) == "${3:three} one ${2:two}" .. eol )
    editor:ReplaceSelection('foo')

    manager:next(editor)
    assert( Editor.GetSelText(editor) == "two" )
    assert( editor:GetText(editor) == "${3:three} foo two" .. eol )

    manager:prev(editor)
    assert( Editor.GetSelText(editor) == "one" )
    assert( editor:GetText(editor) == "${3:three} one ${2:two}" .. eol )

    manager:next(editor)
    assert( Editor.GetSelText(editor) == "two" )
    assert( editor:GetText(editor) == "${3:three} one two" .. eol )

    manager:next(editor)
    assert( Editor.GetSelText(editor) == "three" )
    manager:next(editor)
    assert( editor:GetText() == "three one two" )
    print('tab stops passed')
  end

  do -- Embedded tab stops
    editor:ClearAll()
    print('testing embedded tab stops')
    editor:AddText('etabs'); manager:insert(editor)
    assert( Editor.GetSelText(editor) == 'two')
    manager:next(editor)
    assert( Editor.GetSelText(editor) == 'one two ${3:three}' )
    manager:next(editor)
    assert(Editor.GetSelText(editor) == 'three')
    manager:next(editor)
    manager:next(editor)
    assert( editor:GetText() == 'one two three four' )
    print('embedded tabs passed')
  end

  do -- Mirrors
    editor:ClearAll()
    print('testing mirrors')
    editor:AddText('mirrors'); manager:insert(editor)
    manager:next(editor)
    assert( editor:GetText() == 'one two one ${2}' .. eol )

    manager:prev(editor)
    assert( editor:GetText() == 'one ${2:two} ${1} ${2}' .. eol )
    assert( Editor.GetSelText(editor) == 'one' )

    manager:next(editor)
    assert( editor:GetText() == 'one two one ${2}' .. eol )

    editor:DeleteBack(); editor:AddText('three')
    manager:next(editor)
    assert( editor:GetText() == 'one three one three' )
    print('mirrors passed')
  end

  do -- Regex Mirrors
    editor:ClearAll()
    print('testing regex mirrors')
    editor:AddText('rmirrors'); manager:insert(editor)
    manager:next(editor)
    assert( editor:GetText() == 'one two' )
    editor:ClearAll()
    editor:AddText('rmirrors'); manager:insert(editor)
    editor:DeleteBack(); editor:AddText('two')
    manager:next(editor)
    assert( editor:GetText() == 'two ' )
    print('regex mirrors passed')
  end

  do -- Regex Groups
    editor:ClearAll()
    print('testing regex groups')
    editor:AddText('rgroups'); manager:insert(editor)
    manager:next(editor)
    assert( editor:GetText() == 'Ordered pair: (2, 8) so x = 2, y = 8' )
    editor:ClearAll()
    editor:AddText('rgroups'); manager:insert(editor)
    editor:DeleteBack(); editor:AddText('[5, 9]')
    manager:next(editor)
    assert( editor:GetText() == 'Ordered pair: [5, 9] so x = 5, y = 9' )
    print('regex groups passed')
  end

  do -- Transformations
    editor:ClearAll()
    print('testing transformations')
    editor:AddText('trans'); manager:insert(editor)
    manager:next(editor)
    assert( editor:GetText() == 'one One' )
    editor:ClearAll()
    editor:AddText('trans'); manager:insert(editor)
    editor:DeleteBack(); editor:AddText('once')
    manager:next(editor)
    assert( editor:GetText() == 'once O' )
    print('transformations passed')
  end

  if false then -- SciTE variables
    editor:ClearAll()
    print('testing scite variables')
    editor:AddText('scivar'); manager:insert(editor)
    assert( editor:GetText() == props['FilePath'] )
    print('scite variables passed')
  end

  do -- Escapes
    for _, name in ipairs{'esc1', 'esc2'} do
        editor:ClearAll()
        print('testing escapes - ' .. name)
        editor:AddText(name); manager:insert(editor)
        assert( Editor.GetSelText(editor) == 'real one' )
        manager:next(editor)
        assert( Editor.GetSelText(editor) == '} two' )
        manager:next(editor)
        assert( editor:GetText() == '${1:fake one} real one {} two' )
        print('escapes passed' .. name)
    end
  end

  do -- Embeded Ruby
    editor:ClearAll()
    print('testing embedded ruby')
    editor:AddText('eruby'); manager:insert(editor)
    manager:next(editor)
    assert( editor:GetText() == 'one One' )
    editor:ClearAll()
    editor:AddText('eruby'); manager:insert(editor)
    editor:DeleteBack(); editor:AddText('two')
    manager:next(editor)
    assert( editor:GetText() == 'two Two' )
    print('embedded ruby passed')
  end

  do -- Default value for cursor position
    editor:ClearAll()
    print('testing cursor position')
    editor:AddText('cursor'); manager:insert(editor)
    manager:next(editor)
    assert( editor:GetText() == 'beginend' )
    assert( editor:GetCurrentPos() == 5 )
    assert( Editor.GetSelText(editor) == '' )
    assert( not manager:has_active_snippet(editor) )
    print('cursor position passed')
  end

  do -- Default value for cursor position
    editor:ClearAll()
    print('testing cursor position with default value')
    editor:AddText('dcursor'); manager:insert(editor)
    manager:next(editor)
    assert( editor:GetText() == 'begin helloend' )
    assert( editor:GetCurrentPos() == 11 )
    assert( Editor.GetSelText(editor) == ' hello' )
    assert( not manager:has_active_snippet(editor) )
    print('cursor position with default value passed')
  end

  do -- Stops on last missing placeholder
    editor:ClearAll()
    print('testing stops on last missing placeholder')
    editor:AddText('skip'); manager:insert(editor)
    assert( editor:GetText() == 'one ${3:three}' .. eol )
    assert( Editor.GetSelText(editor) == 'one')
    assert( manager:has_active_snippet(editor) )

    manager:next(editor)
    assert( editor:GetText() == 'one ${3:three}' )
    assert( editor:GetCurrentPos() == 14 )
    assert( Editor.GetSelText(editor) == '')
    assert( not manager:has_active_snippet(editor) )
    print('stops on last missing placeholder passed')
  end

  do -- EOL
    editor:ClearAll()
    print('testing remove eol')
    local s = eol .. 'foo.boo()' .. eol .. 'bbb'
    editor:AddText('rmirrors' .. s);
    editor:SetSelection(8,8)
    manager:insert(editor)

    assert( editor:GetText() == 'one ${1/one/two/}' .. eol .. s)
    assert( Editor.GetSelText(editor) == 'one')
    assert( manager:has_active_snippet(editor) )

    manager:next(editor)
    assert( editor:GetText() == 'one two' .. s)
    assert( editor:GetCurrentPos() == 7 )
    assert( not manager:has_active_snippet(editor) )
  end

end

local function test_cancel(editor)
  manager:load_config{
    {
      activation = {'key', 'Ctrl+1'},
      text = '<b>$(SelectedText)${1:}</b>'
    },
    {
      activation = {'tab', '111222'},
      text = '<b>$(SelectedText)${1:}</b>'
    }
  }
  manager:release(editor)

  local eol = Editor.GetEOL(editor)

  if true then -- ignore unknown shourtcuts
    print('testing ingnoring unknown shortcuts')
    editor:ClearAll()
    editor:AddText("111222333")

    editor:SetAnchor(3) editor:SetCurrentPos(6)
    manager:insert(editor, 'Ctrl+I') -- Do not change selection for unknown snippet
    assert( Editor.GetSelText(editor) == "222" )
    assert( editor:GetCurrentPos() == 6 )

    editor:SetAnchor(6) editor:SetCurrentPos(3)
    manager:insert(editor, 'Ctrl+I') -- Do not change selection for unknown snippet
    assert( Editor.GetSelText(editor) == "222" )
    assert( editor:GetCurrentPos() == 3 )
  end

  if true then -- cancel key
    editor:ClearAll()
    print('testing cancel snippet with key activation')
    editor:AddText("111222333")

    for i = 1, 2 do
      if i == 1 then
        editor:SetAnchor(6) editor:SetCurrentPos(3)
      else
        editor:SetAnchor(3) editor:SetCurrentPos(6)
      end

      manager:insert(editor, 'Ctrl+1')
      assert( editor:GetText() == '111<b>222</b>' .. eol .. '333' )
      assert( editor:GetCurrentPos() == 9 )
      assert( Editor.GetSelText(editor) == "" )
      editor:AddText('444')
      assert( editor:GetText() == '111<b>222444</b>' .. eol .. '333' )

      manager:cancel(editor)
      assert( editor:GetText() == '111222333' )
      assert( Editor.GetSelText(editor) == "222" )
      assert( editor:GetCurrentPos() == 6 ) -- TODO restore correct position
    end
    print('testing cancel snippet with key activation passed')
  end

  if true then -- ignore unknown shourtcuts
    print('testing ingnoring unknown tab activators')
    editor:ClearAll()
    editor:AddText("111222333")

    editor:SetAnchor(3) editor:SetCurrentPos(5)
    manager:insert(editor)
    assert( Editor.GetSelText(editor) == "22" )
    assert( editor:GetCurrentPos() == 5 )

    editor:SetAnchor(5) editor:SetCurrentPos(3)
    manager:insert(editor)
    assert( Editor.GetSelText(editor) == "22" )
    assert( editor:GetCurrentPos() == 3 )
    print('test ingnoring unknown tab activators passed')
  end

  if true then -- cancel tab
    editor:ClearAll()
    print('testing cancel snippet with tab activation (without selection)')
    editor:AddText("111222333")

    editor:SetSelection(6, 6);
    manager:insert(editor)
    assert( editor:GetText() == '<b></b>' .. eol .. '333' )
    assert( editor:GetCurrentPos() == 3 )
    assert( Editor.GetSelText(editor) == "" )
    editor:AddText('444')

    manager:cancel(editor)
    assert( editor:GetText() == '111222333' )
    assert( editor:GetCurrentPos() == 6 ) -- TODO restore correct position
    print('test cancel snippet with tab activation (without selection) passed')
  end

  if true then -- TODO FIX not supported correctly cancel for tab activatin with selection
    editor:ClearAll()
    editor:AddText("111222333")

    editor:SetAnchor(3) editor:SetCurrentPos(6)
    assert( Editor.GetSelText(editor) == "222" )

    manager:insert(editor)
    assert( editor:GetText() == '<b>222</b>' .. eol .. '333' )
    assert( editor:GetCurrentPos() == 6 )
    assert( Editor.GetSelText(editor) == "" )
    editor:AddText('444')

    manager:cancel(editor)
    assert( editor:GetText() == '222333' ) -- BUG in
    assert( editor:GetCurrentPos() == 3 )
    print('TODO FIX not supported correctly cancel for tab activatin with selection')
  end

  if true then -- TODO FIX not supported correctly cancel for tab activatin with selection
    editor:ClearAll()
    editor:AddText("111222333")

    editor:SetAnchor(9) editor:SetCurrentPos(6)
    assert( Editor.GetSelText(editor) == "333" )

    manager:insert(editor)
    assert( editor:GetText() == '<b>333</b>' .. eol .. '333')
    assert( editor:GetCurrentPos() == 6 )
    assert( Editor.GetSelText(editor) == "" )
    editor:AddText('444')

    manager:cancel(editor)
    assert( editor:GetText() == '333333' ) -- BUG
    assert( editor:GetCurrentPos() == 3 )
    print('TODO FIX not supported correctly cancel for tab activatin with selection')
  end
end

local function run()
  local editor = NewFile()
  test_snippets(editor)
  test_cancel(editor)
  ide:GetDocument(editor):SetModified(false)
  ClosePage()
  Config.__self_test__()
  print('snippet tests passed')
end

return run