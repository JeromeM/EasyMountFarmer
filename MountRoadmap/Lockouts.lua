-- Lockouts.lua — detects instances already locked this reset
-- (GetSavedInstanceInfo) and marks the matching runs as done.

local ADDON, ns = ...
ns.Lockouts = ns.Lockouts or {}
local Lockouts = ns.Lockouts

function Lockouts.Scan()
  if not ns.charDB or not ns.Progress then return end
  local loc = MountRoadmapLocations or {}

  -- map lockout name -> target (among still-active/relevant targets)
  local byLockout = {}
  for _, t in ipairs(ns.allTargets or {}) do
    local l = loc[t.key]
    if l and l.lockout then byLockout[l.lockout] = t end
  end
  if not next(byLockout) then return end

  local changed = false
  for i = 1, GetNumSavedInstances() do
    local name, _, reset, _, locked = GetSavedInstanceInfo(i)
    if locked and reset and reset > 0 and name then
      local t = byLockout[name]
      if t then
        ns.charDB.doneRuns[t.key] = { at = time(), type = t.type or "Raid" }
        changed = true
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
