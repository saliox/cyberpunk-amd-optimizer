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
node relay.js --host --port 7777 --dir "<jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/night_shift"
```
En jeu : touche **« héberger une session co-op »** (ou console `NS = GetMod("night_shift"); NS.HostCoop()`), puis lance une mission normalement.

**Les amis** (rejoignent) :
```
node relay.js --join <ip-de-l-hote> --port 7777 --dir "<…>/mods/night_shift"
```
En jeu : console `NS.JoinCoop()`. Le joiner **démarre automatiquement** la mission que l'hôte a lancée et le suit.

> Réseau : l'hôte doit être joignable sur le port choisi (LAN direct, ou redirection de port / VPN type Radmin/Hamachi pour jouer par Internet).

## En jeu

- Le HUD affiche `CO-OP hôte/join · N joueur(s)` et le **compteur d'hostiles d'équipe**.
- Les **vagues et boss** ne se terminent que quand **toute l'équipe** a nettoyé sa part — chacun contribue.
- Les **choix** (Choix A / Choix B) sont des **votes** : la majorité décide, l'hôte tranche les égalités, et tout le monde bascule sur la même fin en même temps.
- `NS.LeaveCoop()` (ou la touche dédiée) quitte la session et rétablit le solo.

## Console

`NS.HostCoop(code?)` · `NS.JoinCoop(code?)` · `NS.LeaveCoop()` · `NS.GetCoop()` → `{ active, role, code, peers, teamRemaining }`.

## Fiabilité

- Toutes les I/O du mod sont en `pcall` : un fichier verrouillé ne fait jamais tomber le mod, et le co-op inactif ne coûte rien (solo strictement intact — 40 tests de non-régression le prouvent).
- Le relais ignore un pair sans heartbeat depuis 6 s (déconnexion) et recalcule l'équipe.
- La logique de fusion du relais (`mergePeers`) est pure et testée ; la logique co-op du mod est couverte par 7 scénarios de simulation.
