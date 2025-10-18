// crawl.mud — no VFS, single-file checkpoint (crawl.save)

CR_LEFT_W = 43
CR_RIGHT_W = 20
CR_SEP = "|"
CR_LASTLINE_FREE = 2
CR_LF = char(10)
CR_MSG_N = 4

CR_CLOCK_START_CS = 8 * 3600 * 100  // start at 08:00:00.00 (centiseconds)
CR_CLOCK_HOURS = 8
CR_CLOCK_MINUTES = 0
CR_CLOCK_SECONDS = 0
CR_CLOCK_TENTHS = 0
CR_LAST_CLOCK_TICK = 0

// regen timings (ticks per +1 HP). 1 tick = 0.2 s
REGEN_MINOR_IDLE_T = 4500   // 15 min
REGEN_MINOR_SLEEP_T = 1500  // 5  min
REGEN_MOD_IDLE_T   = 9000   // 30 min
REGEN_MOD_SLEEP_T  = 3000   // 10 min
REGEN_CRIT_IDLE_T  = 0      // none
REGEN_CRIT_SLEEP_T = 4500   // 15 min

REGEN_KCAL_HP = 20 // 20 kcal per hp
REGEN_WATER_HP = 0.01 // 0.01 water per hp

REGEN_WATER_GATE = 0.5      // need at least this water to regen

CHUNK = 144000 // 8 hours for sleep/rest operations

VIEW_W = 43
VIEW_H = 13

LVL_W = 64
LVL_H = 48

CR_SAVE_PATH = "crawl.save"


// ---------- PLC file I/O (overwrite whole file) ----------
cr_file_write_all = function(p, txt)
  L = txt.split(CR_LF)
  oldN = countlines(p)
  if oldN <= 0 then
    create(p)
    oldN = 0
  end if
  i = 0
  while i < L.len
    writeline(p, i, L[i])
    i = i + 1
  end while
  // clear any leftover old lines without deleting the file
  while i < oldN
    writeline(p, i, "")
    i = i + 1
  end while
end function

cr_file_read_all = function(p)
  n = countlines(p)
  if n <= 0 then return null
  out = ""
  i = 0
  while i < n
    if i > 0 then out = out + CR_LF
    out = out + readfile(p, i)
    i = i + 1
  end while
  return out
end function

cr_file_delete = function(p)
  if countlines(p) > 0 then delete(p)
end function

// ---------- checkpoint pack/unpack ----------
cr_ts_now = function()
  y = str(getyear())
  mo = "0" + str(getmonth()); mo = mo[-2:]
  d = "0" + str(getday()); d = d[-2:]
  h = "0" + str(gethour()); h = h[-2:]
  mi = "0" + str(getminute()); mi = mi[-2:]
  return y + mo + d + "-" + h + mi
end function

// links/used encoders so stairs form one-to-one connections per index
cr_link_key = function(fid, dir, idx)
  return fid + "^" + dir + "^" + str(idx)
end function

cr_links_to_str = function(L)
  if L == null then return ""
  ks = L.indexes
  out = ""
  i = 0
  while i < ks.len
    k = ks[i]
    if out.len > 0 then out = out + ","
    out = out + k + "=" + L[k]
    i = i + 1
  end while
  return out
end function

cr_links_from_str = function(s)
  D = {}
  if s == null or s == "" then return D
  parts = s.split(","); i = 0
  while i < parts.len
    p = parts[i].split("=")
    if p.len >= 2 then D[p[0]] = p[1]
    i = i + 1
  end while
  return D
end function

cr_links_get = function(L, fid, dir, idx)
  key = cr_link_key(fid, dir, idx)
  if L.hasIndex(key) then
    return L[key]
  else
    return null
  end if
end function

cr_links_set_pair = function(L, srcFid, dir, idx, dstFid)
  L[cr_link_key(srcFid, dir, idx)] = dstFid
  if dir == "down" then
    L[cr_link_key(dstFid, "up", idx)] = srcFid
  else
    L[cr_link_key(dstFid, "down", idx)] = srcFid
  end if
end function

cr_used_to_str = function(U)
  if U == null then return ""
  ks = U.indexes
  out = ""
  i = 0
  while i < ks.len
    k = ks[i]
    if out.len > 0 then out = out + ","
    out = out + k + ":" + U[k]
    i = i + 1
  end while
  return out
end function

cr_used_from_str = function(s)
  U = {}
  if s == null or s == "" then return U
  parts = s.split(","); i = 0
  while i < parts.len
    p = parts[i].split(":")
    if p.len >= 2 then U[p[0]] = p[1]
    i = i + 1
  end while
  return U
end function

cr_used_has = function(U, floorN, v)
  k = str(floorN)
  if not U.hasIndex(k) then return 0
  s = U[k]
  j = 0
  while j < s.len
    if s[j:j+1] == v then return 1
    j = j + 1
  end while
  return 0
end function

cr_used_add = function(U, floorN, v)
  k = str(floorN)
  s = ""
  if U.hasIndex(k) then s = U[k]
  j = 0; seen = 0
  while j < s.len
    if s[j:j+1] == v then seen = 1
    j = j + 1
  end while
  if not seen then U[k] = s + v else U[k] = s
end function

cr_used_next_free = function(U, floorN)
  code = 65
  while code <= 90
    v = char(code)
    if not cr_used_has(U, floorN, v) then return v
    code = code + 1
  end while
  return "Z"
end function

// generic string map <-> string codecs (values may contain ':' and ';' but not ','' or '=')
cr_dict_to_str = function(M)
  if M == null then return ""
  ks = M.indexes
  out = ""
  i = 0
  while i < ks.len
    k = ks[i]
    if out.len > 0 then out = out + ","
    out = out + k + "=" + M[k]
    i = i + 1
  end while
  return out
end function

cr_dict_from_str = function(s)
  D = {}
  if s == null or s == "" then return D
  parts = s.split(","); i = 0
  while i < parts.len
    p = parts[i].split("=")
    if p.len >= 2 then D[p[0]] = p[1]
    i = i + 1
  end while
  return D
end function

// ---------- checkpoint pack/unpack ----------
cr_ckpt_pack = function(life,fid,px,py,tick,hp,hpMax,lvl,xp,xpNext,enemies,items,links,used,eBy,iBy)
  return ("hdr|CrawlSave1" + CR_LF +
      "fid|" + fid + CR_LF +
      "life|" + life + CR_LF +
      "px|" + str(px) + CR_LF +
      "py|" + str(py) + CR_LF +
      "tick|" + str(tick) + CR_LF +
      "hp|" + str(hp) + CR_LF + "hpMax|" + str(hpMax) + CR_LF +
      "kcal|" + str(G_KCAL) + CR_LF + "water|" + str(G_WATER) + CR_LF + "alert|" + str(G_ALERT) + CR_LF +
      "lvl|" + str(lvl) + CR_LF + "xp|" + str(xp) + CR_LF + "xpNext|" + str(xpNext) + CR_LF +
      "enemies|" + cr_enemies_to_str(enemies) + CR_LF +
      "items|" + cr_items_to_str(items) + CR_LF +
      "links|" + cr_links_to_str(links) + CR_LF +
      "used|" + cr_used_to_str(used) + CR_LF +
      "byE|" + cr_dict_to_str(eBy) + CR_LF +
      "byI|" + cr_dict_to_str(iBy) + CR_LF +
      "ts|" + cr_ts_now())
end function

cr_ckpt_unpack = function(txt)
  if txt == null then return null
  lines = txt.split(CR_LF)
  m = {}
  i = 0
  while i < lines.len
    if lines[i].len > 0 then
      p = lines[i].split("|")
      if p.len >= 2 then m[p[0]] = lines[i][(p[0].len + 1):]
    end if
    i = i + 1
  end while
  if not m.hasIndex("fid") then return null
  // ints
  toInt = function(k); if m.hasIndex(k) then m[k] = val(m[k]); end function
  toNum = function(k); if m.hasIndex(k) then m[k] = val(m[k]); end function
  toInt("px"); toInt("py"); toInt("tick"); toInt("hp"); toInt("hpMax"); toInt("lvl"); toInt("xp"); toInt("xpNext")
  // pools (defaults)
  if m.hasIndex("kcal") then G_KCAL = val(m["kcal"]) else G_KCAL = 1200
  if m.hasIndex("water") then G_WATER = val(m["water"]) else G_WATER = 1.0
  if m.hasIndex("alert") then G_ALERT = val(m["alert"]) else G_ALERT = 100
  // payloads
  if m.hasIndex("enemies") then m["enemies"] = cr_str_to_enemies(m["enemies"]) else m["enemies"] = []
  if m.hasIndex("items") then m["items"] = cr_str_to_items(m["items"]) else m["items"] = []
  if m.hasIndex("links") then m["links"] = cr_links_from_str(m["links"]) else m["links"] = {}
  if m.hasIndex("used") then m["used"] = cr_used_from_str(m["used"]) else m["used"] = {}
  if m.hasIndex("byE") then m["byE"] = cr_dict_from_str(m["byE"]) else m["byE"] = {}
  if m.hasIndex("byI") then m["byI"] = cr_dict_from_str(m["byI"]) else m["byI"] = {}
  return m
end function


cr_ckpt_save = function(life,fid,px,py,tick,hp,hpMax,lvl,xp,xpNext,enemies,items,links,used,eBy,iBy)
  cr_file_write_all(CR_SAVE_PATH, cr_ckpt_pack(life,fid,px,py,tick,hp,hpMax,lvl,xp,xpNext,enemies,items,links,used,eBy,iBy))
