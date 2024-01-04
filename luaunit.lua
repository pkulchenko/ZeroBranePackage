local api = {
  luaunit = {
    childs = {
      VERSION = {
        description = 'LuaUnit version',  type = "value"
      },
      ORDER_ACTUAL_EXPECTED = {
        description = 'Some people like assertEquals( actual, expected ) and some people prefer assertEquals( expected, actual )',
        type = "boolean"
      },
      LuaUnit = {
        description = "Main object of the library",
        type = "class",
        childs = {
          run = {
            args = "(...)", type = "function", returns = "(number)",
            description = [[
Run some specific test classes.
If no arguments are passed, run the class names specified on the
command line. If no class name is specified on the command line
run all classes whose name starts with 'Test'

If arguments are passed, they must be strings of the class names
that you want to run or generic command line arguments (-o, -p, -v, ...)
          
Normally, you should run your test suite with the following line 'os.exit(luaunit.LuaUnit.run())' ]],
        },
        runSuite = {
                  args = "(...)", type = "method", returns = "(number)",
            description = [[
Run some specific test classes. Like run() but on a luaunit instance.
If no arguments are passed, run the class names specified on the
command line. If no class name is specified on the command line
run all classes whose name starts with 'Test'

If arguments are passed, they must be strings of the class names
that you want to run or generic command line arguments (-o, -p, -v, ...) ]],
          },
        },
      },
      setVerbosity = {
        args = "(verbosity)", type = "function", returns = "(number)",
        description = [[Set the test verbosity.
            
VERBOSITY_DEFAULT = 10
VERBOSITY_LOW     = 1
VERBOSITY_QUIET   = 0
VERBOSITY_VERBOSE = 20
]]
      },
      assertEquals = {
        args = "(actual, expected)",type = "function",  
        description = [[Assert that two values are equal.

For tables, the comparison is a deep comparison :

- number of elements must be the same
- tables must contain the same keys
- each key must contain the same values. The values are also compared recursively with deep comparison.
LuaUnit provides other table-related assertions, see Table assertions]], 
      },
      assertNotEquals = {
        args= "(actual, expected)",type = "function",         returns = "()",
        description= [[Assert that two values are different. The assertion fails if the two values are identical.

It also uses table deep comparison.
]],  
      },
      assertAlmostEquals= {
        args = "(actual, expected, margin)",type = "function",         returns = "()",
        description=[[Assert that two floating point numbers are almost equal.

When comparing floating point numbers, strict equality does not work. Computer arithmetic is so that an operation that mathematically yields 1.00000000 might yield 0.999999999999 in lua . That’s why you need an almost equals comparison, where you specify the error margin.]],

      },
      assertNotAlmostEquals= {
        args = "(actual, expected, margin)",type = "function",        returns = "()",
        description=[[Assert that two floating point numbers are not almost equal.]],
      },

      EPS= {
        type = 'value',
        description=[[The machine epsilon, to be used with 'assertAlmostEquals'.

This is either:

* 2^-52 or ~2.22E-16 (with lua number defined as double)
* 2^-23 or ~1.19E-07 (with lua number defined as float)]],
      },

      assertNan= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[ Assert that a given number is a *NaN* (Not a Number), according to the definition of IEEE-754_ .
If provided, *extra_msg* is a string which will be printed along with the failure message.]],
      },

      assertNotNan= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is NOT a *NaN* (Not a Number), according to the definition of IEEE-754_ .
If provided, *extra_msg* is a string which will be printed along with the failure message.]],
      },

      assertPlusInf= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is *plus infinity*, according to the definition of IEEE-754_ .
If provided, *extra_msg* is a string which will be printed along with the failure message.]],
      },

      assertMinusInf= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is *minus infinity*, according to the definition of IEEE-754_ .
If provided, *extra_msg* is a string which will be printed along with the failure message.]]  
      },

      assertInf= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is *infinity* (either positive or negative), according to the definition of IEEE-754_ .
    If provided, *extra_msg* is a string which will be printed along with the failure message.]]    
      },

      assertNotPlusInf= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is NOT *plus infinity*, according to the definition of IEEE-754_ .
If provided, *extra_msg* is a string which will be printed along with the failure message.]]    
      },
      assertNotMinusInf= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is NOT *minus infinity*, according to the definition of IEEE-754_ .
