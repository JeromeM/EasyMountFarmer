-- Waypoint.lua — guide to a point: TomTom if present, otherwise Blizzard's
-- native user waypoint. We track the waypoint we set so Clear() only removes
-- ours (never a waypoint the player placed by hand).

local ADDON, ns = ...
ns.Waypoint = ns.Waypoint or {}
local Waypoint = ns.Waypoint
local L = ns.L

-- Use TomTom only when it is present AND the user hasn't disabled it.
local function useTomTom()
  return TomTom and TomTom.AddWaypoint and (not ns.db or ns.db.useTomTom ~= false)
end

-- Resolve a run's entrance from the game's Encounter Journal when it defines
-- entranceJID + candidate entranceMaps. Some raids' portals move (e.g. Ny'alotha,
-- whose entrance follows the weekly N'Zoth assault between Uldum and the Vale);
-- the game only lists the entrance on the map where it currently is, so this
-- auto-tracks the rotation. Returns map, x, y in 0-100, or nil.
local function liveEntrance(l)
  if not (l and l.entranceJID and l.entranceMaps) then return end
  if not (C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap) then return end
  for _, mapId in ipairs(l.entranceMaps) do
    local ok, list = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapId)
    if ok and type(list) == "table" then
      for _, e in ipairs(list) do
        if e.journalInstanceID == l.entranceJID and e.position then
          local px, py
          if e.position.GetXY then px, py = e.position:GetXY() end
          px = px or e.position.x; py = py or e.position.y
          if px and py then return mapId, px * 100, py * 100 end
        end
      end
    end
  end
end

-- Effective entrance coords (0-100) for a run key: live Encounter-Journal
-- resolution first, then the static Locations coords as a fallback.
function ns.EntranceFor(key)
  local l = (EasyMountFarmerLocations or {})[key]
  if not l then return end
  local m, x, y = liveEntrance(l)
  if m then return m, x, y end
  if l.map and l.x and l.y then return l.map, l.x, l.y end
end

-- Remove the waypoint WE set (if any).
function Waypoint.Clear()
  if TomTom and Waypoint._uid then
    if TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, Waypoint._uid) end
    Waypoint._uid = nil
  end
  if Waypoint._blizzard and C_Map and C_Map.ClearUserWaypoint then
    C_Map.ClearUserWaypoint()
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    end
    Waypoint._blizzard = nil
  end
end

-- Low-level: set a waypoint/arrow to an explicit UI map point (x,y in 0-1).
function Waypoint.SetTo(mapID, x, y, title)
  if not mapID or not x or not y then return end
  Waypoint.Clear()   -- drop our previous one first

  if useTomTom() then
    Waypoint._uid = TomTom:AddWaypoint(mapID, x, y, {
      title = title, from = "EasyMountFarmer", persistent = false, minimap = true, world = true,
    })
    return
  end

  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then return end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    Waypoint._blizzard = true
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
  end
end

-- High-level: guide to the target's entrance (from Locations coords, 0-100).
function Waypoint.GuideTo(target, silent)
  if not target then return end
  local map, x, y = ns.EntranceFor(target.key)
  if not map or not x or not y then
    if not silent then
      ns.Print(string.format(L["No coordinates for \"%s\" (fill them in Locations.lua)."], target.title or "?"))
    end
    return
  end

  if not useTomTom()
     and C_Map and C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map) then
    if not silent then ns.Print(L["Cannot place a waypoint on that map from here."]) end
    return
  end

  Waypoint.SetTo(map, x / 100, y / 100, target.title)
end
