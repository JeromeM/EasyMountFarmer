-- Generator.lua — one-shot data generator (dev tool). Walks the game's Encounter
-- Journal and lists every mount that drops from a dungeon/raid boss, grouped by
-- expansion tier and tagged with the difficulties it drops on. The result is
-- written to the EasyMountFarmerGen saved variable (flushed to disk on /reload)
-- so it can be turned into our own route data — replacing SimpleArmory's planner.
--
-- Three client quirks are handled:
--  * EJ loot is per-DIFFICULTY: instance loot only lists the selected difficulty's
--    drops, so Heroic-only (Raven Lord…) or Mythic-only (Ny'alotha Allseer…) mounts
--    are missed unless we iterate difficulties. We scan every valid difficulty and
--    merge, recording the set of difficulties each mount drops on.
--  * EJ loot is delivered ASYNCHRONOUSLY (EJ_LOOT_DATA_RECIEVED), so we scan one
--    (instance, difficulty) job at a time and wait for its data.
--  * GetMountFromItem needs the ITEM cached, which it is not mid-sweep, so we detect
--    mounts by item class/subclass and resolve mountID/spellID in a polling pass.
--
-- Usage in game:  /emf gen   then   /reload   (then read the saved variable).

local ADDON, ns = ...
ns.Gen = ns.Gen or {}
local Gen = ns.Gen

local ITEM_CLASS_MISC     = 15  -- Enum.ItemClass.Miscellaneous
local ITEM_SUBCLASS_MOUNT = 5   -- Enum.ItemMiscellaneousSubclass.Mount

-- Difficulty IDs we probe per instance (filtered by EJ_IsValidInstanceDifficulty):
-- dungeon Normal/Heroic/Mythic, then legacy + modern raid sizes/difficulties.
local CANDIDATE_DIFFS = { 1, 2, 23, 3, 4, 5, 6, 7, 9, 14, 15, 16, 17 }

local scanner = CreateFrame("Frame")   -- receives EJ_LOOT_DATA_RECIEVED during a scan

-- scan state (reset by Gen.Generate)
local queue, candidates, byKey, scanned, qi, proceed, running, entranceLoc

--- Instant, cache-free test: is this item a mount-teaching item?
---@param itemID number?
---@return boolean
local function isMountItem(itemID)
  if not itemID then return false end
  local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not getInstant then return false end
  local _, _, _, _, _, classID, subclassID = getInstant(itemID)
  return classID == ITEM_CLASS_MISC and subclassID == ITEM_SUBCLASS_MOUNT
end

--- Resolve an item's mountID: GetMountFromItem, falling back to its teaching spell
--- (GetItemSpell -> GetMountFromSpell). Needs the item cached.
---@param itemID number
---@return number?  mountID, or nil if unresolved
local function mountIDForItem(itemID)
  local id = C_MountJournal.GetMountFromItem and C_MountJournal.GetMountFromItem(itemID)
  if id then return id end
  if C_Item and C_Item.GetItemSpell and C_MountJournal.GetMountFromSpell then
    local _, spellID = C_Item.GetItemSpell(itemID)
    if spellID then return C_MountJournal.GetMountFromSpell(spellID) end
  end
  return nil
end

--- Brute-force harvest of instance entrances across every map: returns
--- journalInstanceID -> { zone, zoneName, x, y (0-100), continent, continentName }.
--- Covers dungeon/raid portals (world bosses have no journal entrance) and feeds
--- the route-ordering (group by continent -> zone -> intra-zone proximity).
---@return table<number, table>
local function harvestEntrances()
  local loc = {}
  if not (C_EncounterJournal.GetDungeonEntrancesForMap and C_Map and C_Map.GetMapInfo) then return loc end
  local CONT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
  for mapID = 1, 2700 do
    local ok, ents = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapID)
    if ok and type(ents) == "table" then
      for _, e in ipairs(ents) do
        local jid = e.journalInstanceID
        if jid and not loc[jid] then
          local x, y = 0, 0
          if e.position and e.position.GetXY then x, y = e.position:GetXY() end
          loc[jid] = { zone = mapID, x = (x or 0) * 100, y = (y or 0) * 100 }
        end
      end
    end
  end
  for _, l in pairs(loc) do
    local zi = C_Map.GetMapInfo(l.zone)
    l.zoneName = zi and zi.name
    local id = l.zone
    while id and id ~= 0 do
      local mi = C_Map.GetMapInfo(id)
      if not mi then break end
      if mi.mapType == CONT then l.continent = id; l.continentName = mi.name; break end
      id = mi.parentMapID
    end
  end
  return loc