end function

cr_ckpt_load = function()
  return cr_ckpt_unpack(cr_file_read_all(CR_SAVE_PATH))
end function

cr_ckpt_delete = function()
  cr_file_delete(CR_SAVE_PATH)
end function

G_MSGS = []

// right info box max columns = 20
cr_msg_push = function(s)
  if s == null then return
  if s.len <= 0 then return
  G_MSGS.push(s)
  while G_MSGS.len > CR_MSG_N
    G_MSGS.remove(0)
  end while
end function

// ---------- clock ----------
cr_2d = function(n); s = "0" + str(n); return s[-2:]; end function
cr_fmt_clock = function(tick)
  // 1 tick = 0.20 s = 20 cs
  cs = CR_CLOCK_START_CS + tick * 20
  sTot = cr_idiv(cs, 100)
  csRem = cs - sTot * 100
  hTot = cr_idiv(sTot, 3600)
  h = cr_mod(hTot, 24)
  m = cr_idiv(sTot - hTot * 3600, 60)
  s = sTot - hTot * 3600 - m * 60
  tenths = cr_idiv(csRem, 10)     // 0..9
  return cr_2d(h) + ":" + cr_2d(m) + ":" + cr_2d(s) + "." + str(tenths)
end function

cr_fmt_dur_ticks = function(dt_ticks)
  // 1 tick = 0.20 s = 20 centiseconds
  total_cs = dt_ticks * 20
  sTot = cr_idiv(total_cs, 100)
  csRem = total_cs - sTot * 100
  h = cr_idiv(sTot, 3600)
  m = cr_idiv(sTot - h * 3600, 60)
  s = sTot - h * 3600 - m * 60
  tenths = cr_idiv(csRem, 10)
  return cr_2d(h) + ":" + cr_2d(m) + ":" + cr_2d(s) + "." + str(tenths)
end function

cr_clock_init = function(tick)
  globals.CR_LAST_CLOCK_TICK = tick
  total_cs = CR_CLOCK_START_CS + tick * 20
  total_seconds = floor(total_cs / 100)
  globals.CR_CLOCK_HOURS   = floor(total_seconds / 3600) % 24
  remaining_seconds        = total_seconds % 3600
  globals.CR_CLOCK_MINUTES = floor(remaining_seconds / 60)
  globals.CR_CLOCK_SECONDS = remaining_seconds % 60
  globals.CR_CLOCK_TENTHS  = floor((total_cs % 100) / 10)
end function

cr_clock_tick = function(tick)
  if tick <= globals.CR_LAST_CLOCK_TICK then return

  ticks_elapsed = tick - globals.CR_LAST_CLOCK_TICK
  globals.CR_LAST_CLOCK_TICK = tick

  total_new_cs      = ticks_elapsed * 20
  total_new_seconds = floor(total_new_cs / 100)
  new_tenths        = floor((total_new_cs % 100) / 10)

  globals.CR_CLOCK_TENTHS = globals.CR_CLOCK_TENTHS + new_tenths
  if globals.CR_CLOCK_TENTHS >= 10 then
    extra_seconds = floor(globals.CR_CLOCK_TENTHS / 10)
    globals.CR_CLOCK_TENTHS = globals.CR_CLOCK_TENTHS % 10
    total_new_seconds = total_new_seconds + extra_seconds
  end if

  globals.CR_CLOCK_SECONDS = globals.CR_CLOCK_SECONDS + total_new_seconds
  if globals.CR_CLOCK_SECONDS >= 60 then
    extra_minutes = floor(globals.CR_CLOCK_SECONDS / 60)
    globals.CR_CLOCK_SECONDS = globals.CR_CLOCK_SECONDS % 60
    globals.CR_CLOCK_MINUTES = globals.CR_CLOCK_MINUTES + extra_minutes
  end if

  if globals.CR_CLOCK_MINUTES >= 60 then
    extra_hours = floor(globals.CR_CLOCK_MINUTES / 60)
    globals.CR_CLOCK_MINUTES = globals.CR_CLOCK_MINUTES % 60
    globals.CR_CLOCK_HOURS   = (globals.CR_CLOCK_HOURS + extra_hours) % 24
  end if
end function

cr_fmt_clock_fast = function()
  h = globals.CR_CLOCK_HOURS
  m = globals.CR_CLOCK_MINUTES
  s = globals.CR_CLOCK_SECONDS
  t = globals.CR_CLOCK_TENTHS
  return cr_2d(h) + ":" + cr_2d(m) + ":" + cr_2d(s) + "." + str(t)
end function

// ---------- utils ----------
cr_repeat = function(ch, n)
  out = ""
  i = 0
  while i < n
    out = out + ch
    i = i + 1
  end while
  return out
end function

cr_idiv = function(a, b)
  r = 0
  while (r + 1) * b <= a
    r = r + 1
  end while
  return r
end function

cr_mod = function(a, m)
  q = cr_idiv(a, m)
  return a - q * m
end function

cr_pad = function(s, w)
  t = str(s)
  if t.len > w then return t[0:w]
  return t + cr_repeat(" ", w - t.len)
end function

cr_bar10 = function(cur, maxv)
  if maxv <= 0 then return "[..........]"
  n = cr_idiv(cur * 10, maxv)
  if n > 10 then n = 10
  if n < 0 then n = 0
  return "[" + cr_repeat("#", n) + cr_repeat(".", 10 - n) + "]"
end function

// ===== survival core =====
SPT = 0.20 // not used by PLC timing; for reference
TPH = 18000

HP_MAX_DEFAULT = 100
HUNGER_GATE = 800

// drains: ticks per unit change
IDLE_K_T = 225;   IDLE_W_T = 1800;  IDLE_A_T = 4800   // 16 min per −1
ACT_K_T  = 72;    ACT_W_T  = 600;   ACT_A_T  = 3600   // 12 min per −1
SLP_K_T  = 300;   SLP_W_T  = 3600;  SLP_A_T  = 2100   // 7  min per +1

TIRED_T   = 60     // ready-for-night
EXH_T     = 20     // near collapse

REGEN_T = 100
REGEN_SLEEP_X = 2
STARVE_HP_T_K = 54000   // kcals==0 : 3 h per -1 HP
STARVE_HP_T_W = 9000    // water==0 : 30 min per -1 HP
STARVE_HP_T = 1800 // −1 HP if kcal==0 or water==0

// persistent player pools (saved via ckpt pack/unpack)
G_KCAL = 1200
G_WATER = 1.0
G_ALERT = 100

// accumulators (not saved)
G_ACC_K = 0; G_ACC_W = 0; G_ACC_A = 0
G_ACC_REGEN = 0; G_ACC_STARVE_K = 0; G_ACC_STARVE_W = 0
G_ACC_EXH = 0  // exhaustion: add cost while alert ≤20; +1 idle tick per 200

// status latches to avoid spam
G_S_HUNGRY = 0; G_S_STARVING = 0; G_S_THIRST = 0; G_S_DEHY = 0; G_S_VT = 0; G_S_EXH = 0

cr_clamp = function(x, lo, hi); if x < lo then return lo; if x > hi then return hi; return x; end function
cr_fmt1 = function(x); return str(cr_idiv(x*10,1)/10); end function

cr_speed_mul = function()
  // worst-of per axis, then multiply axes
  // hunger axis
  mH = 1.0
  if G_KCAL < 300 then
    mH = 0.75
  else if G_KCAL < 800 then
    mH = 0.9
  end if
  // water axis
  mW = 1.0
  if G_WATER < 0.25 then
    mW = 0.8
  else if G_WATER < 0.5 then
    mW = 0.9
  end if
  return mH * mW
end function

cr_cost_adj = function(baseTurns)
  // apply action speed multiplier, ceil to int >=1
  c = baseTurns * (1.0 / cr_speed_mul())
  ci = cr_idiv(c,1)
  if ci*1.0 < c then ci = ci + 1
  if ci < 1 then ci = 1
  return ci
end function

cr_status_msg_edge = function()
  g = globals
  if g["G_KCAL"] < 300 then
    if not g["G_S_STARVING"] then g["G_S_STARVING"] = 1; return "You are starving."
  else
    g["G_S_STARVING"] = 0
  end if
  if g["G_KCAL"] < 800 then
    if not g["G_S_HUNGRY"] then g["G_S_HUNGRY"] = 1; return "You are hungry."
  else
    g["G_S_HUNGRY"] = 0
  end if
  if g["G_WATER"] < 0.25 then
    if not g["G_S_DEHY"] then g["G_S_DEHY"] = 1; return "You are dehydrated."
  else
    g["G_S_DEHY"] = 0
  end if
  if g["G_WATER"] < 0.5 then
    if not g["G_S_THIRST"] then g["G_S_THIRST"] = 1; return "You are thirsty."
  else
    g["G_S_THIRST"] = 0
  end if
  if g["G_ALERT"] <= EXH_T then
    if not g["G_S_EXH"] then g["G_S_EXH"] = 1; return "You are exhausted."
  else
    g["G_S_EXH"] = 0
  end if
  if g["G_ALERT"] <= TIRED_T then
    if not g["G_S_VT"] then g["G_S_VT"] = 1; return "You feel very tired."
  else
    g["G_S_VT"] = 0
  end if

  return null
end function

