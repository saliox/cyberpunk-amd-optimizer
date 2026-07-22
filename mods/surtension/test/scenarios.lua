--------------------------------------------------------------------------
-- Scénarios de simulation de SURTENSION (utilise test/stubs.lua)
-- Chaque scénario tourne dans un runtime Lua ET un dossier frais.
--------------------------------------------------------------------------

local OBJ  = { x = -1522, y = -978,  z = 25 }
local GRID = { x = -1548, y = -1002, z = 25 }
local SELL = { x = -1611, y = -882,  z = 22 }

-- Joue le déroulé nominal jusqu'à la phase demandée (incluse)
local function playTo(target)
    loadMod()
    MOD.Start()
    expect(MOD.GetPhase() == "intro", "intro attendue, obtenu " .. MOD.GetPhase())
    if target == "intro" then return end

    tickFor(17)
    expect(MOD.GetPhase() == "travel", "travel attendue, obtenu " .. MOD.GetPhase())
    if target == "travel" then return end

    teleport(OBJ); tick(0.1)
    expect(MOD.GetPhase() == "wave1", "wave1 attendue, obtenu " .. MOD.GetPhase())
    if target == "wave1" then return end

    tickFor(3)          -- spawns matérialisés
    killAll()
    tickFor(1)
    expect(MOD.GetPhase() == "hack", "hack attendue, obtenu " .. MOD.GetPhase())
    if target == "hack" then return end

    tickFor(9)          -- harceleurs à 50 %
    killAll()
    tickFor(8)          -- override terminé à 15 s
    expect(MOD.GetPhase() == "twist", "twist attendue, obtenu " .. MOD.GetPhase())
    if target == "twist" then return end

    tickFor(21)
    expect(MOD.GetPhase() == "boss", "boss attendue, obtenu " .. MOD.GetPhase())
    if target == "boss" then return end

    tickFor(10)         -- renforts + GRIDLOCK (spawné à 8 s, matérialisé 8.5 s)
    killAll()
    tickFor(3)
    expect(MOD.GetPhase() == "finale", "finale attendue, obtenu " .. MOD.GetPhase())
end

SCENARIOS = {}

