# Mount Roadmap

Addon World of Warcraft (retail / Midnight, patch 12.x) qui porte **en jeu** le « plan de route » de farm
de montures de [SimpleArmory](https://simplearmory.com).

L'addon affiche **une étape à la fois** (le prochain donjon/raid à faire pour une monture qui te manque),
avec :

- masquage automatique des montures déjà possédées (`C_MountJournal`) ;
- avance automatique quand tu tues le boss (`ENCOUNTER_END`) ;
- popup de félicitations quand la monture tombe (`NEW_MOUNT_ADDED`) ;
- retour automatique à l'étape 1 aux resets (quotidien pour les donjons, hebdo pour les raids) ;
- détection des lockouts de raid déjà pris cette semaine ;
- bouton pour passer à la bonne difficulté (héroïque / mythique / 10-25) ;
- guidage par waypoint (TomTom si présent, sinon flèche Blizzard).

## Installation (usage privé)

Copier (ou lier en symlink) le dossier `MountRoadmap/` dans
`World of Warcraft/_retail_/Interface/AddOns/`, puis `/reload` en jeu.

En jeu : `/mr` (ou `/mountroadmap`) ouvre la fenêtre. `/mr next`, `/mr prev`, `/mr guide`, `/mr reset`.

## Développement / mise à jour des données

La route provient de `data/planner.json` (snapshot de SimpleArmory). Pour régénérer les données Lua :

```sh
node scripts/build-data.mjs
```

Cela réécrit `MountRoadmap/RouteData.lua` et régénère `scripts/Locations.skeleton.lua`.
`MountRoadmap/Locations.lua` (coordonnées, lockouts, difficultés, encounterIDs saisis à la main) n'est
**jamais** écrasé par le build.

Pour resynchroniser après une mise à jour du site : recopier `static/data/planner.json` de SimpleArmory
dans `data/planner.json`, puis relancer le build.
