return {
  name = "Auto-start debugger server",
  description = "Auto-start debugger server.",
  author = "Paul Kulchenko",
  version = 0.1,

  onRegister = function() DebuggerAttachDefault() end,
}
