-- Progress.lua — current step, per-reset completions, and jumping back to step 1
-- when the daily / weekly reset boundary is crossed.
--
-- Two states:
--   * permanent : mount collected -> the target disappears (handled by Route via C_MountJournal)
--   * per-reset : boss already killed this reset -> charDB.doneRuns[key] = { at, type }
--
-- "Active" list = remaining targets minus doneRuns that are still valid.
-- currentIdx points into that active list.

local ADDON, ns = ...
ns.Progress = ns.Progress or {}
local Progress = ns.Progress

local DAY = 86400
local WEEK = 7 * 86400

-- --- time until reset (native API, defensive fallbacks) --------------------
function Progress.SecondsUntilDaily()
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
    return C_DateAndTime.GetSecondsUntilDailyReset()
  end
  return (GetQuestResetTime and GetQuestResetTime()) or DAY
end

function Progress.SecondsUntilWeekly()
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
    return C_DateAndTime.GetSecondsUntilWeeklyReset()
  end
  return WEEK
end

-- Is this run already completed this reset according to its weekly/daily
-- tracking quest (world bosses, and anything with a questId in Locations)?
-- Checked live so it clears itself automatically at reset.
function Progress.IsDoneByQuest(key)
  local l = (SAMountsLocations or {})[key]
  local q = l and l.questId
  if not q then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    return C_QuestLog.IsQuestFlaggedCompleted(q)
  end
  return false
end

-- Is a doneRun still valid (not yet reset)?
function Progress.IsDoneValid(entry)
  if not entry or not entry.at then return false end
  local now = time()
  if entry.type == "Dungeon" then
    return entry.at >= (now + Progress.SecondsUntilDaily() - DAY)
  end
  return entry.at >= (now + Progress.SecondsUntilWeekly() - WEEK)
end

-- --- access ---------------------------------------------------------------
function Progress.Active()
  return ns.activeTargets or {}
end

function Progress.Current()
  local a = ns.activeTargets
  if not a or #a == 0 then return nil end
  local idx = (ns.charDB and ns.charDB.currentIdx) or 1
  return a[idx]
end

function Progress.Index()
  return (ns.charDB and ns.charDB.currentIdx) or 1
end

-- --- rebuild --------------------------------------------------------------
-- resetPointer=true jumps the pointer back to step 1 (used on resets).
function Progress.Rebuild(resetPointer)
  local prevKey = not resetPointer and Progress.Current() and Progress.Current().key or nil

  ns.allTargets = ns.Route.BuildTargets()

  -- "lowPriority" runs have no reset lock (farmable any time, e.g. Stratholme
  -- Baron): keep them but push them to the very end so time-gated content comes first.
  local loc = SAMountsLocations or {}
  local normal, low = {}, {}
  for _, t in ipairs(ns.allTargets) do
    local d = ns.charDB.doneRuns[t.key]
    local done = Progress.IsDoneByQuest(t.key) or (d and Progress.IsDoneValid(d))
    if not done then
      local l = loc[t.key]
      if l and l.lowPriority then low[#low + 1] = t else normal[#normal + 1] = t end
    end
  end
  for _, t in ipairs(low) do normal[#normal + 1] = t end
  local active = normal
  ns.activeTargets = active

  local idx = ns.charDB.currentIdx or 1
  if resetPointer then
    idx = 1
  elseif prevKey then
    for i, t in ipairs(active) do
      if t.key == prevKey then idx = i break end
    end
  end
  if idx < 1 then idx = 1 end
  if #active == 0 then idx = 1 elseif idx > #active then idx = #active end
  ns.charDB.currentIdx = idx

  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

-- --- navigation -----------------------------------------------------------
function Progress.Next()
  local n = #(ns.activeTargets or {})
  if n == 0 then return end
  ns.charDB.currentIdx = math.min((ns.charDB.currentIdx or 1) + 1, n)
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

function Progress.Prev()
  local n = #(ns.activeTargets or {})
  if n == 0 then return end
  ns.charDB.currentIdx = math.max((ns.charDB.currentIdx or 1) - 1, 1)
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

function Progress.ResetPointer()
  ns.charDB.currentIdx = 1
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

-- Mark a run as done for this reset (auto-advance / detected lockout).
function Progress.MarkDone(key, ptype)
  if not key then return end
  ns.charDB.doneRuns[key] = { at = time(), type = ptype or "Raid" }
  Progress.Rebuild()
end

-- Manually clear per-reset completions (button / slash command).
function Progress.ResetAllDone()
  wipe(ns.charDB.doneRuns)
  Progress.Rebuild(true)
end

-- --- reset handling -------------------------------------------------------
-- Call on login, on PLAYER_ENTERING_WORLD, and periodically.
-- Purges stale doneRuns and, if a reset boundary was crossed, jumps back to step 1.
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
