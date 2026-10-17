# Changelog

## Unreleased

- Flasks, elixirs and potions get compact lines too. `Use: Increases the player's maximum health by 1,200 for 2 hrs. You can only have the effect of one flask at a time. This effect persists through death.` becomes `+1200 health (2 hrs)`, and Elixir of the Mongoose shows `+25 agility (30 min)` and `+2% critical strike (30 min)`.
- That covers flasks of health, mana, spell damage and resistances, elixirs of the primary stats, armor, health, spell damage, a spell school, healing, health or mana every 5 seconds (`+12 HP5 (1 hour)`) and crit, and potions of attack power, spell damage, healing, armor, resistances and attack power or spell damage against a creature type. Durations and stat names are the game's own, in the chosen language: `+1200 salud (2 h)`.
- The cooldown every elixir and flask shares (3 seconds) and every potion shares (2 minutes) is left out. Any other cooldown keeps the original text.
- Healing and mana potions, bandages, and anything whose text says something else (invisibility, water breathing, the Natural flasks' bonus in Hyjal's zones, rage) keep their original text.
- Holding Ctrl switches recipe tooltips at once too, such as AtlasLoot's alchemy and cooking recipes, which show the crafted item's lines. Before, they only switched when the mouse moved to another recipe.
- The settings window has a third tab, Alchemy, with its own color rows in collapsible Attributes, Attack, Defense, Spells and Damage extra sections, and a sample potion.
- After updating, restart the game instead of using `/reload`: the new files are only loaded on a restart.

## v0.5.1 (2026-10-16)

- An equip line with more than one percentage, such as a hit bonus next to a movement speed bonus, keeps its original text instead of losing the second one.
- Food whose cooldown is a minute or an hour keeps its original text, which shows it. Only the 1 second cooldown foods share is left out.
- The class colors no longer stay in the color picker, with it taller than usual, when another addon opens the picker while Stats Trimmer's pick is still open.
- The settings window keeps its tabs on screen at large UI scales, including when dragged to the bottom edge, and adjusts when the UI scale or display size changes.
- The game's texts are those of its current build, 1.60.1.70425. Italian keeps those of 1.60.1.70338, the last build with Italian texts available.
- When the game has no name for a stat, the addon's own English matches the game's: `+1% hit`, `+1% critical strike`.
- After updating, restart the game instead of using `/reload`: the new files are only loaded on a restart.

## v0.5.0 (2026-10-15)

- Food and drink get compact lines too. `Use: Restores 530 health over 24 sec. Must remain seated while eating.` becomes `+530 health (24 sec)`, and a drink `+803 mana (24 sec)`.
- Well Fed buffs show as the stat they give and how long it lasts, `+10 attack power (well fed, 15 min)`, plus `+5% experience gained from kills` when the game shows that bonus. Foods that restore a percentage every second read `+2% health/s (25 sec)`.
- Durations, "well fed" and the stat names are the game's own, in the chosen language: `+530 salud (24 s)`, `+10 poder de ataque (bien alimentado, 15 min)`.
- The settings window has two tabs, named with the game's own words: Combat, with the item sections, the sample item and the spell power setting, and Food & Drink, with rows for health, mana, experience and the stats only Well Fed buffs give (stamina, intellect, strength, agility, spirit and armor), and a sample food. Well Fed attack power, spell damage, healing and crit use their rows in Combat.
- "Reset all colors" is now "Reset these colors": it resets the open tab's colors only.
- Foods whose text says something else keep it as it is: alcohol, fishing and herbalism buffs, buffs that only work in one zone, and a few special foods.
- After updating, restart the game instead of using `/reload`: the new files are only loaded on a restart.

## v0.4.0 (2026-10-14)

- Every kind of compact line has its own color row now, including crit, spell hit, spell crit, dodge, parry, block value, weapon skills, spell damage against a creature type, ranged and feral attack power, and spell penetration.
- The color rows are grouped in Attack, Defense, Spells and Damage extra (the spell schools) sections, titled with the game's own names, and scroll inside the settings window. Click a section's title to collapse or expand it; the preview leaves out collapsed sections, and they stay collapsed next time.
- The settings window sizes itself to its texts in the chosen language: stat names are no longer cut off, and the preview always fits. It grows for languages with longer texts, but never gets smaller than its size in Spanish with every section open. On a screen too small for it (a large UI scale) it is scaled down to fit.
- The color picker shows the colors of the game's classes under the color wheel: hover one to see its class, in the chosen language, and click it to use it.
- The spell power setting says when it applies: "Split spell power into spell damage and spell healing when both values are the same".
- Holding Ctrl also switches other addons' own item tooltips at once, such as AtlasLoot's when it doesn't use the game's tooltip.

## v0.3.1 (2026-10-13)

- Holding Ctrl no longer removes the lines other addons add to an item tooltip, such as AtlasLoot's drop rate or DungeonJournal's source.
- Hidden tooltips that other addons use to read an item's text keep the original text, which is what those addons expect.

## v0.3.0 (2026-10-11)

- Every compact line starts with `+`, like the game's own item comparison: `+10 spell damage` instead of `≤10 spell damage`. The original "up to" is about how much of the bonus each spell gets, not the bonus itself.
- Spell power that adds damage and healing shows as one line, `+26 spell power`, like the game's item comparison, with its own color row. Items with separate damage and healing still get both lines.
- New "Split spell power into spell damage and spell healing" setting, off by default: with it on, spell power shows as `+26 spell damage` and `+26 spell healing`, as in v0.2.0.

## v0.2.0 (2026-10-11)

- The compact lines use the game's own stat names, in lowercase: `≤10 spell damage`, `+1% hit`; `≤10 daño con hechizos` on a Spanish client. MP5 and HP5 stay as they are.
- Spell power that adds damage and healing shows as `≤26 spell damage` and `≤26 spell healing`, like items with separate damage and healing.
- New "Language" setting: your client's language (default) or English, German, Spanish, Mexican Spanish, French, Italian or Portuguese. It changes at once, with no restart.
- The settings window uses the game's own texts in the chosen language: key names, headers, Reset buttons, the color rows and the preview.
- Lines against a creature type are recognized in more languages: capitals like "É" or "Ж" are matched whatever their case, and declined forms through the game's own stat names.
- Some clients name a few "vs creature" stats wrongly (the Spanish client calls spell damage vs beasts "…contra mecánicos"); those names are neither used to recognize lines nor shown.
- After updating, restart the game instead of using `/reload`: the new language data is only loaded on a restart.

## v0.1.0 (2026-10-10)

First release.

- Compact equip lines in item tooltips (bags, character pane, chat links and comparison tooltips), on any client language:
  - spell damage and healing: `≤10 spell power`, `≤30 healing power`;
  - single-school spell damage: `≤32 frost damage`;
  - attack power and spell damage against a creature type: `+6 attack power vs beasts`;
  - mana and health regeneration: `+4 MP5`, `+5 HP5`;
  - attack power, ranged and feral attack power, block value, spell penetration and defense;
  - weapon skills, with one line for several skills of the same value: `+7 axes/daggers/swords skill`;
  - percentage bonuses: block, hit, crit, spell hit, spell crit, dodge and parry, e.g. `+1% block rating`.
- Lines that more than one stat could own keep their original text.
- Hold Ctrl (or Alt, or Shift) to see the original text.
- Settings window with a color per kind of line and a live preview, opened from the minimap button or Options > AddOns > Stats Trimmer.
