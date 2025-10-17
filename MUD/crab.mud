@add|__manifest__|1|meta
cmd=godmode entry=cheats/god.eee
@end

@add|cheats/god.eee|3|script
cmd_godmode = function(line, args)
  print_line("godmode: on")
  return 0
end function
@end