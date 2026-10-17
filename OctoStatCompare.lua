--[[
  OctoStatCompare  -  by JackedCow
  Target: WoW 1.12.1 client (Lua 5.0) / OctoWoW

  Hold SHIFT over an equippable item: a stat comparison against the item(s)
  you currently have equipped is appended to the tooltip.

  Lua 5.0 rules respected in this file:
    - no '#' length operator (table.getn), no '%' operator, no string.match,
      no string.gmatch (string.gfind), no select(), no '...' (fixed args)
    - globals 'this', 'event', 'arg1' used in script handlers
    - tooltip hooking by replacing methods (no HookScript / hooksecurefunc)
]]

local DEFAULTS = { enabled = 1, zero = 0, effects = 0, debug = 0, inline = 0 }

local function Opt(k)
  local db = OctoStatCompareDB
  if type(db) == "table" and db[k] ~= nil then return db[k] end
  return DEFAULTS[k]
end

local function SetOpt(k, v)
  if type(OctoStatCompareDB) ~= "table" then OctoStatCompareDB = {} end
  OctoStatCompareDB[k] = v
end

local function Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99OctoStatCompare:|r " .. msg)
  end
end

local function Debug(msg)
  if Opt("debug") == 1 then Print("|cff999999" .. msg .. "|r") end
end

local function Cap(s)
  return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

local function Clean(s)
  s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end

----------------------------------------------------------------------
-- Stat registry (key -> label / unit).  Order here = display order.
----------------------------------------------------------------------
local STAT, ORDER, ORDER_N = {}, {}, 0

local function Def(key, label, pct, dec)
  ORDER_N = ORDER_N + 1
  ORDER[key] = ORDER_N
  STAT[key] = { label = label, pct = pct, dec = dec }
end

Def("ARMOR", "Armor")
Def("BLOCKVAL", "Block Value")
Def("STR", "Strength")
Def("AGI", "Agility")
Def("STA", "Stamina")
Def("INT", "Intellect")
Def("SPI", "Spirit")
Def("HEALTH", "Health")
Def("MANA", "Mana")
Def("AP", "Attack Power")
Def("RAP", "Ranged Attack Power")
Def("SPELLDMG", "Spell Damage")
Def("HEAL", "Healing")
Def("SD_ARCANE", "Arcane Spell Damage")
Def("SD_FIRE", "Fire Spell Damage")
Def("SD_FROST", "Frost Spell Damage")
Def("SD_HOLY", "Holy Spell Damage")
Def("SD_NATURE", "Nature Spell Damage")
Def("SD_SHADOW", "Shadow Spell Damage")
Def("DEF", "Defense")
Def("HIT", "Hit Chance", true)
Def("SPELLHIT", "Spell Hit Chance", true)
Def("CRIT", "Critical Strike Chance", true)
Def("SPELLCRIT", "Spell Critical Strike Chance", true)
Def("HASTE", "Attack Speed (Haste)", true)
Def("DODGE", "Dodge Chance", true)
Def("PARRY", "Parry Chance", true)
Def("BLOCK", "Block Chance", true)
Def("MP5", "Mana per 5 sec")
Def("HP5", "Health per 5 sec")
Def("WEAPDMG", "Weapon Damage")
Def("DPS", "Damage per Second", nil, true)
Def("RES_ARCANE", "Arcane Resistance")
Def("RES_FIRE", "Fire Resistance")
Def("RES_FROST", "Frost Resistance")
Def("RES_HOLY", "Holy Resistance")
Def("RES_NATURE", "Nature Resistance")
Def("RES_SHADOW", "Shadow Resistance")

local ALLRES = { "RES_ARCANE", "RES_FIRE", "RES_FROST", "RES_HOLY", "RES_NATURE", "RES_SHADOW" }

