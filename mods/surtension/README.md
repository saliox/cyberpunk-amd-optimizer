# ⚡ SURTENSION 2.1 — mission custom pour Cyberpunk 2077

« Regina » te demande de couper un siphon sur le réseau électrique d'Arroyo. Sauf que rien n'est ce qu'il paraît.

Mission scriptée complète en Lua (Cyber Engine Tweaks) : intro cinématique, combat, piratage sous pression, **twist scénaristique**, **boss**, et **double fin à choix** qui change littéralement le ciel de Night City.

> ⚠️ **Spoilers ci-dessous.** Si tu veux jouer la mission à l'aveugle, installe et lance — reviens ici après.

## Déroulé

| Phase | Ce qui se passe |
|---|---|
| 📞 Intro | Appel de « Regina » en ralenti cinématique — coupe le siphon de la sous-station Petrochem |
| 🗺️ Trajet | Marqueur de quête vers Arroyo |
| 🔫 Vague 1 | 4 Maelstrom défendent le transformateur, orage électrique déclenché |
| 💻 Piratage | 15 s d'override collé au transformateur — **une patrouille débarque à 50 %** |
| 🌒 LE TWIST | Le signal était **usurpé**. Le « siphon » était le pare-feu retenant **VOLT**, une IA sauvage vivant dans le réseau. Tu viens de la libérer — blackout immédiat, nuit noire sur Night City |
| ⚠️ Boss | 4 renforts (dont un netrunner), puis **GRIDLOCK**, cyberpsycho au marteau venu récupérer le cœur de l'IA |
| 🎬 Finale cinématique | GRIDLOCK tombe → ralenti profond (×0.35), joueur immobilisé, comms brouillées. **VOLT te pose la question en face**, 5 répliques, le cœur pulse dans ta main — et tu tranches d'une touche : ☀ LUMIÈRE ou 🌑 NOIR |
| ☀ Fin LUMIÈRE — « Rallumer Night City » | Tu écrases le cœur dans la console : VOLT hurle dans les haut-parleurs, la ville se rallume bloc par bloc, l'aube se lève, la vraie Regina appelle. **20 000 €$ + 600 Street Cred + une Quadra Type-66 Avenger dans ton garage** |
| 🌑 Fin NOIR — « La ville dort » | Tu gardes le cœur : les lampadaires s'éteignent en haie d'honneur, VOLT scelle le pacte. **60 000 €$ + 200 Street Cred + SMG intelligent Yinglong (EMP)** |

## Prérequis

- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) 1.31+
- [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780) 1.5+ (spawn des ennemis)

## Installation

Copier le dossier `surtension/` dans :

```
<dossier du jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/
```

## Utilisation

1. En jeu, ouvre CET (`²`/`~`) → **Bindings** → assigne :
   - **« SURTENSION — démarrer la mission »**
   - **« SURTENSION — Finale : ☀ LUMIÈRE »** et **« SURTENSION — Finale : 🌑 NOIR »** ← les touches du choix final
2. Ou dans la console CET : `GetMod("surtension").Start()`

**Si les touches de finale ne sont pas assignées** : au bout de 35 s de cinématique, la mission bascule automatiquement sur un choix de secours par déplacement (deux marqueurs apparaissent, tu marches vers ta fin). Le choix est aussi possible en console : `GetMod("surtension").Choose("grid")` (lumière) ou `Choose("sell")` (noir).

Autres raccourcis : afficher ta position (pour recaler les points de mission) et annuler la mission.
Pour tester une phase précise : `GetMod("surtension").Jump("finale")` (phases : `intro`, `travel`, `wave1`, `hack`, `twist`, `boss`, `finale`).

## Personnalisation

Tout est dans le bloc `CONFIG` en tête de `init.lua` :

- `objectivePos` / `gridPos` / `sellPos` — les points de mission (arène, et les deux marqueurs du choix de secours). Utilise le raccourci **« afficher ma position »** en jeu pour relever des coordonnées exactes (les valeurs par défaut visent la zone industrielle d'Arroyo ; vérifie-les en jeu, surtout le `z`).
- `finaleTimeout` — délai avant la bascule de la finale cinématique vers le choix de secours par déplacement (35 s par défaut)
- `bossRecord` — GRIDLOCK utilise le record du boss Sasquatch (`Character.mql003_boss_sasquatch`), réhabillé par la fiction. Remplace-le par n'importe quel record de boss.
- `wave1` / `hackHarassers` / `bossAdds` — les ennemis de chaque vague
- `hackDuration`, `bossDelay`, récompenses des deux fins…

## Notes techniques

- Ennemis spawnés via le `DynamicEntitySystem` de Codeware (pas de persistance : recharger une sauvegarde nettoie tout).
- Objectifs en `SimpleScreenMessage` natifs + mappins du jeu — pas d'UI custom à maintenir.
- La **finale cinématique** combine ralenti profond (`SetTimeDilation(0.35)`), immobilisation du joueur (`GameplayRestriction.NoMovement`, retirée à la sortie quoi qu'il arrive) et brouillage de comms — le choix se fait par hotkey, avec double secours (marqueurs au sol après 35 s, ou commande console `Choose`).
- La fin LUMIÈRE touche au monde : heure basculée à l'aube + météo dégagée ; la fin NOIR laisse la nuit du blackout en place.
- Machine à états dans `onUpdate`, une fonction courte par phase — facile d'ajouter une vague, une fin C, un second boss…