If provided, *extra_msg* is a string which will be printed along with the failure message.]]    
      },
      assertNotInf= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is neither *infinity* nor *minus infinity*, according to the definition of IEEE-754_ .
If provided, *extra_msg* is a string which will be printed along with the failure message.]]    
      },
      assertPlusZero= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is *+0*, according to the definition of IEEE-754_ . The
verification is done by dividing by the provided number and verifying that it yields
*infinity* . If provided, *extra_msg* is a string which will be printed along with the failure message.

Be careful when dealing with *+0* and *-0*, see note above.]]    
      },
      assertMinusZero= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is *-0*, according to the definition of IEEE-754_ . The
verification is done by dividing by the provided number and verifying that it yields
*minus infinity* . If provided, *extra_msg* is a string which will be printed along with the failure message.

Be careful when dealing with *+0* and *-0*, see note above.]]    
      },
      assertNotPlusZero= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is NOT *+0*, according to the definition of IEEE-754_ .
If provided, *extra_msg* is a string which will be printed along with the failure message.

Be careful when dealing with *+0* and *-0*, see note above.]]    
      },
      assertNotMinusZero= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that a given number is NOT *-0*, according to the definition of IEEE-754_ .
If provided, *extra_msg* is a string which will be printed along with the failure message.

Be careful when dealing with *+0* and *-0*, see note above.]]    
      },
      assertAlmostEquals= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that two floating point numbers are equal by the defined margin. 
If margin is not provided, the machine epsilon *EPS* is used.
If provided, *extra_msg* is a string which will be printed along with the failure message.

