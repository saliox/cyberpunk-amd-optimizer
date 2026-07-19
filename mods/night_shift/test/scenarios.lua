--------------------------------------------------------------------------
-- Scénarios de simulation de NIGHT SHIFT (réutilise les stubs SURTENSION)
-- Le pilote autoplay() sait terminer n'importe quelle mission en lisant
-- GetPhaseInfo() — même moteur que jouerait un humain, en accéléré.
--------------------------------------------------------------------------

-- Par défaut les tests jouent en sélection libre : les tests de mécanique
-- et de conséquences ne dépendent pas du déverrouillage de campagne, qui
-- est couvert par des scénarios dédiés (lesquels réactivent le mode
-- campagne avec SetFreePlay(false)).
local _origLoadMod = loadMod
function loadMod()
    local m = _origLoadMod()
    m.SetFreePlay(true)
    return m
end

-- Invariants de fin : le monde doit être rendu propre
local function expectCleanWorld(context)
    context = context and (" [" .. context .. "]") or ""
    expect(not SIM.effects["GameplayRestriction.NoMovement"], "verrou de mouvement résiduel" .. context)
    expect(not SIM.effects["BaseStatusEffect.CommsNoiseJam"], "brouillage résiduel" .. context)
    expect(SIM.dilation == 0 or SIM.dilation == nil, "dilatation résiduelle" .. context)
    expect(activeMappins() == 0, "mappins résiduels" .. context)
    local live = 0
    for _, e in pairs(SIM.entities) do
        if not e.deleted and not e.dead and not e.defeated then live = live + 1 end
    end
    expect(live == 0, "entités vivantes résiduelles" .. context)
end

-- Joue une mission de bout en bout via l'API publique.
-- choiceMode : "a" | "b" | "walk_a" | "walk_b" | "timeout" (fin secrète)
function autoplay(missionIndex, choiceMode)
    choiceMode = choiceMode or "a"
    NS = loadMod()
    expect(NS.Start(missionIndex), "démarrage refusé pour la mission " .. tostring(missionIndex))
    local guard = 0
    while NS.GetStatus() ~= "done" and NS.GetStatus() ~= "idle" do
        guard = guard + 1
        expect(guard < 20000, "autoplay bloqué (mission " .. tostring(missionIndex)
            .. ", phase " .. tostring(NS.GetPhaseInfo().type) .. ")")
        local info = NS.GetPhaseInfo()
        if info.status == "epilogue" then
            tick(0.5)
        elseif info.type == "dialogue" then
            tick(0.5)
        elseif info.type == "goto" or info.type == "race" or info.type == "collect" then
            if info.target then teleport(info.target) end
            tick(0.2)
        elseif info.type == "hold" then
            if info.target then teleport(info.target) end
            tick(0.5)
            killAll()   -- on abat les harceleurs dès qu'ils apparaissent
        elseif info.type == "wave" or info.type == "boss" or info.type == "defend" then
            tick(0.5)
            killAll()
        elseif info.type == "choice" then
            if choiceMode == "a" or choiceMode == "b" then
                press("ns_choice_" .. choiceMode)
            elseif choiceMode == "timeout" then
                tickFor(50)   -- laisse le timeout (45 s max) s'écouler
            elseif choiceMode == "walk_a" or choiceMode == "walk_b" then
                tickFor(40)   -- déclenche la bascule marche
                local i2 = NS.GetPhaseInfo()
                local target = (choiceMode == "walk_a") and i2.optionA or i2.optionB
                expect(target, "cible de choix par marche absente")
                teleport(target)
                tick(0.2)
            end
        else
            tick(0.5)
        end
    end
    expect(NS.GetStatus() == "done", "mission " .. tostring(missionIndex)
        .. " non terminée (statut " .. NS.GetStatus() .. ")")
    expectCleanWorld("mission " .. tostring(missionIndex))
    local id = NS.GetMissionId(missionIndex)
    local stats = NS.GetStats()
    expect((stats["done_" .. id] or 0) >= 1, "complétion non comptée pour " .. id)
    expect(sawMessage("MISSION ACCOMPLIE") or sawMessage("MISSION ACCOMPLISHED"),
        "message de fin absent pour " .. id)
    return stats
