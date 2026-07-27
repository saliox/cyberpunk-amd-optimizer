--------------------------------------------------------------------------
-- Scénarios de simulation de LATENCY OPTIMIZER
--------------------------------------------------------------------------

SCENARIOS = {}

table.insert(SCENARIOS, { name = "mesure : FPS constant → frametime et FPS exacts", fn = function()
    loadMod()
    feedFps(100, 3)          -- 100 fps pendant 3 s (dt = 10 ms)
    local s = MOD.GetStats()
    expect(s.ready, "les stats devraient être prêtes après 3 s")
    expect(approx(s.frametimeMs, 10.0, 0.1), "frametime attendu ~10 ms, obtenu " .. s.frametimeMs)
    expect(approx(s.fps, 100, 1), "FPS attendu ~100, obtenu " .. s.fps)
    expect(s.stutterPct == 0, "aucune saccade attendue à 100 fps stable")
end })

table.insert(SCENARIOS, { name = "mesure : le 1% low capte les frames lentes", fn = function()
    loadMod()
    -- 198 frames à 100 fps + 2 frames très lentes (100 ms) → 1% low bas
    for _ = 1, 198 do frame(0.010) end
    frame(0.100); frame(0.100)
    local s = MOD.GetStats()
    -- 1% de 200 = 2 frames les plus lentes (100 ms) → 1% low ~10 FPS
    expect(approx(s.low1, 10, 1), "1% low attendu ~10 FPS, obtenu " .. s.low1)
    expect(s.fps > s.low1 + 20, "le FPS moyen doit rester bien au-dessus du 1% low")
end })

table.insert(SCENARIOS, { name = "mesure : compteur de saccades (frames > seuil)", fn = function()
    loadMod()
    -- 90 frames fluides (10 ms) + 10 saccades (60 ms > seuil 40 ms) = 10 %
    for _ = 1, 90 do frame(0.010) end
    for _ = 1, 10 do frame(0.060) end
    local s = MOD.GetStats()
    expect(approx(s.stutterPct, 10, 1), "saccades attendues ~10 %, obtenu " .. s.stutterPct)
end })

table.insert(SCENARIOS, { name = "conseil : le cap conseillé est ~97 % du FPS médian", fn = function()
    loadMod()
    feedFps(120, 3)          -- 120 fps stable
    local s = MOD.GetStats()
    -- cap = floor(120 * 0.97) = 116
    expect(s.suggestedCap == 116, "cap conseillé attendu 116, obtenu " .. s.suggestedCap)
end })

