-- Progress.lua — current step, per-reset completions, and the "auto-follow"
-- pointer that always sits on the first step still to do.
--
-- Two states per target:
--   * permanent : mount collected -> the target leaves the list (via C_MountJournal, in Route)
--   * per-reset : boss killed / instance locked / world-boss quest done this reset
--       -> the step STAYS in the list (so the total is stable) but is flagged "done"
--          and shown with a marker; the pointer skips over it.
--
-- ns.activeTargets = every target with an uncollected mount (done ones included).
-- ns.autoFollow = while true (until the user navigates), the pointer auto-snaps to
--   the first not-done step, so kills/lockouts/resets advance it automatically.

local ADDON, ns = ...
ns.Progress = ns.Progress or {}
local Progress = ns.Progress

ns.autoFollow = true

local DAY = 86400
local WEEK = 7 * 86400

-- --- time until reset (native API, defensive fallbacks) --------------------
--- Return the number of seconds until the daily reset (native API, with fallbacks).
---@return number  seconds until the next daily reset
function Progress.SecondsUntilDaily()
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
    return C_DateAndTime.GetSecondsUntilDailyReset()
  end
  return (GetQuestResetTime and GetQuestResetTime()) or DAY
end

--- Return the number of seconds until the weekly reset (native API, with fallback).
---@return number  seconds until the next weekly reset
function Progress.SecondsUntilWeekly()
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
    return C_DateAndTime.GetSecondsUntilWeeklyReset()
  end
  return WEEK
end

--- Report whether a run is completed this reset via its tracking quest flag
--- (world bosses, and anything with a questId in Locations). Checked live so it
--- clears itself automatically at reset.
---@param key string  target key (index into EasyMountFarmerLocations)
---@return boolean  true if the tracking quest is flagged completed
function Progress.IsDoneByQuest(key)
  local l = (EasyMountFarmerLocations or {})[key]
  local q = l and l.questId
  if not q then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    return C_QuestLog.IsQuestFlaggedCompleted(q)
  end
  return false
end

--- Report whether a stored doneRun is still valid (i.e. its reset has not passed).
---@param entry table?  doneRun entry with `at` timestamp and `type`
---@return boolean  true if the entry is still within the current reset window
function Progress.IsDoneValid(entry)
  if not entry or not entry.at then return false end
  local now = time()
  if entry.type == "Dungeon" then
    return entry.at >= (now + Progress.SecondsUntilDaily() - DAY)
  end
  return entry.at >= (now + Progress.SecondsUntilWeekly() - WEEK)
end

--- Report whether a step is done for the current reset (quest flag OR a still-valid doneRun).
---@param key string?  target key
---@return boolean  true if the step is done this reset
function Progress.IsDone(key)
  if not key then return false end
  if Progress.IsDoneByQuest(key) then return true end
  local d = ns.charDB and ns.charDB.doneRuns and ns.charDB.doneRuns[key]
  return (d and Progress.IsDoneValid(d)) or false
end

-- --- access ---------------------------------------------------------------
--- Return the list of active targets (uncollected mounts, done ones included).
---@return table  active targets list (empty table when none)
function Progress.Active()
  return ns.activeTargets or {}
end

--- Return the currently pointed-to target, or nil when there are none.
---@return table?  the current target, or nil if the list is empty
function Progress.Current()
  local a = ns.activeTargets
  if not a or #a == 0 then return nil end
  local idx = (ns.charDB and ns.charDB.currentIdx) or 1
  return a[idx]
end

--- Return the current pointer index (defaults to 1).
---@return number  current target index
function Progress.Index()
  return (ns.charDB and ns.charDB.currentIdx) or 1
end

--- Report whether at least one step is still to do this reset.
---@return boolean  true if any active target is not done
function Progress.AnyUndone()
  for _, t in ipairs(ns.activeTargets or {}) do
    if not Progress.IsDone(t.key) then return true end
  end
  return false
