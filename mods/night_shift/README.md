# 🌃 NIGHT SHIFT 1.0 — pack de 15 missions pour Cyberpunk 2077

La suite de **SURTENSION**. VOLT a laissé des traces dans le réseau de Night City — des échos, des sectes, des charognards, et une facture. 15 contrats scénarisés, du nettoyage de nid au boss final à **trois issues** (dont une fin secrète).

## Les 15 contrats

| # | Mission | District | Type | Particularité |
|---|---------|----------|------|---------------|
| 01 | Échos | Watson | enquête | l'antenne qui répète une voix morte |
| 02 | Basse tension | Japantown | collecte ×3 + vague | Tyger Claws |
| 03 | Le Convoi | Badlands | **course** 120 s + vague | échec possible |
| 04 | Static | Pacifica | dialogue + vague | Voodoo Boys |
| 05 | Chaleur morte | Heywood | **défense** 60 s, 3 vagues | Scavs |
| 06 | La Fourmilière | Arroyo | 3 vagues successives | + Copperhead offert |
| 07 | Peau neuve | Japantown | zone à tenir + **choix A/B** | NCPD ou marché noir |
| 08 | Ligne morte | City Center | sabotage + **course d'évacuation** | |
| 09 | Les Enfants du Courant | Badlands | dialogue + **choix moral** | mentir à Regina ? |
| 10 | GRIDLOCK : Écho | Arroyo | **boss** rematch | le châssis réanimé |
| 11 | Blackout partiel | Pacifica | défense 45 s + collecte | |
| 12 | Le Courtier | City Center | embuscade Arasaka + fuite | |
| 13 | Tension de surface | Badlands | double sabotage + boss | Animals |
| 14 | Le Chœur | Westbrook | collecte ×3 + vague + **choix** | la berceuse |
| 15 | **CODA** | Arroyo | boss final + **3 fins** | fin secrète : *ne rien faire* |

## Prérequis & installation

- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) 1.31+ et [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780) 1.5+
- Copier `night_shift/` dans `<jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/`
- Dans CET → Bindings : **mission suivante**, **démarrer**, **annuler**, **Choix A**, **Choix B**, **position**

Console : `NS = GetMod("night_shift")` puis `NS.List()`, `NS.Start(3)` ou `NS.Start("ns10")`, `NS.Choose("a")`, `NS.Abort()`, `NS.GetStats()`.

> ⚠️ **Première run** : les coordonnées et les records d'ennemis sont des préréglages — recale les positions avec la touche « position » et ajuste les records dans `FOES`/les définitions si besoin. Chaque mission est un bloc de données en tête de fichier.

## Les choix qui comptent — « le réseau se souvient »

Tes décisions sont **persistantes** (dans `night_shift_stats.json`) et se répercutent sur les missions suivantes. Deux axes se dessinent selon tes choix : **Signal** (protéger l'héritage de VOLT) et **Marché** (tout monnayer).

| Ton choix… | …change plus tard |
|---|---|
| **ns07 B** — vendre le shard du témoin | Dans **ns12**, le Courtier te reconnaît (« on a déjà fait affaire ») et amène 2 équipes de renfort en plus |
| **ns09 B** — épargner les Enfants du Courant | **ns10** révèle que la secte a tenté de ressusciter GRIDLOCK (au lieu de pointer le Courtier), et dans **ns14** ils font diversion : la garde Voodoo est allégée |
| **Alignement Signal ≥ 2** | Dans **CODA**, VOLT t'accueille en allié, **grille 2 renforts Arasaka** au combat, bonifie la fin A (« caches d'eddies propres »), et **débloque la fin secrète** (la Communion) |
| **Alignement Marché ≥ 2** | Dans **CODA**, VOLT est distant, tes ventes ont financé Arasaka : **2 équipes de plus** verrouillent les sorties |

La **fin secrète de CODA** (ne rien faire, écouter la berceuse) n'est plus un simple timeout : elle se **mérite** — il faut avoir gagné la confiance du réseau (2 choix Signal), sinon l'attente bascule sur le choix par déplacement classique.

Console : `NS.GetAlignment()` → `{ signal, eddies }`, `NS.GetChoices()` → tes décisions par mission.

## Le moteur

Un moteur générique à **9 types de phases** — `dialogue`, `goto`, `wave`, `hold` (zone à tenir avec harceleurs), `boss`, `defend` (vagues chronométrées), `collect` (multi-points), `race` (checkpoints + limite de temps, échec possible), `choice` (A/B par hotkey, secours à la marche, fin secrète par attente) — plus un **système de conséquences déclaratif** : conditions `when` sur les phases, épilogues à variantes, renforts et assistances conditionnels, choix verrouillables. Toutes les protections héritées de SURTENSION :

- comptage d'ennemis robuste (non létal compté, spawns asynchrones suivis, timeouts anti soft-lock)
- mort/rechargement détectés → annulation propre sans écraser l'heure du save chargé
- teardown central (verrou, brouillage, ralenti, météo) sur tous les chemins de sortie + `onShutdown`
- rayon de validation des choix **plus petit** que celui des objectifs (une fin ne peut pas se valider toute seule)
- HUD ImGui à pile garantie équilibrée (panne isolée + log unique)
- stats persistantes par mission (`night_shift_stats.json`) : jouées / finies / record de temps
- FR / EN auto

**Ajouter une mission 16** = ajouter un bloc `M{...}` de données : aucune ligne de moteur à toucher.

## Tests

`python3 test/run.py` (requiert `pip install lupa`) — **33 scénarios** : les 15 missions en autoplay complet, les choix A/B/marche/fin secrète, **les conséquences croisées entre missions** (reconnaissance du Courtier, révélation de la secte, allègement/durcissement des vagues, assistance de VOLT, fin secrète déblocable/verrouillée, bonus de fidélité), l'échec de course, l'abandon en pleine défense, la perte de session en plein boss, les négatifs (double démarrage, choix hors phase, auto-validation des fins) et la persistance des stats + choix.