cr_regen_ticks_per_hp = function(mode, hp)
  if hp <= 0 then return 0
  if hp >= HP_MAX_DEFAULT then return 0
  if G_KCAL < HUNGER_GATE then return 0
  if G_WATER < REGEN_WATER_GATE then return 0

  if hp < 40 then
    if mode == "sleep" then return REGEN_CRIT_SLEEP_T else return REGEN_CRIT_IDLE_T
  else if hp < 80 then
    if mode == "sleep" then return REGEN_MOD_SLEEP_T else return REGEN_MOD_IDLE_T
  else
    if mode == "sleep" then return REGEN_MINOR_SLEEP_T else return REGEN_MINOR_IDLE_T
  end if
end function

cr_next_regen_dt = function(mode, hp)
  tp = cr_regen_ticks_per_hp(mode, hp)
  if tp <= 0 then return 999999
  rem = cr_mod(globals.G_ACC_REGEN, tp)
  dt = tp - rem
  if dt <= 0 then dt = tp
  return dt
end function

// cr_pools_tick — direct global reads/writes (search: cr_pools_tick — direct)
cr_pools_tick = function(mode, dt, hp, status)
  // sync globals snapshot
  globals.G_ACC_K = G_ACC_K; globals.G_ACC_W = G_ACC_W; globals.G_ACC_A = G_ACC_A
  globals.G_ACC_REGEN = G_ACC_REGEN; globals.G_ACC_STARVE_K = G_ACC_STARVE_K; globals.G_ACC_STARVE_W = G_ACC_STARVE_W

  // choose rates
  kT = IDLE_K_T; wT = IDLE_W_T; aT = IDLE_A_T; aSign = -1
  if mode == "act" then
    kT = ACT_K_T; wT = ACT_W_T; aT = ACT_A_T; aSign = -1
  else if mode == "sleep" then
    kT = SLP_K_T; wT = SLP_W_T; aT = SLP_A_T; aSign = 1
  end if

  // kcal −1 per kT
  if kT > 0 then
    globals.G_ACC_K = G_ACC_K + dt
    dk = cr_idiv(G_ACC_K, kT)
    if dk > 0 then
      globals.G_KCAL = G_KCAL - dk
      if G_KCAL < 0 then globals.G_KCAL = 0
      globals.G_ACC_K = G_ACC_K - dk * kT
    end if
  end if

  // water −0.01 per wT
  if wT > 0 then
    globals.G_ACC_W = G_ACC_W + dt
    dw = cr_idiv(G_ACC_W, wT)
    if dw > 0 then
      globals.G_WATER = G_WATER - (dw * 0.01)
      if G_WATER < 0 then globals.G_WATER = 0
      globals.G_ACC_W = G_ACC_W - dw * wT
    end if
  end if

  // alert ±1 per aT
  if aT > 0 then
    globals.G_ACC_A = G_ACC_A + dt
    da = cr_idiv(G_ACC_A, aT)
    if da > 0 then
      globals.G_ALERT = cr_clamp(G_ALERT + aSign * da, 0, 100)
      globals.G_ACC_A = G_ACC_A - da * aT
    end if
  end if

  // starvation & dehydration damage (stacking)
  dsTot = 0
  if G_KCAL <= 0 and STARVE_HP_T_K > 0 then
    globals.G_ACC_STARVE_K = G_ACC_STARVE_K + dt
    dsK = cr_idiv(G_ACC_STARVE_K, STARVE_HP_T_K)
    if dsK > 0 then
      dsTot = dsTot + dsK
      globals.G_ACC_STARVE_K = G_ACC_STARVE_K - dsK * STARVE_HP_T_K
    end if
  end if
  if G_WATER <= 0 and STARVE_HP_T_W > 0 then
    globals.G_ACC_STARVE_W = G_ACC_STARVE_W + dt
    dsW = cr_idiv(G_ACC_STARVE_W, STARVE_HP_T_W)
    if dsW > 0 then
      dsTot = dsTot + dsW
      globals.G_ACC_STARVE_W = G_ACC_STARVE_W - dsW * STARVE_HP_T_W
    end if
  end if
  if dsTot > 0 then
    hp = hp - dsTot; if hp < 0 then hp = 0
  end if
  

  // regen: piecewise by HP band; sleep is faster
  tp = cr_regen_ticks_per_hp(mode, hp)
  if tp > 0 then
    globals.G_ACC_REGEN = G_ACC_REGEN + dt
    dr = cr_idiv(G_ACC_REGEN, tp)
    if dr > 0 then
      hp = hp + dr
      G_KCAL = G_KCAL - dr * REGEN_KCAL_HP       // ~20 kcal per HP
      G_WATER = G_WATER - dr * REGEN_WATER_HP   // 0.01 water per HP
      if hp > HP_MAX_DEFAULT then hp = HP_MAX_DEFAULT
      globals.G_ACC_REGEN = G_ACC_REGEN - dr * tp
    end if
  end if

  m = cr_status_msg_edge()
  if m != null then status = m
  return [hp, status]
end function

cr_any_enemy_visible = function(enemies, px, py)
  // rectangle visibility; shadowcasting TODO
  vx = px - cr_idiv(VIEW_W - 1, 2)
  vy = py - cr_idiv(VIEW_H - 1, 2)
  if vx < 0 then vx = 0
  if vy < 0 then vy = 0
  if vx > LVL_W - VIEW_W then vx = LVL_W - VIEW_W
  if vy > LVL_H - VIEW_H then vy = LVL_H - VIEW_H
  i = 0
  while i < enemies.len
    e = enemies[i]
    if e["x"] >= vx and e["x"] < vx + VIEW_W and e["y"] >= vy and e["y"] < vy + VIEW_H then return 1
    i = i + 1
  end while
  return 0
end function

// central time step that also advances pools - FIXED VERSION
cr_do_time = function(mode, baseCost, map, enemies, px, py, tick, hp, status)
  // Validate inputs to prevent state corruption
  if tick == null then
    print "ERROR: null tick in cr_do_time"
    return [0, hp, "Error: time corrupted", 0]
  end if
  if hp == null then
    print "ERROR: null hp in cr_do_time" 
    hp = HP_MAX_DEFAULT
  end if
  
  cost = cr_cost_adj(baseCost)

  // Process enemies up to the goal
  goal = tick + cost
  r = cr_enemies_process(map, enemies, px, py, goal, status)
  status = r[0]; hp = hp - r[1]; if hp < 0 then hp = 0
  if r[1] > 0 then cr_msg_push(status)
  
  // Process pools
  t2 = cr_pools_tick(mode, cost, hp, status)
  hp = t2[0]; status = t2[1]
  tick = goal

  // Exhaustion handling - SIMPLIFIED
  if G_ALERT <= 20 then
    globals.G_ACC_EXH = G_ACC_EXH + cost
    exh_ticks = cr_idiv(G_ACC_EXH, 200)
    if exh_ticks > 0 then
      // Process exhaustion as a separate time step
      rE = cr_enemies_process(map, enemies, px, py, tick + exh_ticks, status)
      status = rE[0]; hp = hp - rE[1]; if hp < 0 then hp = 0
      tE = cr_pools_tick("idle", exh_ticks, hp, status)
      hp = tE[0]; status = tE[1]
      tick = tick + exh_ticks
      globals.G_ACC_EXH = G_ACC_EXH - exh_ticks * 200
    end if
  end if
  cr_clock_tick(tick) // update clock with the new tick
  return [tick, hp, status]
end function

cr_rest = function(map, enemies, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status)
    // ----- REST: Heal when not tired but wounded -----
    // Check for visible enemies first - no resting in danger
    if cr_any_enemy_visible(enemies, px, py) then
        status = "Visible! Can't rest"
        cr_msg_push(status)
        return [tick, hp, status, 0]
    end if

    // Already fully healed check
    if hp >= hpMax then
        status = "Fully healed"
        cr_msg_push(status)
        return [tick, hp, status, 0]
    end if

    // Strict healing prerequisites
    if globals.G_KCAL < HUNGER_GATE then
        status = "Too hungry to heal"
        cr_msg_push(status)
        return [tick, hp, status, 0]
    end if
    
    if globals.G_WATER < REGEN_WATER_GATE then
        status = "Too thirsty to heal"
        cr_msg_push(status)
        return [tick, hp, status, 0]
    end if

    // Check if healing is actually possible at current injury level
    healing_rate = cr_regen_ticks_per_hp("idle", hp)
    if healing_rate <= 0 then
        if hp < 40 then
            status = "Need medical care"
        else
            status = "Can't heal now"
        end if
        cr_msg_push(status)
        return [tick, hp, status, 0]
    end if

    return cr_do_rest(map, enemies, px, py, floorN, var, tick, hp, hpMax, status)
end function

cr_sleep = function(map, enemies, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status)
    // ----- SLEEP: Must be tired -----
    // Check for visible enemies first - no sleeping in danger
    if cr_any_enemy_visible(enemies, px, py) then
        status = "Visible! Can't sleep"
        cr_msg_push(status)
        return [tick, hp, status, 0]
    end if

    // Must be tired to sleep
    if globals.G_ALERT > TIRED_T then
        status = "Not tired enough to sleep"
        cr_msg_push(status)
        return [tick, hp, status, 0]
    end if

    // Check if sleep would actually provide alertness recovery
    if cr_next_alert_gain() <= 0 then
        status = "Too tired for sleep"
        cr_msg_push(status)
        return [tick, hp, status, 0]
    end if

    // Danger zone confirmation for low food/water
    if globals.G_KCAL < 300 or globals.G_WATER < 0.25 then
        print "Low supplies. Sleep? y/n"
        confirm = null
        while confirm == null
            confirm = readkey
        end while
        if confirm.lower != "y" then
            status = "Sleep cancelled"
            cr_msg_push(status)
            return [tick, hp, status, 0]
        end if
        clear
    end if

    return cr_do_sleep(map, enemies, px, py, floorN, var, tick, hp, status)