table.insert(SCENARIOS, { name = "application : basse latence écrit VSync off + cap FPS", fn = function()
    loadMod()
    feedFps(120, 3)
    local applied = MOD.ApplyLowLatency()
    expect(#applied == 2, "2 réglages basse latence attendus, obtenu " .. #applied)
    expect(SIM.settings["/video/display|VSync"] == false, "VSync devrait être mis à false")
    expect(SIM.settings["/video/display|MaxFPS"] == 116,
        "le cap FPS devrait valoir le cap conseillé (116), obtenu " ..
        tostring(SIM.settings["/video/display|MaxFPS"]))
    expect(SIM.messages[#SIM.messages]:find("Basse latence"), "message de confirmation absent")
end })

table.insert(SCENARIOS, { name = "application : cap de repli à 60 sans mesure disponible", fn = function()
    loadMod()
    -- pas de frames alimentées → M.disp.cap = 0 → repli à 60
    MOD.ApplyLowLatency()
    expect(SIM.settings["/video/display|MaxFPS"] == 60,
        "sans mesure, le cap doit retomber sur 60, obtenu " ..
        tostring(SIM.settings["/video/display|MaxFPS"]))
end })

table.insert(SCENARIOS, { name = "netteté : ApplyClarity coupe flou/aberration/grain (pas la latence)", fn = function()
    loadMod()
    local applied = MOD.ApplyClarity()
    expect(#applied == 3, "3 réglages de netteté attendus")
    expect(SIM.settings["/graphics/basic|MotionBlur"] == 0, "flou de mouvement non coupé")
    expect(SIM.settings["/graphics/basic|ChromaticAberration"] == false, "aberration non coupée")
    -- la netteté ne doit PAS toucher aux réglages de latence
    expect(SIM.settings["/video/display|VSync"] == nil, "la netteté ne doit pas toucher VSync")
end })

table.insert(SCENARIOS, { name = "HUD : payload caché, rendu ImGui seulement, pile équilibrée", fn = function()
    loadMod()
    feedFps(90, 2)           -- remplit la mesure ; refreshHud construit le payload
    local pushes = SIM.imgui.push
    draw(); draw()
    expect(SIM.imgui.push > pushes, "le HUD aurait dû se dessiner depuis le cache")
    expect(SIM.imgui.push == SIM.imgui.pop, "pile de styles ImGui déséquilibrée")
    expect(SIM.imgui.beginN == SIM.imgui.endN, "Begin/End ImGui déséquilibrés")
end })

table.insert(SCENARIOS, { name = "HUD : erreur ImGui isolée → HUD coupé, pile rééquilibrée", fn = function()
    loadMod()
    feedFps(90, 2)
    SIM.imgui.textThrows = true
    draw()
    expect(sawLog("HUD désactivé"), "la panne ImGui n'a pas été loguée")
    expect(SIM.imgui.push == SIM.imgui.pop, "pile non rééquilibrée après la panne")
    local p = SIM.imgui.push
    draw()
    expect(SIM.imgui.push == p, "le HUD doit rester coupé après une panne")
    SIM.imgui.textThrows = false
end })

table.insert(SCENARIOS, { name = "overlay off : aucun dessin", fn = function()
    loadMod()
    feedFps(90, 2)
    MOD.ToggleOverlay()      -- passe à off
    local p = SIM.imgui.push
    draw()
    expect(SIM.imgui.push == p, "aucun dessin quand l'overlay est off")
end })

table.insert(SCENARIOS, { name = "robustesse : fenêtre glissante bornée (pas de fuite mémoire)", fn = function()
    loadMod()
    feedFps(200, 10)         -- 2000 frames
    local s = MOD.GetStats()
    expect(s.samples <= 240, "la fenêtre doit rester bornée à window (240), obtenu " .. s.samples)
end })

table.insert(SCENARIOS, { name = "robustesse : frametimes nuls/négatifs ignorés", fn = function()
    loadMod()
    frame(0); frame(-0.5); frame(0)
    local s = MOD.GetStats()
    expect(s.samples == 0, "les deltas non positifs ne doivent pas être comptés")
end })

-- Restaurer (annuler) + mémoire de profil ---------------------------------

table.insert(SCENARIOS, { name = "restaurer : capture avant, revient aux réglages d'origine", fn = function()
    loadMod()
    -- réglages « d'origine » du joueur
    SIM.settings["/video/display|VSync"] = true
    SIM.settings["/video/display|MaxFPS"] = 0
    feedFps(120, 3)
    MOD.ApplyLowLatency()
    expect(SIM.settings["/video/display|VSync"] == false, "VSync devrait être coupé après apply")
    expect(SIM.settings["/video/display|MaxFPS"] == 116, "cap devrait être 116 après apply")
    -- annuler → retour à l'état d'origine capturé
    local n = MOD.Restore()
    expect(n >= 1, "au moins un réglage restauré")
    expect(SIM.settings["/video/display|VSync"] == true, "VSync d'origine (true) non restauré")
    expect(SIM.settings["/video/display|MaxFPS"] == 0, "cap d'origine (0) non restauré")
end })

table.insert(SCENARIOS, { name = "restaurer : capture UNE fois (n'écrase pas l'original)", fn = function()
    loadMod()
    SIM.settings["/video/display|VSync"] = true
    SIM.settings["/video/display|MaxFPS"] = 30
    feedFps(120, 3)
    MOD.ApplyLowLatency()   -- capture {true,30}, applique {false,116}
    MOD.ApplyLowLatency()   -- NE doit PAS recapturer l'état déjà bas-latence
    MOD.Restore()
    expect(SIM.settings["/video/display|MaxFPS"] == 30,
        "restore doit rendre l'original (30), pas un état intermédiaire")
end })

table.insert(SCENARIOS, { name = "restaurer : rien à annuler → message, aucun crash", fn = function()
    loadMod()
    local n = MOD.Restore()
    expect(n == 0, "aucun réglage appliqué → rien à restaurer")
    expect(sawMessage("Rien à restaurer") or sawMessage("Nothing to restore"), "message absent")
end })

table.insert(SCENARIOS, { name = "profil : le cap est mémorisé par résolution et relu", fn = function()
    loadMod()
    feedFps(120, 3)
    MOD.ApplyLowLatency()   -- mémorise 116 pour 1920x1080
    local prof = MOD.GetProfiles()
    expect(prof["1920x1080"] == 116, "le profil 1920x1080 devrait mémoriser 116")
    -- rechargement du mod : le profil revient du disque
    loadMod()
    local prof2 = MOD.GetProfiles()
    expect(prof2["1920x1080"] == 116, "le profil devrait persister sur disque")
    -- apply sans mesure → réutilise le profil au lieu du repli 60
    MOD.ApplyLowLatency()
    expect(SIM.settings["/video/display|MaxFPS"] == 116,
        "sans mesure, le cap doit venir du profil (116), pas du repli 60")
end })

-- Mode AUTO + courbe + 0.1% low -------------------------------------------

table.insert(SCENARIOS, { name = "auto : mesure puis applique le cap tout seul après le warmup", fn = function()
    loadMod()
    MOD.SetAutoTune(true)
    -- avant le warmup (8 s), rien n'est appliqué
    feedFps(120, 5)
    expect(SIM.settings["/video/display|MaxFPS"] == nil, "auto ne doit pas agir avant le warmup")
    -- au-delà du warmup, le cap optimal est posé une fois
    feedFps(120, 5)
    expect(SIM.settings["/video/display|MaxFPS"] == 116, "auto aurait dû poser le cap (116)")
    expect(SIM.settings["/video/display|VSync"] == false, "auto aurait dû couper le VSync")
    local st = MOD.GetStats()
    expect(st.autoApplied == true, "GetStats devrait signaler autoApplied")
end })

table.insert(SCENARIOS, { name = "auto : n'applique qu'une seule fois (pas de flip-flop)", fn = function()
    loadMod()
    MOD.SetAutoTune(true)
    feedFps(120, 10)     -- applique
    SIM.settings["/video/display|MaxFPS"] = nil
    feedFps(120, 10)     -- ne doit PAS réappliquer
    expect(SIM.settings["/video/display|MaxFPS"] == nil,
        "auto ne doit pas réappliquer tant qu'il n'est pas ré-armé")
end })

table.insert(SCENARIOS, { name = "auto : off par défaut → aucun réglage touché", fn = function()
    loadMod()
    feedFps(120, 12)     -- autoTune off par défaut
    expect(SIM.settings["/video/display|MaxFPS"] == nil, "auto off ne doit rien appliquer")
end })

table.insert(SCENARIOS, { name = "mesure : le 0.1% low est renseigné et <= 1% low", fn = function()
    loadMod()
    for _ = 1, 998 do frame(0.010) end
    frame(0.100); frame(0.100)
    local s = MOD.GetStats()
    expect(s.low01 > 0, "0.1% low devrait être renseigné")
    expect(s.low01 <= s.low1 + 0.5, "0.1% low doit être <= 1% low (frames les plus lentes)")
end })

table.insert(SCENARIOS, { name = "courbe : PlotLines dessiné quand des données existent", fn = function()
    loadMod()
    feedFps(90, 2)
    SIM.imgui.plots = 0
    draw()
    expect((SIM.imgui.plots or 0) >= 1, "la courbe de frametime aurait dû être dessinée")
    expect(SIM.imgui.push == SIM.imgui.pop, "pile ImGui déséquilibrée avec la courbe")
end })

-- Pont avec l'app ---------------------------------------------------------

local function readJson(name)
    local f = io.open(name, "r")
    if not f then return nil end
    local raw = f:read("*a"); f:close()
    return raw
end

local function writeJson(name, content)
    local f = io.open(name, "w")
    f:write(content); f:close()
end

table.insert(SCENARIOS, { name = "pont : le mod publie un statut live lisible par l'app", fn = function()
    loadMod()
    feedFps(120, 3)
    MOD.PushStatus()   -- force une écriture immédiate
    local raw = readJson("bridge_status.json")
    expect(raw, "bridge_status.json devrait exister")
    expect(raw:find('"mod":"latency_optimizer"'), "champ mod absent")
    expect(raw:find('"ready":true'), "le statut devrait être prêt après 3 s")
    expect(raw:find('"suggestedCap":116'), "cap conseillé absent/incorrect dans le statut")
    expect(raw:match('"fps":([%d%.]+)'), "fps absent du statut")
end })

table.insert(SCENARIOS, { name = "pont : heartbeat initial dès le chargement", fn = function()
    loadMod()   -- onInit écrit un premier statut
    local raw = readJson("bridge_status.json")
    expect(raw, "un heartbeat initial devrait être écrit au chargement")
    expect(raw:find('"ready":false'), "sans mesure, ready doit être false")
end })

table.insert(SCENARIOS, { name = "pont : l'app envoie apply_low_latency → exécuté + accusé", fn = function()
    loadMod()
    feedFps(120, 3)
    writeJson("bridge_command.json", '{"id":42,"cmd":"apply_low_latency"}')
    MOD.PollCommands()
    expect(SIM.settings["/video/display|VSync"] == false, "VSync non appliqué via la commande")
    expect(SIM.settings["/video/display|MaxFPS"] == 116, "cap non appliqué via la commande")
    local ack = readJson("bridge_ack.json")
    expect(ack and ack:find('"id":42'), "accusé manquant pour la commande 42")
    expect(ack:find('"ok":true'), "l'accusé devrait indiquer un succès")
end })

table.insert(SCENARIOS, { name = "pont : une commande n'est exécutée qu'une fois (déduplication)", fn = function()
    loadMod()
    feedFps(120, 3)
    writeJson("bridge_command.json", '{"id":7,"cmd":"set_cap","cap":90}')
    MOD.PollCommands()
    expect(SIM.settings["/video/display|MaxFPS"] == 90, "cap 90 attendu")
    -- l'app change d'avis mais on relit le MÊME fichier (id 7 déjà consommé)
    SIM.settings["/video/display|MaxFPS"] = nil
    MOD.PollCommands()
    expect(SIM.settings["/video/display|MaxFPS"] == nil,
        "une commande au même id ne doit pas être ré-exécutée")
end })

table.insert(SCENARIOS, { name = "pont : set_cap ne touche PAS au VSync et reste annulable", fn = function()
    loadMod()
    feedFps(120, 3)
    SIM.settings["/video/display|VSync"] = true    -- le joueur a VSync ON
    writeJson("bridge_command.json", '{"id":11,"cmd":"set_cap","cap":90}')
    MOD.PollCommands()
    expect(SIM.settings["/video/display|MaxFPS"] == 90, "cap 90 attendu")
    expect(SIM.settings["/video/display|VSync"] == true,
        "set_cap ne doit PAS couper le VSync (effet de bord eliminé)")
    local n = MOD.Restore()
    expect(n and n >= 1, "set_cap doit etre annulable (Restore effectif)")
    expect(SIM.settings["/video/display|MaxFPS"] ~= 90, "Restore doit annuler le cap")
    expect(SIM.settings["/video/display|VSync"] == true, "VSync jamais modifié par set_cap")
end })

table.insert(SCENARIOS, { name = "pont : set_cap PUIS apply_low_latency -> restore rend bien le VSync", fn = function()
    loadMod()
    feedFps(120, 3)
    SIM.settings["/video/display|VSync"] = true      -- VSync d'origine = ON
    SIM.settings["/video/display|MaxFPS"] = 30        -- cap d'origine = 30
    writeJson("bridge_command.json", '{"id":1,"cmd":"set_cap","cap":90}')
    MOD.PollCommands()
    writeJson("bridge_command.json", '{"id":2,"cmd":"apply_low_latency"}')
    MOD.PollCommands()
    expect(SIM.settings["/video/display|VSync"] == false, "apply doit couper le VSync")
    MOD.Restore()
    -- la capture additive doit avoir mémorisé le VSync malgré le set_cap prealable
    expect(SIM.settings["/video/display|VSync"] == true, "restore doit RENDRE le VSync d'origine (true)")
    expect(SIM.settings["/video/display|MaxFPS"] == 30, "restore doit rendre le cap d'origine (30)")
end })

table.insert(SCENARIOS, { name = "pont : une commande d'id 0 est bien traitee", fn = function()
    loadMod()
    feedFps(120, 3)
    writeJson("bridge_command.json", '{"id":0,"cmd":"set_cap","cap":77}')
    MOD.PollCommands()
    expect(SIM.settings["/video/display|MaxFPS"] == 77, "la commande id:0 doit etre executee")
end })

table.insert(SCENARIOS, { name = "mesure : un delta NaN est ignore (pas de pollution des stats)", fn = function()
    loadMod()
    feedFps(100, 2)
    local before = MOD.GetStats().frametimeMs
    frame(0/0)   -- NaN
    local after = MOD.GetStats().frametimeMs
    expect(after == after, "les stats ne doivent pas devenir NaN")
    expect(math.abs(after - before) < 0.5, "un delta NaN ne doit pas polluer la moyenne")
end })

table.insert(SCENARIOS, { name = "pont : cap piloté par l'app (override du conseil)", fn = function()
    loadMod()
    feedFps(120, 3)   -- cap conseillé = 116
    writeJson("bridge_command.json", '{"id":9,"cmd":"apply_low_latency","cap":141}')
    MOD.PollCommands()
    expect(SIM.settings["/video/display|MaxFPS"] == 141,
        "le cap fourni par l'app (141) doit primer sur le conseil (116)")
end })

table.insert(SCENARIOS, { name = "pont : ping → pong, et set_overlay pilote l'affichage", fn = function()
    loadMod()
    writeJson("bridge_command.json", '{"id":1,"cmd":"ping"}')
    MOD.PollCommands()
    expect(readJson("bridge_ack.json"):find("pong"), "ping devrait répondre pong")
    writeJson("bridge_command.json", '{"id":2,"cmd":"set_overlay","value":0}')
    MOD.PollCommands()
    feedFps(90, 1)
    local p = SIM.imgui.push
    draw()
    expect(SIM.imgui.push == p, "set_overlay 0 doit couper le dessin")
end })

table.insert(SCENARIOS, { name = "pont : l'app active le mode AUTO à distance", fn = function()
    loadMod()
    writeJson("bridge_command.json", '{"id":11,"cmd":"auto_tune","value":1}')
    MOD.PollCommands()
    expect(MOD.GetStats().autoTune == true, "auto_tune 1 devrait activer le mode AUTO")
    -- et il s'exécute ensuite tout seul
    feedFps(120, 12)
    expect(SIM.settings["/video/display|MaxFPS"] == 116, "AUTO piloté par l'app aurait dû poser le cap")
    -- le statut publié reflète l'état auto
    MOD.PushStatus()
    local raw = readJson("bridge_status.json")
    expect(raw:find('"autoTune":true'), "le statut devrait exposer autoTune")
    expect(raw:find('"autoApplied":true'), "le statut devrait exposer autoApplied")
    expect(raw:find('"low01":'), "le statut devrait exposer low01")
end })

table.insert(SCENARIOS, { name = "pont : l'app peut annuler à distance (restore)", fn = function()
    loadMod()
    SIM.settings["/video/display|VSync"] = true
    SIM.settings["/video/display|MaxFPS"] = 0
    feedFps(120, 3)
    MOD.ApplyLowLatency()
    -- le statut signale que c'est appliqué et annulable
    MOD.PushStatus()
    local raw = readJson("bridge_status.json")
    expect(raw:find('"applied":true'), "le statut devrait exposer applied")
    expect(raw:find('"restorable":true'), "le statut devrait exposer restorable")
    -- l'app envoie restore
    writeJson("bridge_command.json", '{"id":21,"cmd":"restore"}')
    MOD.PollCommands()
    expect(SIM.settings["/video/display|VSync"] == true, "restore via le pont n'a pas rétabli VSync")
    expect(SIM.settings["/video/display|MaxFPS"] == 0, "restore via le pont n'a pas rétabli le cap")
end })

table.insert(SCENARIOS, { name = "pont : commande malformée ignorée sans crash", fn = function()
    loadMod()
    writeJson("bridge_command.json", '{ pas du json valide')
    MOD.PollCommands()   -- ne doit pas lever
    writeJson("bridge_command.json", '{"cmd":"apply_low_latency"}')  -- id manquant
    MOD.PollCommands()
    expect(true, "aucune erreur levée sur commande malformée")
end })

-- ajoute sawLog / sawMessage aux helpers du harness
function sawLog(fragment)
    for _, m in ipairs(SIM.logs) do
        if m:find(fragment, 1, true) then return true end
    end
    return false
end

function sawMessage(fragment)
    for _, m in ipairs(SIM.messages) do
        if m:find(fragment, 1, true) then return true end
    end
    return false
end
