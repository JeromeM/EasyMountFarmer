# EasyMountFarmer — Development Handoff / Context

Resume-context doc. (User speaks **French**; write **all code in English** — comments, UI strings, messages.)
Display name, folder, slash (`/emf`, `/easymountfarmer`), and all globals/saved vars are **EasyMountFarmer**.
(Renamed from the old id **SAMounts** — the "Simple Armory" name could not be used. `Core.lua` has a one-time
`importOldSavedVars()` that copies old `SAMountsDB`/`SAMountsCharDB` if the old addon is still installed during transition.)

## What & where
- WoW **retail, Midnight (patch 12.x)** addon. Slash **`/emf`** / `/easymountfarmer`.
- Ports SimpleArmory's mount-farming planner in-game: shows **one uncollected mount target at a time**,
  guided, auto-skips what's already done (collected / locked this reset / world-boss quest done).
- Repo: **`/apps/perso/EasyMountFarmer`** (git). Addon folder: `EasyMountFarmer/` (copied into `Interface/AddOns`).
- Derived from `/apps/perso/SimpleArmory` (`static/data/planner.json`).

## Build / deploy / validate (from repo root)
- **Build data**: `node scripts/build-mounts.mjs` transforms `data/mounts-export.lua`
  (the `/emf gen` snapshot) → `Data/MountsInstances.lua` + `Data/MountsWorld.lua`.
  Hand data (`Data/ExtraMounts.lua`, `Data/Overrides.lua`) is never overwritten.
- **Validate**: `node scripts/check-lua.mjs` (luaparse, recursive). The `_encode/_decode` shell lines are harmless zsh noise.
- **Deploy (dev)**: `bash scripts/deploy.sh` → copies `EasyMountFarmer/` to `/mnt/d/Games/World of Warcraft/_retail_/Interface/AddOns/EasyMountFarmer`.
- **Package (public)**: `bash scripts/package.sh` → `EasyMountFarmer-<version>.zip` at the repo
  root (CurseForge layout), data baked in, `Tools/Generator.lua` + `/emf gen` + the
  `EasyMountFarmerGen` saved var stripped. (`build/` and the zip are gitignored.)
- Can't run WoW here → user tests. Code-only change = `/reload`; new file or `.toc` change = full client restart.

## Folder structure (load order matters, set in EasyMountFarmer.toc)
`Core/` (Locale.lua, Core.lua) · `Locales/` (enUS.lua, frFR.lua) · `Data/` (RouteData.lua, Locations.lua) ·
`Modules/` (Route, Progress, Lockouts, Difficulty, Detect) · `Navigation/` (Waypoint, Travel, Nav) · `UI/` (UI, MinimapButton).
.toc order: Core\Locale, Locales\enUS, Locales\frFR, Data\RouteData, Data\Locations, Modules\Route, Modules\Progress,
Modules\Lockouts, Modules\Difficulty, Modules\Detect, Navigation\Waypoint, Navigation\Travel, Navigation\Nav, UI\UI, UI\MinimapButton, Core\Core.

## Files & roles
- **Core/Locale.lua** — `ns.L` (metatable → returns the key if untranslated), `ns.Print`.
- **Locales/enUS.lua** — every English key. **Locales/frFR.lua** — French values (guarded `if GetLocale()~="frFR"`),
  incl. a **route-steps section** (breadcrumb labels) and **instance-name overrides** (e.g. `L["Dawn of the Infinites"]="Aube de l'Infini"`).
- **Data/RouteData.lua** — GENERATED. **Data/Locations.lua** — hand-authored per run (key = English run title):
  `map,x,y` (entrance 0–100), `instanceId` (**primary lockout key** = GetSavedInstanceInfo 14th = GetInstanceInfo 8th),
  `lockout` (English name, fallback only — **useless on frFR clients**), `questId` (world boss), `reqDiff`+`diffScope`,
  `encounters` (`[mountSpellId]=DungeonEncounterID`), `lowPriority`.
- **Modules/Route.lua** — `BuildTargets()` (flatten, prune collected + wrong-faction, keep breadcrumb).
  `ns.RouteHops` (English hop label → `{v=verb, m=uiMapID}`) + `ns.LocalizeHop(label)` (zone name via `C_Map.GetMapInfo`,
  verb via L template; falls back to hand string / English).