end function

cr_next_alert_gain = function()
    if SLP_A_T <= 0 then return 0
    remA = cr_mod(globals.G_ACC_A, SLP_A_T)
    return SLP_A_T - remA
end function

cr_do_sleep = function(map, enemies, px, py, floorN, var, tick, hp, status)
    cr_draw_loading("F" + str(floorN) + var, "Sleeping...")
    interrupted = 0
    sleep_start = tick
    cycles_without_progress = 0

    while globals.G_ALERT < 100 and hp > 0
        // Check if we're still making progress
        dA = cr_next_alert_gain()
        if dA <= 0 then
            cycles_without_progress = cycles_without_progress + 1
            if cycles_without_progress > 10 then
                status = "Alertness not improving - interrupted sleep."
                cr_msg_push(status)
                interrupted = 1
                break
            end if
        else
            cycles_without_progress = 0
        end if

        dR = cr_next_regen_dt("sleep", hp)
        dS = cr_next_starve_dt()

        dt = dA
        if dR < dt and dR > 0 then dt = dR
        if dS < dt then dt = dS
        if dt > CHUNK then dt = CHUNK
        if dt < 1 then dt = 1

        r = cr_do_time("sleep", dt, map, enemies, px, py, tick, hp, status)
        tick = r[0]; hp = r[1]; status = r[2]

        if hp <= 0 then break
        if cr_any_enemy_visible(enemies, px, py) then
            interrupted = 1
            break
        end if
    end while

    if hp > 0 then
        if interrupted then
            status = "You wake, interrupted."
        else
            status = "You feel rested."
        end if
        cr_msg_push(status)
        slept_ticks = tick - sleep_start
        if slept_ticks > 0 then
            cr_msg_push("Slept " + cr_fmt_dur_ticks(slept_ticks))
        end if
    end if
    return [tick, hp, status, 1]
end function

cr_do_rest = function(map, enemies, px, py, floorN, var, tick, hp, hpMax, status)
    cr_draw_loading("F" + str(floorN) + var, "Resting...")
    rest_start = tick
    start_hp = hp
    cycles_without_healing = 0
    max_cycles_without_healing = 3

    while hp < hpMax and hp > 0
        // Re-check conditions periodically
        if globals.G_KCAL < HUNGER_GATE or globals.G_WATER < REGEN_WATER_GATE then
            status = "Ran out of food/water during rest."
            cr_msg_push(status)
            break
        end if

        // Check if healing is still possible
        healing_rate = cr_regen_ticks_per_hp("idle", hp)
        if healing_rate <= 0 then
            status = "Healing stalled - condition worsened."
            cr_msg_push(status)
            break
        end if

        dR = cr_next_regen_dt("idle", hp)
        dS = cr_next_starve_dt()

        dt = dR
        if dS < dt then dt = dS
        if dt > CHUNK then dt = CHUNK
        if dt < 1 then dt = 1

        old_hp = hp
        r2 = cr_do_time("idle", dt, map, enemies, px, py, tick, hp, status)
        tick = r2[0]; hp = r2[1]; status = r2[2]
        if hp <= 0 then break

        if cr_any_enemy_visible(enemies, px, py) then
            status = "You see something."
            cr_msg_push(status)
            break
        end if

        // Track healing progress
        if hp > old_hp then
            cycles_without_healing = 0
            status = "Healed to " + str(hp) + "/" + str(hpMax) + " HP"
            cr_msg_push(status)
        else
            cycles_without_healing = cycles_without_healing + 1
            if cycles_without_healing >= max_cycles_without_healing then
                status = "No healing progress - stopping rest."
                cr_msg_push(status)
                break
            end if
        end if
    end while

    if hp > 0 then
        hp_gained = hp - start_hp
        if hp_gained > 0 then
            status = "Gained " + str(hp_gained) + " HP from rest."
            cr_msg_push(status)
        else
            status = "Rest completed with no healing."
            cr_msg_push(status)
        end if
        rest_ticks = tick - rest_start
        if rest_ticks > 0 then
            cr_msg_push("Rested " + cr_fmt_dur_ticks(rest_ticks))
        end if
    end if
    return [tick, hp, status, 1]
end function

cr_next_starve_dt = function()
    dS = 999999
    if globals.G_KCAL <= 0 and STARVE_HP_T_K > 0 then
        remK = cr_mod(globals.G_ACC_STARVE_K, STARVE_HP_T_K)
        nextK = STARVE_HP_T_K - remK; if nextK <= 0 then nextK = STARVE_HP_T_K
        if nextK < dS then dS = nextK
    end if
    if globals.G_WATER <= 0 and STARVE_HP_T_W > 0 then
        remW = cr_mod(globals.G_ACC_STARVE_W, STARVE_HP_T_W)
        nextW = STARVE_HP_T_W - remW; if nextW <= 0 then nextW = STARVE_HP_T_W
        if nextW < dS then dS = nextW
    end if
    return dS
end function

cr_list_join = function(lst, sep)
  out = ""
  i = 0
  while i < lst.len
    if i > 0 then out = out + sep
    out = out + lst[i]
    i = i + 1
  end while
  return out
end function

// ---------- RNG ----------
CR_HASHMOD = 1000003

cr_srand = function(seed)
  if seed < 0 then seed = 0 - seed
  rnd(seed)
end function

cr_rand = function(n)
  if n <= 1 then return 0
  return floor(rnd() * n)
end function

// ---------- map primitives ----------
cr_set = function(m, x, y, ch)
  row = m[y]
  pre = row[0:x]
  post = row[x + 1:]
  m[y] = pre + ch + post
end function

cr_get = function(m, x, y)
  if x < 0 or x >= LVL_W then return "#"
  if y < 0 or y >= LVL_H then return "#"
  row = m[y]
  return row[x:x + 1]
end function

cr_is_floor = function(m, x, y)
  t = cr_get(m, x, y)
  return t == "." or t == ">" or t == "<"
end function

cr_blank_map = function()
  m = []
  y = 0
  while y < LVL_H
    m.push(cr_repeat("#", LVL_W))
    y = y + 1
  end while
  return m
end function

// ---------- rooms & corridors ----------
cr_room = function(m, x, y, w, h)
  yy = y
  while yy < y + h
    xx = x
    while xx < x + w
      edge = (yy == y or yy == y + h - 1 or xx == x or xx == x + w - 1)
      if edge then cr_set(m, xx, yy, "#") else cr_set(m, xx, yy, ".")
      xx = xx + 1
    end while
    yy = yy + 1
  end while
  return [x + cr_idiv(w, 2), y + cr_idiv(h, 2)]
end function

cr_hcorr = function(m, x1, x2, y)
  if x2 < x1 then
    t = x1
    x1 = x2
    x2 = t
  end if
  x = x1
  while x <= x2
    cr_set(m, x, y, ".")
    x = x + 1
  end while
end function

cr_vcorr = function(m, y1, y2, x)
  if y2 < y1 then
    t = y1
    y1 = y2
    y2 = t
  end if
  y = y1
  while y <= y2
    cr_set(m, x, y, ".")
    y = y + 1
  end while
end function

cr_first_floor_from = function(m, sx, sy)
  y = sy
  while y < LVL_H
    x = sx
    while x < LVL_W
      if cr_is_floor(m, x, y) then return [x, y]
      x = x + 1
    end while
    y = y + 1
  end while
  return [sx, sy]
end function

cr_first_dot_from = function(m, sx, sy)
  y = sy
  while y < LVL_H
    x = sx
    while x < LVL_W
      if cr_get(m, x, y) == "." then return [x, y]
      x = x + 1
    end while
    y = y + 1
  end while
  return [sx, sy]
end function

cr_find_free_dot = function(m, sx, sy, enemies, items, px, py)
  if sx < 0 then sx = 0
  if sy < 0 then sy = 0
  y = sy
  while y < LVL_H
    x = sx
    while x < LVL_W
      if cr_get(m, x, y) == "." then
        if not (x == px and y == py) and cr_enemy_at(enemies, x, y) < 0 then
          taken = 0
          j = 0
          while j < items.len
            it = items[j]
            if it["x"] == x and it["y"] == y then taken = 1
            j = j + 1
          end while
          if not taken then return [x, y]
        end if
      end if
      x = x + 1
    end while
    y = y + 1
  end while
  return [sx, sy]
end function

// ---------- stairs encode ----------
cr_xy_to_str = function(x, y); return str(x) + ":" + str(y); end function

cr_str_to_xy = function(s)
  parts = s.split(":")
  x = 0; y = 0
  if parts.len >= 1 then x = val(parts[0])
  if parts.len >= 2 then y = val(parts[1])
  return [x, y]
end function

cr_list_to_str = function(lst)
  out = ""
  i = 0
  while i < lst.len
    if i > 0 then out = out + ","
    out = out + cr_xy_to_str(lst[i][0], lst[i][1])
    i = i + 1
  end while
  return out
end function

cr_str_to_list = function(s)
  out = []
  if s == null or s == "" then return out
  parts = s.split(","); i = 0
  while i < parts.len
    out.push(cr_str_to_xy(parts[i]))
    i = i + 1
  end while
  return out
