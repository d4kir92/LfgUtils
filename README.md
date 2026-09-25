# LFG Utils

LFG Utils extends World of Warcraft's group finder with additional information and filtering options.

## Features

- Displays a language flag based on a player's realm.
- Displays class icons next to applicants.
- Shows the group leader's overall Mythic+ score.
- Shows the score and best completed key level for the selected dungeon.
- Adds role, class, and level filters to the Vanilla Style Group Finder in WoW Forever.
- Adds a filter and sorting window to the Retail premade group finder for dungeons, raids, delves, arenas, and rated battlegrounds.
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

On Retail, a filter window opens beside the group finder while the search results of a dungeon, raid, delve, arena, or rated battleground category are visible. Each category has its own window with collapsible sections:

- **Dungeons:** activities, difficulty, playstyle, minimum leader rating, has tank/healer, has tank or healer, has or hide Augmentation Evoker, has or hide Bloodlust/Heroism, hide groups with your specialization, and hide groups without room for your roles. Difficulty, playstyle, minimum rating, and has tank/healer use Blizzard's own advanced filter and start a new search.
- **Raids:** activities of the current or legacy list, bosses defeated, difficulty, playstyle, and tank/healer/damage count requirements.
- **Delves:** activities, tier range, groups with a ?/?? tier, and playstyle.
- **Arenas and rated battlegrounds:** activities, minimum leader PvP rating, and playstyle.
- **Sorting:** groups you have applied to can be moved to the top, and results can be sorted by up to two criteria instead of Blizzard's default order.

Groups you have applied to are never filtered out. The window is hidden and nothing is filtered while you have an active listing of your own.

Settings are saved account-wide.

## Localization

LFG Utils includes translations for all World of Warcraft client locales:

`deDE`, `enUS`, `esES`, `esMX`, `frFR`, `itIT`, `koKR`, `ptBR`, `ruRU`, `zhCN`, and `zhTW`.

## Author

D4KiR
