# 🔌 Pont mod ↔ app — LATENCY OPTIMIZER

Fait communiquer le mod CET **LATENCY OPTIMIZER** (en jeu) avec l'application **Cyberpunk AMD Optimizer** (bureau, Electron). L'app peut alors **afficher les stats de latence en direct** et **piloter le mod** (appliquer basse latence, poser un cap, etc.) depuis son interface.

## Pourquoi des fichiers ?

CET exécute le mod en Lua **sandboxé** : pas de socket, pas de HTTP, mais un accès `io` au **dossier du mod**. C'est le canal fiable et sans dépendance : le mod écrit/lit des fichiers JSON, l'app fait de même (elle connaît déjà le chemin d'installation du jeu). C'est la méthode standard des mods CET qui parlent à un outil externe.

## Le protocole

Trois fichiers dans `…/cyber_engine_tweaks/mods/latency_optimizer/` :

| Fichier | Écrit par | Contenu |
|---|---|---|
| `bridge_status.json` | **le mod** (~1×/s) | `{ schema, mod, version, ts, ready, fps, frametimeMs, low1, stutterPct, suggestedCap, samples, overlay }` |
| `bridge_command.json` | **l'app** | `{ id, cmd, cap?, value? }` — `id` strictement croissant |
| `bridge_ack.json` | **le mod** | `{ id, ok, message, ts }` — réponse à la commande `id` |

Le mod ne traite chaque `id` qu'**une fois** (déduplication), puis neutralise le fichier de commande. `ts` sert de heartbeat (l'app sait si le jeu tourne).

### Commandes reconnues

| `cmd` | Effet | Champs |
|---|---|---|
| `apply_low_latency` | cap FPS conseillé + VSync off | `cap?` (sinon calculé) |
| `set_cap` | pose un cap FPS précis | `cap` |
| `apply_clarity` | coupe flou/aberration/grain (netteté) | — |
| `reset` | réinitialise les mesures | — |
| `set_overlay` | affiche/masque le compteur | `value` 0/1 |
| `ping` | test de vie | — |

## Côté app : le module de référence

`latency-bridge.js` (Node.js, **aucune dépendance**) implémente la moitié app. À importer dans le **process principal** Electron de Cyberpunk AMD Optimizer :

```js
const { LatencyBridge } = require('./bridge/latency-bridge');

const bridge = new LatencyBridge(gameInstallPath);   // le chemin que l'app gère déjà
if (bridge.modInstalled()) {
  bridge.on('status', s => mainWindow.webContents.send('latency:status', s));
  bridge.start();                                    // poll du statut

  // depuis un bouton du renderer (via IPC) :
  ipcMain.handle('latency:applyLowLatency', () => bridge.applyLowLatency());
  ipcMain.handle('latency:setCap', (_e, cap) => bridge.setCap(cap));
  ipcMain.handle('latency:reset', () => bridge.reset());
}
```

- `readStatus()` / événement `status` : dernières stats du mod.
- `isLive(status)` : le mod tourne-t-il (heartbeat récent) ?
- `applyLowLatency(cap?)`, `setCap(cap)`, `applyClarity()`, `reset()`, `setOverlay(on)`, `ping()` : renvoient une `Promise` résolue avec l'accusé du mod (ou rejetée au timeout si le jeu n'est pas lancé).

## Ce qu'il reste à faire côté app

Le code source de l'app n'étant pas dans ce dépôt, cette moitié est fournie **prête à brancher** : importer `latency-bridge.js`, ajouter un panneau « Latence (en jeu) » qui affiche `frametimeMs / fps / low1 / stutterPct / suggestedCap`, et des boutons qui appellent les raccourcis ci-dessus. Le mod, lui, est complet et testé — il écrit son statut et exécute les commandes dès qu'il tourne.

## Sécurité / robustesse

- Toutes les I/O du mod sont en `pcall` : un fichier verrouillé/corrompu ne fait jamais tomber le mod.
- Le module app avale les erreurs de lecture (retourne `null`) et borne les commandes par un timeout.
- Aucune donnée sensible : uniquement des métriques de perf locales.
