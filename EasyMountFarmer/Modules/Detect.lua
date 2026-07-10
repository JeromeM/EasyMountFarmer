-- Detect.lua — auto-advance when the boss is killed (ENCOUNTER_END) and a
-- congrats popup when the mount is looted (NEW_MOUNT_ADDED).

local ADDON, ns = ...
ns.Detect = ns.Detect or {}
local Detect = ns.Detect

--- Find the active target (and its boss row) whose still-needed mount drops from
--- this encounterID. Only still-needed mounts are considered (collected ones are
--- already pruned from the target's bosses).
---@param encounterID number  encounter journal ID from ENCOUNTER_END
---@return table? target  the matching target from ns.allTargets, or nil if none
---@return table? boss  the matching boss row, or nil if none
local function bossForEncounter(encounterID)
  for _, t in ipairs(ns.allTargets or {}) do
    for _, b in ipairs(t.bosses or {}) do
      if b.encounterID == encounterID then return t, b end
    end
  end
  return nil
end

--- Report whether a mount that drops on `difficulties` could have dropped on the
--- difficulty just cleared. A Mythic Keystone (8) also satisfies a Mythic (23).
---@param difficulties number[]?  the difficultyIDs the mount drops on
---@param difficultyID number?  the difficulty the encounter was fought on
---@return boolean  true if the mount could have dropped
local function difficultyDrops(difficulties, difficultyID)
  if not difficulties or #difficulties == 0 or not difficultyID then return true end
  for _, d in ipairs(difficulties) do
    if d == difficultyID or (d == 23 and difficultyID == 8) then return true end
  end
  return false
end

--- Handle ENCOUNTER_END: on a successful kill of a boss whose still-needed mount
--- could have dropped on the cleared difficulty, mark that run done (source "kill").
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
  local t, b = bossForEncounter(encounterID)
  if not t then return end
  if not difficultyDrops(b.difficulties, difficultyID) then return end
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
