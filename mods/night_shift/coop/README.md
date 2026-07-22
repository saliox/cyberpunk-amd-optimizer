# 🤝 NIGHT SHIFT — Co-op de missions

Jouez les missions de NIGHT SHIFT **ensemble** : même session, **objectifs de combat d'équipe** (une vague se termine quand *l'équipe* l'a nettoyée), et **choix votés à la majorité**.

## À lire d'abord — ce qui est synchronisé (et ce qui ne l'est pas)

Un mod Cyber Engine Tweaks tourne dans une session **solo** et ne peut pas ouvrir de connexion réseau. Ce co-op synchronise donc la **logique de mission**, pas le monde physique :

| ✅ Synchronisé | ❌ Non synchronisé |
|---|---|
| La mission et la phase en cours (l'hôte décide) | Voir le personnage de tes amis à l'écran |
| Le **compteur d'hostiles d'équipe** (somme des restants) | Partager physiquement les mêmes ennemis / PNJ |
| La progression : la vague avance quand l'équipe a nettoyé | Les dégâts, l'inventaire, le loot |
| Les **choix** (vote à la majorité, l'hôte tranche les égalités) | |

En clair : **« mêmes missions, mêmes objectifs, décisions collectives, progression synchronisée »**, chacun dans son instance. Pour vous **voir** et partager le monde, lancez **[CyberpunkMP](https://www.nexusmods.com/cyberpunk2077)** en parallèle — les deux sont complémentaires.

## Comment ça marche

Le sandbox CET ne peut écrire que des fichiers. Un **relais** compagnon (Node.js) fait le réseau :
- le mod écrit `coop_out.json` (son état + sa contribution) et lit `coop_in.json` (l'état d'équipe) ;
- le relais échange ces fichiers entre les machines par TCP et **agrège** (somme des hostiles restants, résolution des votes).

## Mise en place

Sur chaque machine, le mod NIGHT SHIFT doit être installé. Puis **le relais** (Node.js requis) :

**L'hôte** (celui qui mène) :
```
node relay.js --host --port 7777 --token <code> --dir "<jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/night_shift"
```
Si tu omets `--token`, le relais **génère un code et l'affiche** : partage-le à tes amis (c'est le mot de passe de la session). En jeu : touche **« héberger une session co-op »** (ou console `NS = GetMod("night_shift"); NS.HostCoop()`), puis lance une mission.

**Les amis** (rejoignent) :
```
node relay.js --join <ip-de-l-hote> --port 7777 --token <code> --dir "<…>/mods/night_shift"
```
En jeu : console `NS.JoinCoop()`. Le joiner **démarre automatiquement** la mission que l'hôte a lancée et le suit.

> Réseau : l'hôte doit être joignable sur le port choisi (LAN direct, ou redirection de port / VPN type Radmin/Hamachi pour jouer par Internet).

## Sécurité du serveur

Le relais hôte est un serveur TCP qui peut être exposé à Internet (redirection de port) — il est donc durci contre les connexions hostiles :

- 🔑 **Authentification par jeton partagé** : sans le bon `--token`, la connexion est fermée. Comparaison à temps constant (anti timing-attack). Jamais de serveur ouvert : sans jeton fourni, il en génère un et l'affiche.
- 🛡️ **Pas d'usurpation d'hôte** : un pair distant est **toujours** forcé au rôle « join ». Seul le fichier local de la machine hôte fait autorité sur la mission/phase — un intrus ne peut pas détourner la partie.
- 🧹 **Toutes les entrées réseau sont validées et bornées** avant usage : nombres plafonnés (pas de `teamRemaining` géant), chaînes nettoyées (guillemets/accolades/contrôles retirés → aucune injection dans `coop_in.json`) et tronquées.
- 🚦 **Anti-DoS** : limite de connexions simultanées (`--max-clients`, 8 par défaut), limite de débit par connexion, plafond de taille de tampon et de message, timeout d'inactivité, et fenêtre de handshake courte. Un pair déconnecté sort de l'équipe au heartbeat périmé.
- 🔒 **Défense en profondeur côté mod** : le mod ignore un `coop_in.json` anormalement gros.
- 🌐 **Bonnes pratiques** : n'ouvre le port que le temps de la session, préfère un VPN (Radmin/Hamachi/Tailscale) à une redirection de port publique, et ne partage le jeton qu'avec tes coéquipiers. Choisis un `--token` long si tu exposes le port publiquement.

Validé par `node test-security.js` (bornage, anti-usurpation, jeton) et par `test-relay.js` (rejet d'un intrus au mauvais jeton, en conditions réseau réelles).

## En jeu

- Le HUD affiche `CO-OP hôte/join · N joueur(s)` et le **compteur d'hostiles d'équipe**.
- **Avertissement de latence discret** : si le ping dépasse `pingWarnMs` (120 ms par défaut, réglable dans `CONFIG`), une ligne orange apparaît sous le HUD — `⚠ Latence — Hôte 0 ms · Joueur X ms`. L'hôte y voit le **pire ping** des joueurs connectés ; chaque joiner y voit **sa** latence vers l'hôte. Rien ne s'affiche tant que le ping reste correct. Le relais mesure le ping par un ping/pong horodaté chaque seconde (RTT réel).
- Les **vagues et boss** ne se terminent que quand **toute l'équipe** a nettoyé sa part — chacun contribue.
- Les **choix** (Choix A / Choix B) sont des **votes** : la majorité décide, l'hôte tranche les égalités, et tout le monde bascule sur la même fin en même temps.
- `NS.LeaveCoop()` (ou la touche dédiée) quitte la session et rétablit le solo.

## Console

`NS.HostCoop(code?)` · `NS.JoinCoop(code?)` · `NS.LeaveCoop()` · `NS.GetCoop()` → `{ active, role, code, peers, teamRemaining }`.

## Fiabilité

- Toutes les I/O du mod sont en `pcall` : un fichier verrouillé ne fait jamais tomber le mod, et le co-op inactif ne coûte rien (solo strictement intact — 40 tests de non-régression le prouvent).
- Le relais ignore un pair sans heartbeat depuis 6 s (déconnexion) et recalcule l'équipe.
- La logique de fusion du relais (`mergePeers`) est pure et testée ; la logique co-op du mod (dont l'avertissement de latence) est couverte par 11 scénarios de simulation.

## Validation réseau réelle

`node test-relay.js` lance le **vrai relais** (hôte + 2 clients, processus séparés) qui dialoguent par de **vraies sockets TCP** sur `127.0.0.1`, chacun avec son dossier et ses fichiers `coop_*.json` comme en jeu. Vérifié end-to-end : connexion, **somme des hostiles d'équipe** propagée à tous, mission/phase de l'hôte diffusées, **résolution des votes à la majorité**, **mesure du ping** (ping/pong horodaté → `selfPingMs`/`worstPingMs` écrits dans `coop_in.json`), et **déconnexion** (un pair tué sort de l'équipe au heartbeat périmé). Latence de propagation mesurée : **~130 ms sur localhost** (bornée par le poll de 200 ms du relais + le sync ~0,4 s du mod en jeu → état d'équipe synchronisé en **moins d'une seconde**, largement suffisant pour de la logique de mission).

> Non couvert par ce test : le pare-feu / NAT d'un **vrai réseau distant** (c'est de la config réseau, pas du code — LAN direct, redirection de port, ou VPN type Radmin/Hamachi), et le jeu lui-même.