end function

// ---------- enemies/items serialize ----------
cr_enemy_to_str = function(e)
  return str(e["x"]) + ":" + str(e["y"]) + ":" + e["g"] + ":" + str(e["hp"]) + ":" + str(e["max"]) + ":" + str(e["dmg"]) + ":" + str(e["t"]) + ":" + e["state"] + ":" + str(e["mv"]) + ":" + str(e["wind"]) + ":" + str(e["rec"]) + ":" + str(e["mx"]) + ":" + str(e["my"])
end function

cr_enemies_to_str = function(lst)
  out = ""
  i = 0
  while i < lst.len
    if i > 0 then out = out + ";"
    out = out + cr_enemy_to_str(lst[i])
    i = i + 1
  end while
  return out
end function

cr_str_to_enemies = function(s)
  out = []
  if s == null or s == "" then return out
  ents = s.split(";"); i = 0
  while i < ents.len
    f = ents[i].split(":")
    if f.len >= 13 then
      e = {"x":val(f[0]), "y":val(f[1]), "g":f[2], "hp":val(f[3]), "max":val(f[4]), "dmg":val(f[5]), "t":val(f[6]), "state":f[7], "mv":val(f[8]), "wind":val(f[9]), "rec":val(f[10]), "mx":val(f[11]), "my":val(f[12])}
      out.push(e)
    end if
    i = i + 1
  end while
  return out
end function

cr_item_to_str = function(it); return str(it["x"]) + ":" + str(it["y"]) + ":" + it["name"]; end function

cr_items_to_str = function(lst)
  out = ""
  i = 0
  while i < lst.len
    if i > 0 then out = out + ";"
    out = out + cr_item_to_str(lst[i])
    i = i + 1
  end while
  return out
end function

cr_str_to_items = function(s)
  out = []
  if s == null or s == "" then return out
  ents = s.split(";"); i = 0
  while i < ents.len
    f = ents[i].split(":")
    if f.len >= 3 then out.push({"x":val(f[0]), "y":val(f[1]), "name":f[2]})
    i = i + 1
  end while
  return out
end function

// ---------- level IDs & seeding ----------
cr_fid = function(floorN, var)
  return "L" + str(floorN) + var
end function

cr_parse_fid = function(fid)
  return [val(fid[1:-1]), fid[-1:]]
end function

cr_char_code = function(ch)
  return ch.code
end function

cr_hash_life = function(life)
  h = 0; i = 0
  while i < life.len
    h = cr_mod(h * 131 + life[i].code, CR_HASHMOD)
    i = i + 1
  end while
  return h
end function

cr_seed_for = function(life, fid)
  // Deterministic per life + floor + variant so each new game is a new world
  p = cr_parse_fid(fid)
  fl = p[0]; vcode = cr_char_code(p[1])
  return cr_mod(cr_hash_life(life) * 4093 + fl * 977 + vcode * 67 + 12345, CR_HASHMOD) + 1
end function

// ---------- generator (seeded) ----------
cr_overlaps = function(ax, ay, aw, ah, bx, by, bw, bh, pad)
  ax0 = ax - pad; ay0 = ay - pad
  ax1 = ax + aw + pad; ay1 = ay + ah + pad
  bx0 = bx - pad; by0 = by - pad
  bx1 = bx + bw + pad; by1 = by + bh + pad
  if ax1 <= bx0 then return 0
  if bx1 <= ax0 then return 0
  if ay1 <= by0 then return 0
  if by1 <= ay0 then return 0
  return 1
end function

cr_make_level_seeded = function(seed, needUp, needDown)
  cr_srand(seed)
  m = cr_blank_map()

  nRooms = 8 + cr_rand(6)
  centers = []; rects = []
  i = 0
  while i < nRooms
    w = 9 + cr_rand(9)
    h = 6 + cr_rand(6)
    tries = 0; placed = 0
    while tries < 80 and placed == 0
      x = 2 + cr_rand(LVL_W - w - 4)
      y = 2 + cr_rand(LVL_H - h - 4)
      ok = 1; j = 0
      while j < rects.len
        r = rects[j]
        if cr_overlaps(x, y, w, h, r[0], r[1], r[2], r[3], 2) then ok = 0
        j = j + 1
      end while
      if ok then
        c = cr_room(m, x, y, w, h)
        centers.push(c); rects.push([x, y, w, h]); placed = 1
      end if
      tries = tries + 1
    end while
    i = i + 1
  end while

  i = 0
  while i + 1 < centers.len
    a = centers[i]; b = centers[i + 1]
    if cr_rand(2) == 0 then
      cr_hcorr(m, a[0], b[0], a[1]); cr_vcorr(m, a[1], b[1], b[0])
    else
      cr_vcorr(m, a[1], b[1], a[0]); cr_hcorr(m, a[0], b[0], b[1])
    end if
    i = i + 1
  end while

  j = 0
  while j < 9
    cx = 2 + cr_rand(LVL_W - 4); cy = 2 + cr_rand(LVL_H - 4)
    if cr_get(m, cx, cy) == "#" then
      if cr_is_floor(m, cx - 1, cy) or cr_is_floor(m, cx + 1, cy) or cr_is_floor(m, cx, cy - 1) or cr_is_floor(m, cx, cy + 1) then
        cr_set(m, cx, cy, ".")
      end if
    end if
    j = j + 1
  end while

  // spawn must be '.' only
  spawn = cr_first_dot_from(m, centers[0][0], centers[0][1])

  // compute counts: start from needs, then fill remaining slots up to 6 with equal chance up/down/none
  upN = needUp
  dnN = needDown
  spare = 6 - (upN + dnN); if spare < 0 then spare = 0
  s = 0
  while s < spare
    r = cr_rand(3)
    if r == 0 then
      upN = upN + 1
    else if r == 1 then
      dnN = dnN + 1
    end if
    s = s + 1
  end while

  ups = []; dns = []

  k = 0
  while k < upN
    cr_srand(seed + 10000 + k * 97)
    base = centers[(k * 2) % centers.len]
    attempts = 0; placed = 0
    while attempts < 60 and placed == 0
      p1 = cr_first_dot_from(m, base[0] + (cr_rand(5) - 2), base[1] + (cr_rand(3) - 1))
      if cr_get(m, p1[0], p1[1]) == "." and not (p1[0] == spawn[0] and p1[1] == spawn[1]) then
        cr_set(m, p1[0], p1[1], "<"); ups.push(p1); placed = 1
      end if
      attempts = attempts + 1
    end while
    if placed == 0 then
      p1 = cr_first_dot_from(m, base[0], base[1])
      if cr_get(m, p1[0], p1[1]) == "." and not (p1[0] == spawn[0] and p1[1] == spawn[1]) then
        cr_set(m, p1[0], p1[1], "<"); ups.push(p1)
      end if
    end if
    k = k + 1
  end while

  k = 0
  while k < dnN
    cr_srand(seed + 20000 + k * 131)
    base2 = centers[(k * 2 + 1) % centers.len]
    attempts = 0; placed = 0
    while attempts < 60 and placed == 0
      p2 = cr_first_dot_from(m, base2[0] + (cr_rand(5) - 2), base2[1] + (cr_rand(3) - 1))
      if cr_get(m, p2[0], p2[1]) == "." and not (p2[0] == spawn[0] and p2[1] == spawn[1]) then
        cr_set(m, p2[0], p2[1], ">"); dns.push(p2); placed = 1
      end if
      attempts = attempts + 1
    end while
    if placed == 0 then
      p2 = cr_first_dot_from(m, base2[0], base2[1])
      if cr_get(m, p2[0], p2[1]) == "." and not (p2[0] == spawn[0] and p2[1] == spawn[1]) then
        cr_set(m, p2[0], p2[1], ">"); dns.push(p2)
      end if
    end if
    k = k + 1
  end while

  return {"map":m, "spawn":spawn, "up":ups, "down":dns}
end function

// ---------- entities / AI ----------
cr_adjacent = function(ax, ay, bx, by)
  dx = ax - bx; if dx < 0 then dx = 0 - dx
  dy = ay - by; if dy < 0 then dy = 0 - dy
  return (dx <= 1 and dy <= 1 and not (dx == 0 and dy == 0))
end function

cr_sgn = function(n); if n > 0 then return 1; if n < 0 then return -1; return 0; end function

cr_step_toward = function(m, enemies, ex, ey, tx, ty)
  dx = cr_sgn(tx - ex); dy = cr_sgn(ty - ey)
  nx = ex + dx; ny = ey + dy
  if (dx != 0 or dy != 0) and cr_is_floor(m, nx, ny) and not cr_enemy_blocked(enemies, nx, ny) then return [nx, ny]
  if dx != 0 then
    nx = ex + dx; ny = ey
    if cr_is_floor(m, nx, ny) and not cr_enemy_blocked(enemies, nx, ny) then return [nx, ny]
  end if
  if dy != 0 then
    nx = ex; ny = ey + dy
    if cr_is_floor(m, nx, ny) and not cr_enemy_blocked(enemies, nx, ny) then return [nx, ny]
  end if
  return [ex, ey]
end function

cr_enemy_at = function(enemies, x, y)
  i = 0
  while i < enemies.len
    e = enemies[i]
    if e["x"] == x and e["y"] == y then return i
    i = i + 1
  end while
  return -1
end function

