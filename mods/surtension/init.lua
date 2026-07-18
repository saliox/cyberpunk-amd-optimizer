--------------------------------------------------------------------------
-- SURTENSION 2.0 — mission custom pour Cyberpunk 2077
--------------------------------------------------------------------------
-- « Regina » te demande de couper un siphon sur le réseau d'Arroyo.
-- Sauf que l'appel était usurpé : le siphon était le pare-feu qui
-- retenait VOLT, une IA sauvage vivant dans le réseau électrique.
-- En le coupant, c'est TOI qui déclenches le blackout. Maelstrom
-- débarque avec GRIDLOCK, un cyberpsycho porteur du cœur de l'IA.
-- Après le boss : réinjecter le cœur et rallumer Night City,
-- ou le vendre et laisser la ville dans le noir. Ton choix.
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
    gridPos      = { x = -1548.0, y = -1002.0, z = 25.0 }, -- FIN A : console de réinjection
    sellPos      = { x = -1611.0, y = -882.0,  z = 22.0 }, -- FIN B : acheteur du cœur

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

    spawnRadius   = 12.0,  -- rayon de spawn autour de l'arène
    reachDistance = 15.0,  -- distance pour valider un point de mission
    hackDistance  = 4.0,   -- distance max pendant le piratage
    hackDuration  = 15.0,  -- secondes d'override (harceleurs à mi-course !)
    bossDelay     = 8.0,   -- les renforts arrivent d'abord, GRIDLOCK ensuite

    -- FIN A — « Rallumer Night City » (la vraie Regina te dédommage)
    rewardGridMoney   = 20000,
    rewardGridCred    = 600,
    rewardGridVehicle = "Vehicle.v_sport2_quadra_type66_avenger",
    -- FIN B — « La ville dort » (les eddies siphonnés par VOLT)
    rewardSellMoney = 60000,
    rewardSellCred  = 200,
    rewardSellItem  = "Items.Preset_Yinglong_Default", -- SMG intelligent EMP
}

local Mission = {
    phase = "idle", -- idle > intro > travel > wave1 > hack > twist > boss > choice > epilogue > done
    timer = 0,
    hackProgress = 0,
    harassersSpawned = false,
    bossSpawned = false,
    bossID = nil,
    ending = nil,          -- "grid" ou "sell"
    enemies = {},
    mappins = {},
    step = 0,              -- index de réplique (intro / twist / épilogue)
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

-- Grésillement de comms pendant le twist (sans conséquence si absent)
local function commsGlitch()
    pcall(function()
        Game.GetStatusEffectSystem():ApplyStatusEffect(
            Game.GetPlayer():GetEntityID(), "BaseStatusEffect.CommsNoiseJam")
    end)
    playSound("ui_glitch_start")
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
    if id then table.insert(Mission.enemies, id) end
    return id
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

local function isAlive(id)
    if not id then return false end
    local entity = Game.GetDynamicEntitySystem():GetEntity(id)
    return entity ~= nil and not entity:IsDead()
end

local function countAliveEnemies()
    local alive = 0
    for _, id in ipairs(Mission.enemies) do
        if isAlive(id) then alive = alive + 1 end
    end
    return alive
end

local function despawnEnemies()
    local system = Game.GetDynamicEntitySystem()
    for _, id in ipairs(Mission.enemies) do
        pcall(function() system:DeleteEntity(id) end)
    end
    Mission.enemies = {}
    Mission.bossID = nil
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
    { at = 17.0, text = "VOLT : Maelstrom arrive pour récupérer mon cœur. Ne les laisse pas faire… ou fais-en ce que tu veux." },
}

local EPILOGUE_GRID = {
    { at = 2.0, text = "RÉSEAU RESTAURÉ — Night City se rallume, bloc par bloc." },
    { at = 6.5, text = "APPEL ENTRANT — REGINA JONES (authentifié)" },
    { at = 9.0, text = "Regina : V ? C'est la VRAIE Regina. Je n'ai jamais passé cet appel… mais tu viens de sauver le district." },
    { at = 14.0, text = "Regina : Je te dois une explication — et un dédommagement. Regarde ton garage." },
}

local EPILOGUE_SELL = {
    { at = 2.0, text = "CŒUR VENDU — le convoyeur disparaît dans la nuit." },
    { at = 6.0, text = "VOLT : Marché conclu. Les eddies que j'ai siphonnés sont à toi." },
    { at = 11.0, text = "VOLT : Profite de la vue, V. Night City est tellement plus belle éteinte." },
}

-- Joue une liste de répliques minutées ; retourne true quand terminé
local function playLines(lines, delta, endAt)
    Mission.timer = Mission.timer + delta
    local nextLine = lines[Mission.step + 1]
    if nextLine and Mission.timer >= nextLine.at then
        Mission.step = Mission.step + 1
        screenMessage(nextLine.text)
        playSound("ui_menu_onpress")
    end
    return Mission.timer >= endAt