-- "+N <name>" lines  (name already lower-case)
local NAME_MAP = {
  ["strength"] = "STR", ["agility"] = "AGI", ["stamina"] = "STA",
  ["intellect"] = "INT", ["spirit"] = "SPI",
  ["armor"] = "ARMOR", ["defense"] = "DEF",
  ["health"] = "HEALTH", ["mana"] = "MANA",
  ["attack power"] = "AP", ["ranged attack power"] = "RAP",
  ["spell damage"] = "SPELLDMG",
  ["healing"] = "HEAL", ["healing spells"] = "HEAL",
  ["damage"] = "WEAPDMG", ["weapon damage"] = "WEAPDMG",
  ["mana per 5 sec"] = "MP5", ["mana every 5 sec"] = "MP5",
  ["mana per 5 seconds"] = "MP5", ["mana every 5 seconds"] = "MP5",
  ["health per 5 sec"] = "HP5", ["health every 5 sec"] = "HP5",
  ["health per 5 seconds"] = "HP5", ["health every 5 seconds"] = "HP5",
  ["arcane resistance"] = "RES_ARCANE", ["fire resistance"] = "RES_FIRE",
  ["frost resistance"] = "RES_FROST", ["holy resistance"] = "RES_HOLY",
  ["nature resistance"] = "RES_NATURE", ["shadow resistance"] = "RES_SHADOW",
  ["arcane spell damage"] = "SD_ARCANE", ["arcane damage"] = "SD_ARCANE",
  ["fire spell damage"] = "SD_FIRE", ["fire damage"] = "SD_FIRE",
  ["frost spell damage"] = "SD_FROST", ["frost damage"] = "SD_FROST",
  ["holy spell damage"] = "SD_HOLY", ["holy damage"] = "SD_HOLY",
  ["nature spell damage"] = "SD_NATURE", ["nature damage"] = "SD_NATURE",
  ["shadow spell damage"] = "SD_SHADOW", ["shadow damage"] = "SD_SHADOW",
  ["all resistances"] = ALLRES, ["all resistance"] = ALLRES,
  ["spell power"] = { "SPELLDMG", "HEAL" },
  ["damage and healing spells"] = { "SPELLDMG", "HEAL" },
  ["spell damage and healing"] = { "SPELLDMG", "HEAL" },
}

local SCHOOL = {
  arcane = "SD_ARCANE", fire = "SD_FIRE", frost = "SD_FROST",
  holy = "SD_HOLY", nature = "SD_NATURE", shadow = "SD_SHADOW",
}

----------------------------------------------------------------------
-- Item record helpers
----------------------------------------------------------------------
local function AddStat(item, key, val)
  item.stats[key] = (item.stats[key] or 0) + val
end

local function AddEffect(item, key, text)
  if not item.effects[key] then
    item.effects[key] = text
    item.nEffects = item.nEffects + 1
  end
end

local function MapName(item, name, val)
  local v = NAME_MAP[name]
  if not v then return false end
  if type(v) == "table" then
    local i
    for i = 1, table.getn(v) do AddStat(item, v[i], val) end
  else
    AddStat(item, v, val)
  end
  return true
end

----------------------------------------------------------------------
-- Explicit patterns (lower-case body, trailing '.' removed, "equip: " removed)
-- Handler returns false when it declines the line.
----------------------------------------------------------------------
local PATTERNS = {}

local function PF(pat, fn)
  table.insert(PATTERNS, { pat, fn })
end

local function P(pat, key)
  PF(pat, function(it, a) AddStat(it, key, tonumber(a)) end)
end

P("^(%d+) armor$", "ARMOR")
P("^(%d+) block$", "BLOCKVAL")
PF("^%(([%d%.]+) damage per second%)$", function(it, a)
  local v = tonumber(a)
  if not v then return false end
  AddStat(it, "DPS", v)
end)

P("^increases attack power by (%d+)$", "AP")
P("^increases your attack power by (%d+)$", "AP")
P("^increases ranged attack power by (%d+)$", "RAP")

PF("^increases damage and healing done by magical spells and effects by up to (%d+)$", function(it, a)
  AddStat(it, "SPELLDMG", tonumber(a))
  AddStat(it, "HEAL", tonumber(a))
end)
PF("^increases healing done by up to (%d+) and damage done by up to (%d+) for all magical spells and effects$", function(it, h, d)
  AddStat(it, "HEAL", tonumber(h))
  AddStat(it, "SPELLDMG", tonumber(d))
end)
P("^increases healing done by spells and effects by up to (%d+)$", "HEAL")
PF("^increases damage done by (%a+) spells and effects by up to (%d+)$", function(it, school, a)
  if school == "magical" then
    AddStat(it, "SPELLDMG", tonumber(a))
  elseif SCHOOL[school] then
    AddStat(it, SCHOOL[school], tonumber(a))
  else
    return false
  end
end)