- **Modules/Progress.lua** — the one-step engine. `ns.activeTargets` = ALL targets with uncollected mounts (done-this-reset
  ones STAY, shown with a marker; only a **collected** mount removes a step). `ns.autoFollow` (session) + `ns.db.autoAdvance`
  (pref) → `AutoFollowing()`; while true the pointer auto-snaps to `FirstUndoneIndex()`. `Next/Prev` turn autoFollow off.
  `MarkDone(key,ptype,source)` (source "kill"/"lock"/"manual"; sets `ns.leaveInstanceHint` if kill/manual while `IsInInstance()`;
  uses `ResetTypeFor`). `ResetTypeFor` → **mythic dungeon (reqDiff 23) locks WEEKLY** like raids, not daily. `AdvanceToNextUndone`.
  `ResetAllDone` = **re-sync (no wipe)**: autoFollow on + RequestRaidInfo + Rebuild(true). `CheckResets` (native daily/weekly timers).
- **Modules/Lockouts.lua** — scans GetSavedInstanceInfo, matches by **instanceId** (name fallback), **skips the current instance**
  (you may be mid-run), marks done via ResetTypeFor. Runs on PLAYER_ENTERING_WORLD / UPDATE_INSTANCE_INFO / BOSS_KILL.
- **Modules/Difficulty.lua** — NeedsSwitch/SwitchTo; keystone(8) satisfies mythic(23).
- **Modules/Detect.lua** — ENCOUNTER_END (success + encounterID match + difficulty ok, **keystone 8 satisfies mythic 23**)
  → MarkDone("kill"). NEW_MOUNT_ADDED → loot popup (if `db.lootPopup`) + **chat announce with mount spell link** (if `db.lootChannel`~="NONE")
  + Rebuild. `/emf enc` debug prints encounterID on any kill.
- **Navigation/Waypoint.lua** — `SetTo(map,x01,y01,title)` / `GuideTo(target,silent)` / `Clear()`. TomTom if present AND
  `db.useTomTom`, else Blizzard user waypoint. Tracks its own waypoint so Clear only removes ours. Also owns
  **`ns.EntranceFor(key)`** — the shared entrance resolver (0-100): live from the Encounter Journal when the run defines
  `entranceJID`+`entranceMaps` (moving portals — see learnings), else static `Locations` coords. Nav AND Waypoint both use it.
- **Navigation/Travel.lua** — the **docked secure action button**. Parented to **UIParent** (so the window has no protected
  child and can move/resize freely) but **anchored to the action panel** (a Frame) so it sits inside the window.
  `Ensure(panel)`, `ShowAction(kind,id,labelOverride)` (sets `Travel.active`+`Travel.label`; defers attrs/show in combat),
  `Hide()`. Anchoring to a Frame (NOT a region) out of combat is what makes docking work.
- **Navigation/Nav.lua** — FarstriderLib router. `Available()`, `Update(target)`: resolves coords via `ns.EntranceFor(key)`
  then `FindTrailTo(map, x/100, y/100, 0)` → render step[1]: item/spell action → button; else → arrow (`Waypoint.SetTo`),
  **always falls back to the entrance waypoint** if the hop has no usable loc. Returns false only when the target has no coords.
  Note: FarstriderLib **routes to the coords WE give it** — it does not pick entrances; a wrong/faction-hostile hop
  (e.g. an Orgrimmar portal for an Alliance player) is the symptom of a wrong destination coord, not a router bug.
