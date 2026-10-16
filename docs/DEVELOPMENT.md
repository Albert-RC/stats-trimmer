# Development guide

Stats Trimmer is an addon for Blizzard's official **WoW: Forever** client (`## Interface: 16001`, Lua 5.1). Forever runs on the modern addon framework: its API matches neither 1.12-era vanilla tutorials nor Retail, so knowledge from either is unreliable here.

All code, comments, in-game strings and docs are written in English.

## What it does

It rewrites the verbose green **Equip:** lines of item tooltips into compact ones:

```
Equip: Increases damage and healing done by magical spells and effects by up to 2.
```

becomes

```
+2 spell power
```

or, with the spell power split setting, two lines: `+2 spell damage` and `+2 spell healing`.

It also rewrites the **Use:** line of food and drink:

```
Use: Restores 530 health over 24 sec.  Must remain seated while eating. If you spend at least 10 sec eating, you will become well fed and gain 10 Attack Power for 15 min. Additionally, experience gained from kills is increased by 5%. (1 Sec Cooldown)
```

becomes

```
+530 health (24 sec)
+10 attack power (well fed, 15 min)
+5% experience gained from kills
```

- Every compact line starts with `+`: it shows what the item adds to the stat, like Blizzard's item comparison. The original "up to" describes spell coefficients (how much of the bonus each spell gets), not the stat itself.
- The original line must be recognized in **every client locale**, so nothing may match English text only.
- The compact lines use Blizzard's own stat names, in lowercase, in the language chosen in the addon (the client's by default): `+10 daño con hechizos` on esES, `+10 spell damage` in English. MP5 and HP5 read the same in every language. See [Localization](#localization).

## Repository layout

- `StatsTrimmer/`: the addon. Only this folder reaches the game. Its name, the `.toc` base name and the folder name in `Interface\AddOns` must match exactly.
- `spec/`: unit tests (`*_spec.lua`), the test runner, helpers and the fake WoW API.
- `scripts/`: `test.ps1`, `coverage.ps1`, `package.ps1`, `update-locales.ps1` and `update-foods.ps1`.
- `docs/`: this guide and the CurseForge description (`docs/curseforge/StatsTrimmer.md`).
- `.github/workflows/`: CI and releases (see [CI and releases](#ci-and-releases)).
- Root tooling: `.luacheckrc`, `.luacov`, `stylua.toml`, `.vscode/`.

## Setup

1. Link the addon folder into the Forever client with a directory junction (in `cmd`), so edits reach the game directly:

   ```bat
   mklink /J "<WoW>\_classic_beta_\Interface\AddOns\StatsTrimmer" "<repo>\StatsTrimmer"
   ```

   `rmdir "<WoW>\_classic_beta_\Interface\AddOns\StatsTrimmer"` removes the link without touching the code. Other folders under `<WoW>` (`_retail_`, `_classic_era_`, …) are different game versions.
2. Tools:
   - [StyLua](https://github.com/JohnnyMorganz/StyLua), for formatting.
   - [Luacheck](https://github.com/lunarmodules/luacheck), for static analysis.
   - LuaJIT 2.1 (`winget install --id DEVCOM.LuaJIT -e`), to run the tests.
   - [LuaCov](https://github.com/lunarmodules/luacov) 0.17.0 (pure Lua) for coverage. Copy its `src/` folder to `%LOCALAPPDATA%\Programs\luacov`, or pass another one with `coverage.ps1 -LuaCov <folder>`.
3. VS Code extensions: `sumneko.lua`, `ketho.wow-api`, `JohnnyMorganz.stylua` (see `.vscode/extensions.json`).
4. In game: [BugSack](https://github.com/funkydude/BugSack) and !BugGrabber capture Lua errors.

## Commands

```
stylua --check .        # format check (stylua . to fix)
luacheck .              # static analysis; luacheck <file> for one file
./scripts/test.ps1      # unit tests (spec/*_spec.lua)
./scripts/coverage.ps1  # tests under LuaCov; fails if StatsTrimmer/ line coverage < 85%
./scripts/package.ps1   # release zip and notes for the .toc version, in .release/
luajit spec/runner.lua spec/rules_spec.lua   # a single spec file
```

Workflow: edit, run the checks above, then test in game.
- `/reload` picks up edits to existing Lua files.
- A full client restart is needed for a new addon, files added to or renamed in the `.toc`, and `.toc` metadata changes.
- Debugging: BugSack (`/bugsack`), `/console scriptErrors 1`, `/etrace`, `/fstack`, `/run print(GetBuildInfo())`.

## Architecture

SavedVariables: `StatsTrimmerDB`, available as `ns.db` after `ADDON_LOADED`. Files share state through the addon namespace (`local _, ns = ...`, functions exported as `ns.Name`), never through globals. Pure files (no WoW API) are kept apart so they can be unit tested.

The `.toc` loads these files in order:

- `Util.lua`: pure text helpers.
  - `NumbersMatch(text, a, b)` checks that a line's numbers are exactly `{a, b}` and that the line has no percentage.
  - `GetOnlyPercent(text)` reads a lone percentage: the line's only number, and its only percentage.
  - `FormatLine(value, percent, name)` writes a compact line's text (`+10 spell damage`, `+1% golpe`).
  - `FormatDetails(details, GetText)` writes what follows a food line's stat name: `/s` for a rate, then ` (24 sec)` or ` (well fed, 15 min)`, with the words `GetText` gives (see [Food and drink](#food-and-drink)).
  - `CompactLine(kind, value, name, stats, percent, details)` builds a compact line (see `Rules.lua` below).
- `Config.lua`: pure settings model.
  - `ns.SETTINGS_TABS`: the window's tabs, in order, each `{ key, labelGlobal, label, spellPowerSplit }`: combat (`COMBAT`, "Combate") and food and drink (`MINIMAP_TRACKING_VENDOR_FOOD`, "Comida y bebida"). `spellPowerSplit` marks the tab with the spell power split.
  - `ns.COLOR_GROUPS`: the window's five color sections, in order, each `{ key, tab, labelGlobal, label, labelSuffix }`: attack (`STAT_CATEGORY_ATTACK`), defense (`STAT_CATEGORY_DEFENSE`), spells (`SPELLS`) and spell schools in the combat tab, and food and drink in its own. Blizzard has no name for spell schools, so that title is `DAMAGE` plus the addon's " extra": "Daño extra", "Damage extra".
  - `ns.IsCollapsible(groupKey)`: a section collapses when it shares its tab with others. The only section of a tab has no header: the tab names it.
  - `ns.COLOR_KINDS`: 36 line kinds, listed section by section, each `{ key, group, label, stat, sample }`. `group` is its section; `stat` names the client's text for the row label; `sample` describes the preview line, which `ns.GetSampleLine(kind)` builds (`details` for a food line's).
    - Attack: attack power, attack power vs type, ranged attack power, feral attack power, hit, crit and weapon skills.
    - Defense: defense, dodge, parry, block (%), block value and HP5.
    - Spells: spell power, spell damage, spell healing, spell damage vs type, spell hit, spell crit, spell penetration and MP5.
    - Spell schools: arcane, fire, frost, holy, nature and shadow damage.
    - Food and drink: health, mana, experience, and the stats only Well Fed buffs give: stamina, intellect, strength, agility, spirit and armor. Well Fed attack power, spell damage, healing and crit use their kinds above.
  - `ns.ORIGINAL_TEXT_KEYS`: Ctrl, Alt, Shift, with the client's text for each (`labelGlobal`).
  - The language setting is `language`: `CLIENT` (the default) or a bundled language.
  - `splitSpellPower` (false by default) shows combined spell power as spell damage and spell healing lines instead of its own line.
  - `ns.GetOfferedLanguages(clientLocale)`: the bundled languages a client's font can show. `ns.ResolveLanguage(saved, clientLocale)`: the language the texts are actually shown in (see [Localization](#localization)).
  - Empty `ns.LOCALES`, `ns.LOCALE_STRINGS` and `ns.LOCALE_CLASS_NAMES`, which `Locales.lua` replaces, and an empty `ns.FOODS`, which `FoodData.lua` replaces.
  - `ns.DEFAULTS`: every color starts as equip green, the key defaults to Ctrl, the language to the client's, spell power isn't split and no color section is collapsed (`collapsedSections`, COLOR_GROUPS key -> true).
  - `ns.LoadSettings(saved)`: completes and validates the saved table in place (known key and language, a boolean `splitSpellPower`, colors in 0–1, collapsed sections that can collapse, a finite minimap angle).
- `Locales.lua`: generated by `scripts/update-locales.ps1` (see [Localization](#localization)). Blizzard's strings in each bundled language: `ns.LOCALES` (menu order), `ns.LOCALE_STRINGS[locale][name]` and the class names, `ns.LOCALE_CLASS_NAMES[locale][classFile]`.
- `FoodData.lua`: generated by `scripts/update-foods.ps1`. `ns.FOODS[spellID]`: what each food's Use line shows (see [Food and drink](#food-and-drink)).
- `Rules.lua`: pure. Turns the item's stats into claims and decides which equip lines to rewrite (see [Rules](#rules)).
  - `ns.GetReplacement(text, stats, context)` returns a list of compact lines, `{}` to remove the line, or `nil` to keep it.
  - A compact line is `{ kind, text, value, percent, stats }`. `text` is the English line, `kind` is a `COLOR_KINDS` key (school damage is `<school>Damage`) and `stats` lists the `ITEM_MOD_*_SHORT` keys it shows.
  - `ns.TrustedNames(GetStatName, FoldCase)` makes a stat name getter that leaves out untrusted vs names (see [Creature types](#creature-types)). `context.GetStatName` is one of these, over the client's names.
  - `ns.LocalizeLines(lines, GetStatName)` rebuilds the lines with the names of a `TrustedNames` getter, food lines' details included.
- `FoodRules.lua`: pure. `ns.GetFoodReplacement(text, food, context)` returns the compact lines of a food's Use line, or `nil` to keep it (see [Food and drink](#food-and-drink)).
- `Tooltip.lua`: the WoW API side. It registers the line pre-calls, for equip lines and for food's Use lines, and checks their prefix. It reads the item and its stats (or the line's food), builds `context`, applies the language setting and colors each line with `ns.db.colors[kind]`, falling back to the original line color. It skips tooltips other addons only fill to read an item (see [Other addons' tooltips](#other-addons-tooltips)) and handles the "show original text" key.
  - `ns.GetClientText(name)` reads the client's own strings (for recognition), `ns.GetTextIn(language, name)` a string in a given language (`CLIENT` or a bundled one; `ns.GetLanguage()` is the chosen one) and `ns.GetEnglishText(name)` one in English. `ns.GetClassName(classFile)` is a class's name in the chosen language, then in English.
  - Two of the texts aren't GlobalStrings. `WELL_FED`, the Well Fed buff's name: the client's is `C_Spell.GetSpellName(19705)`, a Well Fed spell. `KILL_EXPERIENCE`, the experience from kills, comes from a buff's description, which no API gives: the client's is the bundled one of its language, if any.
  - `ns.GetLanguage()` is the language the texts are shown in (`ns.ResolveLanguage` for this client).
  - `ns.InLanguage(lines[, language])` gives the compact lines Blizzard's names in the chosen language (or `language`), lowercased. Its name getters are made once per language.
  - `ns.ToLower(text)` is the display lowercase.
  - `ns.RefreshItemTooltips()` rebuilds the shown item tooltips (see ["Show original text" key](#show-original-text-key)).
- `OptionsWindow.lua`: the settings window. `ns.ShowOptions()` opens it, `ns.ToggleOptions()` toggles it.
  - Rows: the original text key and the language, for both tabs, then the shown tab's colors and preview. Changing the language sets every Blizzard text in the window again, with no `/reload`.
  - Tabs: `PanelTabButtonTemplate` buttons under the window (`$parentTab1`, `$parentTab2`), as in Blizzard's inspect window, with `PanelTemplates_SetNumTabs`, `PanelTemplates_SetTab` and `PanelTemplates_TabResize`, and the tab sound. Combat holds the item sections, the sample item and the spell power split checkbox; food and drink holds its rows and the sample food. The window opens on the tab left open, the first one after a `/reload`.
  - The split checkbox: changing it rebuilds the preview and the shown item tooltips; while it is on, the preview leaves out the spell power sample line, which would look like the spell damage and healing ones.
  - The color rows sit in a `ScrollFrameTemplate` inside the colors panel, in one section per `COLOR_GROUPS` entry; `LayoutSections` stacks the shown tab's sections, hides the other tab's and sizes the scroll child. Each row has its swatch, label and Reset button. "Reset these colors" resets the shown tab's colors.
  - A section that shares its tab has a `ListHeaderThreeSliceTemplate` header (Blizzard's collapsible header, as in the currency window) titled with Blizzard's name for it. A click collapses or expands it (`SetClickHandler`, `UpdateCollapsedState`). Collapsed sections are saved in `ns.db.collapsedSections` and left out of the preview. Food and drink, alone in its tab, has no header and always shows.
  - `ColorPickerFrame:SetupColorPickerAndShow`: `swatchFunc` updates the color live and `cancelFunc` restores the previous one.
  - The color picker gets a palette of class colors when the window opens it: Forever's classes in the game's order (`CLASS_SORT_ORDER`), as `ColorSwatchTemplate` swatches in a row under the color wheel, each naming its class in its color (`C_ClassColor.GetClassColor`) on hover.
    - A click calls `ColorPickerFrame.Content.ColorPicker:SetColorRGB`, which runs `swatchFunc` like any change in the picker, so OK and Cancel work as usual.
    - The palette is a child of `ColorPickerFrame`: the picker cancels and hides on any click outside itself (`GLOBAL_MOUSE_DOWN` and `DoesAncestryIncludeAny`).
    - The picker (331×210 without opacity) has no room for it, so it grows by `PALETTE_HEIGHT` while the palette shows and gets its own height back when the pick ends (`OnHide` while no longer shown: hiding with UIParent, Alt+Z, keeps both). Other addons' picks never show the palette.
  - Built from Blizzard templates: `PortraitFrameTemplate`, `PanelTabButtonTemplate`, `InsetFrameTemplate`, `ScrollFrameTemplate`, `ListHeaderThreeSliceTemplate`, `WowStyle1DropdownTemplate` with `MenuUtil.CreateRadioMenu`, `ColorSwatchTemplate`, `UIPanelButtonTemplate`, `UICheckButtonTemplate`.
  - The preview is real `GameTooltipTemplate` tooltips filled with `AddLine`, in the same place: a sample item (`StatsTrimmerPreviewTooltip`) in the combat tab and a sample food (`StatsTrimmerFoodPreviewTooltip`) in the food tab. Both are filled and measured every time, and the other tab's hidden.
  - The window is strata HIGH, so the color picker (DIALOG) stays above it.
  - `FitWindow` sizes the window to its texts after opening and after every language, split, section or tab change (a color change only refills the preview): the colors panel to its longest row label in either tab (`GetUnboundedStringWidth`) plus the swatch and Reset button, and the window to that panel, the larger preview tooltip with its margins, the rows above the panels and the preview's height. Both tabs count, so switching tabs doesn't resize the window. The panels grow for longer texts, but never get smaller than with Spanish texts and every section open (`REFERENCE_LANGUAGE`): those sizes are measured once, on the window's own labels, Reset button and preview, which then get the chosen language's texts back before anything is drawn. The window is never smaller than 600×690 either. A screen too small for it (a large UI scale) gets it scaled down, tabs included (`SetScale`): their height below the frame counts towards the required height and extends the bottom screen boundary (`SetClampRectInsets`), so dragging the window cannot hide them either. `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED` fit the shown window again; a hidden window fits when reopened.
- `MinimapButton.lua`: `StatsTrimmerMinimapButton`, a child of `Minimap` with Blizzard's minimap button textures.
  - It saves its angle in `ns.db.minimap.angle` and follows the minimap's edge when the minimap is resized.
  - MinimapButtonButton collects it with no library: it takes `Minimap` children whose global name contains `MinimapButton`, scanning on `PLAYER_LOGIN` and when its own button is clicked. Once the button has been reparented, dragging and resizes no longer move it.
- `SettingsCategory.lua`: an Options > AddOns canvas with a button that opens the window.
- `Core.lua`: on `ADDON_LOADED` it loads the settings, places the minimap button and registers the Options category.

UI rule: use Blizzard templates wherever possible; don't hand-roll frames or backdrops.

### Tooltip mechanism

Verified against the `forever` branch of [wow-ui-source](https://github.com/Gethe/wow-ui-source) (builds 1.60.1.70291 and 1.60.1.70338):

- Item tooltips are data-driven. `Blizzard_GameTooltip` only ships the Mainline variant, where `GameTooltipTemplate` uses `GameTooltipDataMixin` and `ShoppingTooltipTemplate` uses `TooltipDataHandlerMixin`.
- `TooltipDataProcessor.AddLinePreCall(lineType, func(tooltip, lineData))`: if `func` returns `true`, the original line is not added (`TooltipDataHandlerMixin:ProcessLineData` in `Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua`). Addon callbacks run insecurely through an attribute delegate, but they can still consume the line.
- Pre-calls run for **every** tooltip that processes data, shown or not (see [Other addons' tooltips](#other-addons-tooltips)).
- Blizzard runs the insecure pre-calls in registration order, each through `securecallfunction`:
  - the first one that returns `true` consumes the line, and the later ones don't see it;
  - an error goes to the error handler (BugSack), and the line keeps its original text;
  - a consumed line gets no line post-calls and no `lineData.lineIndex`.
- Inside a line pre-call, `tooltip:GetProcessingTooltipInfo()` is the info being processed (appended infos included). `TooltipUtil.GetDisplayedItem` reads the primary one instead.
- Tooltip line text can be a **secret value** in this framework (Blizzard's comment in `GameTooltip.lua` mentions world cursor tooltips with secret line text). Addon code can't compare or search secrets, so the pre-call skips any line whose text fails `type(text) == "string" and not issecretvalue(text)`, and never passes secret item lines to the rules.

The equip `lineData` only has `type`, `leftText`, `leftColor` (green) and `wrapText`: there is no spell ID or other args (confirmed in game). That is why lines are matched by their numbers.

Use lines are different (seen in a `C_TooltipInfo.GetBagItem` dump on 2026-10-15): their type is `ItemSpellTriggerOnUse` (44) and their `lineData` has the item spell's `spellID`, so the second pre-call is registered on that type.

### Other addons' tooltips

Checked on 2026-10-13 with the addons installed in the Forever client: AtlasLoot Forever 1.60.1, DungeonJournal (`ForeverDungeonJournal`) 1.6.3 and GearQuest Forever 0.5.5-beta.

- Addons show items through the same data path (`SetHyperlink`, `SetItemByID`, `SetInventoryItem`), so their tooltips get the compact lines with no special handling:
  - AtlasLoot uses `GameTooltip` by default (its `useGameTooltip` setting), or its own `AtlasLootTooltip` owned by the hovered button, and Blizzard's comparison tooltips;
  - DungeonJournal uses `GameTooltip`, and its own comparison tooltips owned by the hovered row with `ANCHOR_NONE`.
- Addons also fill hidden tooltips only to read an item's text (all three do): `SetOwner(UIParent, "ANCHOR_NONE")`, then `SetHyperlink`.
  - `IsScanningTooltip` leaves the original text in those, which is what such addons expect to read: a tooltip with no owner, or owned by `UIParent` or `WorldFrame` with `ANCHOR_NONE`.
  - Blizzard's item tooltips (`GameTooltip`, `ItemRefTooltip`, `ShoppingTooltip1/2`, `ItemRefShoppingTooltip1/2`) are never skipped: default-anchored ones are owned by `UIParent` with `ANCHOR_NONE` too.
  - Addons that read items through `C_TooltipInfo` (DungeonJournal does too) get the data without the pre-calls, so they always see the original text.
- Addons add lines in two ways, and only one survives a rebuild (`RefreshData` → `RebuildFromTooltipInfo` processes the tooltip's infos again):
  - tooltip post-calls (`TooltipDataProcessor.AddTooltipPostCall`) run again: GearQuest's score line on bag items stays;
  - lines added with `AddLine` after `SetX` are lost: AtlasLoot's drop rate and item ID, and DungeonJournal's source, disappeared when the original-text key rebuilt `GameTooltip` (seen in game). GearQuest does the same in its own window: its score line comes after the data there.
- All three fill `GameTooltip` from the `OnEnter` script of the hovered button or row, and none defines `UpdateTooltip`, so Blizzard doesn't rebuild their tooltips by itself.
- GearQuest's own window shows the game's tooltip only for items it has no stored text for. For the rest (about 2,400 to 3,700 items per class, in `GearQuestForever_<CLASS>\AuditTips.lua`) it writes text copied from Wowhead Forever, in English, with `AddLine`. No item data is behind those lines, so the pre-call never sees them and the original-text key has nothing to switch. Left as it is on purpose (user decision, 2026-10-13): it is GearQuest's text, not the game's.

### "Show original text" key

- While the chosen modifier is down (`IsControlKeyDown` / `IsAltKeyDown` / `IsShiftKeyDown`), the pre-calls don't replace anything. They never mutate `lineData`, so no original text needs to be stored.
- On `MODIFIER_STATE_CHANGED` for that key, shown item tooltips are rebuilt so they switch at once: `GameTooltip`, `ItemRefTooltip`, and other addons' own tooltips that showed equip or food lines (the pre-calls remember them; Blizzard's comparison tooltips follow their main tooltip instead). `ns.IsOriginalTextEventKey` maps `LCTRL`/`RCTRL` to `CTRL`, and so on.
  - `hooksecurefunc` on their `ProcessInfo` (which every `SetX` calls) records `NumLines()` after each build, other addons' post-calls included.
  - A tooltip with only those lines is rebuilt from its data with `RefreshData()`. Comparison tooltips follow their main tooltip.
  - A tooltip with more lines has some another addon added with `AddLine`, which `RefreshData()` would lose (see [Other addons' tooltips](#other-addons-tooltips)). Its owner rebuilds it instead, with `ExecuteFrameScript(owner, "OnEnter")`, as when the mouse enters it again. That needs an owner under the mouse with an `OnEnter` script, not protected and without `UpdateTooltip`. Other addons' own tooltips always go this way (only `GameTooltip` and `ItemRefTooltip` record their line count), and an owner is run once even when it shows several of them.
  - Blizzard's other item tooltips (`EmbeddedItemTooltip`, the UI widgets' `UIWidgetBaseItemEmbeddedTooltipN`) aren't rebuilt: their owners can be Blizzard widgets with an `OnEnter` script, which addon code must not run. The pre-call leaves out any tooltip whose global name is secure (`issecurevariable(name)`), i.e. set by Blizzard's code; addons' named and unnamed tooltips are kept. `issecurevariable` doesn't appear in Forever's UI source: it was checked in game on 2026-10-15 (`/dump issecurevariable("EmbeddedItemTooltip")` prints true), and MinimapButtonButton and Leatrix Plus use it in Forever.
  - Anything else switches the next time it is built. Owners with `UpdateTooltip` (Blizzard's bag and character buttons) get it called by `GameTooltip_OnUpdate` every 0.2 s.
- Taint risks to watch, since both run from addon code:
  - `RefreshData`: Blizzard notes that tainted tooltip state can show no lines for secret data. If unit or NPC tooltips ever come up empty, stop calling `RefreshData` and rely on the bags' automatic refresh.
  - `ExecuteFrameScript` runs the owner's `OnEnter` as addon code. That is harmless for another addon's frame, but would taint a Blizzard frame's handler. Blizzard's item buttons have `UpdateTooltip` or don't add lines after the data, so they shouldn't get there; if one does and errors or blocked actions follow hovering it, narrow `CanEnterAgain`.

## Rules

### How a line is matched

`C_Item.GetItemStats(link)` gives the item's stat values in every locale (keys like `ITEM_MOD_SPELL_DAMAGE_DONE_SHORT`). The tooltip text varies per locale and item, so a line is matched to stats by its numbers only.

1. Each entry of `ns.Rules` turns the item's stats into **claims** (`claims(stats, context, Add)`). A claim is a stat, or a group of stats, that can own equip lines. It has:
   - `numbers`, the numbers its line shows; or `percent`, for a line with a lone percentage;
   - `size`, how many lines it owns;
   - optional creature type info;
   - `Render(text)`, which returns the compact lines.

   A claim without `Render` (an unknown creature type, a rating missing from `PERCENT_RATINGS`) still counts as an owner, so it keeps other stats from taking its line.
2. Every equip line of the item (lines starting with the localized `ITEM_SPELL_TRIGGER_ONEQUIP`) is matched against every claim.
3. A line is rewritten only if **exactly one claim** can own it **and** that claim matches exactly `size` lines. Anything else keeps the original text: guessing between two stats with the same number would show a wrong line.

The order of `ns.Rules` doesn't matter.

Consequences, all pinned by tests in `spec/rules_spec.lua`:
- Two stats with the same value (MP5 and HP5, attack power and ranged attack power, two schools, defense and block value) leave both lines untouched.
- A stat whose number also appears in an unrelated equip line ("stealth level by 1" next to +1 attack power) leaves both untouched.
- `NumbersMatch` uses sets: MP5 expects `{value, 5}`, so MP5 5 is `{5}`, and MP5 5 next to attack power 5 leaves both untouched.
- A line with a percentage never matches a point stat ("resist Silence by 10%" next to 10 spell damage).
- A line with more than one percentage ("hit by 1% and movement speed by 8%"), even the same one twice, is left untouched: a compact line for the first would hide the second.

### Creature types

`ITEM_MOD_<STAT>_VS_<TYPE>_SHORT` (attack power and spell damage) can share its number with a plain line. *Nudillos de hueso* has "+6 p. de poder de ataque." and "+6 p. de poder de ataque contra bestias." with `ATTACK_POWER=6` and `ATTACK_POWER_VS_BEAST=6`.

- Words naming the creature type tell them apart. A creature claim has two search terms, both folded with `C_Intl.FoldCase` (Unicode-aware lowercase: "Élémentaire" → "élémentaire") and searched as plain text:
  - the client's type name, `C_CreatureInfo.GetCreatureTypeInfo(1).name` ("Bestia" on esES);
  - the last word of the client's name for the stat itself, `ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT` ("Poder de ataque contra **bestias**"). It is usually the form the tooltip uses, even in locales that decline the type name (ruRU).
- A creature claim is **located** in the lines it matches that contain one of its terms. Once located, it leaves its other lines, and a line where some claim is located keeps only the located claims. Only equip lines are searched: the item name can mention a type too.
- If no term is found, the claim isn't located. Its line is then rewritten only if no other stat shares its number.
- The client's vs names aren't always right: esES names spell damage vs beasts "Daño con hechizos contra **mecánicos**" and vs mechanicals "…contra **humanoides**". The attack power names (the vs stat seen on items) are the reference:
  - an attack power vs name is trusted when no other type's name ends in the same word;
  - a spell damage vs name only when it ends like the attack power name for its type.

  Words are compared folded, so ptBR "Mortos-vivos" and "Mortos-Vivos" agree. `ns.TrustedNames` checks the vs names once, when its getter is made.

  Untrusted names are neither search terms nor shown (see [Localization](#localization)).
- One line naming several types for the same stat ("…when fighting Undead and Demons") becomes `+150 attack power vs undead/demons`, in the order the line names them.
- Creature type IDs on esES: 1 Bestia, 2 Dragonante, 3 Demonio, 4 Elemental, 5 Gigante, 6 No-muerto, 7 Humanoide, 8 Alimaña, 9 Mecánico, 10 Sin especificar, 11 Tótem, 12 Mascota mansa, 14 Mascota salvaje.
- Keys seen in game: `VS_BEAST` and `VS_ELEMENTAL` (an item with `ATTACK_POWER=4`, `ATTACK_POWER_VS_ELEMENTAL=6`, `MINING=2`). `VS_CREATURE_TYPES` also lists DRAGONKIN, DEMON, GIANT, UNDEAD, HUMANOID and MECHANICAL by analogy; those keys are unverified.

### Data tables

A new stat of an existing shape is a new entry in one of these tables in `Rules.lua`:

- `POINT_STATS`: the line shows exactly the value.
  - Defense (`ITEM_MOD_DEFENSE_SKILL_RATING_SHORT=3`, seen in game) shows plain skill points ("Increased Defense +3.") despite the `RATING` in its key, so it renders as `+3 defense`.
  - Ranged attack power, feral attack power, block value and spell penetration have not been seen yet.
- `WEAPON_SKILLS`: `+7 swords skill`. Skills with the same value form one group claim. Edgemaster's Handguards (axes/daggers/swords +7, one line each) gets its compact lines on the first line, one per skill (`+7 axes skill`, `+7 daggers skill`, `+7 swords skill`), and the other lines are removed (`{}`). If the line count doesn't match the skill count, the lines are left untouched.
- `PERCENT_RATINGS`: ratings shown as a percentage. The rating isn't the shown number, so the claim is on the line with a lone percentage and the value is read from its text: `+1% hit`, `+1% block`.
  - Seen in game: block (*Espejo de Rath'mael*, "Aumenta un 1.0% la probabilidad de bloquear…", `ITEM_MOD_BLOCK_RATING_SHORT=5`) and hit (`ITEM_MOD_HIT_RATING_SHORT=4`).
  - Added from Classic knowledge: crit, spell crit, spell hit, dodge and parry.
  - The decimal is a dot even on esES, but `,` and a space before `%` are accepted. `+1% block` has no trailing `.0`.
  - 5 block rating = 1% is a single data point and is not relied on.
  - Two percentage ratings on one item (e.g. hit and crit) leave both lines untouched. Skill ratings (`*_SKILL_RATING_SHORT`, defense) are points, not percentages.
- `VS_STATS` and `VS_CREATURE_TYPES`: the vs-creature stats and types. `+20 spell damage vs undead` hasn't been seen in game yet.

Other rules: combined spell power, spell damage and/or healing, MP5, HP5, attack power and single-school damage.

Adding a case:
- Add the table entry or a rule in `ns.Rules`, plus a test in `spec/rules_spec.lua` with the real in-game text and `GetItemStats` output (esES, and enUS when known).
- A new line kind also needs an entry in `ns.COLOR_KINDS`, in its section. Ask which section when it isn't obvious.

### In-game findings

Checked on esES with *Cosedora*, whose tooltip says "Equipar: Aumenta hasta 30 p. la sanación realizada y hasta 10 p. el daño infligido con todos los hechizos y efectos mágicos.":

- **Equip lines have type `None` (0), not `ItemSpellTriggerOnEquip` (45).** The type can't be used to find them; the pre-call is registered on `Enum.TooltipDataLineType.None`.
- The line text starts with the localized global `ITEM_SPELL_TRIGGER_ONEQUIP` ("Equipar:" on esES). That is the locale-independent way to detect equip lines.
- The rest of the text does **not** match the GlobalStrings templates `ITEM_MOD_SPELL_POWER`, `ITEM_MOD_SPELL_DAMAGE_DONE` or `ITEM_MOD_SPELL_HEALING_DONE`. It comes from the item's spell description and varies in wording, so don't build patterns from those templates.
- `GetItemStats` gives `ITEM_MOD_SPELL_DAMAGE_DONE_SHORT=10` and `ITEM_MOD_SPELL_HEALING_DONE_SHORT=30`. Damage and healing can differ, so the numbers always come from there.

Other items:
- A combined line ("Aumenta hasta 26 p. el daño infligido y la sanación realizada…", *Bastón nudoso de nigromancia*) is a single stat, `ITEM_MOD_SPELL_POWER_SHORT=26`, with no separate damage/healing keys. It shows as one line, `+26 spell power` (`+26 poder con hechizos`), like Blizzard's item comparison, which lists it as a single "poder con hechizos" stat (checked in game). With the `splitSpellPower` setting it counts as both and shows as the same two lines as separate damage and healing: `+26 spell damage` and `+26 spell healing`. Items with separate keys (*Cosedora*) always get their two lines.
- Single-school damage ("…con hechizos y efectos de escarcha") is `ITEM_MOD_FROST_DAMAGE_DONE_SHORT=32` and renders as `+32 frost damage`. Any `ITEM_MOD_<SCHOOL>_DAMAGE_DONE_SHORT` key is matched; only FROST has been seen in game so far.
- Mana regen ("Equipar: Restaura 4 p. de maná cada 5 s.") is `ITEM_MOD_MANA_REGENERATION_SHORT=4` and renders as `+4 MP5`, the community abbreviation.
- Health regen ("Equipar: Restaura 5 p. de salud cada 5 s.") is `ITEM_MOD_HEALTH_REGEN_SHORT=5` and renders as `+5 HP5`.
- Attack power is `ITEM_MOD_ATTACK_POWER_SHORT=4` and renders as `+4 attack power`.

### All stat keys the client knows

No API lists them; they're GlobalStrings named like the `GetItemStats` keys. To regenerate the list:

1. In game: `/run local t={} for k,v in pairs(_G) do if type(k)=="string" and k:find("^ITEM_MOD_") then t[k]=v end end StatsTrimmerDB.statKeys=t`
2. `/reload`.
3. Read `WTF\Account\<account>\SavedVariables\StatsTrimmer.lua`.
4. Remove it afterwards with `/run StatsTrimmerDB.statKeys=nil`.

On 2026-10-09 the client had 148 `_SHORT` keys. Classic-relevant ones not handled:
- professions (`ALCHEMY`, `MINING`, …), on purpose;
- the `_MELEE`/`_RANGED` rating variants;
- `ARMOR_PENETRATION_RATING`;
- the aliases `HEALTH_REGENERATION` and `POWER_REGEN0`.

Retail-only keys (haste, mastery, versatility, `CR_*`, crafting stats, PvP, resilience) are present but not expected on Forever items. The long templates (`ITEM_MOD_X`) always say "%s p.", even for stats that item lines show as a percentage, so they don't tell points from percentages.

### Known limits

- Lines are matched by numbers only, so a line that more than one stat could own keeps its original text (see above).
- Creature type recognition outside esES has only been checked with made-up lines in the specs.
- A tooltip another addon shows with no owner, or owned by `UIParent` or `WorldFrame` with `ANCHOR_NONE`, keeps the original text, like a scanning tooltip. An addon that builds its shown tooltip by copying lines from a scanning tooltip gets the original text too (GearQuest has such code for random-suffix items, unused in 0.5.5-beta).
- Replaced lines get no line post-calls or `lineIndex`, and if another addon also consumes equip lines with a line pre-call, the one registered first wins. None of the addons checked on 2026-10-13 uses line callbacks.
- Text another addon writes itself with `AddLine` isn't rewritten: only lines that come from the game's item data are. GearQuest's window is the case seen so far (see [Other addons' tooltips](#other-addons-tooltips)).

## Food and drink

Only food and drink are handled: potions, bandages, elixirs and other consumables keep their text.

### What the client gives

Checked on 2026-10-15 with a dump of the bag items with a Use spell (`C_TooltipInfo.GetBagItem`, `C_Item.GetItemSpell`, `C_Spell.GetSpellDescription`, `C_Item.GetItemInfoInstant`), on an enUS client:

- Food and drink are class 0, subclass 5 (Consumable, Food & Drink).
- The Use line is its spell's description after `ITEM_SPELL_TRIGGER_ONUSE` ("Use:", "Usar:"), and has the spell's ID (see [Tooltip mechanism](#tooltip-mechanism)). Its wording and the order of its numbers vary per language: deDE puts the duration first ("Stellt im Verlauf von 24 Sek. 530 Punkt(e) Gesundheit wieder her").
- A food with a cooldown has it at the end of the line, from `ITEM_COOLDOWN_TOTAL` with a plural escape: "(1 |4Sec:Sec; Cooldown)". Most foods share a 1 second one.
- `C_Spell.GetAuraStatChanges(spellID)` returns 0 and no power changes for food spells: there is no API for what a food restores.
- The client computes that amount in its own way: Spongy Morel restores 530 health over 24 s, where its 115 base points every 5 s would make 552; Melon Juice restores 803 mana.
- Forever's well fed foods are new spells. Their description includes the base food's (`$@spelldesc435`) and ends with the experience bonus spell's (1243969), "Additionally, experience gained from kills is increased by 5%.", which only some players see (`$?pc142418[...]`). Some of them aren't translated: esES clients see their well fed part in English.

### FoodData.lua

`scripts/update-foods.ps1 [-Build <build>]` generates it from Forever's Item, ItemSparse, ItemEffect, ItemXItemEffect, Spell, SpellEffect, SpellMisc and SpellDuration tables on wago.tools. It reads each food's English description to learn which numbers the line shows and what each one is:

- `$d` is a duration, `$s1` an effect's base points, `$t2` its period, `$o1` its total: a percentage total for health and mana percentage auras (20, 21), and for health and mana regeneration (84, 85) an amount the client computes, which only the line gives.
- `ns.FOODS[spellID]` is `{ numbers, lines, experience }`: the numbers the line shows besides the amounts and the experience bonus; the compact lines (a stat key, a `value` or an `amount` with its base points, and their details); and the bonus, when the line can end with it.
- It understands restores of health and/or mana over time (points, a total percentage or a percentage per second) and Well Fed buffs of stamina, intellect, strength, agility, spirit, armor, attack power, spell damage, healing and crit, one or two stats.
- It leaves out, with their original text: alcohol and joke foods with no numbers, instant restores, Fishing and Herbalism buffs (professions aren't handled), movement speed in one zone, Enriched Manna Biscuit (its text for inside Naxxramas), Bobbing Apple (a well fed buff with no number) and a few others. The script lists them.

**Run it again when the client build changes**, and commit the new file. On build 1.60.1.70338 it describes 82 food spells and leaves out 35.

### Matching a Use line

`ns.GetFoodReplacement(text, food, context)`:

1. Takes the Use prefix off, and the cooldown when it is the shared 1 second one (built from the client's `ITEM_COOLDOWN_TOTAL`). A longer cooldown keeps the original text: the compact lines would hide it.
2. Counts the line's numbers, without plural escapes and with a thousands separator ("2,148", "2.148") inside the number. Whether the client adds separators is unverified: no food seen so far restores 1000 or more.
3. Takes the food's `numbers`. Every one must be there; what is left must be one number per amount, plus the experience bonus when the line shows it.
4. The larger amount goes to the larger base points, as the client computes every amount of a food the same way. Two amounts with the same base points must be the same number.

Anything else keeps the original text.

The compact lines, in English and on esES:

| Line | English | esES |
|---|---|---|
| Restore | `+530 health (24 sec)` | `+530 salud (24 s)` |
| Percentage per second | `+2% health/s (25 sec)` | `+2% salud/s (25 s)` |
| Well Fed | `+10 attack power (well fed, 15 min)` | `+10 poder de ataque (bien alimentado, 15 min)` |
| Experience (from kills only) | `+5% experience gained from kills` | `+5% experiencia obtenida al matar enemigos` |

- "Must remain seated while eating", the 10 seconds of eating and the shared cooldown are left out.
- A Well Fed buff of two stats with one number ("6 Stamina and Spirit") is two lines.
- `/s` reads the same in every language, like MP5. The rest are Blizzard's words (see [Localization](#localization)).

## Localization

Stats Trimmer has no translations of its own: everything it shows in a language other than English is one of Blizzard's own strings.

### The Language setting

`ns.db.language` is `CLIENT` (default) or one of the bundled languages. It covers everything that comes from Blizzard: the compact lines, the color row labels and the window's Blizzard texts. Changing it in the window applies at once: the window's texts, the preview and the shown item tooltips are rebuilt.

The client only loads its own language's strings, so the other languages are bundled:
- `StatsTrimmer/Locales.lua` holds the strings of **enUS, deDE, esES, esMX, frFR, itIT and ptBR**: every `ITEM_MOD_*_SHORT` stat name, the few interface strings the window uses, the words of food lines (`HEALTH`, `MANA`, `COMBAT_XP_GAIN`, `ARMOR`, `INT_SPELL_DURATION_SEC`, `INT_SPELL_DURATION_MIN`), the Well Fed buff's name as `WELL_FED`, the experience from kills as `KILL_EXPERIENCE`, and the male names of Forever's 9 classes.
- It is generated by `./scripts/update-locales.ps1 [-Build <build>]` from Forever's `GlobalStrings`, `ChrClasses`, `SpellName` and `Spell` on wago.tools (`https://wago.tools/db2/GlobalStrings/csv?build=<build>&locale=<locale>`, and the same for the others). For build 1.60.1.70338 the GlobalStrings match the client exactly (checked against an in-game dump).
  - `ChrClasses`' `Name_male_lang` matches `LocalizedClassList(false)`.
  - `WELL_FED` is spell 19705's name, the same spell the client is asked for.
  - `KILL_EXPERIENCE` is the aura description of the experience bonus (spell 1243969) without its number and the two words before it: "Experience gained from kills increased by $w1%." gives "Experience gained from kills", "Experiencia obtenida al matar enemigos aumentada un $w1%." gives "Experiencia obtenida al matar enemigos", and "Durch Siege erhaltene Erfahrung um $w1% erhöht." gives "Durch Siege erhaltene Erfahrung". The bonus only counts for kills, and Blizzard has no shorter string that says so. Check the result in every language when the build changes. itIT's is in English, as its description isn't translated.
- Forever's itIT data has no class names, so Italian shows the English ones, and a few of its strings are in English too ("Weapon Skills").
- **Run the script again when the client build changes**, and commit the new file.
- These are Blizzard's texts, not covered by the addon's MIT license.
- `/reload` doesn't load a file new in the `.toc`, so right after the update that added `Locales.lua` the addon runs without it until the client restarts. `Config.lua` starts both tables empty: the texts are the client's and the English fallback is the addon's own, with no Lua errors. The same goes for `FoodData.lua` and `FoodRules.lua`: with `ns.FOODS` empty, Use lines keep their text until the restart.

Which languages the dropdown offers depends on the client's font (`ns.GetOfferedLanguages`):
- clients with the Latin alphabet: their own language plus every bundled one;
- ruRU, koKR, zhCN and zhTW clients: their own language (from the game, not bundled) and English. A Latin font can't show Cyrillic, Korean or Chinese, and those fonts may lack accented letters.
- enGB isn't a bundled language, so an enGB client gets the same as a ruRU one: its own (English) and enUS. Not handled on purpose.
- Language names come from `LocaleUtil.GetLocaleDisplayName` (`LFG_LIST_LANGUAGE_*`), in the client's language: «Inglés», «Alemán»…

SavedVariables are per account, so a language chosen on one client can be loaded on another. `ns.ResolveLanguage` shows the client's own language when the saved one is the client's language, or one the client doesn't offer. The saved value isn't changed, so it applies again when the client changes back.

Text lookup:
- `ns.GetTextIn(language, name)`: the client's strings (`_G`) when `language` is `CLIENT`, otherwise the bundled table. The chosen language is `ns.GetLanguage()`.
- `ns.GetEnglishText(name)`: the client's strings on an enUS client, otherwise the bundled `enUS`.
- `ns.GetClientText(name)`: always the client's strings. Equip lines are recognized with these, since the tooltip is in the client's language.

### Compact lines

`ns.InLanguage` runs `ns.LocalizeLines` twice: with the chosen language's names, then with English names for any line still left.
- The names are lowercased with `C_Intl.ToLower` (display lowercase that follows the client's language rules; `string.lower` if it returns nothing). Blizzard's own capitalization is uneven ("Daño Arcano", "golpe").
- A line naming several stats becomes one line per stat: a group of weapon skills, or several creature types on one line.
- MP5 and HP5 lines have no stat names, so they read `+4 MP5` and `+5 HP5` in every language.
- Food lines' details use Blizzard's words too, lowercased like the names: `INT_SPELL_DURATION_SEC` ("%d s"), `INT_SPELL_DURATION_MIN` and `WELL_FED`. A line lacking one of them goes to the English pass whole. `/s` is the same in every language.
- The experience bonus is named `KILL_EXPERIENCE`, not `COMBAT_XP_GAIN` ("Experience"): it only counts for kills. Its color row is still labelled with `COMBAT_XP_GAIN`.
- A name is skipped when it is missing or untrusted (see [Creature types](#creature-types)), and the line goes to the next pass. The addon's internal English in `Rules.lua` (`+10 spell damage`) is only the last resort.

On esES that gives `+10 daño con hechizos`, `+1% golpe`, `+6 poder de ataque contra bestias`, `+10 poder de ataque (bien alimentado, 15 min)`; in English `+10 spell damage`, `+1% hit`, `+6 attack power vs beasts`, `+10 attack power (well fed, 15 min)`.

Blizzard's data has mistakes that fall back to English:
- esES spell damage vs beasts says "…contra mecánicos" and vs mechanicals "…contra humanoides";
- deDE uses two words for beasts ("Wildtiere", "Bestien"), so spell damage vs beasts isn't trusted either;
- frFR doesn't translate `ITEM_MOD_MANA_REGENERATION_SHORT`, which isn't used anyway.

### Interface

| Where | Blizzard string |
|---|---|
| Original text key options | `CTRL_KEY`, `ALT_KEY`, `SHIFT_KEY` ("Control", "Alt", "Mayús" on esES) |
| Headers | `COLORS`, `PREVIEW` |
| Reset buttons | `RESET` |
| Preview | `ITEM_BIND_ON_EQUIP`, `ITEM_MOD_STAMINA_SHORT` |
| Tabs | `COMBAT`, `MINIMAP_TRACKING_VENDOR_FOOD` ("Combate", "Comida y bebida" on esES) |
| Color section titles | `STAT_CATEGORY_ATTACK`, `STAT_CATEGORY_DEFENSE`, `SPELLS`, and `DAMAGE` followed by the addon's " extra" ("Ataque", "Defensa", "Hechizos", "Daño extra" on esES) |
| Color row labels | each kind's `stat`, lowercased. MP5 and HP5 read "MP5" and "HP5". "Attack power vs type" is `ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT` without its last word: "poder de ataque contra …"; "spell damage vs type" is `ITEM_MOD_SPELL_DAMAGE_VS_UNDEAD_SHORT` the same way. Weapon skills are `STAT_CATEGORY_WEAPON_SKILLS`. Food and drink: `HEALTH`, `MANA`, `COMBAT_XP_GAIN`, the primary stats' `ITEM_MOD_*_SHORT` and `ARMOR` |
| Class color palette | the class names on hover: `LocalizedClassList(false)` on the client's language (Forever has no `LOCALIZED_CLASS_NAMES_MALE`), `ns.LOCALE_CLASS_NAMES` on the others |
| Language options | `LocaleUtil.GetLocaleDisplayName` |

Each falls back to Blizzard's English, then to the addon's English. The rest are the addon's own phrases and stay in English: the row titles, the help text, the spell power checkbox, "Reset these colors", "Sample Item", "Sample Food", the minimap tooltip and the Options panel.

Translated text can be longer, so:
- buttons are sized to their text plus a padding with `SetTextToFit` (`UIButtonFitToTextBehaviorMixin`, part of `UIPanelButtonTemplate`, which lets them get narrower too: `fitTextCanWidthDecrease`);
- row labels sit between the swatch and the Reset button without wrapping, and `FitWindow` widens the colors panel to the longest one, so none is cut off;
- the preview's longest line varies too ("+20 dégâts des sorts contre les morts-vivants" in frFR), so the window widens to the preview tooltip. Clients in other languages use their own texts, which can't be measured beforehand.

### Testing another language

Choosing another language in the addon covers most checks. Switching the game text language in Battle.net (Forever's game settings) downloads that language's texts and fonts, which is still needed to check creature type recognition in that language (Nudillos-style items).

`/dump` shows any client string, e.g. `/dump ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT`.

## Tests

Unit tests run on LuaJIT 2.1 (Lua 5.1 compatible) through `spec/runner.lua`, a minimal busted-compatible runner, so specs also run under real busted.

- The runner supports `describe`, `it`, `before_each`, `assert.are.same/equal/near` and `assert.is_nil/is_not_nil/is_true/is_false`. Only use those.
- Each spec file starts with a clean set of `describe` blocks, so a file that fails while loading doesn't affect the next one.
- `spec/helpers.lua` `LoadAddon(name, files, env)` loads addon files with `(addonName, ns)` like the client does. Without `env`, only pure files can be loaded.
- Game-facing files are tested against `spec/fakes.lua` (`fakes.NewWoW()`). It is a fake WoW API that records scripts, hooks, events, tooltip lines, colors, positions, the color picker, the radio menus, check button states, Settings registrations, secret texts and `ExecuteFrameScript` calls. Its line pre-calls run for their line type, like the client's (a line without `type` is a None line), and `C_Spell.GetSpellName` reads `wow.spellNames`. Its class colors (`fakes.CLASS_COLORS`) are made exact in hex. Its `ColorPickerFrame` is a frame like Blizzard's: setting it up or changing `Content.ColorPicker`'s color runs `swatchFunc`, and hiding it runs its `OnHide` hooks. Blizzard's tooltips (`EmbeddedItemTooltip` too) have secure global names for `issecurevariable`; frames the addon or the specs create don't.
  - The default world is an esES client whose globals are the bundled esES strings (`fakes.LocaleStrings("esES")`, which match the client exactly) and the client strings Locales.lua doesn't bundle (`fakes.ES_CLIENT_STRINGS`: the Equip and Use prefixes, `ITEM_COOLDOWN_TOTAL`). `fakes.NewWoW({ locale = "enUS" })` has only the prefixes, which exercises the fallbacks.
  - `fakes.FoldCase` stands in for `C_Intl.FoldCase` for the letters the specs use.
  - Load into it with `helpers.LoadAddon(name, files, wow.env)` or `helpers.StartStatsTrimmer(wow)`, which loads the full `.toc` and fires `ADDON_LOADED`.
  - Drive it with `fakes.Fire(frame, script)`, `fakes.ClickCheckButton(button)` (which toggles the button before `OnClick`, like the client) and `fakes.FireEvent(wow, event, ...)`.
  - Text is measured with `fakes.TEXT_METRICS` (6 per character, 14 per tooltip line, 20 of tooltip padding), which a world can change in `wow.textMetrics`. `UIParent` is 1365×768.
  - Tooltips: `fakes.ItemTooltip(wow, data)` is another addon's tooltip in the middle of processing, for calling the pre-call directly. `fakes.ShowItem(wow, tooltip, owner, anchorType, data)` fills one like the client: `SetOwner`, then `ProcessInfo`, which runs the registered line pre-calls and shows it.
  - Frame methods the specs don't care about are listed explicitly as no-ops. Any other missing method fails, so a misspelled WoW method is caught.
- Every `.toc` file must be loaded by some spec, otherwise LuaCov silently leaves it out. `spec/addon_load_spec.lua` loads the whole `.toc`.
- Test observable behavior: the lines and colors shown, saved settings, positions, what opens or closes. Don't test calls like `SetSize`; layout isn't asserted, except the window's size contract: the preview and every row label fit, in every language, and the scaled window and tabs fit within the screen bounds.
- Expected values (labels, names) are written in the spec, not copied from the code's tables, so typos are caught.
- When adding tests, check that they catch a real bug: change the code on purpose, see the right test fail, restore.

Coverage uses LuaCov, configured in `.luacov` (only `^StatsTrimmer/`). It runs with `luajit -joff`, because JIT-compiled code skips line hooks. On 2026-10-15 it was 100% of 1688 lines (465 of them the generated `FoodData.lua`) with 333 tests.

The tests cover the logic. Game-facing behavior still has to be checked in game.

## CI and releases

GitHub Actions, in `.github/workflows/`:

- `ci.yml` runs on every pull request, and by hand from the Actions tab:
  - `stylua --check .` (StyLua 2.5.2) and `luacheck .` (Luacheck 1.2.0);
  - `test.ps1` and `coverage.ps1` on Ubuntu's LuaJIT 2.1 with LuaCov 0.17.0;
  - `package.ps1`. The zip it builds is attached to the run as an artifact, to try a pull request in game.
- `release.yml` runs on every push to `main`, i.e. every merged pull request. It runs the same checks, then publishes a GitHub release if the `.toc` version has no tag yet:
  - the tag `v<version>`, on the merged commit;
  - `StatsTrimmer-v<version>.zip`: the `StatsTrimmer` folder, with `LICENSE` inside it;
  - as notes, that version's CHANGELOG section plus the installation steps.

  A push that doesn't change `## Version` publishes nothing.

To release a version, in its pull request:

1. Set `## Version: X.Y.Z` in `StatsTrimmer/StatsTrimmer.toc`.
2. Rename `## Unreleased` in `CHANGELOG.md` to `## vX.Y.Z (<date>)`.
3. Merge it.

The `.toc` version must always have a CHANGELOG section: `package.ps1` fails without one, so the pull request's CI catches it before the merge.

`package.ps1` builds the same files locally, in `.release/` (gitignored), from the committed files: commit first. When StyLua or Luacheck are updated locally, update their versions in `ci.yml` too.

## WoW API rules

- Verify every WoW API function, event, widget method, template and CVar before using it. Check it against the `forever` branch of [wow-ui-source](https://github.com/Gethe/wow-ui-source), starting with `Interface/AddOns/Blizzard_APIDocumentationGenerated/`.
- To search Blizzard's code, use a shallow clone (~34 MB): `git clone --depth 1 --single-branch --branch forever https://github.com/Gethe/wow-ui-source.git`. Check that `version.txt` matches the client build.
- Many Blizzard addons have `Mainline/`, `Classic/` and `Camelot/` subfolders; `Camelot/` holds Forever-specific code. Read the `.toc` to see which file actually loads for game type `camelot`. For example, the Addon Compartment is `mainline` only, so it doesn't exist in Forever.
- GlobalStrings (e.g. `ITEM_SPELL_TRIGGER_ONEQUIP`) are not in that repo. Check them in game with `/dump`.
- The `ketho.wow-api` annotations cover Retail/Classic in general. They are not proof that an API exists in Forever.
- Protected actions are blocked in combat (`InCombatLockdown()`). The restricted list is in `RestrictedActionsDocumentation.lua` on that branch.
- Forever addons worth reading: ForeverQuestTint, ForeverDungeonJournal, TalentsForeverBook. Multi-version addons use the `_Camelot` `.toc` suffix for Forever (e.g. `Prat-3.0_Camelot.toc`). Inside a single `.toc`, Forever-only files can be gated with `[AllowLoadGameType camelot]` (see BugSack's `.toc`).

## Code conventions

- Formatting is owned by `stylua.toml`: tabs, double quotes, 120 columns, LF.
- Luacheck runs with `std = "lua51"` and explicit globals. When code reads a new WoW global, add it to `read_globals` in `.luacheckrc`. Globals the addon writes go in `globals` (SavedVariables, `SLASH_*`, `SlashCmdList`).
- The AddOns list groups addons by the exact localized `## Category` value. Always add the `Category-<locale>` variants (see `StatsTrimmer.toc`), or the addon ends up in a separate English-named group on non-English clients.
- Get the addon name from `local addonName = ...`. SavedVariables are only populated once `ADDON_LOADED` fires for that addon, so initialize them there.

## Commits

Format `type(scope): message`, in English.

- `type` is one of `feat`, `fix`, `chore`.
- `scope` is always present. It is free-form and names what the change touches, e.g. `ui`, `tooltip`, `rules`, `luacheck`.

Example: `fix(tooltip): match spell power line on esES client`.