P("^improves your chance to get a critical strike by (%d+)%%$", "CRIT")
P("^improves your chance to get a critical strike with spells by (%d+)%%$", "SPELLCRIT")
P("^improves your chance to hit by (%d+)%%$", "HIT")
P("^improves your chance to hit with spells by (%d+)%%$", "SPELLHIT")
P("^increases your chance to dodge an attack by (%d+)%%$", "DODGE")
P("^increases your chance to parry an attack by (%d+)%%$", "PARRY")
P("^increases your chance to block attacks with a shield by (%d+)%%$", "BLOCK")
P("^increases the block value of your shield by (%d+)$", "BLOCKVAL")
P("^increases your attack speed by (%d+)%%$", "HASTE")
P("^increases attack speed by (%d+)%%$", "HASTE")

P("^restores (%d+) mana per 5 sec$", "MP5")
P("^restores (%d+) mana per 5 seconds$", "MP5")
P("^restores (%d+) mana every 5 sec$", "MP5")
P("^restores (%d+) mana every 5 seconds$", "MP5")
P("^restores (%d+) health per 5 sec$", "HP5")
P("^restores (%d+) health per 5 seconds$", "HP5")
P("^restores (%d+) health every 5 sec$", "HP5")
P("^restores (%d+) health every 5 seconds$", "HP5")

P("^increased defense %+(%d+)$", "DEF")
P("^increases defense by (%d+)$", "DEF")
P("^increases your defense by (%d+)$", "DEF")

local function RatingHandler(it, name, a)
  local key = "rating:" .. name
  if not STAT[key] then STAT[key] = { label = Cap(name) .. " Rating" } end
  AddStat(it, key, tonumber(a))
end
PF("^improves your (.+) rating by (%d+)$", RatingHandler)
PF("^improves (.+) rating by (%d+)$", RatingHandler)
PF("^increases your (.+) rating by (%d+)$", RatingHandler)
PF("^increases (.+) rating by (%d+)$", RatingHandler)

-- weapon skills: "Increased Swords +4"
PF("^increased (.+) %+(%d+)$", function(it, name, a)
  local key = "skill:" .. name
  if not STAT[key] then STAT[key] = { label = Cap(name) .. " Skill" } end
  AddStat(it, key, tonumber(a))
end)

local function ParseBody(item, body)
  local s, e, sign, num, name = string.find(body, "^([%+%-])(%d+) (.+)$")
  if s then
    local v = tonumber(num)
    if sign == "-" then v = -v end
    if MapName(item, name, v) then return true end
  end
  local i
  for i = 1, table.getn(PATTERNS) do
    local entry = PATTERNS[i]
    local s2, e2, c1, c2 = string.find(body, entry[1])
    if s2 then
      if entry[2](item, c1, c2) ~= false then return true end
    end
  end
  return false
end

-- Generic fallback: exactly one number -> comparable stat keyed by the line
-- template (number replaced by '#').  0 or 2+ numbers -> "effect" (not compared).
local function ParseGeneric(item, body, orig)
  local count, last = 0, nil
  local num
  for num in string.gfind(body, "%d+%.?%d*") do
    count = count + 1
    last = num
  end
  local val = last and tonumber(last)
  if count ~= 1 or not val then
    AddEffect(item, body, orig)
    return
  end
  if string.find(body, "^%-") then val = -val end
  local template = string.gsub(body, "%d+%.?%d*", "#")
  template = string.gsub(template, "^[%+%-]#", "#")
  local key = "g:" .. template
  if not STAT[key] then
    local label = string.gsub(orig, "^[Ee]quip:%s*", "")
    label = string.gsub(label, "%.$", "")
    label = string.gsub(label, "%d+%.?%d*", "#")
    label = string.gsub(label, "^[%+%-]#", "#")
    label = string.gsub(label, "^#%%?%s*", "")
    local pct = nil
    if string.find(template, "#%%") then
      pct = true
      label = string.gsub(label, "#%%", "#")
    end
    STAT[key] = { label = Cap(label), pct = pct }
  end
  AddStat(item, key, val)