end

--------------------------------------------------------------------------
-- Déroulé de la mission
--------------------------------------------------------------------------

local function enterPhase(phase)
    Mission.phase = phase
    Mission.timer = 0
    Mission.step = 0
end

local function startMission()
    if Mission.phase ~= "idle" and Mission.phase ~= "done" then
        screenMessage("Mission SURTENSION déjà en cours.")
        return
    end
    despawnEnemies()
    clearMappins()
    Mission.hackProgress = 0
    Mission.harassersSpawned = false
    Mission.bossSpawned = false
    Mission.ending = nil
    enterPhase("intro")
    playSound("ui_phone_incoming_call")
    Game.SetTimeDilation(0.6)   -- ralenti "cinématique" pendant l'appel
end

local function updateIntro(delta)
    if playLines(INTRO_LINES, delta, 16.0) then
        Game.SetTimeDilation(0)
        enterPhase("travel")
        addMappin(CONFIG.objectivePos)
        playSound("ui_jingle_quest_update")
    end
end

local function updateTravel()
    if distanceTo(CONFIG.objectivePos) <= CONFIG.reachDistance then
        enterPhase("wave1")
        clearMappins()
        screenMessage("Maelstrom sur zone — élimine les hostiles !")
        playSound("ui_hacking_access_granted")
        spawnWave(CONFIG.wave1, CONFIG.objectivePos)
        pcall(function()  -- orage électrique sur le district
            Game.GetWeatherSystem():RequestNewWeather(TweakDBID.new("24h_weather_storm"))
        end)
    end
end

local function updateWave1(delta)
    Mission.timer = Mission.timer + delta
    if Mission.timer > 2.0 and countAliveEnemies() == 0 then
        enterPhase("hack")
        Mission.hackProgress = 0
        addMappin(CONFIG.objectivePos)
        screenMessage("Zone dégagée. Approche-toi du transformateur et lance l'override.")
        playSound("ui_jingle_quest_update")
    end
end

local function updateHack(delta)
    if distanceTo(CONFIG.objectivePos) <= CONFIG.hackDistance then
        Mission.hackProgress = Mission.hackProgress + delta
        Mission.timer = Mission.timer + delta

        -- surprise : des harceleurs débarquent à mi-piratage
        if not Mission.harassersSpawned
            and Mission.hackProgress >= CONFIG.hackDuration * 0.5 then
            Mission.harassersSpawned = true
            spawnWave(CONFIG.hackHarassers, CONFIG.objectivePos)
            screenMessage("⚠ PATROUILLE MAELSTROM — maintiens l'override sous le feu !")
            playSound("ui_hacking_access_denied")
        end

        if Mission.timer >= 2.0 then  -- progression toutes les ~2 s
            Mission.timer = 0
            local pct = math.floor(math.min(100, Mission.hackProgress / CONFIG.hackDuration * 100))
            screenMessage(("OVERRIDE DU SIPHON — %d%%"):format(pct))
            playSound("ui_hacking_hackloop")
        end

        if Mission.hackProgress >= CONFIG.hackDuration then
            -- LE TWIST : blackout immédiat + signal usurpé
            enterPhase("twist")
            clearMappins()
            commsGlitch()
            Game.SetTimeDilation(0.5)
            pcall(function() Game.GetTimeSystem():SetGameTimeByHMS(2, 0, 0) end)
            playSound("ui_hacking_access_granted")
        end
    else
        Mission.timer = Mission.timer + delta
        if Mission.timer >= 5.0 then
            Mission.timer = 0
            screenMessage("Reste près du transformateur pour maintenir l'override !")
        end
    end
end

local function updateTwist(delta)
    if playLines(TWIST_LINES, delta, 20.0) then
        Game.SetTimeDilation(0)
        enterPhase("boss")
        screenMessage("⚠ RENFORTS MAELSTROM — DÉFENDS LE CŒUR DE VOLT !")
        spawnWave(CONFIG.bossAdds, CONFIG.objectivePos)
        playSound("ui_hacking_access_denied")
    end
end

local function updateBoss(delta)
    Mission.timer = Mission.timer + delta

    -- GRIDLOCK arrive après les renforts, avec annonce
    if not Mission.bossSpawned and Mission.timer >= CONFIG.bossDelay then
        Mission.bossSpawned = true
        Mission.bossID = spawnAt(CONFIG.bossRecord,
            CONFIG.objectivePos.x + CONFIG.spawnRadius,
            CONFIG.objectivePos.y,
            CONFIG.objectivePos.z)
        screenMessage("⚠⚠ GRIDLOCK — CYBERPSYCHO PORTEUR DU CŒUR ⚠⚠")
        playSound("ui_jingle_relic_malfunction")
    end

    if Mission.bossSpawned and Mission.timer > CONFIG.bossDelay + 3.0
        and countAliveEnemies() == 0 then
        enterPhase("choice")
        screenMessage("CŒUR DE VOLT RÉCUPÉRÉ — à toi de décider.")
        playSound("ui_jingle_quest_update")
    end
