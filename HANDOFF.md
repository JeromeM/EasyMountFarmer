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
- **Generate data**: `node scripts/build-data.mjs` → `EasyMountFarmer/Data/RouteData.lua` (global `EasyMountFarmerRouteData`)
  + `scripts/Locations.skeleton.lua`. Never overwrites `EasyMountFarmer/Data/Locations.lua` (hand-authored).
- **Validate**: `node scripts/check-lua.mjs` (luaparse, recursive). The `_encode/_decode` shell lines are harmless zsh noise.
- **Deploy**: `bash scripts/deploy.sh` → copies `EasyMountFarmer/` to `/mnt/d/Games/World of Warcraft/_retail_/Interface/AddOns/EasyMountFarmer`.
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