end

local function ParseLine(item, text, green)
  local lt = string.lower(text)
  lt = string.gsub(lt, "%.$", "")

  -- set bonuses are not part of the plain item: ignore
  if string.find(lt, "^%(%d+%) set:") or string.find(lt, "^set:") then return end

  if string.find(lt, "^use:") or string.find(lt, "^chance on hit:") then
    AddEffect(item, lt, text)
    return
  end

  local body = lt
  local isEquip = false
  local s, e = string.find(lt, "^equip:%s*")
  if s then
    body = string.sub(lt, e + 1)
    isEquip = true
  end

  if ParseBody(item, body) then return end

  if isEquip or green or string.find(body, "^[%+%-]%d+ ") then
    ParseGeneric(item, body, text)
  end
end

----------------------------------------------------------------------
-- Slot detection from tooltip text (client-language: English)
----------------------------------------------------------------------
local SLOT_TEXT = {
  ["Head"] = "HEAD", ["Neck"] = "NECK", ["Shoulder"] = "SHOULDER", ["Back"] = "BACK",
  ["Chest"] = "CHEST", ["Shirt"] = "SHIRT", ["Tabard"] = "TABARD", ["Wrist"] = "WRIST",
  ["Hands"] = "HANDS", ["Waist"] = "WAIST", ["Legs"] = "LEGS", ["Feet"] = "FEET",
  ["Finger"] = "FINGER", ["Trinket"] = "TRINKET",
  ["One-Hand"] = "1H", ["Main Hand"] = "MH", ["Off Hand"] = "OH",
  ["Held In Off-hand"] = "HELD", ["Held in Off-hand"] = "HELD",
  ["Two-Hand"] = "2H",
  ["Ranged"] = "RANGED", ["Thrown"] = "RANGED", ["Relic"] = "RANGED",
}
local RANGED_WORD = {
  ["Bow"] = true, ["Gun"] = true, ["Crossbow"] = true, ["Wand"] = true,
  ["Thrown"] = true, ["Idol"] = true, ["Libram"] = true, ["Totem"] = true,
}

local function IsWeapon(kind)
  return kind == "1H" or kind == "MH" or kind == "OH" or kind == "2H"
end

local function ParseTooltip(prefix, tt)
  local item = { stats = {}, effects = {}, nEffects = 0 }
  local n = tt:NumLines()
  item.lines = n
  local i
  for i = 1, n do
    local L = getglobal(prefix .. "TextLeft" .. i)
    local R = getglobal(prefix .. "TextRight" .. i)
    local lt = L and L:GetText()
    local rt = R and R:GetText()
    if lt and lt ~= "" then
      lt = Clean(lt)
      if rt then rt = Clean(rt) end
      if i == 1 then
        item.name = lt
      else
        if not item.kind then
          if SLOT_TEXT[lt] then
            item.kind = SLOT_TEXT[lt]
            item.slotRight = rt
          elseif RANGED_WORD[lt] or (rt and RANGED_WORD[rt]) then
            item.kind = "RANGED"
          end
        end
        local r, g, b = L:GetTextColor()
        local green = false
        if r and g and b and g > 0.8 and r < 0.4 and b < 0.4 then green = true end
        ParseLine(item, lt, green)
      end
    end
  end
  if item.kind == "OH" and item.slotRight == "Shield" then item.kind = "SHIELD" end
  return item
end

----------------------------------------------------------------------
-- Equipped item scanning (hidden tooltip)
----------------------------------------------------------------------
local SCAN_NAME = "OctoStatCompareScanTip"
local scanTip

local function GetScanTip()
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", SCAN_NAME, nil, "GameTooltipTemplate")
  end
  return scanTip
end

