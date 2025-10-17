# Time and basics

* **SPT** 0.20 s. **TPH** 18,000.
* **HPmax** 100.
* Pools: **kcal**, **water L**, **alert 0–100**.

# Drains (integer ticks)

* **Idle**: −1 kcal/**225**; −0.01 L/**1800**; alert −1/**3000**.
* **Move/Action**: −1 kcal/**72**; −0.01 L/**600**; alert −1/**3000**.
* **Sleep**: −1 kcal/**300**; −0.01 L/**3600**; alert +1/**1440**.

# Regen (always on, but hunger-gated)

* Base: **+1 HP / 100 turns**.
* Sleep: ×2 (→ **+1 / 50**).
* **Requires kcal ≥ 800**. If <800, regen = 0.
* Food/plant multipliers use highest active only.

# Status thresholds (no fluff tiers)

* **Hungry** (kcal < 800): action speed ×0.9, no regen.
* **Starving** (kcal < 300): action speed ×0.75, no regen.
* **Thirsty** (L < 0.5): action speed ×0.9.
* **Dehydrated** (L < 0.25): action speed ×0.8.
* **Very tired** (alert ≤ 40): hit −5%, vision −1.
* **Exhausted** (alert ≤ 20): skip 1 turn/200.
* At 0 kcal or 0 L: −1 HP / **1800** turns (regen can still add back if hunger gate is open).

# Sleep

* **s** to sleep. You cannot sleep if **any monster can see you**.
* Sleep runs to alert = 100 or until interrupted.

# Vision and AI

* Viewport: **43×13** tiles. Player centered when possible.
* **FOV = full rectangle with shadowcasting**:

  * Compute shadowcasting from the player. Clip to the 43×13 box.
  * Opaque: walls, closed doors. Transparent: floors, open doors, water.
  * Reveal “visible”; previously seen stays as “dim memory.”
* **Detection rule**: if you can see them, they can see you. Else they ignore you (idle/wander).
* Monsters path to the last seen location before going idle.

# Actions and costs

* Move: **5** hv / **7** diag.
* Wait 1: Numpad **.** (Idle). Wait 5: Numpad **5** (Idle ×5).
* Pickup **g**: **3**. Eat meat **e**: **5**. Drink **d**: **5**. Consume plant **c**: **5**.
* Swap a slot: **8**. Open/close: **2**. Throw **t**: **5**.
* Fire/aim **f**: weapon-dependent. Reload is part of **f** if empty.
* Bump to melee. Numpad **Enter**: force attack at target tile (range rules apply).
* Stairs: down **> / Numpad***, up **< / Numpad/**.
* Target cycle: Numpad **+ / −**.
* **q** save+quit. **i** inventory. **?** help.

# Hit pipeline

Order: **Dodge → Block → Hit → Pen vs AC → Damage**.

* **Hit% = clamp(5,99, 60 + 2.5·skill − EV%)**.
* **Dodge (EV%)**: naked +20%. Gear adds deltas. Clamp **[−50%, +40%]**. On success: negate.
* **Block**: shield chance 20% wood, 30% metal. On success: negate.
* **Pen vs AC (step)** with Δ=Pen−AC: Δ≥0 → 100%; Δ=−1 → 50%; Δ=−2 → 25%; Δ≤−3 → 0%.

# Armor and EV

AC from slots (max **10** total): Chest 0–4, Helm 0–2, Legs 0–2, Boots 0–1, Gloves 0–1.
Examples (AC / EVΔ):

* Cloth 1 / +0% ; Leather 2 / −4% ; Bone 3 / −8% ; Scrap plate 4 / −14%
* Cap 1 / −2% ; Metal helm 2 / −6%
* Pants 1 / −3% ; Greaves 2 / −6%
* Boots 1 / −3% ; Gloves 1 / −2%
  Outfits: Naked **AC0 EV+20%**; Light leather **AC3–4 EV +5…0%**; Hides/bone **AC5–6 EV −10…−15%**; Scrap plate **AC7–9 EV −20…−40%**; **Steel suit AC10 EV −50%**.

# Weapon balance (equal niches)

Skill 0 **BaseTurns**; **MinTurns = ceil(0.5·BaseTurns)**;
**EffectiveTurns = ceil(BaseTurns − (BaseTurns−MinTurns)·skill/10)**.
Per-hit damage is fixed; skill raises DPS via speed. **Spear/Pike reach 2** (may attack at range 1 or 2; use +/− then Enter).

**Melee**

* **Dagger**: Pen **7**, **3t**, dmg **4**. Niche: high pen, low dmg, fastest.
* **Sword 1H**: Pen **5**, **4t**, dmg **6**. Niche: balanced.
* **Axe 1H**: Pen **4**, **5t**, dmg **9**. Niche: armor-light mauler.
* **Spear**: Pen **6**, **5t**, dmg **7**, **reach 2**. Niche: spacing control.
* **Greatclub**: Pen **3**, **5t**, dmg **10**. Niche: jelly/soft targets.
* **Greatsword**: Pen **6**, **6t**, dmg **11**. Niche: heavy generalist.
* **Warhammer/Maul**: Pen **8**, **6t**, dmg **10**. Niche: anti-armor.
* **Pike**: Pen **7**, **6t**, dmg **9**, **reach 2**. Niche: long reach, good pen.
* **Fist**: Pen **0**, **3t**, dmg **3**.

**Ranged**

* **Throw rock**: Pen **2**, **5t**, dmg **3**, range 5, −1 dmg per tile beyond 3 (min 1).
* **Bow**: Pen **4**, **11t**, dmg **6**. Ammo: arrows.
* **Sling**: Pen **3**, **10t**, dmg **4**. Ammo: stones.
* **Light xbow**: Pen **6**, **18t**, dmg **10**. Ammo: bolts.
* **Heavy xbow**: Pen **8**, **30t**, dmg **12**. Ammo: bolts.
* **Junk musket**: **Best**. Pen **10**, fire **5t**, reload **100t**, dmg **30**.

  * **Ammo rule**: needs **1 stone shot + 1 fire pod** in inventory. Firing consumes both. No misfires.

# Food: raw meat only

* **Butcher b** on corpse. Time: Small **25t**, Medium **75t**, Large **150t**.
* Yields: Small **1**, Medium **2**, Large **4** meat.
* **Nutrition**: **300 kcal** per meat.
* **Rot** per stack:

  * Fresh **0–180,000t** → 300 kcal
  * Stale **180,001–360,000t** → 150 kcal
  * Spoiled **>360,000t** → unsafe: apply **Sick** 3,000t (−1 HP/300t, hit −5%), 0 kcal
* Eating meat **e**: **5t**. Regen still needs kcal ≥ 800.

# Water

* **d** to drink. Each use: **0.25 L**, **5t**.
* Carriers: waterskin 0.5 L, gourd 1.0 L. Refill at sources (10t per 0.5 L).

# Plants (raw, ground/cave names; no calories)

Consume with **c** (5t). Only top regen multiplier applies.

* **Moss tuft**: regen ×3 for **900t**.
* **White cap**: +20 HP over **200t**; hit −5% for **600t**.
* **Root**: +15 alert instantly.
* **Reed bulb**: +0.25 L instantly; move ×0.9 for **300t**.
* **Brown cap**: resist bleed/poison **3600t**.
* **Spore puff**: −10 alert instantly; +10% EV **1200t**.
* **Fire pod**: explosive plant used as musket propellant; also throwable for **8t**, radius-1 blast **8 dmg**, Pen **5**. Throwing consumes the pod (rock not required).

# Inventory (weight/volume, not slots)

* Capacity: **20 bulk**. Worn items do not count. Over cap: cannot pick up.
* Examples (bulk each unless noted):

  * Dagger 1, Sword 3, Axe 3, Spear 4, Greatsword 6, Pike 6, Warhammer 5, Club 2, Shield 4, Bow 3, L.Xbow 4, H.Xbow 5, Musket 5
  * Arrows 1 per **10**, Bolts 1 per **10**, Stones 1 per **5**, **Fire pods 1 per 5**
  * Meat **1 each** (any stage)
  * Waterskin full **1**, Gourd full **2**
  * Plants (non–fire pod) **1 per 10**

# Creatures and materials

Natural armor tags map to AC bands:

* **Skinless 0**, **Skin 1–2**, **Fur 2–3**, **Thick hide 3–5**, **Scale 4–6**, **Bone 5–7**, **Shell 6–9**, **Scrap metal 7–9**, **Steel 10**.
  EV by body plan: small +10–20%; large −10–30%.

# Shields

* Wood: 20% block. Metal: 30% block. Blocking negates damage. No time cost.

# Target UI

* On hover/target list:

  * `S [#####.....]+` → species glyph, 10-tick bar, `+` means **you** are targeting it.
  * `S![#####.....]+` → `!` means it is actively attacking **you**.
* Bar fills with `#` proportional to HP (round to 10 segments).

# Messages

* “You are hungry/starving/thirsty/dehydrated/very tired/exhausted.”
* “You can’t sleep while visible.”
* “Fresh meat is going stale.” / “Your meat has spoiled.”
* Plant/meat effects: concise icon timers. No cosmetic messages without effect.

# Tuning knobs

* Regen interval **100**; sleep regen **×2**.
* Hunger gate **800 kcal**. Meat **300 kcal**. Rot cutoffs **180k / 360k** turns.
* Hit base **60%**; skill step **+2.5%**; EV clamp **−50..+40**.
* Pen vs AC steps as above.
* Inventory cap **20 bulk**; adjust per item as needed.

Language: Miniscript within the PLC of the video game No Time by Lost in days studios
Below does NOT include everything you can do. Miniscript is fully available and you are encouraged to browse the miniscript docs to double check syntax and capabilities. if you discover ANY limitations not listed here, you must report them to me for confirmation before continuing, if I approve, they will be added to this document.

goal: MUD is a barebones unix-like shell. you supply .mud files, MUD can import them and use the verbs and scripts that the .mud files have.
Files: MUD.eee -> only required file, entry point, as minimal as possible MUD.vfs -> append-only virtual file system for MUD to use as persistent storage. Everything that MUD needs to save between sessions lives here. read from the bottom up, first match (which will be the latest) wins. MUD.eee creates this if it does not exist shell.mud -> unix commands/scripts multiverse.mud -> my game commands/scripts crab.mud -> my cheat commands/scripts x.mud, y.mud, z.mud, etc -> anyone can make their own mud pack

## hot tips (most important part)
* in-line if statements cannot have end if at the end of them, end if is only for blocks. `if a then b = c` is valid. `if a then b = c end if` is invalid.
* if you have a line like `if a then b = c; d = e` it compiles, but what it actually means is: 
  ```
  if a then
    b = c
  end if
  d = e
  ```
* there are no directories on the PLC. files are listed by creation date with no way of sorting
* expect users to kill the script whenever they feel like it because leaving the terminal in any way kills the script
* you must yield when taking input otherwise readline will never ask for another input and will keep reusing the first one
* #include lines can fail if pasted. Theory is that hidden non-ASCII (BOM/zero-width/curly quotes) breaks import. Manually typing the line fixes it.
* connectgate() needs a tiny more than `wait 2`, it can miss the frame. 
* factional waits are allowed ie `wait 2.1`
* rnd(seed) seeds the global RNG
* rnd() then yields deterministic floats in [0,1).
* s.len → length.
* s[a:b] → slice [a..b). Slices are zero-based and end-exclusive. Negative indices count from the end. Example: `s[-2:]` gets last two chars.
* s.split(sep) → list of fields.
* str(x) ↔ val(s) for number↔string. They are explicit
* Dictionaries are unordered
* If you access a key thaat doesn't exist it throws `Runtime error Key Not Found: '<key>' not found in map`
* Re-seeding mid-function restarts the stream
* `readkey` returns `null` until a key is pressed

list of No Time cheat intrinsics: https://no-time.fandom.com/wiki/Cococrab_Mode
## PLC Intrinsics:
    https://no-time.fandom.com/wiki/PLC_Intrinsics
# Drive and File Operations
    setlabel(name: string) - Renames a local drive (HVD). Only works on external drive
    delete(name: string) - Deletes a specified file. prints an output, returns nothing
    create(name: string) - Creates an empty file with the specified name. prints an output, returns nothing
    rename(name: string, newname: string) - Renames a specified file. prints it's own output, returns nothing
    copy(name: string) - Copies a file into a buffer.
    paste() - Pastes the copied file, creating a duplicate.
    edit(name: string) - Opens the file for editing. - opens in-game text editor, kills script when ran
    cd() - Allows switching between PLC or disk. `cd "Item_HoloDisk(Clone)"` is the only way to swap to disk, and `cd "FPSController"` is the only way to swap to local

# File Read/Write Operations

    readfile(name: string, line: int) - Reads a specific line from a file. 0 is first line
    countlines(name: string) - Returns the number of lines in a file. returns 0 and prints a message when file doesn't exist. files will always have at least one empty line at minimum, so empty files return 1. if a file has three lines, it returns 3.
    writeline(name: string, line: int, content: string) - Writes or replaces a line in a file. 0 is first line. `writeline(file, i, text)` replaces or creates that exact line. Clearing trailing old content requires writing `""` to those extra lines.
    find(name: string) - Searches for a file by name. - returns -1 if it doesn't exist otherwise returns file index (0-39 int) files are always sorted by creation date. use find when you want to test if a file exists.

# Time Travel Functions

    cardiag() - Prints the time car's statistics.
    cantravel(year: int) -> int - Returns 1 if travel to the specified year is possible, otherwise 0.
    getyear() -> int - Returns the current in-game year.
    getmonth() -> int - Returns the current in-game month.
    getday() -> int - Returns the current in-game day.
    gethour() -> int - Returns the current in-game hour (24-hour format).
    getminute() -> int - Returns the current in-game minute.
    timegraph() - Opens the time graph program. kills the script when ran
    getweekday(year: int, month: int, day: int) -> int - Returns the the weekday in numbers 0-6 (0 is sunday)
    getcurrentweekday() -> int - Returns the current in-game minute the weekday in numbers 0-6 (0 is sunday)

# Space/Time Gate Functions

    dialgate(address: string) - Dials a connected gate if in range.
    connectgate() - Attempts to connect to a nearby gate before dialing. Must `wait 1` before dialing
    gatereadings() - Returns gate readings (temperature, planet details) after dialing.
    gettemperature() -> int - Returns the ambient temperature in Fahrenheit.
    recalltimegate() - Spawns a remote teleport portal to return to the safe house after using a time gate.

# Hacking Functions

    openperipheral() - Toggles a connected peripheral (doors, shield gates, etc.).
    closeperipheral() - Closes a connected peripheral.
    SetFactionMimCore() - (Act 4 only) Used for taking over Mim's computer core.

## hello world script written by the game's dev
//This shows the basic functions of 
//mini script

// you can also insert an #include command can insert a file to be compiled along with the rest of the code
// an example would be #include filename.eee
// the code snippet is placed and compiled in the main program where the #include line is located

print "hello world!"
wait 2
breakline
print "....breaking line..."
breakline
wait 2
print "....lemme draw some for you..."
wait 2
clear
 
b = 0
while b < 10
	b = b + 1
	//row column opacy
	draw 1,1,b*20
end while
breakline
 
b = 0
while b < 10
	b = b + 1
	//row column opacy
	draw 1,1,b*20
end while
breakline

print "nice isn't it?"
wait 4
clear

print "Shall I reboot the PLC? Y/N"

yes = readline
//readline waits for an input line entered
//readkey waits for an input button pressed
//getkey only checks if a key has been pressed and does not wait

print "you said: "+yes

if yes.lower == "y" then
  clear
  breakline
  print "Ok Bye am restarting PLC..."
  wait 2
  reboot
else
  clear
  print "Ok then no..."
end if