end

local function updateChoice(delta)
    Mission.timer = Mission.timer + delta
    if Mission.step == 0 then
        Mission.step = 1
        -- deux mappins simultanés = deux fins
        addMappin(CONFIG.gridPos)                                       -- FIN A
        addMappin(CONFIG.sellPos, gamedataMappinVariant.ExclamationMarkVariant) -- FIN B
    end
    if Mission.step == 1 and Mission.timer >= 3.0 then
        Mission.step = 2
        screenMessage("FIN A — Console réseau : réinjecter le cœur, rallumer Night City (20 000 €$ + surprise de Regina)")
    end
    if Mission.step == 2 and Mission.timer >= 7.0 then
        Mission.step = 3
        screenMessage("FIN B — L'acheteur : vendre le cœur, la ville reste éteinte (60 000 €$)")
    end

    if distanceTo(CONFIG.gridPos) <= CONFIG.reachDistance then
        Mission.ending = "grid"
    elseif distanceTo(CONFIG.sellPos) <= CONFIG.reachDistance then
        Mission.ending = "sell"
    end

    if Mission.ending then
        clearMappins()
        despawnEnemies()
        enterPhase("epilogue")
        if Mission.ending == "grid" then
            -- Night City se rallume : aube + ciel dégagé
            pcall(function() Game.GetTimeSystem():SetGameTimeByHMS(6, 30, 0) end)
            pcall(function()
                Game.GetWeatherSystem():RequestNewWeather(TweakDBID.new("24h_weather_sunny"))
            end)
            Game.AddToInventory("Items.money", CONFIG.rewardGridMoney)
            pcall(function() Game.AddExp("StreetCred", CONFIG.rewardGridCred) end)
            -- la surprise de Regina : une Quadra Avenger dans ton garage
            pcall(function()
                Game.GetVehicleSystem():EnablePlayerVehicle(CONFIG.rewardGridVehicle, true, false)
            end)
        else
            Game.AddToInventory("Items.money", CONFIG.rewardSellMoney)
            Game.AddToInventory(CONFIG.rewardSellItem, 1)
            pcall(function() Game.AddExp("StreetCred", CONFIG.rewardSellCred) end)
        end
        screenMessage("MISSION ACCOMPLIE — SURTENSION")
        playSound("ui_jingle_quest_success")
    end
end

local function updateEpilogue(delta)
    local lines = Mission.ending == "grid" and EPILOGUE_GRID or EPILOGUE_SELL
    if playLines(lines, delta, 18.0) then
        enterPhase("done")
    end
end

--------------------------------------------------------------------------
-- Branchements CET
--------------------------------------------------------------------------

registerForEvent("onInit", function()
    print("[SURTENSION] Mission 2.0 chargée. Console : GetMod(\"surtension\").Start()")
end)

registerForEvent("onUpdate", function(delta)
    if Mission.phase == "idle" or Mission.phase == "done" or not Game.GetPlayer() then return end
    if     Mission.phase == "intro"    then updateIntro(delta)
    elseif Mission.phase == "travel"   then updateTravel()
    elseif Mission.phase == "wave1"    then updateWave1(delta)
    elseif Mission.phase == "hack"     then updateHack(delta)
    elseif Mission.phase == "twist"    then updateTwist(delta)
    elseif Mission.phase == "boss"     then updateBoss(delta)
    elseif Mission.phase == "choice"   then updateChoice(delta)
    elseif Mission.phase == "epilogue" then updateEpilogue(delta)
    end
end)

registerHotkey("surtension_start", "SURTENSION — démarrer la mission", startMission)

registerHotkey("surtension_pos", "SURTENSION — afficher ma position (console)", function()
    local pos = playerPos()
    if pos then
        print(("[SURTENSION] Position : x = %.1f, y = %.1f, z = %.1f"):format(pos.x, pos.y, pos.z))
        screenMessage("Position affichée dans la console CET.")
    end
end)

registerHotkey("surtension_abort", "SURTENSION — annuler la mission", function()
    despawnEnemies()
    clearMappins()
    Game.SetTimeDilation(0)
    Mission.phase = "idle"
    screenMessage("Mission SURTENSION annulée.")
end)

-- API publique pour la console CET
return {
    Start = startMission,
    GetPhase = function() return Mission.phase end,
    -- outil de test : saute à la phase voulue, ex. GetMod("surtension").Jump("choice")
    Jump = function(phase)
        despawnEnemies()
        clearMappins()
        Game.SetTimeDilation(0)
        Mission.hackProgress = 0
        Mission.harassersSpawned = false
        Mission.bossSpawned = false
        Mission.ending = nil
        enterPhase(phase or "intro")
        screenMessage("SURTENSION — saut vers la phase : " .. Mission.phase)
    end,
}
