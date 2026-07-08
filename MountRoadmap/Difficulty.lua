-- Difficulty.lua — detects the current difficulty and switches to the one
-- required by the target (dungeon / modern raid / legacy raid).

local ADDON, ns = ...
ns.Difficulty = ns.Difficulty or {}
local Difficulty = ns.Difficulty
local L = ns.L

-- Short labels per difficultyID (localized).
local DIFF_LABEL = {
  [1] = L["Normal"], [2] = L["Heroic"], [23] = L["Mythic"], [8] = L["Mythic Keystone"],
  [14] = L["Normal"], [15] = L["Heroic"], [16] = L["Mythic"], [17] = L["Looking For Raid"],
  [3] = L["10 Player"], [4] = L["25 Player"], [5] = L["10 Player Heroic"], [6] = L["25 Player Heroic"],
  [7] = L["Looking For Raid"], [9] = L["40 Player"],
}

local GETTERS = {
  dungeon = "GetDungeonDifficultyID",
  raid = "GetRaidDifficultyID",
  legacyRaid = "GetLegacyRaidDifficultyID",
}
local SETTERS = {
  dungeon = "SetDungeonDifficultyID",
  raid = "SetRaidDifficultyID",
  legacyRaid = "SetLegacyRaidDifficultyID",
}

local function locFor(target)
  if not target then return nil end
  return (MountRoadmapLocations or {})[target.key]
end

function Difficulty.GetCurrent(scope)
  local fn = _G[GETTERS[scope or ""] or ""]
  if fn then return fn() end
  return nil
end

-- Should we offer a difficulty switch for this target?
function Difficulty.NeedsSwitch(target)
  local l = locFor(target)
  if not l or not l.reqDiff or not l.diffScope then return false end
  local cur = Difficulty.GetCurrent(l.diffScope)
  return cur ~= nil and cur ~= l.reqDiff
end

-- Button text, e.g. "Switch to Mythic".
function Difficulty.SwitchLabel(target)
  local l = locFor(target)
  if not l or not l.reqDiff then return L["Difficulty"] end
  return string.format(L["Switch to %s"], DIFF_LABEL[l.reqDiff] or tostring(l.reqDiff))
end

function Difficulty.SwitchTo(target)
  local l = locFor(target)
  if not l or not l.reqDiff or not l.diffScope then return end
  if InCombatLockdown() then
    ns.Print(L["Cannot change difficulty in combat."])
    return
  end
  local fn = _G[SETTERS[l.diffScope] or ""]
  if not fn then return end
  local ok = pcall(fn, l.reqDiff)
  if not ok then
    ns.Print(L["Cannot change difficulty (party leader required, or already inside the instance)."])
  end
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end
