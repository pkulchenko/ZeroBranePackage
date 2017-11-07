return {
  name = "Auto-start debugger server",
  description = "Auto-starts debugger server.",
  author = "Paul Kulchenko",
  version = 0.21,
  dependencies = "1.4",

  onRegister = function() ide:GetDebugger():Listen(true) end,
}