end

--- Report whether auto-follow is active: only when the user hasn't manually
--- navigated AND the "auto-advance" preference is on.
---@return boolean  true if the pointer should auto-snap to the next step
function Progress.AutoFollowing()
  return (not ns.db or ns.db.autoAdvance ~= false) and ns.autoFollow
end

--- Return the index of the first not-done step; if all are done, keep the current index.
---@return number  index of the first undone target (clamped to the list bounds)
function Progress.FirstUndoneIndex()
  local a = ns.activeTargets or {}
  for i, t in ipairs(a) do
    if not Progress.IsDone(t.key) then return i end
  end
  local idx = (ns.charDB and ns.charDB.currentIdx) or 1
  if idx < 1 then idx = 1 end
  if #a > 0 and idx > #a then idx = #a end
  return idx
end

-- --- rebuild --------------------------------------------------------------
--- Rebuild the active targets list and reposition the pointer, refreshing the UI.
--- resetPointer=true re-enables auto-follow (used on resets / manual reset).
---@param resetPointer boolean?  when true, re-enable auto-follow before rebuilding
function Progress.Rebuild(resetPointer)
  if resetPointer then ns.autoFollow = true end
  local prevKey = Progress.Current() and Progress.Current().key or nil

  ns.allTargets = ns.Route.BuildTargets()

  -- Keep ALL targets (done ones included, so the total is stable). "lowPriority"
  -- runs have no reset lock (farmable any time, e.g. Stratholme Baron): push them
  -- to the very end so time-gated content comes first.
  local loc = EasyMountFarmerLocations or {}
  local normal, low = {}, {}
  for _, t in ipairs(ns.allTargets) do
    local l = loc[t.key]
    if l and l.lowPriority then low[#low + 1] = t else normal[#normal + 1] = t end
  end
  for _, t in ipairs(low) do normal[#normal + 1] = t end
  ns.activeTargets = normal
  local n = #normal

  local idx
  if Progress.AutoFollowing() then
    idx = Progress.FirstUndoneIndex()   -- always sit on the next thing to do
  elseif prevKey then
    idx = nil
    for i, t in ipairs(normal) do
      if t.key == prevKey then idx = i break end
    end
    idx = idx or (ns.charDB.currentIdx or 1)
  else
    idx = ns.charDB.currentIdx or 1
  end
  if n == 0 then idx = 1 elseif idx < 1 then idx = 1 elseif idx > n then idx = n end
  ns.charDB.currentIdx = idx

  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

-- --- navigation -----------------------------------------------------------
--- Move the pointer to the next target. Manual navigation turns auto-follow OFF
--- so the pointer stays where the user put it (they can review done steps); it
--- re-enables on reset / login.
function Progress.Next()
  local n = #(ns.activeTargets or {})
  if n == 0 then return end
  ns.autoFollow = false
  ns.charDB.currentIdx = math.min((ns.charDB.currentIdx or 1) + 1, n)
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

--- Move the pointer to the previous target (turns auto-follow off; see Next).
function Progress.Prev()
  local n = #(ns.activeTargets or {})
  if n == 0 then return end
  ns.autoFollow = false
  ns.charDB.currentIdx = math.max((ns.charDB.currentIdx or 1) - 1, 1)
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

--- Re-enable auto-follow and jump to the first step still to do, refreshing the UI.
function Progress.ResetPointer()
  ns.autoFollow = true
  local n = #(ns.activeTargets or {})
  ns.charDB.currentIdx = (n > 0) and Progress.FirstUndoneIndex() or 1
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

--- Move the pointer forward to the next not-done step (wrapping around once), or
--- stay put if everything is done this reset. Used for auto-advance after a
--- detected kill/lockout; while auto-following, Rebuild already re-snaps the
--- pointer, so this handles the manual-navigation case.
function Progress.AdvanceToNextUndone()
  local a = ns.activeTargets or {}
  local n = #a
  if n == 0 then return end
  local start = ns.charDB.currentIdx or 1
  for i = start + 1, n do
    if not Progress.IsDone(a[i].key) then
      ns.charDB.currentIdx = i
      if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
      return
    end
  end
  for i = 1, start - 1 do
    if not Progress.IsDone(a[i].key) then
      ns.charDB.currentIdx = i
      if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
      return
    end
  end
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

--- Return the reset cadence type for a run: mythic dungeons lock WEEKLY (like
--- raids), not daily.
---@param key string  target key (index into EasyMountFarmerLocations)
---@param ptype string?  fallback reset type when no special rule applies
---@return string  reset type ("WeeklyDungeon", the given ptype, or "Raid")
function Progress.ResetTypeFor(key, ptype)
  local l = (EasyMountFarmerLocations or {})[key]
  if l and l.diffScope == "dungeon" and l.reqDiff == 23 then return "WeeklyDungeon" end
  return ptype or "Raid"
end

--- Mark a run done for this reset, then rebuild and (when appropriate) advance
--- the pointer. Sets a "leave instance" hint when a boss is killed while inside.
---@param key string?  target key to mark done
---@param ptype string?  reset type hint passed to ResetTypeFor
---@param source string?  how it was marked done ("kill", "manual", ...; defaults to "kill")
function Progress.MarkDone(key, ptype, source)
  if not key then return end
  local cur = Progress.Current()
  local wasCurrent = cur and cur.key == key
  ns.charDB.doneRuns[key] = { at = time(), type = Progress.ResetTypeFor(key, ptype), source = source or "kill" }
  -- completed a boss while inside an instance -> hint the player to head out
  if (source == nil or source == "kill" or source == "manual") and IsInInstance() then
    ns.leaveInstanceHint = true
  end
  Progress.Rebuild()
  -- Completing the step you're on advances to the next thing to do, even if you
  -- had navigated manually (auto-follow off). When auto-following, Rebuild already
  -- re-snapped the pointer, so don't double-advance.
  if wasCurrent and (not ns.db or ns.db.autoAdvance ~= false) and not Progress.AutoFollowing() then
    Progress.AdvanceToNextUndone()
  end
end

--- Re-sync (slash / minimap): return to auto-follow and jump to the first step
--- still to do. Does NOT wipe detected progress -- doneRuns is persistent, and
--- some kills (e.g. heroic dungeons) only re-detect on a zone change, so wiping
--- would briefly lose them and stall the pointer. A background raid-info refresh
--- catches anything newly locked.
function Progress.ResetAllDone()
  ns.autoFollow = true
  if RequestRaidInfo then RequestRaidInfo() end
  Progress.Rebuild(true)
end

-- --- reset handling -------------------------------------------------------
--- Purge stale doneRuns and, if a reset boundary was crossed, re-enable
--- auto-follow via Rebuild. Call on login, on PLAYER_ENTERING_WORLD, and periodically.
function Progress.CheckResets()
  local db = ns.charDB
  db.doneRuns = db.doneRuns or {}
  local now = time()
  local lastDaily = now + Progress.SecondsUntilDaily() - DAY
  local lastWeekly = now + Progress.SecondsUntilWeekly() - WEEK
  local crossed = false

  if not db.seenDaily or db.seenDaily < lastDaily then
    for k, v in pairs(db.doneRuns) do
      if v.type == "Dungeon" and v.at < lastDaily then db.doneRuns[k] = nil end
    end
    db.seenDaily = lastDaily
    crossed = true
  end
  if not db.seenWeekly or db.seenWeekly < lastWeekly then
    for k, v in pairs(db.doneRuns) do
      if (v.type == "Raid" or v.type == "WeeklyDungeon") and v.at < lastWeekly then
        db.doneRuns[k] = nil
      end
    end
    db.seenWeekly = lastWeekly
    crossed = true
  end

  Progress.Rebuild(crossed)
end
