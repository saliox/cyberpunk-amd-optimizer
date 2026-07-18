--------------------------------------------------------------------------
-- SURTENSION — mission custom pour Cyberpunk 2077
--------------------------------------------------------------------------
-- Un netrunner de Maelstrom siphonne le réseau électrique d'Arroyo.
-- Regina te contacte : coupe le siphon avant que tout le district saute.
--
-- Requiert : Cyber Engine Tweaks (CET) 1.31+  et  Codeware 1.5+
-- Installation : copier le dossier "surtension" dans
--   <jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/
--
-- Démarrage : touche configurée dans CET (Bindings > surtension_start)
--             ou console CET :  GetMod("surtension").Start()
--------------------------------------------------------------------------

local CONFIG = {
    -- Coordonnées de la mission (zone industrielle d'Arroyo, Santo Domingo).
    -- Ajustables : la touche "surtension_pos" affiche ta position actuelle
    -- dans la console CET pour recaler chaque point où tu veux.
    objectivePos  = { x = -1522.0, y = -978.0, z = 25.0 },  -- transformateur à saboter
    extractionPos = { x = -1611.0, y = -882.0, z = 22.0 },  -- point d'extraction

    -- Ennemis (records TweakDB de Maelstrom, hostiles par défaut)
    wave1 = {
        "Character.maelstrom_grunt2_ranged2_copperhead_ma",
        "Character.maelstrom_grunt2_ranged2_copperhead_wa",
        "Character.maelstrom_grunt1_melee1_knife_ma",
        "Character.maelstrom_grunt2_ranged2_pulsar_ma",
    },
    wave2 = {
        "Character.maelstrom_grunt2_ranged2_copperhead_ma",
        "Character.maelstrom_grunt2_ranged2_pulsar_wa",
        "Character.maelstrom_grunt2_ranged2_copperhead_wa",
        "Character.maelstrom_grunt1_melee1_machete_ma",
        "Character.maelstrom_netrunner1_netrunner1_omaha_ma",
        "Character.maelstrom_grunt2_ranged2_pulsar_ma",
    },
    spawnRadius     = 12.0,   -- rayon de spawn autour de l'objectif
    reachDistance   = 15.0,   -- distance pour valider "arrivé sur zone"
    hackDistance    = 4.0,    -- distance pour pirater le transformateur
    hackDuration    = 12.0,   -- secondes de piratage (sous le feu ennemi !)
    rewardMoney     = 25000,  -- eddies
    rewardStreetCred = 400,   -- XP street cred
    rewardItem      = "Items.Preset_Yinglong_Default", -- SMG intelligent EMP, thème énergie
}

local Mission = {
    phase = "idle",   -- idle > intro > travel > wave1 > hack > wave2 > extract > done
    timer = 0,
    hackProgress = 0,
    enemies = {},     -- entityID Codeware des ennemis vivants
    mappinID = nil,
    introStep = 0,
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

local function setMappin(p)
    local data = MappinData.new()
    data.mappinType = TweakDBID.new("Mappins.DefaultStaticMappin")
    data.variant = gamedataMappinVariant.QuestGiverVariant
    data.visibleThroughWalls = true
    Mission.mappinID = Game.GetMappinSystem():RegisterMappin(data, vec4(p))
end

local function clearMappin()
    if Mission.mappinID then
        Game.GetMappinSystem():UnregisterMappin(Mission.mappinID)
        Mission.mappinID = nil
    end
end

--------------------------------------------------------------------------
-- Gestion des ennemis (Codeware DynamicEntitySystem)
--------------------------------------------------------------------------

local function spawnWave(records, center)
    local system = Game.GetDynamicEntitySystem()
    for i, record in ipairs(records) do
        -- répartis en cercle autour du point central
        local angle = (i / #records) * 2 * math.pi
        local spec = DynamicEntitySpec.new()
        spec.recordID = record
        spec.appearanceName = "random"
        spec.position = Vector4.new(
            center.x + math.cos(angle) * CONFIG.spawnRadius,
            center.y + math.sin(angle) * CONFIG.spawnRadius,
            center.z, 1.0)
        spec.orientation = Quaternion.new(0, 0, 0, 1)
        spec.persistState = false
        spec.persistSpawn = false
        spec.alwaysSpawned = true
        spec.tags = { "surtension_enemy" }
        local id = system:CreateEntity(spec)
        if id then table.insert(Mission.enemies, id) end
    end
end

local function countAliveEnemies()
    local system = Game.GetDynamicEntitySystem()
    local alive = 0
    for _, id in ipairs(Mission.enemies) do
        local entity = system:GetEntity(id)
        if entity and not entity:IsDead() then
            alive = alive + 1
        end
    end
    return alive
end

local function despawnEnemies()
    local system = Game.GetDynamicEntitySystem()
    for _, id in ipairs(Mission.enemies) do
        pcall(function() system:DeleteEntity(id) end)
    end
    Mission.enemies = {}
end

--------------------------------------------------------------------------
-- Déroulé de la mission
--------------------------------------------------------------------------

local INTRO_LINES = {
    { at = 0.5, text = "APPEL ENTRANT — REGINA JONES" },
    { at = 3.0, text = "Regina : V, on a un gros problème à Arroyo. Un netrunner de Maelstrom siphonne la sous-station Petrochem." },
    { at = 8.0, text = "Regina : Si le siphon tient encore une heure, tout le district saute. Coupe-le. Cash à la clé." },
    { at = 13.0, text = "SURTENSION — Rejoins la sous-station d'Arroyo" },
}

local function startMission()
    if Mission.phase ~= "idle" and Mission.phase ~= "done" then
        screenMessage("Mission SURTENSION déjà en cours.")
        return
    end
    Mission.phase = "intro"
    Mission.timer = 0
    Mission.introStep = 0
    Mission.hackProgress = 0
    despawnEnemies()
    clearMappin()
    playSound("ui_phone_incoming_call")
    -- léger ralenti "cinématique" pendant l'appel
    Game.SetTimeDilation(0.6)
end

local function updateIntro(delta)
    Mission.timer = Mission.timer + delta
    local nextLine = INTRO_LINES[Mission.introStep + 1]
    if nextLine and Mission.timer >= nextLine.at then
        Mission.introStep = Mission.introStep + 1
        screenMessage(nextLine.text)
        playSound("ui_menu_onpress")
    end
    if Mission.timer >= 16.0 then
        Game.SetTimeDilation(0)   -- fin du ralenti
        Mission.phase = "travel"
        Mission.timer = 0
        setMappin(CONFIG.objectivePos)
        playSound("ui_jingle_quest_update")
    end
end

local function updateTravel()
    if distanceTo(CONFIG.objectivePos) <= CONFIG.reachDistance then
        Mission.phase = "wave1"
        Mission.timer = 0
        clearMappin()
        screenMessage("Maelstrom sur zone — élimine les hostiles !")
        playSound("ui_hacking_access_granted")
        spawnWave(CONFIG.wave1, CONFIG.objectivePos)
        -- ambiance : orage électrique sur le district
        pcall(function()
            Game.GetWeatherSystem():RequestNewWeather(TweakDBID.new("24h_weather_storm"))
        end)
    end
end

local function updateWave1(delta)
    Mission.timer = Mission.timer + delta
    -- laisse 2 s aux spawns avant de compter
    if Mission.timer > 2.0 and countAliveEnemies() == 0 then
        Mission.phase = "hack"
        Mission.timer = 0
        Mission.hackProgress = 0
        setMappin(CONFIG.objectivePos)
        screenMessage("Zone dégagée. Approche-toi du transformateur et lance l'override.")
        playSound("ui_jingle_quest_update")
    end
end

local function updateHack(delta)
    if distanceTo(CONFIG.objectivePos) <= CONFIG.hackDistance then
        Mission.hackProgress = Mission.hackProgress + delta
        Mission.timer = Mission.timer + delta
        -- feedback de progression toutes les ~2 s
        if Mission.timer >= 2.0 then
            Mission.timer = 0
            local pct = math.floor(math.min(100, Mission.hackProgress / CONFIG.hackDuration * 100))
            screenMessage(("OVERRIDE DU SIPHON — %d%%"):format(pct))
            playSound("ui_hacking_hackloop")
        end
        if Mission.hackProgress >= CONFIG.hackDuration then
            Mission.phase = "wave2"
            Mission.timer = 0
            clearMappin()
            screenMessage("SIPHON COUPÉ — les renforts Maelstrom débarquent. TIENS LA POSITION !")
            playSound("ui_hacking_access_granted")
            spawnWave(CONFIG.wave2, CONFIG.objectivePos)
            -- le "blackout" : nuit noire immédiate sur Night City
            pcall(function() Game.GetTimeSystem():SetGameTimeByHMS(2, 0, 0) end)
        end
    else
        -- le joueur s'est éloigné : la progression gèle, petit rappel
        Mission.timer = Mission.timer + delta
        if Mission.timer >= 5.0 then
            Mission.timer = 0
            screenMessage("Reste près du transformateur pour maintenir l'override !")
        end
    end
end

local function updateWave2(delta)
    Mission.timer = Mission.timer + delta
    if Mission.timer > 2.0 and countAliveEnemies() == 0 then
        Mission.phase = "extract"
        Mission.timer = 0
        setMappin(CONFIG.extractionPos)
        screenMessage("Renforts éliminés. File au point d'extraction, Regina t'y attend.")
        playSound("ui_jingle_quest_update")
    end
end

local function finishMission()
    Mission.phase = "done"
    clearMappin()
    despawnEnemies()
    screenMessage("MISSION ACCOMPLIE — SURTENSION")
    playSound("ui_jingle_quest_success")
    -- Récompenses
    Game.AddToInventory("Items.money", CONFIG.rewardMoney)
    Game.AddToInventory(CONFIG.rewardItem, 1)
    pcall(function() Game.AddExp("StreetCred", CONFIG.rewardStreetCred) end)
    -- Petit épilogue différé via le timer de la phase "done"
    Mission.timer = 0
end

local function updateExtract()
    if distanceTo(CONFIG.extractionPos) <= CONFIG.reachDistance then
        finishMission()
    end
end

local function updateDone(delta)
    if Mission.timer >= 0 then
        Mission.timer = Mission.timer + delta
        if Mission.timer >= 4.0 then
            screenMessage("Regina : Beau boulot, V. Le district te doit une nuit au frais. Virement effectué.")
            Mission.timer = -1  -- épilogue joué une seule fois
        end
    end
end

--------------------------------------------------------------------------
-- Branchements CET
--------------------------------------------------------------------------

registerForEvent("onInit", function()
    print("[SURTENSION] Mission chargée. Console : GetMod(\"surtension\").Start()")
end)

registerForEvent("onUpdate", function(delta)
    if Mission.phase == "idle" or not Game.GetPlayer() then return end
    if     Mission.phase == "intro"   then updateIntro(delta)
    elseif Mission.phase == "travel"  then updateTravel()
    elseif Mission.phase == "wave1"   then updateWave1(delta)
    elseif Mission.phase == "hack"    then updateHack(delta)
    elseif Mission.phase == "wave2"   then updateWave2(delta)
    elseif Mission.phase == "extract" then updateExtract()
    elseif Mission.phase == "done"    then updateDone(delta)
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
    clearMappin()
    Game.SetTimeDilation(0)
    Mission.phase = "idle"
    screenMessage("Mission SURTENSION annulée.")
end)

-- API publique pour la console CET
return {
    Start = startMission,
    GetPhase = function() return Mission.phase end,
}