Be careful that depending on the calculation, it might make more sense to measure
the absolute error or the relative error.]]    
      },
      assertNotAlmostEquals= {
        args = "(value  [, extra_msg])",type = "function",        returns = "()",
        description=[[Assert that two floating point numbers are not equal by the defined margin.
If margin is not provided, the machine epsilon *EPS* is used.
If provided, *extra_msg* is a string which will be printed along with the failure message.

Be careful that depending on the calculation, it might make more sense to measure
the absolute error or the relative error.]]    
      },
      assertTrue= {
        args = "(value)",type = "function",        returns = "()",
        description=[[Assert that a given value compares to true. Lua coercion rules are applied so that values like 0, "", 1.17 all compare to true.]],
      },
      assertFalse= {
        args = "(value)",        type = "function",        returns = "()",
        description=[[Assert that a given value compares to false. Lua coercion rules are applied so that only nil and false all compare to false.]],
      },
      assertNil= {
        args = "(value)", type = "function",        returns = "()",
        description="Assert that a given value is nil.",
      },
      assertNotNil= {
        args = "(value)", type = "function",        returns = "()",
        description=[[Assert that a given value is not nil . Lua coercion rules are applied so that values like 0, "", false all validate the assertion.]],
      },
      assertIs= {
        args = "(actual, expected)",type = "function",        returns = "()",
        description=[[Assert that two variables are identical. For string, numbers, boolean and for nil, this gives the same result as assertEquals(). For the other types, identity means that the two variables refer to the same object.]],
      },
      assertNotIs= {
        args = "(actual, expected)",type = "function",        returns = "()",
        description=[[Assert that two variables are not identical, in the sense that they do not refer to the same value. See assertIs() for more details.]],
      },

      assertStrContains= {
        args = "(str, sub[, useRe])",type = "function",        returns = "()",
        description=[[Assert that a string contains the given substring or pattern.

By default, substring is searched in the string. If useRe is provided and is true, sub is treated as a pattern which is searched inside the string str .
]],
      },
      assertStrIContains= {
        args = "(str, sub)",        type = "function",        returns = "()",
        description=[[Assert that a string contains the given substring, irrespective of the case.

Not that unlike assertStrcontains(), you can not search for a pattern.]],
      },

      assertNotStrContains= {
        args = "(str, sub[, useRe])",        type = "function",        returns = "()",
        description=[[Assert that a string does not contain a given substring or pattern.

By default, substring is searched in the string. If useRe is provided and is true, sub is treated as a pattern which is searched inside the string str .
]],
      },
      assertNotStrIContains= {
        args = "(str, sub)",        type = "function",        returns = "()",
        description=[[Assert that a string does not contain the given substring, irrespective of the case.

Not that unlike assertNotStrcontains(), you can not search for a pattern.]],
      },
      assertStrMatches= {
        args = "(str, pattern[, start[, final]])", type = "function",        returns = "()",
        description=[[Assert that a string matches the full pattern pattern.
        
If start and final are not provided or are nil, the pattern must match the full string, from start to end. The functions allows to specify the expected start and end position of the pattern in the string.]],
      },
      assertError= {
        args = "(func, ...)", type = "function",        returns = "()",
        description=[[Assert that calling functions func with the arguments yields an error. If the function does not yield an error, the assertion fails.

Note that the error message itself is not checked, which means that this function does not distinguish between the legitimate error that you expect and another error that might be triggered by mistake.

Use assertErrorMsgXXX for a better approach to error testing, by checking explicitly the error message content.]]  ,      type = "function",        returns = "()",
      },
      assertErrorMsgEquals = {
        args = "(expectedMsg, func, ...)", type = "function",        returns = "()",
        description=[[Assert that calling function func will generate exactly the given error message. If the function does not yield an error, or if the error message is not identical, the assertion fails.

Be careful when using this function that error messages usually contain the file name and line number information of where the error was generated. This is usually inconvenient. To ignore the filename and line number information, you can either use a pattern with assertErrorMsgMatches() or simply check for the message containt with assertErrorMsgContains() .]] ,       type = "function",        returns = "()",
      },
      assertErrorMsgContains= {
        args = "(partialMsg, func, ...)", type = "function",        returns = "()",
        description=[[Assert that calling function func will generate an error message containing partialMsg . If the function does not yield an error, or if the expected message is not contained in the error message, the assertion fails.]] ,      

      }, 
      assertErrorMsgMatches= {
        args = "(expectedPattern, func, ...)",  type = "function",        returns = "()",
        description=[[Assert that calling function func will generate an error message matching expectedPattern . If the function does not yield an error, or if the error message does not match the provided patternm the assertion fails.

Note that matching is done from the start to the end of the error message. Be sure to escape all magic characters with % (like -+.?*) .]] ,     
      },

      assertIsNumber= {
        args = "(value)",   type = "function",        returns = "()",
        description=[[Assert that the argument is a number (integer or float).]] ,    
      },

      assertIsString= {
        args = "(value)", type = "function", returns = "()",
        description=[[Assert that the argument is a string.]] ,      
      },

      assertIsTable= {
        args = "(value)", type = "function", returns = "()",
        description=[[Assert that the argument is a table.]] ,      
      },

      assertIsBoolean= {
        args = "(value)", type = "function", returns = "()",
        description=[[Assert that the argument is a boolean.]] ,      
      },

      assertIsNil= {
        args = "(value)", type = "function", returns = "()",
        description=[[Assert that the argument is a nil.]] ,       
      },

      assertIsFunction= {
        args = "(value)", type = "function", returns = "()",
        description=[[Assert that the argument is a function.]] ,    
      },

      assertIsUserdata= {
        args = "(value)", type = "function", returns = "()",
        description=[[Assert that the argument is a userdata.]] ,        
      },
      assertIsCoroutine= {
        args = "(value)", type = "function", returns = "()",
        description=[[Assert that the argument is a coroutine (an object with type thread ).]] ,    
      },

      assertItemsEquals= {  
        args = "(actual, expected)", type = "function", returns = "()",
        description=[[Assert that two tables contain the same items, irrespective of their keys.

This function is practical for example if you want to compare two lists but where items are not in the same order:

luaunit.assertItemsEquals( {1,2,3}, {3,2,1} ) -- assertion succeeds

The comparison is not recursive on the items: if any of the items are tables, they are compared using table equality (like as in assertEquals() ), where the key matters.

luaunit.assertItemsEquals( {1,{2,3},4}, {4,{3,2,},1} ) -- assertion fails because {2,3} ~= {3,2}
]] , 
      },
    }
  } 
} 


return {
  name = "luaunit",
  description = "Adds API description for auto-complete and tooltip support for luaunit v3.4 .",
  author = "Chowette",
  version = "20200228",

  onRegister = function(self)
    ide:AddAPI("lua", "luaunit", api)
    
  end,

  onUnRegister = function(self)
    ide:RemoveAPI("lua", "luaunit")
  end,
}
