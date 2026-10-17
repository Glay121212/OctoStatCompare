# OctoStatCompare
OctoStatCompare 1.0.0 - by JackedCow
For WoW 1.12.1 / OctoWoW

INSTALL
 1. Close WoW.
 2. Extract the ZIP into your WoW folder (the one containing WoW.exe), so you get:
      <WoW>\Interface\AddOns\OctoStatCompare\OctoStatCompare.toc
      <WoW>\Interface\AddOns\OctoStatCompare\OctoStatCompare.lua
 3. Start WoW, on the character screen click "AddOns" and make sure OctoStatCompare is enabled
    (tick "Load out of date AddOns" if it is listed as out of date).

USE
 Hold SHIFT over any equippable item (bags, bank, vendor, loot, auction, trade, mail, quest
 rewards, chat links, another player's inspected gear). Shift can be pressed before or after
 hovering. Green = better, red = worse.

 /osc on | off   enable/disable
 /osc zero       also list stats that are equal (grey 0 lines)
 /osc effects    list Use/proc/special lines that differ
 /osc debug      print what was parsed (slot, stats, unparsed effects) to chat

COMPARISON RULES
 - Single-slot items compare against that slot only.
 - Rings / trinkets: two blocks, one per slot (empty slot = everything counts as gain).
 - One-hand weapon: vs main hand; also vs off hand if you have a weapon there (dual wield).
 - Main Hand-only weapon: vs main hand.  Off hand / shield / held-in-off-hand: vs off hand.
 - Two-hander: vs main hand + off hand combined (it replaces both).
 - Off hand item while a two-hander is equipped: vs the two-hander (it would be unequipped).
 - Ranged / thrown / wand / relic: vs the ranged slot.
 - DPS is only compared for like-for-like weapon swaps (not vs dual-wield or shields).

LIMITATIONS
 - English client only (slot names and "Equip:" wording are matched as English text).
 - Class/proficiency restrictions are not checked (it will compare a plate item for a cloth wearer).
 - Stats are compared as listed: "Spell Damage" and school damage (e.g. Fire) are separate lines;
   "+X All Resistances" is split into the six resistances; "Spell Power" (custom) counts as
   Spell Damage + Healing; ratings (e.g. "hit rating") are never mixed with % stats.
 - Unknown Equip: lines with exactly one number are compared by their exact wording (shown with
   the number replaced by #). Lines with zero or several numbers, and Use:/Chance on hit: effects,
   cannot be compared numerically; the addon says "effects differ (not compared)" instead of
   guessing.
 - Set bonuses are ignored. Weapon speed is not compared. Conditional bonuses are separate stats.
 - Gem/socket systems and Haste only appear if the server prints them as normal tooltip text.
 - Blizzard's own side-by-side comparison tooltips may also appear; that is unrelated.
