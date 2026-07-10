-- ExtraMounts.lua — HAND-AUTHORED, never overwritten by the build.
-- Instance mounts the Encounter Journal can't expose because they drop from TRASH
-- (no boss encounter), so they have no encounterID and are detected at loot time
-- (NEW_MOUNT_ADDED), like world bosses. Merged with the generated instance data.
--
-- Fields mirror EasyMountFarmerInstances; mountID is enough (name/spellID/icon are
-- resolved at runtime from it). `legacy = true` marks a no-longer-obtainable mount.

EasyMountFarmerExtra = {
  -- Ahn'Qiraj battle tanks — drop from Qiraji trash in the Temple of Ahn'Qiraj (AQ40).
  { category = "trash", expansion = "Classic", instance = "Temple of Ahn'Qiraj",
    boss = nil, encounterID = nil, mountID = 110 },  -- Blue Qiraji Battle Tank
  { category = "trash", expansion = "Classic", instance = "Temple of Ahn'Qiraj",
    boss = nil, encounterID = nil, mountID = 117 },  -- Red Qiraji Battle Tank
  { category = "trash", expansion = "Classic", instance = "Temple of Ahn'Qiraj",
    boss = nil, encounterID = nil, mountID = 118 },  -- Yellow Qiraji Battle Tank
  { category = "trash", expansion = "Classic", instance = "Temple of Ahn'Qiraj",
    boss = nil, encounterID = nil, mountID = 119 },  -- Green Qiraji Battle Tank
  { category = "trash", expansion = "Classic", instance = "Temple of Ahn'Qiraj",
    boss = nil, encounterID = nil, mountID = 120, legacy = true },  -- Black (Scarab Lord, unobtainable)

  -- Amani Battle Bear — timed reward (kill 4 bosses before the timer) in Zul'Aman.
  { category = "trash", expansion = "Burning Crusade", instance = "Zul'Aman",
    boss = nil, encounterID = nil, mountID = 400 },
}
