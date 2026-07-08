-- enUS locale (base / reference). Copy this file to another locale (e.g. frFR.lua),
-- guard it with `if GetLocale() ~= "frFR" then return end`, and translate the values.

local ADDON, ns = ...
local L = ns.L

-- window / general
L["SAMounts"] = "SAMounts"
L["Grats! All farmable mounts collected."] = "Grats! All farmable mounts collected."
L["Nothing to farm this reset — come back after reset."] = "Nothing to farm this reset — come back after reset."
L["Step %d / %d"] = "Step %d / %d"
L["%d mounts left"] = "%d mounts left"
L["Daily reset: %s"] = "Daily reset: %s"
L["Weekly: %s"] = "Weekly: %s"
L["Route:"] = "Route:"
L["(+%d more mounts here)"] = "(+%d more mounts here)"
L["< Prev"] = "< Prev"
L["Next >"] = "Next >"
L["Guide me"] = "Guide me"
L["Mount obtained!"] = "Mount obtained!"

-- breadcrumb
L["Hearthstone: %s"] = "Hearthstone: %s"
L["Stormwind"] = "Stormwind"
L["Orgrimmar"] = "Orgrimmar"

-- difficulty
L["Normal"] = "Normal"
L["Heroic"] = "Heroic"
L["Mythic"] = "Mythic"
L["Mythic Keystone"] = "Mythic Keystone"
L["Looking For Raid"] = "Looking For Raid"
L["10 Player"] = "10 Player"
L["25 Player"] = "25 Player"
L["10 Player Heroic"] = "10 Player Heroic"
L["25 Player Heroic"] = "25 Player Heroic"
L["40 Player"] = "40 Player"
L["Difficulty"] = "Difficulty"
L["Switch to %s"] = "Switch to %s"
L["Cannot change difficulty in combat."] = "Cannot change difficulty in combat."
L["Cannot change difficulty (party leader required, or already inside the instance)."] = "Cannot change difficulty (party leader required, or already inside the instance)."

-- waypoint
L["No coordinates for \"%s\" (fill them in Locations.lua)."] = "No coordinates for \"%s\" (fill them in Locations.lua)."
L["Cannot place a waypoint on that map from here."] = "Cannot place a waypoint on that map from here."
L["No waypoint system available."] = "No waypoint system available."

-- minimap / slash
L["Left-click: open/close"] = "Left-click: open/close"
L["Right-click: reset this-reset progress"] = "Right-click: reset this-reset progress"
L["Per-reset progress cleared."] = "Per-reset progress cleared."
L["Commands:"] = "Commands:"
L["/sam — open/close the window"] = "/sam — open/close the window"
L["/sam next | prev — navigate steps"] = "/sam next | prev — navigate steps"
L["/sam guide — set a waypoint to the current step"] = "/sam guide — set a waypoint to the current step"
L["/sam reset — clear this-reset progress"] = "/sam reset — clear this-reset progress"
L["/sam minimap — toggle the minimap button"] = "/sam minimap — toggle the minimap button"
