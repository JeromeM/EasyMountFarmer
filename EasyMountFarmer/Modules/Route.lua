-- Route.lua — builds the ordered list of "farm targets" from the generated mount
-- data (EasyMountFarmerInstances + EasyMountFarmerWorld + the hand-authored
-- EasyMountFarmerExtra), merged with the runtime overrides in Overrides.lua.
--
-- A target = one FARM STOP with the mounts still worth getting there:
--   * dungeon / raid : one target per instance (journalInstanceID) -> its N mounts.
--   * world boss     : one target per mount (each boss is its own trip).
--   * trash (Extra)  : one target per instance (AQ tanks share one visit).
--   * world rare     : one target per mount (only when the filter enables them).
--
-- Targets are FULLY enriched here (coords, lockout id, quest id, difficulty, reset
-- type, encounter ids, route order); every other module reads those fields off the
-- target and never touches the raw data tables again.
--
-- Target shape (see the grouping code below):
--   key, title, instance, journalInstanceID, category, expansion, type, order,
--   map, x, y, continent, zone, entranceJID, entranceMaps, instanceId, questId,
--   lowPriority, reqDiff, diffScope,
--   bosses = { { mountID, mount, spellID, itemID, name, encounterID, faction,
--                difficulties, reqDiff, diffScope, epic }, ... },
--   encounters = { [i] = encounterID }   -- flat list, for ENCOUNTER_END matching

local ADDON, ns = ...
ns.Route = ns.Route or {}
local Route = ns.Route
local L = ns.L

-- Expansion display order (top level of the route: each has its own capital hub).
local EXPANSION_ORDER = {
  "Classic", "Burning Crusade", "Wrath of the Lich King", "Cataclysm",
  "Mists of Pandaria", "Warlords of Draenor", "Legion", "Battle for Azeroth",
  "Shadowlands", "Dragonflight", "The War Within", "Midnight",
}
local EXP_IDX = {}
for i, e in ipairs(EXPANSION_ORDER) do EXP_IDX[e] = i end
ns.EXPANSION_ORDER = EXPANSION_ORDER