end

SCENARIOS = {}

-- Les 15 missions, de bout en bout (choix A par défaut quand il y en a un)
for i = 1, 15 do
    table.insert(SCENARIOS, {
        name = string.format("mission %02d : autoplay complet", i),
        fn = function() autoplay(i) end,
    })
end

-- Variantes de choix ------------------------------------------------------

table.insert(SCENARIOS, { name = "ns07 : choix B (vendre le shard) au hotkey", fn = function()
    local stats = autoplay(7, "b")
    expect(SIM.inventory["Items.money"] == 22000, "récompense du choix B incorrecte")
end })

table.insert(SCENARIOS, { name = "ns09 : choix B par MARCHE (secours sans touche)", fn = function()
    autoplay(9, "walk_b")
    expect(SIM.inventory["Items.money"] == 4000, "récompense du choix B (marche) incorrecte")
    expect(sawMessage("clignotent") or sawMessage("blink"), "épilogue du choix B absent")
end })

table.insert(SCENARIOS, { name = "ns15 : FIN SECRÈTE déblocable — méritée par 2 choix Signal", fn = function()
    -- on gagne la confiance de VOLT : ns09 B (épargner la secte) + ns14 B (laisser chanter)
    autoplay(9, "b")
    autoplay(14, "b")
    local align = NS.GetAlignment()
    expect(align.signal == 2, "alignement Signal attendu à 2, obtenu " .. tostring(align.signal))
    SIM.inventory = {}   -- isole les récompenses de CODA
    autoplay(15, "timeout")
    expect(sawMessage("COMMUNION"), "fin secrète non déclenchée malgré l'alignement")
    expect(sawMessage("je te couvre") or sawMessage("got you"), "intro variante Signal absente")
    expect(sawMessage("Pas ceux-là") or sawMessage("Not these ones"), "l'assistance de VOLT au boss est absente")
    expect(SIM.inventory["Items.Preset_Yinglong_Default"] == 1, "récompense secrète absente")
    expect((SIM.inventory["Items.money"] or 0) == 0, "la fin secrète ne paie pas en eddies")
end })

table.insert(SCENARIOS, { name = "ns15 : fin secrète VERROUILLÉE sans alignement (secours marche)", fn = function()
    NS = loadMod()
    NS.Start(15)
    local guard = 0
    while NS.GetStatus() == "running" and NS.GetPhaseInfo().type ~= "choice" do
        guard = guard + 1
        expect(guard < 20000, "CODA bloquée avant le choix")
        local info = NS.GetPhaseInfo()
        if info.type == "goto" then teleport(info.target); tick(0.2)
        elseif info.type == "boss" then tick(0.5); killAll()
        else tick(0.5) end
    end
    expect(sawMessage("Débrouille-toi") or sawMessage("Handle it"), "intro variante Marché/neutre absente")
    tickFor(50)   -- timeout 45 s dépassé
    expect(NS.GetStatus() == "running", "sans alignement, l'attente ne doit PAS conclure la mission")
    expect(NS.GetPhaseInfo().walk == true, "le secours par marche doit s'activer à la place")
    expect(not sawMessage("COMMUNION"), "la fin secrète ne doit pas être accessible sans la mériter")
    NS.Abort()
end })

table.insert(SCENARIOS, { name = "ns15 : fin A bonifiée par la fidélité (caches de VOLT)", fn = function()
    autoplay(9, "b")
    autoplay(14, "b")
    SIM.inventory = {}
    autoplay(15, "a")
    expect(SIM.inventory["Items.money"] == 25000,
        "fin A + Signal>=2 : 15000 + 10000 de bonus attendus, obtenu " .. tostring(SIM.inventory["Items.money"]))
    expect(sawMessage("caches") or sawMessage("stashes"), "message du bonus de fidélité absent")
end })

