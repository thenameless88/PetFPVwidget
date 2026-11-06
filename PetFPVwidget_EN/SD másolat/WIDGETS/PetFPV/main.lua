---------------------------------------------------------------------------
-- PetFPV v1 - pixel-art cat and dog widget, full screen (HelloRadioSky V12 / EdgeTX)
-- Pixel-art version: PNG frames (img/), built on the CatBot / PetFPV v7 logic.
-- Install: SD:/WIDGETS/PetFPV/main.lua + SD:/WIDGETS/PetFPV/img/...
-- (EdgeTX: the widget folder name is limited to 8 characters -> "PetFPV")
--
-- Drawing uses ready-made images (1 lcd.drawBitmap per frame instead of the old
-- ~74 line/circle calls), and only the images of the current mood are kept
-- in memory (the others are released when the mood changes).
---------------------------------------------------------------------------

-- ===== Settings ===========================================================
local CARD = false           -- true: pastel background card behind the pet; false: plain dark background
local DEBUG = false          -- true: memory + number of loaded images in the top left corner
local ARM_ACTIVE_HIGH = true -- true: switch high = ARM, false: switch low = ARM
local TX_LOW_V = 6.8         -- TX battery warning (V)
local CELL_LOW = 3.50        -- RX battery warning (V per cell)
-- =========================================================================

local name = "PetFPV"
local DIR = "/WIDGETS/PetFPV/img/"
local SPR_W, SPR_H = 216, 156          -- sprite size (72x52 grid, 3x scale)
-- Breed option: cats 1 Siamese (blue point), 2 calico, 3 black, 4 British shorthair, 5 ginger tabby
--               dogs   6 golden retriever, 7 husky, 8 harlequin dachshund, 9 corgi, 10 German shepherd
local BREED_DIRS = { "siamese", "calico", "black", "british", "ginger",
                     "golden", "husky", "dachshund", "corgi", "shepherd" }
local FIRST_DOG = 6

local TXTS = {
  EN = {
    breed = "Breed",
    nosig = { "No signal... sleeping", "Turn on the radio!" },
    armed = { "Armed!", "Mind the props!" },
    wLQ   = "Weak link! LQ %d%%",
    wRSSI = "Weak signal! RSSI %d",
    wBat  = "Battery low! %.2fV/cell",
    wTx   = "TX battery low! %.1fV",
    moods = {
      normal  = { "Meow!", "Ready to go", "Just looking..." },
      happy   = { "Love you!", "Purr... purr...", "Great day to fly!" },
      look    = { "Sniffing for signal", "What's over there?", "Hmm?" },
      excited = { "Let's fly!", "Take me high!", "Yay!" },
      sleepy  = { "Long day...", "So sleepy", "Zzz..." },
      meh     = { "Hmm...", "What's up?", "Bored..." },
    },
    dog = {
      normal  = { "Woof!", "Ready to go", "Just looking..." },
      happy   = { "Love you!", "Wag wag wag!", "Great day to fly!" },
    },
  },
}
local TXT = TXTS.EN

-- mood order in the calm state (changes every 4 s)
local MOODS = {
  { m = "normal",  t = "normal" },
  { m = "happy",   t = "happy" },
  { m = "lookl",   t = "look" },
  { m = "lookr",   t = "look" },
  { m = "excited", t = "excited" },
  { m = "meh",     t = "meh" },
  { m = "sleepy",  t = "sleepy" },
}

-- mood -> image frames (img/<breed>/<name>.png)
local ANIM = {
  normal  = { "idle_0", "idle_1", "idle_2", "idle_3" },
  lookl   = { "look_l", "idle_1", "idle_2" },
  lookr   = { "look_r", "idle_1", "idle_2" },
  happy   = { "happy_0", "happy_1" },
  excited = { "excit_0", "excit_1" },
  sleepy  = { "sleep_0", "sleep_1" },
  nosig   = { "sleep_0", "sleep_1" },
  alert   = { "cry_0", "cry_1", "cry_2" },
  armed   = { "armed_0", "armed_1", "armed_2" },
  meh     = { "meh_0", "meh_1" },
}
-- dogs also pant in the calm state (pant_0/1)
local ANIM_DOG = {}
for k, v in pairs(ANIM) do ANIM_DOG[k] = v end
ANIM_DOG.normal = { "idle_0", "idle_1", "idle_2", "idle_3", "pant_0", "pant_1" }