end

--- Build a journal-encounterID -> { name, dungeonEncounterID } map for an instance
--- (dungeonEncounterID is the id ENCOUNTER_END reports on a kill).
---@param instanceID number  the selected journalInstanceID
---@return table<number, table>  encounter info keyed by journal encounterID
local function encounterMap(instanceID)
  local map = {}
  local j = 1
  while true do
    local name, _, encounterID, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(j, instanceID)
    if not name then break end
    if encounterID then map[encounterID] = { name = name, dungeonEncounterID = dungeonEncounterID } end
    j = j + 1
  end
  return map
end

--- Read the selected (instance, difficulty)'s loot; record each mount item once per
--- instance (merging the difficulty into an existing record) and request its data.
---@param job table  the queue entry (instance + difficulty) currently selected
local function readLoot(job)
  local n = (EJ_GetNumLoot and EJ_GetNumLoot()) or 0
  scanned = scanned + n
  for k = 1, n do
    local info = C_EncounterJournal.GetLootInfoByIndex(k)
    if info and info.itemID and isMountItem(info.itemID) then
      local key = job.instanceID .. ":" .. info.itemID
      local c = byKey[key]
      if not c then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(info.itemID) end
        local enc = info.encounterID and job.encs[info.encounterID]
        c = {
          expansion         = job.tierName,
          instance          = job.instName,
          journalInstanceID = job.instanceID,
          isRaid            = job.isRaid,
          boss              = enc and enc.name or nil,
          encounterID       = enc and enc.dungeonEncounterID or nil,   -- ENCOUNTER_END id
          itemID            = info.itemID,
          name              = info.name,
          zone              = job.loc and job.loc.zone or nil,
          zoneName          = job.loc and job.loc.zoneName or nil,
          x                 = job.loc and job.loc.x or nil,
          y                 = job.loc and job.loc.y or nil,
          continent         = job.loc and job.loc.continent or nil,
          continentName     = job.loc and job.loc.continentName or nil,
          diffSet           = {},   -- set of difficultyIDs this mount drops on
        }
        byKey[key] = c
        candidates[#candidates + 1] = c
      end
      if job.difficulty and job.difficulty > 0 then c.diffSet[job.difficulty] = true end
    end
  end
end

--- Deferred, self-polling pass: mount items load asynchronously, so keep retrying
--- (every 0.5s, up to ~10s) until every candidate resolves, then finalize + persist.
---@param attempt number?  current retry, 1-based
local function resolve(attempt)
  attempt = attempt or 1
  local pending = 0
  for _, c in ipairs(candidates) do
    if not c.mountID then
      if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(c.itemID) end
      local mountID = mountIDForItem(c.itemID)
      if mountID then
        local mName, spellID, _, _, _, _, _, isFactionSpecific, faction = C_MountJournal.GetMountInfoByID(mountID)
        c.mountID = mountID
        c.spellID = spellID
        c.mount   = mName
        c.faction = isFactionSpecific and faction or nil   -- 0 = Horde, 1 = Alliance
      else
        pending = pending + 1
      end
    end
  end

  if pending > 0 and attempt < 20 then
    C_Timer.After(0.5, function() resolve(attempt + 1) end)
    return
  end

  -- finalize: name fallback for stragglers + turn each diff set into a sorted list
  -- of ids and a readable name string.
  local resolved = 0
  for _, c in ipairs(candidates) do
    if c.mountID then resolved = resolved + 1
    elseif not c.mount then c.mount = (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(c.itemID)) or c.name end

    local ids, names = {}, {}
    for d in pairs(c.diffSet) do ids[#ids + 1] = d end
    table.sort(ids)
    for _, d in ipairs(ids) do
      names[#names + 1] = (GetDifficultyInfo and (GetDifficultyInfo(d))) or tostring(d)
    end
    c.difficulties = ids
    c.diff = table.concat(names, ", ")
    c.diffSet = nil
  end

  -- Cross-check the full Mount Journal for DROP mounts we did NOT capture via boss
  -- loot (trash drops like the Ahn'Qiraj tanks, world rares, etc.) so the instance
  -- ones can be added by hand. A "drop" is identified by the leading label of its
  -- source text (e.g. "Drop"/"Butin"), taken from a mount we DID capture so it stays
  -- locale-proof (sourceType is unreliable — it does not cleanly mark drops).
  local orphans = {}
  if C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoExtraByID then
    -- leading label ("Drop" / "Butin" / …) of a mount's source line 1, or nil
    local function dropLabel(mountID)
      local _, _, src = C_MountJournal.GetMountInfoExtraByID(mountID)
      if not src or src == "" then return nil end
      local line1 = src:match("^(.-)|n") or src
      line1 = line1:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
      return line1:match("^%s*(.-)%s*[:：]")
    end

    local have, wantLabel = {}, nil
    for _, c in ipairs(candidates) do
      if c.mountID then
        have[c.mountID] = true
        wantLabel = wantLabel or dropLabel(c.mountID)
      end
    end
    if wantLabel then
      for _, mid in ipairs(C_MountJournal.GetMountIDs()) do
        if not have[mid] and dropLabel(mid) == wantLabel then
          local _, _, source = C_MountJournal.GetMountInfoExtraByID(mid)
          orphans[#orphans + 1] = { mountID = mid, mount = (C_MountJournal.GetMountInfoByID(mid)), source = source }
        end
      end
    end
  end

  EasyMountFarmerGen = { built = true, count = #candidates, resolved = resolved,
                         mounts = candidates, orphans = orphans }
  running = false
  ns.Print(string.format("Found |cffffff00%d|r boss-loot mounts (%d resolved); |cffffff00%d|r other 'drop' mounts not on a boss (see orphans).",
    #candidates, resolved, #orphans))
  ns.Print("Now type |cffffff00/reload|r to save it to disk.")
end

--- All jobs scanned: let requested item data start arriving, then resolve.
local function finish()
  scanner:UnregisterAllEvents()
  proceed = nil
  ns.Print(string.format("Scan done: %d mount items, resolving item data…", #candidates))
  C_Timer.After(1, function() resolve(1) end)
end

--- Advance to the next (instance, difficulty) job, select it, and read its loot when
--- available (synchronously if cached, else on the loot event, with a timeout).
local function step()
  qi = qi + 1
  if qi > #queue then finish(); return end

  local job = queue[qi]
  local handled = false
  proceed = function()
    if handled then return end
    handled = true
    readLoot(job)
    step()
  end

  EJ_SelectTier(job.tier)
  EJ_SelectInstance(job.instanceID)
  if job.difficulty and job.difficulty > 0 and EJ_SetDifficulty then pcall(EJ_SetDifficulty, job.difficulty) end
  if EJ_SetLootFilter then pcall(EJ_SetLootFilter, 0, 0) end   -- no class/spec filter

  if ((EJ_GetNumLoot and EJ_GetNumLoot()) or 0) > 0 then
    proceed()
  else
    C_Timer.After(0.3, proceed)
  end
end

scanner:SetScript("OnEvent", function() if proceed then proceed() end end)

--- Walk every expansion tier and instance, expand each into one job per valid
--- difficulty, and record all dungeon/raid mount drops into EasyMountFarmerGen.
function Gen.Generate()
  if running then ns.Print("Already scanning…"); return end
  if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
  if not (EJ_GetNumTiers and EJ_GetInstanceByIndex and EJ_GetNumLoot and C_EncounterJournal) then
    ns.Print("Encounter Journal API unavailable here.")
    return
  end

  queue, candidates, byKey, scanned, qi = {}, {}, {}, 0, 0
  entranceLoc = harvestEntrances()

  for t = 1, EJ_GetNumTiers() do
    EJ_SelectTier(t)
    local tierName = EJ_GetTierInfo(t) or ("Tier " .. t)
    for _, isRaid in ipairs({ false, true }) do
      local i = 1
      while true do
        local instanceID, instName = EJ_GetInstanceByIndex(i, isRaid)
        if not instanceID then break end
        EJ_SelectInstance(instanceID)
        local encs = encounterMap(instanceID)

        -- one job per valid difficulty (fallback to the current one if none report)
        local diffs = {}
        for _, d in ipairs(CANDIDATE_DIFFS) do
          if EJ_IsValidInstanceDifficulty and EJ_IsValidInstanceDifficulty(d) then diffs[#diffs + 1] = d end
        end
        if #diffs == 0 then diffs = { 0 } end
        for _, d in ipairs(diffs) do
          queue[#queue + 1] = {
            tier = t, tierName = tierName, instanceID = instanceID,
            instName = instName, isRaid = isRaid, encs = encs, difficulty = d,
            loc = entranceLoc[instanceID],
          }
        end
        i = i + 1
      end
    end
  end

  running = true
  scanner:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
  ns.Print(string.format("Scanning %d instance/difficulty combos… (this can take ~1-2 min)", #queue))
  step()
end
