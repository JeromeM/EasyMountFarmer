-- Core.lua — initialization, saved variables, slash commands and the periodic
-- reset check. Loads last, so it can wire all other modules together.

local ADDON, ns = ...
local L = ns.L

local function initSavedVars()
  EasyMountFarmerDB = EasyMountFarmerDB or {}
  EasyMountFarmerCharDB = EasyMountFarmerCharDB or {}
  ns.db = EasyMountFarmerDB
  ns.charDB = EasyMountFarmerCharDB

  ns.db.minimap = ns.db.minimap or { angle = 200, hide = false }
  if ns.db.autoGuide == nil then ns.db.autoGuide = true end
  if ns.db.shown == nil then ns.db.shown = false end
  if ns.db.autoAdvance == nil then ns.db.autoAdvance = true end
  if ns.db.useTomTom == nil then ns.db.useTomTom = true end
  if ns.db.lootPopup == nil then ns.db.lootPopup = true end
  if ns.db.lootChannel == nil then ns.db.lootChannel = "NONE" end
  ns.charDB.doneRuns = ns.charDB.doneRuns or {}
  ns.charDB.currentIdx = ns.charDB.currentIdx or 1
end

-- One-time import of settings/progress from the previous addon name (SAMounts).
-- Runs at PLAYER_LOGIN, when both addons' saved vars are loaded if the old folder
-- is still installed during the transition. Persistent flag stops it re-running.
local function importOldSavedVars()
  if ns.db.importedFromSAMounts then return end
  ns.db.importedFromSAMounts = true
  if type(_G.SAMountsDB) == "table" then
    for k, v in pairs(_G.SAMountsDB) do ns.db[k] = v end
  end
  if type(_G.SAMountsCharDB) == "table" then
    for k, v in pairs(_G.SAMountsCharDB) do ns.charDB[k] = v end
  end
end

local function onLogin()
  importOldSavedVars()
  ns.UI.Init()
  ns.UI.BuildSettings()
  ns.Minimap.Init()
  ns.Progress.CheckResets()   -- builds targets, prunes stale, refreshes UI
  ns.Progress.ResetPointer()  -- each session starts on the first step still to do
  if ns.db.shown then ns.UI.Show() end   -- restore the window's open/closed state
end

-- --- events ---------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("QUEST_TURNED_IN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then initSavedVars() end
  elseif event == "PLAYER_LOGIN" then
    onLogin()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if ns.charDB then ns.Progress.CheckResets() end
  elseif event == "QUEST_TURNED_IN" then
    -- a weekly/daily tracking quest may have completed (e.g. world boss)
    if ns.charDB then ns.Progress.Rebuild() end
  end
end)

-- Periodic tick: refresh reset countdowns and catch a reset crossing while online.
C_Timer.NewTicker(30, function()
  if ns.charDB then ns.Progress.CheckResets() end
end)