- **UI/UI.lua** — the flat card. Header (icon [click→`ToggleCollectionsJournal(1)`] + centered title + **gear**⚙ + close×),
  step/count, **ROUTE box** (bullet list via LocalizeHop), **two-line headline** (dim action line "Faire le donjon" + big amber
  localized instance/boss name), boss rows (icon+mount+boss+diff badge), diff-switch button, Prev/Done/Next (right-click ‹/› =
  ResetPointer). Localization helpers: mount name (journal), instance/boss (mount **source text** — strip `|c…|r` color codes &
  `|T…|t`, split on `|n`, capitalize first ASCII letter; world boss uses source line 1 = boss, else line 2 = instance).
  Done step → dim rows + green "Terminé ce reset" marker. Leave-instance panel (hearthstone item 6948 + "Sortir de l'instance /
  Pierre de foyer") shows when `inInstance and ns.leaveInstanceHint` (no FarstriderLib needed). **"Wait for reset" step**: when
  auto-following AND `not AnyUndone()` (everything done this reset but mounts remain), Refresh short-circuits to a dedicated screen
  ("Tout est fait pour ce reset" + guidance + the relevant countdown(s) via `pendingResets()`/`f.waitInfo`); ‹ still browses done steps. **Settings = native game panel**:
  `UI.BuildSettings()` (Settings.RegisterVerticalLayoutCategory + RegisterProxySetting + CreateCheckbox/CreateDropdown),
  `UI.OpenSettings()` (Settings.OpenToCategory). Options: autoAdvance, useTomTom (only if TomTom loaded), lootPopup,
  lootChannel dropdown (NONE/PARTY/RAID/GUILD), autoGuide, showMinimap. Window pos + open/closed state persist (`db.pos`, `db.shown`).
- **UI/MinimapButton.lua** — self-contained. Left-click toggle, right-click ResetAllDone.
- **Core/Core.lua** — saved-var init/defaults (autoGuide, shown, autoAdvance, useTomTom, lootPopup, lootChannel="NONE",
  minimap); onLogin (Init, BuildSettings, Minimap.Init, CheckResets, ResetPointer, restore shown); events; 30s ticker;
  slash `/emf` (toggle|next|prev|guide|reset|minimap|arrow|debug|**nav**|**enc**|help).

## Key technical learnings (do NOT relearn)
- **Mount source text carries color codes** (`|cff…|r`) and uses **`|n`** as line separator. MUST strip codes + split on `|n`,
  else names show wrong-colored and lowercase (capitalize sees `|`). This was a real bug.
- **Capitalize** only the first byte if ASCII a–z (UTF-8 safe; don't corrupt accented first letters).
- **Secure buttons**: cannot anchor to a **region** (fontstring/texture) — only to a **Frame**, out of combat. Docked button =
  parent UIParent + anchor to the panel Frame; defer SetAttribute/Show/Hide in combat.
- **Lockouts are locale-proof only via `instanceId`** (GetSavedInstanceInfo 14th == GetInstanceInfo 8th). The English `lockout`
  name never matches on a frFR client. **Every run needs an `instanceId`** or it won't be detected as done for non-enUS users.
- **Keystone difficulty is 8, Mythic-0 is 23** — ENCOUNTER_END on an M+ run reports 8; treat 8 as satisfying a reqDiff of 23
  (in Detect AND Difficulty). **Mythic dungeons lock WEEKLY** (ResetTypeFor → "WeeklyDungeon").
- **FarstriderLib** covers most zones (incl. Zuldazar). If `Update` shows nothing, it's usually the run being an **undetected
  lockout** (missing instanceId) — the addon was guiding to already-done instances. FarstriderLib IS faction-aware (its
  connections are guarded by `UnitFactionGroup("player")`) and only routes to the destination coord we pass to `FindTrailTo`.
- **FarstriderLib can return an unusable enemy-faction route** (its bug, not ours). `FindTrailTo` has **no faction param** —
  FarstriderLib reads `UnitFactionGroup` itself. CONFIRMED via `/emf route` for an **Alliance** player → **Utgarde Pinnacle**
  (Northrend): it returns a 3-hop chain of Horde Undercity zeppelins ("Grom'gol → Ruins of Lordaeron → Howling Fjord"), all
  `actions=[]` (pure travel it chose itself), which Alliance can't even take. The Kirin Tor ring (44935) was owned/usable/off
  cooldown (verified with the `/emf route` item dump) — FarstriderLib still won't use it, because the ring lands you in **Dalaran
  (Crystalsong)** and its graph **can't complete Dalaran → Howling Fjord**, so it picks the cheaper direct-but-Horde chain. Our
  request is byte-identical to before the rename → provably not us. **Decision (user): do NOT build any workaround** — we use
  FarstriderLib and nothing else. This is a FarstriderLib bug, **reported upstream via a GitHub ticket**; the fix belongs there.
  Two dead-ends were tried and fully reverted (don't revisit): (1) `skipRouterFor` = plain-arrow fallback — the entrance arrow is
  useless off-continent; (2) a `gateway`/`GATEWAYS` mini-router offering the Kirin Tor ring button — rejected as a bespoke nav
  system for one case. Nav.lua stays pure FarstriderLib. Diagnostic kept: **`/emf route`** dumps FarstriderLib's chosen steps +
  your Kirin Tor/Dalaran item usability (handy for the upstream ticket).
- **Moving instance entrances** (e.g. **Ny'alotha**, whose raid portal follows the weekly N'Zoth assault between the Vale of
  Eternal Blossoms `1530` and Uldum `1527`): the game's **`C_EncounterJournal.GetDungeonEntrancesForMap(uiMapID)`** lists an
  instance's entrance **only on the map where the portal physically is that week** (confirmed: `/emf entrance` in the Vale shows
  Ny'alotha jID=1180 at 40.0/45.6; in Uldum it shows nothing). So a run can set `entranceJID` + `entranceMaps={...}` and
  `ns.EntranceFor` resolves the live entrance each week — self-tracking, faction-neutral, zero maintenance. This also removed the
  bogus Orgrimmar-portal routing (caused by the stale Uldum coord). `map/x/y` stays as the fallback. Reusable for any moving portal.
- Settings: mirror **Overachiever2** (`/mnt/d/.../AddOns/Overachiever2/Options.lua`) for the Settings API; **Syndicator** uses canvas.

## Backlog / TODO (priority)
1. **Fill missing `instanceId`s in Data/Locations.lua** — the big one. Many runs lack it → not skipped on frFR. Capture via
   `/emf debug` while locked (prints `instanceId=…`). Added this session: King's Rest 1762, Operation Mechagon 2097.
2. **Fill missing/verify `encounterID`s** — needed so a mount-boss kill sets `leaveInstanceHint` + auto-advances (else it only
   advances via lockout scan and the "leave" panel doesn't fire). Capture via `/emf enc`.
3. Verify uncertain frFR zone names in the route-steps section (user corrected several already).
4. Optional (user unsure): addon-side **attempt counter** (game gives no per-mount stat) — count kills, show in announce/card.
5. UI polish if desired.

## Diagnostics (slash)
- `/emf debug` — saved instances (name + instanceId=info[14]) + current step's expected lockout.
- `/emf enc` — toggle: print encounterID/name/diff on every boss kill.
- `/emf nav` — prints FarstriderLib available / inInstance / autoGuide / cur / done / Travel.active / leaveInstanceHint.
- `/emf entrance` — lists the instance entrances the game reports on the CURRENT map (name + jID + map/x/y), via
  `C_EncounterJournal.GetDungeonEntrancesForMap`. The source of truth for a run's coords; used to fill `entranceJID`/`Locations`.

## Reference addons on disk (study only, ARR-licensed)
`FarstriderLib`/`FarstriderLibData` (router we call), `TomTom` (optional arrow), `Overachiever2` (Settings API pattern), `Syndicator`.

## Mount-data pipeline (INTEGRATED — replaced SimpleArmory planner.json)
Our own data, generated in-game, with an optimized visiting order (expansion → zone →
proximity). **RouteData.lua + Locations.lua are GONE** (git-removed); the addon now runs
entirely off the generated data + a slim hand-authored override layer.

- **`Tools/Generator.lua`** (`/emf gen`, DEV-ONLY) walks the Encounter Journal → every
  dungeon/raid/world-boss mount drop, tagged with expansion, encounterID, difficulties,
  faction, location (zone/continent/entrance x,y). Also lists orphans (world rares / trash)
  via source-label match. Writes saved var `EasyMountFarmerGen`. Async loot + item-cache
  polling; iterates all difficulties.
- Flow: `/emf gen` → `/reload` → snapshot `WTF/.../EasyMountFarmer.lua`'s Gen table into
  repo `data/mounts-export.lua` → `scripts/build-mounts.mjs` (luaparse) emits:
  - **`Data/MountsInstances.lua`** (`EasyMountFarmerInstances`, GENERATED) — 65 mounts,
    each: category, expansion, continent/zone, x/y, instance, journalInstanceID, boss,
    encounterID, mountID, spellID, itemID, mount, faction, difficulties, order.
  - **`Data/MountsWorld.lua`** (`EasyMountFarmerWorld`, GENERATED) — world rares (filter-gated off by default).
  - **`Data/ExtraMounts.lua`** (`EasyMountFarmerExtra`, HAND) — AQ tanks + Amani bear
    (trash, no encounterID), now carrying instanceId + entrance coords.
  - **`Data/Overrides.lua`** (HAND) — the IRREDUCIBLE runtime overrides the EJ can't
    generate: `EasyMountFarmerInstanceInfo[journalInstanceID]` = { instanceId, lowPriority,
    entranceJID/entranceMaps, map/x/y (only where the generator captured none), encByMount
    (encounterID the generator missed, e.g. Sethekk/Anzu 185→1904) };
    `EasyMountFarmerWorldBossInfo[mountID]` = { questId, map/x/y }.

### Integration model (Route.lua)
- `Route.BuildTargets()` groups the generated data into FULLY-ENRICHED targets and every
  other module reads fields off the target (no more Locations lookups):
  dungeon/raid → 1 target per journalInstanceID (`key="i:"..jid`); world boss/rare →
  1 per mountID (`key="m:"..mountID`); trash → 1 per instance (`key="x:"..instance`).
- **Difficulty is DERIVED** from `difficulties`: a single non-Normal diff → forced switch;
  multiple → none. Per-instance = the single distinct reqDiff among still-needed mounts
  (adapts as mounts get collected; e.g. Obsidian Sanctum 10/25 → no switch).
- **Reset type** from category+reqDiff: mythic dungeon (23) → WeeklyDungeon; raid/trash/WB → weekly; else daily.
- Legacy (unobtainable) mounts and collected/wrong-faction mounts are pruned. lowPriority (Stratholme) sorts last.
- Validated by simulation: **53 farmable targets** (17 dun / 28 raid / 6 WB / 2 trash), 69 mounts.

### Known data gaps (report to user; not integration bugs)
- **Quantum Courser** (Dawn of the Infinites) has no mountID yet → its target is silently dropped. Refetch on next `/emf gen`.
- **Stonevault Mechsuit** and **Culling of Stratholme Bronze Drake** are MISSING from the
  generated data (Stonevault: a gen cache miss — should reappear on re-gen; Bronze Drake:
  timed-mob drop the EJ never lists → needs a hand ExtraMounts entry once we have its mountID).
- 11 instances have no `instanceId` yet (mythic dungeons + recent raids) → lockout auto-skip
  relies on the localized-name fallback / kill-detection for those. Fill via `/emf debug` while saved.

### Manual order (DONE — the user hand-specified the exact tour)
- `EasyMountFarmerOrder` in Overrides.lua = an ordered list of target keys ("i:"..jid /
  "m:"..mountID / "x:"..instance). When present it OVERRIDES the geographic auto-order
  (`Route.orderManual`); unlisted targets fall to the end. No player-rotation (fixed order).
- Conditional entries `{ key, entrance = <uiMapID> }` claim their slot only when the run's
  live entrance is on that map — used so **Ny'alotha appears near Uldum on Uldum weeks
  (slot 16) and near Pandaria on Vale weeks (slot 24)**, resolved via `liveEntranceMap`.
- **BUG FIXED**: `target.map` was nil for all generated instances (the generated field is
  `zone`, not `map`) — broke nav/waypoints. Now `map = info.map or first.map or first.zone`.
- Cross-checked vs SimpleArmory: Ascendant Skyrazor = "Rasoir-céleste ascendant" (in Nerub-ar),
  Wick = "Mèche" (in Darkflame Cleft) — both already included. Bronze Drake = "Drake bronze"
  (mountID 248) is a world rare (Culling of Stratholme). Smoldering Ember Wyrm (Nightbane, RtK)
  is NOT in the generated data (summoned event boss) — TODO: a "special events" zone with
  instructions (user idea, later).

### World-drop sub-categories (DONE — source-text classified)
- build-mounts `classifyWorld` splits world drops into **rare (153) / treasure (21) /
  vendor (5) / event (6)** from the source text; `parseVendor` stores the vendor NAME.
  `achievement` category exists but is EMPTY — achievement-reward mounts aren't "Butin :"
  drops so the generator never collected them (needs a generator change + re-gen to add,
  ideally with the achievement ID so the card can open the Achievements window).
- Route: `WORLD_CATEGORIES`/`IS_WORLD` — these share reset ("WorldRare") + zone-slot
  ordering. Each defaults OFF in the filter. UI filter lists all 5; card headline shows
  "Rare enemy/Treasure/Vendor/Seasonal event · <vendor> · <region>".
- **NO COORDINATES**: the source text has none, so world rares still can't be navigated to
  (no TomTom arrow). Getting coords needs an external source (Wowhead / a coords addon like
  HandyNotes/RareScanner) or a region→uiMapID table for zone-level waypoints. PENDING a decision.

### World rares slotted by zone (DONE)
- build-mounts parses the "Région/Zone/Lieu : X" out of each rare's source into `zoneName`.
- `orderManual` slots a world rare right AFTER the listed stop in the SAME zone (rank + 0.5).
  24/185 rares match a stop's zone (e.g. Terremine ×8 → Liberation of Undermine, K'aresh ×3 →
  Tazavesh, Jungle de Tanaan ×3 → Hellfire Citadel). The other 161 (region with no stop, or
  no region at all — festivals/vendors/treasures) stay grouped at the end when world rares are on.
- Possible follow-up (Tier 2): a region→expansion table to group the remaining rares near their
  expansion's stops (data has only a region NAME, no coords, so true proximity is limited).

### Ordering + rotation (auto fallback — runtime, Route.lua; used only when no manual order)
- `Route.OrderTargets` orders expansion (portal hubs) → continent → intra-continent
  nearest-neighbour on REAL world coords (`C_Map.GetWorldPosFromMapPos`), so adjacent
  zones cluster and **world bosses are placed in their zone** (they now have coords via
  `EasyMountFarmerWorldBossInfo`). Targets with no resolvable world pos (world rares) fall
  to the end of their expansion. Degrades to generated `order` if the map API is unavailable.
- **Rotation**: `Route.ComputeStart()` picks the expansion holding the target nearest the
  player and caches it in `ns.rotateExpansion`; OrderTargets rotates the expansion-block
  sequence to lead with it (stable across rebuilds; recomputed on login + window open).
  Can't be simulated offline (needs live world coords) — verify in-game.
- User chose "auto then I adjust": the auto baseline is geographic; fine-tune later with
  small per-expansion/zone overrides if a sequence is off (e.g. their ideal Pandaria order).

### Remaining TODO (deferred, user's call)
1. **World-rare coordinates / navigation** — rares have no coords (source text has none), so
   no waypoint/arrow for them. User chose "later"; options captured above (coords addon import /
   zone-level waypoint / Wowhead scrape).
2. **Achievement mounts** — extend `Tools/Generator.lua` to also collect achievement-reward
   mounts (with their achievement ID → clickable card), then re-gen. The "achievement" filter
   category already exists (empty for now).
3. **Nightbane / special-event mounts** (Smoldering Ember Wyrm) — a "special events" zone with
   ritual instructions (user idea).
4. **Quantum Courser** (Dawn of the Infinites) + **Stonevault Mechsuit** — refetch via `/emf gen`.

### Done this pass
- Full data-model swap (above). Removed the "manual route" breadcrumb box from the UI.
- Added a window **lock** button (padlock in the header; `ns.db.locked` gates dragging).
- **Category + expansion filter** — a "Filter" button in the header opens an in-window
  checklist popup (`UI.BuildFilterPanel`/`ToggleFilter`, flat check rows) with Dungeons/Raids/
  World bosses/Trash/World rares + one row per expansion; each flips `ns.db.filter` and rebuilds.
  (NOT in the game Settings panel — the user wanted it in the main UI.)
- Window **lock** button restyled: the game's clean LFG padlock icon (desaturated when unlocked).
- **Geographic ordering + player rotation** (above).
- **Fixed the Ahn'Qiraj / Amani mountIDs** in ExtraMounts — they were ALL shifted by one
  (110 was Swift Razzashi Raptor!). Correct: Qiraji tanks blue 117 / red 118 / yellow 119 /
  green 120 / black 122 (legacy), Amani Battle Bear 419. `EXTRA_MOUNT_IDS` in build-mounts fixed to match.
