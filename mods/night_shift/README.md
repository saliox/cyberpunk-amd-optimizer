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

## 🤝 Co-op (multijoueur de missions)

Jouez les missions **ensemble** : session partagée, **objectifs de combat d'équipe** (une vague se termine quand *l'équipe* l'a nettoyée) et **choix votés à la majorité**. L'hôte mène, les autres suivent automatiquement la mission lancée.

Comme un mod CET tourne en session solo, c'est la **logique de mission** qui est synchronisée (objectifs, progression, choix), **pas le monde physique** (pour vous voir à l'écran, lancez CyberpunkMP en parallèle). La mise en réseau passe par un **relais** compagnon (`coop/relay.js`, Node.js) — voir **[`coop/README.md`](coop/README.md)** pour la mise en place. Console : `NS.HostCoop()`, `NS.JoinCoop()`, `NS.LeaveCoop()`, `NS.GetCoop()`. Désactivé par défaut : le solo est strictement intact.

## Structure de campagne

Par défaut (`CONFIG.campaign = true`), les 15 missions **se déverrouillent au fil de la progression** : chaque contrat attend que ses antécédents soient terminés. L'ordre est pensé pour que les missions à choix précèdent toujours leurs retombées (ns07 avant ns12, ns09 avant ns10 et ns14), et **CODA se débloque une fois les trois grands fils bouclés** (ns12, ns13, ns14). Tu peux tout ouvrir avec `CONFIG.campaign = false` ou `NS.SetFreePlay(true)` en console.

- **Journal** : `NS.Journal()` (ou `NS.GetJournal()`) — statut de chaque contrat (terminé / dispo / verrouillé), choix effectué, meilleur temps, et ton alignement courant.
- **Bilan de campagne** : à la fin de **CODA**, un débriefing généré à l'exécution récapitule ton parcours — contrats bouclés, tally Signal/Marché, une conclusion qui varie selon ta voie dominante, et ton dernier mot. Le vrai point final de la campagne.

## Performances

Le mod est pensé pour un **coût FPS minimal, sans rien retirer au contenu ni à la qualité** :
- **Logique throttlée** (`CONFIG.pollInterval`, ~12 Hz) : les tests de distance, scans d'ennemis et calculs d'objectif ne tournent pas à chaque frame mais ~12 fois par seconde, avec le delta cumulé — invisible en jeu, ~5× moins de travail CPU par seconde.
- **HUD sans coût de rendu** : l'objectif, la distance et les compteurs sont **pré-calculés** pendant le tick de logique ; le rendu par frame ne fait que des appels ImGui, aucune requête au jeu.
- **Hors mission, le mod coûte ~0** : `onUpdate` et `onDraw` se court-circuitent en une comparaison.
- Position joueur et résolution d'écran mises en cache par tick. Aucune vague, aucun effet, aucun élément de HUD n'a été réduit — c'est purement de la plomberie.

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

`python3 test/run.py` (requiert `pip install lupa`) — **47 scénarios** (dont 7 de **co-op** : off par défaut, publication de l'hôte, vague qui attend l'équipe, HUD d'équipe, suivi du joiner, choix par vote, quitter ; la fusion réseau du relais `mergePeers` a son propre test Node) et 3 d'optimisation : HUD peint depuis le cache avec pile ImGui équilibrée, panne de rendu isolée, logique throttlée qui préserve la complétion malgré des deltas de 60 fps) : les 15 missions en autoplay complet, les choix A/B/marche/fin secrète, **les conséquences croisées entre missions** (reconnaissance du Courtier, révélation de la secte, allègement/durcissement des vagues, assistance de VOLT, fin secrète déblocable/verrouillée, bonus de fidélité), **la campagne** (déverrouillage progressif, journal, bilan final des deux voies), l'échec de course, l'abandon en pleine défense, la perte de session en plein boss, les négatifs (double démarrage, choix hors phase, auto-validation des fins) et la persistance des stats + choix.
