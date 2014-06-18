-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local spec = {
  exts = {"xml"},
  lexer = wxstc.wxSTC_LEX_XML,
  apitype = "xml",
  stylingbits = 7,

  lexerstyleconvert = {
    text = {wxstc.wxSTC_H_DEFAULT,},
    comment = {wxstc.wxSTC_H_COMMENT,},
    stringeol = {wxstc.wxSTC_HJ_STRINGEOL,},
    number = {wxstc.wxSTC_H_NUMBER,},
    stringtxt = {
      wxstc.wxSTC_H_DOUBLESTRING,
      wxstc.wxSTC_H_SINGLESTRING,
    },
    lexerdef= {
      wxstc.wxSTC_H_OTHER,
      wxstc.wxSTC_H_ENTITY,
      wxstc.wxSTC_H_VALUE,
    },
    keywords0 = {
      wxstc.wxSTC_H_TAG,
      wxstc.wxSTC_H_ATTRIBUTE,
    },
    keywords1 = {wxstc.wxSTC_H_TAGUNKNOWN,
      wxstc.wxSTC_H_ATTRIBUTEUNKNOWN,
    },
    keywords2 = {wxstc.wxSTC_H_SCRIPT,},
    keywords3 = {wxstc.wxSTC_LUA_WORD,},
    keywords4 = {wxstc.wxSTC_LUA_WORD1,},
    keywords5 = {wxstc.wxSTC_LUA_WORD2,},
    preprocessor= {wxstc.wxSTC_LUA_PREPROCESSOR,},
  },

  keywords = {
  },
}

return {
  name = "XML syntax highlighting",
  description = "XML syntax highlighting",
  author = "Paul Kulchenko",
  version = 0.2,

  onRegister = function(self)
    local keywords = self:GetConfig().keywords or ''
    spec.keywords[1] = keywords
    ide:AddSpec("xml", spec)
  end,
  onUnRegister = function(self) ide:RemoveSpec("xml") end,
}

--[[ configuration example:
xml = {keywords = "foo bar"}
--]]