-- --- slash commands -------------------------------------------------------
SLASH_EASYMOUNTFARMER1 = "/easymountfarmer"
SLASH_EASYMOUNTFARMER2 = "/emf"
SlashCmdList.EASYMOUNTFARMER = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "next" then
    ns.Progress.Next()
  elseif msg == "prev" or msg == "previous" then
    ns.Progress.Prev()
  elseif msg == "guide" then
    ns.Waypoint.GuideTo(ns.Progress.Current())
  elseif msg == "reset" then
    ns.Progress.ResetAllDone()
    ns.Print(L["Re-synced to the first step to do."])
  elseif msg == "minimap" then
    ns.db.minimap.hide = not ns.db.minimap.hide
    if ns.Minimap.button then
      ns.Minimap.button:SetShown(not ns.db.minimap.hide)
    end
  elseif msg == "arrow" then
    ns.db.autoGuide = not ns.db.autoGuide
    ns.Print(ns.db.autoGuide and L["Auto waypoint arrow: ON"] or L["Auto waypoint arrow: OFF"])
    if ns.db.autoGuide and ns.UI then ns.UI.lastGuidedKey = nil; ns.UI.Refresh() end
  elseif msg == "debug" then
    -- diagnostics: what the client actually reports as saved instances
    RequestRaidInfo()
    ns.Print("client locale: " .. GetLocale())
    ns.Print("saved instances (" .. GetNumSavedInstances() .. "):")
    for i = 1, GetNumSavedInstances() do
      local info = { GetSavedInstanceInfo(i) }
      print(string.format("  |cffffff00%s|r  instanceId=%s locked=%s reset=%s diffID=%s",
        tostring(info[1]), tostring(info[14]), tostring(info[5]), tostring(info[3]), tostring(info[4])))
    end
    local cur = ns.Progress.Current()
    if cur then
      local l = (EasyMountFarmerLocations or {})[cur.key]
      ns.Print("current step: " .. tostring(cur.key))
      print("  expected lockout string = |cffffff00" .. tostring(l and l.lockout) .. "|r (must match a name above to auto-skip)")
    end
  elseif msg == "mapid" then
    -- report the current zone's UiMapID + localized name (to fill RouteHops)
    local id = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local info = id and C_Map.GetMapInfo(id)
    ns.Print(string.format("UiMapID = |cffffff00%s|r  (%s)", tostring(id), info and info.name or "?"))
  elseif msg == "nav" then
    local cur = ns.Progress.Current()
    ns.Print(string.format("FarstriderLib=%s | inInstance=%s | autoGuide=%s",
      tostring(ns.Nav and ns.Nav.Available()), tostring(IsInInstance()),
      tostring(ns.db and ns.db.autoGuide)))
    ns.Print(string.format("cur=%s | done=%s | Travel.active=%s | hint=%s",
      tostring(cur and cur.key), tostring(cur and ns.Progress.IsDone(cur.key)),
      tostring(ns.Travel and ns.Travel.active), tostring(ns.leaveInstanceHint)))
  elseif msg == "enc" then
    ns.db.encDebug = not ns.db.encDebug
    ns.Print("encounter debug: " .. (ns.db.encDebug and "ON" or "OFF")
      .. " — kill the mount boss and note the id.")
  elseif msg == "entrance" then
    -- the game's own source of truth for instance entrances on the current map
    -- (this is what FarstriderLib routes to). Stand in the zone that holds the
    -- portal, run this, and copy the exact map/x/y into Locations.lua.
    local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapId or not (C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap) then
      ns.Print("No map / EncounterJournal API available here.")
      return
    end
    local info = C_Map.GetMapInfo(mapId)
    ns.Print(string.format("instance entrances on map |cffffff00%d|r (%s):", mapId, info and info.name or "?"))
    local list = C_EncounterJournal.GetDungeonEntrancesForMap(mapId) or {}
    if #list == 0 then
      print("  (none here — stand in the zone that physically holds the portal)")
    end
    for _, e in ipairs(list) do
      local x, y = 0, 0
      if e.position and e.position.GetXY then x, y = e.position:GetXY() end
      print(string.format("  |cffffff00%s|r  jID=%s  map=%d x=%.1f y=%.1f",
        tostring(e.name), tostring(e.journalInstanceID), mapId, (x or 0) * 100, (y or 0) * 100))
    end
  elseif msg == "help" then
    ns.Print(L["Commands:"])
    print("  " .. L["/emf — open/close the window"])
    print("  " .. L["/emf next | prev — navigate steps"])
    print("  " .. L["/emf guide — set a waypoint to the current step"])
    print("  " .. L["/emf reset — clear this-reset progress"])
    print("  " .. L["/emf minimap — toggle the minimap button"])
    print("  " .. L["/emf arrow — toggle the auto waypoint arrow"])
    print("  " .. L["/emf debug — show saved-instance diagnostics"])
    print("  " .. L["/emf entrance — list instance entrances on this map"])
  else
    ns.UI.Toggle()
  end
end
