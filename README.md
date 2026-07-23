# StockPlusUI

A faithful overhaul of the default World of Warcraft user interface. Every
element, refined — the stock UI as it was meant to be, just better.

Built for **WotLK 3.3.5a** clients (Interface build `30300`), developed against
an AzerothCore local server.

## Design Philosophy

- **Ultra-lightweight & modular** — pure Lua and native WoW API. Minimal frame
  updates and memory footprint.
- **Faithful, not replaced** — enhances Blizzard's default UI rather than
  reskinning it. No taint, no protected-frame tampering.
- **Clean architecture** — logic and configuration live in dedicated modules,
  auto-registered through a lightweight core.

## Features

- **Action Bar Fading** — action bars fade out when idle and fade back in on
  combat, target, non-default health/power, or mouseover. Smooth alpha
  transitions, configurable faded opacity.
- **ESC Menu Integration** — a native-styled `StockPlusUI` entry in the Game
  Menu opens the config panel.

## Installation

1. Copy the `StockPlusUI` folder into
   `World of Warcraft/Interface/AddOns/`.
2. Restart the client or `/reload`.
3. Enable **StockPlusUI** on the character-select AddOns list.

## Configuration

- `/stockplus` or `/stockplusui` — open the options panel
- `/sui`, `/spui` — short aliases
- `/stockplus toggle` — toggle action bar fading
- Or open the panel from the **StockPlusUI** button in the ESC menu

Settings are saved per account via `StockPlusUIDB`.

## Project Structure

```
StockPlusUI/
├── StockPlusUI.toc            # manifest / load order
├── core.lua                   # addon table, event dispatcher, saved vars, slash cmds
├── config.lua                 # defaults + Interface options panel
└── modules/
    ├── action_bar_fader.lua   # auto-fade action bars by player state
    └── game_menu_button.lua   # ESC menu entry
```

Load order is defined in `StockPlusUI.toc`: `core.lua` first (it defines the
shared `SPU` table and module registry), then `config.lua`, then each file
under `modules/`. Modules self-register during load and initialize on
`ADDON_LOADED` once saved variables are available.

## Development

StockPlusUI uses a small module system. The core (`core.lua`) exposes a shared
`SPU` table with a lightweight event dispatcher, a saved-variable store, and a
module registry. Features register themselves and receive their own settings
sub-table on init.

### Adding a module

```lua
-- modules/my_feature.lua
local SPU = _G["StockPlusUI"]

local module = { name = "my_feature" }
SPU:register_module(module)

function module:on_init(settings)
    -- `settings` is this module's saved-variable sub-table (SPU.db.my_feature).
    -- Register only the events you need; they route through the shared frame.
    SPU:register_event("PLAYER_ENTERING_WORLD", function()
        -- ...
    end)
end
```

Then add the file to `StockPlusUI.toc` below the existing modules, and add its
defaults to the `defaults` table in `config.lua` so `on_init` receives populated
settings.

### Event handling

Modules do not create their own event frames. Instead they call
`SPU:register_event(event, fn)`; the core keeps one hidden frame and dispatches
each event to every registered listener. This keeps the frame count and memory
footprint minimal.

### Add-a-module checklist

1. Create `modules/<name>.lua` and `SPU:register_module({ name = "<name>" })`.
2. Implement `function module:on_init(settings)`.
3. Add a `<name>` defaults block in `config.lua`.
4. Add the file path to `StockPlusUI.toc` (after `core.lua` and `config.lua`).
5. Reload and verify with `/stockplus`.

### Code style

`snake_case` for all addon-authored identifiers — locals, functions, table
keys, and file names. Blizzard API globals, event strings, and template names
(for example `MultiBarBottomLeft`, `PLAYER_REGEN_DISABLED`,
`GameMenuButtonTemplate`) are left as-is; they are the API contract, not ours
to rename. The addon name and folder stay `StockPlusUI`.

### Taint safety

The addon only manipulates non-protected state. Action bar fading uses
`SetAlpha` / `UIFrameFade` (never `Show`/`Hide` on protected frames), and the
ESC menu button opens Interface Options without touching combat-restricted
frames. This avoids taint and "action blocked" errors, including in combat.

## Compatibility

- **Client:** WotLK 3.3.5a (build 30300)
- **Server:** AzerothCore (local development)

## Contributing

This is a personal project under active development. Issues and pull requests
are welcome. Please keep changes consistent with the design philosophy
(lightweight, faithful, modular) and follow the code style above. Commits use
the [Conventional Commits](https://www.conventionalcommits.org/) format
(`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).

## License

Licensed under the **GNU General Public License v3.0**. You may use, modify, and
distribute this software, but any distributed derivative must remain open source
under the same license and must preserve the original copyright and attribution
notices. See the [LICENSE](LICENSE) file for the full text.

Copyright (C) 2026 Michael Mulek
