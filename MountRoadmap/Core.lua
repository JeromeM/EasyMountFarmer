-- Core.lua — initialization, saved variables, slash commands and the periodic
-- reset check. Loads last, so it can wire all other modules together.

local ADDON, ns = ...

local function initSavedVars()
  MountRoadmapDB = MountRoadmapDB or {}
  MountRoadmapCharDB = MountRoadmapCharDB or {}
  ns.db = MountRoadmapDB
  ns.charDB = MountRoadmapCharDB

  ns.db.minimap = ns.db.minimap or { angle = 200, hide = false }
  ns.charDB.doneRuns = ns.charDB.doneRuns or {}
  ns.charDB.currentIdx = ns.charDB.currentIdx or 1
end

local function onLogin()
  ns.UI.Init()
  ns.Minimap.Init()
  ns.Progress.CheckResets()   -- builds targets, prunes stale, refreshes UI
end

-- --- events ---------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then initSavedVars() end
  elseif event == "PLAYER_LOGIN" then
    onLogin()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if ns.charDB then ns.Progress.CheckResets() end
  end
end)

-- Periodic tick: refresh reset countdowns and catch a reset crossing while online.
C_Timer.NewTicker(30, function()
  if ns.charDB then ns.Progress.CheckResets() end
end)

-- --- slash commands -------------------------------------------------------
SLASH_MOUNTROADMAP1 = "/mountroadmap"
SLASH_MOUNTROADMAP2 = "/mr"
SlashCmdList.MOUNTROADMAP = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "next" then
    ns.Progress.Next()
  elseif msg == "prev" or msg == "previous" then
    ns.Progress.Prev()
  elseif msg == "guide" then
    ns.Waypoint.GuideTo(ns.Progress.Current())
  elseif msg == "reset" then
    ns.Progress.ResetAllDone()
    print("|cffffd200Mount Roadmap|r: per-reset progress cleared.")
  elseif msg == "minimap" then
    ns.db.minimap.hide = not ns.db.minimap.hide
    if ns.Minimap.button then
      ns.Minimap.button:SetShown(not ns.db.minimap.hide)
    end
  elseif msg == "help" then
    print("|cffffd200Mount Roadmap|r commands:")
    print("  /mr — open/close the window")
    print("  /mr next | prev — navigate steps")
    print("  /mr guide — set a waypoint to the current step")
    print("  /mr reset — clear this-reset progress")
    print("  /mr minimap — toggle the minimap button")
  else
    ns.UI.Toggle()
  end
end
