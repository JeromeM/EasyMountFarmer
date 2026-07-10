-- Route.lua — builds the ordered list of "farm targets" from EasyMountFarmerRouteData
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

-- Route breadcrumb localization.
-- The travel-step labels come from planner.json in English. When we know the
-- zone's UiMapID we resolve its name via C_Map.GetMapInfo (the game's own
-- localized name -> always correct, in every locale) and pair it with a
-- localized verb template. Labels not listed here fall back to a hand
-- translation in the locale file (or English via the L metatable).
local HOP_VERB = {
  fly = "Fly to %s", flightpath = "Fly to %s", portal = "Portal to %s",
  walk = "Walk to %s", teleport = "Teleport to %s", hearth = "Hearthstone to %s",
}

ns.RouteHops = {
  -- Northrend
  ["Fly to Howling Fjord"]                 = { v = "fly",        m = 117 },
  ["Fly to Icecrown"]                      = { v = "fly",        m = 118 },
  ["Fly to Storm Peaks"]                   = { v = "fly",        m = 120 },
  ["Fly to Wintergrasp"]                   = { v = "fly",        m = 123 },
  -- Eastern Kingdoms / Kalimdor
  ["Fly to Eastern Plaguelands"]           = { v = "fly",        m = 23 },
  ["Fly to Deadwind Pass"]                 = { v = "fly",        m = 42 },
  ["Fly to Dustwallow Marsh"]              = { v = "fly",        m = 70 },
  ["Fly to Silithus"]                      = { v = "fly",        m = 81 },
  ["Fly to Ghostlands"]                    = { v = "fly",        m = 95 },
  ["Flightpath to Eversong Woods"]         = { v = "flightpath", m = 94 },
  ["Flightpath to Isle of Quel'Danas"]     = { v = "flightpath", m = 122 },
  ["Portal to Isle of Quel'Danas"]         = { v = "portal",     m = 122 },
  ["Portal to Silvermoon"]                 = { v = "portal",     m = 110 },
  ["Portal to Deepholm"]                   = { v = "portal",     m = 207 },
  ["Portal to Hyjal"]                      = { v = "portal",     m = 198 },
  ["Portal to Uldum"]                      = { v = "portal",     m = 249 },
  -- Outland
  ["Fly to Netherstorm"]                   = { v = "fly",        m = 109 },
  ["Fly to Shattrath"]                     = { v = "fly",        m = 111 },
  ["Portal to Shattrath"]                  = { v = "portal",     m = 111 },
  -- Pandaria
  ["Fly to Kun-Lai Summit"]                = { v = "fly",        m = 379 },
  ["Portal to Jade Forest"]                = { v = "portal",     m = 371 },
  ["Fly to Vale of the Eternal Blossoms"]  = { v = "fly",        m = 390 },
  ["Portal to Isle of Thunder"]            = { v = "portal",     m = 504 },
  ["Fly to Isle of Giants"]                = { v = "fly",        m = 507 },
  -- Warlords of Draenor
  ["Fly to Tanaan Jungle"]                 = { v = "fly",        m = 534 },
  ["Fly to Spires of Arak"]                = { v = "fly",        m = 542 },
  ["Fly to Gorgrond"]                      = { v = "fly",        m = 543 },
  -- Legion
  ["Fly to Broken Shore"]                  = { v = "fly",        m = 646 },
  ["Fly to Suramar"]                       = { v = "fly",        m = 680 },
  ["Portal to Antoran Wastes"]             = { v = "portal",     m = 885 },
  -- Battle for Azeroth
  ["Walk to Nazmir"]                       = { v = "walk",       m = 863 },
  ["Walk to Zuldazar"]                     = { v = "walk",       m = 862 },
  ["Walk to Tiragarde Sound"]              = { v = "walk",       m = 895 },
  -- Shadowlands
  ["Portal to Oribos"]                     = { v = "portal",     m = 1670 },
  ["Flightpath to Bastion"]                = { v = "flightpath", m = 1533 },
  ["Teleport to Zereth Mortis"]            = { v = "teleport",   m = 1970 },
  -- Dragonflight
  ["Portal to Valdrakken"]                 = { v = "portal",     m = 2112 },
}

-- Localize a breadcrumb label: game-resolved zone name when we have a map ID,
-- otherwise the hand translation / English.
function ns.LocalizeHop(label)
  if not label then return "" end
  local h = ns.RouteHops[label]
  if h and h.m and C_Map and C_Map.GetMapInfo then
    local info = C_Map.GetMapInfo(h.m)
    if info and info.name and info.name ~= "" then
      return string.format(L[HOP_VERB[h.v] or "%s"], info.name)
    end
  end
  return L[label]
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
  if EasyMountFarmerRouteData then walk(EasyMountFarmerRouteData) end
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
          entry = { label = (label:gsub("^and ", ""):gsub("%s+$", "")), capital = step.capital }
        end
        walk(step.steps, entry and copyTrail(trail, entry) or trail)
      end
    end
  end

  if EasyMountFarmerRouteData then walk(EasyMountFarmerRouteData, {}) end
  return targets
end

-- Total number of mounts still to farm (across all targets, ignoring lockouts).
function Route.CountRemainingMounts(targets)
  local n = 0
  for _, t in ipairs(targets) do n = n + #t.bosses end
  return n
end
