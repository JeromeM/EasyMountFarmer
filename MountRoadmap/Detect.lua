-- Detect.lua — auto-advance when the boss is killed (ENCOUNTER_END) and a
-- congrats popup when the mount is looted (NEW_MOUNT_ADDED).

local ADDON, ns = ...
ns.Detect = ns.Detect or {}
local Detect = ns.Detect

-- Find the active target whose boss matches this encounterID.
local function targetForEncounter(encounterID)
  local loc = MountRoadmapLocations or {}
  for _, t in ipairs(ns.allTargets or {}) do
    local l = loc[t.key]
    if l and l.encounters then
      for _, encID in pairs(l.encounters) do
        if encID == encounterID then return t, l end
      end
    end
  end
  return nil
end

local function onEncounterEnd(encounterID, _, difficultyID, _, success)
  if success ~= 1 then return end
  if not ns.charDB then return end
  local t, l = targetForEncounter(encounterID)
  if not t then return end
  -- if a difficulty is required, only count it when it matches
  if l.reqDiff and difficultyID and difficultyID ~= l.reqDiff then return end
  ns.Progress.MarkDone(t.key, t.type)
end

local function onNewMount(mountID)
  if not mountID or not ns.Route then return end
  if not ns.Route.IsRouteMount(mountID) then return end
  local name, _, icon = C_MountJournal.GetMountInfoByID(mountID)
  if ns.UI and ns.UI.ShowLootPopup then
    ns.UI.ShowLootPopup(name, icon)
  end
  if ns.Progress then ns.Progress.Rebuild() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("NEW_MOUNT_ADDED")
f:SetScript("OnEvent", function(_, event, a, b, c, d, e)
  if event == "ENCOUNTER_END" then
    onEncounterEnd(a, b, c, d, e)
  elseif event == "NEW_MOUNT_ADDED" then
    onNewMount(a)
  end
end)