table.insert(SCENARIOS, { name = "ns15 : fin A au hotkey (VOLT s'éteint en paix)", fn = function()
    autoplay(15, "a")
    expect(SIM.inventory["Items.money"] == 15000, "récompense fin A incorrecte")
    expect(sawMessage("la fin") or sawMessage("the ending"), "épilogue fin A absent")
end })

-- Conséquences croisées entre missions ------------------------------------

table.insert(SCENARIOS, { name = "conséquence : ns07 B → le Courtier te reconnaît et renforce ns12", fn = function()
    autoplay(7, "b")   -- vendre le shard au marché noir
    local before = spawnedCount()
    autoplay(12)
    expect(sawMessage("déjà fait affaire") or sawMessage("done business"),
        "le dialogue de reconnaissance du courtier est absent")
    expect(sawMessage("prévu large") or sawMessage("planned big"), "l'annonce des renforts est absente")
    -- embuscade renforcée : 5 de base + 2 équipes supplémentaires
    expect(spawnedCount() - before == 7,
        "embuscade renforcée attendue (7 spawns), obtenu " .. (spawnedCount() - before))
end })

table.insert(SCENARIOS, { name = "conséquence : ns07 A → ns12 standard (pas de reconnaissance)", fn = function()
    autoplay(7, "a")   -- rendre le shard au NCPD
    local before = spawnedCount()
    autoplay(12)
    expect(not sawMessage("déjà fait affaire") and not sawMessage("done business"),
        "le courtier ne doit pas te reconnaître")
    expect(spawnedCount() - before == 5,
        "embuscade standard attendue (5 spawns), obtenu " .. (spawnedCount() - before))
end })

table.insert(SCENARIOS, { name = "conséquence : ns09 B → ns10 révèle la secte, ns14 allégée", fn = function()
    autoplay(9, "b")   -- épargner les Enfants du Courant
    autoplay(10)
    expect(sawMessage("bougies LED encore tièdes") or sawMessage("candles still warm"),
        "l'épilogue variante (la secte) est absent de ns10")
    local before = spawnedCount()
    autoplay(14, "b")
    expect(sawMessage("chant monte") or sawMessage("chant rises"),
        "la diversion des Enfants est absente de ns14")
    expect(spawnedCount() - before == 4,
        "garde voodoo allégée attendue (4 spawns), obtenu " .. (spawnedCount() - before))
end })

table.insert(SCENARIOS, { name = "conséquence : ns09 A → ns10 pointe le courtier, ns14 complète", fn = function()
    autoplay(9, "a")   -- disperser la secte
    autoplay(10)
    expect(sawMessage("sous-traitant") or sawMessage("subcontractor"),
        "l'épilogue par défaut (piste du courtier) est absent de ns10")
    local before = spawnedCount()
    autoplay(14, "a")
    expect(spawnedCount() - before == 6,
        "garde voodoo complète attendue (6 spawns), obtenu " .. (spawnedCount() - before))
end })

table.insert(SCENARIOS, { name = "conséquence : alignement Marché → CODA durcie (renforts Arasaka)", fn = function()
    autoplay(7, "b")
    autoplay(9, "a")   -- 2 choix Marché
    local align = NS.GetAlignment()
    expect(align.eddies == 2, "alignement Marché attendu à 2")
    autoplay(15, "b")
    expect(sawMessage("financé leurs renseignements") or sawMessage("funded their intel"),
        "les renforts conditionnels de CODA sont absents")
end })

-- Campagne : progression, journal, bilan -----------------------------------

