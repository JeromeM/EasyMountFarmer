-- Waypoint.lua — guide to the current target's entrance: TomTom if present,
-- otherwise Blizzard's native user waypoint.

local ADDON, ns = ...
ns.Waypoint = ns.Waypoint or {}
local Waypoint = ns.Waypoint
local L = ns.L

local function isLoaded(name)
  local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  return fn and fn(name)
end

-- If Mapzeroth is present, ask it to route to the waypoint we just set
-- (it has no push API, so we invoke its documented "/mz waypoint" handler).
local function triggerMapzeroth()
  if not isLoaded("Mapzeroth") then return end
  for _, key in ipairs({ "MAPZEROTH", "MZ" }) do
    local fn = SlashCmdList and SlashCmdList[key]
    if fn then fn("waypoint"); return end
  end
end

function Waypoint.GuideTo(target, silent)
  if not target then return end
  local l = (SAMountsLocations or {})[target.key]
  if not l or not l.map or not l.x or not l.y then
    if not silent then
      ns.Print(string.format(L["No coordinates for \"%s\" (fill them in Locations.lua)."], target.title or "?"))
    end
    return
  end

  -- TomTom takes priority
  if TomTom and TomTom.AddWaypoint then
    TomTom:AddWaypoint(l.map, l.x / 100, l.y / 100, {
      title = target.title,
      from = "SAMounts",
      persistent = false,
      minimap = true,
      world = true,
    })
    if not silent then triggerMapzeroth() end
    return
  end

  -- Fallback: Blizzard user waypoint
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(l.map) then
      ns.Print(L["Cannot place a waypoint on that map from here."])
      return
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(l.map, l.x / 100, l.y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    if not silent then triggerMapzeroth() end
    return
  end

  ns.Print(L["No waypoint system available."])
end
