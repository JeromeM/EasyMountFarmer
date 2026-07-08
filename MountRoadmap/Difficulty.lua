-- Difficulty.lua — detects the current difficulty and switches to the one
-- required by the target (dungeon / modern raid / legacy raid).

local ADDON, ns = ...
ns.Difficulty = ns.Difficulty or {}
local Difficulty = ns.Difficulty

-- Short labels per difficultyID.
local DIFF_LABEL = {
  [1] = "Normal", [2] = "Heroic", [23] = "Mythic", [8] = "Mythic Keystone",
  [14] = "Normal", [15] = "Heroic", [16] = "Mythic", [17] = "Looking For Raid",
  [3] = "10 Player", [4] = "25 Player", [5] = "10 Player Heroic", [6] = "25 Player Heroic",
  [7] = "Looking For Raid", [9] = "40 Player",
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
  if not l or not l.reqDiff then return "Difficulty" end
  return "Switch to " .. (DIFF_LABEL[l.reqDiff] or ("difficulty " .. l.reqDiff))
end

function Difficulty.SwitchTo(target)
  local l = locFor(target)
  if not l or not l.reqDiff or not l.diffScope then return end
  if InCombatLockdown() then
    print("|cffffd200Mount Roadmap|r: cannot change difficulty in combat.")
    return
  end
  local fn = _G[SETTERS[l.diffScope] or ""]
  if not fn then return end
  local ok = pcall(fn, l.reqDiff)
  if not ok then
    print("|cffffd200Mount Roadmap|r: cannot change difficulty (party leader required, or already inside the instance).")
  end
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end
