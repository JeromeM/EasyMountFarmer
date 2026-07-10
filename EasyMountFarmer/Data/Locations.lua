-- Hand-authored per-run data. Never overwritten by scripts/build-data.mjs
-- (only (re)created when missing). Re-run the build to refresh the skeleton in
-- scripts/Locations.skeleton.lua when new runs appear, then port entries here.
--
-- Per run:
--   map, x, y   : UiMapID + entrance coords in 0-100  (in-game: /dump C_Map.GetBestMapForUnit("player")
--                 and hover the map, or use an addon that prints cursor coords)
--   lockout     : exact name from GetSavedInstanceInfo  (/dump for i=1,GetNumSavedInstances() do print(GetSavedInstanceInfo(i)) end)
--   reqDiff     : difficultyID required for the mount to drop (nil = any)
--   diffScope   : "dungeon" | "raid" | "legacyRaid"
--                 dungeon 1=N 2=H 23=M ; raid 14=N 15=H 16=M 17=LFR ; legacy 3=10N 4=25N 5=10H 6=25H
--   encounters  : [mount spellId] = encounterID  (DungeonEncounterID = ENCOUNTER_END first arg)
--
-- Values compiled from the DB2 DungeonEncounter/UiMap/Map tables (wago.tools) and warcraft.wiki.gg.
-- Coordinates are entrance-portal estimates (0-100); a few are marked "-- unsure". World bosses have
-- no ENCOUNTER_END and are not in GetSavedInstanceInfo, so lockout=nil and encounters={} for them.

