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

    bridge      = true,   -- pont fichier avec l'app « Cyberpunk AMD Optimizer »
    bridgeWrite = 1.0,    -- écriture du statut (s) — heartbeat + stats live
    bridgeRead  = 0.5,    -- lecture des commandes venues de l'app (s)

    window      = 240,    -- nb de frames analysées (fenêtre glissante)
    refresh     = 0.25,   -- rafraîchissement de l'affichage (s) — la MESURE
                          -- reste par frame ; seul l'affichage est throttlé
    stutterMs   = 40.0,   -- seuil de « saccade » : frame plus longue que ça
    capHeadroom = 0.97,   -- cap conseillé = 97 % du FPS médian soutenu

    -- Mode AUTO : mesure quelques secondes puis applique le cap optimal tout
    -- seul (opt-in — modifie tes réglages vidéo sans te demander).
    autoTune    = false,  -- true : ferme la boucle automatiquement
    autoWarmup  = 8.0,    -- secondes de mesure avant d'appliquer le cap
    autoMinSamples = 60,  -- refuse d'agir sans assez de frames mesurées

    -- Courbe de frametime dans l'overlay (voir les saccades en un coup d'œil)
    graph        = true,
    graphSamples = 120,   -- points affichés dans la courbe

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
        hud_low01   = "0.1%% low : %d FPS",
        hud_stutter = "Saccades : %.0f %%",
        hud_cap     = "Cap conseillé : %d FPS",
        hud_wait    = "Mesure en cours…",
        hud_graph   = "frametime (ms)",
        auto_on     = "Mode AUTO activé — mesure puis application du cap optimal.",
        auto_off    = "Mode AUTO désactivé.",
        auto_applied = "AUTO : cap appliqué à %d FPS + VSync off.",
        restored    = "Réglages d'origine restaurés (%d).",
        restore_none = "Rien à restaurer (aucun réglage appliqué).",
        profile_hint = "Profil %s : cap mémorisé %d FPS.",
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
        hud_low01   = "0.1%% low: %d FPS",
        hud_stutter = "Stutter: %.0f %%",
        hud_cap     = "Suggested cap: %d FPS",
        hud_wait    = "Measuring…",
        hud_graph   = "frametime (ms)",
        auto_on     = "AUTO mode on — measuring, then applying the optimal cap.",
        auto_off    = "AUTO mode off.",
        auto_applied = "AUTO: cap applied at %d FPS + VSync off.",
        restored    = "Original settings restored (%d).",
        restore_none = "Nothing to restore (no setting applied).",
        profile_hint = "Profile %s: remembered cap %d FPS.",
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
    disp = { fps = 0, ms = 0, low1 = 0, low01 = 0, stutterPct = 0, cap = 0, samples = 0 },
    hud = nil,        -- payload HUD pré-calculé
    hudDisabled = false,
    autoApplied = false,  -- le mode AUTO a déjà appliqué son cap
    autoElapsed = 0,      -- temps de mesure accumulé pour le mode AUTO
    restore = {},         -- instantané des réglages d'origine (pour annuler)
    applied = false,      -- des réglages basse latence sont-ils appliqués ?
}

local function resetMeter()
    M.frames = {}
    M.idx, M.count = 0, 0
    M.displayTimer = 0
    M.ready = false
    M.disp = { fps = 0, ms = 0, low1 = 0, low01 = 0, stutterPct = 0, cap = 0, samples = 0 }
    M.hud = nil
    M.autoApplied = false   -- ré-arme le mode AUTO
    M.autoElapsed = 0
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

    -- 1% / 0.1% low : FPS moyen des X % de frames les plus longues
    table.sort(tmp, function(a, b) return a > b end)  -- décroissant
    local function lowAvg(frac)
        local k = math.max(1, math.floor(n * frac))
        local worst = 0
        for i = 1, k do worst = worst + tmp[i] end
        worst = worst / k
        return worst > 0 and 1 / worst or 0
    end
    local low1  = lowAvg(0.01)
    local low01 = lowAvg(0.001)

    -- saccades : part des frames au-dessus du seuil
    local st = 0
    local thr = CONFIG.stutterMs / 1000
    for i = 1, n do if M.frames[i] > thr then st = st + 1 end end
    local stutterPct = st / n * 100

    -- cap conseillé : 97 % du FPS médian (tmp décroissant → médiane au milieu)
    local median = tmp[math.floor((n + 1) / 2)]
    local medFps = median > 0 and 1 / median or 0
    local cap = math.floor(medFps * CONFIG.capHeadroom)

    return { fps = fps, ms = avg * 1000, low1 = low1, low01 = low01,
             stutterPct = stutterPct, cap = cap, samples = n }