cr_enemy_blocked = function(enemies, x, y); return cr_enemy_at(enemies, x, y) >= 0; end function

cr_mon_stats = function(g, floorN)
  baseHp = 6 + (floorN - 1)
  baseD = 1 + cr_idiv(floorN, 3)
  mv = 6; wind = 5; rec = 5
  if g == "G" then
    mv = 5; wind = 5; rec = 4
  else if g == "O" then
    mv = 7; wind = 6; rec = 6
    baseHp = baseHp + 3
  else if g == "S" then
    mv = 4; wind = 6; rec = 4
    baseD = baseD + 1
  else if g == "K" then
    mv = 6; wind = 7; rec = 6
    baseHp = baseHp + 2
  else if g == "T" then
    mv = 8; wind = 9; rec = 7
    baseHp = baseHp + 5
    baseD = baseD + 2
  end if
  return {"hp":baseHp, "dmg":baseD, "mv":mv, "wind":wind, "rec":rec}
end function

cr_make_enemy = function(x, y, g, floorN)
  st = cr_mon_stats(g, floorN)
  return {"x":x, "y":y, "g":g, "hp":st["hp"], "max":st["hp"], "dmg":st["dmg"], "t":0, "state":"idle", "mv":st["mv"], "wind":st["wind"], "rec":st["rec"], "mx":x, "my":y}
end function

cr_enemies_process = function(m, enemies, px, py, goalTick, status)
  total = 0
  i = 0
  while i < enemies.len
    e = enemies[i]
    // Only process if enemy needs to act before goalTick
    if e["t"] < goalTick then
      if e["state"] == "wind" then
        if cr_adjacent(e["x"], e["y"], px, py) then
          dmg = e["dmg"]; total = total + dmg
          status = e["g"] + " hits you for " + str(dmg) + "."
        end if
        e["state"] = "idle"; e["t"] = e["t"] + e["rec"]
      else if e["state"] == "mvwind" then
        if cr_adjacent(e["x"], e["y"], px, py) then
          e["state"] = "wind"; e["t"] = e["t"] + e["wind"]
        else
          tx = e["mx"]; ty = e["my"]
          if not (tx == px and ty == py) and cr_is_floor(m, tx, ty) and not cr_enemy_blocked(enemies, tx, ty) then
            e["x"] = tx; e["y"] = ty
          end if
          if cr_adjacent(e["x"], e["y"], px, py) then
            e["state"] = "wind"; e["t"] = e["t"] + e["wind"]
          else
            e["state"] = "idle"; e["t"] = e["t"] + e["mv"]
          end if
        end if
      else
        if cr_adjacent(e["x"], e["y"], px, py) then
          e["state"] = "wind"; e["t"] = e["t"] + e["wind"]
        else
          step = cr_step_toward(m, enemies, e["x"], e["y"], px, py)
          e["mx"] = step[0]; e["my"] = step[1]
          e["state"] = "mvwind"; e["t"] = e["t"] + e["mv"]
        end if
      end if
    end if
    i = i + 1
  end while
  return [status, total]
end function

// ---- REPLACE ----
cr_emit_row = function(leftInner, rightInner, is_last)
  left = cr_pad(leftInner, CR_LEFT_W)
  if is_last == 1 then
    // show prompt on the last line without padding the right pane
    print left + CR_SEP + rightInner
  else
    right = cr_pad(rightInner, CR_RIGHT_W)
    print left + CR_SEP + right
    breakline
  end if
end function


cr_find_index = function(lst, x, y)
  i = 0
  while i < lst.len
    if lst[i][0] == x and lst[i][1] == y then return i
    i = i + 1
  end while
  return -1
end function

cr_items_near = function(items, px, py)
  names = []
  i = 0
  while i < items.len
    it = items[i]
    dx = it["x"] - px; dy = it["y"] - py
    if dx >= -1 and dx <= 1 and dy >= -1 and dy <= 1 then names.push(it["name"])
    i = i + 1
  end while
  out = ""
  j = 0
  while j < names.len
    if j > 0 then out = out + ", "
    out = out + names[j]
    j = j + 1
  end while
  return out
end function

// ---- REPLACE ----
cr_draw = function(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, statusMsg, footer)
  map = level["map"]

  vx = px - cr_idiv(VIEW_W - 1, 2)
  vy = py - cr_idiv(VIEW_H - 1, 2)
  if vx < 0 then vx = 0
  if vy < 0 then vy = 0
  if vx > LVL_W - VIEW_W then vx = LVL_W - VIEW_W
  if vy > LVL_H - VIEW_H then vy = LVL_H - VIEW_H

  // left view
  L = []
  y = 0
  while y < VIEW_H
    row = ""
    x = 0
    while x < VIEW_W
      gx = vx + x; gy = vy + y
      ch = cr_get(map, gx, gy)
      if ch != "#" then
        k = 0
        while k < items.len
          it = items[k]
          if it["x"] == gx and it["y"] == gy then ch = "*"
          k = k + 1
        end while
        ei = cr_enemy_at(enemies, gx, gy)
        if ei >= 0 then ch = enemies[ei]["g"]
      end if
      if gx == px and gy == py then ch = "@"
      row = row + ch
      x = x + 1
    end while
    L.push(row)
    y = y + 1
  end while

  // right panel header
  R = []
  R.push("F" + str(floorN) + var + " " + cr_fmt_clock_fast())
  R.push("HP " + str(hp) + " " + cr_bar10(hp, hpMax))

  // effect lines: +buffs / -debuffs
  pos = []
  neg = []
  // alert
  if G_ALERT <= EXH_T then
    neg.push("-x")        // exhausted
  else if G_ALERT <= TIRED_T then
    neg.push("-t")        // tired
  end if
  
  // kcal
  if G_KCAL <= 0 then
    neg.push("-F")             // starving
  else if G_KCAL < 800 then
    neg.push("-f")             // hungry
  end if
  // water
  if G_WATER <= 0 then
    neg.push("-W")             // dehydrated
  else if G_WATER < 0.5 then
    neg.push("-w")             // thirsty
  end if
  
  R.push(cr_pad(cr_list_join(pos, " "), CR_RIGHT_W))
  R.push(cr_pad(cr_list_join(neg, " "), CR_RIGHT_W))

  // visible enemies sorted by distance
  vis = []
  i = 0
  while i < enemies.len
    e = enemies[i]
    if e["x"] >= vx and e["x"] < vx + VIEW_W and e["y"] >= vy and e["y"] < vy + VIEW_H then
      dx = e["x"] - px; dy = e["y"] - py
      d2 = dx*dx + dy*dy
      vis.push([d2, i])
    end if
    i = i + 1
  end while
  a = 0
  while a < vis.len
    b = a + 1; mi = a
    while b < vis.len
      if vis[b][0] < vis[mi][0] then mi = b
      b = b + 1
    end while
    tmp = vis[a]; vis[a] = vis[mi]; vis[mi] = tmp
    a = a + 1
  end while

  // rows available for enemies before message box and prompt
  rowsForEnemies = VIEW_H - 2 - 2 - CR_MSG_N - 1 
  c = 0
  while c < vis.len and c < rowsForEnemies
    e = enemies[vis[c][1]]
    bang = ""; if e["state"] == "wind" then bang = "!"
    R.push(cr_pad(e["g"] + bang + " " + cr_bar10(e["hp"], e["max"]), CR_RIGHT_W))
    c = c + 1
  end while

  // pad up to start of message box
  while R.len < VIEW_H - CR_MSG_N - 1
    R.push("")
  end while

  // 4-line scrolling message box (bottom-aligned until full)
  while R.len < VIEW_H - CR_MSG_N - 1
    R.push("")
  end while

  count = G_MSGS.len
  visible = count
  if visible > CR_MSG_N then visible = CR_MSG_N
  blanks = CR_MSG_N - visible

  i = 0
  while i < blanks
    R.push("")
    i = i + 1
  end while

  start = count - visible
  j = 0
  while j < visible
    R.push(cr_pad(G_MSGS[start + j], CR_RIGHT_W))
    j = j + 1
  end while


  // prompt on the last line
  while R.len < VIEW_H - 1
    R.push("")
  end while
  R.push(":")

  // draw
  clear
  i = 0
  while i < VIEW_H
    last = 0
    if i == VIEW_H - 1 then last = 1
    cr_emit_row(L[i], R[i], last)
    i = i + 1
  end while
  print tick
end function


cr_draw_loading = function(titleRight, msgCenter)
  L = []
  y = 0
  while y < VIEW_H
    L.push(cr_repeat("#", VIEW_W))
    y = y + 1
  end while
  cy = cr_idiv(VIEW_H, 2)
  cx = cr_idiv(VIEW_W - msgCenter.len, 2)
  if cx < 0 then cx = 0
  row = L[cy]
  pre = row[0:cx]
  post = row[cx + msgCenter.len:]
  L[cy] = pre + msgCenter + post

  R = []; R.push(titleRight)
  while R.len < VIEW_H
    R.push("")
  end while

  clear
  i = 0
  while i < VIEW_H
    last = 0
    if i == VIEW_H - 1 then last = 1
    cr_emit_row(L[i], R[i], last)
    i = i + 1
  end while
end function

// ---------- controls ----------
cr_wait_cost_for_key = function(key)
  if key == "5" then return 5
  if key == "." then return 1
  return 0
end function

