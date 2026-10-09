# wow-addon

Addons for World of Warcraft: Forever (`## Interface: 16001`, Lua 5.1).

## Layout

- `EasyStats/`: rewrites verbose equip lines in item tooltips into compact ones, e.g. `≤10 spell power` / `≤30 healing power`. Works on any client locale. Settings (a color per line kind with a live preview, and the key that shows the original text) open from the minimap button, which MinimapButtonButton also collects, or from Options > AddOns > Easy Stats.
- `HelloForever/`: test addon. Shows a button that prints to chat and stores the click count in `HelloForeverDB`. `/helloforever` shows or hides it.

Each addon folder is linked into the client through a directory junction; the rest of the repository never reaches the game.

## Linking an addon into the client

Forever client: `F:\World of Warcraft\_classic_beta_\`. In `cmd`:

```bat
mklink /J "F:\World of Warcraft\_classic_beta_\Interface\AddOns\HelloForever" "C:\Users\alber\Documents\Github\wow-addon\HelloForever"
```

To remove the link without deleting the code: `rmdir "F:\World of Warcraft\_classic_beta_\Interface\AddOns\HelloForever"`.

## Tools

- VS Code + `sumneko.lua` (LuaLS) + `ketho.wow-api` + `JohnnyMorganz.stylua`
- StyLua (`stylua .`) and Luacheck (`luacheck .`)
- In-game: BugSack + !BugGrabber to capture Lua errors

## Tests

The pure logic (e.g. `EasyStats/Util.lua`, `EasyStats/Rules.lua`) has unit tests in `spec/`, written in busted syntax. They run with LuaJIT and a small busted-compatible runner:

```powershell
winget install --id DEVCOM.LuaJIT -e   # once
./scripts/test.ps1
```

Game-facing code is tested against a small fake of the WoW API (`spec/fakes.lua`).

Coverage uses [LuaCov](https://github.com/lunarmodules/luacov) 0.17.0, which is pure Lua. Copy its `src/` folder to `%LOCALAPPDATA%\Programs\luacov` once, then run:

```powershell
./scripts/coverage.ps1   # fails if EasyStats/ line coverage is below 85%
```

## Workflow

Edit → `stylua --check .`, `luacheck .` and `./scripts/test.ps1` → `/reload` in game → test.
Restart the client when adding files to the `.toc` or adding new addons.
Debugging: `/console scriptErrors 1`, `/etrace`, `/fstack`.
