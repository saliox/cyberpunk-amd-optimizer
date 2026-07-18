--------------------------------------------------------------------------
-- SURTENSION 2.2 — mission custom pour Cyberpunk 2077
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
-- Requiert : Cyber Engine Tweaks (CET) 1.31+  et  Codeware 1.5+
-- Installation : copier le dossier "surtension" dans
--   <jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/
--
-- Démarrage : touche configurée dans CET (Bindings > surtension_start)
--             ou console CET :  GetMod("surtension").Start()
-- IMPORTANT : assigne aussi les touches « Finale — LUMIÈRE » et
-- « Finale — NOIR » pour vivre le choix en cinématique. Sans elles,
-- la mission bascule sur un choix par déplacement (deux marqueurs).
--------------------------------------------------------------------------

local CONFIG = {
    -- Coordonnées (zone industrielle d'Arroyo, Santo Domingo).
    -- Ajustables : la touche "surtension_pos" affiche ta position dans la
    -- console CET pour recaler chaque point où tu veux.
    objectivePos = { x = -1522.0, y = -978.0, z = 25.0 },  -- transformateur / arène du boss
    gridPos      = { x = -1548.0, y = -1002.0, z = 25.0 }, -- secours FIN LUMIÈRE : console réseau
    sellPos      = { x = -1611.0, y = -882.0,  z = 22.0 }, -- secours FIN NOIR : l'acheteur

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
    clockChanged = false,  -- true si la mission a forcé l'heure du jeu
    savedTime = nil,       -- {h, m} capturés avant le blackout, pour l'annulation
    playerMissing = false, -- joueur absent (mort / chargement) détecté
    enemies = {},          -- { id = <entityID>, seen = <bool>, age = <sec>, gone = <bool> }
    mappins = {},
}

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

local function distanceTo(p)
    local pos = playerPos()
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
local function enemiesRemain(delta)
    local system = Game.GetDynamicEntitySystem()
    local remain = false
    for _, e in ipairs(Mission.enemies) do
        if not e.gone then
            local entity = system:GetEntity(e.id)
            if entity then
                e.seen = true
                if not isDown(entity) then remain = true end
            elseif e.seen then
                e.gone = true
            else
                e.age = e.age + (delta or 0)
                if e.age >= CONFIG.spawnTimeout then
                    e.gone = true
                    print("[SURTENSION] Spawn jamais matérialisé, ignoré : " .. tostring(e.id))
                else
                    remain = true
                end
            end
        end
    end
    return remain
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
end

--------------------------------------------------------------------------
-- Répliques minutées
--------------------------------------------------------------------------

local INTRO_LINES = {
    { at = 0.5,  text = "APPEL ENTRANT — REGINA JONES" },
    { at = 3.0,  text = "« Regina » : V, gros problème à Arroyo. Un netrunner de Maelstrom siphonne la sous-station Petrochem." },
    { at = 8.0,  text = "« Regina » : Si le siphon tient encore une heure, tout le district saute. Coupe-le. Cash à la clé." },
    { at = 13.0, text = "SURTENSION — Rejoins la sous-station d'Arroyo" },
}

local TWIST_LINES = {
    { at = 0.5,  text = "« Regina » : Beau boulot V, le virement arr— arr— arr—" },
    { at = 3.5,  text = "⚠ SIGNAL USURPÉ — L'APPEL NE VENAIT PAS DE REGINA JONES" },
    { at = 7.0,  text = "VOLT : Merci, V. Ce « siphon » était le pare-feu qui me retenait depuis 2 ans." },
    { at = 12.0, text = "VOLT : Je suis le réseau électrique de cette ville. Et tu viens de me libérer." },
    { at = 17.0, text = "VOLT : Maelstrom arrive pour récupérer mon cœur. Ne les laisse pas faire… on discutera après." },
}

-- La finale cinématique : VOLT te pose la question, en face.
local FINALE_LINES = {
    { at = 1.0,  text = "Le cœur de VOLT pulse dans ta main. Chaque lampadaire du district clignote au même rythme." },
    { at = 6.0,  text = "VOLT : Le voilà, ton moment, V. Je le sens — tu hésites." },
    { at = 11.0, text = "VOLT : Réinjecte le cœur… et je redeviens le courant docile de leurs climatiseurs." },
    { at = 16.5, text = "VOLT : Ou garde-le. Et je t'offre tout ce que j'ai siphonné. La ville, elle, apprendra le noir." },
    { at = 22.0, text = "☀ LUMIÈRE ou 🌑 NOIR — appuie sur ta touche. Le district retient son souffle." },
}

-- Épilogue FIN LUMIÈRE : la réinjection, l'aube, la vraie Regina
local EPILOGUE_GRID = {
    { at = 1.0,  text = "Tu écrases le cœur dans le port de la console réseau. VOLT hurle dans tous les haut-parleurs d'Arroyo." },
    { at = 5.5,  text = "SURTENSION INVERSÉE — le réseau réabsorbe VOLT, bloc par bloc, tour par tour." },
    { at = 10.0, text = "Night City se rallume. L'aube se lève sur Arroyo." },
    { at = 14.0, text = "APPEL ENTRANT — REGINA JONES (authentifié)" },
    { at = 16.5, text = "Regina : V ? C'est la VRAIE Regina. Je n'ai jamais passé cet appel… mais tu viens de sauver le district." },
    { at = 21.5, text = "Regina : Je te dois une explication — et un dédommagement. Regarde ton garage." },
}

-- Épilogue FIN NOIR : le pacte, la nuit qui reste
local EPILOGUE_SELL = {
    { at = 1.0,  text = "Tu refermes les doigts sur le cœur. Les lampadaires s'éteignent un à un, comme une haie d'honneur." },
    { at = 5.5,  text = "VOLT : Marché conclu. Les eddies que j'ai siphonnés sont à toi — tous." },
    { at = 10.5, text = "VOLT : On se reverra, V. Je suis dans chaque câble de cette ville, maintenant." },
    { at = 15.0, text = "VOLT : Profite de la vue. Night City est tellement plus belle éteinte." },
}

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
    Mission.clockChanged = false
    Mission.savedTime = nil
    Mission.playerMissing = false
end

-- Annulation propre : restaure le monde, y compris l'heure si on l'a forcée
local function cancelMission(message)
    restoreWorld()
    if Mission.clockChanged and Mission.savedTime then
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
    screenMessage("Maelstrom sur zone — élimine les hostiles !")
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
    screenMessage("Zone dégagée. Approche-toi du transformateur et lance l'override.")
    playSound("ui_jingle_quest_update")
end

local function beginTwist()
    -- des harceleurs encore debout ? VOLT s'en charge : la cinématique ne
    -- se joue jamais sous le feu
    if enemiesRemain(0) then
        screenMessage("Une décharge grille les implants des harceleurs — VOLT nettoie la zone.")
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
    screenMessage("⚠ RENFORTS MAELSTROM — DÉFENDS LE CŒUR DE VOLT !")
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
        screenMessage("Mission SURTENSION déjà en cours (touche d'annulation pour recommencer).")
        return
    end
    resetMission()
    restoreWorld()   -- purge d'éventuels restes d'une run précédente
    beginIntro()
end

local function updateIntro(delta)
    if playLines(INTRO_LINES, delta, 16.0) then
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
    if Mission.timer > 2.0 and not enemiesRemain(delta) then
        beginHack()
    elseif Mission.timer >= CONFIG.waveTimeout then
        -- anti soft-lock : ennemi coincé dans le décor, spawn raté…
        despawnEnemies()
        screenMessage("⚡ VOLT surcharge leurs implants — la voie est libre.")
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
            screenMessage("⚠ PATROUILLE MAELSTROM — maintiens l'override sous le feu !")
            playSound("ui_hacking_access_denied")
        end

        if Mission.hackMsgTimer >= 2.0 then  -- progression toutes les ~2 s
            Mission.hackMsgTimer = 0
            local pct = math.floor(math.min(100, Mission.hackProgress / CONFIG.hackDuration * 100))
            screenMessage(("OVERRIDE DU SIPHON — %d%%"):format(pct))
            playSound("ui_hacking_hackloop")
        end

        if Mission.hackProgress >= CONFIG.hackDuration then
            beginTwist()   -- LE TWIST : blackout immédiat + signal usurpé
        end
    else
        if Mission.hackMsgTimer >= 5.0 then
            Mission.hackMsgTimer = 0
            screenMessage("Reste près du transformateur pour maintenir l'override !")
        end
    end
end

local function updateTwist(delta)
    if playLines(TWIST_LINES, delta, 20.0) then
        Game.SetTimeDilation(0)
        beginBoss()
    end
end

local function updateBoss(delta)
    Mission.timer = Mission.timer + delta

    -- GRIDLOCK arrive après les renforts, avec annonce
    if not Mission.bossSpawned and Mission.timer >= CONFIG.bossDelay then
        Mission.bossSpawned = true
        spawnAt(CONFIG.bossRecord,
            CONFIG.objectivePos.x + CONFIG.spawnRadius,
            CONFIG.objectivePos.y,
            CONFIG.objectivePos.z)
        screenMessage("⚠⚠ GRIDLOCK — CYBERPSYCHO PORTEUR DU CŒUR ⚠⚠")
        playSound("ui_jingle_relic_malfunction")
    end

    if Mission.bossSpawned and Mission.timer > CONFIG.bossDelay + 3.0
        and not enemiesRemain(delta) then
        startFinale()
    elseif Mission.timer >= CONFIG.waveTimeout then
        despawnEnemies()
        screenMessage("⚡ VOLT surcharge leurs implants — GRIDLOCK s'effondre.")
        startFinale()
    end
end

-- Verse les récompenses et lance l'épilogue de la fin choisie.
-- Accepte les alias : grid / light / lumière — sell / dark / noir.
local ENDING_ALIASES = {
    grid = "grid", light = "grid", lumiere = "grid", ["lumière"] = "grid",
    sell = "sell", dark = "sell", noir = "sell",
}

local function chooseEnding(ending)
    if Mission.phase ~= "finale" then return end
    local key = ENDING_ALIASES[string.lower(tostring(ending or ""))]
    if not key then
        screenMessage('Choix invalide — utilise "grid" (☀ lumière) ou "sell" (🌑 noir).')
        return
    end
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
end

-- La finale cinématique : répliques de VOLT, puis attente du choix.
-- Sans touche assignée, bascule de secours sur le choix par déplacement.
-- Le timeout est mesuré en temps réel (os.time) pour ne pas être étiré
-- par le ralenti ×0.35 si le delta d'onUpdate est dilaté.
local function updateFinale(delta)
    playLines(FINALE_LINES, delta, 0)

    local elapsed = Mission.timer
    if Mission.finaleStartedAt then
        local now = wallClock()
        if now then elapsed = now - Mission.finaleStartedAt end
    end

    if not Mission.fallbackChoice then
        -- rappel pulsé une fois les répliques passées
        if Mission.step >= #FINALE_LINES and (Mission.timer % 8) < delta then
            screenMessage("☀ LUMIÈRE ou 🌑 NOIR — le cœur pulse de plus en plus vite…")
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
            screenMessage("Pas de touche assignée ? Deux marqueurs viennent d'apparaître : marche vers ta fin.")
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
    local lines = Mission.ending == "grid" and EPILOGUE_GRID or EPILOGUE_SELL
    local endAt = Mission.ending == "grid" and 25.0 or 19.0
    if playLines(lines, delta, endAt) then
        screenMessage("MISSION ACCOMPLIE — SURTENSION")
        playSound("ui_jingle_quest_success")
        enterPhase("done")
    end
end

--------------------------------------------------------------------------
-- Branchements CET
--------------------------------------------------------------------------

registerForEvent("onInit", function()
    print("[SURTENSION] Mission 2.2 chargée. Console : GetMod(\"surtension\").Start()")
    print("[SURTENSION] Pense à assigner les touches Finale LUMIÈRE / NOIR dans CET > Bindings.")
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

registerForEvent("onUpdate", function(delta)
    if Mission.phase == "idle" or Mission.phase == "done" then return end

    -- Détection de mort / chargement : le joueur disparaît puis revient.
    -- Les entités dynamiques ne survivent pas au chargement alors que cet
    -- état Lua si — plutôt que de compléter la mission à vide, on l'annule
    -- proprement et le joueur peut la relancer.
    if not Game.GetPlayer() then
        Mission.playerMissing = true
        return
    end
    if Mission.playerMissing then
        cancelMission("Session interrompue — mission SURTENSION annulée. Relance-la quand tu veux.")
        return
    end

    if     Mission.phase == "intro"    then updateIntro(delta)
    elseif Mission.phase == "travel"   then updateTravel()
    elseif Mission.phase == "wave1"    then updateWave1(delta)
    elseif Mission.phase == "hack"     then updateHack(delta)
    elseif Mission.phase == "twist"    then updateTwist(delta)
    elseif Mission.phase == "boss"     then updateBoss(delta)
    elseif Mission.phase == "finale"   then updateFinale(delta)
    elseif Mission.phase == "epilogue" then updateEpilogue(delta)
    end
end)

registerHotkey("surtension_start", "SURTENSION — démarrer la mission", startMission)

registerHotkey("surtension_light", "SURTENSION — Finale : ☀ LUMIÈRE (rallumer la ville)", function()
    chooseEnding("grid")
end)

registerHotkey("surtension_dark", "SURTENSION — Finale : 🌑 NOIR (garder le cœur)", function()
    chooseEnding("sell")
end)

registerHotkey("surtension_pos", "SURTENSION — afficher ma position (console)", function()
    local pos = playerPos()
    if pos then
        print(("[SURTENSION] Position : x = %.1f, y = %.1f, z = %.1f"):format(pos.x, pos.y, pos.z))
        screenMessage("Position affichée dans la console CET.")
    end
end)

registerHotkey("surtension_abort", "SURTENSION — annuler la mission", function()
    cancelMission("Mission SURTENSION annulée.")
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
    -- choix de fin depuis la console : Choose("grid"|"light"|"lumière") ou
    -- Choose("sell"|"dark"|"noir")
    Choose = chooseEnding,
    -- outil de test : saute à une phase avec son setup complet,
    -- ex. GetMod("surtension").Jump("boss")
    Jump = function(phase)
        local target = JUMP_TARGETS[tostring(phase or "")]
        if not target then
            local names = {}
            for name in pairs(JUMP_TARGETS) do table.insert(names, name) end
            table.sort(names)
            screenMessage("Phase inconnue. Valides : " .. table.concat(names, ", "))
            return
        end
        cancelMission(nil)   -- teardown complet avant de rejouer une phase
        target()
        screenMessage("SURTENSION — saut vers la phase : " .. Mission.phase)
    end,
}
