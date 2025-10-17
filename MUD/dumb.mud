// dumb.mud — gate helpers with ETA, force, and configurable progress

// ===== helpers =====
dm_repeat = function(ch, n)
  out = ""
  i = 0
  while i < n
    out = out + ch
    i = i + 1
  end while
  return out
end function

dm_idiv = function(a, b) // floor(a/b)
  r = 0
  while (r + 1) * b <= a
    r = r + 1
  end while
  return r
end function

dm_is_space_addr = function(s)
  if s == null then return 0
  t = s.lower
  if t.len != 5 then return 0
  i = 0
  while i < 5
    c = t[i]
    if c < "a" or c > "x" then return 0
    i = i + 1
  end while
  return 1
end function

dm_is_time_like = function(s)
  if s == null then return 0
  return s.len == 12
end function

dm_digits_only = function(s)
  if s == null or s.len == 0 then return 0
  i = 0
  while i < s.len
    c = s[i]
    if c < "0" or c > "9" then return 0
    i = i + 1
  end while
  return 1
end function

dm_is_int = function(s)
  if s == null or s.len == 0 then return 0
  i = 0
  if s[0] == "-" then
    if s.len == 1 then return 0
    i = 1
  end if
  while i < s.len
    c = s[i]
    if c < "0" or c > "9" then return 0
    i = i + 1
  end while
  return 1
end function

dm_time12 = function(h24, mi)
  mer = "AM"
  h = h24
  if h >= 12 then mer = "PM"
  if h == 0 then h = 12
  if h > 12 then h = h - 12
  mm = str(mi)
  if mi < 10 then mm = "0" + mm
  return str(h) + ":" + mm + mer
end function

// ETA computed once from total seconds. 1 game minute = 4 real seconds.
dm_eta_time_fixed = function(total_s)
  add_min = dm_idiv(total_s + 3, 4) // ceil(total_s/4)
  h = gethour()
  m = getminute() + add_min
  while m >= 60
    m = m - 60
    h = h + 1
  end while
  while h >= 24
    h = h - 24
  end while
  return dm_time12(h, m)
end function

dm_parse_flags = function(args)
  force = 0
  out = []
  for a in args
    al = a.lower
    if al == "-f" or al == "--force" then
      force = 1
    else
      out.push(a)
    end if
  end for
  return [force, out]
end function

dm_classify_addr = function(addr) // returns [valid, kind, note, hint]
  // kind: "space","time","time-weird","invalid"
  if dm_is_space_addr(addr) then
    return [1, "space", "Format: SPACE address (5 letters a–x)", "Ensure SPACE core is installed."]
  end if
  if dm_is_time_like(addr) then
    if dm_digits_only(addr) then
      return [1, "time", "Format: TIME address MMDDYYYYHHMM", "Ensure TIME core is installed."]
    else
      return [1, "time-weird", "Format: 12-char TIME address (non-digits). Intended MMDDYYYYHHMM.", "Ensure TIME core is installed."]
    end if
  end if
  return [0, "invalid", "Format: invalid. Expected 5 letters a–x or any 12-char string.", ""]
end function

// ----- progress UIs -----
DM_DIAL_SECONDS = 28
DM_BARLEN = 29

// header OFF: dots + single ETA line, no seconds display
dm_progress_simple = function(seconds, eta_str)
  println("ETA: ~" + eta_str)
  print "dialing: "
  i = 0
  while i < seconds
    print "."
    wait 1
    i = i + 1
  end while
  breakline
end function

// header ON: redraw per tick. Order: format, reminder, Dialing, bar, ETA.
// Show 100% on last frame, then brief settle so it's visible.
dm_progress_fancy = function(seconds, addr, cmdline, eta_str, note, hint)
  i = 0
  while i <= seconds
    clear
    render_header(cmdline)

    // format type
    if note != "" then println(note)
    // install reminder
    if hint != "" then println(hint)
    // dialing line
    println("Dialing: " + addr)

    // progress bar
    pct = dm_idiv(i * 100, seconds)
    if i >= seconds then pct = 100
    fill = dm_idiv(i * DM_BARLEN, seconds)
    if i >= seconds then fill = DM_BARLEN
    empty = DM_BARLEN - fill
    if empty < 0 then empty = 0
    println("[" + dm_repeat("#", fill) + dm_repeat("-", empty) + "]  " + str(pct) + "%")

    // ETA last
    rem = seconds - i
    if rem < 0 then rem = 0
    println("ETA: ~" + eta_str + " (" + str(rem) + "s remaining)")

    if i == seconds then
      wait 0.25 // settle so 100% frame is visible
      break
    end if
    wait 1
    i = i + 1
  end while
end function

// ===== car =====
verb_car = function(args)
  cardiag()
end function
help_car = "show time car diagnostics"
help_car_long = "Usage: car" + char(10) + "Runs the in-vehicle diagnostics and prints status."

verb_cardiag = function(args)
  verb_car(args)
end function
help_cardiag = "alias of car"
help_cardiag_long = "Usage: cardiag" + char(10) + "Same as 'car'."

