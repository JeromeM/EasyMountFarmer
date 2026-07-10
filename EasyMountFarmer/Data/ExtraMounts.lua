-- ExtraMounts.lua — HAND-AUTHORED, never overwritten by the build.
-- Instance mounts the Encounter Journal can't expose because they drop from TRASH
-- or a timed reward (no boss encounter), so they have no encounterID and are
-- detected at loot time (NEW_MOUNT_ADDED). Merged with the generated instance data.
--
-- Fields mirror a generated instance entry; mountID is enough (name/spellID/icon are
-- resolved at runtime from it). Entries sharing the same `instance` string are grouped
-- into a single farm target (one visit), so repeat instanceId/map/x/y across them.
--   instanceId : GetSavedInstanceInfo lockout id (weekly skip).
--   map/x/y    : entrance coords for guidance.
--   legacy     : a no-longer-obtainable mount (excluded from the farm list).
-- mountIDs verified against the generated export (data/mounts-export.lua).

EasyMountFarmerExtra = {
  -- Qiraji battle tanks — drop from Qiraji trash in the Temple of Ahn'Qiraj (AQ40).
  { category = "trash", expansion = "Classic", instance = "Temple of Ahn'Qiraj",
    instanceId = 531, map = 81, x = 27.1, y = 93.6, mountID = 117 },  -- Blue Qiraji Battle Tank
  { category = "trash", expansion = "Classic", instance = "Temple of Ahn'Qiraj",
    instanceId = 531, map = 81, x = 27.1, y = 93.6, mountID = 118 },  -- Red Qiraji Battle Tank
  { category = "trash", expansion = "Classic", instance = "Temple of Ahn'Qiraj",
    instanceId = 531, map = 81, x = 27.1, y = 93.6, mountID = 119 },  -- Yellow Qiraji Battle Tank
  { category = "trash", expansion = "Classic", instance = "Temple of Ahn'Qiraj",
    instanceId = 531, map = 81, x = 27.1, y = 93.6, mountID = 120 },  -- Green Qiraji Battle Tank
  { category = "trash", expansion = "Classic", instance = "Temple of Ahn'Qiraj",
    instanceId = 531, map = 81, x = 27.1, y = 93.6, mountID = 122, legacy = true },  -- Black (Scarab Lord, unobtainable)

  -- Amani Battle Bear — timed reward (kill 4 bosses before the timer) in Zul'Aman.
  { category = "trash", expansion = "Burning Crusade", instance = "Zul'Aman",
    instanceId = 568, map = 95, x = 81.0, y = 65.0, mountID = 419 },
}