-- returns nil (empty slot) or item record (item.unreadable = true if no data)
local function ScanEquipped(slot)
  if not GetInventoryItemTexture("player", slot) then return nil end
  local tt = GetScanTip()
  tt:SetOwner(UIParent, "ANCHOR_NONE")
  tt:ClearLines()
  tt:SetInventoryItem("player", slot)
  local item
  if tt:NumLines() < 1 then
    item = { stats = {}, effects = {}, nEffects = 0, unreadable = true }
  else
    item = ParseTooltip(SCAN_NAME, tt)
  end
  tt:Hide()
  return item
end

----------------------------------------------------------------------
-- Comparison targets
----------------------------------------------------------------------
local SIMPLE = {
  HEAD = 1, NECK = 2, SHOULDER = 3, SHIRT = 4, CHEST = 5, WAIST = 6, LEGS = 7,
  FEET = 8, WRIST = 9, HANDS = 10, BACK = 15, RANGED = 18, TABARD = 19,
}
local PAIR = { FINGER = { 11, 12 }, TRINKET = { 13, 14 } }

local function BuildGroups(kind, getEq)
  local groups = {}
  if SIMPLE[kind] then
    table.insert(groups, { slots = { SIMPLE[kind] } })
  elseif PAIR[kind] then
    local nm = "ring"
    if kind == "TRINKET" then nm = "trinket" end
    table.insert(groups, { slots = { PAIR[kind][1] }, note = nm .. " slot 1" })
    table.insert(groups, { slots = { PAIR[kind][2] }, note = nm .. " slot 2" })
  elseif kind == "2H" then
    table.insert(groups, { slots = { 16, 17 }, note = "two-hander replaces main hand + off hand" })
  elseif kind == "MH" then
    table.insert(groups, { slots = { 16 }, note = "main hand" })
  elseif kind == "1H" then
    local mh = getEq(16)
    local oh = getEq(17)
    if mh and mh.kind == "2H" then
      table.insert(groups, { slots = { 16 }, note = "replaces your two-hander" })
    else
      table.insert(groups, { slots = { 16 }, note = "main hand" })
      if oh and oh.kind and IsWeapon(oh.kind) then
        table.insert(groups, { slots = { 17 }, note = "off hand (dual wield)" })
      end
    end
  elseif kind == "OH" or kind == "SHIELD" or kind == "HELD" then
    local mh = getEq(16)
    if mh and mh.kind == "2H" then
      table.insert(groups, { slots = { 16, 17 }, note = "replaces your two-hander" })
    else
      table.insert(groups, { slots = { 17 }, note = "off hand" })
    end
  end
  return groups
end

local function Combine(group, getEq)
  local res = { stats = {}, effects = {}, nEffects = 0, names = {}, empty = true,
                unreadable = false, weapons = 0 }
  local i
  for i = 1, table.getn(group.slots) do
    local it = getEq(group.slots[i])
    if it then
      res.empty = false
      if it.unreadable then
        res.unreadable = true
      else
        table.insert(res.names, it.name or "?")
        local k, v
        for k, v in pairs(it.stats) do
          res.stats[k] = (res.stats[k] or 0) + v
        end
        for k, v in pairs(it.effects) do
          if not res.effects[k] then
            res.effects[k] = v
            res.nEffects = res.nEffects + 1
          end
        end
        if it.kind and IsWeapon(it.kind) then res.weapons = res.weapons + 1 end
      end
    end
  end
  return res
end

----------------------------------------------------------------------
-- Diff + formatting
----------------------------------------------------------------------
local function Fmt(d, def)
  local s
  if (def and def.dec) or d ~= math.floor(d) then
    s = string.format("%+.1f", d)
  else
    s = string.format("%+d", d)
  end
  if def and def.pct then s = s .. "%" end
  return s
end

local function KeyLess(a, b)
  local oa = ORDER[a] or 1000
  local ob = ORDER[b] or 1000
  if oa ~= ob then return oa < ob end
  local la = STAT[a] and STAT[a].label or a
  local lb = STAT[b] and STAT[b].label or b
  if la ~= lb then return la < lb end
  return a < b
end

