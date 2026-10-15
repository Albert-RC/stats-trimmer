# Stats Trimmer

An addon for **World of Warcraft: Forever** that trims the verbose green **Equip:** lines in item tooltips down to short stat lines, so you can compare gear at a glance.

```
Equip: Increases damage and healing done by magical spells and effects by up to 26.
```

becomes

```
+26 spell power
```

Each line shows what the item adds, as in the game's own item comparison. The original "up to" is about how much of that bonus each spell gets, not the bonus itself.

Food and drink get the same treatment: `+530 health (24 sec)`, `+10 attack power (well fed, 15 min)`.

- **Any client language.** Lines are recognized through the game's own item data, not English text. The compact lines use the game's own stat names, in your client's language or another one you pick in the addon.
- **When in doubt, it leaves the line alone.** A line is only rewritten when exactly one of the item's stats can own it.
- **Original text on demand.** Hold Ctrl (or Alt, or Shift) over an item to see the original lines.
- **Your colors.** A color for each kind of line, or one of the game's class colors, with a live preview.

The full list of rewritten lines is in [docs/curseforge/StatsTrimmer.md](docs/curseforge/StatsTrimmer.md).

## Installation

1. Download `StatsTrimmer-<version>.zip` from the [latest release](../../releases/latest).
2. Extract it into the Forever client's `Interface\AddOns` folder. You should end up with `World of Warcraft\_classic_beta_\Interface\AddOns\StatsTrimmer\StatsTrimmer.toc`.
3. Restart the game. Stats Trimmer appears in the AddOns list under User Interface.

## Settings

Click the minimap button, or go to **Options > AddOns > Stats Trimmer**:

- **Show original text while holding:** Ctrl (default), Alt or Shift. Shift also compares items.
- **Language:** your client's (default), or English, German, Spanish, Mexican Spanish, French, Italian or Portuguese. Russian, Korean and Chinese clients offer only English besides their own, since their fonts may lack accented letters. It changes at once, with no restart.
- **Split spell power into spell damage and spell healing when both values are the same:** off by default. Spell power that adds damage and healing shows as one line, `+26 spell power`, like the game's item comparison; with this on, it shows as `+26 spell damage` and `+26 spell healing`.
- **Tabs:** Combat, for items' lines and the spell power setting, and Food & Drink, for food's lines.
- **Colors:** a row for each kind of line, in collapsible Attack, Defense, Spells and Damage extra (spell schools) sections in Combat, each with a swatch and a Reset button, plus "Reset these colors" for the tab. The color picker offers the game's class colors.
- **Preview:** a sample item, or a sample food, that updates as you pick colors.

## Reporting a problem

Please [open an issue](../../issues) with:

- your client language;
- the item name, or a link to it;
- the exact tooltip line (hold Ctrl to see the original text);
- for Lua errors, the BugSack stack trace.

## Development

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the architecture, the tooltip mechanism, the rules and the test setup. The checks before a change:

```
stylua --check .
luacheck .
./scripts/test.ps1
```

CI runs them on every pull request. Merging a version bump into `main` publishes the release.

## License

[MIT](LICENSE). `StatsTrimmer/Locales.lua` holds Blizzard's own game strings, generated from the client data; they aren't covered by the MIT license.