local FX_NAMES = { "heart", "heart_o", "z_s", "z_b", "spark0", "spark1", "drop", "note" }

-- colors
local PAL = {
  bg       = { 28, 31, 38 },
  bgWarn   = { 62, 30, 34 },
  bar      = { 40, 44, 54 },
  text     = { 205, 210, 220 },
  textWarn = { 255, 125, 115 },
  label    = { 135, 142, 158 },
  ok       = { 70, 190, 110 },
  bad      = { 230, 70, 70 },
  none     = { 105, 112, 128 },
  hi       = { 235, 245, 255 },
  safe     = { 40, 130, 80 },
  armOn    = { 215, 55, 55 },
  armDim   = { 140, 40, 45 },
}
-- pastel card per mood
local CARDCOL = {
  normal  = { 236, 222, 170 }, lookl = { 236, 222, 170 }, lookr = { 236, 222, 170 },
  happy   = { 244, 200, 206 },
  excited = { 196, 226, 184 },
  meh     = { 188, 206, 232 },
  sleepy  = { 150, 160, 200 }, nosig = { 120, 128, 160 },
  alert   = { 240, 170, 160 }, alertHi = { 255, 120, 110 },
  armed   = { 232, 150, 150 },
}

local ARM_DEFAULT = 0
do
  local ok, fi = pcall(getFieldInfo, "ch5")
  if ok and fi and fi.id then ARM_DEFAULT = fi.id end
end

