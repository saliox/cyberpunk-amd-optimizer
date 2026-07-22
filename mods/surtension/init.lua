--------------------------------------------------------------------------
-- SURTENSION 2.3.1 — mission custom pour Cyberpunk 2077
--------------------------------------------------------------------------
-- « Regina » te demande de couper un siphon sur le réseau d'Arroyo.
-- Sauf que l'appel était usurpé : le siphon était le pare-feu qui
-- retenait VOLT, une IA sauvage vivant dans le réseau électrique.
-- En le coupant, c'est TOI qui déclenches le blackout. Maelstrom
-- débarque avec GRIDLOCK, un cyberpsycho porteur du cœur de l'IA.
-- Après le boss : FINALE CINÉMATIQUE — VOLT te pose la question en
-- face, ralenti, joueur immobilisé. Tu tranches d'une touche :
--   ☀ LUMIÈRE — réinjecter le cœur et rallumer Night City
--   🌑 NOIR   — garder le cœur et laisser la ville éteinte
--
-- 2.3 : HUD persistant (ImGui), localisation FR/EN auto, statistiques
-- persistantes (stats.json, meilleur temps), chatter radio en combat.
--
-- Requiert : Cyber Engine Tweaks (CET) 1.31+  et  Codeware 1.5+
-- Installation : copier le dossier "surtension" dans
--   <jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/
--
-- Démarrage : touche configurée dans CET (Bindings > surtension_start)
--             ou console CET :  GetMod("surtension").Start()
--------------------------------------------------------------------------

