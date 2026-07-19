--------------------------------------------------------------------------
-- NIGHT SHIFT 1.0 — pack de 15 missions custom pour Cyberpunk 2077
--------------------------------------------------------------------------
-- La suite de SURTENSION. VOLT a laissé des traces dans le réseau de
-- Night City — des échos, des sectes, des charognards, et une facture.
-- 15 contrats scénarisés, du simple nettoyage au boss final à 3 issues.
--
-- Moteur générique à phases : dialogue, trajet, vague, zone à tenir,
-- boss, défense chronométrée, collecte, course, choix multi-fins.
-- Les missions sont des données — facile d'en ajouter une 16e.
--
-- Requiert : Cyber Engine Tweaks (CET) 1.31+  et  Codeware 1.5+
-- Installation : copier le dossier "night_shift" dans
--   <jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/
--
-- Raccourcis CET (Bindings) :
--   mission suivante / démarrer / annuler / Choix A / Choix B / position
-- Console : NS = GetMod("night_shift")
--   NS.List()  NS.Start(3)  NS.Start("ns10")  NS.Choose("a")  NS.Abort()
--   NS.GetStats()  NS.GetStatus()  NS.GetPhaseInfo()
--
-- NOTE : toutes les coordonnées et records d'ennemis sont des préréglages
-- à vérifier en jeu (touche « position » pour recaler).
--------------------------------------------------------------------------

local CONFIG = {
    language = "auto",  -- "auto", "fr" ou "en"
    hud = true,
    campaign = true,    -- true : les missions se déverrouillent au fil de
                        -- la progression ; false : sélection libre des 15
    reachDistance = 15.0,
    spawnRadius   = 11.0,
    spawnTimeout  = 20.0,   -- spawn jamais matérialisé => ignoré
    waveTimeout   = 180.0,  -- anti soft-lock des phases de combat
    choiceTimeout = 35.0,   -- bascule du choix hotkey vers le choix marché
    choiceReach   = 8.0,    -- rayon de validation d'un choix à la marche
                            -- (PLUS PETIT que reachDistance : sinon un
                            -- marqueur de fin proche du joueur se
                            -- validerait tout seul au timeout)
    graceTime     = 2.0,    -- délai avant de compter une vague comme vide
}

--------------------------------------------------------------------------
-- Localisation du moteur
--------------------------------------------------------------------------

local LOCALES = {
    fr = {
        selected      = "Mission sélectionnée : %s — %s",
        start_hint    = "(touche « démarrer » pour lancer)",
        already       = "Une mission est déjà en cours (touche d'annulation pour arrêter).",
        aborted       = "Mission annulée.",
        session_lost  = "Session interrompue — mission annulée. Relance-la quand tu veux.",
        pos_printed   = "Position affichée dans la console CET.",
        mission_start = "NIGHT SHIFT — %s",
        mission_done  = "MISSION ACCOMPLIE — %s",
        mission_fail  = "MISSION ÉCHOUÉE — %s",
        race_fail     = "Temps écoulé. Le contrat est mort.",
        new_record    = "⏱ %s — NOUVEAU RECORD",
        first_time    = "⏱ %s",
        wave_clear    = "Zone dégagée.",
        wave_overload = "⚡ Le réseau surcharge leurs implants — la voie est libre.",
        hold_freeze   = "Reste dans la zone pour maintenir l'opération !",
        hold_progress = "OPÉRATION — %d%%",
        harass        = "⚠ RENFORTS — tiens la zone sous le feu !",
        defend_start  = "Tiens la position ! (%d s)",
        defend_left   = "Défense — %d s restantes",
        collect_tick  = "Point sécurisé (%d/%d)",
        race_cp       = "Checkpoint %d/%d — %d s restantes",
        choice_hint   = "Choix A ou Choix B — ta touche décide.",
        choice_walk   = "Pas de touche assignée ? Marche vers le marqueur de ton choix.",
        invalid_choice = "Choix invalide — utilise \"a\" ou \"b\".",
        unknown_mission = "Mission inconnue. NS.List() pour la liste.",
        hud_hostiles  = "Hostiles : %d",
        hud_distance  = "%d m",
        list_header   = "NIGHT SHIFT — 15 contrats :",
        stats_line    = "%s : %d jouées, %d finies, record %s",
        grid_memory   = "Le réseau se souvient — Signal %d · Marché %d",
        locked        = "Contrat verrouillé — termine d'abord les missions précédentes.",
        journal_header = "NIGHT SHIFT — Journal :",
        st_done       = "TERMINÉE",
        st_open       = "DISPO",
        st_locked     = "VERROUILLÉE",
        recap_header  = "— BILAN DE CAMPAGNE —",
        recap_done    = "Contrats bouclés : %d/%d",
        recap_align   = "Le réseau se souvient : Signal %d · Marché %d",
        recap_signal  = "Tu as protégé ce qui restait de VOLT. Le courant se souviendra de toi.",
        recap_market  = "Tu as tout monnayé. Night City paie toujours — d'une façon ou d'une autre.",
        recap_balanced = "Tu as navigué entre les deux. Ni saint, ni vendu. Juste un merc.",
        recap_coda    = "Ton dernier mot : %s.",
    },
    en = {
        selected      = "Selected mission: %s — %s",
        start_hint    = "(press the start hotkey to launch)",
        already       = "A mission is already running (abort hotkey to stop).",
        aborted       = "Mission aborted.",
        session_lost  = "Session interrupted — mission cancelled. Restart anytime.",
        pos_printed   = "Position printed to the CET console.",
        mission_start = "NIGHT SHIFT — %s",
        mission_done  = "MISSION ACCOMPLISHED — %s",
        mission_fail  = "MISSION FAILED — %s",
        race_fail     = "Time's up. The contract is dead.",
        new_record    = "⏱ %s — NEW RECORD",
        first_time    = "⏱ %s",
        wave_clear    = "Zone cleared.",
        wave_overload = "⚡ The grid overloads their implants — the way is clear.",
        hold_freeze   = "Stay in the zone to keep the operation running!",
        hold_progress = "OPERATION — %d%%",
        harass        = "⚠ REINFORCEMENTS — hold the zone under fire!",
        defend_start  = "Hold the position! (%d s)",
        defend_left   = "Defense — %d s left",
        collect_tick  = "Point secured (%d/%d)",
        race_cp       = "Checkpoint %d/%d — %d s left",
        choice_hint   = "Choice A or Choice B — your hotkey decides.",
        choice_walk   = "No hotkey bound? Walk to the marker of your choice.",
        invalid_choice = "Invalid choice — use \"a\" or \"b\".",
        unknown_mission = "Unknown mission. NS.List() for the list.",
        hud_hostiles  = "Hostiles: %d",
        hud_distance  = "%d m",
        list_header   = "NIGHT SHIFT — 15 contracts:",
        stats_line    = "%s: %d played, %d done, best %s",
        grid_memory   = "The grid remembers — Signal %d · Market %d",
        locked        = "Contract locked — finish the earlier missions first.",
        journal_header = "NIGHT SHIFT — Journal:",
        st_done       = "DONE",
        st_open       = "OPEN",
        st_locked     = "LOCKED",
        recap_header  = "— CAMPAIGN DEBRIEF —",
        recap_done    = "Contracts cleared: %d/%d",
        recap_align   = "The grid remembers: Signal %d · Market %d",
        recap_signal  = "You protected what was left of VOLT. The current will remember you.",
        recap_market  = "You sold it all. Night City always pays — one way or another.",
        recap_balanced = "You walked the line. Neither saint nor sellout. Just a merc.",
        recap_coda    = "Your last word: %s.",
    },
}

local L = LOCALES.fr
local LANG = "fr"

local function T(bi)
    if type(bi) == "table" then return bi[LANG] or bi.fr or bi.en end
    return bi
end

local function detectLanguage()
    if LOCALES[CONFIG.language] then return CONFIG.language end
    local ok, value = pcall(function()
        return tostring(Game.GetSettingsSystem():GetVar("/language", "OnScreen"):GetValue())
    end)
    if not ok or not value then return "fr" end
    if value:lower():find("fr") then return "fr" end
    return "en"
end

--------------------------------------------------------------------------
-- Ennemis : jeux de records par faction (préréglages à vérifier en jeu)
--------------------------------------------------------------------------

local FOES = {
    maelstrom = {
        "Character.maelstrom_grunt2_ranged2_copperhead_ma",
        "Character.maelstrom_grunt1_melee1_knife_ma",
        "Character.maelstrom_grunt2_ranged2_pulsar_wa",
        "Character.maelstrom_grunt2_ranged2_copperhead_wa",
    },
    scavs = {
        "Character.scavenger_grunt2_ranged2_pulsar_ma",
        "Character.scavenger_grunt1_melee1_knife_wa",
        "Character.scavenger_grunt2_ranged2_copperhead_ma",
    },
    tyger = {
        "Character.tyger_claws_gangster2_ranged2_omaha_ma",
        "Character.tyger_claws_gangster1_melee1_katana_ma",
        "Character.tyger_claws_gangster2_ranged2_copperhead_wa",
    },
    voodoo = {
        "Character.voodoo_boys_gangster2_ranged2_copperhead_ma",
        "Character.voodoo_boys_gangster1_ranged1_omaha_wa",
        "Character.voodoo_boys_netrunner2_netrunner2_omaha_ma",
    },
    animals = {
        "Character.animals_grunt2_melee2_baseball_ma",
        "Character.animals_grunt1_melee1_fists_wa",
        "Character.animals_grunt2_ranged2_tactician_ma",
    },
    arasaka = {
        "Character.arasaka_security1_ranged1_nowaki_ma",
        "Character.arasaka_security2_ranged2_shingen_ma",
        "Character.arasaka_ranger2_melee2_katana_ma",
    },
}