// ===== travel / cantravel =====
verb_travel = function(args)
  if args.len < 1 then
    println("usage: travel <year>")
    return
  end if
  ystr = args[0]
  if not dm_is_int(ystr) then
    println("travel: year must be an integer, got '" + ystr + "'")
    return
  end if
  y = val(ystr)
  ok = cantravel(y)
  if ok == 1 then
    println("OK: travel to " + str(y) + " is possible")
  else
    println("NO: travel to " + str(y) + " is not possible")
  end if
end function
help_travel = "check if a year is travelable"
help_travel_long = "Usage: travel <year>" + char(10) + "Calls cantravel(year) and prints a result."

verb_cantravel = function(args)
  verb_travel(args)
end function
help_cantravel = "alias of travel"
help_cantravel_long = "Usage: cantravel <year>"

// ===== hack =====
verb_hack = function(args)
  if args.len < 1 then
    println("usage: hack open | hack close | hack mim")
    return
  end if
  sub = args[0].lower
  if sub == "open" then
    openperipheral()
    println("hack: open")
    return
  end if
  if sub == "close" then
    closeperipheral()
    println("hack: close")
    return
  end if
  if sub == "mim" then
    SetFactionMimCore()
    println("hack: mim core takeover requested")
    return
  end if
  println("hack: unknown subcommand")
end function
help_hack = "open/close peripherals, act4 mim core"

// ===== direct gate intrinsics =====
verb_connectgate = function(args)
  connectgate()
end function
help_connectgate = "call connectgate()"

verb_dialgate = function(args)
  if args.len < 1 then
    println("usage: dialgate <address>")
    return
  end if
  dialgate args[0]
end function
help_dialgate = "call dialgate(<address>)"

verb_gatereadings = function(args)
  clear
  gatereadings()
end function
help_gatereadings = "clear then call gatereadings()"

verb_recalltimegate = function(args)
  recalltimegate()
end function
help_recalltimegate = "call recalltimegate()"

// ===== dial program =====
verb_dial = function(args)
  if args.len < 1 then
    println("usage: dial [-f|--force] <address>|read|readings|recall|readings on|off|read on|off")
    return
  end if

  // config toggle: dial readings|read on|off
  if args.len >= 2 then
    s0 = args[0].lower
    s1 = args[1].lower
    if (s0 == "read" or s0 == "readings") and (s1 == "on" or s1 == "off") then
      if s1 == "on" then
        vfs_set("/etc/mud/config/dial/progress_enabled", "1")
        println("dial: progress enabled")
      else
        vfs_set("/etc/mud/config/dial/progress_enabled", "0")
        println("dial: progress disabled")
      end if
      return
    end if
  end if

  // immediate actions
  sub0 = args[0].lower
  if sub0 == "read" or sub0 == "readings" then
    clear
    gatereadings()
    return
  end if
  if sub0 == "recall" then
    recalltimegate()
    return
  end if

  // parse flags
  parsed = dm_parse_flags(args)
  force = parsed[0]
  argv = parsed[1]
  if argv.len < 1 then
    println("usage: dial [-f|--force] <address>|read|readings|recall|readings on|off")
    return
  end if
  addr = argv[0]

  // classify
  cls = dm_classify_addr(addr)
  isValid = cls[0]
  kind = cls[1]
  note = cls[2]
  hint = cls[3]

  hdr = vfs_get("/etc/mud/config/header_enabled")
  if hdr == null then hdr = "1"

  // validation unless forced
  if isValid == 0 and force == 0 then
    println("dial: " + note)
    println("hint: use -f or --force to dial anyway.")
    return
  end if

  // upfront info when header OFF
  if hdr != "1" then
    if note != "" then println(note)
    if hint != "" then println(hint)
  end if

  // connect, settle, dial
  connectgate()
  wait 2.1 // sometimes 2 is too short
  dialgate addr

  // progress config
  prog = vfs_get("/etc/mud/config/dial/progress_enabled")
  if prog == null then prog = "1"

  // compute ETA once
  eta_str = dm_eta_time_fixed(DM_DIAL_SECONDS)

  if prog == "1" and kind == "space" then
    if hdr == "1" then
      cmdline = "dial " + addr
      if force == 1 then cmdline = "dial -f " + addr
      fancy_note = note
      fancy_hint = hint
      if isValid == 0 and force == 1 then fancy_note = "forced: " + note + " Dialing anyway."
      dm_progress_fancy(DM_DIAL_SECONDS, addr, cmdline, eta_str, fancy_note, fancy_hint)
      clear
      gatereadings()
    else
      dm_progress_simple(DM_DIAL_SECONDS, eta_str)
      clear
      gatereadings()
    end if
  else
    // progress disabled: just return control after initial info
    // no readings auto-display
  end if
end function

help_dial = "dial a gate; progress bar configurable"
help_dial_long = "Usage:" + char(10) +
"  dial [-f|--force] <address> - connect, wait, dial, optional progress, then readings if enabled" + char(10) +
"  dial readings|read           - show current gate readings now" + char(10) +
"  dial readings|read on|off    - enable/disable progress+auto-readings" + char(10) +
"  dial recall                  - recall time gate" + char(10) +
"Notes:" + char(10) +
"- SPACE: 5 letters a–x. TIME: 12 chars (intended MMDDYYYYHHMM). Non-digit 12 chars dial with warning." + char(10) +
"- Reminders: Ensure SPACE/TIME core installed for the selected format." + char(10) +
"- Progress shows 100% on last frame, then clears to readings when enabled."