end

-- Construit la courbe de frametime (ms) des derniers points, dans l'ordre
-- chronologique (plus ancien à gauche). Renvoie aussi l'échelle max.
local function buildGraph()
    local n = M.count
    if n == 0 then return nil, 0 end
    local take = math.min(CONFIG.graphSamples, n)
    local plot, maxMs = {}, 0
    for j = take - 1, 0, -1 do
        local pos = ((M.idx - 1 - j) % n) + 1
        local ms = M.frames[pos] * 1000
        plot[#plot + 1] = ms
        if ms > maxMs then maxMs = ms end
    end
    return plot, math.max(20, maxMs)   -- plancher à 20 ms pour un rendu stable
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

-- Lit les valeurs ACTUELLES des réglages (pour pouvoir les restaurer)
local function captureCurrent(list)
    local sys = nil
    pcall(function() sys = Game.GetSettingsSystem() end)
    if not sys then return {} end
    local snap = {}
    for _, s in ipairs(list) do
        local ok, val = pcall(function() return sys:GetVar(s.group, s.var):GetValue() end)
        if ok then snap[#snap + 1] = { group = s.group, var = s.var, value = val } end
    end
    return snap
end

-- Réapplique un instantané de réglages (= annuler)
local function restoreSnapshot(snap)
    local sys = nil
    pcall(function() sys = Game.GetSettingsSystem() end)
    if not sys or not snap then return 0 end
    local n = 0
    for _, s in ipairs(snap) do
        local ok = pcall(function() sys:GetVar(s.group, s.var):SetValue(s.value) end)
        if ok then n = n + 1 end
    end
    pcall(function() sys:ConfirmChanges() end)
    return n
end

-- Profils mémorisés par résolution (latency_profiles.json) : le cap optimal
-- une fois trouvé est réutilisable instantanément à la prochaine session,
-- sans re-mesurer.
local Profiles = {}

local function resolutionKey()
    local w, h = 1920, 1080
    pcall(function() w, h = GetDisplayResolution() end)
    return string.format("%dx%d", math.floor(w or 1920), math.floor(h or 1080))
end

local function loadProfiles()
    pcall(function()
        local f = io.open("latency_profiles.json", "r")
        if not f then return end
        local raw = f:read("*a"); f:close()
        for key, cap in string.gmatch(raw or "", '"(%d+x%d+)"%s*:%s*(%d+)') do
            Profiles[key] = tonumber(cap)
        end
    end)
end

local function saveProfiles()
    pcall(function()
        local parts = {}
        for k, v in pairs(Profiles) do
            parts[#parts + 1] = string.format('"%s":%d', k, math.floor(v))
        end
        local f = io.open("latency_profiles.json", "w")
        if f then f:write("{" .. table.concat(parts, ",") .. "}"); f:close() end
    end)
end

local function applyLowLatency(capOverride)
    local cap = capOverride
    if not cap or cap <= 0 then
        local live = computeStats()
        cap = live and live.cap or 0
    end
    if cap <= 0 then cap = Profiles[resolutionKey()] or 60 end  -- profil mémo, sinon 60

    -- capture les réglages d'origine AVANT la 1re modification (pour Restore)
    if #M.restore == 0 then M.restore = captureCurrent(CONFIG.latencySettings) end

    local applied = applySettings(CONFIG.latencySettings, cap)
    if #applied == 0 then
        screenMessage(L.apply_none)
        print("[LATENCY] " .. L.apply_none)
        return applied
    end
    M.applied = true
    if cap > 0 then                       -- mémorise le cap pour cette résolution
        Profiles[resolutionKey()] = cap
        saveProfiles()
    end
    local msg = L.applied:format(#applied, table.concat(applied, ", "))
    screenMessage(msg)
    print("[LATENCY] " .. msg)
    return applied
end

-- Annule : restaure les réglages d'origine capturés au premier Apply
local function restoreSettings()
    if #M.restore == 0 then
        screenMessage(L.restore_none)
        return 0
    end
    local n = restoreSnapshot(M.restore)
    M.restore = {}
    M.applied = false
    local msg = L.restored:format(n)
    screenMessage(msg)
    print("[LATENCY] " .. msg)
    return n
end

local function applyClarity()
    local applied = applySettings(CONFIG.claritySettings, nil)
    local msg = L.clarity_ok:format(#applied, table.concat(applied, ", "))
    screenMessage(msg)
    print("[LATENCY] " .. msg)
    return applied
end

-- Applique UNIQUEMENT le cap FPS (les entrées autoCap), sans toucher à VSync
-- ni au reste du préréglage. Capture l'état d'origine et marque « appliqué »
-- pour que l'app puisse voir et annuler le changement (contrairement à un
-- applySettings brut sur toute la liste).
local function applyCapOnly(cap)
    local capList = {}
    for _, s in ipairs(CONFIG.latencySettings) do
        if s.autoCap then capList[#capList + 1] = s end
    end
    if #M.restore == 0 then M.restore = captureCurrent(capList) end
    local applied = applySettings(capList, cap)
    if #applied > 0 then M.applied = true end
    return applied
end

--------------------------------------------------------------------------
-- Pont avec l'app « Cyberpunk AMD Optimizer » (IPC par fichiers JSON)
--------------------------------------------------------------------------
-- CET sandboxe io au dossier du mod : les deux fichiers vivent dans
--   <jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/latency_optimizer/
-- que l'app connaît (elle gère déjà le chemin du jeu). Protocole :
--   • bridge_status.json  — ÉCRIT par le mod : stats live + heartbeat (ts)
--   • bridge_command.json — ÉCRIT par l'app  : { id, cmd, cap?, value? }
--   • bridge_ack.json     — ÉCRIT par le mod : { id, ok, message }
-- Le mod écrit le statut ~1×/s et lit les commandes ~2×/s (throttlé, pcall).

local STATUS_FILE  = "bridge_status.json"
local COMMAND_FILE = "bridge_command.json"
local ACK_FILE     = "bridge_ack.json"

local Bridge = { writeTimer = 0, readTimer = 0, lastCmdId = 0, seq = 0 }

local function nowTs()
    local ok, t = pcall(os.time)
    if ok and type(t) == "number" then return t end
    Bridge.seq = Bridge.seq + 1
    return Bridge.seq
end

local function jbool(v) return v and "true" or "false" end

local function writeFile(name, content)
    return pcall(function()
        local f = io.open(name, "w")
        if f then f:write(content); f:close() end
    end)
end

local function readFile(name)
    local content
    pcall(function()
        local f = io.open(name, "r")
        if f then content = f:read("*a"); f:close() end
    end)
    return content
end

-- Active/désactive le mode AUTO (ré-arme la mesure à chaque activation)
local function setAutoTune(on)
    CONFIG.autoTune = on and true or false
    if CONFIG.autoTune then
        M.autoApplied = false
        M.autoElapsed = 0
    end
    return CONFIG.autoTune
end

-- Écrit le statut live (stats + heartbeat) pour l'app
local function writeStatus()
    local d = computeStats()
    local ready = d ~= nil
    d = d or { fps = 0, ms = 0, low1 = 0, low01 = 0, stutterPct = 0, cap = 0, samples = 0 }
    local json = string.format(
        '{"schema":1,"mod":"latency_optimizer","version":"1.0","ts":%d,' ..
        '"ready":%s,"fps":%.1f,"frametimeMs":%.2f,"low1":%.1f,"low01":%.1f,' ..
        '"stutterPct":%.1f,"suggestedCap":%d,"samples":%d,"overlay":%s,' ..
        '"autoTune":%s,"autoApplied":%s,"applied":%s,"restorable":%s}',
        nowTs(), jbool(ready), d.fps, d.ms, d.low1, d.low01 or 0,
        d.stutterPct, d.cap, d.samples, jbool(CONFIG.overlay),
        jbool(CONFIG.autoTune), jbool(M.autoApplied),
        jbool(M.applied), jbool(#M.restore > 0))
    writeFile(STATUS_FILE, json)
end

-- Exécute une commande venue de l'app, renvoie un message d'accusé
local function runCommand(cmd, cap, value)
    if cmd == "apply_low_latency" then
        local applied = applyLowLatency(cap)
        return true, ("apply_low_latency: %d réglage(s)"):format(#applied)
    elseif cmd == "apply_clarity" then
        local applied = applyClarity()
        return true, ("apply_clarity: %d réglage(s)"):format(#applied)
    elseif cmd == "set_cap" then
        local applied = applyCapOnly(cap)   -- seulement le cap FPS (pas VSync)
        return true, ("set_cap: %d → %d réglage(s)"):format(cap or 0, #applied)
    elseif cmd == "reset" then
        resetMeter()
        return true, "reset"
    elseif cmd == "set_overlay" then
        CONFIG.overlay = (value ~= 0)
        if not CONFIG.overlay then M.hud = nil end
        return true, "set_overlay: " .. tostring(CONFIG.overlay)
    elseif cmd == "auto_tune" then
        setAutoTune(value ~= 0)
        return true, "auto_tune: " .. tostring(CONFIG.autoTune)
    elseif cmd == "restore" then
        local n = restoreSettings()
        return true, ("restore: %d réglage(s)"):format(n)
    elseif cmd == "ping" then
        return true, "pong"
    end
    return false, "commande inconnue : " .. tostring(cmd)
end

-- Lit et consomme une éventuelle commande de l'app (une seule fois par id)
local function readCommand()
    local raw = readFile(COMMAND_FILE)
    if not raw then return end
    local id = tonumber(raw:match('"id"%s*:%s*(%d+)'))
    local cmd = raw:match('"cmd"%s*:%s*"([%w_]+)"')
    if not id or not cmd then return end
    if id == Bridge.lastCmdId then return end   -- déjà traitée
    Bridge.lastCmdId = id
    local cap = tonumber(raw:match('"cap"%s*:%s*(%d+)'))
    local value = tonumber(raw:match('"value"%s*:%s*(%-?%d+)'))
    local ok, message = runCommand(cmd, cap, value)
    writeFile(ACK_FILE, string.format(
        '{"schema":1,"id":%d,"ok":%s,"message":"%s","ts":%d}',
        id, jbool(ok), tostring(message):gsub('"', "'"), nowTs()))
    -- neutralise le fichier de commande pour ne pas la relire au chargement
    writeFile(COMMAND_FILE, string.format('{"id":%d,"consumed":true}', id))
end

local function bridgeTick(delta)
    if not CONFIG.bridge then return end
    Bridge.writeTimer = Bridge.writeTimer + delta
    if Bridge.writeTimer >= CONFIG.bridgeWrite then
        Bridge.writeTimer = 0
        writeStatus()
    end
    Bridge.readTimer = Bridge.readTimer + delta
    if Bridge.readTimer >= CONFIG.bridgeRead then
        Bridge.readTimer = 0
        readCommand()
    end
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
    local plot, plotMax
    if CONFIG.graph then plot, plotMax = buildGraph() end
    M.hud = {
        ms      = L.hud_ms:format(d.ms),
        fps     = L.hud_fps:format(math.floor(d.fps + 0.5)),
        low1    = L.hud_low:format(math.floor(d.low1 + 0.5)),
        low01   = L.hud_low01:format(math.floor((d.low01 or 0) + 0.5)),
        stutter = L.hud_stutter:format(d.stutterPct),
        cap     = L.hud_cap:format(d.cap),
        auto    = M.autoApplied,   -- badge « AUTO » quand le cap a été posé
        -- couleur du frametime : vert < 11 ms (~90 fps), jaune < 20 ms, rouge sinon
        msColor = d.ms < 11 and 1 or (d.ms < 20 and 2 or 3),
        stutterHot = d.stutterPct >= 2,
        plot = plot, plotMax = plotMax,
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
        if h.auto then
            ImGui.TextColored(0.24, 0.94, 0.55, 1.0, L.hud_title .. "  [AUTO]")
        else
            ImGui.TextColored(0.30, 0.91, 0.96, 1.0, L.hud_title)
        end
        ImGui.Separator()
        if h.wait then
            ImGui.Text(L.hud_wait)
        else
            if h.msColor == 1 then ImGui.TextColored(0.24, 0.94, 0.55, 1.0, h.ms)
            elseif h.msColor == 2 then ImGui.TextColored(0.99, 0.93, 0.04, 1.0, h.ms)
            else ImGui.TextColored(1.0, 0.23, 0.30, 1.0, h.ms) end
            ImGui.Text(h.fps)
            ImGui.Text(h.low1)
            ImGui.Text(h.low01)
            if h.stutterHot then ImGui.TextColored(1.0, 0.23, 0.30, 1.0, h.stutter)
            else ImGui.Text(h.stutter) end
            if h.plot and #h.plot > 1 then
                ImGui.PlotLines("", h.plot, #h.plot, 0, L.hud_graph, 0, h.plotMax, 220, 40)
            end
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
    loadProfiles()
    print(L.loaded)
    local remembered = Profiles[resolutionKey()]
    if remembered then
        print(("[LATENCY] " .. L.profile_hint):format(resolutionKey(), remembered))
    end
    if CONFIG.applyOnStart then applyLowLatency() end
    if CONFIG.bridge then writeStatus() end   -- heartbeat initial pour l'app
end)

-- Mode AUTO : après autoWarmup secondes de mesure, applique une seule fois
-- le cap optimal calculé (referme la boucle sans intervention).
local function autoTuneTick(delta)
    if not CONFIG.autoTune or M.autoApplied then return end
    M.autoElapsed = M.autoElapsed + delta
    if M.autoElapsed < CONFIG.autoWarmup then return end
    local s = computeStats()
    if s and s.samples >= CONFIG.autoMinSamples and s.cap > 0 then
        applyLowLatency(s.cap)
        M.autoApplied = true
        local msg = L.auto_applied:format(s.cap)
        screenMessage(msg)
        print("[LATENCY] " .. msg)
    end
end

-- Mesure chaque frame (pur Lua, négligeable) ; l'affichage, l'auto-tune et
-- le pont vers l'app sont throttlés / conditionnels.
registerForEvent("onUpdate", function(delta)
    sample(delta)
    autoTuneTick(delta)
    bridgeTick(delta)
end)

-- L'app peut aussi être arrêtée proprement : on laisse un dernier statut.
registerForEvent("onShutdown", function()
    if CONFIG.bridge then pcall(writeStatus) end
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

registerHotkey("lat_auto", "LATENCY — mode AUTO on/off / toggle auto-tune", function()
    setAutoTune(not CONFIG.autoTune)
    screenMessage(CONFIG.autoTune and L.auto_on or L.auto_off)
end)

registerHotkey("lat_restore", "LATENCY — restaurer mes réglages / restore my settings", function()
    restoreSettings()
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
            return { fps = 0, frametimeMs = 0, low1 = 0, low01 = 0, stutterPct = 0,
                     suggestedCap = 0, samples = 0, ready = false,
                     autoTune = CONFIG.autoTune, autoApplied = M.autoApplied }
        end
        return { fps = d.fps, frametimeMs = d.ms, low1 = d.low1, low01 = d.low01,
                 stutterPct = d.stutterPct, suggestedCap = d.cap,
                 samples = d.samples, ready = true,
                 autoTune = CONFIG.autoTune, autoApplied = M.autoApplied }
    end,
    ApplyLowLatency = applyLowLatency,
    ApplyClarity = applyClarity,
    Restore = restoreSettings,
    SetAutoTune = setAutoTune,
    GetProfiles = function()
        local out = {}
        for k, v in pairs(Profiles) do out[k] = v end
        return out
    end,
    Reset = resetMeter,
    ToggleOverlay = function()
        CONFIG.overlay = not CONFIG.overlay
        if not CONFIG.overlay then M.hud = nil end
        return CONFIG.overlay
    end,
    -- Pont avec l'app : forcer une synchro immédiate (l'app peut s'en servir
    -- au lieu d'attendre le prochain tick throttlé)
    PushStatus = function() if CONFIG.bridge then writeStatus() end end,
    PollCommands = function() if CONFIG.bridge then readCommand() end end,
    SetBridge = function(v) CONFIG.bridge = (v ~= false) end,
    Help = function()
        print("[LATENCY] Optimiseur de latence — commandes :")
        print("  .ApplyLowLatency()  — cap FPS conseillé + VSync off (best-effort)")
        print("  .GetStats()         — { fps, frametimeMs, low1, stutterPct, suggestedCap }")
        print("  .ApplyClarity()     — coupe flou/aberration/grain (netteté, PAS la latence)")
        print("  .Reset()  .ToggleOverlay()")
        print("  .PushStatus() / .PollCommands() — pont avec l'app AMD Optimizer")
        print("  Le compteur en haut à droite montre ta latence de rendu (ms) en direct.")
    end,
}