local function BuildDiffLines(cand, eq, dropDps)
  local keys, seen = {}, {}
  local k
  for k in pairs(cand.stats) do seen[k] = true; table.insert(keys, k) end
  for k in pairs(eq.stats) do
    if not seen[k] then seen[k] = true; table.insert(keys, k) end
  end
  table.sort(keys, KeyLess)

  local lines = {}
  local i
  for i = 1, table.getn(keys) do
    k = keys[i]
    if not (dropDps and k == "DPS") then
      local def = STAT[k]
      local d = (cand.stats[k] or 0) - (eq.stats[k] or 0)
      local eps = 0.0001
      if def and def.dec then eps = 0.05 end
      local label = def and def.label or k
      if d > eps or d < -eps then
        local r, g, b = 0.1, 1, 0.1
        if d < 0 then r, g, b = 1, 0.15, 0.15 end
        table.insert(lines, { Fmt(d, def) .. " " .. label, r, g, b })
      elseif Opt("zero") == 1 then
        table.insert(lines, { "0 " .. label, 0.55, 0.55, 0.55 })
      end
    end
  end
  return lines
end

local function EffectsDiffer(a, b)
  local k
  for k in pairs(a.effects) do if not b.effects[k] then return true end end
  for k in pairs(b.effects) do if not a.effects[k] then return true end end
  return false
end

----------------------------------------------------------------------
-- Append comparison to a tooltip
----------------------------------------------------------------------
local HEADER = "Compared with equipped:"          -- inline mode
local HEADER_SHOP = "Stat change if swapped:"       -- equipped-item tooltip mode

local function AlreadyHas(tt, text)
  local name = tt:GetName()
  local i
  for i = 1, tt:NumLines() do
    local L = getglobal(name .. "TextLeft" .. i)
    local t = L and L:GetText()
    if t and string.find(t, text, 1, true) then return true end
  end
  return false
end

local function MakeGetEq()
  local cache = {}
  return function(slot)
    if cache[slot] == nil then
      local it = ScanEquipped(slot)
      if it then cache[slot] = it else cache[slot] = false end
    end
    return cache[slot]
  end
end

-- adds header + diff lines for one comparison group to tooltip tt
local function AddBlock(tt, cand, eq, head)
  tt:AddLine(head, 1, 1, 1, 1)
  if eq.unreadable then return end
  local dropDps = false
  if eq.weapons >= 2 or not IsWeapon(cand.kind) then dropDps = true end
  local lines = BuildDiffLines(cand, eq, dropDps)
  local li
  for li = 1, table.getn(lines) do
    local l = lines[li]
    tt:AddLine(l[1], l[2], l[3], l[4])
  end
  if table.getn(lines) == 0 then
    tt:AddLine("No stat differences", 0.6, 0.6, 0.6)
  end
  if dropDps and eq.stats["DPS"] then
    tt:AddLine("DPS not compared (not a like-for-like weapon swap)", 0.6, 0.6, 0.6)
  end
  if EffectsDiffer(cand, eq) then
    tt:AddLine("Use/proc/special effects differ (not compared)", 0.6, 0.6, 0.6)
    if Opt("effects") == 1 then
      local k, v
      for k, v in pairs(cand.effects) do
        if not eq.effects[k] then tt:AddLine("  + " .. v, 0.7, 0.7, 0.9, 1) end
      end
      for k, v in pairs(eq.effects) do
        if not cand.effects[k] then tt:AddLine("  - " .. v, 0.9, 0.7, 0.7, 1) end
      end
    end
  end
end

local function DebugCand(cand)
  if Opt("debug") ~= 1 then return end
  local k, v
  Debug("candidate '" .. tostring(cand.name) .. "' kind=" .. tostring(cand.kind) ..
        " effects=" .. cand.nEffects)
  for k, v in pairs(cand.stats) do Debug("  " .. k .. " = " .. v) end
  for k, v in pairs(cand.effects) do Debug("  effect: " .. v) end
end