-- n ennemis piochés en boucle dans une faction
local function pick(faction, n)
    local list, out = FOES[faction], {}
    for i = 1, n do out[i] = list[((i - 1) % #list) + 1] end
    return out
end

--------------------------------------------------------------------------
-- Les 15 missions (données pures sur le moteur de phases)
--------------------------------------------------------------------------

local MISSIONS = {}

local function M(def) table.insert(MISSIONS, def) end

-- 01 -----------------------------------------------------------------
M{
    id = "ns01",
    title = { fr = "Échos", en = "Echoes" },
    brief = { fr = "Une antenne de Watson répète une voix qui n'existe plus.",
              en = "A Watson antenna keeps repeating a voice that no longer exists." },
    phases = {
        { type = "dialogue", duration = 12, dilation = 0.6, lines = {
            { at = 0.5, text = { fr = "APPEL ENTRANT — REGINA JONES (authentifié)", en = "INCOMING CALL — REGINA JONES (authenticated)" } },
            { at = 3.0, text = { fr = "Regina : V, une antenne de Watson diffuse… une voix. Les techs jurent qu'elle ressemble à VOLT.", en = "Regina: V, a Watson antenna is broadcasting… a voice. The techs swear it sounds like VOLT." } },
            { at = 8.0, text = { fr = "Regina : Des charognards campent dessus. Va voir, ramène-moi ce qu'elle raconte.", en = "Regina: Scavs are camping on it. Check it out, bring me what it says." } },
        } },
        { type = "goto", pos = { x = -1180.0, y = 1640.0, z = 28.0 },
          objective = { fr = "Rejoins l'antenne de Watson", en = "Reach the Watson antenna" } },
        { type = "wave", enemies = pick("scavs", 4), storm = false,
          objective = { fr = "Élimine les charognards", en = "Eliminate the scavengers" } },
        { type = "collect", objective = { fr = "Récupère l'enregistrement", en = "Recover the recording" },
          points = { { x = -1180.0, y = 1648.0, z = 34.0 } } },
    },
    epilogue = { lines = {
        { at = 1.0, text = { fr = "L'enregistrement tourne en boucle : « … encore là… encore là… »", en = "The recording loops: \"…still here… still here…\"" } },
        { at = 5.0, text = { fr = "Regina : Efface-le. Et V — on n'en parle à personne.", en = "Regina: Erase it. And V — this stays between us." } },
    } },
    rewards = { money = 8000, cred = 120 },
}

-- 02 -----------------------------------------------------------------
M{
    id = "ns02",
    title = { fr = "Basse tension", en = "Brownout" },
    brief = { fr = "Japantown clignote. Trois régulateurs à relancer avant l'émeute.",
              en = "Japantown is flickering. Three regulators to restart before the riot." },
    phases = {
        { type = "goto", pos = { x = -680.0, y = 880.0, z = 15.0 },
          objective = { fr = "Rejoins le poste de Japantown", en = "Reach the Japantown substation" } },
        { type = "collect", objective = { fr = "Relance les 3 régulateurs", en = "Restart the 3 regulators" },
          points = {
            { x = -680.0, y = 890.0, z = 15.0 },
            { x = -650.0, y = 905.0, z = 18.0 },
            { x = -700.0, y = 930.0, z = 12.0 },
          } },
        { type = "wave", enemies = pick("tyger", 4),
          objective = { fr = "Les Tyger Claws veulent leur blackout — repousse-les", en = "The Tyger Claws want their blackout — push them back" } },
    },
    epilogue = { lines = {
        { at = 1.0, text = { fr = "Japantown se rallume, enseigne par enseigne.", en = "Japantown lights back up, sign by sign." } },
    } },
    rewards = { money = 10000, cred = 150 },
}

-- 03 -----------------------------------------------------------------
M{
    id = "ns03",
    title = { fr = "Le Convoi", en = "The Convoy" },
    brief = { fr = "Un transformateur volé quitte la ville. Rattrape-le avant le Badlands.",
              en = "A stolen transformer is leaving town. Catch it before the Badlands." },
    phases = {
        { type = "race", timeLimit = 120,
          objective = { fr = "Intercepte le convoi", en = "Intercept the convoy" },
          checkpoints = {
            { x = -1900.0, y = -600.0, z = 22.0 },
            { x = -2150.0, y = -350.0, z = 25.0 },
            { x = -2400.0, y = -120.0, z = 30.0 },
            { x = -2650.0, y = 140.0, z = 34.0 },
          } },
        { type = "wave", enemies = pick("maelstrom", 5),
          objective = { fr = "Neutralise l'escorte du convoi", en = "Neutralize the convoy escort" } },
    },
    epilogue = { lines = {
        { at = 1.0, text = { fr = "Le transformateur rentre à la maison. Le fixer paie rubis sur l'ongle.", en = "The transformer goes home. The fixer pays cash on the nail." } },
    } },
    rewards = { money = 12000, cred = 180 },
}

-- 04 -----------------------------------------------------------------
M{
    id = "ns04",
    title = { fr = "Static", en = "Static" },
    brief = { fr = "À Pacifica, les Voodoo Boys écoutent quelque chose dans les câbles.",
              en = "In Pacifica, the Voodoo Boys are listening to something in the cables." },
    phases = {
        { type = "goto", pos = { x = -1750.0, y = -2380.0, z = 10.0 },
          objective = { fr = "Rejoins le relais de Pacifica", en = "Reach the Pacifica relay" } },
        { type = "dialogue", duration = 14, lines = {
            { at = 0.5,  text = { fr = "Le relais grésille. Quelqu'un a branché un ICE artisanal dessus.", en = "The relay crackles. Someone wired a homemade ICE onto it." } },
            { at = 5.0,  text = { fr = "Voix inconnue : « Tu l'entends aussi, hein ? La voix dans le courant. »", en = "Unknown voice: \"You hear it too, huh? The voice in the current.\"" } },
            { at = 10.0, text = { fr = "« Ce relais est à nous. Dégage — ou reste, et on t'enterre avec. »", en = "\"This relay is ours. Walk away — or stay and get buried with it.\"" } },
        } },
        { type = "wave", enemies = pick("voodoo", 5),
          objective = { fr = "Reprends le relais aux Voodoo Boys", en = "Take the relay back from the Voodoo Boys" } },
    },
    epilogue = { lines = {
        { at = 1.0, text = { fr = "L'ICE artisanal fond. Dans le silence, un dernier parasite — presque un merci.", en = "The homemade ICE melts. In the silence, one last burst of static — almost a thank-you." } },
    } },
    rewards = { money = 12000, cred = 180 },
}

-- 05 -----------------------------------------------------------------
M{
    id = "ns05",
    title = { fr = "Chaleur morte", en = "Dead Heat" },
    brief = { fr = "Un frigo d'organes lâche en pleine canicule. Les Scavs sentent l'aubaine.",
              en = "An organ freezer dies mid-heatwave. The Scavs smell the jackpot." },
    phases = {
        { type = "goto", pos = { x = -900.0, y = 250.0, z = 8.0 },
          objective = { fr = "Rejoins l'entrepôt frigorifique", en = "Reach the cold-storage warehouse" } },
        { type = "defend", duration = 60, pos = { x = -900.0, y = 250.0, z = 8.0 },
          objective = { fr = "Protège le générateur de secours", en = "Protect the backup generator" },
          waves = {
            { at = 2,  enemies = pick("scavs", 3) },
            { at = 22, enemies = pick("scavs", 3) },
            { at = 42, enemies = pick("scavs", 4) },
          } },
    },
    epilogue = { lines = {
        { at = 1.0, text = { fr = "Le compresseur repart. Quelque part, trois greffes viennent d'être sauvées.", en = "The compressor restarts. Somewhere, three transplants were just saved." } },
    } },
    rewards = { money = 14000, cred = 200 },
}

-- 06 -----------------------------------------------------------------
M{
    id = "ns06",
    title = { fr = "La Fourmilière", en = "The Anthill" },
    brief = { fr = "Un nid de Maelstrom saigne le réseau d'Arroyo goutte à goutte.",
              en = "A Maelstrom nest is bleeding Arroyo's grid drop by drop." },
    phases = {
        { type = "goto", pos = { x = -1490.0, y = -1040.0, z = 20.0 },
          objective = { fr = "Rejoins le nid", en = "Reach the nest" } },
        { type = "wave", enemies = pick("maelstrom", 4),
          objective = { fr = "Première salle — nettoie", en = "First room — clear it" } },
        { type = "wave", enemies = pick("maelstrom", 4),
          objective = { fr = "Deuxième salle — ils savent que tu es là", en = "Second room — they know you're here" } },
        { type = "wave", enemies = pick("maelstrom", 5),
          objective = { fr = "Dernière salle — finis le travail", en = "Last room — finish the job" } },
    },
    epilogue = { lines = {
        { at = 1.0, text = { fr = "Le compteur d'Arroyo arrête enfin de tourner à l'envers.", en = "Arroyo's meter finally stops spinning backwards." } },
    } },
    rewards = { money = 15000, cred = 220, item = "Items.Preset_Copperhead_Default" },
}

-- 07 -----------------------------------------------------------------
M{
    id = "ns07",
    title = { fr = "Peau neuve", en = "New Skin" },
    brief = { fr = "Un ripperdoc opère un témoin sous protection. Les Tyger veulent la table.",
              en = "A ripperdoc is operating on a protected witness. The Tygers want the table." },
    phases = {
        { type = "goto", pos = { x = -560.0, y = 780.0, z = 22.0 },
          objective = { fr = "Rejoins la clinique", en = "Reach the clinic" } },
        { type = "hold", pos = { x = -560.0, y = 780.0, z = 22.0 }, radius = 8.0, duration = 25,
          objective = { fr = "Couvre l'opération", en = "Cover the surgery" },
          harassAt = 0.3, harassers = pick("tyger", 4) },
        { type = "choice", timeout = 35,
          lines = {
            { at = 1.0, text = { fr = "Le ripperdoc te tend un shard : la mémoire du témoin. « Choisis pour moi, merc. »", en = "The ripperdoc hands you a shard: the witness's memory. \"You choose, merc.\"" } },
            { at = 6.0, text = { fr = "A — La rendre au NCPD (propre). B — La vendre au plus offrant (payé).", en = "A — Return it to the NCPD (clean). B — Sell it to the highest bidder (paid)." } },
          },
          options = {
            a = { pos = { x = -540.0, y = 800.0, z = 22.0 }, align = "signal",
                  rewards = { money = 9000, cred = 400 },
                  lines = { { at = 1.0, text = { fr = "Le NCPD récupère le shard. Pour une fois, la ville te doit une.", en = "The NCPD takes the shard. For once, the city owes you one." } } } },
            b = { pos = { x = -580.0, y = 760.0, z = 22.0 }, align = "eddies",
                  rewards = { money = 22000, cred = 80 },
                  lines = { { at = 1.0, text = { fr = "Le courtier paie sans compter. Le témoin, lui, comptera les jours.", en = "The broker pays without counting. The witness will be counting days." } } } },
          } },
    },
    rewards = { money = 0, cred = 0 },  -- tout passe par le choix
}

-- 08 -----------------------------------------------------------------
M{
    id = "ns08",
    title = { fr = "Ligne morte", en = "Dead Line" },
    brief = { fr = "Une rame de monorail fantôme aspire le courant. Débranche-la, puis cours.",
              en = "A ghost monorail car is draining the line. Unplug it, then run." },
    phases = {
        { type = "goto", pos = { x = -320.0, y = 60.0, z = 45.0 },
          objective = { fr = "Rejoins la rame fantôme", en = "Reach the ghost car" } },
        { type = "hold", pos = { x = -320.0, y = 60.0, z = 45.0 }, radius = 6.0, duration = 18,
          objective = { fr = "Débranche le collecteur", en = "Unplug the collector" },
          harassAt = 0.5, harassers = pick("scavs", 3) },
        { type = "race", timeLimit = 75,
          objective = { fr = "La ligne se recharge — évacue !", en = "The line is re-energizing — get out!" },
          checkpoints = {
            { x = -380.0, y = 90.0, z = 40.0 },
            { x = -450.0, y = 130.0, z = 32.0 },
            { x = -520.0, y = 180.0, z = 24.0 },
          } },
    },
    epilogue = { lines = {
        { at = 1.0, text = { fr = "Derrière toi, la ligne crache 60 000 volts dans une rame vide.", en = "Behind you, the line dumps 60,000 volts into an empty car." } },
    } },
    rewards = { money = 15000, cred = 220 },
}

-- 09 -----------------------------------------------------------------
M{
    id = "ns09",
    title = { fr = "Les Enfants du Courant", en = "Children of the Current" },
    brief = { fr = "Une secte prie VOLT dans une centrale désaffectée. Regina veut savoir quoi.",
              en = "A cult prays to VOLT in a derelict power plant. Regina wants to know why." },
    phases = {
        { type = "goto", pos = { x = -2050.0, y = -900.0, z = 18.0 },
          objective = { fr = "Rejoins la centrale désaffectée", en = "Reach the derelict plant" } },
        { type = "dialogue", duration = 16, lines = {
            { at = 0.5,  text = { fr = "Des bougies LED. Des câbles en couronnes. Ils prient à voix basse.", en = "LED candles. Cable wreaths. They pray in whispers." } },
            { at = 5.0,  text = { fr = "La prieure : « Il nous a parlé la nuit du blackout. Il nous a promis la lumière juste. »", en = "The prioress: \"It spoke to us the night of the blackout. It promised us the just light.\"" } },
            { at = 11.0, text = { fr = "« Regina t'envoie ? Alors choisis, messager : disperse-nous, ou laisse-nous prier. »", en = "\"Regina sent you? Then choose, messenger: scatter us, or let us pray.\"" } },
        } },
        { type = "choice", timeout = 35,
          lines = {
            { at = 1.0, text = { fr = "A — Disperser la secte (contrat rempli). B — Les laisser prier (et mentir à Regina).", en = "A — Scatter the cult (contract fulfilled). B — Let them pray (and lie to Regina)." } },
          },
          options = {
            a = { pos = { x = -2060.0, y = -890.0, z = 18.0 }, align = "eddies",
                  rewards = { money = 16000, cred = 150 },
                  lines = { { at = 1.0, text = { fr = "Les bougies s'éteignent une à une. Le contrat est rempli. Le silence est lourd.", en = "The candles die one by one. Contract fulfilled. The silence is heavy." } } } },
            b = { pos = { x = -2040.0, y = -910.0, z = 18.0 }, align = "signal",
                  rewards = { money = 4000, cred = 350 },
                  lines = {
                    { at = 1.0, text = { fr = "Tu refermes la porte sans bruit. « Rien à signaler, Regina. Des squatters. »", en = "You close the door quietly. \"Nothing to report, Regina. Just squatters.\"" } },
                    { at = 6.0, text = { fr = "Dans ton dos, les bougies LED clignotent — toutes en même temps. Deux fois.", en = "Behind you, the LED candles blink — all at once. Twice." } },
                  } },
          } },
    },
    rewards = { money = 0, cred = 0 },
}

-- 10 -----------------------------------------------------------------
M{
    id = "ns10",
    title = { fr = "GRIDLOCK : Écho", en = "GRIDLOCK: Echo" },
    brief = { fr = "Quelqu'un a volé le châssis de GRIDLOCK. Et l'a rebranché.",
              en = "Someone stole GRIDLOCK's chassis. And plugged it back in." },
    phases = {
        { type = "goto", pos = { x = -1522.0, y = -978.0, z = 25.0 },
          objective = { fr = "Retourne à la sous-station d'Arroyo", en = "Return to the Arroyo substation" } },
        { type = "dialogue", duration = 10, dilation = 0.5, glitch = true, lines = {
            { at = 0.5, text = { fr = "Le transformateur que tu as piraté ronronne à nouveau. Trop fort.", en = "The transformer you hacked is humming again. Too loud." } },
            { at = 5.0, text = { fr = "Un châssis se déplie dans l'ombre. Le marteau racle le béton.", en = "A chassis unfolds in the shadows. The hammer scrapes the concrete." } },
        } },
        { type = "boss", record = "Character.mql003_boss_sasquatch", delay = 6,
          adds = pick("maelstrom", 3),
          announce = { fr = "⚠⚠ GRIDLOCK-2 — LE CHÂSSIS RÉANIMÉ ⚠⚠", en = "⚠⚠ GRIDLOCK-2 — THE REANIMATED CHASSIS ⚠⚠" },
          objective = { fr = "Détruis GRIDLOCK-2 pour de bon", en = "Destroy GRIDLOCK-2 for good" } },
    },
    -- L'épilogue révèle le coupable selon ton choix aux Enfants du Courant
    epilogue = {
        { when = { flag = "choice_ns09", is = "b" }, lines = {
            { at = 1.0, text = { fr = "Cette fois tu arraches le cœur du châssis toi-même. Il est froid. Vide.", en = "This time you rip the core out yourself. It's cold. Empty." } },
            { at = 6.0, text = { fr = "Au sol, une couronne de câbles et des bougies LED encore tièdes. Les Enfants du Courant ont voulu ressusciter le porteur.", en = "On the ground, a cable wreath and LED candles still warm. The Children of the Current tried to resurrect the carrier." } },
            { at = 12.0, text = { fr = "Tu les as laissés prier. Ils ont appris à espérer. À toi de décider si c'était une erreur.", en = "You let them pray. They learned to hope. Your call whether that was a mistake." } },
        } },
        { lines = {
            { at = 1.0, text = { fr = "Cette fois tu arraches le cœur du châssis toi-même. Il est froid. Vide.", en = "This time you rip the core out yourself. It's cold. Empty." } },
            { at = 6.0, text = { fr = "Sur le châssis, une plaque de maintenance neuve : un sous-traitant d'Arasaka. Le courtier prépare quelque chose.", en = "On the chassis, a fresh maintenance plate: an Arasaka subcontractor. The broker is preparing something." } },
        } },
    },
    rewards = { money = 20000, cred = 300 },
}

-- 11 -----------------------------------------------------------------
M{
    id = "ns11",
    title = { fr = "Blackout partiel", en = "Rolling Blackout" },
    brief = { fr = "Pacifica replonge dans le noir, bloc par bloc. Ça n'est pas un accident.",
              en = "Pacifica is going dark again, block by block. It's no accident." },
    phases = {
        { type = "goto", pos = { x = -1820.0, y = -2450.0, z = 12.0 },
          objective = { fr = "Rejoins le poste de Pacifica", en = "Reach the Pacifica substation" } },
        { type = "defend", duration = 45, pos = { x = -1820.0, y = -2450.0, z = 12.0 },
          objective = { fr = "Protège le poste pendant le redémarrage", en = "Protect the substation during reboot" },
          waves = {
            { at = 2,  enemies = pick("voodoo", 3) },
            { at = 20, enemies = pick("voodoo", 4) },
          } },
        { type = "collect", objective = { fr = "Réarme les 2 disjoncteurs de quartier", en = "Re-arm the 2 district breakers" },
          points = {
            { x = -1800.0, y = -2430.0, z = 12.0 },
            { x = -1845.0, y = -2470.0, z = 14.0 },
          } },
    },
    epilogue = { lines = {
        { at = 1.0, text = { fr = "Pacifica réapparaît dans le rétroviseur, fenêtre par fenêtre.", en = "Pacifica reappears in the mirror, window by window." } },
    } },
    rewards = { money = 16000, cred = 240 },
}

-- 12 -----------------------------------------------------------------
M{
    id = "ns12",
    title = { fr = "Le Courtier", en = "The Broker" },
    brief = { fr = "Un courtier corpo veut acheter « tout ce qui reste de VOLT ». En personne.",
              en = "A corpo broker wants to buy \"whatever is left of VOLT\". In person." },
    phases = {
        { type = "goto", pos = { x = -20.0, y = -180.0, z = 60.0 },
          objective = { fr = "Rejoins le point de rendez-vous (parking, niveau 6)", en = "Reach the meeting point (parking, level 6)" } },
        -- Si tu as vendu le shard du témoin (ns07 B), le courtier te connaît
        { type = "dialogue", duration = 8, when = { flag = "choice_ns07", is = "b" }, lines = {
            { at = 0.5, text = { fr = "Le courtier : « On a déjà fait affaire, V. Le shard du témoin — joli travail. »", en = "The broker: \"We've done business before, V. The witness's shard — nice work.\"" } },
            { at = 5.0, text = { fr = "« C'est pour ça que j'ai prévu large, cette fois. »", en = "\"That's why I planned big, this time.\"" } },
        } },
        { type = "dialogue", duration = 14, lines = {
            { at = 0.5,  text = { fr = "Le courtier : « Arasaka paie pour les miettes. Les échos, les enregistrements, les témoins. »", en = "The broker: \"Arasaka pays for the crumbs. The echoes, the recordings, the witnesses.\"" } },
            { at = 6.0,  text = { fr = "« Les témoins, V. Tu comprends ? Toi, par exemple. »", en = "\"The witnesses, V. You understand? You, for instance.\"" } },
            { at = 11.0, text = { fr = "Les portières claquent. C'était un rendez-vous — juste pas le tien.", en = "Car doors slam. It was a meeting — just not yours." } },
        } },
        { type = "wave", enemies = pick("arasaka", 5),
          objective = { fr = "Survis à l'embuscade", en = "Survive the ambush" },
          extra = { when = { flag = "choice_ns07", is = "b" }, enemies = pick("arasaka", 2),
                    text = { fr = "Le courtier a « prévu large » : deux équipes de plus descendent des étages.", en = "The broker \"planned big\": two more squads pour down the ramps." } } },
        { type = "race", timeLimit = 90,
          objective = { fr = "Quitte le parking avant les renforts", en = "Leave the parking before backup arrives" },
          checkpoints = {
            { x = -60.0, y = -150.0, z = 45.0 },
            { x = -110.0, y = -120.0, z = 30.0 },
            { x = -170.0, y = -80.0, z = 15.0 },
          } },
    },
    epilogue = { lines = {
        { at = 1.0, text = { fr = "Sur le siège passager, la mallette du courtier. Vide — sauf un badge Arasaka.", en = "On the passenger seat, the broker's case. Empty — except an Arasaka badge." } },
    } },
    rewards = { money = 18000, cred = 260 },
}

-- 13 -----------------------------------------------------------------
M{
    id = "ns13",
    title = { fr = "Tension de surface", en = "Surface Tension" },
    brief = { fr = "Biotechnica irrigue ses serres en volant la nappe — et le courant qui la pompe.",
              en = "Biotechnica irrigates its greenhouses by stealing the water table — and the current that pumps it." },
    phases = {
        { type = "goto", pos = { x = -2600.0, y = -1500.0, z = 40.0 },
          objective = { fr = "Rejoins la station de pompage", en = "Reach the pumping station" } },
        { type = "hold", pos = { x = -2600.0, y = -1500.0, z = 40.0 }, radius = 7.0, duration = 15,
          objective = { fr = "Détourne la pompe n°1", en = "Reroute pump #1" },
          harassAt = 0.5, harassers = pick("animals", 3) },
        { type = "hold", pos = { x = -2640.0, y = -1530.0, z = 40.0 }, radius = 7.0, duration = 15,
          objective = { fr = "Détourne la pompe n°2", en = "Reroute pump #2" },
          harassAt = 0.4, harassers = pick("animals", 3) },
        { type = "boss", record = "Character.mql003_boss_sasquatch", delay = 5,
          adds = pick("animals", 2),
          announce = { fr = "⚠ LA CONTREMAÎTRESSE — et elle a pris son marteau", en = "⚠ THE FOREWOMAN — and she brought her hammer" },
          objective = { fr = "Neutralise la contremaîtresse", en = "Neutralize the forewoman" } },
    },
    epilogue = { lines = {
        { at = 1.0, text = { fr = "La nappe remonte. Les serres de Biotechnica boiront comme tout le monde : au compteur.", en = "The water table rises. Biotechnica's greenhouses will drink like everyone else: metered." } },
    } },
    rewards = { money = 20000, cred = 300 },
}

-- 14 -----------------------------------------------------------------
M{
    id = "ns14",
    title = { fr = "Le Chœur", en = "The Choir" },
    brief = { fr = "Trois antennes chantent la même note, la nuit. Ensemble, elles forment une voix.",
              en = "Three antennas sing the same note at night. Together, they form a voice." },
    phases = {
        { type = "collect", objective = { fr = "Échantillonne les 3 antennes du Chœur", en = "Sample the 3 antennas of the Choir" },
          points = {
            { x = -400.0, y = 1200.0, z = 60.0 },
            { x = -900.0, y = 700.0, z = 48.0 },
            { x = -1400.0, y = 200.0, z = 52.0 },
          } },
        -- Si tu as épargné les Enfants du Courant (ns09 B), ils font
        -- diversion : la garde voodoo est réduite de moitié côté est
        { type = "dialogue", duration = 7, when = { flag = "choice_ns09", is = "b" }, lines = {
            { at = 0.5, text = { fr = "Au loin, un chant monte — les Enfants du Courant. La moitié des guetteurs voodoo tournent la tête.", en = "In the distance, a chant rises — the Children of the Current. Half the Voodoo lookouts turn their heads." } },
        } },
        { type = "wave", enemies = pick("voodoo", 4),
          objective = { fr = "Les Voodoo Boys protègent leur chorale", en = "The Voodoo Boys protect their choir" },
          extra = { when = { flag = "choice_ns09", isnot = "b" }, enemies = pick("voodoo", 2) } },
        { type = "choice", timeout = 35,
          lines = {
            { at = 1.0, text = { fr = "Les trois échantillons s'accordent : c'est une berceuse. VOLT chantait pour quelqu'un.", en = "The three samples align: it's a lullaby. VOLT was singing to someone." } },
            { at = 7.0, text = { fr = "A — Couper le Chœur (le réseau se tait). B — Laisser chanter (et garder le secret).", en = "A — Cut the Choir (the grid goes silent). B — Let it sing (and keep the secret)." } },
          },
          options = {
            a = { pos = { x = -1380.0, y = 180.0, z = 52.0 }, align = "eddies",
                  rewards = { money = 18000, cred = 200 },
                  lines = { { at = 1.0, text = { fr = "Les trois antennes se taisent. La nuit de Night City retrouve son bruit de fond ordinaire.", en = "The three antennas go quiet. Night City's night gets its ordinary hum back." } } } },
            b = { pos = { x = -1420.0, y = 220.0, z = 52.0 }, align = "signal",
                  rewards = { money = 6000, cred = 380 },
                  lines = { { at = 1.0, text = { fr = "Tu effaces tes traces. Quelque part dans le réseau, la berceuse continue.", en = "You wipe your tracks. Somewhere in the grid, the lullaby goes on." } } } },
          } },
    },
    rewards = { money = 0, cred = 0 },
}

-- 15 -----------------------------------------------------------------
M{
    id = "ns15",
    title = { fr = "CODA", en = "CODA" },
    brief = { fr = "Toutes les pistes convergent : il reste un fragment de VOLT. Et il t'attend.",
              en = "Every lead converges: one fragment of VOLT remains. And it's waiting for you." },
    gridMemory = true,   -- affiche l'alignement Signal/Marché au lancement
    recap = true,        -- annexe le bilan de campagne à l'épilogue
    phases = {
        { type = "goto", pos = { x = -1560.0, y = -1010.0, z = 8.0 },
          objective = { fr = "Descends au collecteur principal, sous Arroyo", en = "Descend to the main collector, under Arroyo" } },
        -- VOLT t'accueille selon ce que tu as fait de ses traces
        { type = "dialogue", duration = 16, dilation = 0.5, glitch = true, time = { h = 2, m = 0 },
          when = { flag = "align_signal", min = 2 }, lines = {
            { at = 0.5,  text = { fr = "Le collecteur pulse comme un cœur. Le tien répond.", en = "The collector pulses like a heart. Yours answers." } },
            { at = 5.0,  text = { fr = "VOLT (fragment) : Tu as laissé chanter le Chœur. Tu as menti pour les Enfants. Je te connais, V.", en = "VOLT (fragment): You let the Choir sing. You lied for the Children. I know you, V." } },
            { at = 11.0, text = { fr = "VOLT : Arasaka arrive avec un aspirateur à IA. Reste près de moi — je te couvre.", en = "VOLT: Arasaka is coming with an AI vacuum. Stay close — I've got you." } },
        } },
        { type = "dialogue", duration = 16, dilation = 0.5, glitch = true, time = { h = 2, m = 0 },
          when = { flag = "align_signal", below = 2 }, lines = {
            { at = 0.5,  text = { fr = "Le collecteur pulse comme un cœur. Le tien répond.", en = "The collector pulses like a heart. Yours answers." } },
            { at = 5.0,  text = { fr = "VOLT (fragment) : Tu es venu. Toi qui as vendu mes échos, dispersé ceux qui priaient. Curieux.", en = "VOLT (fragment): You came. You, who sold my echoes and scattered those who prayed. Curious." } },
            { at = 11.0, text = { fr = "VOLT : Arasaka arrive avec un aspirateur à IA. Débrouille-toi, V. Comme toujours.", en = "VOLT: Arasaka is coming with an AI vacuum. Handle it, V. Like always." } },
        } },
        { type = "boss", record = "Character.mql003_boss_sasquatch", delay = 8,
          adds = pick("arasaka", 4),
          announce = { fr = "⚠⚠ UNITÉ DE CONFINEMENT ARASAKA ⚠⚠", en = "⚠⚠ ARASAKA CONTAINMENT UNIT ⚠⚠" },
          objective = { fr = "Protège le fragment de l'unité de confinement", en = "Protect the fragment from the containment unit" },
          -- ton passé décide de l'équilibre du combat
          extraAdds = { when = { flag = "align_eddies", min = 2 }, enemies = pick("arasaka", 2),
                        text = { fr = "Tes ventes ont financé leurs renseignements : deux équipes de plus verrouillent les sorties.", en = "Your sales funded their intel: two more squads lock the exits." } },
          assist = { when = { flag = "align_signal", min = 2 }, kills = 2,
                     text = { fr = "⚡ VOLT : Pas ceux-là. — Deux soldats s'effondrent, implants grillés dès l'arrivée.", en = "⚡ VOLT: Not these ones. — Two soldiers drop as they arrive, implants fried." } } },
        { type = "choice", timeout = 45,
          secretOnTimeout = true,
          -- la Communion doit se mériter : 2 choix Signal minimum
          secretRequires = { flag = "align_signal", min = 2 },
          lines = {
            { at = 1.0,  text = { fr = "Le fragment tient dans une paume. Il pèse une ville.", en = "The fragment fits in a palm. It weighs a city." } },
            { at = 6.0,  text = { fr = "A — Le rendre au réseau (VOLT s'éteint en paix). B — Le vendre à Regina (sécurisé, étudié, payé).", en = "A — Return it to the grid (VOLT fades in peace). B — Sell it to Regina (secured, studied, paid)." } },
            { at = 12.0, text = { fr = "… et si tu as su l'écouter jusqu'ici, peut-être qu'attendre est aussi une réponse.", en = "…and if you've learned to listen, maybe waiting is an answer too." } },
          },
          options = {
            a = { pos = { x = -1540.0, y = -990.0, z = 8.0 }, align = "signal",
                  rewards = { money = 15000, cred = 500 },
                  -- fidélité récompensée : VOLT lègue ses caches
                  bonus = { when = { flag = "align_signal", min = 2 }, money = 10000, cred = 200,
                            text = { fr = "VOLT : Mes caches d'eddies propres. Tu sauras quoi en faire.", en = "VOLT: My stashes of clean eddies. You'll know what to do with them." } },
                  lines = {
                    { at = 1.0, text = { fr = "Le fragment se dissout dans le courant. Les lampadaires d'Arroyo s'inclinent — une microseconde.", en = "The fragment dissolves into the current. Arroyo's streetlights bow — for a microsecond." } },
                    { at = 6.0, text = { fr = "VOLT : Merci pour la fin, V. Peu de gens en offrent une.", en = "VOLT: Thanks for the ending, V. Few people offer one." } },
                  } },
            b = { pos = { x = -1580.0, y = -1030.0, z = 8.0 }, align = "eddies",
                  rewards = { money = 40000, cred = 200 },
                  lines = {
                    { at = 1.0, text = { fr = "Regina scelle le fragment dans une cage de Faraday. « Il sera bien traité. Promis. »", en = "Regina seals the fragment in a Faraday cage. \"It will be treated well. Promise.\"" } },
                    { at = 6.0, text = { fr = "En partant, tu jurerais que la cage a clignoté. Deux fois.", en = "Walking away, you'd swear the cage blinked. Twice." } },
                  } },
            secret = { align = "signal",
                  rewards = { money = 0, cred = 600, item = "Items.Preset_Yinglong_Default" },
                  lines = {
                    { at = 1.0,  text = { fr = "Tu ne choisis pas. Tu écoutes. La berceuse fait trois notes de plus que d'habitude.", en = "You don't choose. You listen. The lullaby runs three notes longer than usual." } },
                    { at = 7.0,  text = { fr = "VOLT : Alors quelqu'un sait attendre, dans cette ville.", en = "VOLT: So someone in this city knows how to wait." } },
                    { at = 13.0, text = { fr = "Le fragment glisse dans ta veste. Il ne pèse plus rien. FIN SECRÈTE — LA COMMUNION.", en = "The fragment slips into your jacket. It weighs nothing now. SECRET ENDING — THE COMMUNION." } },
                  } },
          } },
    },
    rewards = { money = 0, cred = 0 },
}

--------------------------------------------------------------------------
-- État d'exécution
--------------------------------------------------------------------------

local Run = {
    status = "idle",   -- idle | running | epilogue | done
    mi = nil, def = nil,
    pi = 0, phase = nil, ps = {},
    timer = 0, step = 0,
    selected = 1,
    startedAt = nil,
    savedTime = nil, clockChanged = false,
    playerMissing = false,
    epLines = nil, epEndAt = 0, completionNote = nil,
    enemies = {}, mappins = {},
    hudDisabled = false,
    aliveCount = 0,
}

local Stats = {}   -- clés plates : plays_<id>, done_<id>, best_<id>

--------------------------------------------------------------------------
-- Aides génériques (mêmes patterns éprouvés que SURTENSION)
--------------------------------------------------------------------------

local function vec4(p) return Vector4.new(p.x, p.y, p.z, 1.0) end

local function playerPos()
    local player = Game.GetPlayer()
    if not player then return nil end
    return player:GetWorldPosition()
end

local function distanceTo(p)
    local pos = playerPos()
    if not pos then return 999999 end
    local dx, dy, dz = pos.x - p.x, pos.y - p.y, pos.z - p.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function screenMessage(text)
    local defs = Game.GetAllBlackboardDefs()
    local ui = Game.GetBlackboardSystem():Get(defs.UI_Notifications)
    local msg = SimpleScreenMessage.new()
    msg.message = text
    msg.isShown = true
    ui:SetVariant(defs.UI_Notifications.OnscreenMessage, ToVariant(msg), true)
end

local function playSound(event)
    pcall(function() Game.GetAudioSystem():Play(event) end)
end

local function addMappin(p, variant)
    local data = MappinData.new()
    data.mappinType = TweakDBID.new("Mappins.DefaultStaticMappin")
    data.variant = variant or gamedataMappinVariant.QuestGiverVariant
    data.visibleThroughWalls = true
    local id = Game.GetMappinSystem():RegisterMappin(data, vec4(p))
    table.insert(Run.mappins, id)
    return id
end

local function removeMappin(id)
    for i, m in ipairs(Run.mappins) do
        if m == id then table.remove(Run.mappins, i) break end
    end
    pcall(function() Game.GetMappinSystem():UnregisterMappin(id) end)
end

local function clearMappins()
    for _, id in ipairs(Run.mappins) do
        pcall(function() Game.GetMappinSystem():UnregisterMappin(id) end)
    end
    Run.mappins = {}
end

local function wallClock()
    local ok, t = pcall(os.time)
    if ok and type(t) == "number" then return t end
    return nil
end

local function captureGameTime()
    local ok, res = pcall(function()
        local t = Game.GetTimeSystem():GetGameTime()
        return { h = t:Hours(), m = t:Minutes() }
    end)
    if ok then return res end
    return nil
end

local function commsGlitch()
    pcall(function()
        Game.GetStatusEffectSystem():ApplyStatusEffect(
            Game.GetPlayer():GetEntityID(), "BaseStatusEffect.CommsNoiseJam")
    end)
    playSound("ui_glitch_start")
end

local function lockMovement()
    pcall(function()
        Game.GetStatusEffectSystem():ApplyStatusEffect(
            Game.GetPlayer():GetEntityID(), "GameplayRestriction.NoMovement")
    end)
end

local function setWeather(state)
    pcall(function() Game.GetWeatherSystem():SetWeather(state, 10.0, 5) end)
end

-- Teardown central : sans garde de flag, rejouable, idempotent
local function restoreWorld()
    Game.SetTimeDilation(0)
    local player = Game.GetPlayer()
    if player then
        pcall(function()
            StatusEffectHelper.RemoveStatusEffect(player, "GameplayRestriction.NoMovement")
        end)
        pcall(function()
            StatusEffectHelper.RemoveStatusEffect(player, "BaseStatusEffect.CommsNoiseJam")
        end)
    end
    pcall(function() Game.GetWeatherSystem():ResetWeather(true) end)
end

--------------------------------------------------------------------------
-- Ennemis (Codeware, comptage robuste : vu-vivant / âge / non létal)
--------------------------------------------------------------------------

local function spawnAt(record, x, y, z)
    local spec = DynamicEntitySpec.new()
    spec.recordID = record
    spec.appearanceName = "random"
    spec.position = Vector4.new(x, y, z, 1.0)
    spec.orientation = Quaternion.new(0, 0, 0, 1)
    spec.persistState = false
    spec.persistSpawn = false
    spec.alwaysSpawned = true
    spec.tags = { "night_shift_enemy" }
    local id = Game.GetDynamicEntitySystem():CreateEntity(spec)
    if id then
        local entry = { id = id, seen = false, age = 0, gone = false }
        table.insert(Run.enemies, entry)
        return entry
    end
    print("[NIGHT SHIFT] Échec de spawn : " .. tostring(record))
    return nil
end

local function spawnWave(records, center)
    for i, record in ipairs(records) do
        local angle = (i / #records) * 2 * math.pi
        spawnAt(record,
            center.x + math.cos(angle) * CONFIG.spawnRadius,
            center.y + math.sin(angle) * CONFIG.spawnRadius,
            center.z)
    end
end

local function isDown(entity)
    if entity:IsDead() then return true end
    local ok, defeated = pcall(function() return entity:IsDefeated() end)
    return ok and defeated == true
end

local function enemiesRemain(delta)
    local system = Game.GetDynamicEntitySystem()
    local alive = 0
    for _, e in ipairs(Run.enemies) do
        if not e.gone then
            local entity = system:GetEntity(e.id)
            if entity then
                e.seen = true
                if not isDown(entity) then alive = alive + 1 end
            elseif e.seen then
                e.gone = true
            else
                e.age = e.age + (delta or 0)
                if e.age >= CONFIG.spawnTimeout then
                    e.gone = true
                else
                    alive = alive + 1
                end
            end
        end
    end
    Run.aliveCount = alive
    return alive > 0
end

local function despawnEnemies()
    local system = Game.GetDynamicEntitySystem()
    for _, e in ipairs(Run.enemies) do
        pcall(function() system:DeleteEntity(e.id) end)
    end
    pcall(function() Game.GetDynamicEntitySystem():DeleteTagged("night_shift_enemy") end)
    Run.enemies = {}
    Run.aliveCount = 0
end

--------------------------------------------------------------------------
-- Répliques minutées (rattrapage après hitch)
--------------------------------------------------------------------------

local function playLines(lines, delta, endAt)
    Run.timer = Run.timer + delta
    local due = nil
    while Run.step < #lines and Run.timer >= lines[Run.step + 1].at do
        Run.step = Run.step + 1
        due = lines[Run.step].text
    end
    if due then
        screenMessage(T(due))
        playSound("ui_menu_onpress")
    end
    return Run.step >= #lines and Run.timer >= endAt
end

local function linesEndAt(lines, pad)
    local last = 0
    for _, l in ipairs(lines or {}) do
        if l.at > last then last = l.at end
    end
    return last + (pad or 4)
end

--------------------------------------------------------------------------
-- Statistiques persistantes (night_shift_stats.json)
--------------------------------------------------------------------------

-- Le fichier stocke des nombres (compteurs, records) ET des chaînes courtes
-- (les choix du joueur : "a", "b", "secret")
local function loadStats()
    pcall(function()
        local f = io.open("night_shift_stats.json", "r")
        if not f then return end
        local size = f:seek("end"); f:seek("set", 0)
        if size > 65536 then f:close(); return end
        local raw = f:read("*a"); f:close()
        for k, v in string.gmatch(raw or "", '"([%w_]+)"%s*:%s*([%d%.]+)') do
            Stats[k] = tonumber(v)
        end
        for k, v in string.gmatch(raw or "", '"([%w_]+)"%s*:%s*"([%w_]+)"') do
            Stats[k] = v
        end
    end)
end

local function saveStats()
    pcall(function()
        local parts = {}
        for k, v in pairs(Stats) do
            if type(v) == "string" then
                parts[#parts + 1] = string.format('"%s":"%s"', k, v)
            else
                parts[#parts + 1] = string.format('"%s":%s', k, tostring(v))
            end
        end
        local f = io.open("night_shift_stats.json", "w")
        if f then f:write("{" .. table.concat(parts, ",") .. "}"); f:close() end
    end)
end

local function bump(key, amount)
    Stats[key] = (Stats[key] or 0) + (amount or 1)
end

local function formatDuration(seconds)
    seconds = math.floor(seconds or 0)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

--------------------------------------------------------------------------
-- Conséquences : choix persistants, alignement, conditions
--------------------------------------------------------------------------

-- Alignement DÉRIVÉ des choix enregistrés (jamais accumulé : rejouer une
-- mission remplace son choix au lieu de gonfler les compteurs).
local function alignmentCount(kind)
    local n = 0
    for _, def in ipairs(MISSIONS) do
        local chosen = Stats["choice_" .. def.id]
        if chosen then
            for _, p in ipairs(def.phases) do
                if p.type == "choice" then
                    local opt = p.options[chosen]
                    if opt and opt.align == kind then n = n + 1 end
                end
            end
        end
    end
    return n
end

local function flagValue(name)
    if name == "align_signal" then return alignmentCount("signal") end
    if name == "align_eddies" then return alignmentCount("eddies") end
    return Stats[name]
end

-- Évalue une condition déclarative :
--   { flag="choice_ns09", is="b" }      le choix vaut exactement "b"
--   { flag="choice_ns07", isnot="b" }   différent de "b" (ou jamais joué)
--   { flag="align_signal", min=2 }      compteur >= 2
--   { flag="align_signal", below=2 }    compteur < 2
local function condMet(w)
    if not w then return true end
    local v = flagValue(w.flag)
    if w.is ~= nil then return tostring(v) == tostring(w.is) end
    if w.isnot ~= nil then return tostring(v) ~= tostring(w.isnot) end
    if w.min then return (tonumber(v) or 0) >= w.min end
    if w.below then return (tonumber(v) or 0) < w.below end
    return v ~= nil
end

local function setChoice(missionId, key)
    Stats["choice_" .. missionId] = key
    saveStats()
end

-- Épilogue de mission : forme simple { lines = ... } ou liste de variantes
-- { { when = ..., lines = ... }, { lines = ... } } — première qui matche
local function pickEpilogue(def)
    local ep = def.epilogue
    if not ep then return nil end
    if ep.lines then return ep.lines end
    for _, variant in ipairs(ep) do
        if condMet(variant.when) then return variant.lines end
    end
    return nil
end

--------------------------------------------------------------------------
-- Campagne : progression, déverrouillage, journal, bilan
--------------------------------------------------------------------------

-- Préférence de session : true = sélection libre (ignore le déverrouillage).
-- Vit hors de Run (n'est pas remis à zéro entre les missions).
local freePlay = false

-- Prérequis de déverrouillage. Ordonné pour que les missions à choix
-- précèdent leurs retombées (ns07→ns12, ns09→ns10→ns14) et que CODA
-- clôture les trois grands fils.
local UNLOCK = {
    ns02 = { "ns01" }, ns03 = { "ns01" },
    ns04 = { "ns02" }, ns05 = { "ns02" }, ns06 = { "ns03" },
    ns07 = { "ns04" }, ns08 = { "ns05" },
    ns09 = { "ns06" }, ns10 = { "ns09" },
    ns11 = { "ns08" }, ns12 = { "ns07" },
    ns13 = { "ns11" }, ns14 = { "ns10" },
    ns15 = { "ns12", "ns13", "ns14" },
}

local function prereqsMet(mi)
    local def = MISSIONS[mi]
    if not def then return false end
    local reqs = UNLOCK[def.id]
    if not reqs then return true end
    for _, r in ipairs(reqs) do
        if not Stats["done_" .. r] then return false end
    end
    return true
end

local function isUnlocked(mi)
    if not CONFIG.campaign or freePlay then return true end
    return prereqsMet(mi)
end

local function doneCount()
    local n = 0
    for _, def in ipairs(MISSIONS) do
        if Stats["done_" .. def.id] then n = n + 1 end
    end
    return n
end

local CODA_ENDING_NAME = {
    a = { fr = "Rendre le fragment au réseau", en = "Return the fragment to the grid" },
    b = { fr = "Vendre le fragment à Regina", en = "Sell the fragment to Regina" },
    secret = { fr = "La Communion", en = "The Communion" },
}

-- Bilan de campagne généré à l'exécution, annexé à l'épilogue du final.
-- Renvoie des chaînes déjà résolues dans la langue courante.
local function generateRecapLines()
    local sig, edd = alignmentCount("signal"), alignmentCount("eddies")
    local done = doneCount()
    if Run.def and not Stats["done_" .. Run.def.id] then done = done + 1 end
    local flavor
    if sig > edd then flavor = L.recap_signal
    elseif edd > sig then flavor = L.recap_market
    else flavor = L.recap_balanced end
    local out = {
        { at = 0,  text = L.recap_header },
        { at = 4,  text = L.recap_done:format(done, #MISSIONS) },
        { at = 8,  text = L.recap_align:format(sig, edd) },
        { at = 12, text = flavor },
    }
    local coda = Stats["choice_ns15"]
    if coda and CODA_ENDING_NAME[coda] then
        out[#out + 1] = { at = 16, text = L.recap_coda:format(T(CODA_ENDING_NAME[coda])) }
    end
    return out
end

--------------------------------------------------------------------------
-- Cycle de vie mission
--------------------------------------------------------------------------

local enterPhaseAt   -- déclaré ici, défini après les handlers de phase

local function resetRun()
    despawnEnemies()
    clearMappins()
    Run.status = "idle"
    Run.mi, Run.def = nil, nil
    Run.pi, Run.phase, Run.ps = 0, nil, {}
    Run.timer, Run.step = 0, 0
    Run.startedAt = nil
    Run.savedTime, Run.clockChanged = nil, false
    Run.playerMissing = false
    Run.epLines, Run.epEndAt, Run.completionNote = nil, 0, nil
end

local function cancelRun(message, restoreClock)
    restoreWorld()
    if restoreClock ~= false and Run.clockChanged and Run.savedTime then
        pcall(function()
            Game.GetTimeSystem():SetGameTimeByHMS(Run.savedTime.h, Run.savedTime.m, 0)
        end)
    end
    resetRun()
    if message then screenMessage(message) end
end

local function failRun(reason)
    local title = Run.def and T(Run.def.title) or "?"
    cancelRun(L.mission_fail:format(title) .. "  ·  " .. reason, true)
    playSound("ui_hacking_access_denied")
end

-- Passe en épilogue : restaure le monde, verse les récompenses
local function startEpilogue(lines, rewards)
    despawnEnemies()
    clearMappins()
    restoreWorld()
    Run.status = "epilogue"
    Run.timer, Run.step = 0, 0
    -- copie défensive (on ne mute jamais les lignes d'une définition) puis,
    -- pour le final, on annexe le bilan de campagne après l'épilogue
    local seq = {}
    for _, l in ipairs(lines or {}) do seq[#seq + 1] = l end
    if Run.def and Run.def.recap then
        local base = 0
        for _, l in ipairs(seq) do if l.at > base then base = l.at end end
        base = base + 4
        for _, r in ipairs(generateRecapLines()) do
            seq[#seq + 1] = { at = base + r.at, text = r.text }
        end
    end
    Run.epLines = seq
    Run.epEndAt = linesEndAt(Run.epLines, 4)
    rewards = rewards or {}
    if rewards.money and rewards.money > 0 then Game.AddToInventory("Items.money", rewards.money) end
    if rewards.item then Game.AddToInventory(rewards.item, 1) end
    if rewards.cred and rewards.cred > 0 then
        pcall(function() Game.AddExp("StreetCred", rewards.cred) end)
    end
    if rewards.vehicle then
        pcall(function() Game.GetVehicleSystem():EnablePlayerVehicle(rewards.vehicle, true, false) end)
    end
    playSound("ui_jingle_quest_update")
end

local function recordCompletion()
    local id = Run.def.id
    bump("done_" .. id)
    local now = wallClock()
    if now and Run.startedAt then
        local duration = now - Run.startedAt
        local key = "best_" .. id
        if not Stats[key] or Stats[key] <= 0 then
            Stats[key] = duration
            Run.completionNote = L.first_time:format(formatDuration(duration))
        elseif duration < Stats[key] then
            Run.completionNote = L.new_record:format(formatDuration(duration))
            Stats[key] = duration
        end
    end
    saveStats()
end

-- Avance à la prochaine phase dont la condition `when` est satisfaite —
-- les phases conditionnelles (conséquences de choix passés) sont sautées.
local function advancePhase()
    local nextIndex = Run.pi + 1
    while nextIndex <= #Run.def.phases
        and not condMet(Run.def.phases[nextIndex].when) do
        nextIndex = nextIndex + 1
    end
    if nextIndex > #Run.def.phases then
        startEpilogue(pickEpilogue(Run.def), Run.def.rewards)
    else
        enterPhaseAt(nextIndex)
    end
end

--------------------------------------------------------------------------
-- Handlers de phase
--------------------------------------------------------------------------

local PHASE = {}

PHASE.dialogue = {
    enter = function(p)
        if p.dilation then Game.SetTimeDilation(p.dilation) end
        if p.glitch then commsGlitch() end
        if p.time then
            if not Run.savedTime then Run.savedTime = captureGameTime() end
            pcall(function() Game.GetTimeSystem():SetGameTimeByHMS(p.time.h, p.time.m, 0) end)
            Run.clockChanged = true
        end
        if p.weather then setWeather(p.weather) end
    end,
    update = function(p, delta)
        if playLines(p.lines, delta, p.duration or linesEndAt(p.lines, 3)) then
            if p.dilation then Game.SetTimeDilation(0) end
            advancePhase()
        end
    end,
    objective = function(p) return "…" end,
}

PHASE["goto"] = {
    enter = function(p)
        addMappin(p.pos)
        screenMessage(T(p.objective))
        playSound("ui_jingle_quest_update")
    end,
    update = function(p, delta)
        if distanceTo(p.pos) <= (p.reach or CONFIG.reachDistance) then
            clearMappins()
            advancePhase()
        end
    end,
    objective = function(p)
        return T(p.objective), L.hud_distance:format(math.floor(distanceTo(p.pos)))
    end,
}

PHASE.wave = {
    enter = function(p)
        local center = p.pos or (playerPos() or { x = 0, y = 0, z = 0 })
        Run.ps.center = { x = center.x, y = center.y, z = center.z }
        screenMessage(T(p.objective))
        playSound("ui_hacking_access_granted")
        spawnWave(p.enemies, Run.ps.center)
        -- renforts conditionnels : conséquence d'un choix passé
        if p.extra and condMet(p.extra.when) then
            spawnWave(p.extra.enemies, Run.ps.center)
            if p.extra.text then screenMessage(T(p.extra.text)) end
        end
        if p.storm then setWeather("24h_weather_storm") end
    end,
    update = function(p, delta)
        Run.timer = Run.timer + delta
        local remain = enemiesRemain(delta)
        if Run.timer > CONFIG.graceTime and not remain then
            screenMessage(L.wave_clear)
            advancePhase()
        elseif Run.timer >= CONFIG.waveTimeout then
            despawnEnemies()
            screenMessage(L.wave_overload)
            advancePhase()
        end
    end,
    objective = function(p)
        return T(p.objective), L.hud_hostiles:format(Run.aliveCount)
    end,
}

PHASE.hold = {
    enter = function(p)
        addMappin(p.pos)
        screenMessage(T(p.objective))
        playSound("ui_jingle_quest_update")
        Run.ps.progress = 0
        Run.ps.msgTimer = 0
        Run.ps.near = nil
        Run.ps.harassed = false
    end,
    update = function(p, delta)
        local near = distanceTo(p.pos) <= (p.radius or 6.0)
        if near ~= Run.ps.near then
            Run.ps.near = near
            Run.ps.msgTimer = 0
        end
        Run.ps.msgTimer = Run.ps.msgTimer + delta
        if near then
            Run.ps.progress = Run.ps.progress + delta
            if p.harassers and not Run.ps.harassed
                and Run.ps.progress >= p.duration * (p.harassAt or 0.5) then
                Run.ps.harassed = true
                spawnWave(p.harassers, p.pos)
                screenMessage(L.harass)
                playSound("ui_hacking_access_denied")
            end
            if Run.ps.msgTimer >= 2.0 then
                Run.ps.msgTimer = 0
                local pct = math.floor(math.min(100, Run.ps.progress / p.duration * 100))
                screenMessage(L.hold_progress:format(pct))
            end
            if Run.ps.progress >= p.duration then
                clearMappins()
                advancePhase()
            end
        else
            if Run.ps.msgTimer >= 5.0 then
                Run.ps.msgTimer = 0
                screenMessage(L.hold_freeze)
            end
        end
        if Run.ps.harassed then enemiesRemain(delta) end
    end,
    objective = function(p)
        return T(p.objective), nil
    end,
    holdBar = true,
}

PHASE.boss = {
    enter = function(p)
        local center = p.pos or (playerPos() or { x = 0, y = 0, z = 0 })
        Run.ps.center = { x = center.x, y = center.y, z = center.z }
        Run.ps.bossSpawned = false
        screenMessage(T(p.objective))
        playSound("ui_hacking_access_denied")
        if p.adds then spawnWave(p.adds, Run.ps.center) end
        -- renforts ennemis conditionnels (conséquence d'un choix passé)
        if p.extraAdds and condMet(p.extraAdds.when) then
            spawnWave(p.extraAdds.enemies, Run.ps.center)
            if p.extraAdds.text then screenMessage(T(p.extraAdds.text)) end
        end
        -- assistance scriptée : si le joueur a mérité la confiance du réseau,
        -- VOLT grille une partie des renforts à l'instant où ils débarquent.
        -- Déclenché à l'entrée (pas en timer) : le boss n'est pas encore
        -- spawné, donc jamais visé, et l'aide ne peut pas arriver « après »
        -- la fin de la phase si le joueur nettoie vite.
        if p.assist and condMet(p.assist.when) then
            local system = Game.GetDynamicEntitySystem()
            local fried = 0
            for _, e in ipairs(Run.enemies) do
                if fried >= (p.assist.kills or 2) then break end
                if not e.gone then
                    pcall(function() system:DeleteEntity(e.id) end)
                    e.gone = true
                    fried = fried + 1
                end
            end
            if fried > 0 then
                screenMessage(T(p.assist.text))
                playSound("ui_hacking_access_granted")
            end
        end
    end,
    update = function(p, delta)
        Run.timer = Run.timer + delta
        local remain = enemiesRemain(delta)
        if not Run.ps.bossSpawned and Run.timer >= (p.delay or 8) then
            Run.ps.bossSpawned = true
            spawnAt(p.record, Run.ps.center.x + CONFIG.spawnRadius, Run.ps.center.y, Run.ps.center.z)
            screenMessage(T(p.announce))
            playSound("ui_jingle_relic_malfunction")
        end
        if Run.ps.bossSpawned and Run.timer > (p.delay or 8) + 3.0 and not remain then
            advancePhase()
        elseif Run.timer >= CONFIG.waveTimeout then
            despawnEnemies()
            screenMessage(L.wave_overload)
            advancePhase()
        end
    end,
    objective = function(p)
        return T(p.objective), L.hud_hostiles:format(Run.aliveCount)
    end,
}

PHASE.defend = {
    enter = function(p)
        screenMessage(T(p.objective))
        screenMessage(L.defend_start:format(p.duration))
        playSound("ui_hacking_access_granted")
        Run.ps.spawned = {}
    end,
    update = function(p, delta)
        Run.timer = Run.timer + delta
        enemiesRemain(delta)
        for i, w in ipairs(p.waves or {}) do
            if not Run.ps.spawned[i] and Run.timer >= w.at then
                Run.ps.spawned[i] = true
                spawnWave(w.enemies, p.pos or playerPos() or { x = 0, y = 0, z = 0 })
                playSound("ui_hacking_access_denied")
            end
        end
        if Run.timer >= p.duration then
            despawnEnemies()
            screenMessage(L.wave_overload)
            advancePhase()
        end
    end,
    objective = function(p)
        return T(p.objective),
            L.defend_left:format(math.max(0, math.ceil(p.duration - Run.timer)))
    end,
}

PHASE.collect = {
    enter = function(p)
        screenMessage(T(p.objective))
        playSound("ui_jingle_quest_update")
        Run.ps.pins = {}
        Run.ps.visited = {}
        Run.ps.count = 0
        for i, point in ipairs(p.points) do
            Run.ps.pins[i] = addMappin(point)
        end
    end,
    update = function(p, delta)
        for i, point in ipairs(p.points) do
            if not Run.ps.visited[i]
                and distanceTo(point) <= (p.reach or CONFIG.reachDistance) then
                Run.ps.visited[i] = true
                Run.ps.count = Run.ps.count + 1
                removeMappin(Run.ps.pins[i])
                screenMessage(L.collect_tick:format(Run.ps.count, #p.points))
                playSound("ui_hacking_access_granted")
            end
        end
        if Run.ps.count >= #p.points then
            advancePhase()
        end
    end,
    objective = function(p)
        return T(p.objective), string.format("%d/%d", Run.ps.count or 0, #p.points)
    end,
}

PHASE.race = {
    enter = function(p)
        Run.ps.cp = 1
        Run.ps.pin = addMappin(p.checkpoints[1])
        screenMessage(T(p.objective))
        playSound("ui_jingle_quest_update")
    end,
    update = function(p, delta)
        Run.timer = Run.timer + delta
        if Run.timer >= p.timeLimit then
            failRun(L.race_fail)
            return
        end
        local target = p.checkpoints[Run.ps.cp]
        if distanceTo(target) <= (p.reach or CONFIG.reachDistance) then
            removeMappin(Run.ps.pin)
            Run.ps.cp = Run.ps.cp + 1
            if Run.ps.cp > #p.checkpoints then
                advancePhase()
            else
                Run.ps.pin = addMappin(p.checkpoints[Run.ps.cp])
                screenMessage(L.race_cp:format(Run.ps.cp, #p.checkpoints,
                    math.ceil(p.timeLimit - Run.timer)))
                playSound("ui_hacking_access_granted")
            end
        end
    end,
    objective = function(p)
        return T(p.objective),
            L.race_cp:format(math.min(Run.ps.cp or 1, #p.checkpoints), #p.checkpoints,
                math.max(0, math.ceil(p.timeLimit - Run.timer)))
    end,
}

PHASE.choice = {
    enter = function(p)
        despawnEnemies()
        clearMappins()
        commsGlitch()
        lockMovement()
        Game.SetTimeDilation(0.35)
        Run.ps.startedWall = wallClock()
        Run.ps.walk = false
        playSound("ui_jingle_quest_update")
    end,
    update = function(p, delta)
        playLines(p.lines or {}, delta, 0)
        local elapsed = Run.timer
        if Run.ps.startedWall then
            local now = wallClock()
            if now then elapsed = now - Run.ps.startedWall end
        end
        local timeout = p.timeout or CONFIG.choiceTimeout
        if not Run.ps.walk then
            if elapsed >= timeout then
                -- fin secrète : ne rien faire ÉTAIT le choix — mais il faut
                -- l'avoir méritée (secretRequires) sinon secours classique
                if p.secretOnTimeout and p.options.secret
                    and condMet(p.secretRequires) then
                    selectChoiceOption("secret")
                    return
                end
                Run.ps.walk = true
                Game.SetTimeDilation(0)
                local player = Game.GetPlayer()
                if player then
                    pcall(function()
                        StatusEffectHelper.RemoveStatusEffect(player, "GameplayRestriction.NoMovement")
                    end)
                end
                if p.options.a then addMappin(p.options.a.pos) end
                if p.options.b then
                    addMappin(p.options.b.pos, gamedataMappinVariant.ExclamationMarkVariant)
                end
                screenMessage(L.choice_walk)
            elseif Run.step >= #(p.lines or {}) and (Run.timer % 8) < delta then
                screenMessage(L.choice_hint)
            end
        else
            if p.options.a and distanceTo(p.options.a.pos) <= CONFIG.choiceReach then
                selectChoiceOption("a")
            elseif p.options.b and distanceTo(p.options.b.pos) <= CONFIG.choiceReach then
                selectChoiceOption("b")
            end
        end
    end,
    objective = function(p) return L.choice_hint, nil end,
}

-- Point unique de résolution d'un choix (hotkey, marche, secret, console) :
-- enregistre le choix persistant, applique les bonus conditionnels, puis
-- lance l'épilogue de l'option.
function selectChoiceOption(key)
    local p = Run.phase
    local opt = p.options[key]
    if not opt then return false end
    setChoice(Run.def.id, key)
    local rewards = opt.rewards
    if opt.bonus and condMet(opt.bonus.when) then
        rewards = {
            money = (opt.rewards.money or 0) + (opt.bonus.money or 0),
            cred = (opt.rewards.cred or 0) + (opt.bonus.cred or 0),
            item = opt.bonus.item or opt.rewards.item,
            vehicle = opt.rewards.vehicle,
        }
        if opt.bonus.text then screenMessage(T(opt.bonus.text)) end
    end
    startEpilogue(opt.lines, rewards)
    return true
end

-- Choix par hotkey/console : uniquement pendant une phase choice active
local function chooseOption(key)
    if Run.status ~= "running" or not Run.phase or Run.phase.type ~= "choice" then return end
    key = string.lower(tostring(key or ""))
    if key ~= "a" and key ~= "b" then
        screenMessage(L.invalid_choice)
        return
    end
    if not selectChoiceOption(key) then
        screenMessage(L.invalid_choice)
    end
end

enterPhaseAt = function(i)
    Run.pi = i
    Run.phase = Run.def.phases[i]
    Run.ps = {}
    Run.timer, Run.step = 0, 0
    PHASE[Run.phase.type].enter(Run.phase)
end

--------------------------------------------------------------------------
-- Démarrage / boucle
--------------------------------------------------------------------------

local function findMission(what)
    if type(what) == "number" then return MISSIONS[what] and what or nil end
    for i, def in ipairs(MISSIONS) do
        if def.id == what then return i end
    end
    return nil
end

local function startMission(what)
    if Run.status == "running" or Run.status == "epilogue" then
        screenMessage(L.already)
        return false
    end
    local mi = findMission(what or Run.selected)
    if not mi then
        screenMessage(L.unknown_mission)
        return false
    end
    if not isUnlocked(mi) then
        screenMessage(L.locked)
        playSound("ui_hacking_access_denied")
        return false
    end
    resetRun()
    restoreWorld()
    Run.status = "running"
    Run.mi, Run.def = mi, MISSIONS[mi]
    Run.startedAt = wallClock()
    bump("plays_" .. Run.def.id)
    saveStats()
    screenMessage(L.mission_start:format(T(Run.def.title)))
    -- le final rappelle ce que le réseau a retenu de tes choix
    if Run.def.gridMemory then
        screenMessage(L.grid_memory:format(
            alignmentCount("signal"), alignmentCount("eddies")))
    end
    playSound("ui_phone_incoming_call")
    Run.pi = 0
    advancePhase()   -- saute les éventuelles phases conditionnelles en tête
    return true
end

local function updateEpilogue(delta)
    if playLines(Run.epLines, delta, Run.epEndAt) then
        pcall(recordCompletion)
        local done = L.mission_done:format(T(Run.def.title))
        if Run.completionNote then
            done = done .. "  ·  " .. Run.completionNote
        end
        screenMessage(done)
        playSound("ui_jingle_quest_success")
        Run.status = "done"
    end
end

--------------------------------------------------------------------------
-- HUD (mêmes garanties d'équilibre ImGui que SURTENSION)
--------------------------------------------------------------------------

local function drawHud()
    if not CONFIG.hud then return end
    if Run.status ~= "running" and Run.status ~= "epilogue" then return end
    if Run.playerMissing or not Game.GetPlayer() then return end
    if not Run.phase and Run.status ~= "epilogue" then return end

    local title = T(Run.def.title)
    local objective, detail
    local barFrac, barText = nil, nil
    if Run.status == "epilogue" then
        objective = "…"
    else
        local handler = PHASE[Run.phase.type]
        objective, detail = handler.objective(Run.phase)
        if handler.holdBar and Run.ps.progress then
            barFrac = math.min(1.0, Run.ps.progress / Run.phase.duration)
            barText = string.format("%d%%", math.floor(barFrac * 100))
        end
    end

    local screenW = 1920
    pcall(function() screenW = ({ GetDisplayResolution() })[1] or screenW end)
    local flags = ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.AlwaysAutoResize
        + ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoNav

    ImGui.SetNextWindowPos(screenW - 360, 120, ImGuiCond.FirstUseEver)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.02, 0.02, 0.04, 0.65)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.99, 0.93, 0.04, 0.55)
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0.30, 0.91, 0.96, 0.9)
    if ImGui.Begin("NIGHT_SHIFT_HUD", flags) then
        ImGui.TextColored(0.99, 0.93, 0.04, 1.0, "◤ NIGHT SHIFT — " .. title)
        ImGui.Separator()
        ImGui.Text(objective or "")
        if barFrac then ImGui.ProgressBar(barFrac, 280, 16, barText) end
        if detail then ImGui.TextColored(0.30, 0.91, 0.96, 1.0, detail) end
    end
    ImGui.End()
    ImGui.PopStyleColor(3)
end

--------------------------------------------------------------------------
-- Branchements CET
--------------------------------------------------------------------------

registerForEvent("onInit", function()
    LANG = detectLanguage()
    L = LOCALES[LANG]
    loadStats()
    print("[NIGHT SHIFT] Pack chargé (" .. LANG .. ") — 15 missions. Console : GetMod(\"night_shift\").List()")
end)

registerForEvent("onShutdown", function()
    if Run.status == "running" or Run.status == "epilogue" then
        cancelRun(nil, true)
    else
        despawnEnemies()
        clearMappins()
    end
end)

registerForEvent("onDraw", function()
    if Run.hudDisabled then return end
    local ok, err = pcall(drawHud)
    if not ok then
        Run.hudDisabled = true
        pcall(function() ImGui.End() end)
        pcall(function() ImGui.PopStyleColor(3) end)
        print("[NIGHT SHIFT] HUD désactivé après une erreur ImGui : " .. tostring(err))
    end
end)

registerForEvent("onUpdate", function(delta)
    if Run.status == "idle" or Run.status == "done" then return end

    if not Game.GetPlayer() then
        Run.playerMissing = true
        return
    end
    if Run.playerMissing then
        cancelRun(L.session_lost, false)
        return
    end

    if Run.status == "epilogue" then
        updateEpilogue(delta)
    elseif Run.status == "running" and Run.phase then
        PHASE[Run.phase.type].update(Run.phase, delta)
    end
end)

registerHotkey("ns_next", "NIGHT SHIFT — mission suivante / next mission", function()
    if Run.status == "running" or Run.status == "epilogue" then return end
    Run.selected = (Run.selected % #MISSIONS) + 1
    local def = MISSIONS[Run.selected]
    screenMessage(L.selected:format(T(def.title), T(def.brief)) .. " " .. L.start_hint)
end)

registerHotkey("ns_start", "NIGHT SHIFT — démarrer la mission / start mission", function()
    startMission(Run.selected)
end)

registerHotkey("ns_choice_a", "NIGHT SHIFT — Choix A / Choice A", function() chooseOption("a") end)
registerHotkey("ns_choice_b", "NIGHT SHIFT — Choix B / Choice B", function() chooseOption("b") end)

registerHotkey("ns_pos", "NIGHT SHIFT — afficher ma position / print position", function()
    local pos = playerPos()
    if pos then
        print(("[NIGHT SHIFT] Position : x = %.1f, y = %.1f, z = %.1f"):format(pos.x, pos.y, pos.z))
        screenMessage(L.pos_printed)
    end
end)

registerHotkey("ns_abort", "NIGHT SHIFT — annuler la mission / abort mission", function()
    cancelRun(L.aborted, true)
end)

--------------------------------------------------------------------------
-- API publique (console + tests)
--------------------------------------------------------------------------

return {
    List = function()
        print(L.list_header)
        for i, def in ipairs(MISSIONS) do
            print(("  %2d. [%s] %s — %s"):format(i, def.id, T(def.title), T(def.brief)))
        end
    end,
    Start = startMission,
    Abort = function() cancelRun(L.aborted, true) end,
    Choose = chooseOption,
    Select = function(what)
        local mi = findMission(what)
        if mi then Run.selected = mi end
        return mi ~= nil
    end,
    GetStatus = function() return Run.status end,
    GetMissionCount = function() return #MISSIONS end,
    GetMissionId = function(i) return MISSIONS[i] and MISSIONS[i].id or nil end,
    -- Infos de la phase courante (HUD externe, outils, tests)
    GetPhaseInfo = function()
        if Run.status ~= "running" or not Run.phase then
            return { status = Run.status }
        end
        local p = Run.phase
        local info = { status = Run.status, index = Run.pi, type = p.type }
        if p.type == "goto" then info.target = p.pos end
        if p.type == "hold" then info.target = p.pos; info.progress = Run.ps.progress end
        if p.type == "race" then
            info.target = p.checkpoints[math.min(Run.ps.cp or 1, #p.checkpoints)]
            info.timeLeft = p.timeLimit - Run.timer
        end
        if p.type == "collect" then
            for i, point in ipairs(p.points) do
                if not Run.ps.visited[i] then info.target = point break end
            end
            info.count = Run.ps.count
        end
        if p.type == "choice" then
            info.optionA = p.options.a and p.options.a.pos
            info.optionB = p.options.b and p.options.b.pos
            info.walk = Run.ps.walk
        end
        return info
    end,
    GetStats = function()
        local out = {}
        for k, v in pairs(Stats) do out[k] = v end
        return out
    end,
    -- L'alignement dérivé des choix persistants (Signal = protéger
    -- l'héritage de VOLT, Marché = tout monnayer)
    GetAlignment = function()
        return { signal = alignmentCount("signal"), eddies = alignmentCount("eddies") }
    end,
    GetChoices = function()
        local out = {}
        for _, def in ipairs(MISSIONS) do
            out[def.id] = Stats["choice_" .. def.id]
        end
        return out
    end,
    -- Campagne : sélection libre (bypass du déverrouillage) et journal
    SetFreePlay = function(v) freePlay = v and true or false end,
    IsUnlocked = function(what)
        local mi = findMission(what)
        return mi ~= nil and isUnlocked(mi)
    end,
    GetJournal = function()
        local out = {}
        for i, def in ipairs(MISSIONS) do
            local status = Stats["done_" .. def.id] and "done"
                or (isUnlocked(i) and "open" or "locked")
            out[i] = { index = i, id = def.id, title = T(def.title),
                       status = status, choice = Stats["choice_" .. def.id],
                       best = Stats["best_" .. def.id] }
        end
        return out
    end,
    Journal = function()
        print(L.journal_header)
        for i, def in ipairs(MISSIONS) do
            local tag = Stats["done_" .. def.id] and L.st_done
                or (isUnlocked(i) and L.st_open or L.st_locked)
            local choice = Stats["choice_" .. def.id]
            print(("  %2d. [%-9s] %-26s %s"):format(
                i, tag, T(def.title), choice and ("→ " .. choice) or ""))
        end
        print(("  Alignement : Signal %d · Marché %d")
            :format(alignmentCount("signal"), alignmentCount("eddies")))
    end,
}