-- Difficulty scopes, by difficultyID (drives which Get/SetXDifficultyID to call).
local DUNGEON_DIFF     = { [1] = true, [2] = true, [23] = true, [8] = true }
local RAID_MODERN_DIFF = { [14] = true, [15] = true, [16] = true, [17] = true }
local RAID_LEGACY_DIFF = { [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [9] = true }

--- Derive the difficulty scope ("dungeon" | "raid" | "legacyRaid") from a set of
--- difficultyIDs a mount drops on.
---@param diffs number[]?  the difficultyIDs from the generated data
---@return string?  the scope, or nil if the set is empty/unknown
local function deriveScope(diffs)
  for _, d in ipairs(diffs or {}) do
    if RAID_MODERN_DIFF[d] then return "raid" end
    if RAID_LEGACY_DIFF[d] then return "legacyRaid" end
    if DUNGEON_DIFF[d] then return "dungeon" end
  end
  return nil
end

--- Derive the required difficulty for a mount: only when it drops on exactly ONE
--- difficulty that isn't plain Normal (which needs no switch). Multiple drop
--- difficulties mean the easiest one is enough -> no forced switch (nil).
---@param diffs number[]?  the difficultyIDs from the generated data
---@return number?  the required difficultyID, or nil if none is forced
local function deriveReqDiff(diffs)
  if not diffs or #diffs ~= 1 then return nil end
  local d = diffs[1]
  if d == 1 or d == 14 then return nil end   -- plain Normal: nothing to switch to
  return d
end

--- Aggregate a per-instance required difficulty from its still-needed mounts: if
--- they all point at a single difficulty, offer that switch; if they disagree
--- (e.g. a 10-player and a 25-player drake), force nothing.
---@param bosses table  the target's bosses (each may carry .reqDiff / .diffScope)
---@return number? reqDiff  the shared required difficulty, or nil
---@return string? diffScope  the matching scope, or nil
local function aggregateDiff(bosses)
  local reqDiff, diffScope, count = nil, nil, 0
  for _, b in ipairs(bosses) do
    if b.reqDiff then
      if b.reqDiff ~= reqDiff then count = count + 1 end
      reqDiff, diffScope = b.reqDiff, b.diffScope
    end
  end
  if count == 1 then return reqDiff, diffScope end
  return nil, nil
end

--- Map a mount category + required difficulty to a reset cadence bucket:
--- "Dungeon" (daily), "Raid"/"WeeklyDungeon"/"WorldBoss" (weekly), "WorldRare" (none).
---@param category string  the mount category
---@param reqDiff number?  the instance-level required difficulty
---@return string  the reset type
local function resetTypeFor(category, reqDiff)
  if category == "worldboss" then return "WorldBoss" end
  if IS_WORLD[category] then return "WorldRare" end
  if category == "raid" or category == "trash" then return "Raid" end
  -- dungeon: a Mythic dungeon (reqDiff 23) locks weekly, everything else is daily
  if reqDiff == 23 then return "WeeklyDungeon" end
  return "Dungeon"
end

--- Report whether a mount is already collected.
---@param id number?  mount journal ID
---@return boolean  true if the mount is collected
function Route.IsMountCollected(id)
  if not id then return false end
  local ok, isCollected = pcall(function()
    return select(11, C_MountJournal.GetMountInfoByID(id))
  end)
  return ok and isCollected == true
end

--- Report whether a mount is available to the player's faction. The generated
--- faction field mirrors GetMountInfoByID: 0 = Horde, 1 = Alliance, nil = both.
---@param faction number?  the mount's faction restriction
---@param isAlliance boolean  true if the player is Alliance
---@return boolean  true if the player can obtain the mount
local function factionOk(faction, isAlliance)
  if faction == nil then return true end
  if faction == 1 then return isAlliance end
  if faction == 0 then return not isAlliance end
  return true
end

-- Set of every mount ID present in the data (to filter NEW_MOUNT_ADDED).
local routeMountSet
--- Populate routeMountSet with every mount ID across all data sources.
local function BuildRouteMountSet()
  routeMountSet = {}
  for _, m in ipairs(EasyMountFarmerInstances or {}) do if m.mountID then routeMountSet[m.mountID] = true end end
  for _, m in ipairs(EasyMountFarmerExtra or {}) do if m.mountID then routeMountSet[m.mountID] = true end end
  for _, m in ipairs(EasyMountFarmerWorld or {}) do if m.mountID then routeMountSet[m.mountID] = true end end
end

--- Report whether a mount ID belongs to our data (lazily builds the set).
---@param mountID number  mount journal ID
---@return boolean  true if the mount appears in any data source
function Route.IsRouteMount(mountID)
  if not routeMountSet then BuildRouteMountSet() end
  return routeMountSet[mountID] == true
end

-- ---------------------------------------------------------------------------
-- category / expansion filter
-- ---------------------------------------------------------------------------
-- World-drop sub-categories (open-world mounts, no lockout). Split so they can be
-- filtered separately. They share reset/ordering behaviour (treated as "world").
local WORLD_CATEGORIES = { "rare", "event", "vendor", "treasure", "achievement" }
local IS_WORLD = {}
for _, c in ipairs(WORLD_CATEGORIES) do IS_WORLD[c] = true end
ns.WORLD_CATEGORIES = WORLD_CATEGORIES

-- Every filterable category. Default: instances/raids/world bosses/trash on; the
-- open-world sub-categories off (they are numerous and location-poor).
local ALL_CATEGORIES = { "dungeon", "raid", "worldboss", "trash",
  "rare", "event", "vendor", "treasure", "achievement" }
ns.ALL_CATEGORIES = ALL_CATEGORIES

--- Report whether a category passes the current filter (default: all but world drops).
---@param category string  the mount category
---@return boolean  true if the category is enabled
local function categoryEnabled(category)
  local f = ns.db and ns.db.filter
  if not f or not f.categories then return not IS_WORLD[category] end
  return f.categories[category] == true
end

--- Report whether an expansion passes the current filter (default: all enabled).
---@param expansion string?  the mount's expansion
---@return boolean  true if the expansion is enabled
local function expansionEnabled(expansion)
  local f = ns.db and ns.db.filter
  if not f or not f.expansions then return true end
  if expansion == nil then return true end
  return f.expansions[expansion] ~= false
end

-- ---------------------------------------------------------------------------
-- geographic ordering + rotation
-- ---------------------------------------------------------------------------
-- The visiting order is expansion (each has its own portal hub) -> continent ->
-- an intra-continent nearest-neighbour chain on real WORLD coordinates (so zones
-- that are physically adjacent end up next to each other, world bosses included).
-- The whole expansion sequence is then ROTATED to lead with the expansion nearest
-- the player, so the tour starts where you are and wraps around.

--- Resolve a target's entrance to continent-space world coordinates (comparable
--- across zones of the same continent). Falls back to nil when the map API can't.
---@param t table  a target (uses map / x / y in 0-100)
---@return number? continentID  the continent the entrance is on
---@return number? wx  world X (continent yards)
---@return number? wy  world Y (continent yards)
local function worldPos(t)
  if not (t.map and t.x and t.y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local ok, continentID, pos = pcall(C_Map.GetWorldPosFromMapPos, t.map, CreateVector2D(t.x / 100, t.y / 100))
  if not ok or not continentID or not pos then return nil end
  local wx, wy = pos:GetXY()
  if not wx then return nil end
  return continentID, wx, wy
end

--- Chain targets by nearest-neighbour on their world coords, starting from the one
--- with the lowest generated order (a stable, sensible entry point).
---@param items table  targets that all carry _wx / _wy
---@return table  the chained order
local function nnChainWorld(items)
  local rem = {}
  for i, t in ipairs(items) do rem[i] = t end
  if #rem <= 1 then return rem end
  table.sort(rem, function(a, b) return (a.order or 9999) < (b.order or 9999) end)
  local out = { table.remove(rem, 1) }
  while #rem > 0 do
    local last = out[#out]
    local bi, bd = 1, math.huge
    for i, t in ipairs(rem) do
      local dx, dy = (t._wx or 0) - (last._wx or 0), (t._wy or 0) - (last._wy or 0)
      local d = dx * dx + dy * dy
      if d < bd then bd = d; bi = i end
    end
    out[#out + 1] = table.remove(rem, bi)
  end
  return out
end

--- Order the targets of a single expansion: group by continent (continents in
--- generated-order), nearest-neighbour within each; targets with no resolvable
--- world position (e.g. world rares) fall to the end by generated order.
---@param list table  the expansion's targets
---@return table  the ordered targets
local function orderWithinExpansion(list)
  if #list <= 1 then return list end
  local byCont, contSeen, noPos = {}, {}, {}
  for _, t in ipairs(list) do
    local c, wx, wy = worldPos(t)
    if c then
      t._wx, t._wy = wx, wy
      if not byCont[c] then byCont[c] = {}; contSeen[#contSeen + 1] = c end
      byCont[c][#byCont[c] + 1] = t
    else
      noPos[#noPos + 1] = t
    end
  end
  local function minOrder(g) local m = 9999; for _, t in ipairs(g) do m = math.min(m, t.order or 9999) end; return m end
  table.sort(contSeen, function(a, b) return minOrder(byCont[a]) < minOrder(byCont[b]) end)
  local out = {}
  for _, c in ipairs(contSeen) do
    for _, t in ipairs(nnChainWorld(byCont[c])) do out[#out + 1] = t end
  end
  table.sort(noPos, function(a, b)
    return (a.order or 9999) < (b.order or 9999) or ((a.order or 9999) == (b.order or 9999) and (a.instance or "") < (b.instance or ""))
  end)
  for _, t in ipairs(noPos) do out[#out + 1] = t end
  return out
end

--- Resolve the map a run's entrance is currently on. Most runs have a fixed map;
--- moving portals (Ny'alotha) are looked up live via the Encounter Journal.
---@param t table  a target (may carry entranceJID / entranceMaps)
---@return number?  the uiMapID the entrance is currently on
local function liveEntranceMap(t)
  if not (t and t.entranceJID and t.entranceMaps
          and C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap) then
    return t and t.map
  end
  for _, mapId in ipairs(t.entranceMaps) do
    local ok, list = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapId)
    if ok and type(list) == "table" then
      for _, e in ipairs(list) do
        if e.journalInstanceID == t.entranceJID then return mapId end
      end
    end
  end
  return t.map
end

--- Order targets by the hand-authored EasyMountFarmerOrder. A plain string entry is
--- a target key; a { key, entrance } entry only claims its slot when the run's live
--- entrance is on that map (Ny'alotha's moving portal). A world rare whose zone
--- matches a listed stop is slotted right AFTER that stop (so nearby rares ride along
--- the tour); everything else falls to the end (alphabetically).
---@param targets table  the unordered targets
---@return table  the ordered targets
local function orderManual(targets)
  local byKey = {}
  for _, t in ipairs(targets) do byKey[t.key] = t end

  local rank, i = {}, 0
  for _, entry in ipairs(EasyMountFarmerOrder) do
    i = i + 1
    if type(entry) == "table" then
      local t = byKey[entry.key]
      if t and rank[entry.key] == nil and liveEntranceMap(t) == entry.entrance then
        rank[entry.key] = i
      end
    elseif rank[entry] == nil then
      rank[entry] = i
    end
  end

  -- zone name -> rank of the first listed stop there, so a world rare in the same
  -- zone can be inserted just after it.
  local zoneRank = {}
  for _, t in ipairs(targets) do
    if rank[t.key] and t.zoneName and zoneRank[t.zoneName] == nil then
      zoneRank[t.zoneName] = rank[t.key]
    end
  end

  local BIG = #EasyMountFarmerOrder + 1000
  --- Effective sort rank: a listed stop's own rank, a world rare's matching-zone stop
  --- rank + 0.5 (rides just behind it), else the end.
  ---@param t table  a target
  ---@return number  the effective rank
  local function effRank(t)
    if rank[t.key] then return rank[t.key] end
    if IS_WORLD[t.category] and t.zoneName and zoneRank[t.zoneName] then
      return zoneRank[t.zoneName] + 0.5
    end
    return BIG
  end

  table.sort(targets, function(a, b)
    local ra, rb = effRank(a), effRank(b)
    if ra ~= rb then return ra < rb end
    return (a.instance or "") < (b.instance or "")
  end)
  return targets
end

--- Order the full target list. When EasyMountFarmerOrder is defined it wins (hand
--- order); otherwise fall back to the automatic geographic order: low-priority runs
--- last; the rest grouped into expansion blocks (expansion order), each ordered
--- geographically, then rotated to lead with ns.rotateExpansion (the player's).
---@param targets table  the unordered targets
---@return table  the ordered targets
function Route.OrderTargets(targets)
  if EasyMountFarmerOrder then return orderManual(targets) end
  local main, low = {}, {}
  for _, t in ipairs(targets) do
    if t.lowPriority then low[#low + 1] = t else main[#main + 1] = t end
  end

  local byExp, expSeen = {}, {}
  for _, t in ipairs(main) do
    local e = t.expansion or "?"
    if not byExp[e] then byExp[e] = {}; expSeen[#expSeen + 1] = e end
    byExp[e][#byExp[e] + 1] = t
  end
  table.sort(expSeen, function(a, b) return (EXP_IDX[a] or 99) < (EXP_IDX[b] or 99) end)
  for _, e in ipairs(expSeen) do byExp[e] = orderWithinExpansion(byExp[e]) end

  -- rotate the expansion sequence to start at the player's expansion (if known)
  local start = 1
  if ns.rotateExpansion then
    for i, e in ipairs(expSeen) do if e == ns.rotateExpansion then start = i; break end end
  end
  local ordered = {}
  for k = 0, #expSeen - 1 do
    local e = expSeen[((start - 1 + k) % #expSeen) + 1]
    for _, t in ipairs(byExp[e]) do ordered[#ordered + 1] = t end
  end
  for _, t in ipairs(orderWithinExpansion(low)) do ordered[#ordered + 1] = t end
  return ordered
end

--- Recompute which expansion the tour should start with: the one holding the target
--- physically nearest the player. Cached in ns.rotateExpansion so the order stays
--- stable across rebuilds during a session (recomputed on login / open / re-sync).
function Route.ComputeStart()
  ns.rotateExpansion = nil
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
  local map = C_Map.GetBestMapForUnit("player")
  if not map then return end
  local ppos = C_Map.GetPlayerMapPosition(map, "player")
  if not ppos then return end
  local okc, pc, pwx, pwy
  local ok, cont, wpos = pcall(C_Map.GetWorldPosFromMapPos, map, ppos)
  if ok and cont and wpos then okc, pc = true, cont; pwx, pwy = wpos:GetXY() end
  if not okc or not pwx then return end

  local best, bd
  for _, t in ipairs(ns.allTargets or {}) do
    local c, wx, wy = worldPos(t)
    if c == pc then
      local dx, dy = wx - pwx, wy - pwy
      local d = dx * dx + dy * dy
      if not bd or d < bd then bd = d; best = t end
    end
  end
  ns.rotateExpansion = best and best.expansion or nil
end

-- ---------------------------------------------------------------------------
-- build targets
-- ---------------------------------------------------------------------------
--- Turn one generated/hand mount record into a boss row, deriving its difficulty.
---@param m table  a record from EasyMountFarmerInstances / Extra / World
---@param info table?  the matching instance override (may supply a missing encounterID)
---@return table  the boss row
local function makeBoss(m, info)
  local enc = m.encounterID
  if not enc and info and info.encByMount then enc = info.encByMount[m.mountID] end
  return {
    mountID = m.mountID, mount = m.mount, spellID = m.spellID, itemID = m.itemID,
    name = m.boss, encounterID = enc, faction = m.faction,
    difficulties = m.difficulties, reqDiff = deriveReqDiff(m.difficulties),
    diffScope = deriveScope(m.difficulties), epic = true,
  }
end

--- Finalize a grouped target: keep only still-needed bosses, merge the override,
--- derive instance-level difficulty and reset type, and collect encounter ids.
--- Returns nil when nothing is left to farm there or the category/expansion is filtered.
---@param g table  a partial target (key, category, expansion, records, and any override fields)
---@param isAlliance boolean  the player's faction
---@return table?  the finished target, or nil to drop it
local function finishTarget(g, isAlliance)
  if not categoryEnabled(g.category) or not expansionEnabled(g.expansion) then return nil end
  local bosses = {}
  for _, m in ipairs(g.records) do
    -- skip collected, wrong-faction and legacy (no-longer-obtainable) mounts
    if m.mountID and not m.legacy
       and not Route.IsMountCollected(m.mountID) and factionOk(m.faction, isAlliance) then
      bosses[#bosses + 1] = makeBoss(m, g.info)
    end
  end
  if #bosses == 0 then return nil end

  local reqDiff, diffScope = aggregateDiff(bosses)
  local encounters = {}
  for _, b in ipairs(bosses) do if b.encounterID then encounters[#encounters + 1] = b.encounterID end end

  local info = g.info or {}
  local first = g.records[1]
  return {
    key = g.key, title = g.instance, instance = g.instance,
    journalInstanceID = g.journalInstanceID, category = g.category, expansion = g.expansion,
    type = resetTypeFor(g.category, reqDiff), order = g.order,
    -- the entrance map is the mount's zone uiMapID (generated), an override map, or
    -- a hand map (Extra / world bosses). `zone` is the map the x/y coords live on.
    map = info.map or first.map or first.zone or g.map, x = info.x or first.x or g.x, y = info.y or first.y or g.y,
    continent = first.continent, zone = first.zone, zoneName = first.zoneName,
    vendor = first.vendor, source = first.source,
    entranceJID = info.entranceJID, entranceMaps = info.entranceMaps,
    instanceId = info.instanceId or first.instanceId,
    questId = g.questId, lowPriority = info.lowPriority,
    reqDiff = reqDiff, diffScope = diffScope,
    bosses = bosses, encounters = encounters,
  }
end

--- Build the flat, ordered list of farm targets from all enabled data sources.
--- Groups records into farm stops, prunes collected / wrong-faction mounts and
--- filtered categories/expansions, then orders them expansion -> generated route
--- order (world rares and low-priority runs last).
---@return table  ordered list of target tables
function Route.BuildTargets()
  local isAlliance = (UnitFactionGroup("player") == "Alliance")
  local instInfo = EasyMountFarmerInstanceInfo or {}
  local wbInfo = EasyMountFarmerWorldBossInfo or {}
  local groups, orderKeys = {}, {}

  --- Fetch (or create) the group for a key, remembering insertion order.
  ---@param key string  the group key
  ---@return table  the group accumulator
  local function group(key)
    local g = groups[key]
    if not g then g = { key = key, records = {} }; groups[key] = g; orderKeys[#orderKeys + 1] = key end
    return g
  end

  -- generated dungeon/raid (by instance) and world bosses (by mount)
  for _, m in ipairs(EasyMountFarmerInstances or {}) do
    if m.category == "worldboss" then
      local g = group("m:" .. m.mountID)
      g.category, g.expansion, g.instance = "worldboss", m.expansion, m.mount
      g.order, g.questId = m.order, (wbInfo[m.mountID] and wbInfo[m.mountID].questId)
      g.info = wbInfo[m.mountID]
      g.records[#g.records + 1] = m
    else
      local g = group("i:" .. m.journalInstanceID)
      g.category, g.expansion, g.instance = m.category, m.expansion, m.instance
      g.journalInstanceID, g.order = m.journalInstanceID, g.order or m.order
      g.info = instInfo[m.journalInstanceID]
      g.records[#g.records + 1] = m
    end
  end

  -- hand-authored trash drops (Extra), grouped per instance
  for _, m in ipairs(EasyMountFarmerExtra or {}) do
    local g = group("x:" .. m.instance)
    g.category, g.expansion, g.instance = m.category, m.expansion, m.instance
    g.records[#g.records + 1] = m
  end

  -- world drops (rare / event / vendor / treasure), each its own stop; the specific
  -- sub-category comes from the data and is filtered per-category in finishTarget.
  for _, m in ipairs(EasyMountFarmerWorld or {}) do
    local g = group("m:" .. m.mountID)
    g.category, g.expansion, g.instance = m.category, m.expansion, m.mount
    g.records[#g.records + 1] = m
  end

  local targets = {}
  for _, key in ipairs(orderKeys) do
    local t = finishTarget(groups[key], isAlliance)
    if t then targets[#targets + 1] = t end
  end

  -- order geographically (expansion -> continent -> proximity) + rotate to the player
  return Route.OrderTargets(targets)
end

--- Count the mounts still to farm across all targets (ignoring lockouts).
---@param targets table  list of target tables (each with a bosses list)
---@return number  total number of uncollected mounts
function Route.CountRemainingMounts(targets)
  local n = 0
  for _, t in ipairs(targets) do n = n + #t.bosses end
  return n
end