-- EdgeTX allows at most 5 widget options
local options = {
  { "LQLow",   VALUE, 70,   0,    100 },
  { "RssiLow", VALUE, -95,  -130, 0   },
  { "Cells",   VALUE, 0,    0,    12  },
  { "ArmSw",   SOURCE, ARM_DEFAULT },
  { TXT.breed, VALUE, 1,    1,    10  },   -- 1-5 cats, 6-10 dogs
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local floor, ceil, max = math.floor, math.ceil, math.max

local function C(c)
  local v = c[4]
  if not v then v = lcd.RGB(c[1], c[2], c[3]); c[4] = v end
  lcd.setColor(CUSTOM_COLOR, v)
  return CUSTOM_COLOR
end

local function rd(names)
  for _, n in ipairs(names) do
    local v = getValue(n)
    if type(v) == "number" and v ~= 0 then return v end
  end
  return nil
end

-- load a PNG; nil if missing or broken
local function loadBmp(path)
  local ok, b = pcall(Bitmap.open, path)
  if not ok or not b then return nil end
  local ok2, bw = pcall(Bitmap.getSize, b)
  if not ok2 or not bw or bw == 0 then return nil end
  return b
end

-- only the images of the current mood stay in memory
local function useSet(wgt, mood)
  if wgt.setMood == mood then return end
  local keep = {}
  for _, n in ipairs(wgt.anim[mood]) do keep[n] = true end
  for n in pairs(wgt.cache) do
    if not keep[n] then wgt.cache[n] = nil end
  end
  wgt.setMood = mood
  collectgarbage()
end

local function frameBmp(wgt, fname)
  local b = wgt.cache[fname]
  if b == nil then
    b = loadBmp(DIR .. wgt.breedDir .. "/" .. fname .. ".png")
    if not b and wgt.breedDir ~= "ginger" then
      b = loadBmp(DIR .. "ginger/" .. fname .. ".png")
    end
    wgt.cache[fname] = b or false   -- false: do not retry on every frame
  end
  return b or nil
end

local function fx(wgt, n, x, y)
  local b = wgt.fx[n]
  if b then lcd.drawBitmap(b, floor(x / 3) * 3, floor(y / 3) * 3) end  -- snapped to the 3 px grid
end

-- pixel card with stepped corners
local function card(x, y, w, h, c)
  local f = C(c)
  lcd.drawFilledRectangle(x + 6, y, w - 12, h, f)
  lcd.drawFilledRectangle(x + 3, y + 3, w - 6, h - 6, f)
  lcd.drawFilledRectangle(x, y + 6, w, h - 12, f)
end

---------------------------------------------------------------------------
-- Widget lifecycle
---------------------------------------------------------------------------
local function setBreed(wgt)
  local i = floor(wgt.options[TXT.breed] or 1)
  wgt.breedDir = BREED_DIRS[i] or "ginger"
  wgt.dog = (i >= FIRST_DOG)
  wgt.anim = wgt.dog and ANIM_DOG or ANIM
  wgt.cache = {}
  wgt.setMood = nil
end

local function create(zone, opts)
  local wgt = { zone = zone, options = opts, lastKey = "", lastBeep = 0, armed = nil, fx = {} }
  setBreed(wgt)
  for _, n in ipairs(FX_NAMES) do wgt.fx[n] = loadBmp(DIR .. "fx/" .. n .. ".png") end
  return wgt
end

local function update(wgt, opts)
  wgt.options = opts
  setBreed(wgt)
  collectgarbage()
end

local function background(wgt) end

---------------------------------------------------------------------------
-- Telemetry (the original CatBot logic)
---------------------------------------------------------------------------
local function evaluate(wgt)
  local o = wgt.options
  local s = {}
  s.lq   = rd({ "RQly" })
  s.rssi = rd({ "1RSS", "2RSS", "RSSI" })
  s.bat  = rd({ "RxBt", "VFAS" })
  s.tx   = getValue("tx-voltage")
  if type(s.tx) ~= "number" or s.tx == 0 then s.tx = nil end

  s.connected = (s.lq ~= nil) or (s.rssi ~= nil)

  if s.bat then
    s.cells = (o.Cells and o.Cells > 0) and o.Cells or max(1, ceil(s.bat / 4.35))
    s.cellV = s.bat / s.cells
  end

  s.lqState   = s.lq and ((s.lq < o.LQLow) and 2 or 1) or 0
  s.rssiState = s.rssi and ((s.rssi < 0 and s.rssi < o.RssiLow) and 2 or 1) or 0
  s.batState  = s.bat and ((s.cellV < CELL_LOW) and 2 or 1) or 0
  s.txState   = s.tx and ((s.tx < TX_LOW_V) and 2 or 1) or 0

  s.arm = nil
  if o.ArmSw and o.ArmSw ~= 0 then
    local v = getValue(o.ArmSw)
    if type(v) == "number" then s.arm = ((v > 0) == ARM_ACTIVE_HIGH) end
  end

  local w = {}
  if s.lqState == 2 then w[#w + 1] = string.format(TXT.wLQ, floor(s.lq)) end
  if s.rssiState == 2 then w[#w + 1] = string.format(TXT.wRSSI, floor(s.rssi)) end
  if s.batState == 2 then w[#w + 1] = string.format(TXT.wBat, s.cellV) end
  if s.txState == 2 then w[#w + 1] = string.format(TXT.wTx, s.tx) end
  s.warns = w
  return s
end

---------------------------------------------------------------------------
-- Animation: which frame, how much offset
---------------------------------------------------------------------------
-- blink: 0 open, 1 half, 2 closed
local function blink(ms, period)
  local p = ms % period
  if p < 70 then return 1 elseif p < 190 then return 2 elseif p < 260 then return 1 end
  return 0
end

-- returns: frame index (in ANIM[mood]), dx, dy
local function pose(mood, ms, dog)
  if mood == "normal" then
    local b = blink(ms, 3300)
    if b > 0 then return b + 1, 0, 0 end
    if (ms % 7100) < 260 then return 4, 0, 0 end        -- ear twitch
    if dog and (ms % 6000) < 2600 then                  -- dog: pants with its tongue out
      return 5 + floor(ms / 260) % 2, 0, 0
    end
    return 1, 0, ((ms % 3000) < 1500) and 0 or 3        -- breathing
  elseif mood == "lookl" or mood == "lookr" then
    local b = blink(ms + 900, 2900)
    if b > 0 then return b + 1, 0, 0 end
    return 1, (mood == "lookl") and -3 or 3, 0
  elseif mood == "meh" then
    if (ms % 3600) < 220 then return 2, 0, 0 end
    return 1, 0, 0
  elseif mood == "happy" then
    local p = ms % 2000
    return (p < 1300) and 1 or 2, 0, (p < 1000) and 0 or -3
  elseif mood == "excited" then
    local p = floor(ms / 240) % 2
    return p + 1, 0, (p == 0) and 0 or -6
  elseif mood == "sleepy" or mood == "nosig" then
    local p = floor(ms / 1400) % 2
    return p + 1, 0, p * 3
  elseif mood == "alert" then
    local p = floor(ms / 130) % 3
    return p + 1, ((floor(ms / 90) % 2) == 0) and -3 or 3, 0
  elseif mood == "armed" then
    local p = ms % 2400
    if p < 110 then return 2, 0, 0 elseif p < 220 then return 3, 0, 0 end
    return 1, 0, 0
  end
  return 1, 0, 0
end

local function drawFx(wgt, mood, ms, x, y)
  if mood == "sleepy" or mood == "nosig" then
    for i = 0, 2 do
      local t = (ms + i * 1000) % 3000
      local k = t / 3000
      fx(wgt, (i == 1) and "z_b" or "z_s", x + 168 + k * 24, y + 66 - k * 48)
    end
  elseif mood == "happy" then
    for i = 0, 1 do
      local t = (ms + i * 1100) % 2200
      local k = t / 2200
      local hx = (i == 0) and (x + 6 - k * 6) or (x + 186 + k * 6)
      fx(wgt, (i == 0) and "heart" or "heart_o", hx, y + 78 - k * 66)
    end
    if (ms % 2000) >= 1300 then fx(wgt, "note", x + 150, y + 90) end
  elseif mood == "excited" then
    local p = floor(ms / 240) % 2
    fx(wgt, p == 0 and "spark0" or "spark1", x + 18, y + 36)
    fx(wgt, p == 0 and "spark1" or "spark0", x + 186, y + 30)
    fx(wgt, p == 0 and "spark1" or "spark0", x + 24, y + 114)
    fx(wgt, p == 0 and "spark0" or "spark1", x + 180, y + 108)
  elseif mood == "alert" then
    for i = 0, 1 do
      local k = ((ms + i * 300) % 600) / 600
      fx(wgt, "drop", ((i == 0) and (x + 63) or (x + 141)), y + 132 + k * 12)
    end
  end
end

---------------------------------------------------------------------------
-- Main drawing
---------------------------------------------------------------------------
local function drawIndicator(x, y, hgt, label, state, txt)
  local c = (state == 2) and PAL.bad or ((state == 1) and PAL.ok or PAL.none)
  lcd.drawFilledCircle(x + 9, floor(y + hgt / 2), 4, C(c))
  lcd.drawText(x + 18, y + 1, label, C(PAL.label) + SMLSIZE)
  lcd.drawText(x + 18, y + 14, txt, C(c) + MIDSIZE)
end

local function refresh(wgt, event, touchState)
  local w, h = wgt.zone.w, wgt.zone.h
  local t = getTime()
  local ms = t * 10
  local s = evaluate(wgt)

  local mood, text
  local hasWarn = #s.warns > 0 and s.connected
  if not s.connected then
    mood = "nosig"
    text = TXT.nosig[floor(ms / 3000) % 2 + 1]
  elseif hasWarn then
    mood = "alert"
    text = s.warns[floor(ms / 2500) % #s.warns + 1]
  elseif s.arm then
    mood = "armed"
    text = TXT.armed[floor(ms / 3000) % 2 + 1]
  else
    local slot = floor(ms / 4000)
    local md = MOODS[(slot * 5 + floor(slot / 7)) % #MOODS + 1]
    mood = md.m
    local tl = (wgt.dog and TXT.dog[md.t]) or TXT.moods[md.t]
    text = tl[(slot * 7) % #tl + 1]
  end

  -- beep on a new warning
  local key = ""
  if s.lqState == 2 then key = key .. "L" end
  if s.rssiState == 2 then key = key .. "R" end
  if s.batState == 2 then key = key .. "B" end
  if s.txState == 2 then key = key .. "T" end
  if s.connected and key ~= "" and key ~= wgt.lastKey and (t - wgt.lastBeep) > 1500 then
    playTone(1200, 120, 60)
    playTone(800, 200, 0)
    wgt.lastBeep = t
  end
  wgt.lastKey = key

  -- tone when ARM / DISARM changes
  if s.arm ~= nil and wgt.armed ~= nil and s.arm ~= wgt.armed then
    if s.arm then playTone(1500, 100, 0) else playTone(700, 120, 0) end
  end
  wgt.armed = s.arm

  -- background
  local flash = hasWarn and (ms % 1000) < 500
  lcd.drawFilledRectangle(0, 0, w, h, C(flash and PAL.bgWarn or PAL.bg))

  local bh = floor(max(34, h * 0.14))
  local sx = floor((w - SPR_W) / 2)
  local sy = 4
  if CARD then
    local cc = CARDCOL[mood] or CARDCOL.normal
    if mood == "alert" and flash then cc = CARDCOL.alertHi end
    card(sx - 12, sy + 6, SPR_W + 24, SPR_H - 2, cc)
  end

  -- pet
  useSet(wgt, mood)
  local fi, dx, dy = pose(mood, ms, wgt.dog)
  local fr = wgt.anim[mood] or wgt.anim.normal
  local bmp = frameBmp(wgt, fr[fi] or fr[1]) or frameBmp(wgt, fr[1])
  if bmp then
    lcd.drawBitmap(bmp, sx + dx, sy + dy)
  else
    lcd.drawText(w / 2, 60, "img/ missing", C(PAL.textWarn) + CENTER)
  end
  drawFx(wgt, mood, ms, sx, sy)

  -- caption
  local big = (w >= 400) and DBLSIZE or MIDSIZE
  lcd.drawText(floor(w / 2), sy + SPR_H + 6, text, C(hasWarn and PAL.textWarn or PAL.text) + CENTER + big)

  -- ARM indicator, top right
  if s.arm ~= nil then
    local pc, label
    if s.arm then
      pc = ((ms % 800) < 400) and PAL.armOn or PAL.armDim
      label = "ARMED"
    else
      pc = PAL.safe
      label = "SAFE"
    end
    lcd.drawFilledRectangle(w - 64, 6, 58, 18, C(pc))
    lcd.drawText(w - 35, 8, label, C(PAL.hi) + CENTER + SMLSIZE)
  end

  -- flashing frame on warning
  if flash then
    local rc = C(PAL.bad)
    for i = 0, 2 do lcd.drawRectangle(i, i, w - 2 * i, h - 2 * i, rc) end
  end

  -- status bar
  local by = h - bh
  lcd.drawFilledRectangle(0, by, w, bh, C(PAL.bar))
  local cw = floor(w / 4)
  drawIndicator(0,      by, bh, "LQ",   s.lqState,   s.lq and (floor(s.lq) .. "%") or "--")
  drawIndicator(cw,     by, bh, "RSSI", s.rssiState, s.rssi and tostring(floor(s.rssi)) or "--")
  drawIndicator(cw * 2, by, bh, "RX",   s.batState,  s.bat and string.format("%.1fV", s.bat) or "--")
  drawIndicator(cw * 3, by, bh, "TX",   s.txState,   s.tx and string.format("%.1fV", s.tx) or "--")

  if DEBUG then
    local n = 0
    for _, b in pairs(wgt.cache) do if b then n = n + 1 end end
    local mem = "?"
    if getAvailableMemory then
      local ok, m = pcall(getAvailableMemory)
      if ok and m then mem = floor(m / 1024) .. "k" end
    end
    lcd.drawText(4, 4, "mem " .. mem .. "  img " .. n .. "  " .. mood, C(PAL.hi) + SMLSIZE)
  end
end

return {
  name = name,
  options = options,
  create = create,
  update = update,
  refresh = refresh,
  background = background,
}
