-- Lockouts.lua — detects instances already locked this reset
-- (GetSavedInstanceInfo) and marks the matching runs as done.

local ADDON, ns = ...
ns.Lockouts = ns.Lockouts or {}
local Lockouts = ns.Lockouts

--- Scan the player's saved instances and lock-mark matching farm runs as done.
--- Matches saved instances by stable instanceId first, then by English lockout
--- name as a fallback. Never lock-marks the instance we are currently inside
--- (and clears any stale lock-mark left on it). Rebuilds progress if anything
--- changed.
function Lockouts.Scan()
  if not ns.charDB or not ns.Progress then return end

  -- Match saved instances by stable instanceId (locale-independent), with the
  -- instance's own (already localized) name as a fallback for runs lacking an id.
  local byInstanceId, byName = {}, {}
  for _, t in ipairs(ns.allTargets or {}) do
    if t.instanceId then byInstanceId[t.instanceId] = t end
    if t.instance then byName[t.instance] = t end
  end
  if not next(byInstanceId) and not next(byName) then return end

  -- The instance we are standing in right now: being saved to it does NOT mean
  -- the mount boss is dead (we may be mid-run and still able to kill it), so we
  -- never lock-mark the current instance -- only a real boss kill (ENCOUNTER_END,
  -- source "kill") marks it. We also drop a stale lock-mark left on it.
  local insideId
  if IsInInstance() then insideId = select(8, GetInstanceInfo()) end

  local changed = false
  for i = 1, GetNumSavedInstances() do
    local info = { GetSavedInstanceInfo(i) }
    local name, reset, locked, instanceId = info[1], info[3], info[5], info[14]
    if locked and reset and reset > 0 then
      local t = (instanceId and byInstanceId[instanceId]) or (name and byName[name])
      if t then
        if insideId and instanceId == insideId then
          local d = ns.charDB.doneRuns[t.key]
          if d and d.source == "lock" then ns.charDB.doneRuns[t.key] = nil; changed = true end
        elseif not ns.charDB.doneRuns[t.key] then
          ns.charDB.doneRuns[t.key] = { at = time(), type = ns.Progress.ResetTypeFor(t.key, t.type), source = "lock" }
          changed = true
        end
      end
    end
  end
  if changed then ns.Progress.Rebuild() end
end

-- Event frame: request raid info, then scan when it arrives.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_INSTANCE_INFO")
f:RegisterEvent("BOSS_KILL")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" or event == "BOSS_KILL" then
    RequestRaidInfo()   -- triggers UPDATE_INSTANCE_INFO
  else -- UPDATE_INSTANCE_INFO
    Lockouts.Scan()
  end
end)
