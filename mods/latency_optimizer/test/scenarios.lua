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

-- ajoute sawLog aux helpers du harness
function sawLog(fragment)
    for _, m in ipairs(SIM.logs) do
        if m:find(fragment, 1, true) then return true end
    end
    return false
end
