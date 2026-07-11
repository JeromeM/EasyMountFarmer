# Changelog

All notable changes to EasyMountFarmer are documented here.
This project follows [Semantic Versioning](https://semver.org).

## [0.2.3] - 2026-07-11

### Added
- **Built-in navigation arrow** — a self-contained on-screen 3D direction arrow, so
  TomTom is no longer needed. It's a pre-rendered sprite sheet, so the 3D perspective
  holds in every direction (including when it points back toward you), and its colour
  shifts with distance: **red** when far → orange → yellow → **green** when you're close.
- **Right-click the arrow** for a quick menu: arrow size, text size, and lock.
- **New options**: arrow-size, text-size and main-window-size sliders; a metric-distance
  toggle (yards ⇄ m/km); and "Lock the arrow position" (locked = click-through).

### Changed
- **Dropped the TomTom dependency.** The map/minimap pin now uses the native Blizzard
  waypoint and the on-screen arrow is our own. TomTom is no longer referenced anywhere
  (it can stay installed — it's simply ignored).
- The arrow's text shows the **target name** (amber) above the current **routing step**,
  then the distance.
- **Minimap button**: right-click now opens the **settings** (progress re-sync moved to
  the `/emf reset` command).
- **Settings** are grouped into **Navigation / Window / Loot** sections.

## [0.2.2] - 2026-07-10

### Changed
- The filter now shows only **Dungeons, Raids, World bosses and Trash**. Open-world
  drops (rare enemies / seasonal events / vendors / treasures) are hidden for now
  (their data is kept and will come back later).

### Fixed
- The window no longer breaks its layout when you use Prev/Next **in combat** — it
  holds updates during combat and reflows once combat ends.
- **Closing the window now removes its waypoint arrow** (TomTom or the Blizzard pin),
  and it is re-placed when you reopen the window.

## [0.2.1] - 2026-07-10

### Added
- Mount tooltips in the main window now show the mount's **expansion** and **where it
  drops** (boss · instance, or vendor / region for open-world mounts).
- **Ctrl + click** a mount row to open its **3D preview** (dressing room).

## [0.2.0] - 2026-07-10

### Added
- **Filters**: a new *Filters* button on the window opens a checklist to include or
  exclude whole **categories** (Dungeons, Raids, World bosses, Trash, Rare enemies,
  Seasonal events, Vendors, Treasures, Achievements) and individual **expansions**.
- **World mount sub-categories**: open-world drops are split into Rare enemies,
  Seasonal events, Vendors and Treasures (the vendor's name is shown).
- **"Lock the window position"** option.

### Changed
- **Mount database is now generated in-game** from the Encounter Journal (no external
  dependency), replacing the SimpleArmory planner import.
- **Curated route order**: a hand-tuned visiting sequence — Return to Karazhan sits
  next to Karazhan, **Ny'alotha follows its weekly moving portal** (Uldum or Pandaria
  depending on the week), and world rares in a stop's zone appear right after it.
- **Difficulty and reset cadence are derived automatically** from the data.
- **UI**: removed the old "manual route" box; centered the mount counter with the
  Filters button on its right.

### Fixed
- **Navigation / waypoints** now work for the many instances where the entrance map
  was not being resolved.
- **Corrected the mount IDs** for the Ahn'Qiraj battle tanks and the Amani Battle Bear.
- Fixed a **login error** (a nil `IS_WORLD`) and the **Filters panel opening off-screen**
  when the window sits against the right edge.

### Known limitations
- Open-world mounts (rares / treasures / vendors) have no coordinates yet — they are
  filterable and listed by zone, but there is no guidance arrow to them.
- Achievement-reward mounts are not collected yet (the "Achievements" filter is empty).

## [0.1.0]

Initial release: in-game, one-step-at-a-time mount-farming route with auto-hide of
collected mounts, auto-advance on boss kill, loot popup, reset handling, lockout
detection, difficulty switching, and waypoint guidance (TomTom or Blizzard, with
optional FarstriderLib turn-by-turn).