cr_show_controls = function(floorN, var, tick)
  clear
  L = []
  L.push("Crawl controls"); L.push("")
  L.push("Move: numpad")
  L.push("  7 8 9")
  L.push("  4 5 6")
  L.push("  1 2 3")
  L.push("Wait: '5'=5, '.'=1")
  L.push("Rest: 's' (heal when not tired)")
  L.push("Sleep: 'S' (must be tired,hold Shift)")
  L.push("Stairs: '>' down, '<' up")
  L.push("Attack: move into enemy")
  L.push("Quit: Q   Help: ?")
  while L.len < VIEW_H
    L.push("")
  end while
  R = []; R.push("F" + str(floorN) + var + " " + cr_fmt_clock_fast())
  while R.len < VIEW_H
    R.push("")
  end while
  i = 0
  while i < VIEW_H
    last = 0
    if i == VIEW_H - 1 then last = 1
    cr_emit_row(L[i], R[i], last)
    i = i + 1
  end while
  k2 = null
  while k2 == null
    k2 = readkey
  end while
end function

cr_key_to_move = function(k)
  if k == "up" then return [0, -1]
  if k == "down" then return [0, 1]
  if k == "left" then return [-1, 0]
  if k == "right" then return [1, 0]
  if k == "8" then return [0, -1]
  if k == "2" then return [0, 1]
  if k == "4" then return [-1, 0]
  if k == "6" then return [1, 0]
  if k == "7" then return [-1, -1]
  if k == "9" then return [1, -1]
  if k == "1" then return [-1, 1]
  if k == "3" then return [1, 1]
  if k == "." or k == "5" then return [0, 0]
  return null
end function

cr_move_cost = function(dx, dy)
  if dx == 0 and dy == 0 then return 5
  if dx != 0 and dy != 0 then return 7
  return 5
end function

cr_attack_cost = function(weap)
  if weap.hasIndex("cost") then return weap["cost"] else return 6
end function

// ---------- level load (no VFS) ----------
cr_load_level = function(life, fid, needUp, needDown)
  pfid = cr_parse_fid(fid); flN = pfid[0]

  // enforce policy: at least 2 up and 2 down; F1 has no ups
  baseUp = 2
  if flN == 1 then baseUp = 0
  baseDown = 2

  upMin = needUp; if upMin < baseUp then upMin = baseUp
  downMin = needDown; if downMin < baseDown then downMin = baseDown

  total = upMin + downMin
  if total > 6 then
    overflow = total - 6
    reducibleUp = upMin - needUp
    r = reducibleUp; if r > overflow then r = overflow
    upMin = upMin - r; overflow = overflow - r
    if overflow > 0 then
      reducibleDown = downMin - needDown
      r2 = reducibleDown; if r2 > overflow then r2 = overflow
      downMin = downMin - r2; overflow = overflow - r2
    end if
  end if

  seed = cr_seed_for(life, fid)
  gen = cr_make_level_seeded(seed, upMin, downMin)

  if flN == 1 then
    k = 0
    while k < gen["up"].len
      u = gen["up"][k]
      cr_set(gen["map"], u[0], u[1], ".")
      k = k + 1
    end while
    gen["up"] = []
  end if

  return {"map":gen["map"], "spawn":gen["spawn"], "up":gen["up"], "down":gen["down"], "enemies":[], "items":[]}
end function

// ---------- population ----------
cr_populate_if_empty = function(map, enemies, items, px, py, floorN, seed)
  if enemies.len == 0 then
    cr_srand(seed + 300000)
    glyphs = ["G","O","S","K","T"]
    nE = 4 + cr_mod(floorN, 4)
    eCount = 0; tries = 0
    while eCount < nE and tries < 800
      ex = 2 + cr_rand(LVL_W - 4)
      ey = 2 + cr_rand(LVL_H - 4)
      if cr_get(map, ex, ey) == "." and not (ex == px and ey == py) then
        if (ex - px)*(ex - px) + (ey - py)*(ey - py) >= 9 then
          if cr_enemy_at(enemies, ex, ey) < 0 then
            g = glyphs[cr_rand(glyphs.len)]
            enemies.push(cr_make_enemy(ex, ey, g, floorN)); eCount = eCount + 1
          end if
        end if
      end if
      tries = tries + 1
    end while
  end if
  if items.len == 0 then
    p1 = cr_find_free_dot(map, px + 1, py, enemies, items, px, py); items.push({"x":p1[0], "y":p1[1], "name":"key"})
    p2 = cr_find_free_dot(map, px + 2, py + 1, enemies, items, px, py); items.push({"x":p2[0], "y":p2[1], "name":"12g"})
    p3 = cr_find_free_dot(map, px - 2, py, enemies, items, px, py); items.push({"x":p3[0], "y":p3[1], "name":"helm"})
  end if
end function

// ---------- link allocation (one-to-one per stair) ----------
cr_alloc_down = function(links, used, life, srcFid, idx)
  p = cr_parse_fid(srcFid); sf = p[0]; sv = p[1]
  df = sf + 1
  dstVar = null
  if idx == 0 then
    if not cr_used_has(used, df, sv) then dstVar = sv
  end if
  if dstVar == null then dstVar = cr_used_next_free(used, df)
  dstFid = cr_fid(df, dstVar)
  cr_links_set_pair(links, srcFid, "down", idx, dstFid)
  cr_used_add(used, df, dstVar)
  return dstFid
end function

cr_alloc_up = function(links, used, life, srcFid, idx)
  p = cr_parse_fid(srcFid); sf = p[0]; sv = p[1]
  if sf <= 1 then return null
  df = sf - 1
  dstVar = null
  if idx == 0 then
    if not cr_used_has(used, df, sv) then dstVar = sv
  end if
  if dstVar == null then dstVar = cr_used_next_free(used, df)
  dstFid = cr_fid(df, dstVar)
  cr_links_set_pair(links, srcFid, "up", idx, dstFid)
  cr_used_add(used, df, dstVar)
  return dstFid
end function

// ---------- game ----------
cr_make_life_id = function(); return "L" + cr_ts_now(); end function

verb_crawl = function(args)
  ck = cr_ckpt_load()

  if ck != null then
    fid = ck["fid"]
    links = ck["links"]; if links == null then links = {}
    used  = ck["used"];  if used  == null then used  = {}
    // per-floor state dicts
    eBy = ck["byE"]; if eBy == null then eBy = {}
    iBy = ck["byI"]; if iBy == null then iBy = {}

    hadLife = 1
    if ck.hasIndex("life") then
      life = ck["life"]
    else
      hadLife = 0
      life = "L" + str(cr_mod(cr_hash_life("FID:" + fid + "|U:" + cr_used_to_str(used) + "|L:" + cr_links_to_str(links)), CR_HASHMOD))
    end if

    p = cr_parse_fid(fid); floorN = p[0]; var = p[1]
    cur = cr_load_level(life, fid, 0, 1)
    map = cur["map"]; upL = cur["up"]; dnL = cur["down"]

    // bootstrap current floor entry if missing
    if not eBy.hasIndex(fid) then eBy[fid] = cr_enemies_to_str(ck["enemies"])
    if not iBy.hasIndex(fid) then iBy[fid] = cr_items_to_str(ck["items"])

    enemies = cr_str_to_enemies(eBy[fid]); items = cr_str_to_items(iBy[fid])

    px = ck["px"]; py = ck["py"]
    if not cr_is_floor(map, px, py) then
      sp = cur["spawn"]; px = sp[0]; py = sp[1]
    end if
    tick = ck["tick"]; hp = ck["hp"]; hpMax = ck["hpMax"]; lvl = ck["lvl"]; xp = ck["xp"]; xpNext = ck["xpNext"]
    if not cr_used_has(used, floorN, var) then cr_used_add(used, floorN, var)
    if hadLife == 0 then
      // write back patched life and per-floor dicts
      cr_ckpt_save(life,fid,px,py,tick,hp,hpMax,lvl,xp,xpNext,enemies,items,links,used,eBy,iBy)
    end if
  else
    life = cr_make_life_id()
    floorN = 1; var = "A"; fid = cr_fid(floorN, var)
    links = {}; used = {}; cr_used_add(used, 1, "A")
    eBy = {}; iBy = {}
    cr_draw_loading("F" + str(floorN) + var, "Loading F" + str(floorN) + var + "...")
    cur = cr_load_level(life, fid, 0, 1)
    map = cur["map"]; upL = cur["up"]; dnL = cur["down"]
    enemies = cur["enemies"]; items = cur["items"]
    sp = cur["spawn"]; px = sp[0]; py = sp[1]
    seed0 = cr_seed_for(life, fid)
    cr_populate_if_empty(map, enemies, items, px, py, floorN, seed0)
    // seed per-floor dicts
    eBy[fid] = cr_enemies_to_str(enemies)
    iBy[fid] = cr_items_to_str(items)
    tick = 0
    hpMax = HP_MAX_DEFAULT; hp = HP_MAX_DEFAULT
    lvl = 1; xp = 0; xpNext = 200
    // start pools
    G_KCAL = 1200; G_WATER = 1.0; G_ALERT = 100
    cr_ckpt_save(life,fid,px,py,tick,hp,hpMax,lvl,xp,xpNext,enemies,items,links,used,eBy,iBy)
  end if
  
  cr_clock_init(tick) // initialize clock after we find out which tick we're on

  weap = {"name":"shiv", "cost":6, "dmg":3}
  status = ""; footer = ""

  level = {"map":map}
  cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)

  running = 1
  while running
    k = readkey
    if k == null then continue
    if k == "?" then
      cr_show_controls(floorN, var, tick)
      cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
      continue
    end if
    if k == "q" then
  // save and quit unless dead
  if hp > 0 then
    eBy[fid] = cr_enemies_to_str(enemies)
    iBy[fid] = cr_items_to_str(items)
    cr_ckpt_save(life,fid,px,py,tick,hp,hpMax,lvl,xp,xpNext,enemies,items,links,used,eBy,iBy)
  else
    cr_ckpt_delete()
  end if
  running = 0
  continue
