--------------------------------------------------------------------------
-- LATENCY OPTIMIZER 1.0 — mod CET pour Cyberpunk 2077
--------------------------------------------------------------------------
-- Réduit la LATENCE D'INPUT (temps entre ta touche et l'image) par le seul
-- levier qu'un mod en jeu peut réellement actionner : le frame-pacing.
--
-- CE QUI RÉDUIT VRAIMENT LA LATENCE (et que ce mod fait) :
--   • Cap FPS sous ton max soutenu → le GPU n'est plus saturé à 100 %,
--     la file de rendu raccourcit → moins de latence, plus stable.
--   • VSync coupé → supprime jusqu'à ~1 image de latence d'attente.
-- CE QUE CE MOD NE PEUT PAS FAIRE (niveau driver / OS — voir l'app AMD) :
--   • AMD Anti-Lag, HAGS, priorité CPU, Game Mode Windows.
--
-- Le cœur du mod est un MESUREUR de frametime fiable (100 % Lua, sans
-- requête au jeu) : tu vois ta latence de rendu en direct et tu vérifies
-- l'effet des réglages. Le mesureur marche toujours ; l'application des
-- réglages est best-effort (les chemins de variables dépendent de la
-- version du jeu — tout est éditable dans CONFIG).
--
-- Requiert : Cyber Engine Tweaks (CET) 1.31+
-- Installation : dossier "latency_optimizer" dans
--   <jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/
--------------------------------------------------------------------------

local CONFIG = {
    language   = "auto",  -- "auto", "fr" ou "en"
    overlay    = true,    -- afficher le compteur de latence
    applyOnStart = false, -- appliquer le préréglage basse latence au chargement

    window      = 240,    -- nb de frames analysées (fenêtre glissante)
    refresh     = 0.25,   -- rafraîchissement de l'affichage (s) — la MESURE
                          -- reste par frame ; seul l'affichage est throttlé
    stutterMs   = 40.0,   -- seuil de « saccade » : frame plus longue que ça
    capHeadroom = 0.97,   -- cap conseillé = 97 % du FPS médian soutenu

    -- Réglages basse latence appliqués par le préréglage (best-effort).
    -- group/var = chemin de la variable de réglage CET ; ils varient selon
    -- la version du jeu — ajuste-les ici si un réglage ne « prend » pas.
    latencySettings = {
        { group = "/video/display", var = "VSync",  value = false, autoCap = false,
          label = { fr = "VSync coupé", en = "VSync off" } },
        { group = "/video/display", var = "MaxFPS", value = 0,     autoCap = true,
          label = { fr = "Cap FPS", en = "FPS cap" } },
    },
    -- Réglages de NETTETÉ (n'affectent PAS la latence, réduisent le flou de
    -- mouvement — appliqués seulement par ApplyClarity(), jamais par défaut).
    claritySettings = {
        { group = "/graphics/basic", var = "MotionBlur",         value = 0,
          label = { fr = "Flou de mouvement coupé", en = "Motion blur off" } },
        { group = "/graphics/basic", var = "ChromaticAberration", value = false,
          label = { fr = "Aberration chromatique coupée", en = "Chromatic aberration off" } },
        { group = "/graphics/basic", var = "FilmGrain",          value = false,
          label = { fr = "Grain de film coupé", en = "Film grain off" } },
    },
}

--------------------------------------------------------------------------
-- Localisation
--------------------------------------------------------------------------

local LOCALES = {
    fr = {
        loaded      = "[LATENCY] Chargé. Console : GetMod(\"latency_optimizer\").Help()",
        applied     = "Basse latence appliquée : %d réglage(s) — %s",
        apply_none  = "Aucun réglage n'a pu être appliqué (chemins de variables à ajuster dans CONFIG).",
        clarity_ok  = "Netteté appliquée : %d réglage(s) — %s",
        overlay_on  = "Compteur de latence : ON",
        overlay_off = "Compteur de latence : OFF",
        reset_ok    = "Mesures réinitialisées.",
        cap_hint    = "Cap conseillé : %d FPS (97 %% de ton FPS soutenu)",
        hud_title   = "◤ LATENCE",
        hud_ms      = "Rendu : %.1f ms",
        hud_fps     = "FPS : %d",
        hud_low     = "1%% low : %d FPS",
        hud_stutter = "Saccades : %.0f %%",
        hud_cap     = "Cap conseillé : %d FPS",
        hud_wait    = "Mesure en cours…",
    },
    en = {
        loaded      = "[LATENCY] Loaded. Console: GetMod(\"latency_optimizer\").Help()",
        applied     = "Low latency applied: %d setting(s) — %s",
        apply_none  = "No setting could be applied (adjust the variable paths in CONFIG).",
        clarity_ok  = "Clarity applied: %d setting(s) — %s",
        overlay_on  = "Latency meter: ON",
        overlay_off = "Latency meter: OFF",
        reset_ok    = "Measurements reset.",
        cap_hint    = "Suggested cap: %d FPS (97%% of your sustained FPS)",
        hud_title   = "◤ LATENCY",
        hud_ms      = "Render: %.1f ms",
        hud_fps     = "FPS: %d",
        hud_low     = "1%% low: %d FPS",
        hud_stutter = "Stutter: %.0f %%",
        hud_cap     = "Suggested cap: %d FPS",
        hud_wait    = "Measuring…",
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
-- Mesureur de frametime (100 % Lua, aucune requête au jeu par frame)
--------------------------------------------------------------------------

local refreshHud   -- défini plus bas ; appelé par sample()

local M = {
    frames = {},      -- anneau de frametimes (secondes)
    idx = 0, count = 0,
    displayTimer = 0,
    ready = false,
    disp = { fps = 0, ms = 0, low1 = 0, stutterPct = 0, cap = 0, samples = 0 },
    hud = nil,        -- payload HUD pré-calculé
    hudDisabled = false,
}

local function resetMeter()
    M.frames = {}
    M.idx, M.count = 0, 0
    M.displayTimer = 0
    M.ready = false
    M.disp = { fps = 0, ms = 0, low1 = 0, stutterPct = 0, cap = 0, samples = 0 }
    M.hud = nil
end

-- Calcule les statistiques LIVE à partir de la fenêtre glissante. Renvoie
-- nil si aucune donnée. Pur (ne mute rien) — appelable à tout moment.
local function computeStats()
    local n = M.count
    if n == 0 then return nil end
    local sum, tmp = 0, {}
    for i = 1, n do
        local f = M.frames[i]
        sum = sum + f
        tmp[i] = f
    end
    local avg = sum / n
    local fps = avg > 0 and 1 / avg or 0

    -- 1% low : FPS moyen des 1 % de frames les plus longues
    table.sort(tmp, function(a, b) return a > b end)  -- décroissant
    local k = math.max(1, math.floor(n * 0.01))
    local worst = 0
    for i = 1, k do worst = worst + tmp[i] end
    worst = worst / k
    local low1 = worst > 0 and 1 / worst or 0

    -- saccades : part des frames au-dessus du seuil
    local st = 0
    local thr = CONFIG.stutterMs / 1000
    for i = 1, n do if M.frames[i] > thr then st = st + 1 end end
    local stutterPct = st / n * 100

    -- cap conseillé : 97 % du FPS médian (tmp décroissant → médiane au milieu)
    local median = tmp[math.floor((n + 1) / 2)]
    local medFps = median > 0 and 1 / median or 0
    local cap = math.floor(medFps * CONFIG.capHeadroom)

    return { fps = fps, ms = avg * 1000, low1 = low1,
             stutterPct = stutterPct, cap = cap, samples = n }
end

-- Appelé chaque frame : pousse le frametime (arithmétique pure, ~gratuit).
-- Le recalcul + l'actualisation de l'affichage sont throttlés (l'écran n'a
-- pas besoin de plus de 4 rafraîchissements/seconde).
local function sample(delta)
    if not delta or delta <= 0 then return end
    M.idx = (M.idx % CONFIG.window) + 1
    M.frames[M.idx] = delta
    if M.count < CONFIG.window then M.count = M.count + 1 end
    M.displayTimer = M.displayTimer + delta
    if M.displayTimer >= CONFIG.refresh then
        M.displayTimer = 0
        local s = computeStats()
        if s then
            M.disp = s
            M.ready = true
            refreshHud()
        end
    end
end

--------------------------------------------------------------------------
-- Application des réglages (best-effort, tout est pcall + rapporté)
--------------------------------------------------------------------------

local function screenMessage(text)
    pcall(function()
        local defs = Game.GetAllBlackboardDefs()
        local ui = Game.GetBlackboardSystem():Get(defs.UI_Notifications)
        local msg = SimpleScreenMessage.new()
        msg.message = text
        msg.isShown = true
        ui:SetVariant(defs.UI_Notifications.OnscreenMessage, ToVariant(msg), true)
    end)
end

local function applySettings(list, autoCapValue)
    local applied = {}
    local sys = nil
    pcall(function() sys = Game.GetSettingsSystem() end)
    if not sys then return applied end
    for _, s in ipairs(list) do
        local value = s.value
        if s.autoCap then
            value = (autoCapValue and autoCapValue > 0) and autoCapValue or 60
        end
        local ok = pcall(function()
            local v = sys:GetVar(s.group, s.var)
            v:SetValue(value)
        end)
        if ok then applied[#applied + 1] = T(s.label) end
    end
    pcall(function() sys:ConfirmChanges() end)
    return applied
end

local function applyLowLatency()
    local live = computeStats()
    local cap = live and live.cap or 0
    local applied = applySettings(CONFIG.latencySettings, cap)
    if #applied == 0 then
        screenMessage(L.apply_none)
        print("[LATENCY] " .. L.apply_none)
        return applied
    end
    local msg = L.applied:format(#applied, table.concat(applied, ", "))
    screenMessage(msg)
    print("[LATENCY] " .. msg)
    return applied
end

local function applyClarity()
    local applied = applySettings(CONFIG.claritySettings, nil)
    local msg = L.clarity_ok:format(#applied, table.concat(applied, ", "))
    screenMessage(msg)
    print("[LATENCY] " .. msg)
    return applied
end

--------------------------------------------------------------------------
-- HUD (mesure côté logique, rendu ImGui seulement — pile équilibrée)
--------------------------------------------------------------------------

local screenWCache = nil

refreshHud = function()
    if not CONFIG.overlay then M.hud = nil; return end
    if not M.ready then
        M.hud = { wait = true }
        return
    end
    local d = M.disp
    M.hud = {
        ms      = L.hud_ms:format(d.ms),
        fps     = L.hud_fps:format(math.floor(d.fps + 0.5)),
        low1    = L.hud_low:format(math.floor(d.low1 + 0.5)),
        stutter = L.hud_stutter:format(d.stutterPct),
        cap     = L.hud_cap:format(d.cap),
        -- couleur du frametime : vert < 11 ms (~90 fps), jaune < 20 ms, rouge sinon
        msColor = d.ms < 11 and 1 or (d.ms < 20 and 2 or 3),
        stutterHot = d.stutterPct >= 2,
    }
end

local function renderHud()
    local h = M.hud
    if not screenWCache then
        local w = 1920
        pcall(function() w = ({ GetDisplayResolution() })[1] or w end)
        screenWCache = w
    end
    local flags = ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.AlwaysAutoResize
        + ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoNav

    ImGui.SetNextWindowPos(screenWCache - 250, 90, ImGuiCond.FirstUseEver)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.02, 0.02, 0.04, 0.65)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.30, 0.91, 0.96, 0.55)
    if ImGui.Begin("LATENCY_METER", flags) then
        ImGui.TextColored(0.30, 0.91, 0.96, 1.0, L.hud_title)
        ImGui.Separator()
        if h.wait then
            ImGui.Text(L.hud_wait)
        else
            if h.msColor == 1 then ImGui.TextColored(0.24, 0.94, 0.55, 1.0, h.ms)
            elseif h.msColor == 2 then ImGui.TextColored(0.99, 0.93, 0.04, 1.0, h.ms)
            else ImGui.TextColored(1.0, 0.23, 0.30, 1.0, h.ms) end
            ImGui.Text(h.fps)
            ImGui.Text(h.low1)
            if h.stutterHot then ImGui.TextColored(1.0, 0.23, 0.30, 1.0, h.stutter)
            else ImGui.Text(h.stutter) end
            ImGui.Separator()
            ImGui.TextColored(0.99, 0.93, 0.04, 1.0, h.cap)
        end
    end
    ImGui.End()
    ImGui.PopStyleColor(2)
end

--------------------------------------------------------------------------
-- Branchements CET
--------------------------------------------------------------------------

registerForEvent("onInit", function()
    LANG = detectLanguage()
    L = LOCALES[LANG]
    print(L.loaded)
    if CONFIG.applyOnStart then applyLowLatency() end
end)

-- Mesure chaque frame (pur Lua, négligeable) ; l'affichage est throttlé.
registerForEvent("onUpdate", function(delta)
    sample(delta)
end)

registerForEvent("onDraw", function()
    if M.hudDisabled or not M.hud then return end
    local ok, err = pcall(renderHud)
    if not ok then
        M.hudDisabled = true
        pcall(function() ImGui.End() end)
        pcall(function() ImGui.PopStyleColor(2) end)
        print("[LATENCY] HUD désactivé après une erreur ImGui : " .. tostring(err))
    end
end)

registerHotkey("lat_apply", "LATENCY — appliquer basse latence / apply low latency", function()
    applyLowLatency()
end)

registerHotkey("lat_overlay", "LATENCY — afficher/masquer le compteur / toggle meter", function()
    CONFIG.overlay = not CONFIG.overlay
    if not CONFIG.overlay then M.hud = nil end
    screenMessage(CONFIG.overlay and L.overlay_on or L.overlay_off)
end)

registerHotkey("lat_reset", "LATENCY — réinitialiser les mesures / reset meter", function()
    resetMeter()
    screenMessage(L.reset_ok)
end)

--------------------------------------------------------------------------
-- API publique (console + tests)
--------------------------------------------------------------------------

return {
    -- statistiques de latence en direct (recalcul à la demande)
    GetStats = function()
        local d = computeStats()
        if not d then
            return { fps = 0, frametimeMs = 0, low1 = 0, stutterPct = 0,
                     suggestedCap = 0, samples = 0, ready = false }
        end
        return { fps = d.fps, frametimeMs = d.ms, low1 = d.low1,
                 stutterPct = d.stutterPct, suggestedCap = d.cap,
                 samples = d.samples, ready = true }
    end,
    ApplyLowLatency = applyLowLatency,
    ApplyClarity = applyClarity,
    Reset = resetMeter,
    ToggleOverlay = function()
        CONFIG.overlay = not CONFIG.overlay
        if not CONFIG.overlay then M.hud = nil end
        return CONFIG.overlay
    end,
    Help = function()
        print("[LATENCY] Optimiseur de latence — commandes :")
        print("  .ApplyLowLatency()  — cap FPS conseillé + VSync off (best-effort)")
        print("  .GetStats()         — { fps, frametimeMs, low1, stutterPct, suggestedCap }")
        print("  .ApplyClarity()     — coupe flou/aberration/grain (netteté, PAS la latence)")
        print("  .Reset()  .ToggleOverlay()")
        print("  Le compteur en haut à droite montre ta latence de rendu (ms) en direct.")
    end,
}
