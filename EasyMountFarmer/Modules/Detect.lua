-- Detect.lua — auto-advance when the boss is killed (ENCOUNTER_END) and a
-- congrats popup when the mount is looted (NEW_MOUNT_ADDED).

local ADDON, ns = ...
ns.Detect = ns.Detect or {}
local Detect = ns.Detect

--- Find the active target whose boss matches this encounterID.
---@param encounterID number  encounter journal ID from ENCOUNTER_END
---@return table? target  the matching target from ns.allTargets, or nil if none
---@return table? location  its EasyMountFarmerLocations entry, or nil if none
local function targetForEncounter(encounterID)
  local loc = EasyMountFarmerLocations or {}
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

--- Handle ENCOUNTER_END: on a successful kill of a boss belonging to an active
--- target, mark that run done (source "kill"). Only counts on a difficulty where
--- the mount can drop; a Mythic Keystone (8) also satisfies a Mythic (23)
--- requirement.
---@param encounterID number  encounter journal ID of the boss
---@param encName string  encounter name
---@param difficultyID number  difficulty the encounter was fought on
---@param _ any  group size (unused)
---@param success number  1 if the encounter ended in a kill
local function onEncounterEnd(encounterID, encName, difficultyID, _, success)
  if success ~= 1 then return end
  if not ns.charDB then return end
  if ns.db and ns.db.encDebug then
    ns.Print(string.format("ENCOUNTER_END: id=|cffffff00%s|r  name=%s  diff=%s",
      tostring(encounterID), tostring(encName), tostring(difficultyID)))
  end
  local t, l = targetForEncounter(encounterID)
  if not t then return end
  -- count the kill only on a difficulty where the mount can drop; a Mythic
  -- Keystone (8) also satisfies a Mythic (23) requirement.
  if l.reqDiff and difficultyID and difficultyID ~= l.reqDiff
     and not (l.reqDiff == 23 and difficultyID == 8) then
    return
  end
  ns.Progress.MarkDone(t.key, t.type, "kill")
end

--- Handle NEW_MOUNT_ADDED: if the looted mount is on the current route, show the
--- loot congrats popup, optionally announce it in the configured chat channel,
--- and rebuild progress.
---@param mountID number?  journal ID of the newly added mount
local function onNewMount(mountID)
  if not mountID or not ns.Route then return end
  if not ns.Route.IsRouteMount(mountID) then return end
  local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
  if ns.UI and ns.UI.ShowLootPopup and (not ns.db or ns.db.lootPopup ~= false) then
    ns.UI.ShowLootPopup(name, icon)
  end
  local chan = ns.db and ns.db.lootChannel
  if chan and chan ~= "NONE" and name then
    local link = spellID and ((C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(spellID))
      or (GetSpellLink and GetSpellLink(spellID)))
    pcall(SendChatMessage, string.format(ns.L["Looted the mount: %s!"], link or name), chan)
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
