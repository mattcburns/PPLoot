# PPLoot

A lightweight World of Warcraft Classic (`_forever_`) addon that automatically loots when you use **Pick Pocket**, while leaving your normal loot behavior untouched for everything else.

## Features

- **Pick Pocket–only autoloot:** Keeps your global Auto Loot setting off for normal corpses, chests, and nodes, while automatically looting all slots whenever you cast Pick Pocket.
- **Safe by design:** Uses `LootSlot()` on `LOOT_READY` / `LOOT_OPENED` instead of toggling the `autoLootDefault` CVar, so Auto Loot can never get stuck on if you disconnect, reload, or get resisted.
- **Floating visual indicator:** Displays a clean center-screen floating message that drifts upward and fades out:
  - **Looted:** `Pickpocketed: 4s 12c, [Battered Junkbox]`
  - **Empty pockets:** `Nothing picked`
  - **Already looted:** `Already pickpocketed`
  - **Invalid target:** `No pockets to pick`
- **Persistent settings:** Preferences are saved across sessions via `PPLootDB`.

## Slash Commands

| Command | Description |
| --- | --- |
| `/pploot` | Toggle Pick Pocket autoloot on/off |
| `/pploot text` | Toggle the floating visual indicator on/off (`visual` and `indicator` also work) |
| `/pploot test` | Preview the floating visual indicator |
| `/pploot help` | Show current status and available commands |

## Installation

1. Download the latest `PPLoot-*.zip` from the [Releases](https://github.com/mattcburns/PPLoot/releases) page.
2. Extract the `PPLoot` folder into your WoW AddOns directory:
   ```
   World of Warcraft/_forever_/Interface/AddOns/PPLoot
   ```
3. Restart World of Warcraft and make sure **PPLoot** is enabled in the AddOns menu.

## License

[MIT](LICENSE)
