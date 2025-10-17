// soft.mud — first-party software commands

reg_soft = function()
  DISPATCH["dial"] = @cmd_dial
  DISPATCH["scan"] = @cmd_scan
  return 0
end function

cmd_dial = function(line, args)
  print_line("dial: not implemented")
  return 0
end function

cmd_scan = function(line, args)
  print_line("scan: not implemented")
  return 0
end function
