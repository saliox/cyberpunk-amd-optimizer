# ⚡ LATENCY OPTIMIZER — mod CET pour Cyberpunk 2077

Réduit la **latence d'input** (le délai entre ta touche et l'image) et te donne un **compteur de latence en direct** pour vérifier l'effet.

> **Franchise d'abord.** En jeu solo, un mod en Lua ne peut pas toucher au driver ni à Windows. Le seul vrai levier accessible en jeu est le **frame-pacing** — mais c'est justement l'un des plus efficaces contre la latence d'input. Ce mod fait ça honnêtement, et te donne les outils pour mesurer.

## Ce qui réduit vraiment la latence (ce que le mod fait)

| Levier | Effet | Comment |
|---|---|---|
| **Cap FPS** sous ton max soutenu | Le GPU n'est plus saturé à 100 % → la file de rendu raccourcit → **latence plus basse et plus stable** | `ApplyLowLatency()` pose un cap = 97 % de ton FPS médian mesuré |
| **VSync coupé** | Supprime jusqu'à ~1 image de latence d'attente | `ApplyLowLatency()` |
| **Compteur de latence** | Tu vois ta latence de rendu (ms), tes 1 % low et tes saccades en direct → tu peux régler et vérifier | overlay en haut à droite |

La règle d'or du cap : capper **légèrement sous** ce que ta machine soutient (pas au-dessus) garde le pipeline court. Le mod calcule ce cap pour **ta** machine à partir de la mesure.

## Ce que le mod NE peut PAS faire (niveau driver / OS)

Ces leviers sont réels mais hors de portée d'un mod en jeu — utilise l'**app compagnon [Cyberpunk AMD Optimizer](../../)** (ou les réglages Windows/driver) :
- **AMD Anti-Lag / Anti-Lag+** (driver Radeon)
- **HAGS** (planification GPU accélérée par le matériel)
- **Priorité CPU** du process, **Game Mode** Windows, plein écran exclusif
- Overlay/limiteur externe (RTSS) si tu préfères capper hors du jeu

## Le compteur de latence

- **Rendu (ms)** : le temps de frame, la vraie mesure liée à la latence. Vert < 11 ms (~90 fps), jaune < 20 ms, rouge au-delà.
- **FPS** et **1 % low** (les 1 % de frames les plus lentes — ce qui « pique » en jeu).
- **Saccades** : part des frames anormalement longues (au-dessus de `CONFIG.stutterMs`, 40 ms par défaut) — chaque saccade est un pic de latence.
- **Cap conseillé** : la valeur à mettre pour du frame-pacing optimal sur ta machine.

> La mesure est un proxy honnête : le temps de frame et sa stabilité. La **vraie** latence d'input bout-à-bout (touche → pixel) fait ~1 à 3 temps de frame + la latence d'affichage, et ne se mesure qu'avec du matériel ou NVIDIA Reflex/PresentMon. Le mod ne prétend pas la mesurer — il mesure ce qui compte et que l'on peut réduire.

## Prérequis & installation

- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) 1.31+
- Copier `latency_optimizer/` dans `<jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/`
- Dans CET → **Bindings**, assigner : appliquer basse latence, afficher/masquer le compteur, réinitialiser les mesures.

Console : `LO = GetMod("latency_optimizer")` puis `LO.Help()`, `LO.GetStats()`, `LO.ApplyLowLatency()`, `LO.ApplyClarity()`.

## Réglages (`CONFIG` en tête de fichier)

- `latencySettings` — les variables appliquées par le préréglage basse latence (VSync, cap FPS). **Les chemins de variables dépendent de la version du jeu** : si un réglage ne « prend » pas (aucun message de confirmation, ou log `apply_none`), ajuste `group`/`var` ici. Le mesureur, lui, marche indépendamment.
- `capHeadroom` (0.97) — marge du cap conseillé sous le FPS médian.
- `stutterMs` (40) — seuil d'une frame « saccade ».
- `claritySettings` — flou de mouvement / aberration / grain, coupés par `ApplyClarity()`. **N'affectent pas la latence**, mais réduisent le flou en mouvement (souvent confondu avec de la « réactivité »).
- `overlay`, `applyOnStart`, `window`, `language`.

## Perf du mod lui-même

Le mesureur échantillonne chaque frame (arithmétique pure, aucune requête au jeu), mais **ne recalcule et ne redessine qu'à ~4 Hz** ; le HUD se peint depuis un cache (rendu ImGui seulement). Le mod ne coûte donc quasiment rien — il n'ajoute pas la latence qu'il mesure.

## Tests

`python3 test/run.py` (requiert `pip install lupa`) — **12 scénarios** : exactitude de la mesure (frametime, FPS, 1 % low, saccades), cap conseillé, application des réglages basse latence et netteté, isolation des erreurs du HUD, fenêtre glissante bornée, robustesse aux frametimes invalides.
