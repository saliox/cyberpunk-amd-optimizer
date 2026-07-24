# 🎚️ BETTER MIX — table de mixage audio pour Cyberpunk 2077

Le mix par défaut de Cyberpunk noie souvent **les dialogues** sous la musique et les effets. **BETTER MIX** ajoute une **fenêtre de mixage** en jeu : un curseur par canal audio et des **préréglages sauvegardés** que tu rappelles d'un clic.

## Ce que c'est (et ce que ce n'est pas)

Cyberpunk passe par **Wwise** et n'expose aux mods que le **volume de chaque bus audio**, pas d'égaliseur paramétrique. Il n'y a donc **pas d'EQ par bandes de fréquences** (graves/médiums/aigus) accessible depuis un mod CET.

Ce que BETTER MIX fait — et qui **corrige réellement un mix mal foutu** — c'est **rééquilibrer le volume relatif des canaux** et mémoriser des présets. C'est le vrai sens de « mieux mixer » ici : monter les dialogues, baisser la musique, calmer les SFX en combat, etc. Les valeurs sont écrites via le **SettingsSystem** du jeu, exactement comme le menu Audio — donc **persistantes et sûres**.

| ✅ Ce que BETTER MIX fait | ❌ Ce qu'un mod ne peut pas faire |
|---|---|
| Régler le volume par canal (dialogues, SFX, musique, radio, téléphone, général) | Un EQ par fréquences (grave/médium/aigu) |
| Sauvegarder / rappeler des préréglages | Compresser, ducker ou spatialiser le son |
| Rétablir les réglages d'origine d'un clic | |

## Installation

Copie le dossier `better_mix` dans :
```
<jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/
```
Requiert **Cyber Engine Tweaks 1.31+**. Puis, dans le menu **Bindings** de l'overlay CET, assigne une touche à **« ouvrir/fermer la table de mixage »**.

## En jeu

- Ouvre la fenêtre avec ta touche (ou console `GetMod("better_mix").ToggleWindow()`).
- **Un curseur par canal** (0–100). Le volume s'applique **en direct** pendant que tu ajustes (throttlé pour ne pas spammer le jeu).
- **Préréglages d'usine** (cliquables) :
  - **Dialogues clairs** — dialogues à fond, musique/SFX en retrait (le correctif le plus demandé).
  - **Cinématique** — équilibré, musique légèrement baissée.
  - **Combat** — SFX à fond, musique/radio étouffées.
  - **Conduite** — radio voiture en avant.
  - **Nuit (discret)** — tout plus bas mais équilibré.
  - **Défaut jeu** — remet 100 partout.
- **Sauver** : nomme et enregistre tes propres réglages (dans `presets.json`), rappelables à chaque session.
- **Rétablir l'origine** : restaure les volumes captés au chargement du mod.

## Console

`BM = GetMod("better_mix")`

- `BM.ToggleWindow()` — ouvre/ferme la fenêtre
- `BM.ApplyPreset(nom)` — `"dialogue"`, `"cinematic"`, `"combat"`, `"driving"`, `"night"`, `"default"`, ou un préréglage à toi
- `BM.SetChannel(id, 0-100)` — `id` : `master`, `dialogue`, `sfx`, `music`, `radio`, `phone`
- `BM.SavePreset(nom)` · `BM.DeletePreset(nom)` · `BM.ListPresets()`
- `BM.GetChannels()` · `BM.Restore()`

## Réglages (`CONFIG` en tête de `init.lua`)

- `language` — `"auto"`, `"fr"`, `"en"`.
- `openOnStart` — ouvrir la fenêtre au chargement.
- `applyLive` / `applyThrottle` — application en direct des curseurs et sa cadence.
- `channels` — **chemins de variables** de chaque canal (`group`/`var`). Ils suivent le menu Audio du jeu ; si un canal ne « prend » pas sur ta version, ajuste-le ici (par ex. `DialogVolume` selon la build).

## Fiabilité

Toutes les I/O et tous les appels au jeu sont en `pcall` : un fichier verrouillé ou une variable absente ne fait jamais tomber le mod, et une erreur de rendu **coupe proprement** la fenêtre (pile ImGui rééquilibrée) sans crasher. Les noms de préréglages sont **nettoyés** avant écriture (aucune injection dans `presets.json`). Couvert par **21 scénarios de simulation** (`python3 test/run.py`) : capture/écriture des volumes, bornage 0–100, présets d'usine et perso (sauvegarde/rechargement/écrasement/suppression), rétablissement, `ConfirmChanges`, détection de langue, et la fenêtre (ouverture, curseurs, boutons, robustesse à une panne ImGui).
