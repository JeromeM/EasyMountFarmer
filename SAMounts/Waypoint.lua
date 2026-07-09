-- Waypoint.lua — guide to the current target's entrance: TomTom if present,
-- otherwise Blizzard's native user waypoint.

local ADDON, ns = ...
ns.Waypoint = ns.Waypoint or {}
local Waypoint = ns.Waypoint
local L = ns.L

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
    return
  end

  ns.Print(L["No waypoint system available."])
end
