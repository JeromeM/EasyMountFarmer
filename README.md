# EasyMountFarmer

A World of Warcraft addon (retail / Midnight, patch 12.x) that turns mount farming into an
**in-game, one-step-at-a-time route**: it shows the next dungeon, raid, world boss or rare to
visit for a mount you're still missing, and gets out of your way once you've collected it.

## Features

- **One target at a time** — the current stop, its still-needed mounts, and how to get there.
- **Auto-hides collected mounts** via `C_MountJournal` (a mount you own never comes back).
- **Auto-advances** when you kill the boss (`ENCOUNTER_END`, only on a difficulty where the
  mount can drop; a Mythic Keystone counts for a Mythic requirement).
- **Loot popup** when a mount drops (`NEW_MOUNT_ADDED`), with an optional chat announcement
  (party / raid / guild) that includes the mount link.
- **Reset-aware** — daily for dungeons, weekly for raids, Mythic dungeons and world bosses;
  already-locked instances (`GetSavedInstanceInfo`) and done world-boss quests are skipped, and
  the pointer snaps back to the first thing still to do. A **"wait for reset"** screen with
  countdowns shows when everything is done for the reset.
- **Difficulty button** — one click to switch to the required difficulty (Heroic / Mythic /
  10-25 legacy) when it differs from yours.
- **Waypoint guidance** to the entrance (TomTom if installed, otherwise the Blizzard waypoint),
  with live turn-by-turn when **FarstriderLib** is present (portals / flight paths / teleports,
  shown as a clickable action or an arrow). Everything still works without FarstriderLib.
- **Filters** — a *Filters* button on the window opens a checklist to include/exclude whole
  **categories** (Dungeons, Raids, World bosses, Trash, Rare enemies, Seasonal events, Vendors,
  Treasures, Achievements) and individual **expansions**. Open-world drops are off by default.
- **Curated route order** — a hand-tuned visiting sequence (grouped by expansion, kept
  geographically sensible), with a few nice touches: Return to Karazhan sits next to Karazhan,
  **Ny'alotha follows its weekly moving portal** (near Uldum or near Pandaria depending on the
  week), and world rares in the same zone as a stop ride along right after it.
- **Options** in the game's native Settings panel (auto-advance, TomTom, loot popup + channel,
  auto-guide, minimap button, lock the window position).

## Installation

Copy (or symlink) the `EasyMountFarmer/` folder into
`World of Warcraft/_retail_/Interface/AddOns/`, then `/reload` in game.

Open the window with `/emf` (or `/easymountfarmer`). Handy commands:

| Command | Action |
| --- | --- |
| `/emf` | open / close the window |
| `/emf next` · `/emf prev` | navigate steps |
| `/emf guide` | set a waypoint to the current step |
| `/emf reset` | re-sync to the first step still to do |
| `/emf minimap` | toggle the minimap button |
| `/emf arrow` | toggle the auto waypoint arrow |
| `/emf help` | full command list |

## Data & development

The mount data is **generated in-game** from the Encounter Journal, then transformed into the
Lua data files the addon ships with. There is no external website dependency.

Pipeline (developer machine):

1. `/emf gen` in game walks the Encounter Journal for every dungeon / raid / world-boss mount
   drop (expansion, encounter, difficulties, faction, entrance location) plus the world "drop"
   orphans, and writes the `EasyMountFarmerGen` saved variable.
2. Copy that saved-var table into `data/mounts-export.lua`.
3. `node scripts/build-mounts.mjs` transforms it into:
   - `EasyMountFarmer/Data/MountsInstances.lua` — dungeon / raid / world-boss mounts.
   - `EasyMountFarmer/Data/MountsWorld.lua` — open-world drops (rare / event / vendor / treasure),
     each tagged with its zone and, for vendors, the vendor name.

Two files are **hand-authored** and never overwritten by the build:

- `EasyMountFarmer/Data/Overrides.lua` — the irreducible bits the Encounter Journal can't
  provide: lockout ids, world-boss weekly quest ids, moving-portal entrances, a few entrance
  coordinates, and the curated visiting order (`EasyMountFarmerOrder`).
- `EasyMountFarmer/Data/ExtraMounts.lua` — trash / timed-reward mounts with no boss encounter
  (Ahn'Qiraj battle tanks, Amani Battle Bear).

Other scripts:

- `node scripts/check-lua.mjs` — validate every `.lua` file (via `luaparse`).
- `bash scripts/deploy.sh` — copy the addon into your `Interface/AddOns` (dev).
- `bash scripts/package.sh` — build the public CurseForge zip (`EasyMountFarmer-<version>.zip`)
  with the data baked in and the in-game generator (`Tools/Generator.lua`, `/emf gen`) stripped
  out. **The generator is developer-only and is not distributed.**

## Localization

Every user-facing string goes through a locale table (`ns.L`, set up in `Core/Locale.lua`).
English (`Locales/enUS.lua`) is the reference; French (`Locales/frFR.lua`) is provided. To add a
language: copy `Locales/enUS.lua`, guard it with `if GetLocale() ~= "xxXX" then return end`,
translate the values, and add the file to `EasyMountFarmer.toc`. Missing keys fall back to the
English text automatically.

## Known limitations

- **Open-world mounts (rares / treasures / vendors) have no coordinates yet** — they can be
  filtered and are listed with their zone, but there is no waypoint/arrow to them. Achievement
  mounts aren't collected yet either. These are planned improvements.

## Credits

Route concept inspired by [SimpleArmory](https://simplearmory.com)'s mount planner; all in-game
data is generated locally from the Encounter Journal.
