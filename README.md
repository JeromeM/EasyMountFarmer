# EasyMountFarmer

Addon World of Warcraft (retail / Midnight, patch 12.x) qui porte **en jeu** un plan de route de farm de
montures de donjons/raids/boss de zone.

L'addon affiche **une étape à la fois** (le prochain donjon/raid à faire pour une monture qui te manque),
avec :

- masquage automatique des montures déjà possédées (`C_MountJournal`) ;
- avance automatique quand tu tues le boss (`ENCOUNTER_END`) ;
- popup de félicitations quand la monture tombe (`NEW_MOUNT_ADDED`), avec annonce optionnelle dans le chat
  (groupe / raid / guilde) incluant le lien de la monture ;
- retour automatique à l'étape 1 aux resets (quotidien pour les donjons, hebdo pour les raids / mythique) ;
- étape « attendre le reset » quand tout est fait, avec compte à rebours ;
- détection des lockouts déjà pris ce reset (via `instanceId`, robuste quelle que soit la langue du client) ;
- bouton pour passer à la bonne difficulté (héroïque / mythique / 10-25) ;
- guidage par waypoint auto vers l'entrée (TomTom si présent, sinon flèche Blizzard) ;
- page d'options dans le menu natif du jeu (catégorie AddOns).

## Navigation avancée (optionnel)

EasyMountFarmer pose un waypoint sur l'entrée de l'instance. Si **FarstriderLib** est installé, l'addon
l'utilise en plus pour un vrai routage pas-à-pas (portails, vols, téléports) : il affiche l'action à faire
(pierre de foyer / portail cliquable) ou la flèche vers le prochain point, recalculé en direct.

Sans FarstriderLib, tout fonctionne : tu as simplement le waypoint sur l'entrée au lieu du pas-à-pas.

## Installation (usage privé)

Copier (ou lier en symlink) le dossier `EasyMountFarmer/` dans
`World of Warcraft/_retail_/Interface/AddOns/`, puis `/reload` en jeu.

En jeu : `/emf` (ou `/easymountfarmer`) ouvre la fenêtre. `/emf next`, `/emf prev`, `/emf guide`,
`/emf reset`, `/emf help` pour la liste complète.

## Développement / mise à jour des données

La route provient de `data/planner.json`. Pour régénérer les données Lua :

```sh
node scripts/build-data.mjs
```

Cela réécrit `EasyMountFarmer/Data/RouteData.lua` et régénère `scripts/Locations.skeleton.lua`.
`EasyMountFarmer/Data/Locations.lua` (coordonnées, lockouts, difficultés, encounterIDs saisis à la main)
n'est **jamais** écrasé par le build.

`node scripts/check-lua.mjs` valide la syntaxe de tous les `.lua` (via `luaparse`).
`bash scripts/deploy.sh` copie le dossier addon dans ton dossier `Interface/AddOns`.

## Traductions

Tous les textes affichés passent par une table de locale (`ns.L`, mise en place dans `Core/Locale.lua`).
L'anglais (`Locales/enUS.lua`) est la référence ; le français (`Locales/frFR.lua`) est fourni. Pour ajouter
une langue : copier `Locales/enUS.lua`, ajouter `if GetLocale() ~= "xxXX" then return end` en tête, traduire
les valeurs, et référencer le fichier dans `EasyMountFarmer.toc`. Les clés manquantes retombent
automatiquement sur le texte anglais (la clé).