table.insert(SCENARIOS, { name = "run complète — fin LUMIÈRE (hotkey)", fn = function()
    playTo("finale")
    expect(SIM.effects["GameplayRestriction.NoMovement"], "verrou de mouvement absent en finale")
    expect(SIM.effects["BaseStatusEffect.CommsNoiseJam"], "brouillage absent en finale")
    expect(SIM.dilation == 0.35, "ralenti de finale absent")

    press("surtension_light")
    expect(MOD.GetPhase() == "epilogue", "épilogue attendu")
    expect(SIM.inventory["Items.money"] == 20000, "récompense LUMIÈRE incorrecte")
    expect(SIM.vehicles["Vehicle.v_sport2_quadra_type66_avenger"], "véhicule non débloqué")
    expect(not SIM.effects["GameplayRestriction.NoMovement"], "verrou non retiré")
    expect(not SIM.effects["BaseStatusEffect.CommsNoiseJam"], "brouillage non retiré")
    expect(SIM.dilation == 0, "dilatation non réinitialisée")
    local last = SIM.timeSets[#SIM.timeSets]
    expect(last.h == 6 and last.m == 30, "aube non appliquée")
    expect(sawWeather("set:24h_weather_sunny"), "météo dégagée non demandée")

    tickFor(27)
    expect(MOD.GetPhase() == "done", "done attendue, obtenu " .. MOD.GetPhase())
    expect(sawMessage("MISSION ACCOMPLIE"), "message de fin absent")
    expect(sawMessage("⏱"), "chrono absent du message de fin")
    local s = MOD.GetStats()
    expect(s.runs == 1 and s.wins == 1 and s.endGrid == 1, "stats incorrectes")
    expect(s.bestTime > 0, "bestTime non enregistré")
    expect(activeMappins() == 0, "mappins non nettoyés")
end })

table.insert(SCENARIOS, { name = "fin NOIR via choix de secours (marche)", fn = function()
    playTo("finale")
    tickFor(37)   -- finaleTimeout = 35 s (horloge murale)
    expect(not SIM.effects["GameplayRestriction.NoMovement"], "verrou non levé au secours")
    expect(SIM.dilation == 0, "ralenti non levé au secours")
    expect(activeMappins() == 2, "les 2 marqueurs de secours manquent")
    expect(sawMessage("marqueurs"), "message de secours absent")

    teleport(SELL); tick(0.2)
    expect(MOD.GetPhase() == "epilogue", "épilogue attendu après marche vers NOIR")
    expect(SIM.inventory["Items.money"] == 60000, "récompense NOIR incorrecte")
    expect(SIM.inventory["Items.Preset_Yinglong_Default"] == 1, "Yinglong absent")
    -- pas d'aube en fin NOIR
    local last = SIM.timeSets[#SIM.timeSets]
    expect(not (last.h == 6 and last.m == 30), "l'aube ne doit pas se lever en fin NOIR")

    tickFor(21)
    expect(MOD.GetPhase() == "done")
    local s = MOD.GetStats()
    expect(s.endSell == 1 and s.wins == 1, "stats fin NOIR incorrectes")
end })

table.insert(SCENARIOS, { name = "takedowns non létaux : la vague compte les neutralisés", fn = function()
    playTo("wave1")
    tickFor(3)
    defeatAll()   -- inconscients, PAS morts
    tickFor(1)
    expect(MOD.GetPhase() == "hack", "vague non validée avec des ennemis neutralisés")
end })

table.insert(SCENARIOS, { name = "spawns jamais matérialisés : timeout et déblocage", fn = function()
    loadMod()
    SIM.spawnDelay = math.huge
    MOD.Start()
    tickFor(17); teleport(OBJ); tick(0.1)
    expect(MOD.GetPhase() == "wave1")
    tickFor(21)   -- spawnTimeout = 20 s
    expect(MOD.GetPhase() == "hack", "mission bloquée par des spawns fantômes")
end })

table.insert(SCENARIOS, { name = "ennemi injoignable : garde-fou waveTimeout", fn = function()
    playTo("wave1")
    tickFor(181)  -- personne n'est tué
    expect(MOD.GetPhase() == "hack", "waveTimeout inopérant")
    expect(sawMessage("surcharge"), "message de surcharge absent")
end })

table.insert(SCENARIOS, { name = "mort/rechargement en plein boss : annulation propre", fn = function()
    playTo("boss")
    tickFor(2)
    SIM.player.present = false
    tickFor(1)
    SIM.player.present = true
    tick(0.1)
    expect(MOD.GetPhase() == "idle", "mission non annulée après perte de session")
    expect(sawMessage("Session interrompue"), "message de session absent")
    expect(not SIM.effects["BaseStatusEffect.CommsNoiseJam"], "brouillage non purgé")
    expect(SIM.dilation == 0, "dilatation non purgée")
    -- l'heure de la run abandonnée ne doit PAS être restaurée sur le save chargé
    local last = SIM.timeSets[#SIM.timeSets]
    expect(last.h == 2, "l'horloge du save chargé a été écrasée (restauration indue)")
end })

table.insert(SCENARIOS, { name = "abandon volontaire au twist : monde restauré, heure comprise", fn = function()
    playTo("twist")
    expect(SIM.effects["BaseStatusEffect.CommsNoiseJam"], "brouillage attendu au twist")
    press("surtension_abort")
    expect(MOD.GetPhase() == "idle")
    expect(not SIM.effects["BaseStatusEffect.CommsNoiseJam"], "brouillage non retiré à l'abandon")
    expect(SIM.dilation == 0, "dilatation non réinitialisée à l'abandon")
    local last = SIM.timeSets[#SIM.timeSets]
    expect(last.h == 14 and last.m == 0, "heure pré-mission non restaurée à l'abandon")
    expect(sawWeather("reset"), "météo non rendue au cycle naturel")
end })

table.insert(SCENARIOS, { name = "Jump : liste blanche, setup complet, run de test sans stats", fn = function()
    loadMod()
    MOD.Jump("finalle")   -- typo
    expect(MOD.GetPhase() == "idle", "une phase inconnue ne doit rien changer")
    expect(sawMessage("Phase inconnue"), "message de phase inconnue absent")

    MOD.Jump("boss")
    expect(MOD.GetPhase() == "boss")
    expect(spawnedCount() >= 4, "Jump(boss) doit spawner les renforts")

    MOD.Jump("finale")
    MOD.Choose("sell")
    expect(SIM.inventory["Items.money"] == 60000, "récompense du test absente")
    local s = MOD.GetStats()
    expect(s.wins == 0 and s.runs == 0 and s.bestTime == 0,
        "une run de test (Jump) ne doit jamais compter dans les stats")
end })

table.insert(SCENARIOS, { name = "Choose : validation stricte + alias", fn = function()
    loadMod()
    MOD.Jump("finale")
    MOD.Choose("banana")
    expect(MOD.GetPhase() == "finale", "un choix invalide ne doit pas conclure")
    expect(sawMessage("Choix invalide"), "message de choix invalide absent")
    MOD.Choose("light")   -- alias de grid
    expect(MOD.GetPhase() == "epilogue", "alias 'light' non accepté")
    expect(SIM.vehicles["Vehicle.v_sport2_quadra_type66_avenger"], "fin LUMIÈRE non appliquée via alias")
end })

table.insert(SCENARIOS, { name = "stats : persistance disque et garde-fou 64 Ko", fn = function()
    -- run complète pour écrire stats.json
    playTo("finale")
    press("surtension_dark")
    tickFor(21)
    expect(MOD.GetPhase() == "done")

    -- rechargement du mod : les stats reviennent du disque
    local mod2 = loadMod()
    local s = mod2.GetStats()
    expect(s.runs == 1 and s.wins == 1 and s.endSell == 1, "stats non persistées")

    -- fichier énorme : ignoré sans geler
    local f = io.open("stats.json", "w")
    f:write(string.rep("x", 100000))
    f:close()
    local mod3 = loadMod()
    expect(mod3.GetStats().runs == 0, "un stats.json corrompu doit être ignoré")
    expect(sawLog("anormalement gros"), "log du garde-fou absent")
end })

table.insert(SCENARIOS, { name = "HUD : équilibre ImGui, panne isolée, écran de mort", fn = function()
    playTo("travel")
    draw()
    expect(SIM.imgui.push == SIM.imgui.pop, "pile de styles ImGui déséquilibrée")
    expect(SIM.imgui.beginN == SIM.imgui.endN, "Begin/End ImGui déséquilibrés")

    -- pas de HUD par-dessus l'écran de mort
    local pushesBefore = SIM.imgui.push
    SIM.player.present = false
    draw()
    expect(SIM.imgui.push == pushesBefore, "le HUD ne doit pas se dessiner sans joueur")
    SIM.player.present = true

    -- une erreur ImGui coupe le HUD proprement (log unique, pile rééquilibrée)
    teleport(OBJ); tick(0.1)      -- wave1
    tickFor(3); killAll(); tickFor(1)   -- hack
    expect(MOD.GetPhase() == "hack")
    SIM.imgui.progressThrows = true
    draw()
    expect(sawLog("HUD désactivé"), "panne HUD non loguée")
    expect(SIM.imgui.push == SIM.imgui.pop, "pile non rééquilibrée après panne")
    expect(SIM.imgui.beginN == SIM.imgui.endN, "Begin/End non rééquilibrés après panne")
    local pushes = SIM.imgui.push
    draw()
    expect(SIM.imgui.push == pushes, "le HUD doit rester coupé après une panne")
end })

table.insert(SCENARIOS, { name = "hitch de frame : les répliques du twist ne se perdent pas", fn = function()
    playTo("twist")
    tick(25)   -- énorme delta d'un coup
    expect(MOD.GetPhase() == "boss", "le twist doit se conclure après le hitch")
    expect(sawMessage("on discutera après"), "la dernière réplique du twist a été perdue")
end })

table.insert(SCENARIOS, { name = "négatif : les touches de finale sont inertes hors finale", fn = function()
    playTo("travel")
    press("surtension_light")
    press("surtension_dark")
    expect(MOD.GetPhase() == "travel", "un choix de fin hors finale ne doit rien faire")
    expect((SIM.inventory["Items.money"] or 0) == 0, "récompense versée hors finale")
end })

table.insert(SCENARIOS, { name = "négatif : la vague ne se valide pas tant qu'il reste des vivants", fn = function()
    playTo("wave1")
    tickFor(6)   -- spawns matérialisés, personne n'est tué
    expect(MOD.GetPhase() == "wave1", "la vague ne doit pas se valider avec des hostiles vivants")
    killAll()
    tickFor(1)
    expect(MOD.GetPhase() == "hack", "la vague doit se valider une fois les hostiles à terre")
end })

table.insert(SCENARIOS, { name = "piratage : gel à distance, rappel, reprise", fn = function()
    playTo("hack")
    teleport({ x = OBJ.x + 60, y = OBJ.y, z = OBJ.z })
    tickFor(6)
    expect(MOD.GetPhase() == "hack", "la progression ne doit pas avancer à distance")
    expect(sawMessage("Reste près du transformateur"), "rappel de distance absent")
    teleport(OBJ)
    tickFor(16)
    expect(MOD.GetPhase() == "twist", "le piratage doit aboutir après le retour")
end })

-- CO-OP -------------------------------------------------------------------
-- Le relais réseau est simulé : on écrit coop_in.json (ce que le relais
-- livrerait) et on lit coop_out.json (ce que le mod publie).

function writeCoopIn(o)
    o = o or {}
    local f = io.open("coop_in.json", "w")
    f:write(string.format(
        '{"schema":1,"code":"T","host":"h","peerCount":%d,"mission":"%s",' ..
        '"phaseIndex":%d,"phaseType":"%s","objective":"%s",' ..
        '"teamRemaining":%d,"resolved":"%s","hostTs":1,' ..
        '"selfPingMs":%d,"worstPingMs":%d}',
        o.peerCount or 2, o.mission or "", o.phaseIndex or 0, o.phaseType or "",
        o.objective or "", o.teamRemaining or 0, o.resolved or "",
        o.selfPingMs or 0, o.worstPingMs or 0))
    f:close()
end

function readCoopOut()
    local f = io.open("coop_out.json", "r")
    if not f then return "" end
    local raw = f:read("*a"); f:close()
    return raw or ""
end

-- amène l'hôte jusqu'à la vague 1
local function toWave1()
    tickFor(17)                          -- intro
    teleport(OBJ); tick(0.1)             -- arrive sur zone -> wave1
    expect(MOD.GetPhase() == "wave1", "wave1 attendue, obtenu " .. MOD.GetPhase())
end

table.insert(SCENARIOS, { name = "co-op : off par defaut (solo intact)", fn = function()
    loadMod()
    local c = MOD.GetCoop()
    expect(not c.active, "co-op off par defaut")
    expect(c.teamRemaining == nil, "teamRemaining nil en solo")
end })

table.insert(SCENARIOS, { name = "co-op : la vague 1 attend que l'EQUIPE ait nettoye", fn = function()
    loadMod()
    MOD.HostCoop("T", "h")
    MOD.Start()
    toWave1()
    tickFor(3)                           -- spawns materialises
    writeCoopIn({ teamRemaining = 4, mission = "surtension" })
    MOD.CoopSync()
    killAll()
    tickFor(2)
    expect(MOD.GetPhase() == "wave1", "la vague ne doit PAS avancer tant que l'equipe n'a pas nettoye")
    writeCoopIn({ teamRemaining = 0, mission = "surtension" })
    MOD.CoopSync()
    tickFor(1)
    expect(MOD.GetPhase() == "hack", "la vague doit avancer une fois l'equipe au complet")
end })

table.insert(SCENARIOS, { name = "co-op : l'hote publie sa phase dans coop_out", fn = function()
    loadMod()
    MOD.HostCoop("T", "h")
    MOD.Start()
    toWave1()
    tick(0.5)
    MOD.CoopSync()
    local raw = readCoopOut()
    expect(raw:find('"role":"host"'), "coop_out devrait indiquer le role hote")
    expect(raw:find('"mission":"surtension"'), "coop_out devrait publier la mission")
    expect(raw:find('"phaseType":"wave1"'), "coop_out devrait publier la phase")
end })

table.insert(SCENARIOS, { name = "co-op : la fin se resout par VOTE (Lumiere/Noir)", fn = function()
    loadMod()
    MOD.HostCoop("T", "h")
    MOD.Jump("finale")                   -- droit a la finale (run de test)
    expect(MOD.GetPhase() == "finale", "finale attendue")
    press("surtension_light")            -- en co-op : c'est un VOTE
    expect(MOD.GetPhase() == "finale", "un vote ne doit pas conclure immediatement")
    expect(sawMessage("Vote"), "message de vote absent")
    expect(readCoopOut():find('"vote":"grid"'), "le vote grid devrait etre publie")
    writeCoopIn({ mission = "surtension", resolved = "grid" })
    MOD.CoopSync()
    tickFor(1)
    expect(MOD.GetPhase() == "epilogue" or MOD.GetPhase() == "done",
        "la fin resolue par vote doit s'appliquer")
end })

table.insert(SCENARIOS, { name = "co-op : le joiner suit la mission de l'hote", fn = function()
    loadMod()
    MOD.JoinCoop("T", "j")
    writeCoopIn({ mission = "surtension" })
    MOD.CoopSync()
    tick(0.1)
    expect(MOD.GetPhase() ~= "idle", "le joiner aurait du demarrer la mission")
end })

table.insert(SCENARIOS, { name = "co-op : ping eleve -> avertissement discret de latence", fn = function()
    loadMod()
    MOD.HostCoop("T", "h")
    MOD.Start()
    toWave1()
    writeCoopIn({ teamRemaining = 3, mission = "surtension", worstPingMs = 200, selfPingMs = 0 })
    MOD.CoopSync()
    tick(0.1)
    draw()
    expect(sawHudText("200"), "l'avertissement devrait afficher le ping du joueur")
    expect(sawHudText("Latence") or sawHudText("Latency"),
        "l'avertissement de latence devrait apparaitre au-dela du seuil")
end })

table.insert(SCENARIOS, { name = "co-op : ping correct -> aucun avertissement", fn = function()
    loadMod()
    MOD.HostCoop("T", "h")
    MOD.Start()
    toWave1()
    writeCoopIn({ teamRemaining = 3, mission = "surtension", worstPingMs = 35, selfPingMs = 0 })
    MOD.CoopSync()
    tick(0.1)
    draw()
    expect(not sawHudText("Latence") and not sawHudText("Latency"),
        "aucun avertissement quand le ping est bon")
end })

table.insert(SCENARIOS, { name = "co-op : pas d'avertissement de ping en solo", fn = function()
    loadMod()
    MOD.Start()
    toWave1()
    tick(0.1)
    draw()
    expect(not sawHudText("Latence") and not sawHudText("Latency"),
        "le solo ne doit jamais afficher d'avertissement de latence")
end })

table.insert(SCENARIOS, { name = "co-op : quitter retablit le solo", fn = function()
    loadMod()
    MOD.HostCoop("T", "h")
    expect(MOD.GetCoop().active, "session active")
    MOD.LeaveCoop()
    expect(not MOD.GetCoop().active, "quitter desactive le co-op")
end })
