-- Route.lua — builds the ordered list of "farm targets" from SAMountsRouteData
-- (generated from planner.json), pruning mounts already collected and mounts for
-- the wrong faction.

local ADDON, ns = ...
ns.Route = ns.Route or {}
local Route = ns.Route
local L = ns.L

-- Capital name for the faction, used in the "capital" breadcrumb entry.
local function CapitalName(isAlliance)
  return isAlliance and L["Stormwind"] or L["Orgrimmar"]
end

-- True if the mount (mount journal ID) is already collected.
function Route.IsMountCollected(id)
  if not id then return false end
  local ok, isCollected = pcall(function()
    return select(11, C_MountJournal.GetMountInfoByID(id))
  end)
  return ok and isCollected == true
end

-- Set of every mount ID present in the route (to filter NEW_MOUNT_ADDED).
local routeMountSet
local function BuildRouteMountSet()
  routeMountSet = {}
  local function walk(steps)
    for _, step in ipairs(steps) do
      if step.bosses then
        for _, b in ipairs(step.bosses) do
          if b.ID then routeMountSet[b.ID] = true end
        end
      end
      if step.steps then walk(step.steps) end
    end
  end
  if SAMountsRouteData then walk(SAMountsRouteData) end
end

function Route.IsRouteMount(mountID)
  if not routeMountSet then BuildRouteMountSet() end
  return routeMountSet[mountID] == true
end

-- Builds the flat, ordered list of targets.
-- A target = a run (leaf with bosses) that still has at least one uncollected
-- mount of the right faction. Fields: key, title, type, bosses (filtered),
-- breadcrumb (travel steps leading to the target).
function Route.BuildTargets()
  local faction = UnitFactionGroup("player")
  local isAlliance = (faction == "Alliance")
  local targets = {}

  local function copyTrail(trail, entry)
    local t = {}
    for i = 1, #trail do t[i] = trail[i] end
    if entry then t[#t + 1] = entry end
    return t
  end

  local function needBoss(b)
    if not b.ID then return false end
    if Route.IsMountCollected(b.ID) then return false end
    local neutral = not b.isAlliance and not b.isHorde
    if neutral then return true end
    if b.isAlliance then return isAlliance end
    if b.isHorde then return not isAlliance end
    return true
  end

  local function walk(steps, trail)
    for _, step in ipairs(steps) do
      if step.bosses then
        local needed = {}
        for _, b in ipairs(step.bosses) do
          if needBoss(b) then needed[#needed + 1] = b end
        end
        if #needed > 0 then
          targets[#targets + 1] = {
            key = step.title,
            title = step.title,
            type = step.type,
            bosses = needed,
            breadcrumb = trail,
          }
        end
      elseif step.steps then
        local label = step.title
        local entry
        if step.startStep then
          -- the initial "hearthstone to your faction capital" step
          entry = { label = string.format(L["Hearthstone: %s"], CapitalName(isAlliance)), hearth = true }
        elseif label and label ~= "" and label ~= "Start in " then
          entry = { label = (label:gsub("^and ", "")), capital = step.capital }
        end
        walk(step.steps, entry and copyTrail(trail, entry) or trail)
      end
    end
  end

  if SAMountsRouteData then walk(SAMountsRouteData, {}) end
  return targets
end

-- Total number of mounts still to farm (across all targets, ignoring lockouts).
function Route.CountRemainingMounts(targets)
  local n = 0
  for _, t in ipairs(targets) do n = n + #t.bosses end
  return n
end
