# Changelog

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
