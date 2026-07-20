# 🤝 SURTENSION — Co-op

Jouez **SURTENSION à plusieurs** : session partagée, **vagues d'équipe** (les Maelstrom et GRIDLOCK tombent quand *l'équipe* a nettoyé) et **fin votée** (☀ LUMIÈRE / 🌑 NOIR à la majorité).

## Ce qui est synchronisé (et ce qui ne l'est pas)

Un mod CET tourne en session **solo** : ce co-op synchronise la **logique de mission**, pas le monde physique.

| ✅ Synchronisé | ❌ Non synchronisé |
|---|---|
| La phase en cours (l'hôte mène) | Voir le personnage de tes amis |
| Le **compteur d'hostiles d'équipe** | Partager physiquement les ennemis / GRIDLOCK |
| La vague/le boss avancent quand l'équipe a nettoyé | Les dégâts, le loot |
| La **fin** (vote majorité, l'hôte tranche les égalités) | |

Pour vous **voir** en jeu, lancez **CyberpunkMP** en parallèle — c'est complémentaire.

## Mise en place

Le mod SURTENSION installé sur chaque machine, plus le **relais** (Node.js) :

**Hôte** :
```
node relay.js --host --port 7777 --dir "<jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/surtension"
```
En jeu : touche **« héberger une session co-op »** (ou `GetMod("surtension").HostCoop()`), puis lance la mission.

**Amis** :
```
node relay.js --join <ip-hote> --port 7777 --dir "<…>/mods/surtension"
```
En jeu : `GetMod("surtension").JoinCoop()` → SURTENSION démarre automatiquement quand l'hôte la lance.

> L'hôte doit être joignable sur le port choisi (LAN, ou redirection de port / VPN pour jouer par Internet).

## En jeu

- HUD : `CO-OP hôte/join · N joueurs` + compteur d'hostiles **d'équipe**.
- **Vague 1 et boss GRIDLOCK** ne se terminent que quand toute l'équipe a nettoyé.
- La **finale** : ☀ LUMIÈRE / 🌑 NOIR deviennent des **votes** ; la majorité décide, l'hôte tranche les égalités, tout le monde bascule sur la même fin.
- `LeaveCoop()` rétablit le solo.

Le relais (`relay.js`) est identique à celui de NIGHT SHIFT : sa logique de fusion (`mergePeers`) est pure et testée. Co-op désactivé par défaut : le solo est strictement intact (15 tests de non-régression).
