return {
  name = "Auto-start debugger server",
  description = "Auto-start debugger server.",
  author = "Paul Kulchenko",
  version = 0.2,
  dependencies = "1.4",

  onRegister = function() ide:GetDebugger():Listen(true) end,
}