table.insert(SCENARIOS, { name = "campagne : déverrouillage progressif des missions", fn = function()
    NS = loadMod()
    NS.SetFreePlay(false)   -- mode campagne réel
    expect(NS.IsUnlocked(1), "ns01 doit être ouverte d'entrée")
    expect(not NS.IsUnlocked(2), "ns02 doit être verrouillée au départ")
    expect(not NS.IsUnlocked(15), "CODA doit être verrouillée au départ")
    expect(not NS.Start(2), "démarrer une mission verrouillée doit être refusé")
    expect(NS.GetStatus() == "idle", "un démarrage refusé ne doit rien lancer")
    expect(sawMessage("verrouillé") or sawMessage("locked"), "message de verrou absent")

    autoplay(1)   -- termine ns01 (l'autoplay recharge le mod en free-play)
    NS = loadMod(); NS.SetFreePlay(false)
    expect(NS.IsUnlocked(2), "ns02 doit s'ouvrir après ns01")
    expect(NS.IsUnlocked(3), "ns03 doit s'ouvrir après ns01")
    expect(not NS.IsUnlocked(4), "ns04 attend encore ns02")
end })

table.insert(SCENARIOS, { name = "campagne : le journal reflète statut, choix et verrou", fn = function()
    autoplay(7, "b")   -- termine ns07, choix b
    NS = loadMod(); NS.SetFreePlay(false)
    local j = NS.GetJournal()
    expect(j[7].status == "done", "ns07 doit être marquée terminée")
    expect(j[7].choice == "b", "le choix de ns07 doit apparaître au journal")
    expect(j[12].status == "open", "ns12 doit s'ouvrir après ns07")
    expect(j[15].status == "locked", "CODA doit rester verrouillée sans ses prérequis")
    expect(j[1].status == "open", "ns01 doit rester accessible")
end })

table.insert(SCENARIOS, { name = "campagne : bilan final généré (voie Signal)", fn = function()
    autoplay(9, "b")    -- signal
    autoplay(14, "b")   -- signal
    autoplay(15, "a")   -- CODA fin A (align signal) → bilan
    expect(sawMessage("BILAN DE CAMPAGNE"), "l'en-tête du bilan est absent")
    expect(sawMessage("3/15"), "le compte de contrats du bilan est faux")
    expect(sawMessage("Signal 3"), "l'alignement du bilan est faux")
    expect(sawMessage("protégé"), "la conclusion de la voie Signal est absente")
    expect(sawMessage("Rendre le fragment"), "le dernier mot (choix CODA) est absent du bilan")
end })

table.insert(SCENARIOS, { name = "campagne : bilan final généré (voie Marché)", fn = function()
    autoplay(7, "b")    -- marché
    autoplay(9, "a")    -- marché
    autoplay(15, "b")   -- CODA fin B (align marché)
    expect(sawMessage("BILAN DE CAMPAGNE"), "l'en-tête du bilan est absent")
    expect(sawMessage("Marché 3"), "l'alignement Marché du bilan est faux")
    expect(sawMessage("monnayé"), "la conclusion de la voie Marché est absente")
    expect(sawMessage("Vendre le fragment"), "le dernier mot (choix CODA B) est absent")
end })

-- Échecs et interruptions -------------------------------------------------

table.insert(SCENARIOS, { name = "ns03 : échec de course (timeout) → nettoyage propre", fn = function()
    NS = loadMod()
    NS.Start(3)
    tickFor(125)   -- timeLimit = 120 s sans bouger
    expect(NS.GetStatus() == "idle", "l'échec de course doit rendre la main")
    expect(sawMessage("MISSION ÉCHOUÉE") or sawMessage("MISSION FAILED"), "message d'échec absent")
    expectCleanWorld("échec course")
    local stats = NS.GetStats()
    expect((stats.plays_ns03 or 0) == 1 and (stats.done_ns03 or 0) == 0,
        "un échec ne doit pas compter comme complétion")
end })

table.insert(SCENARIOS, { name = "ns05 : abandon en pleine défense → nettoyage propre", fn = function()
    NS = loadMod()
    NS.Start(5)
    teleport({ x = -900, y = 250, z = 8 }); tick(0.2)   -- goto
    tickFor(10)   -- la défense a commencé, des scavs ont spawné
    press("ns_abort")
    expect(NS.GetStatus() == "idle", "abandon inopérant")
    expectCleanWorld("abandon défense")
end })

table.insert(SCENARIOS, { name = "ns10 : perte de session en plein boss → annulation propre", fn = function()
    NS = loadMod()
    NS.Start(10)
    teleport({ x = -1522, y = -978, z = 25 }); tick(0.2)
    tickFor(12)   -- dialogue glitché puis boss lancé
    SIM.player.present = false
    tickFor(1)
    SIM.player.present = true
    tick(0.1)
    expect(NS.GetStatus() == "idle", "perte de session non gérée")
    expect(sawMessage("Session interrompue") or sawMessage("Session interrupted"),
        "message de session absent")
    expectCleanWorld("perte de session")
end })

table.insert(SCENARIOS, { name = "négatif : double démarrage refusé, choix hors phase inerte", fn = function()
    NS = loadMod()
    NS.Start(1)
    expect(not NS.Start(2), "un second démarrage doit être refusé")
    press("ns_choice_a")   -- pas de phase choice en cours
    expect(NS.GetStatus() == "running", "un choix hors phase ne doit rien casser")
    expect((SIM.inventory["Items.money"] or 0) == 0, "aucune récompense ne doit être versée")
end })

table.insert(SCENARIOS, { name = "stats : cumul multi-missions et record persistant", fn = function()
    autoplay(1)
    NS = loadMod()   -- rechargement : stats relues du disque
    local stats = NS.GetStats()
    expect((stats.plays_ns01 or 0) == 1 and (stats.done_ns01 or 0) == 1, "stats ns01 non persistées")
    expect((stats.best_ns01 or 0) > 0, "record ns01 absent")
    local s2 = autoplay(2)
    expect((s2.done_ns02 or 0) == 1, "stats ns02 absentes")
    expect((s2.done_ns01 or 0) == 1, "le cumul multi-missions doit conserver ns01")
end })

table.insert(SCENARIOS, { name = "audit : aucun choix ne se valide tout seul au timeout (ns07/ns09/ns14)", fn = function()
    for _, mi in ipairs({ 7, 9, 14 }) do
        local workNS = loadMod()
        workNS.Start(mi)
        local guard = 0
        -- avance jusqu'à la phase choice avec le pilote standard
        while workNS.GetStatus() == "running" and workNS.GetPhaseInfo().type ~= "choice" do
            guard = guard + 1
            expect(guard < 20000, "audit bloqué avant la phase choice (mission " .. mi .. ")")
            local info = workNS.GetPhaseInfo()
            if info.type == "goto" or info.type == "race" or info.type == "collect" then
                if info.target then teleport(info.target) end
                tick(0.2)
            elseif info.type == "hold" then
                if info.target then teleport(info.target) end
                tick(0.5); killAll()
            elseif info.type == "wave" or info.type == "boss" or info.type == "defend" then
                tick(0.5); killAll()
            else
                tick(0.5)
            end
        end
        expect(workNS.GetPhaseInfo().type == "choice", "phase choice non atteinte (mission " .. mi .. ")")
        tickFor(40)   -- timeout passé, bascule marche activée
        expect(workNS.GetStatus() == "running",
            "mission " .. mi .. " : une fin s'est validée toute seule au timeout !")
        workNS.Abort()
    end
end })

table.insert(SCENARIOS, { name = "sélection : cycle des 15 missions au hotkey", fn = function()
    NS = loadMod()
    for i = 1, 15 do press("ns_next") end
    -- après 15 pressions on est revenu à la mission 1
    expect(sawMessage("Échos") or sawMessage("Echoes"), "le cycle de sélection doit repasser par la mission 1")
    press("ns_start")
    expect(NS.GetStatus() == "running", "démarrage via sélection inopérant")
    press("ns_abort")
end })
