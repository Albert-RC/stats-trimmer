# wow-addon

Addons for World of Warcraft: Forever (`## Interface: 16001`, Lua 5.1).

## Layout

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

## Workflow

Edit → `stylua --check .` and `luacheck .` → `/reload` in game → test.
Restart the client when adding files to the `.toc` or adding new addons.
Debugging: `/console scriptErrors 1`, `/etrace`, `/fstack`.
