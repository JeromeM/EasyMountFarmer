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

--- Look up the Locations entry for a target.
---@param target table?  a target from ns.allTargets (uses its `key` field)
---@return table?  the matching EasyMountFarmerLocations entry, or nil if none
local function locFor(target)
  if not target then return nil end
  return (EasyMountFarmerLocations or {})[target.key]
end

--- Get the player's current difficulty ID for a given scope.
---@param scope string?  difficulty scope: "dungeon", "raid" or "legacyRaid"
---@return number?  current difficultyID, or nil if the scope is unknown
function Difficulty.GetCurrent(scope)
  local fn = _G[GETTERS[scope or ""] or ""]
  if fn then return fn() end
  return nil
end

--- Report whether we should offer a difficulty switch for this target, i.e. the
--- current difficulty differs from the target's required one. A Mythic Keystone
--- (8) also satisfies a Mythic (23) dungeon requirement.
---@param target table  a target from ns.allTargets
---@return boolean  true if a switch to the required difficulty is needed
function Difficulty.NeedsSwitch(target)
  local l = locFor(target)
  if not l or not l.reqDiff or not l.diffScope then return false end
  local cur = Difficulty.GetCurrent(l.diffScope)
  if cur == nil or cur == l.reqDiff then return false end
  -- A Mythic Keystone (8) also satisfies a Mythic (23) dungeon requirement.
  if l.diffScope == "dungeon" and l.reqDiff == 23 and cur == 8 then return false end
  return true
end

--- Build the button label for switching a target to its required difficulty,
--- e.g. "Switch to Mythic".
---@param target table  a target from ns.allTargets
---@return string  localized button text
function Difficulty.SwitchLabel(target)
  local l = locFor(target)
  if not l or not l.reqDiff then return L["Difficulty"] end
  return string.format(L["Switch to %s"], DIFF_LABEL[l.reqDiff] or tostring(l.reqDiff))
end

--- Switch the relevant difficulty to the one required by the target. Aborts in
--- combat, prints a message if the change fails (party leader required, or
--- already inside the instance), then refreshes the UI. The change is applied
--- asynchronously by the client.
---@param target table  a target from ns.allTargets
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
  -- The change is async; PLAYER_DIFFICULTY_CHANGED (below) refreshes once it lands.
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

-- The difficulty change is applied asynchronously by the client, so re-refresh
-- the window when it actually lands (also catches manual changes via the game UI).
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
f:SetScript("OnEvent", function()
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end)