local CONFIG = {
    -- Coordonnées (zone industrielle d'Arroyo, Santo Domingo).
    -- Ajustables : la touche "surtension_pos" affiche ta position dans la
    -- console CET pour recaler chaque point où tu veux.
    objectivePos = { x = -1522.0, y = -978.0, z = 25.0 },  -- transformateur / arène du boss
    gridPos      = { x = -1548.0, y = -1002.0, z = 25.0 }, -- secours FIN LUMIÈRE : console réseau
    sellPos      = { x = -1611.0, y = -882.0,  z = 22.0 }, -- secours FIN NOIR : l'acheteur

    language = "auto",   -- "auto" (langue du jeu), "fr" ou "en"
    hud      = true,     -- widget d'objectif persistant à l'écran
    barkInterval = 14.0, -- secondes entre deux répliques radio en combat
    pollInterval = 0.08, -- cadence de la logique de mission (~12 Hz). La
                         -- logique ne tourne pas à chaque frame : invisible
                         -- en jeu, ~5× moins de coût CPU. N'affecte ni le
                         -- contenu, ni le rendu, ni la qualité.
    coopSync   = 0.4,    -- cadence de synchro co-op (relais)
    coopStale  = 6.0,    -- pair sans heartbeat depuis N s = parti
    pingWarnMs = 120,    -- au-delà, avertissement discret de latence co-op

    -- Ennemis (records TweakDB, hostiles par défaut)
    wave1 = {
        "Character.maelstrom_grunt2_ranged2_copperhead_ma",
        "Character.maelstrom_grunt2_ranged2_copperhead_wa",
        "Character.maelstrom_grunt1_melee1_knife_ma",
        "Character.maelstrom_grunt2_ranged2_pulsar_ma",
    },
    hackHarassers = {  -- surprise à 50 % du piratage
        "Character.maelstrom_grunt1_melee1_machete_ma",
        "Character.maelstrom_grunt2_ranged2_copperhead_wa",
    },
    bossAdds = {
        "Character.maelstrom_grunt2_ranged2_pulsar_wa",
        "Character.maelstrom_netrunner1_netrunner1_omaha_ma",
        "Character.maelstrom_grunt2_ranged2_copperhead_ma",
        "Character.maelstrom_grunt1_melee1_machete_ma",
    },
    -- GRIDLOCK : boss lourd au marteau (record du boss Sasquatch, réhabillé
    -- par la fiction de la mission). Remplaçable par n'importe quel record.
    bossRecord = "Character.mql003_boss_sasquatch",

    spawnRadius    = 12.0,  -- rayon de spawn autour de l'arène
    reachDistance  = 15.0,  -- distance pour valider un point de mission
    hackDistance   = 4.0,   -- distance max pendant le piratage
    hackDuration   = 15.0,  -- secondes d'override (harceleurs à mi-course !)
    bossDelay      = 8.0,   -- les renforts arrivent d'abord, GRIDLOCK ensuite
    finaleTimeout  = 35.0,  -- sans touche assignée : bascule sur le choix par déplacement
    spawnTimeout   = 20.0,  -- spawn jamais matérialisé => considéré échoué, ne bloque plus
    waveTimeout    = 180.0, -- anti soft-lock : VOLT neutralise les hostiles restants

    -- FIN LUMIÈRE — « Rallumer Night City » (la vraie Regina te dédommage)
    rewardGridMoney   = 20000,
    rewardGridCred    = 600,
    rewardGridVehicle = "Vehicle.v_sport2_quadra_type66_avenger",
    -- FIN NOIR — « La ville dort » (les eddies siphonnés par VOLT)
    rewardSellMoney = 60000,
    rewardSellCred  = 200,
    rewardSellItem  = "Items.Preset_Yinglong_Default", -- SMG intelligent EMP
}

--------------------------------------------------------------------------
-- Localisation
--------------------------------------------------------------------------

local LOCALES = {}

LOCALES.fr = {
    -- Interface / messages système
    already_running   = "Mission SURTENSION déjà en cours (touche d'annulation pour recommencer).",
    aborted           = "Mission SURTENSION annulée.",
    session_lost      = "Session interrompue — mission SURTENSION annulée. Relance-la quand tu veux.",
    pos_printed       = "Position affichée dans la console CET.",
    invalid_choice    = 'Choix invalide — utilise "grid" (☀ lumière) ou "sell" (🌑 noir).',
    unknown_phase     = "Phase inconnue. Valides : ",
    jumped_to         = "SURTENSION — saut vers la phase : ",
    mission_done      = "MISSION ACCOMPLIE — SURTENSION",
    new_record        = "⏱ NOUVEAU RECORD : %s (précédent : %s)",
    first_time        = "⏱ Mission bouclée en %s",

    -- Objectifs (messages + HUD)
    obj_travel        = "Rejoins la sous-station d'Arroyo",
    obj_wave1         = "Élimine les hostiles",
    obj_hack_near     = "Maintiens l'override du siphon",
    obj_hack_far      = "Approche-toi du transformateur",
    obj_twist         = "…",
    obj_boss          = "Défends le cœur de VOLT",
    obj_finale        = "☀ LUMIÈRE ou 🌑 NOIR — ta touche décide",
    obj_finale_walk   = "Marche vers la fin de ton choix",
    obj_epilogue      = "…",
    hud_hostiles      = "Hostiles : %d",
    hud_distance      = "%d m",
    hud_coop          = "CO-OP %s · %d joueur(s)",
    hud_ping_warn     = "⚠ Latence — Hôte %d ms · Joueur %d ms",
    coop_hosted       = "Session co-op créée : %s — lance la mission, tes potes suivront.",
    coop_joined       = "Session co-op rejointe : %s — tu suis l'hôte.",
    coop_left         = "Session co-op quittée.",
    coop_relay        = "Rappel : lance le relais (coop/relay.js) pour la synchro réseau.",
    vote_cast         = "Vote enregistré : %s. En attente de l'équipe…",
    coop_vote_hint    = "CO-OP — votez ☀ LUMIÈRE / 🌑 NOIR. La majorité décide.",

    -- Déroulé
    wave1_start       = "Maelstrom sur zone — élimine les hostiles !",
    wave_cleared_hack = "Zone dégagée. Approche-toi du transformateur et lance l'override.",
    harassers         = "⚠ PATROUILLE MAELSTROM — maintiens l'override sous le feu !",
    hack_progress     = "OVERRIDE DU SIPHON — %d%%",
    hack_comeback     = "Reste près du transformateur pour maintenir l'override !",
    twist_fried       = "Une décharge grille les implants des harceleurs — VOLT nettoie la zone.",
    boss_incoming     = "⚠ RENFORTS MAELSTROM — DÉFENDS LE CŒUR DE VOLT !",
    boss_announce     = "⚠⚠ GRIDLOCK — CYBERPSYCHO PORTEUR DU CŒUR ⚠⚠",
    wave_overload     = "⚡ VOLT surcharge leurs implants — la voie est libre.",
    boss_overload     = "⚡ VOLT surcharge leurs implants — GRIDLOCK s'effondre.",
    finale_reminder   = "☀ LUMIÈRE ou 🌑 NOIR — le cœur pulse de plus en plus vite…",
    fallback_hint     = "Pas de touche assignée ? Deux marqueurs viennent d'apparaître : marche vers ta fin.",

    -- Répliques minutées
    INTRO = {
        { at = 0.5,  text = "APPEL ENTRANT — REGINA JONES" },
        { at = 3.0,  text = "« Regina » : V, gros problème à Arroyo. Un netrunner de Maelstrom siphonne la sous-station Petrochem." },
        { at = 8.0,  text = "« Regina » : Si le siphon tient encore une heure, tout le district saute. Coupe-le. Cash à la clé." },
        { at = 13.0, text = "SURTENSION — Rejoins la sous-station d'Arroyo" },
    },
    TWIST = {
        { at = 0.5,  text = "« Regina » : Beau boulot V, le virement arr— arr— arr—" },
        { at = 3.5,  text = "⚠ SIGNAL USURPÉ — L'APPEL NE VENAIT PAS DE REGINA JONES" },
        { at = 7.0,  text = "VOLT : Merci, V. Ce « siphon » était le pare-feu qui me retenait depuis 2 ans." },
        { at = 12.0, text = "VOLT : Je suis le réseau électrique de cette ville. Et tu viens de me libérer." },
        { at = 17.0, text = "VOLT : Maelstrom arrive pour récupérer mon cœur. Ne les laisse pas faire… on discutera après." },
    },
    FINALE = {
        { at = 1.0,  text = "Le cœur de VOLT pulse dans ta main. Chaque lampadaire du district clignote au même rythme." },
        { at = 6.0,  text = "VOLT : Le voilà, ton moment, V. Je le sens — tu hésites." },
        { at = 11.0, text = "VOLT : Réinjecte le cœur… et je redeviens le courant docile de leurs climatiseurs." },
        { at = 16.5, text = "VOLT : Ou garde-le. Et je t'offre tout ce que j'ai siphonné. La ville, elle, apprendra le noir." },
        { at = 22.0, text = "☀ LUMIÈRE ou 🌑 NOIR — appuie sur ta touche. Le district retient son souffle." },
    },
    EPILOGUE_GRID = {
        { at = 1.0,  text = "Tu écrases le cœur dans le port de la console réseau. VOLT hurle dans tous les haut-parleurs d'Arroyo." },
        { at = 5.5,  text = "SURTENSION INVERSÉE — le réseau réabsorbe VOLT, bloc par bloc, tour par tour." },
        { at = 10.0, text = "Night City se rallume. L'aube se lève sur Arroyo." },
        { at = 14.0, text = "APPEL ENTRANT — REGINA JONES (authentifié)" },
        { at = 16.5, text = "Regina : V ? C'est la VRAIE Regina. Je n'ai jamais passé cet appel… mais tu viens de sauver le district." },
        { at = 21.5, text = "Regina : Je te dois une explication — et un dédommagement. Regarde ton garage." },
    },
    EPILOGUE_SELL = {
        { at = 1.0,  text = "Tu refermes les doigts sur le cœur. Les lampadaires s'éteignent un à un, comme une haie d'honneur." },
        { at = 5.5,  text = "VOLT : Marché conclu. Les eddies que j'ai siphonnés sont à toi — tous." },
        { at = 10.5, text = "VOLT : On se reverra, V. Je suis dans chaque câble de cette ville, maintenant." },
        { at = 15.0, text = "VOLT : Profite de la vue. Night City est tellement plus belle éteinte." },
    },

    -- Chatter radio en combat (choisi au hasard)
    BARKS = {
        "Radio Maelstrom : « Le siphon lâche ! Butez ce mercenaire ! »",
        "VOLT : Ils ont peur, V. Je le lis dans leurs optiques.",
        "Radio Maelstrom : « Royce va nous écorcher si on perd ce cœur ! »",
        "VOLT : Chaque étincelle que tu vois, c'est moi qui applaudis.",
        "Radio Maelstrom : « C'est qui ce psycho ?! Il démonte tout ! »",
        "VOLT : Le réseau chante ce soir. Continue.",
    },
}

LOCALES.en = {
    already_running   = "SURTENSION mission already running (use the abort hotkey to restart).",
    aborted           = "SURTENSION mission aborted.",
    session_lost      = "Session interrupted — SURTENSION mission cancelled. Restart it anytime.",
    pos_printed       = "Position printed to the CET console.",
    invalid_choice    = 'Invalid choice — use "grid" (☀ light) or "sell" (🌑 dark).',
    unknown_phase     = "Unknown phase. Valid: ",
    jumped_to         = "SURTENSION — jumping to phase: ",
    mission_done      = "MISSION ACCOMPLISHED — SURTENSION",
    new_record        = "⏱ NEW RECORD: %s (previous: %s)",
    first_time        = "⏱ Mission completed in %s",

    obj_travel        = "Reach the Arroyo substation",
    obj_wave1         = "Eliminate the hostiles",
    obj_hack_near     = "Sustain the siphon override",
    obj_hack_far      = "Get close to the transformer",
    obj_twist         = "…",
    obj_boss          = "Defend VOLT's core",
    obj_finale        = "☀ LIGHT or 🌑 DARK — your hotkey decides",
    obj_finale_walk   = "Walk to the ending of your choice",
    obj_epilogue      = "…",
    hud_hostiles      = "Hostiles: %d",
    hud_distance      = "%d m",
    hud_coop          = "CO-OP %s · %d player(s)",
    hud_ping_warn     = "⚠ Latency — Host %d ms · Player %d ms",
    coop_hosted       = "Co-op session created: %s — start the mission, friends will follow.",
    coop_joined       = "Co-op session joined: %s — following the host.",
    coop_left         = "Co-op session left.",
    coop_relay        = "Reminder: run the relay (coop/relay.js) for network sync.",
    vote_cast         = "Vote cast: %s. Waiting for the team…",
    coop_vote_hint    = "CO-OP — vote ☀ LIGHT / 🌑 DARK. Majority decides.",

    wave1_start       = "Maelstrom on site — eliminate the hostiles!",
    wave_cleared_hack = "Zone cleared. Get close to the transformer and start the override.",
    harassers         = "⚠ MAELSTROM PATROL — hold the override under fire!",
    hack_progress     = "SIPHON OVERRIDE — %d%%",
    hack_comeback     = "Stay close to the transformer to sustain the override!",
    twist_fried       = "A discharge fries the patrol's implants — VOLT clears the zone.",
    boss_incoming     = "⚠ MAELSTROM REINFORCEMENTS — DEFEND VOLT'S CORE!",
    boss_announce     = "⚠⚠ GRIDLOCK — CYBERPSYCHO CARRYING THE CORE ⚠⚠",
    wave_overload     = "⚡ VOLT overloads their implants — the way is clear.",
    boss_overload     = "⚡ VOLT overloads their implants — GRIDLOCK collapses.",
    finale_reminder   = "☀ LIGHT or 🌑 DARK — the core is pulsing faster and faster…",
    fallback_hint     = "No hotkey bound? Two markers just appeared: walk to your ending.",

    INTRO = {
        { at = 0.5,  text = "INCOMING CALL — REGINA JONES" },
        { at = 3.0,  text = "\"Regina\": V, big trouble in Arroyo. A Maelstrom netrunner is siphoning the Petrochem substation." },
        { at = 8.0,  text = "\"Regina\": If that siphon holds another hour, the whole district blows. Cut it. Cash on delivery." },
        { at = 13.0, text = "SURTENSION — Reach the Arroyo substation" },
    },
    TWIST = {
        { at = 0.5,  text = "\"Regina\": Nice work V, the transfer is co— co— co—" },
        { at = 3.5,  text = "⚠ SPOOFED SIGNAL — THE CALL NEVER CAME FROM REGINA JONES" },
        { at = 7.0,  text = "VOLT: Thank you, V. That \"siphon\" was the firewall that held me for 2 years." },
        { at = 12.0, text = "VOLT: I am this city's power grid. And you just set me free." },
        { at = 17.0, text = "VOLT: Maelstrom is coming for my core. Don't let them take it… we'll talk after." },
    },
    FINALE = {
        { at = 1.0,  text = "VOLT's core pulses in your hand. Every streetlight in the district blinks to the same beat." },
        { at = 6.0,  text = "VOLT: There it is, V — your moment. I can feel you hesitating." },
        { at = 11.0, text = "VOLT: Reinject the core… and I go back to being the tame current in their AC units." },
        { at = 16.5, text = "VOLT: Or keep it. I'll give you everything I siphoned. And the city learns the dark." },
        { at = 22.0, text = "☀ LIGHT or 🌑 DARK — press your key. The district is holding its breath." },
    },
    EPILOGUE_GRID = {
        { at = 1.0,  text = "You crush the core into the grid console's port. VOLT screams through every speaker in Arroyo." },
        { at = 5.5,  text = "SURGE REVERSED — the grid reabsorbs VOLT, block by block, tower by tower." },
        { at = 10.0, text = "Night City lights back up. Dawn breaks over Arroyo." },
        { at = 14.0, text = "INCOMING CALL — REGINA JONES (authenticated)" },
        { at = 16.5, text = "Regina: V? This is the REAL Regina. I never made that call… but you just saved the district." },
        { at = 21.5, text = "Regina: I owe you an explanation — and compensation. Check your garage." },
    },
    EPILOGUE_SELL = {
        { at = 1.0,  text = "You close your fingers around the core. The streetlights die one by one, like an honor guard." },
        { at = 5.5,  text = "VOLT: Deal sealed. The eddies I siphoned are yours — all of them." },
        { at = 10.5, text = "VOLT: We'll meet again, V. I live in every cable of this city now." },
        { at = 15.0, text = "VOLT: Enjoy the view. Night City is so much prettier in the dark." },
    },

    BARKS = {
        "Maelstrom radio: \"The siphon's dying! Waste that merc!\"",
        "VOLT: They're afraid, V. I can read it in their optics.",
        "Maelstrom radio: \"Royce will skin us if we lose that core!\"",
        "VOLT: Every spark you see is me applauding.",
        "Maelstrom radio: \"Who IS this psycho?! They're tearing us apart!\"",
        "VOLT: The grid is singing tonight. Keep going.",
    },
}

local L = LOCALES.fr   -- résolu dans onInit (CONFIG.language / langue du jeu)

local function detectLanguage()
    if LOCALES[CONFIG.language] then return CONFIG.language end
    local ok, value = pcall(function()
        return tostring(Game.GetSettingsSystem():GetVar("/language", "OnScreen"):GetValue())
    end)
    if not ok or not value then return "fr" end   -- API indisponible : langue de l'auteur
    if value:lower():find("fr") then return "fr" end
    return "en"
end

--------------------------------------------------------------------------
-- CO-OP : synchronisation de la LOGIQUE de mission entre joueurs
--------------------------------------------------------------------------
-- Ce module NE partage PAS le monde physique (personnages, ennemis à
-- l'écran) — ça, c'est le rôle de CyberpunkMP. Il synchronise la mission :
-- session partagée, objectifs de combat d'ÉQUIPE (une vague se termine quand
-- l'équipe l'a nettoyée), et CHOIX votés ensemble.
--
-- Transport : le sandbox CET ne peut pas ouvrir de sockets, donc on passe
-- par des fichiers, relayés sur le réseau par un compagnon (coop/relay.js).
--   coop_out.json — ce pair ÉCRIT : son état + sa contribution
--   coop_in.json  — le relais ÉCRIT : l'état d'équipe agrégé (somme des
--                   « remaining », vote résolu, mission/phase de l'hôte)
--------------------------------------------------------------------------

local Coop = {
    role = "off",   -- off | host | join
    id = nil, code = nil, name = "V",
    syncTimer = 0,
    seq = 0,
    -- état local publié
    outMission = nil, outPhaseIndex = 0, outPhaseType = "", outObjective = "",
    outRemaining = 0, outVote = "", outResolved = "",
    -- état d'équipe reçu (du relais)
    inb = { peerCount = 1, teamRemaining = 0, mission = nil, phaseIndex = 0,
            phaseType = "", objective = "", resolved = "", hostTs = 0,
            selfPingMs = 0, worstPingMs = 0 },
}

local COOP_OUT = "coop_out.json"
local COOP_IN  = "coop_in.json"

local function coopClock()
    local ok, t = pcall(os.time)
    if ok and type(t) == "number" then return t end
    Coop.seq = Coop.seq + 1
    return Coop.seq
end

local function coopWriteOut()
    pcall(function()
        local json = string.format(
            '{"schema":1,"id":"%s","role":"%s","code":"%s","ts":%d,' ..
            '"mission":"%s","phaseIndex":%d,"phaseType":"%s","objective":"%s",' ..
            '"remaining":%d,"vote":"%s","resolved":"%s"}',
            tostring(Coop.id), Coop.role, tostring(Coop.code or ""), coopClock(),
            tostring(Coop.outMission or ""), Coop.outPhaseIndex,
            Coop.outPhaseType, (Coop.outObjective or ""):gsub('"', "'"),
            Coop.outRemaining, Coop.outVote or "", Coop.outResolved or "")
        local f = io.open(COOP_OUT, "w")
        if f then f:write(json); f:close() end
    end)
end

local function coopReadIn()
    pcall(function()
        local f = io.open(COOP_IN, "r")
        if not f then return end
        local size = f:seek("end"); f:seek("set", 0)   -- garde-fou : fichier anormal ignoré
        if size > 16384 then f:close(); return end
        local raw = f:read("*a"); f:close()
        if not raw then return end
        local function num(key, dflt)
            return tonumber(raw:match('"' .. key .. '"%s*:%s*(%-?%d+)')) or dflt
        end
        local function str(key)
            return raw:match('"' .. key .. '"%s*:%s*"([^"]*)"') or ""
        end
        Coop.inb = {
            peerCount     = num("peerCount", 1),
            teamRemaining = num("teamRemaining", 0),
            mission       = str("mission"),
            phaseIndex    = num("phaseIndex", 0),
            phaseType     = str("phaseType"),
            objective     = str("objective"),
            resolved      = str("resolved"),
            hostTs        = num("hostTs", 0),
            selfPingMs    = num("selfPingMs", 0),
            worstPingMs   = num("worstPingMs", 0),
        }
    end)
end

-- API co-op ---------------------------------------------------------------

function Coop.active() return Coop.role ~= "off" end
function Coop.isHost() return Coop.role == "host" end

function Coop.host(code, id)
    Coop.role = "host"
    Coop.code = code or "NS-COOP"
    Coop.id = id or ("host-" .. coopClock())
    Coop.inb.peerCount = 1
    coopWriteOut()
    return Coop.code
end

function Coop.join(code, id)
    Coop.role = "join"
    Coop.code = code or "NS-COOP"
    Coop.id = id or ("join-" .. coopClock())
    coopReadIn()
    coopWriteOut()
    return Coop.code
end

function Coop.leave()
    Coop.role = "off"
    Coop.outMission, Coop.outObjective, Coop.outVote, Coop.outResolved = nil, "", "", ""
    Coop.outRemaining, Coop.outPhaseIndex = 0, 0
    pcall(function() local f = io.open(COOP_OUT, "w"); if f then f:write('{"left":true}'); f:close() end end)
end

-- L'hôte publie la mission/phase courante ; ignoré côté joiner
function Coop.setMissionPhase(missionId, phaseIndex, phaseType, objective)
    if Coop.role ~= "host" then return end
    Coop.outMission = missionId
    Coop.outPhaseIndex = phaseIndex or 0
    Coop.outPhaseType = phaseType or ""
    Coop.outObjective = objective or ""
end

function Coop.setLocalRemaining(n) Coop.outRemaining = n or 0 end
function Coop.setVote(key) Coop.outVote = key or "" end
function Coop.setResolved(key) Coop.outResolved = key or "" end

-- Total d'hostiles restants dans l'équipe (somme relayée) ; nil si co-op off
function Coop.teamRemaining()
    if not Coop.active() then return nil end
    return Coop.inb.teamRemaining or 0
end

-- La vague est-elle terminée pour l'ÉQUIPE ? (true en solo)
function Coop.teamClear()
    if not Coop.active() then return true end
    return (Coop.inb.teamRemaining or 0) <= 0
end

-- Cible que l'hôte impose au joiner (mission à suivre)
function Coop.followTarget()
    if Coop.role ~= "join" then return nil end
    if not Coop.inb.mission or Coop.inb.mission == "" then return nil end
    return { mission = Coop.inb.mission, phaseIndex = Coop.inb.phaseIndex,
             phaseType = Coop.inb.phaseType, objective = Coop.inb.objective }
end

-- Choix résolu par le vote (le relais agrège et renvoie « resolved »)
function Coop.resolvedVote()
    if not Coop.active() then return nil end
    local r = Coop.inb.resolved
    if r == nil or r == "" then return nil end
    return r
end

function Coop.peerCount()
    if not Coop.active() then return 1 end
    return math.max(1, Coop.inb.peerCount or 1)
end

-- Ping (RTT ms) mesuré par le relais. selfPing = notre latence vers l'hôte
-- (0 pour l'hôte) ; worstPing = pire latence parmi les joueurs connectés.
-- Retourne { host, player } pour un avertissement discret quand la latence
-- dépasse le seuil ; nil si co-op inactif, solo, ou latence correcte.
function Coop.pingWarning()
    if not Coop.active() or Coop.peerCount() < 2 then return nil end
    -- L'hôte est le serveur autoritaire : sa latence de référence est 0.
    -- « joueur » = celui dont la latence pose problème : côté hôte le PIRE
    -- ping connecté (worstPingMs), côté joiner sa propre latence (selfPingMs).
    local player = Coop.isHost() and (Coop.inb.worstPingMs or 0)
                                  or  (Coop.inb.selfPingMs or 0)
    if player < CONFIG.pingWarnMs then return nil end
    return { host = 0, player = player }
end

function Coop.sync(dt)
    if not Coop.active() then return end
    Coop.syncTimer = Coop.syncTimer + (dt or 0)
    if Coop.syncTimer < CONFIG.coopSync then return end
    Coop.syncTimer = 0
    coopWriteOut()
    coopReadIn()
end

-- Pour les tests : forcer une synchro immédiate
function Coop.syncNow()
    if not Coop.active() then return end
    coopWriteOut(); coopReadIn()
end

--------------------------------------------------------------------------
-- Ennemis : jeux de records par faction (préréglages à vérifier en jeu)
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- État de mission
--------------------------------------------------------------------------

local Mission = {
    phase = "idle", -- idle > intro > travel > wave1 > hack > twist > boss > finale > epilogue > done
    timer = 0,
    step = 0,              -- index de réplique (intro / twist / finale / épilogue)
    hackProgress = 0,
    hackMsgTimer = 0,      -- throttle des messages du piratage (distinct du timer de phase)
    hackNear = nil,        -- dernière branche près/loin, pour re-caler le throttle
    harassersSpawned = false,
    bossSpawned = false,
    ending = nil,          -- "grid" (lumière) ou "sell" (noir)
    fallbackChoice = false, -- true si la finale est passée en choix par déplacement
    finaleStartedAt = nil, -- horloge murale (os.time) au début de la finale
    missionStartedAt = nil,-- horloge murale au lancement (pour le chrono)
    clockChanged = false,  -- true si la mission a forcé l'heure du jeu
    savedTime = nil,       -- {h, m} capturés avant le blackout, pour l'annulation
    playerMissing = false, -- joueur absent (mort / chargement) détecté
    barkTimer = 0,         -- prochaine réplique radio de combat
    aliveCount = 0,        -- hostiles restants (rafraîchi par enemiesRemain, pour le HUD)
    testRun = false,       -- run lancée via Jump() : pas de stats ni de record
    completionNote = nil,  -- chrono/record à afficher avec le message de fin
    hudDisabled = false,   -- HUD coupé après une erreur ImGui (log unique)
    pollAccum = 0,         -- accumulateur de delta entre deux ticks de logique
    hud = nil,             -- payload HUD pré-calculé (rendu sans requête jeu)
    enemies = {},          -- { id = <entityID>, seen = <bool>, age = <sec>, gone = <bool> }
    mappins = {},
}

--------------------------------------------------------------------------
-- Statistiques persistantes (stats.json dans le dossier du mod)
--------------------------------------------------------------------------

local Stats = { runs = 0, wins = 0, endGrid = 0, endSell = 0, bestTime = 0 }

local function loadStats()
    local ok = pcall(function()
        local f = io.open("stats.json", "r")
        if not f then return end
        -- garde-fou : un fichier corrompu/énorme ne doit pas geler le chargement
        local size = f:seek("end")
        f:seek("set", 0)
        if size > 65536 then
            f:close()
            print("[SURTENSION] stats.json anormalement gros, ignoré.")
            return
        end
        local raw = f:read("*a")
        f:close()
        for k, v in string.gmatch(raw or "", '"([%w_]+)"%s*:%s*([%d%.]+)') do
            if Stats[k] ~= nil then Stats[k] = tonumber(v) or Stats[k] end
        end
    end)
    if not ok then print("[SURTENSION] stats.json illisible, stats réinitialisées.") end
end

local function saveStats()
    pcall(function()
        local parts = {}
        for k, v in pairs(Stats) do
            parts[#parts + 1] = string.format('"%s":%s', k, tostring(v))
        end
        local f = io.open("stats.json", "w")
        if f then
            f:write("{" .. table.concat(parts, ",") .. "}")
            f:close()
        end
    end)
end

local function formatDuration(seconds)
    seconds = math.floor(seconds or 0)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

--------------------------------------------------------------------------
-- Petites bibliothèques internes
--------------------------------------------------------------------------

local function vec4(p)
    return Vector4.new(p.x, p.y, p.z, 1.0)
end

local function playerPos()
    local player = Game.GetPlayer()
    if not player then return nil end
    return player:GetWorldPosition()
end

-- Position joueur figée pour la durée d'un tick de logique : une seule
-- requête native par tick, réutilisée par tous les tests de distance.
local ppos = nil
local function refreshPlayerPos()
    ppos = playerPos()
    return ppos
end

local function distanceTo(p)
    local pos = ppos
    if not pos then return 999999 end
    local dx, dy, dz = pos.x - p.x, pos.y - p.y, pos.z - p.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Message plein écran (style objectif de quête du jeu)
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
    table.insert(Mission.mappins, id)
    return id
end

local function clearMappins()
    for _, id in ipairs(Mission.mappins) do
        pcall(function() Game.GetMappinSystem():UnregisterMappin(id) end)
    end
    Mission.mappins = {}
end

-- Horloge murale (indépendante de la dilatation du temps de jeu).
-- os.time peut être absent du bac à sable : on retombe sur le temps de jeu.
local function wallClock()
    local ok, t = pcall(os.time)
    if ok and type(t) == "number" then return t end
    return nil
end

-- Capture l'heure du jeu (pour la restaurer en cas d'annulation)
local function captureGameTime()
    local ok, res = pcall(function()
        local t = Game.GetTimeSystem():GetGameTime()
        return { h = t:Hours(), m = t:Minutes() }
    end)
    if ok then return res end
    return nil
end

-- Grésillement de comms pendant le twist (sans conséquence si absent)
local function commsGlitch()
    pcall(function()
        Game.GetStatusEffectSystem():ApplyStatusEffect(
            Game.GetPlayer():GetEntityID(), "BaseStatusEffect.CommsNoiseJam")
    end)
    playSound("ui_glitch_start")
end

-- Immobilisation du joueur pour la cinématique de finale
local function lockMovement()
    pcall(function()
        Game.GetStatusEffectSystem():ApplyStatusEffect(
            Game.GetPlayer():GetEntityID(), "GameplayRestriction.NoMovement")
    end)
end

-- Météo via l'API Codeware (RequestNewWeather n'existe pas sur ce système)
local function setWeather(state)
    pcall(function() Game.GetWeatherSystem():SetWeather(state, 10.0, 5) end)
end

local function resetWeather()
    pcall(function() Game.GetWeatherSystem():ResetWeather(true) end)
end

-- Teardown central : retire TOUT ce que la mission applique au joueur et
-- au monde, sans garde de flag — chaque retrait est inoffensif s'il n'y a
-- rien à retirer, et rejouable si un retrait précédent a échoué.
local function restoreWorld()
    Game.SetTimeDilation(0)   -- 0 = UnsetTimeDilation (retour à la normale)
    local player = Game.GetPlayer()
    if player then
        pcall(function()
            StatusEffectHelper.RemoveStatusEffect(player, "GameplayRestriction.NoMovement")
        end)
        pcall(function()
            StatusEffectHelper.RemoveStatusEffect(player, "BaseStatusEffect.CommsNoiseJam")
        end)
    end
    resetWeather()
end

--------------------------------------------------------------------------
-- Gestion des ennemis (Codeware DynamicEntitySystem)
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
    spec.tags = { "surtension_enemy" }
    local id = Game.GetDynamicEntitySystem():CreateEntity(spec)
    if id then
        table.insert(Mission.enemies, { id = id, seen = false, age = 0, gone = false })
    else
        print("[SURTENSION] Échec de spawn : " .. tostring(record))
    end
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

-- Mort OU neutralisé (les takedowns non létaux laissent IsDead() à false)
local function isDown(entity)
    if entity:IsDead() then return true end
    local ok, defeated = pcall(function() return entity:IsDefeated() end)
    return ok and defeated == true
end

-- Reste-t-il des hostiles actifs ou en cours de spawn ?
-- Le spawn Codeware est asynchrone : une entité pas encore résolue compte
-- comme active tant qu'elle n'a pas dépassé spawnTimeout ; une entité vue
-- vivante puis devenue introuvable ne bloque plus (nettoyage du moteur).
-- Met aussi à jour Mission.aliveCount pour le HUD.
local function enemiesRemain(delta)
    local system = Game.GetDynamicEntitySystem()
    local alive = 0
    for _, e in ipairs(Mission.enemies) do
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
                    print("[SURTENSION] Spawn jamais matérialisé, ignoré : " .. tostring(e.id))
                else
                    alive = alive + 1
                end
            end
        end
    end
    Mission.aliveCount = alive
    return alive > 0
end

local function despawnEnemies()
    local system = Game.GetDynamicEntitySystem()
    for _, e in ipairs(Mission.enemies) do
        pcall(function() system:DeleteEntity(e.id) end)
    end
    -- filet : supprime aussi les orphelins d'un état Lua précédent
    -- (Reload All Mods en pleine mission)
    pcall(function() Game.GetDynamicEntitySystem():DeleteTagged("surtension_enemy") end)
    Mission.enemies = {}
    Mission.aliveCount = 0
end

-- Réplique radio d'ambiance pendant les phases de combat
local function combatBark(delta)
    Mission.barkTimer = Mission.barkTimer + delta
    if Mission.barkTimer >= CONFIG.barkInterval then
        Mission.barkTimer = 0
        local barks = L.BARKS
        screenMessage(barks[math.random(#barks)])
    end
end

--------------------------------------------------------------------------
-- Répliques minutées
--------------------------------------------------------------------------

-- Joue une liste de répliques minutées ; rattrape les répliques en retard
-- après un gros hitch (n'affiche que la dernière due : l'écran ne montre
-- qu'un message à la fois). Terminé quand TOUTES les répliques sont
-- passées ET que endAt est atteint.
local function playLines(lines, delta, endAt)
    Mission.timer = Mission.timer + delta
    local due = nil
    while Mission.step < #lines and Mission.timer >= lines[Mission.step + 1].at do
        Mission.step = Mission.step + 1
        due = lines[Mission.step].text
    end
    if due then
        screenMessage(due)
        playSound("ui_menu_onpress")
    end
    return Mission.step >= #lines and Mission.timer >= endAt
end

--------------------------------------------------------------------------
-- Machine à états : entrées de phase
-- Chaque phase a sa fonction d'entrée (setup complet), utilisée à la fois
-- par le déroulé normal et par l'outil de test Jump().
--------------------------------------------------------------------------

local function enterPhase(phase)
    Mission.phase = phase
    Mission.timer = 0
    Mission.step = 0
    Mission.barkTimer = 0
end

-- Remise à zéro de tous les champs d'une run (une seule source de vérité)
local function resetMission()
    despawnEnemies()
    clearMappins()
    Mission.hackProgress = 0
    Mission.hackMsgTimer = 0
    Mission.hackNear = nil
    Mission.harassersSpawned = false
    Mission.bossSpawned = false
    Mission.ending = nil
    Mission.fallbackChoice = false
    Mission.finaleStartedAt = nil
    Mission.missionStartedAt = nil
    Mission.clockChanged = false
    Mission.savedTime = nil
    Mission.playerMissing = false
    Mission.barkTimer = 0
    Mission.aliveCount = 0
    Mission.testRun = false
    Mission.completionNote = nil
    Mission.pollAccum = 0
    Mission.hud = nil
    if Coop.isHost() then Coop.setMissionPhase(nil, 0, "", "") end
    Coop.setLocalRemaining(0)
    Coop.setVote("")
end

-- Annulation propre : restaure le monde, y compris l'heure si on l'a forcée.
-- restoreClock=false pour l'annulation après mort/chargement : la sauvegarde
-- fraîchement chargée a SA propre heure, on ne doit pas lui imposer celle
-- capturée dans la run abandonnée.
local function cancelMission(message, restoreClock)
    restoreWorld()
    if restoreClock ~= false and Mission.clockChanged and Mission.savedTime then
        pcall(function()
            Game.GetTimeSystem():SetGameTimeByHMS(Mission.savedTime.h, Mission.savedTime.m, 0)
        end)
    end
    resetMission()
    enterPhase("idle")
    if message then screenMessage(message) end
end

local function beginIntro()
    enterPhase("intro")
    playSound("ui_phone_incoming_call")
    Game.SetTimeDilation(0.6)   -- ralenti "cinématique" pendant l'appel
end

local function beginTravel()
    enterPhase("travel")
    addMappin(CONFIG.objectivePos)
    playSound("ui_jingle_quest_update")
end

local function beginWave1()
    enterPhase("wave1")
    clearMappins()
    screenMessage(L.wave1_start)
    playSound("ui_hacking_access_granted")
    spawnWave(CONFIG.wave1, CONFIG.objectivePos)
    setWeather("24h_weather_storm")   -- orage électrique sur le district
end

local function beginHack()
    enterPhase("hack")
    Mission.hackProgress = 0
    Mission.hackMsgTimer = 0
    Mission.hackNear = nil
    addMappin(CONFIG.objectivePos)
    screenMessage(L.wave_cleared_hack)
    playSound("ui_jingle_quest_update")
end

local function beginTwist()
    -- des harceleurs encore debout ? VOLT s'en charge : la cinématique ne
    -- se joue jamais sous le feu
    if enemiesRemain(0) then
        screenMessage(L.twist_fried)
    end
    despawnEnemies()
    clearMappins()
    Mission.savedTime = captureGameTime()   -- pour restaurer l'heure si annulation
    enterPhase("twist")
    commsGlitch()
    Game.SetTimeDilation(0.5)
    pcall(function() Game.GetTimeSystem():SetGameTimeByHMS(2, 0, 0) end)
    Mission.clockChanged = true
    playSound("ui_hacking_access_granted")
end

local function beginBoss()
    enterPhase("boss")
    screenMessage(L.boss_incoming)
    spawnWave(CONFIG.bossAdds, CONFIG.objectivePos)
    playSound("ui_hacking_access_denied")
end

-- Entrée dans la finale cinématique : ralenti profond + joueur figé
local function startFinale()
    despawnEnemies()
    clearMappins()
    enterPhase("finale")
    commsGlitch()
    lockMovement()
    Game.SetTimeDilation(0.35)
    Mission.finaleStartedAt = wallClock()   -- timeout mesuré en temps réel
    playSound("ui_jingle_quest_update")
end

--------------------------------------------------------------------------
-- Déroulé de la mission
--------------------------------------------------------------------------

local function startMission()
    if Mission.phase ~= "idle" and Mission.phase ~= "done" then
        screenMessage(L.already_running)
        return
    end
    resetMission()
    restoreWorld()   -- purge d'éventuels restes d'une run précédente
    Mission.missionStartedAt = wallClock()
    Stats.runs = Stats.runs + 1
    saveStats()
    beginIntro()
end

local function updateIntro(delta)
    if playLines(L.INTRO, delta, 16.0) then
        Game.SetTimeDilation(0)
        beginTravel()
    end
end

local function updateTravel()
    if distanceTo(CONFIG.objectivePos) <= CONFIG.reachDistance then
        beginWave1()
    end
end

local function updateWave1(delta)
    Mission.timer = Mission.timer + delta
    combatBark(delta)
    -- appelé chaque frame (une seule fois) : compteur HUD à jour et
    -- vieillissement des spawns en attente dès le début de la phase
    local remain = enemiesRemain(delta)
    Coop.setLocalRemaining(Mission.aliveCount)   -- contribue au total d'équipe
    if Mission.timer > 2.0 and not remain and Coop.teamClear() then
        beginHack()
    elseif Mission.timer >= CONFIG.waveTimeout then
        -- anti soft-lock : ennemi coincé dans le décor, spawn raté…
        despawnEnemies()
        screenMessage(L.wave_overload)
        beginHack()
    end
end

local function updateHack(delta)
    local near = distanceTo(CONFIG.objectivePos) <= CONFIG.hackDistance
    if near ~= Mission.hackNear then
        Mission.hackNear = near
        Mission.hackMsgTimer = 0   -- pas de report de seuil entre les deux branches
    end
    Mission.hackMsgTimer = Mission.hackMsgTimer + delta

    if near then
        Mission.hackProgress = Mission.hackProgress + delta

        -- surprise : des harceleurs débarquent à mi-piratage
        if not Mission.harassersSpawned
            and Mission.hackProgress >= CONFIG.hackDuration * 0.5 then
            Mission.harassersSpawned = true
            spawnWave(CONFIG.hackHarassers, CONFIG.objectivePos)
            screenMessage(L.harassers)
            playSound("ui_hacking_access_denied")
        end

        if Mission.hackMsgTimer >= 2.0 then  -- progression toutes les ~2 s
            Mission.hackMsgTimer = 0
            local pct = math.floor(math.min(100, Mission.hackProgress / CONFIG.hackDuration * 100))
            screenMessage(L.hack_progress:format(pct))
            playSound("ui_hacking_hackloop")
        end

        if Mission.hackProgress >= CONFIG.hackDuration then
            beginTwist()   -- LE TWIST : blackout immédiat + signal usurpé
        end
    else
        if Mission.hackMsgTimer >= 5.0 then
            Mission.hackMsgTimer = 0
            screenMessage(L.hack_comeback)
        end
    end

    if Mission.harassersSpawned then enemiesRemain(delta) end   -- compteur HUD
end

local function updateTwist(delta)
    if playLines(L.TWIST, delta, 20.0) then
        Game.SetTimeDilation(0)
        beginBoss()
    end
end

local function updateBoss(delta)
    Mission.timer = Mission.timer + delta
    combatBark(delta)
    -- appelé chaque frame (une seule fois) : compteur HUD à jour dès que
    -- les renforts attaquent, pas seulement après l'arrivée de GRIDLOCK
    local remain = enemiesRemain(delta)
    Coop.setLocalRemaining(Mission.aliveCount)

    -- GRIDLOCK arrive après les renforts, avec annonce
    if not Mission.bossSpawned and Mission.timer >= CONFIG.bossDelay then
        Mission.bossSpawned = true
        spawnAt(CONFIG.bossRecord,
            CONFIG.objectivePos.x + CONFIG.spawnRadius,
            CONFIG.objectivePos.y,
            CONFIG.objectivePos.z)
        screenMessage(L.boss_announce)
        playSound("ui_jingle_relic_malfunction")
    end

    if Mission.bossSpawned and Mission.timer > CONFIG.bossDelay + 3.0
        and not remain and Coop.teamClear() then
        startFinale()
    elseif Mission.timer >= CONFIG.waveTimeout then
        despawnEnemies()
        screenMessage(L.boss_overload)
        startFinale()
    end
end

-- Chrono de fin de mission : enregistre le score et prépare l'annonce de
-- record (affichée avec le message de fin, sinon la première réplique
-- d'épilogue l'écraserait au bout d'une seconde).
-- Les runs lancées via Jump() sont des tests : jamais comptées.
local function recordCompletion()
    if Mission.testRun then return end
    Stats.wins = Stats.wins + 1
    if Mission.ending == "grid" then
        Stats.endGrid = Stats.endGrid + 1
    else
        Stats.endSell = Stats.endSell + 1
    end
    local now = wallClock()
    if now and Mission.missionStartedAt then
        local duration = now - Mission.missionStartedAt
        if Stats.bestTime <= 0 then
            Stats.bestTime = duration
            Mission.completionNote = L.first_time:format(formatDuration(duration))
        elseif duration < Stats.bestTime then
            Mission.completionNote = L.new_record:format(
                formatDuration(duration), formatDuration(Stats.bestTime))
            Stats.bestTime = duration
        end
    end
    saveStats()
end

-- Verse les récompenses et lance l'épilogue de la fin choisie.
-- Accepte les alias : grid / light / lumière — sell / dark / noir.
local ENDING_ALIASES = {
    grid = "grid", light = "grid", lumiere = "grid", ["lumière"] = "grid",
    sell = "sell", dark = "sell", noir = "sell",
}

-- Applique RÉELLEMENT une fin (récompenses + épilogue)
local function applyEnding(key)
    if Mission.phase ~= "finale" then return end
    Mission.ending = key
    clearMappins()
    restoreWorld()   -- verrou, brouillage, dilatation, météo : tout est levé
    enterPhase("epilogue")

    if key == "grid" then
        playSound("ui_hacking_access_granted")
        -- Night City se rallume : aube + ciel dégagé
        pcall(function() Game.GetTimeSystem():SetGameTimeByHMS(6, 30, 0) end)
        setWeather("24h_weather_sunny")
        Game.AddToInventory("Items.money", CONFIG.rewardGridMoney)
        pcall(function() Game.AddExp("StreetCred", CONFIG.rewardGridCred) end)
        -- la surprise de Regina : une Quadra Avenger dans ton garage
        pcall(function()
            Game.GetVehicleSystem():EnablePlayerVehicle(CONFIG.rewardGridVehicle, true, false)
        end)
    else
        playSound("ui_glitch_start")
        -- la nuit du blackout reste en place (choix narratif)
        Game.AddToInventory("Items.money", CONFIG.rewardSellMoney)
        Game.AddToInventory(CONFIG.rewardSellItem, 1)
        pcall(function() Game.AddExp("StreetCred", CONFIG.rewardSellCred) end)
    end

    -- comptabilité : un pépin de stats ne doit jamais casser la fin de mission
    pcall(recordCompletion)
end

-- Point d'entrée d'un choix de fin. SOLO : applique tout de suite. CO-OP :
-- ce n'est qu'un VOTE ; le relais résout à la majorité et applyEnding()
-- se déclenche pour tout le monde en même temps (via updateFinale).
local function chooseEnding(ending)
    if Mission.phase ~= "finale" then return end
    local key = ENDING_ALIASES[string.lower(tostring(ending or ""))]
    if not key then
        screenMessage(L.invalid_choice)
        return
    end
    if Coop.active() then
        Coop.setVote(key)
        Coop.syncNow()
        screenMessage(L.vote_cast:format(key == "grid" and "☀" or "🌑"))
        return
    end
    applyEnding(key)
end

-- La finale cinématique : répliques de VOLT, puis attente du choix.
-- Sans touche assignée, bascule de secours sur le choix par déplacement.
-- Le timeout est mesuré en temps réel (os.time) pour ne pas être étiré
-- par le ralenti ×0.35 si le delta d'onUpdate est dilaté.
local function updateFinale(delta)
    playLines(L.FINALE, delta, 0)

    -- CO-OP : la fin se décide par VOTE (majorité, arbitrée par le relais).
    -- Dès qu'une fin est résolue, tout le monde l'applique ensemble.
    if Coop.active() then
        local r = Coop.resolvedVote()
        if r == "grid" or r == "sell" then applyEnding(r); return end
        if Mission.step >= #L.FINALE and (Mission.timer % 8) < delta then
            screenMessage(L.coop_vote_hint)
        end
        Mission.timer = Mission.timer + delta
        return
    end

    local elapsed = Mission.timer
    if Mission.finaleStartedAt then
        local now = wallClock()
        if now then elapsed = now - Mission.finaleStartedAt end
    end

    if not Mission.fallbackChoice then
        -- rappel pulsé une fois les répliques passées
        if Mission.step >= #L.FINALE and (Mission.timer % 8) < delta then
            screenMessage(L.finale_reminder)
            playSound("ui_menu_onpress")
        end
        -- secours : touches non assignées ? on repasse en choix par déplacement
        if elapsed >= CONFIG.finaleTimeout then
            Mission.fallbackChoice = true
            Game.SetTimeDilation(0)
            local player = Game.GetPlayer()
            if player then
                pcall(function()
                    StatusEffectHelper.RemoveStatusEffect(player, "GameplayRestriction.NoMovement")
                end)
            end
            addMappin(CONFIG.gridPos)                                        -- LUMIÈRE
            addMappin(CONFIG.sellPos, gamedataMappinVariant.ExclamationMarkVariant) -- NOIR
            screenMessage(L.fallback_hint)
        end
    else
        if distanceTo(CONFIG.gridPos) <= CONFIG.reachDistance then
            chooseEnding("grid")
        elseif distanceTo(CONFIG.sellPos) <= CONFIG.reachDistance then
            chooseEnding("sell")
        end
    end
end

local function updateEpilogue(delta)
    local lines = Mission.ending == "grid" and L.EPILOGUE_GRID or L.EPILOGUE_SELL
    local endAt = Mission.ending == "grid" and 25.0 or 19.0
    if playLines(lines, delta, endAt) then
        local done = L.mission_done
        if Mission.completionNote then
            done = done .. "  ·  " .. Mission.completionNote
        end
        screenMessage(done)
        playSound("ui_jingle_quest_success")
        enterPhase("done")
    end
end

--------------------------------------------------------------------------
-- HUD persistant (ImGui) — objectif courant, progression, hostiles
--------------------------------------------------------------------------

local HUD_HIDDEN = { idle = true, done = true, intro = true, twist = true, epilogue = true }

local function hudObjective()
    local phase = Mission.phase
    if phase == "travel" then
        return L.obj_travel, L.hud_distance:format(math.floor(distanceTo(CONFIG.objectivePos)))
    elseif phase == "wave1" then
        return L.obj_wave1, L.hud_hostiles:format(Coop.teamRemaining() or Mission.aliveCount)
    elseif phase == "hack" then
        if Mission.hackNear then
            return L.obj_hack_near, nil
        end
        return L.obj_hack_far, L.hud_distance:format(math.floor(distanceTo(CONFIG.objectivePos)))
    elseif phase == "boss" then
        return L.obj_boss, L.hud_hostiles:format(Coop.teamRemaining() or Mission.aliveCount)
    elseif phase == "finale" then
        if Mission.fallbackChoice then return L.obj_finale_walk, nil end
        return L.obj_finale, nil
    end
    return nil, nil
end

-- Le calcul (objectif, distance, barre) se fait pendant le tick de logique
-- throttlé — refreshHud() — et stocke un payload prêt à peindre. Le rendu
-- par frame — renderHud() — ne fait QUE des appels ImGui, aucune requête au
-- jeu : le HUD ne coûte donc quasiment rien par frame.
local screenWCache = nil

local function refreshHud()
    if not CONFIG.hud or HUD_HIDDEN[Mission.phase] then
        Mission.hud = nil
        return
    end
    local objective, detail = hudObjective()
    if not objective then
        Mission.hud = nil
        return
    end
    local barFrac, barText
    if Mission.phase == "hack" and Mission.hackNear then
        barFrac = math.min(1.0, Mission.hackProgress / CONFIG.hackDuration)
        barText = string.format("%d%%", math.floor(barFrac * 100))
    end
    local coopLine, pingLine
    if Coop.active() then
        coopLine = L.hud_coop:format(Coop.role, Coop.peerCount())
        local pw = Coop.pingWarning()
        if pw then pingLine = L.hud_ping_warn:format(pw.host, pw.player) end
    end
    Mission.hud = { objective = objective, detail = detail,
                    barFrac = barFrac, barText = barText,
                    coop = coopLine, ping = pingLine }
end

local function renderHud()
    local h = Mission.hud
    if not screenWCache then
        local w = 1920
        pcall(function() w = ({ GetDisplayResolution() })[1] or w end)
        screenWCache = w
    end
    local flags = ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.AlwaysAutoResize
        + ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoNav

    ImGui.SetNextWindowPos(screenWCache - 340, 120, ImGuiCond.FirstUseEver)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.02, 0.02, 0.04, 0.65)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.99, 0.93, 0.04, 0.55)
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0.30, 0.91, 0.96, 0.9)
    if ImGui.Begin("SURTENSION_HUD", flags) then
        ImGui.TextColored(0.99, 0.93, 0.04, 1.0, "◤ SURTENSION")
        if h.coop then ImGui.TextColored(0.30, 0.91, 0.96, 1.0, h.coop) end
        if h.ping then ImGui.TextColored(0.98, 0.62, 0.10, 1.0, h.ping) end
        ImGui.Separator()
        ImGui.Text(h.objective)
        if h.barFrac then
            ImGui.ProgressBar(h.barFrac, 260, 16, h.barText)
        end
        if h.detail then
            ImGui.TextColored(0.30, 0.91, 0.96, 1.0, h.detail)
        end
    end
    ImGui.End()
    ImGui.PopStyleColor(3)
end

--------------------------------------------------------------------------
-- Branchements CET
--------------------------------------------------------------------------

registerForEvent("onInit", function()
    L = LOCALES[detectLanguage()] or LOCALES.fr
    loadStats()
    print("[SURTENSION] Mission 2.3.1 chargée (" .. detectLanguage() .. "). Console : GetMod(\"surtension\").Start()")
    print(("[SURTENSION] Stats : %d runs, %d victoires (☀ %d / 🌑 %d), record %s")
        :format(Stats.runs, Stats.wins, Stats.endGrid, Stats.endSell,
                Stats.bestTime > 0 and formatDuration(Stats.bestTime) or "—"))
end)

-- Reload All Mods / arrêt du jeu en pleine mission : on ne laisse rien
-- traîner (effets, ralenti, ennemis, marqueurs)
registerForEvent("onShutdown", function()
    if Mission.phase ~= "idle" and Mission.phase ~= "done" then
        cancelMission(nil)
    else
        despawnEnemies()
        clearMappins()
    end
end)

-- Rendu par frame : ne peint que le payload pré-calculé (aucune requête au
-- jeu hormis un garde léger « joueur présent » pour ne rien dessiner sur
-- l'écran de mort/chargement). Court-circuité gratuitement hors mission.
registerForEvent("onDraw", function()
    if Mission.hudDisabled or not Mission.hud then return end
    if not Game.GetPlayer() then return end
    local ok, err = pcall(renderHud)
    if not ok then
        -- Un pcall silencieux qui tourne chaque frame empilerait des styles
        -- ImGui non dépilés (corruption de l'overlay). On rééquilibre au
        -- mieux, on log UNE fois, et on coupe le HUD pour la session.
        Mission.hudDisabled = true
        pcall(function() ImGui.End() end)
        pcall(function() ImGui.PopStyleColor(3) end)
        print("[SURTENSION] HUD désactivé après une erreur ImGui : " .. tostring(err))
    end
end)

-- Joiner : démarre SURTENSION quand l'hôte l'a lancée
local function coopFollow()
    if Coop.role ~= "join" or Mission.phase ~= "idle" then return end
    local t = Coop.followTarget()
    if t and t.mission ~= "" then startMission() end
end

-- Hôte : publie la phase/objectif courant pour l'équipe
local function coopPublish()
    if Coop.role ~= "host" then return end
    if Mission.phase ~= "idle" and Mission.phase ~= "done" then
        Coop.setMissionPhase("surtension", 0, Mission.phase, hudObjective() or "")
    end
end

-- Logique de mission throttlée : chaque frame n'accumule que le delta ; le
-- corps (tests de distance, scans d'ennemis, HUD) ne tourne qu'à ~12 Hz,
-- avec le delta cumulé — invisible en jeu, ~5× moins de travail par seconde.
registerForEvent("onUpdate", function(delta)
    if Coop.active() then Coop.sync(delta) end   -- s'auto-throttle (~0.4 s)
    if Mission.phase == "idle" or Mission.phase == "done" then
        coopFollow()   -- au repos, un joiner peut démarrer la mission de l'hôte
        return
    end
    Mission.pollAccum = Mission.pollAccum + delta
    if Mission.pollAccum < CONFIG.pollInterval then return end
    local dt = Mission.pollAccum
    Mission.pollAccum = 0

    -- Détection de mort / chargement : le joueur disparaît puis revient.
    -- Les entités dynamiques ne survivent pas au chargement alors que cet
    -- état Lua si — plutôt que de compléter la mission à vide, on l'annule
    -- proprement et le joueur peut la relancer.
    if not Game.GetPlayer() then
        Mission.playerMissing = true
        Mission.hud = nil
        return
    end
    if Mission.playerMissing then
        cancelMission(L.session_lost, false)   -- ne pas écraser l'heure du save chargé
        return
    end

    refreshPlayerPos()   -- une seule requête de position pour tout le tick
    if     Mission.phase == "intro"    then updateIntro(dt)
    elseif Mission.phase == "travel"   then updateTravel()
    elseif Mission.phase == "wave1"    then updateWave1(dt)
    elseif Mission.phase == "hack"     then updateHack(dt)
    elseif Mission.phase == "twist"    then updateTwist(dt)
    elseif Mission.phase == "boss"     then updateBoss(dt)
    elseif Mission.phase == "finale"   then updateFinale(dt)
    elseif Mission.phase == "epilogue" then updateEpilogue(dt)
    end
    coopPublish()         -- l'hôte diffuse l'état à l'équipe
    refreshHud()          -- prépare le payload du HUD pour les frames à venir
end)

registerHotkey("surtension_start", "SURTENSION — démarrer la mission / start mission", startMission)

registerHotkey("surtension_light", "SURTENSION — Finale : ☀ LUMIÈRE / LIGHT", function()
    chooseEnding("grid")
end)

registerHotkey("surtension_dark", "SURTENSION — Finale : 🌑 NOIR / DARK", function()
    chooseEnding("sell")
end)

registerHotkey("surtension_pos", "SURTENSION — afficher ma position / print position", function()
    local pos = playerPos()
    if pos then
        print(("[SURTENSION] Position : x = %.1f, y = %.1f, z = %.1f"):format(pos.x, pos.y, pos.z))
        screenMessage(L.pos_printed)
    end
end)

registerHotkey("surtension_abort", "SURTENSION — annuler la mission / abort mission", function()
    cancelMission(L.aborted)
end)

registerHotkey("surtension_coop_host", "SURTENSION — héberger une session co-op / host co-op", function()
    local code = Coop.host()
    screenMessage(L.coop_hosted:format(code))
    screenMessage(L.coop_relay)
end)

registerHotkey("surtension_coop_leave", "SURTENSION — quitter la session co-op / leave co-op", function()
    Coop.leave()
    screenMessage(L.coop_left)
end)

--------------------------------------------------------------------------
-- API publique pour la console CET
--------------------------------------------------------------------------

-- Phases accessibles à l'outil de test, avec leur vrai setup.
-- (Pour tester un épilogue : Jump("finale") puis Choose("grid"|"sell").)
local JUMP_TARGETS = {
    intro  = beginIntro,
    travel = beginTravel,
    wave1  = beginWave1,
    hack   = beginHack,
    twist  = beginTwist,
    boss   = beginBoss,
    finale = startFinale,
}

return {
    Start = startMission,
    GetPhase = function() return Mission.phase end,
    GetStats = function()
        return { runs = Stats.runs, wins = Stats.wins, endGrid = Stats.endGrid,
                 endSell = Stats.endSell, bestTime = Stats.bestTime }
    end,
    -- choix de fin depuis la console : Choose("grid"|"light"|"lumière") ou
    -- Choose("sell"|"dark"|"noir")
    Choose = chooseEnding,
    -- Co-op (session partagée : vagues d'équipe + fin votée)
    HostCoop = function(code, id) local c = Coop.host(code, id); screenMessage(L.coop_hosted:format(c)); return c end,
    JoinCoop = function(code, id) local c = Coop.join(code, id); screenMessage(L.coop_joined:format(c)); return c end,
    LeaveCoop = function() Coop.leave(); screenMessage(L.coop_left) end,
    CoopSync = function() Coop.syncNow() end,
    GetCoop = function()
        return { active = Coop.active(), role = Coop.role, code = Coop.code,
                 peers = Coop.peerCount(), teamRemaining = Coop.teamRemaining() }
    end,
    -- outil de test : saute à une phase avec son setup complet,
    -- ex. GetMod("surtension").Jump("boss")
    Jump = function(phase)
        local target = JUMP_TARGETS[tostring(phase or "")]
        if not target then
            local names = {}
            for name in pairs(JUMP_TARGETS) do table.insert(names, name) end
            table.sort(names)
            screenMessage(L.unknown_phase .. table.concat(names, ", "))
            return
        end
        cancelMission(nil)   -- teardown complet avant de rejouer une phase
        Mission.testRun = true   -- run de test : ni stats, ni record
        target()
        screenMessage(L.jumped_to .. Mission.phase)
    end,
}
