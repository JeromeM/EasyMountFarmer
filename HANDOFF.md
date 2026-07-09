# SAMounts — Development Handoff / Context

Resume-context doc. (User speaks **French**; write **all code in English** — comments, UI strings, messages.)

## What & where
- WoW **retail, Midnight (patch 12.x)** addon. In-game name **SAMounts**; slash **`/sam`** or `/samounts`.
- Purpose: port SimpleArmory's mount-farming **planner** into the game — shows **one uncollected mount
  target at a time**, guided, and auto-skips what's already done.
- Repo: **`/apps/perso/SAMounts`** (git, local only). Addon folder: `/apps/perso/SAMounts/SAMounts/`
  (this folder goes into `Interface/AddOns`).
- Derived from the SimpleArmory repo at `/apps/perso/SimpleArmory` (`static/data/planner.json`).

## Build / deploy / validate (from repo root)
- **Generate data**: `node scripts/build-data.mjs` — reads `data/planner.json` (snapshot of SimpleArmory's
  `static/data/planner.json`) → writes `SAMounts/RouteData.lua` (global `SAMountsRouteData`) and
  `scripts/Locations.skeleton.lua`. **Never overwrites** `SAMounts/Locations.lua` (hand-authored).
- **Validate Lua**: `node scripts/check-lua.mjs` (luaparse, recursive). Run after every edit.
- **Deploy to game**: `bash scripts/deploy.sh` — copies `SAMounts/` → `/mnt/d/Games/World of Warcraft/_retail_/Interface/AddOns/SAMounts`.
  (WoW is a Windows process on `/mnt/d`; can't symlink into the WSL ext4 repo, so we copy.)
- **Can't run WoW from here** → user tests each change in-game. Shell `_encode/_decode` lines are harmless zsh noise.
- After deploy, user runs `/reload` (code changes) — a brand-new addon needs a full client restart.

## Files (SAMounts/) and roles
- **SAMounts.toc** — `## Interface: 120007`; SavedVariables `SAMountsDB` (global) + `SAMountsCharDB` (per char);
  `## OptionalDeps: TomTom, FarstriderLib`. Load order: Locale, Locales\enUS, RouteData, Locations, Route,
  Progress, Lockouts, Difficulty, Detect, Waypoint, Travel, Nav, UI, MinimapButton, Core.
- **Locale.lua** — `ns.L` (metatable → falls back to the key), `ns.Print(msg)` (chat with addon tag).
- **Locales/enUS.lua** — every UI string (key == English text). New locale = copy + `if GetLocale()~="frFR" then return end`.
- **RouteData.lua** — GENERATED tree `SAMountsRouteData` (Category→…→run→bosses). Do not edit by hand.
- **Locations.lua** — hand-authored per-run data, keyed by exact run title. Fields:
  `map` (UiMapID of entrance), `x,y` (0–100 entrance coords), `lockout` (English name, fallback only),
  `instanceId` (**the primary lockout key** = `GetSavedInstanceInfo` 14th return = instance Map.ID),
  `questId` (world-boss weekly loot quest), `reqDiff`+`diffScope` ("dungeon"/"raid"/"legacyRaid"),
  `encounters` (`[mount spellId]=DungeonEncounterID`), `lowPriority` (true → pushed to end, e.g. Stratholme).
  Status: 55 runs; **27 raid + 8 dungeon instanceIds**; 5 world-boss questIds; encounters filled from research.
  TODO: Return to Karazhan encounters; Manaforge Omega + March on Quel'Danas `instanceId` (get via `/sam debug` while saved).
- **Route.lua** — `BuildTargets()` flattens `SAMountsRouteData` → ordered list of targets (each = a run with
  its still-needed, right-faction mounts) + `breadcrumb` (travel steps). `IsMountCollected(id)` =
  `select(11, C_MountJournal.GetMountInfoByID(id))`. `IsRouteMount(id)`.
- **Progress.lua** — the "one step at a time" engine. `charDB.currentIdx` pointer; `charDB.doneRuns[key]={at,type}`
  per-reset completion; `Rebuild()` (exclude collected + done + wrong-faction, `lowPriority` last, preserve/clamp
  pointer); `Next/Prev`, `MarkDone`, `ResetAllDone`; `CheckResets()` (native daily/weekly reset timers, purge +
  jump to step 1 on crossing); `IsDoneByQuest(key)` (world bosses via `C_QuestLog.IsQuestFlaggedCompleted`).
- **Lockouts.lua** — scans `GetSavedInstanceInfo`, matches by **instanceId (#14, locale-proof)** with English
  name as fallback → `MarkDone`. Runs on PLAYER_ENTERING_WORLD / UPDATE_INSTANCE_INFO / BOSS_KILL (+ RequestRaidInfo).
- **Difficulty.lua** — `NeedsSwitch` (reqDiff vs `GetDungeon/Raid/LegacyRaidDifficultyID`; Mythic Keystone 8
  satisfies Mythic 23); `SwitchTo` via `Set*DifficultyID`; refresh on `PLAYER_DIFFICULTY_CHANGED` (async).
- **Detect.lua** — `ENCOUNTER_END` (success + encounterID matches a target's `encounters` → MarkDone + advance);
  `NEW_MOUNT_ADDED` (route mount → congrats popup + Rebuild).
- **Waypoint.lua** — `GuideTo(target[,silent])` → waypoint on entrance (TomTom else Blizzard user waypoint +
  super-track); `SetTo(mapID, x01, y01, title)` low-level (coords **0–1**).
- **Travel.lua** — on-screen, **movable, clickable secure ICON button** for an action.
  `SecureActionButtonTemplate` **parented to UIParent** (NOT inside our window — see gotcha). `type=item`
  (`"item:ID"`) or `type=spell` (localized name). Combat-deferred (PLAYER_REGEN_ENABLED). Saved pos `db.actionPos`.
  **VALIDATED working in-game** (click uses the item; draggable).
- **Nav.lua** — **FarstriderLib** integration (the router). `Available()`; `Update(target)`:
  `FarstriderLib_API.FindTrailTo(loc.map, x/100, y/100, 0)` → `optimizedPath`; render **step[1]**:
  `actionOptions` → `Travel.ShowAction("item"/"spell", data)`; else hide button; `Waypoint.SetTo` arrow to
  `step.loc` (0–1) titled with `step.loca` (already localized). Re-runs each refresh/zone change (FarstriderLib
  re-routes from current position). Returns false when FarstriderLib absent → caller falls back to entrance arrow.
- **UI.lua** — `SAMountsFrame` one-step card: header (Step N/M, X mounts left), reset timers, breadcrumb
  (text route), target title, up to 4 boss rows (icon+mount+boss+note+tooltip), bottom buttons Prev/Next/Guide/
  Done (84px), Reset-all (top-right + confirm popup), conditional difficulty button, loot popup. `Refresh()`
  drives Nav (or fallback arrow) and gates on `db.autoGuide`.
- **MinimapButton.lua** — self-contained (no LibDBIcon). Left-click toggle, right-click reset-all.
- **Core.lua** — saved-var init (`db.minimap`, `db.autoGuide`=true, `charDB.doneRuns/currentIdx`); PLAYER_LOGIN
  (init UI/minimap, CheckResets, **ResetPointer → step 1 each login**); PLAYER_ENTERING_WORLD / QUEST_TURNED_IN
  → refresh; 30s ticker CheckResets; slash `/sam` (toggle | next | prev | guide | reset | minimap | arrow | debug | help).

## Key technical learnings (do NOT relearn the hard way)
- **Secure buttons**: a protected (SecureActionButton) frame **cannot be anchored inside a custom movable
  BackdropTemplate window** — throws "Cannot anchor protected frames to regions" even when anchored to its
  parent. Fix: **parent it to `UIParent`** (Travel.lua). `type=item`/`spell`/`macro` all work; move out of combat only.
- **Localization**: never hardcode item/spell/zone names. Resolve from IDs at runtime:
  `C_Item.GetItemInfo(id)`, `C_Spell.GetSpellInfo(id).name`, `C_Map.GetMapInfo(id).name`. Store IDs in data.
- **Lockout matching is locale-proof via `instanceId`** = 14th return of `GetSavedInstanceInfo` (stable Map.ID,
  added 10.0.5). Do NOT match by localized instance name. World bosses aren't saved instances → weekly quest flag.
- **Client is frFR** (user) — anything name-based must use the game's localized names, not English.
- **Reset**: `C_DateAndTime.GetSecondsUntilDailyReset/WeeklyReset`; pointer → first step on login and on reset crossing.
- **FarstriderLib contract** (the router we call, licensed ARR → call API only, don't copy):
  global `FarstriderLib_API` (VERSION 10400). `FindTrailTo(goalMapId, x, y, z)` — coords **0–1**, z=0, resolves
  player pos, returns `optimizedPath, path, edges` (may be nil/empty → guard). Each `optimizedPath[i]`:
  `{ id, loc={mapId,pos={x,y 0-1},isUI}, completionLoc, loca=<localized label>, actionOptions=nil|{{type="item"/"spell"/"housing",data=id}}, checkDistance }`.
  `actionOptions` present = action step (→ button); absent = travel step (→ arrow). `loca` is display-ready.

## Reference addons on disk (licensed All Rights Reserved — study schema only, never copy data)
- `Mapzeroth`, `QuickRoute` (its SecureButtons.lua errors), `MountRoutePlanner` + **`FarstriderLib`/`FarstriderLibData`** (the router we use).

## Backlog (user-requested, pending)
1. **Text-route fallback** when neither FarstriderLib nor TomTom installed (breadcrumb is always shown — verify it's enough).
2. **Settings/options page** (toggle TomTom use, autoGuide, etc.).
3. **Full UI redesign** — user finds current window ugly/dated; wants a modern look.
4. Fill data TODOs (Return to Karazhan encounters; Manaforge Omega / March on Quel'Danas `instanceId`; verify uncertain coords/instanceIds via `/sam debug`).

## Currently awaiting user test
- Nav/FarstriderLib rendering: does the action button reflect FarstriderLib's suggested item/spell, **localized**,
  and the arrow point to the next hop? (Just implemented, untested in-game.)