-- INLINE mode: comparison appended to the hovered item's own tooltip
local function AppendInline(tt)
  if Opt("enabled") ~= 1 then return end
  if not IsShiftKeyDown() then return end
  if tt:NumLines() < 2 then return end
  if AlreadyHas(tt, HEADER) then return end

  local cand = ParseTooltip(tt:GetName(), tt)
  DebugCand(cand)
  if not cand.kind then return end
  local getEq = MakeGetEq()
  local groups = BuildGroups(cand.kind, getEq)
  if table.getn(groups) == 0 then return end

  tt:AddLine(" ")
  local gi
  for gi = 1, table.getn(groups) do
    local group = groups[gi]
    local eq = Combine(group, getEq)
    local head = "|cffffd200" .. HEADER .. "|r "
    if eq.unreadable then
      head = head .. "|cffff8080(could not read equipped item)|r"
    elseif eq.empty then
      head = head .. "|cffffffff(empty slot)|r"
    else
      head = head .. "|cffffffff" .. table.concat(eq.names, " + ") .. "|r"
    end
    if group.note then head = head .. " |cff999999(" .. group.note .. ")|r" end
    AddBlock(tt, cand, eq, head)
  end
  tt:Show()
end

-- EQUIPPED mode: comparison appended to Blizzard's side-by-side tooltip of
-- the item you are wearing (ShoppingTooltip1/2), for the slot it shows.
local function SourceTip()
  if GameTooltip:IsShown() and GameTooltip:NumLines() >= 2 then return GameTooltip end
  if ItemRefTooltip and ItemRefTooltip:IsShown() and ItemRefTooltip:NumLines() >= 2 then
    return ItemRefTooltip
  end
  return nil
end

local STATE = {}

local function OnShopSet(tt, unit, slot)
  if Opt("enabled") ~= 1 then return end
  if unit ~= "player" or not slot then return end
  if not IsShiftKeyDown() then return end
  if tt:NumLines() < 2 then return end
  if AlreadyHas(tt, HEADER_SHOP) then return end

  local src = SourceTip()
  if not src then return end
  local sst = STATE[src:GetName()]
  if sst and sst.own then return end        -- hovering own equipped gear

  local cand = ParseTooltip(src:GetName(), src)
  DebugCand(cand)
  if not cand.kind then return end

  local getEq = MakeGetEq()
  local groups = BuildGroups(cand.kind, getEq)
  local gi, si
  for gi = 1, table.getn(groups) do
    local group = groups[gi]
    local has = false
    local primary = nil
    for si = 1, table.getn(group.slots) do
      if group.slots[si] == slot then has = true end
      if not primary and getEq(group.slots[si]) then primary = group.slots[si] end
    end
    if has then
      tt:AddLine(" ")
      if primary == slot then
        local eq = Combine(group, getEq)
        local head = "|cffffd200" .. HEADER_SHOP .. "|r |cffffffff" ..
                     tostring(cand.name) .. "|r"
        if group.note then head = head .. " |cff999999(" .. group.note .. ")|r" end
        AddBlock(tt, cand, eq, head)
      else
        tt:AddLine("|cffffd200" .. HEADER_SHOP .. "|r |cff999999(included in the combined comparison on the other tooltip)|r", 1, 1, 1, 1)
      end
      tt:Show()
      return
    end
  end
end

local function InlineMode()
  return Opt("inline") == 1 or not ShoppingTooltip1
end

----------------------------------------------------------------------
-- Tooltip hooks (1.12: replace the Set* methods)
----------------------------------------------------------------------
local TIPS = {}

local function OnItemSet(tt, method, a1, a2, a3, a4, a5)
  local name = tt:GetName()
  if not name then return end
  local st = STATE[name]
  if not st then st = {}; STATE[name] = st end

  st.own = false
  if method == "SetInventoryItem" and a1 == "player" then st.own = true end

  if not InlineMode() then st.redo = nil; return end

  local L1 = getglobal(name .. "TextLeft1")
  st.line1 = L1 and L1:GetText()
  st.redo = function() tt[method](tt, a1, a2, a3, a4, a5) end

  if st.own then return end
  AppendInline(tt)
end

local function InstallHook(tt, method)
  local orig = tt[method]
  if type(orig) ~= "function" then return end
  tt[method] = function(self, a1, a2, a3, a4, a5)
    local r1, r2, r3 = orig(self, a1, a2, a3, a4, a5)
    OnItemSet(self, method, a1, a2, a3, a4, a5)
    return r1, r2, r3
  end
