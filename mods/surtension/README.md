# ⚡ SURTENSION — mission custom pour Cyberpunk 2077

Un netrunner de Maelstrom siphonne le réseau électrique d'Arroyo. Regina Jones te contacte : coupe le siphon avant que tout le district saute.

Mission scriptée complète en Lua (Cyber Engine Tweaks) : appel d'intro façon cinématique (ralenti + dialogue), trajet avec marqueur, deux vagues de combat, phase de piratage sous pression, blackout du district, extraction et récompenses.

## Déroulé

| Phase | Ce qui se passe |
|---|---|
| 📞 Intro | Appel de Regina en ralenti cinématique (60 % de la vitesse), 4 répliques |
| 🗺️ Trajet | Marqueur de quête vers la sous-station Petrochem (Arroyo) |
| 🔫 Vague 1 | 4 Maelstrom défendent le transformateur, orage électrique déclenché |
| 💻 Piratage | 12 s d'override **en restant collé au transformateur** (progression en %) |
| ⚡ Blackout + Vague 2 | Le siphon saute, nuit noire immédiate, 6 renforts (dont un netrunner) |
| 🏃 Extraction | Marqueur vers le point d'extraction |
| 💰 Récompenses | 25 000 €$ + SMG intelligent **Yinglong** (EMP, thème énergie) + 400 Street Cred |

## Prérequis

- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) 1.31+
- [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780) 1.5+ (spawn des ennemis)

## Installation

Copier le dossier `surtension/` dans :

```
<dossier du jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/
```

## Utilisation

1. En jeu, ouvre CET (`²`/`~`) → **Bindings** → assigne une touche à **« SURTENSION — démarrer la mission »**
2. Ou dans la console CET : `GetMod("surtension").Start()`

Autres raccourcis disponibles : afficher ta position (pour recaler les points de mission) et annuler la mission.

## Personnalisation

Tout est dans le bloc `CONFIG` en tête de `init.lua` :

- `objectivePos` / `extractionPos` — coordonnées des points de mission. Utilise le raccourci **« afficher ma position »** en jeu pour relever les coordonnées exactes de l'endroit qui te plaît (les valeurs par défaut visent la zone industrielle d'Arroyo ; vérifie-les en jeu et ajuste, surtout le `z`).
- `wave1` / `wave2` — records TweakDB des ennemis (remplace par du Tyger Claws, Animals, MaxTac…)
- `hackDuration`, `rewardMoney`, `rewardItem`… — difficulté et récompenses

## Notes techniques

- Les ennemis sont spawnés via le `DynamicEntitySystem` de Codeware (pas de persistance : un rechargement de sauvegarde nettoie tout).
- Les objectifs utilisent les `SimpleScreenMessage` natifs et les mappins du jeu — pas d'UI custom à maintenir.
- La mission est une machine à états dans `onUpdate` ; chaque phase est une fonction courte, facile à étendre (ajouter une vague 3, un boss, un choix de fin…).
