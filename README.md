# Stats Trimmer

An addon for **World of Warcraft: Forever** that trims the verbose green **Equip:** lines in item tooltips down to short stat lines, so you can compare gear at a glance.

```
Equip: Increases damage and healing done by magical spells and effects by up to 26.
```

becomes

```
≤26 spell power
≤26 healing power
```

`≤` means "up to", just like the original wording.

- **Any client language.** Lines are recognized through the game's own item data, not English text. The compact lines are always in English.
- **When in doubt, it leaves the line alone.** A line is only rewritten when exactly one of the item's stats can own it.
- **Original text on demand.** Hold Ctrl (or Alt, or Shift) over an item to see the original lines.
- **Your colors.** A color for each kind of line, with a live preview.

The full list of rewritten lines is in [docs/curseforge/StatsTrimmer.md](docs/curseforge/StatsTrimmer.md).

## Installation

1. Download `StatsTrimmer-<version>.zip` from the [latest release](../../releases/latest).
2. Extract it into the Forever client's `Interface\AddOns` folder. You should end up with `World of Warcraft\_classic_beta_\Interface\AddOns\StatsTrimmer\StatsTrimmer.toc`.
3. Restart the game. Stats Trimmer appears in the AddOns list under User Interface.

## Settings

Click the minimap button, or go to **Options > AddOns > Stats Trimmer**:

- **Show original text while holding:** Ctrl (default), Alt or Shift. Shift also compares items.
- **Colors:** a swatch for each kind of line, with a Reset button per row and "Reset all colors".
- **Preview:** a sample tooltip that updates as you pick colors.

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

[MIT](LICENSE)
