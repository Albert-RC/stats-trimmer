# Changelog

## Unreleased

- The compact lines use the game's own stat names, in lowercase: `≤10 spell damage`, `+1% hit`; `≤10 daño con hechizos` on a Spanish client. MP5 and HP5 stay as they are.
- Spell power that adds damage and healing shows as `≤26 spell damage` and `≤26 spell healing`, like items with separate damage and healing.
- New "Language" setting: your client's language (default) or English, German, Spanish, Mexican Spanish, French, Italian or Portuguese. It changes at once, with no restart.
- The settings window uses the game's own texts in the chosen language: key names, headers, Reset buttons, the color rows and the preview.
- Lines against a creature type are recognized in more languages: capitals like "É" or "Ж" are matched whatever their case, and declined forms through the game's own stat names.
- Some clients name a few "vs creature" stats wrongly (the Spanish client calls spell damage vs beasts "…contra mecánicos"); those names are neither used to recognize lines nor shown.

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
