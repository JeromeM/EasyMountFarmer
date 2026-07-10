-- Overrides.lua — HAND-AUTHORED runtime overrides, merged onto the generated
-- instance/world-boss data at BuildTargets time. This is the irreducible minimum
-- the Encounter Journal CANNOT generate:
--   * instanceId : the GetSavedInstanceInfo lockout id (locale-proof lockout skip).
--   * questId    : a world boss's weekly loot-lock quest (done-this-reset skip).
--   * lowPriority: no persistent lockout (farmable in a loop) -> shown last.
--   * entranceJID + entranceMaps : a moving portal (e.g. Ny'alotha) resolved live.
--   * map/x/y    : entrance coords, only where the generator captured none
--                  (world bosses have no dungeon entrance; a few instances slip through).
--   * encByMount : an encounterID the generator missed (boss = summoned / non-standard),
--                  keyed by mountID, so a kill still auto-advances.
-- Everything else (mountID, spellID, itemID, boss, encounterID, difficulties,
-- expansion, zone/continent, entrance coords, route order) comes from the generated
-- Data/MountsInstances.lua and is NOT repeated here.

-- Per-instance overrides, keyed by journalInstanceID (stable, locale-proof).
EasyMountFarmerInstanceInfo = {
  -- Classic
  [1292] = { lowPriority = true, map = 23, x = 27.1, y = 11.6 },      -- Stratholme (Baron loop, no lockout)
  [760]  = { instanceId = 249 },                                      -- Onyxia's Lair
  [749]  = { instanceId = 550 },                                      -- Tempest Keep (The Eye)
  -- (Ahn'Qiraj battle tanks are trash drops — handled in ExtraMounts, not here.)

  -- Burning Crusade
  [252]  = { instanceId = 556, encByMount = { [185] = 1904 } },       -- Sethekk Halls (Anzu enc not generated)
  [745]  = { instanceId = 532 },                                      -- Karazhan
  [249]  = { instanceId = 585, map = 122, x = 61.4, y = 28.8 },       -- Magister's Terrace (no generated entrance)

  -- Wrath of the Lich King
  [758]  = { instanceId = 631 },                                      -- Icecrown Citadel
  [756]  = { instanceId = 616 },                                      -- Eye of Eternity
  [755]  = { instanceId = 615 },                                      -- Obsidian Sanctum
  [286]  = { instanceId = 575 },                                      -- Utgarde Pinnacle
  [759]  = { instanceId = 603 },                                      -- Ulduar
  [753]  = { instanceId = 624 },                                      -- Vault of Archavon

  -- Cataclysm
  [68]   = { instanceId = 657 },                                      -- Vortex Pinnacle
  [74]   = { instanceId = 754 },                                      -- Throne of the Four Winds
  [78]   = { instanceId = 720 },                                      -- Firelands
  [187]  = { instanceId = 967 },                                      -- Dragon Soul
  [67]   = { instanceId = 725 },                                      -- Stonecore
  [76]   = { instanceId = 859 },                                      -- Zul'Gurub

  -- Mists of Pandaria
  [317]  = { instanceId = 1008 },                                     -- Mogu'shan Vaults
  [362]  = { instanceId = 1098 },                                     -- Throne of Thunder
  [369]  = { instanceId = 1136 },                                     -- Siege of Orgrimmar

  -- Warlords of Draenor
  [669]  = { instanceId = 1448 },                                     -- Hellfire Citadel
  [457]  = { instanceId = 1205 },                                     -- Blackrock Foundry

  -- Legion
  [786]  = { instanceId = 1530 },                                     -- The Nighthold
  [875]  = { instanceId = 1676 },                                     -- Tomb of Sargeras
  [946]  = { instanceId = 1712 },                                     -- Antorus, the Burning Throne
  [860]  = { map = 42, x = 46.9, y = 74.5 },                          -- Return to Karazhan (no generated entrance; no lockout id yet)

  -- Battle for Azeroth
  [1176] = { instanceId = 2070 },                                     -- Battle of Dazar'alor
  [1041] = { instanceId = 1762 },                                     -- King's Rest
  [1178] = { instanceId = 2097 },                                     -- Operation: Mechagon

  -- Shadowlands
  [1180] = { instanceId = 2217, entranceJID = 1180, entranceMaps = { 1530, 1527 } }, -- Ny'alotha (moving portal Vale<->Uldum)
  [1193] = { instanceId = 2450 },                                     -- Sanctum of Domination
  [1195] = { instanceId = 2481 },                                     -- Sepulcher of the First Ones

  -- Dragonflight
  [1207] = { instanceId = 2549 },                                     -- Amirdrassil, the Dream's Hope

  -- The War Within
  [1273] = { instanceId = 2657 },                                     -- Nerub-ar Palace
  [1296] = { instanceId = 2769 },                                     -- Liberation of Undermine
  -- 1302 Manaforge Omega, 1001 Freehold, 1022 Underrot, 1182 Necrotic Wake,
  -- 1194 Tazavesh, 1210 Darkflame Cleft: no lockout id captured yet (run /emf debug
  -- while saved to fill instanceId; kill-detection + collection still work meanwhile).

  -- Midnight (preview): 1300 Magister's Terrace, 1308 March on Quel'Danas,
  -- 1299 Windrunner Spire — no lockout id yet.
}

-- World-boss overrides, keyed by mountID. World bosses have no dungeon entrance
-- (hand coords) and are gated by a weekly loot-lock quest (questId), not a lockout.
EasyMountFarmerWorldBossInfo = {
  [515]  = { questId = 32098, map = 376, x = 71.6, y = 64.4 },        -- Galleon (Valley of the Four Winds)
  [533]  = { questId = 32519, map = 507, x = 49.0, y = 55.0 },        -- Oondasta (Isle of Giants)
  [473]  = { questId = 32099, map = 379, x = 53.6, y = 64.8 },        -- Sha of Anger (Kun-Lai Summit)
  [542]  = { questId = 32518, map = 504, x = 60.3, y = 37.4 },        -- Nalak (Isle of Thunder)
  [634]  = { questId = 37464, map = 542, x = 34.1, y = 35.8 },        -- Rukhmar (Spires of Arak)
  [1250] = { map = 864, x = 52.0, y = 88.0 },                         -- Mollie / Kraulok (Vol'dun; no weekly lock) -- coords unsure
}

-- Hand-authored visiting order (overrides the automatic geographic ordering).
-- Each entry is a target key: "i:"..journalInstanceID (dungeon/raid), "m:"..mountID
-- (world boss), or "x:"..instance (trash). Targets not listed here fall to the end.
-- A { key, entrance } entry is CONDITIONAL: it only takes this slot when the run's
-- live entrance is on that map (used for Ny'alotha's moving portal, so it appears
-- near Uldum on Uldum weeks and near Pandaria on Vale weeks).
EasyMountFarmerOrder = {
  "i:252",                              -- Sethekk Halls
  "i:749",                              -- The Eye (Tempest Keep)
  "i:249",                              -- Magister's Terrace
  "i:745",                              -- Karazhan
  "i:860",                              -- Return to Karazhan (Legion, kept next to Karazhan)
  "i:76",                               -- Zul'Gurub (Cataclysm, kept next to Karazhan)
  "x:Zul'Aman",                         -- Zul'Aman (Amani Battle Bear)
  "i:755",                              -- Obsidian Sanctum
  "i:753",                              -- Vault of Archavon
  "i:756",                              -- Eye of Eternity
  "i:758",                              -- Icecrown Citadel
  "i:759",                              -- Ulduar
  "i:286",                              -- Utgarde Pinnacle
  "i:78",                               -- Firelands
  "i:67",                               -- Stonecore
  { key = "i:1180", entrance = 1527 },  -- Ny'alotha — only on an Uldum-entrance week
  "i:68",                               -- Vortex Pinnacle
  "i:74",                               -- Throne of the Four Winds
  "i:760",                              -- Onyxia
  "i:187",                              -- Dragon Soul
  "x:Temple of Ahn'Qiraj",              -- Ahn'Qiraj battle tanks
  "m:515",                              -- Galleon
  "i:369",                              -- Siege of Orgrimmar
  { key = "i:1180", entrance = 1530 },  -- Ny'alotha — only on a Vale (Pandaria) week
  "i:317",                              -- Mogu'shan Vaults
  "m:473",                              -- Sha of Anger
  "m:533",                              -- Oondasta
  "m:542",                              -- Nalak
  "i:362",                              -- Throne of Thunder
  "m:634",                              -- Rukhmar
  "i:669",                              -- Hellfire Citadel
  "i:457",                              -- Blackrock Foundry
  "i:786",                              -- The Nighthold
  "i:875",                              -- Tomb of Sargeras
  "i:946",                              -- Antorus
  "i:1176",                             -- Battle of Dazar'alor
  "i:1001",                             -- Freehold
  "i:1178",                             -- Operation: Mechagon
  "m:1250",                             -- Mollie (Kraulok)
  "i:1022",                             -- The Underrot
  "i:1041",                             -- King's Rest
  "i:1182",                             -- Necrotic Wake
  "i:1193",                             -- Sanctum of Domination
  "i:1195",                             -- Sepulcher of the First Ones
  "i:1207",                             -- Amirdrassil
  "i:1209",                             -- Dawn of the Infinites
  "i:1273",                             -- Nerub-ar Palace
  "i:1210",                             -- Darkflame Cleft
  "i:1296",                             -- Liberation of Undermine
  "i:1194",                             -- Tazavesh
  "i:1302",                             -- Manaforge Omega
  "i:1299",                             -- Windrunner Spire
  "i:1300",                             -- Magister's Terrace (Midnight)
  "i:1308",                             -- March on Quel'Danas
  "i:1292",                             -- Stratholme (Baron loop)
}