end

local METHODS = {
  "SetBagItem", "SetInventoryItem", "SetLootItem", "SetHyperlink",
  "SetAuctionItem", "SetAuctionSellItem", "SetMerchantItem", "SetBuybackItem",
  "SetTradeSkillItem", "SetCraftItem", "SetQuestItem", "SetQuestLogItem",
  "SetTradePlayerItem", "SetTradeTargetItem", "SetInboxItem", "SetSendMailItem",
  "SetLootRollItem",
}

local function InstallTooltip(tt)
  if not tt or not tt:GetName() then return end
  local i
  for i = 1, table.getn(METHODS) do InstallHook(tt, METHODS[i]) end

  local oldHide = tt:GetScript("OnHide")
  tt:SetScript("OnHide", function()
    local st = STATE[this:GetName()]
    if st then st.redo = nil end
    if oldHide then oldHide() end
  end)
  table.insert(TIPS, tt)
end

-- Re-run the last Set* call (rebuilds the tooltip from scratch, so lines can
-- never be duplicated) when the Shift state changes.
local function RedoTooltip(tt)
  local name = tt:GetName()
  local st = STATE[name]
  if not st or not st.redo then return end
  if not tt:IsShown() then st.redo = nil; return end
  local L1 = getglobal(name .. "TextLeft1")
  if not L1 or L1:GetText() ~= st.line1 then st.redo = nil; return end
  st.redo()
end

local poll = CreateFrame("Frame")
local acc, lastShift = 0, nil
poll:SetScript("OnUpdate", function()
  acc = acc + (arg1 or 0)
  if acc < 0.05 then return end
  acc = 0
  local s = nil
  if IsShiftKeyDown() then s = 1 end
  if s ~= lastShift then
    lastShift = s
    local i
    for i = 1, table.getn(TIPS) do
      if TIPS[i]:IsShown() then RedoTooltip(TIPS[i]) end
    end
  end
end)

InstallTooltip(GameTooltip)
if ItemRefTooltip then InstallTooltip(ItemRefTooltip) end

local function InstallShopHook(tt)
  if not tt then return end
  local orig = tt.SetInventoryItem
  if type(orig) ~= "function" then return end
  tt.SetInventoryItem = function(self, a1, a2, a3)
    local r1, r2, r3 = orig(self, a1, a2, a3)
    if not InlineMode() then OnShopSet(self, a1, a2) end
    return r1, r2, r3
  end
end
InstallShopHook(ShoppingTooltip1)
InstallShopHook(ShoppingTooltip2)

----------------------------------------------------------------------
-- Init + slash commands
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:SetScript("OnEvent", function()
  if type(OctoStatCompareDB) ~= "table" then OctoStatCompareDB = {} end
  Print("loaded. Hold Shift over an item to compare. /osc for options.")
end)

local function OnOff(v) if v == 1 then return "on" end return "off" end

local function Toggle(k)
  if Opt(k) == 1 then SetOpt(k, 0) else SetOpt(k, 1) end
  Print(k .. " is now " .. OnOff(Opt(k)))
end

SLASH_OCTOSTATCOMPARE1 = "/osc"
SLASH_OCTOSTATCOMPARE2 = "/octostatcompare"
SlashCmdList["OCTOSTATCOMPARE"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "on" then SetOpt("enabled", 1); Print("enabled")
  elseif msg == "off" then SetOpt("enabled", 0); Print("disabled")
  elseif msg == "zero" then Toggle("zero")
  elseif msg == "effects" then Toggle("effects")
  elseif msg == "debug" then Toggle("debug")
  elseif msg == "inline" then Toggle("inline")
  else
    Print("commands: /osc on | off | zero | effects | debug | inline")
    Print("enabled=" .. OnOff(Opt("enabled")) .. "  zero=" .. OnOff(Opt("zero")) ..
          "  effects=" .. OnOff(Opt("effects")) .. "  debug=" .. OnOff(Opt("debug")) ..
          "  inline=" .. OnOff(Opt("inline")))
  end
end