EasyMountFarmerLocations = {
  ["Run Vortex Pinnacle (Dungeon)"] = {
    map = 249, x = 76.6, y = 84.3,   -- Uldum
    lockout = "The Vortex Pinnacle",
    instanceId = 657,
    reqDiff = nil, diffScope = "dungeon",  -- drops on Normal or Heroic
    encounters = { [88742] = 1041 },  -- Altairus -> Drake of the North Wind
  },
  ["Run Throne of the Four Winds (Raid)"] = {
    map = 249, x = 38.4, y = 80.6,   -- Uldum
    lockout = "Throne of the Four Winds",
    instanceId = 754,
    reqDiff = nil, diffScope = "legacyRaid",
    encounters = { [88744] = 1034 },  -- Al'Akir -> Drake of the South Wind
  },
  ["Run Ahn'Qiraj (Raid)"] = {
    map = 81, x = 27.1, y = 93.6,   -- Silithus (Gates of Ahn'Qiraj) -- unsure coords
    lockout = "Ahn'Qiraj Temple",
    instanceId = 531,
    reqDiff = nil, diffScope = "legacyRaid",
    encounters = {},  -- Qiraji crystals drop from trash, no ENCOUNTER_END
  },
  ["Run Onyxia (Raid)"] = {
    map = 70, x = 52.5, y = 76.5,   -- Dustwallow Marsh (Wyrmbog)
    lockout = "Onyxia's Lair",
    instanceId = 249,
    reqDiff = nil, diffScope = "legacyRaid",
    encounters = { [69395] = 1084 },  -- Onyxia
  },
  ["Run Icecrown Citadel (Raid)"] = {
    map = 118, x = 53.6, y = 87.2,   -- Icecrown
    lockout = "Icecrown Citadel",
    instanceId = 631,
    reqDiff = 6, diffScope = "legacyRaid",  -- 25 Player Heroic
    encounters = { [72286] = 1106 },  -- The Lich King -> Invincible's Reins
  },
  ["Run Vault of Archavon (Raid)"] = {
    map = 123, x = 50.0, y = 15.0,   -- Wintergrasp -- unsure coords
    lockout = "Vault of Archavon",
    instanceId = 624,
    reqDiff = nil, diffScope = "legacyRaid",
    encounters = {},  -- Grand Black War Mammoth has no mount spellId; bosses 1126/1127/1128/1129
  },
  ["Run Eye of Eternity (Raid)"] = {
    map = 114, x = 27.6, y = 26.6,   -- Borean Tundra (Coldarra)
    lockout = "The Eye of Eternity",
    instanceId = 616,
    reqDiff = nil, diffScope = "legacyRaid",
    encounters = { [59567] = 1094, [59568] = 1094 },  -- Malygos -> Azure Drake / Blue Drake
  },
  ["Run Obsidian Sanctum (Raid)"] = {
    map = 115, x = 59.3, y = 49.3,   -- Dragonblight (below Wyrmrest Temple)
    lockout = "The Obsidian Sanctum",
    instanceId = 615,
    reqDiff = nil, diffScope = "legacyRaid",
    encounters = { [59650] = 1090, [59571] = 1090 },  -- Sartharion -> Black Drake / Twilight Drake
  },
  ["Run Utgarde Pinnacle (Dungeon)"] = {
    map = 117, x = 57.3, y = 46.7,   -- Howling Fjord (Utgarde Keep)
    lockout = "Utgarde Pinnacle",
    instanceId = 575,
    reqDiff = 2, diffScope = "dungeon",  -- Heroic only
    encounters = { [59996] = 2029 },  -- Skadi the Ruthless -> Blue Proto-Drake
  },
  ["Run Ulduar (Raid)"] = {
    map = 120, x = 41.0, y = 18.0,   -- The Storm Peaks
    lockout = "Ulduar",
    instanceId = 603,
    reqDiff = nil, diffScope = "legacyRaid",  -- Mimiron's Head: Yogg-Saron with 0 keepers
    encounters = { [63796] = 1143 },  -- Yogg-Saron -> Mimiron's Head
  },
  ["Run Firelands on both Normal and Heroic (Raid)"] = {
    map = 198, x = 47.7, y = 78.3,   -- Mount Hyjal (Sulfuron Spire)
    lockout = "Firelands",
    instanceId = 720,
    reqDiff = nil, diffScope = "legacyRaid",
    encounters = { [101542] = 1206, [97493] = 1203 },  -- Alysrazor -> Flametalon ; Ragnaros -> Egg of Millagazor
  },
  ["Run Culling of Stratholme (Dungeon)"] = {
    map = 75, x = 57.8, y = 82.8,   -- Caverns of Time -- unsure (Tanaris 71 ~64,50)
    lockout = "The Culling of Stratholme",
    instanceId = 595,
    reqDiff = 2, diffScope = "dungeon",  -- Heroic only, timed
    encounters = {},  -- Bronze Drake from Infinite Corruptor (timed mob, no DungeonEncounterID)
  },
  ["Run Dragon Soul (Raid)"] = {
    map = 75, x = 62.2, y = 28.2,   -- Caverns of Time portal -- unsure (Tanaris 71 ~64,49)
    lockout = "Dragon Soul",
    instanceId = 967,
    reqDiff = nil, diffScope = "legacyRaid",  -- Life-Binder's Handmaiden (107845) is Heroic-only
    encounters = { [110039] = 1297, [107842] = 1299, [107845] = 1299 },  -- Ultraxion ; Madness of Deathwing
  },
  ["Run Stonecore (Dungeon)"] = {
    map = 207, x = 47.0, y = 52.0,   -- Deepholm
    lockout = "The Stonecore",
    instanceId = 725,
    reqDiff = nil, diffScope = "dungeon",  -- drops on Normal or Heroic
    encounters = { [88746] = 1059 },  -- Slabhide -> Vitreous Stone Drake
  },
  ["Run Sethekk Halls (Dungeon)"] = {
    map = 108, x = 43.3, y = 65.4,   -- Terokkar Forest (Auchindoun)
    lockout = "Sethekk Halls",  -- unsure: DB2 map name is "Auchindoun: Sethekk Halls"
    instanceId = 556,
    reqDiff = 2, diffScope = "dungeon",  -- Heroic only
    encounters = { [41252] = 1904 },  -- Anzu -> Raven Lord
  },
  ["Run Tempest Keep (Raid)"] = {
    map = 109, x = 73.5, y = 63.7,   -- Netherstorm
    lockout = "Tempest Keep",  -- unsure: UI often shows "The Eye"
    instanceId = 550,
    reqDiff = nil, diffScope = "legacyRaid",
    encounters = { [40192] = 733 },  -- Kael'thas Sunstrider -> Ashes of Al'ar
  },
  ["Run Magister's Terrace (Dungeon)"] = {
    map = 122, x = 61.4, y = 28.8,   -- Isle of Quel'Danas -- unsure (12.x may revamp zone)
    lockout = "Magisters' Terrace",
    instanceId = 585,
    reqDiff = 2, diffScope = "dungeon",  -- Heroic only
    encounters = { [46628] = 1894 },  -- Kael'thas Sunstrider -> Swift White Hawkstrider
  },
  ["Run Zul'Aman (Dungeon)"] = {
    map = 95, x = 81.0, y = 65.0,   -- Ghostlands
    lockout = "Zul'Aman",
    instanceId = 568,
    reqDiff = nil, diffScope = "dungeon",  -- Amani Battle Bear = timed reward
    encounters = {},  -- timed-chest reward, no ENCOUNTER_END
  },
  ["Run Stratholme (Dungeon)"] = {
    map = 23, x = 27.1, y = 11.6,   -- Eastern Plaguelands (main gate)
    lockout = "Stratholme",
    lowPriority = true,  -- no lockout: farmable in a loop (Baron mount ~0.02%); shown last
    reqDiff = nil, diffScope = "dungeon",
    encounters = { [17481] = 484 },  -- Baron Rivendare -> Deathcharger's Reins
  },
  ["Run Karazhan (Raid)"] = {
    map = 42, x = 46.8, y = 74.1,   -- Deadwind Pass
    lockout = "Karazhan",
    instanceId = 532,
    reqDiff = nil, diffScope = "legacyRaid",
    encounters = { [36702] = 652 },  -- Attumen the Huntsman -> Fiery Warhorse's Reins
  },
  ["Run Return to Karazhan (Dungeon)"] = {
    map = 42, x = 46.9, y = 74.5,   -- Deadwind Pass
    lockout = "Return to Karazhan",
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = {},  -- TODO Attumen (229499) / Nightbane (231428) DungeonEncounterIDs
  },
  ["Run Zul'Gurub (Dungeon)"] = {
    map = 50, x = 68.4, y = 33.0,   -- Northern Stranglethorn
    lockout = "Zul'Gurub",
    instanceId = 859,
    reqDiff = 2, diffScope = "dungeon",  -- Heroic only
    encounters = { [96499] = 1180, [96491] = 1179 },  -- Kilnara -> Panther ; Mandokir -> Razzashi Raptor
  },
  ["Kill Galleon (World Boss)"] = {
    map = 376, x = 71.6, y = 64.4,   -- Valley of the Four Winds (roams)
    lockout = nil, questId = 32098,  -- weekly loot-lock quest
    reqDiff = nil, diffScope = nil,
    encounters = {},  -- world boss
  },
  ["Kill Sha of Anger (World Boss)"] = {
    map = 379, x = 53.6, y = 64.8,   -- Kun-Lai Summit (roams)
    lockout = nil, questId = 32099,  -- weekly loot-lock quest
    reqDiff = nil, diffScope = nil,
    encounters = {},  -- world boss
  },
  ["Kill Oondasta (World Boss)"] = {
    map = 507, x = 49.0, y = 55.0,   -- Isle of Giants
    lockout = nil, questId = 32519,  -- weekly loot-lock quest
    reqDiff = nil, diffScope = nil,
    encounters = {},  -- world boss
  },
  ["Run Mogu'shan Vaults (Raid)"] = {
    map = 379, x = 59.2, y = 39.6,   -- Kun-Lai Summit (Mogu'shan Terrace)
    lockout = "Mogu'shan Vaults",
    instanceId = 1008,
    reqDiff = nil, diffScope = "raid",
    encounters = { [127170] = 1500 },  -- Elegon -> Reins of the Astral Cloud Serpent
  },
  ["Kill Nalak (World Boss)"] = {
    map = 504, x = 60.3, y = 37.4,   -- Isle of Thunder
    lockout = nil, questId = 32518,  -- weekly loot-lock quest
    reqDiff = nil, diffScope = nil,
    encounters = {},  -- world boss
  },
  ["Run Throne of Thunder (Raid)"] = {
    map = 504, x = 63.7, y = 32.2,   -- Isle of Thunder
    lockout = "Throne of Thunder",
    instanceId = 1098,
    reqDiff = nil, diffScope = "raid",
    encounters = { [136471] = 1575, [139448] = 1573 },  -- Horridon -> Spawn ; Ji-Kun -> Clutch
  },
  ["Run Siege of Orgrimmar (Raid)"] = {
    map = 1530, x = 74.0, y = 42.0,   -- Vale of Eternal Blossoms (retail 12.x)
    lockout = "Siege of Orgrimmar",
    instanceId = 1136,
    reqDiff = 16, diffScope = "raid",  -- Mythic only
    encounters = { [148417] = 1623 },  -- Garrosh Hellscream -> Kor'kron Juggernaut
  },
  ["Kill Rukhmar (World Boss)"] = {
    map = 542, x = 34.1, y = 35.8,   -- Spires of Arak (circles Skyreach) -- unsure
    lockout = nil, questId = 37464,  -- weekly loot-lock quest
    reqDiff = nil, diffScope = nil,
    encounters = {},  -- world boss
  },
  ["Run Hellfire Citadel (Raid)"] = {
    map = 534, x = 53.5, y = 58.1,   -- Tanaan Jungle
    lockout = "Hellfire Citadel",
    instanceId = 1448,
    reqDiff = 16, diffScope = "raid",  -- Mythic only
    encounters = { [182912] = 1799 },  -- Archimonde -> Felsteel Annihilator
  },
  ["Run Blackrock Foundry (Raid)"] = {
    map = 543, x = 51.7, y = 29.0,   -- Gorgrond
    lockout = "Blackrock Foundry",
    instanceId = 1205,
    reqDiff = 16, diffScope = "raid",  -- Mythic only
    encounters = { [171621] = 1704 },  -- Blackhand -> Ironhoof Destroyer
  },
  ["Run Nighthold (Raid)"] = {
    map = 680, x = 45.8, y = 64.5,   -- Suramar
    lockout = "The Nighthold",
    instanceId = 1530,
    reqDiff = nil, diffScope = "raid",  -- Fiendish Hellfire Core (171827) is Mythic only
    encounters = { [213134] = 1866, [171827] = 1866 },  -- Gul'dan (both mounts)
  },
  ["Run Tomb of Sargeras (Raid)"] = {
    map = 646, x = 63.6, y = 21.8,   -- Broken Shore
    lockout = "Tomb of Sargeras",
    instanceId = 1676,
    reqDiff = nil, diffScope = "raid",
    encounters = { [232519] = 2037 },  -- Mistress Sassz'ine -> Abyss Worm
  },
  ["Run Antorus, the Burning Throne (Raid)"] = {
    map = 885, x = 50.0, y = 70.0,   -- Antoran Wastes
    lockout = "Antorus, the Burning Throne",
    instanceId = 1712,
    reqDiff = nil, diffScope = "raid",  -- Shackled Ur'zul (243651) is Mythic only
    encounters = { [253088] = 2074, [243651] = 2092 },  -- Felhounds ; Argus the Unmaker
  },
  ["Run Battle of Dazar'alor (Raid)"] = {
    map = 1165, x = 38.8, y = 2.4,   -- Dazar'alor (Horde); Alliance = Boralus (1161) ~70.5,35.3
    lockout = "Battle of Dazar'alor",
    instanceId = 2070,
    reqDiff = nil, diffScope = "raid",  -- Glacial Tidestorm (289555) is Mythic only
    encounters = { [289083] = 2276, [289555] = 2281 },  -- Mekkatorque ; Jaina Proudmoore
  },
  ["Run Freehold (Dungeon)"] = {
    map = 895, x = 84.1, y = 79.2,   -- Tiragarde Sound (Castaway Point)
    lockout = "Freehold",
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = { [254813] = 2096 },  -- Harlan Sweete -> Sharkbait's Favorite Crackers
  },
  ["Run King's Rest (Dungeon)"] = {
    map = 862, x = 37.0, y = 39.0,   -- Zuldazar
    lockout = "Kings' Rest",  -- in-game name uses "Kings'"
    instanceId = 1762,
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = { [266058] = 2143 },  -- Dazar, The First King -> Mummified Raptor Skull
  },
  ["Run The Underrot (Dungeon)"] = {
    map = 863, x = 51.6, y = 65.3,   -- Nazmir
    lockout = "The Underrot",
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = { [273541] = 2123 },  -- Unbound Abomination -> Underrot Crawg Harness
  },
  ["Run Mechagon: Junkyard (Dungeon)"] = {
    map = 1462, x = 73.1, y = 36.3,   -- Mechagon Island (Rustbolt)
    lockout = "Operation: Mechagon",  -- M+ wings are separate maps
    instanceId = 2097,
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = { [299158] = 2291, [290718] = 2260 },  -- HK-8 ; King Mechagon
  },
  ["Run Ny'alotha the Waking City (Raid)"] = {
    -- The raid portal follows the weekly N'Zoth assault, alternating between the
    -- Vale of Eternal Blossoms (1530) and Uldum (1527). entranceJID + entranceMaps
    -- let Nav/Waypoint resolve the live entrance from the game each week; map/x/y
    -- below is only the fallback (Vale, the confirmed default).
    entranceJID = 1180, entranceMaps = { 1530, 1527 },
    map = 1530, x = 40.0, y = 45.6,   -- Vale of Eternal Blossoms (fallback)
    lockout = "Ny'alotha, the Waking City",
    instanceId = 2217,
    reqDiff = 16, diffScope = "raid",  -- Mythic only
    encounters = { [308814] = 2344 },  -- N'Zoth the Corruptor -> Ny'alotha Allseer
  },
  ["Run Necrotic Wake (Dungeon)"] = {
    map = 1533, x = 40.2, y = 55.2,   -- Bastion
    lockout = "The Necrotic Wake",
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = { [336036] = 2390 },  -- Nalthor the Rimebinder -> Marrowfang
  },
  ["Run Tazavesh the Veiled Market (Dungeon)"] = {
    map = 1671, x = 63.8, y = 26.6,   -- Oribos (Ring of Transference) -- unsure coords
    lockout = "Tazavesh, the Veiled Market",
    reqDiff = nil, diffScope = "dungeon",  -- Heroic (repeatable) or Mythic
    encounters = { [353263] = 2442 },  -- So'leah -> Cartel Master's Gearglider
  },
  ["Run Sanctum of Domination (Raid)"] = {
    map = 1543, x = 69.7, y = 31.8,   -- The Maw (Desmotaeron)
    lockout = "Sanctum of Domination",
    instanceId = 2450,
    reqDiff = nil, diffScope = "raid",  -- Vengeance (351195) is Mythic only
    encounters = { [354351] = 2429, [351195] = 2435 },  -- The Nine ; Sylvanas Windrunner
  },
  ["Run Sepulcher of the First Ones (Raid)"] = {
    map = 1970, x = 80.6, y = 53.4,   -- Zereth Mortis
    lockout = "Sepulcher of the First Ones",
    instanceId = 2481,
    reqDiff = 16, diffScope = "raid",  -- Mythic only
    encounters = { [368158] = 2537 },  -- The Jailer -> Zereth Overseer
  },
  ["Run Dawn of the Infinites (Dungeon)"] = {
    map = 2025, x = 61.2, y = 84.4,   -- Thaldraszus (Temporal Conflux)
    lockout = "Dawn of the Infinite",
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = {},  -- drop is the random "Reins of the Quantum Courser" container, no single spellId
  },
  ["Run Amirdrassil, the Dream's Hope (Raid)"] = {
    map = 2200, x = 27.0, y = 31.0,   -- Emerald Dream
    lockout = "Amirdrassil, the Dream's Hope",
    instanceId = 2549,
    reqDiff = 16, diffScope = "raid",  -- Mythic only
    encounters = { [424484] = 2677 },  -- Fyrakk the Blazing -> Anu'relos
  },
  ["Run The Stonevault (Dungeon)"] = {
    map = 2214, x = 42.7, y = 8.6,   -- The Ringing Deeps
    lockout = "The Stonevault",
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = { [442358] = 2883 },  -- Void Speaker Eirich -> Stonevault Mechsuit
  },
  ["Run Darkflame Cleft (Dungeon)"] = {
    map = 2214, x = 55.5, y = 21.6,   -- The Ringing Deeps
    lockout = "Darkflame Cleft",
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = { [449264] = 2788 },  -- The Darkness -> Wick
  },
  ["Run Nerub-ar Palace (Raid)"] = {
    map = 2213, x = 35.3, y = 72.0,   -- City of Threads (Azj-Kahet 2255 ~45.1,90.7)
    lockout = "Nerub-ar Palace",
    instanceId = 2657,
    reqDiff = nil, diffScope = "raid",  -- Ascendant Skyrazor (451491) is Mythic only
    encounters = { [451486] = 2922, [451491] = 2922 },  -- Queen Ansurek (both mounts)
  },
  ["Run Liberation of Undermine (Raid)"] = {
    map = 2346, x = 41.6, y = 48.8,   -- Undermine
    lockout = "Liberation of Undermine",
    instanceId = 2769,
    reqDiff = nil, diffScope = "raid",  -- The Big G (235626) is Mythic only
    encounters = { [1221155] = 3016, [235626] = 3016 },  -- Chrome King Gallywix (both mounts)
  },
  ["Run Manaforge Omega (Raid)"] = {
    map = 2371, x = 42.0, y = 21.5,   -- K'aresh (Shadow Point) -- unsure coords
    lockout = "Manaforge Omega",
    -- instanceId TODO (recent raid): run /emf debug while saved to read it; needed for non-enUS auto-skip
    reqDiff = 16, diffScope = "raid",  -- Mythic only
    encounters = { [1234573] = 3135 },  -- Dimensius -> Unbound Star-Eater
  },
  ["Run Magister's Terrace (Midnight Dungeon)"] = {
    map = 2424, x = 63.4, y = 15.3,   -- Isle of Quel'Danas (Midnight) -- unsure (preview)
    lockout = "Magisters' Terrace",
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = { [1265784] = 3074 },  -- Degentrius -> Lucent Hawkstrider -- unsure (preview)
  },
  ["Run March on Quel'Danas (Raid)"] = {
    map = 2424, x = 52.7, y = 84.9,   -- Isle of Quel'Danas (Midnight) -- unsure (preview)
    lockout = "March on Quel'Danas",
    -- instanceId TODO (recent raid): run /emf debug while saved to read it; needed for non-enUS auto-skip
    reqDiff = 16, diffScope = "raid",  -- Mythic only
    encounters = { [1242904] = 3182 },  -- -> Ashes of Belo'ren -- unsure (preview)
  },
  ["Run Windrunner Spire (Dungeon)"] = {
    map = 2395, x = 35.2, y = 78.4,   -- Eversong Woods (Midnight) -- unsure (preview)
    lockout = "Windrunner Spire",
    reqDiff = 23, diffScope = "dungeon",  -- Mythic only
    encounters = { [1263635] = 3059 },  -- The Restless Heart -> Spectral Hawkstrider -- unsure (preview)
  },
}
