-- Waypoint.lua — guide to a point using the game's native user waypoint (map +
-- minimap pin + supertracked distance) together with our own on-screen direction
-- arrow (ns.Arrow). No external addon dependency. We track what WE set so Clear()
-- only removes ours (never a waypoint the player placed by hand).

local ADDON, ns = ...
ns.Waypoint = ns.Waypoint or {}
local Waypoint = ns.Waypoint
local L = ns.L

--- Resolve a run's entrance from the game's Encounter Journal when it defines
--- entranceJID + candidate entranceMaps. Some raids' portals move (e.g. Ny'alotha,
--- whose entrance follows the weekly N'Zoth assault between Uldum and the Vale);
--- the game only lists the entrance on the map where it currently is, so this
--- auto-tracks the rotation.
---@param l table  location entry with entranceJID and entranceMaps fields
---@return number? mapId  uiMapID of the map holding the entrance, or nil
---@return number? x  entrance X coordinate in 0-100
---@return number? y  entrance Y coordinate in 0-100
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

--- Resolve the effective entrance coords (0-100) for a target key: live
--- Encounter-Journal resolution first (moving portals), then the target's static
--- coords (from the generated data / Overrides) as a fallback.
---@param key string  target key identifying the run (index into ns.targetsByKey)
---@return number? mapId  uiMapID of the entrance map, or nil if unknown
---@return number? x  entrance X coordinate in 0-100
---@return number? y  entrance Y coordinate in 0-100
function ns.EntranceFor(key)
  local t = ns.targetsByKey and ns.targetsByKey[key]
  if not t then return end
  local m, x, y = liveEntrance(t)
  if m then return m, x, y end
  if t.map and t.x and t.y then return t.map, t.x, t.y end
end

--- Remove what WE set (native user waypoint + our arrow), leaving player-placed
--- waypoints intact.
function Waypoint.Clear()
  if Waypoint._blizzard and C_Map and C_Map.ClearUserWaypoint then
    C_Map.ClearUserWaypoint()
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    end
    Waypoint._blizzard = nil
  end
  if ns.Arrow then ns.Arrow.Hide() end
end

--- Point at an explicit UI map point: set the native user waypoint (map + minimap
--- pin + supertracked distance) best-effort, and always show our own on-screen
--- arrow. Clears our previous one first.
---@param mapID number  uiMapID of the target map
---@param x number  normalized X coordinate (0-1)
---@param y number  normalized Y coordinate (0-1)
---@param title string?  label shown on the waypoint / arrow
function Waypoint.SetTo(mapID, x, y, title)
  if not mapID or not x or not y then return end
  Waypoint.Clear()   -- drop our previous one first

  -- Native user waypoint for the map + minimap pin. Best-effort: some maps
  -- disallow it (CanSetUserWaypointOnMap == false) — the arrow still guides there.
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    if not (C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID)) then
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
      Waypoint._blizzard = true
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
      end
    end
  end

  -- Our own on-screen direction arrow.
  if ns.Arrow then ns.Arrow.Show(mapID, x, y, title) end
end

--- Guide to the target's entrance (0-100 coords): resolve the coords then point
--- at them, printing a message on failure unless silent.
---@param target table  run entry with key and title fields
---@param silent boolean?  suppress user-facing error messages when true
function Waypoint.GuideTo(target, silent)
  if not target then return end
  local map, x, y = ns.EntranceFor(target.key)
  if not map or not x or not y then
    if not silent then
      ns.Print(string.format(L["No coordinates for \"%s\"."], target.title or "?"))
    end
    return
  end

  Waypoint.SetTo(map, x / 100, y / 100, target.title)
end
