-- Core.lua — initialization, saved variables, slash commands and the periodic
-- reset check. Loads last, so it can wire all other modules together.

local ADDON, ns = ...
local L = ns.L

local function initSavedVars()
  SAMountsDB = SAMountsDB or {}
  SAMountsCharDB = SAMountsCharDB or {}
  ns.db = SAMountsDB
  ns.charDB = SAMountsCharDB

  ns.db.minimap = ns.db.minimap or { angle = 200, hide = false }
  ns.charDB.doneRuns = ns.charDB.doneRuns or {}
  ns.charDB.currentIdx = ns.charDB.currentIdx or 1
end

local function onLogin()
  ns.UI.Init()
  ns.Minimap.Init()
  ns.Progress.CheckResets()   -- builds targets, prunes stale, refreshes UI
  ns.Progress.ResetPointer()  -- each session starts on the first step still to do
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
SLASH_SAMOUNTS1 = "/samounts"
SLASH_SAMOUNTS2 = "/sam"
SlashCmdList.SAMOUNTS = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "next" then
    ns.Progress.Next()
  elseif msg == "prev" or msg == "previous" then
    ns.Progress.Prev()
  elseif msg == "guide" then
    ns.Waypoint.GuideTo(ns.Progress.Current())
  elseif msg == "reset" then
    ns.Progress.ResetAllDone()
    ns.Print(L["Per-reset progress cleared."])
  elseif msg == "minimap" then
    ns.db.minimap.hide = not ns.db.minimap.hide
    if ns.Minimap.button then
      ns.Minimap.button:SetShown(not ns.db.minimap.hide)
    end
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
      local l = (SAMountsLocations or {})[cur.key]
      ns.Print("current step: " .. tostring(cur.key))
      print("  expected lockout string = |cffffff00" .. tostring(l and l.lockout) .. "|r (must match a name above to auto-skip)")
    end
  elseif msg == "help" then
    ns.Print(L["Commands:"])
    print("  " .. L["/sam — open/close the window"])
    print("  " .. L["/sam next | prev — navigate steps"])
    print("  " .. L["/sam guide — set a waypoint to the current step"])
    print("  " .. L["/sam reset — clear this-reset progress"])
    print("  " .. L["/sam minimap — toggle the minimap button"])
    print("  " .. L["/sam debug — show saved-instance diagnostics"])
  else
    ns.UI.Toggle()
  end
end