end if

    if hp <= 0 then
      footer = "You died. Press Q."
      cr_ckpt_delete()
      cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
      continue
    end if

    // stairs down (cost 10)
    if k == ">" then
      if cr_get(map, px, py) == ">" then
        idx = cr_find_index(dnL, px, py)
        if idx >= 0 then
          dstFid = cr_links_get(links, fid, "down", idx)
          if dstFid == null then dstFid = cr_alloc_down(links, used, life, fid, idx)
          // spend time before transition (player commits)
          rS = cr_do_time("act", 10, map, enemies, px, py, tick, hp, status)
          tick = rS[0]; hp = rS[1]; status = rS[2]
          if hp <= 0 then
            footer = "You died. Press Q."
            cr_ckpt_delete()
            cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
            continue
          end if
          // persist current floor entities before leaving
          i = 0
          while i < enemies.len
            if enemies[i]["t"] < tick then enemies[i]["t"] = tick
            i = i + 1
          end while
          eBy[fid] = cr_enemies_to_str(enemies)
          iBy[fid] = cr_items_to_str(items)
          pz = cr_parse_fid(dstFid)
          cr_draw_loading("F" + str(pz[0]) + pz[1], "Loading F" + str(pz[0]) + pz[1] + "...")
          // transition
          floorN = pz[0]; var = pz[1]; fid = dstFid
          cur = cr_load_level(life, fid, idx + 1, 0)
          map = cur["map"]; upL = cur["up"]; dnL = cur["down"]
          if idx < upL.len then
            px = upL[idx][0]; py = upL[idx][1]
          else
            spd = cur["spawn"]; px = spd[0]; py = spd[1]
          end if
          if eBy.hasIndex(fid) then enemies = cr_str_to_enemies(eBy[fid]) else enemies = []
          if iBy.hasIndex(fid) then items = cr_str_to_items(iBy[fid]) else items = []
          if enemies.len == 0 and items.len == 0 then
            seedX = cr_seed_for(life, fid)
            cr_populate_if_empty(map, enemies, items, px, py, floorN, seedX)
            eBy[fid] = cr_enemies_to_str(enemies)
            iBy[fid] = cr_items_to_str(items)
          end if
          // align arrival floor so enemies don't "catch up" from time 0
          i = 0
          while i < enemies.len
            minT = tick + enemies[i]["mv"]
            if enemies[i]["t"] < minT then enemies[i]["t"] = minT
            i = i + 1
          end while
          level = {"map":map}; status = "You descend."; cr_msg_push(status) 
          cr_ckpt_save(life,fid,px,py,tick,hp,hpMax,lvl,xp,xpNext,enemies,items,links,used,eBy,iBy)
          cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
          continue
        else
          status = "No stairs link."; cr_msg_push(status) 
        end if
      else
        status = "No stairs down here."; cr_msg_push(status) 
      end if
      cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
      continue
    end if

    // stairs up (cost 10)
    if k == "<" then
      if cr_get(map, px, py) == "<" then
        idxu = cr_find_index(upL, px, py)
        if idxu >= 0 and floorN > 1 then
          dstFid2 = cr_links_get(links, fid, "up", idxu)
          if dstFid2 == null then dstFid2 = cr_alloc_up(links, used, life, fid, idxu)
          if dstFid2 != null then
            // spend time before transition (player commits)
            rS = cr_do_time("act", 10, map, enemies, px, py, tick, hp, status)
            tick = rS[0]; hp = rS[1]; status = rS[2]
            if hp <= 0 then
              footer = "You died. Press Q."
              cr_ckpt_delete()
              cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
              continue
            end if
            // persist current floor entities before leaving
            i = 0
            while i < enemies.len
              if enemies[i]["t"] < tick then enemies[i]["t"] = tick
              i = i + 1
            end while
            eBy[fid] = cr_enemies_to_str(enemies)
            iBy[fid] = cr_items_to_str(items)
            pz2 = cr_parse_fid(dstFid2)
            cr_draw_loading("F" + str(pz2[0]) + pz2[1], "Loading F" + str(pz2[0]) + pz2[1] + "...")
            // transition
            floorN = pz2[0]; var = pz2[1]; fid = dstFid2
            cur = cr_load_level(life, fid, 0, idxu + 1)
            map = cur["map"]; upL = cur["up"]; dnL = cur["down"]
            if idxu < dnL.len then
              px = dnL[idxu][0]; py = dnL[idxu][1]
            else
              spu = cur["spawn"]; px = spu[0]; py = spu[1]
            end if
            if eBy.hasIndex(fid) then enemies = cr_str_to_enemies(eBy[fid]) else enemies = []
            if iBy.hasIndex(fid) then items = cr_str_to_items(iBy[fid]) else items = []
            if enemies.len == 0 and items.len == 0 then
              seedY = cr_seed_for(life, fid)
              cr_populate_if_empty(map, enemies, items, px, py, floorN, seedY)
              eBy[fid] = cr_enemies_to_str(enemies)
              iBy[fid] = cr_items_to_str(items)
            end if
            // align arrival floor so enemies don't "catch up" from time 0
            i = 0
            while i < enemies.len
              minT = tick + enemies[i]["mv"]
              if enemies[i]["t"] < minT then enemies[i]["t"] = minT
              i = i + 1
            end while
            level = {"map":map}; status = "You ascend."; cr_msg_push(status) 
            cr_ckpt_save(life,fid,px,py,tick,hp,hpMax,lvl,xp,xpNext,enemies,items,links,used,eBy,iBy)
            cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
            continue
          else
            status = "No stairs up link."; cr_msg_push(status) 
          end if
        else
          status = "No stairs up link."; cr_msg_push(status) 
        end if
      else
        status = "No stairs up here."; cr_msg_push(status) 
      end if
      cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
      continue
    end if

    // rest (s) - heal when not tired but wounded
    if k == "s" then
        res = cr_rest(map, enemies, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status)
        tick = res[0]; hp = res[1]; status = res[2]
        cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
        continue
    end if

    // sleep (S) - must be tired
    if k == "S" then
        res = cr_sleep(map, enemies, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status)
        tick = res[0]; hp = res[1]; status = res[2]
        cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
        continue
    end if

    // movement / waits / attacks
    mv = cr_key_to_move(k)
    if mv == null then
      cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
      continue
    end if


    dx = mv[0]; dy = mv[1]
    if dx == 0 and dy == 0 then
      wc = cr_wait_cost_for_key(k); if wc == 0 then wc = 5
      rW = cr_do_time("idle", wc, map, enemies, px, py, tick, hp, status)
      tick = rW[0]; hp = rW[1]; status = rW[2]
    else
      tx = px + dx; ty = py + dy
      ei = cr_enemy_at(enemies, tx, ty)
      if ei >= 0 then
        // commit the attack first
        cost = cr_attack_cost(weap)
        rA = cr_do_time("act", cost, map, enemies, px, py, tick, hp, status)
        tick = rA[0]; hp = rA[1]; status = rA[2]
        // target may have moved or canceled
        ei2 = cr_enemy_at(enemies, tx, ty)
        if ei2 >= 0 and cr_adjacent(px, py, enemies[ei2]["x"], enemies[ei2]["y"]) then
          e = enemies[ei2]; dmg = weap["dmg"]; e["hp"] = e["hp"] - dmg
          if e["hp"] <= 0 then
            enemies.remove(ei2); status = "You kill " + e["g"] + "."; cr_msg_push(status) 
          else
            status = "You hit " + e["g"] + " for " + str(dmg) + "."; cr_msg_push(status) 
          end if
        else
          status = "Your swing hits nothing."; cr_msg_push(status) 
        end if
        cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
        continue
      else
        // commit the move first
        costm = cr_move_cost(dx, dy)
        rM = cr_do_time("act", costm, map, enemies, px, py, tick, hp, status)
        tick = rM[0]; hp = rM[1]; status = rM[2]
        tx2 = px + dx; ty2 = py + dy
        if cr_is_floor(map, tx2, ty2) and cr_enemy_at(enemies, tx2, ty2) < 0 then
          px = tx2; py = ty2; status = ""; cr_msg_push(status) 
        else
          status = "Blocked."; cr_msg_push(status) 
        end if
      end if
    end if
    

    if hp <= 0 then
      footer = "You died. Press Q."
      cr_ckpt_delete()
    end if

    cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, status, footer)
  end while

  // final screen
  cr_draw(level, enemies, items, px, py, floorN, var, tick, hp, hpMax, lvl, xp, xpNext, "Quit.", "")
end function

help_crawl = "start Crawl"
help_crawl_long = "Arrows/numpad. H/V=5, diag=7. '5'=wait5, '.'=wait1. Use '>'/'<' on stairs (cost 10). Floors like F1A. Death deletes save; Q saves and quits."

// --- standalone entry point ---
if not globals.hasIndex("__CrawlStandaloneRun") then
  globals["__CrawlStandaloneRun"] = 1
  bgcolor(15,10,5) // dark brown
  verb_crawl("")
end if
