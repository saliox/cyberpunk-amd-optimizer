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
node relay.js --host --port 7777 --token <code> --dir "<jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/surtension"
```
Sans `--token`, le relais génère un code et l'affiche : partage-le à tes amis (mot de passe de la session). En jeu : touche **« héberger une session co-op »** (ou `GetMod("surtension").HostCoop()`), puis lance la mission.

**Amis** :
```
node relay.js --join <ip-hote> --port 7777 --token <code> --dir "<…>/mods/surtension"
```
En jeu : `GetMod("surtension").JoinCoop()` → SURTENSION démarre automatiquement quand l'hôte la lance.

> L'hôte doit être joignable sur le port choisi (LAN, ou redirection de port / VPN pour jouer par Internet).

## En jeu

- HUD : `CO-OP hôte/join · N joueurs` + compteur d'hostiles **d'équipe**.
- **Avertissement de latence discret** : au-delà de `pingWarnMs` (120 ms par défaut), une ligne orange `⚠ Latence — Hôte 0 ms · Joueur X ms` apparaît sous le HUD. L'hôte voit le **pire ping** connecté, chaque joiner voit **sa** latence vers l'hôte. Invisible tant que le ping est bon. Ping mesuré par ping/pong horodaté (RTT réel) chaque seconde côté relais.
- **Vague 1 et boss GRIDLOCK** ne se terminent que quand toute l'équipe a nettoyé.
- La **finale** : ☀ LUMIÈRE / 🌑 NOIR deviennent des **votes** ; la majorité décide, l'hôte tranche les égalités, tout le monde bascule sur la même fin.
- **Détection « relais injoignable »** : le relais écrit un battement de cœur (`ts`) ; s'il fige > ~6 s (relais mort), le HUD affiche `⚠ CO-OP désynchronisé` et la mission **retombe sur ton compte local** (pas de vague qui fige). `GetCoop().relayLost` le signale.
- **Reconnexion automatique** du client (backoff 1→8 s) : la session survit à une coupure de l'hôte.
- `LeaveCoop()` rétablit le solo.

Le relais (`relay.js`) est identique à celui de NIGHT SHIFT : sa logique de fusion (`mergePeers`) est pure et testée, et il mesure le ping (ping/pong horodaté) pour l'avertissement de latence. Co-op désactivé par défaut : le solo est strictement intact (15 tests de non-régression).

## Sécurité du serveur

Le relais hôte est un serveur TCP durci (il peut être exposé à Internet) :

- 🔑 **Authentification par jeton** (`--token`) à temps constant ; jamais de serveur ouvert (jeton auto-généré et affiché si absent).
- 🛡️ **Pas d'usurpation d'hôte** : un pair distant est toujours forcé au rôle « join ».
- 🧹 **Entrées réseau validées et bornées** (nombres plafonnés, chaînes nettoyées → pas d'injection).
- 🚦 **Anti-DoS** : limites de connexions / **cap par IP** / débit / taille / timeouts ; pair déconnecté purgé.
- 🌐 Ouvre le port seulement le temps de la session, préfère un VPN à une redirection publique.

Validé par `node test-security.js` et `node test-relay.js` (rejet d'un intrus au mauvais jeton en réseau réel).
