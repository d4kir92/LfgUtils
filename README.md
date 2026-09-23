# LFG Utils

LFG Utils extends World of Warcraft's group finder with additional information and filtering options.

## Features

- Displays a language flag based on a player's realm.
- Displays class icons next to applicants.
- Shows the group leader's overall Mythic+ score.
- Shows the score and best completed key level for the selected dungeon.
- Adds role, class, and level filters to the Vanilla Style Group Finder in WoW Forever.
- Migrates existing LFG settings from ImproveAny once when available.

Features that depend on Mythic+ or the modern premade group finder are shown only on clients that provide the required APIs.

## Supported clients

- Retail
- Classic Era
- WoW Forever
- The Burning Crusade Classic
- Wrath of the Lich King Classic
- Cataclysm Classic
- Mists of Pandaria Classic
- Titan

## Installation

1. Copy the `LfgUtils` folder into your World of Warcraft `Interface/AddOns` directory.
2. Enable **LFG Utils** in the character-selection add-on list.
3. Log in or reload the user interface.

## Configuration

Enter `/lfgutils` in chat to open the settings window. All standard LFG enhancements are disabled by default and can be enabled individually.

On WoW Forever, the filter window opens automatically beside the Vanilla Style Group Finder while its browse tab is visible. It is docked to the group finder and cannot be moved. Its options are grouped into collapsible Role, Class, and Level categories, and the open or closed state of each category is remembered. A solo or group listing remains visible when at least one member matches the selected roles, classes, and level range. Solo players match by the roles they listed with; group members match by their assigned role. While all roles are selected, the role filter is inactive; once a role is deselected, players without a role are hidden.

Settings are saved account-wide.

## Localization

LFG Utils includes translations for all World of Warcraft client locales:

`deDE`, `enUS`, `esES`, `esMX`, `frFR`, `itIT`, `koKR`, `ptBR`, `ruRU`, `zhCN`, and `zhTW`.

## Author

D4KiR
