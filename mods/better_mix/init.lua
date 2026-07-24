--------------------------------------------------------------------------
-- BETTER MIX 1.0 — mod CET pour Cyberpunk 2077
--------------------------------------------------------------------------
-- Une TABLE DE MIXAGE en jeu : une fenêtre avec un curseur par canal audio
-- (dialogues, effets, musique, radio, téléphone, général) et des PRÉRÉGLAGES
-- SAUVEGARDÉS. Le mix par défaut de Cyberpunk noie souvent les dialogues sous
-- la musique et les SFX ; ce mod te laisse le rééquilibrer une fois pour
-- toutes et rappeler ton réglage d'un clic.
--
-- HONNÊTETÉ TECHNIQUE — ce que c'est / ce que ce n'est PAS :
--   • Le jeu passe par Wwise et n'expose aux mods QUE le volume de chaque
--     BUS audio, pas d'égaliseur paramétrique (graves/médiums/aigus). Il n'y
--     a donc pas d'EQ par bandes de fréquences accessible depuis CET.
--   • Ce que ce mod fait — et qui corrige réellement un mix mal fichu — c'est
--     RÉÉQUILIBRER le volume relatif des canaux (baisser la musique, monter
--     les dialogues, etc.) et mémoriser des présets. C'est le vrai sens de
--     « mieux mixer » ici.
--
-- Les valeurs (0–100) sont écrites via le SettingsSystem du jeu, exactement
-- comme le menu Audio — donc persistantes et sûres. Les chemins de variables
-- dépendent de la version du jeu : ils sont tous éditables dans CONFIG.
--
-- Requiert : Cyber Engine Tweaks (CET) 1.31+
-- Installation : dossier "better_mix" dans
--   <jeu>/bin/x64/plugins/cyber_engine_tweaks/mods/
--------------------------------------------------------------------------

local CONFIG = {
    language      = "auto",  -- "auto", "fr" ou "en"
    openOnStart   = false,   -- ouvrir la fenêtre de mixage au chargement
    applyLive     = true,    -- appliquer en direct pendant qu'on bouge un curseur
    applyThrottle = 0.12,    -- cadence max d'application (évite de spammer
                             -- ConfirmChanges pendant qu'on fait glisser)

    -- Canaux audio du jeu. group/var = chemin de la variable de réglage CET,
    -- comme dans le menu Audio ; ajuste-les ici si un canal ne « prend » pas
    -- sur ta version du jeu. Valeurs entières 0–100.
    channels = {
        { id = "master",   group = "/audio/volume", var = "MasterVolume",
          default = 100, label = { fr = "Général",        en = "Master" } },
        { id = "dialogue", group = "/audio/volume", var = "DialogVolume",
          default = 100, label = { fr = "Dialogues",      en = "Dialogue" } },
        { id = "sfx",      group = "/audio/volume", var = "SfxVolume",
          default = 100, label = { fr = "Effets (SFX)",   en = "SFX" } },
        { id = "music",    group = "/audio/volume", var = "MusicVolume",
          default = 100, label = { fr = "Musique",        en = "Music" } },
        { id = "radio",    group = "/audio/volume", var = "CarRadioVolume",
          default = 100, label = { fr = "Radio voiture",  en = "Car radio" } },
        { id = "phone",    group = "/audio/volume", var = "RadioportVolume",
          default = 100, label = { fr = "Téléphone",      en = "Phone" } },
    },
}

-- Présets d'usine : des équilibrages prêts à l'emploi qui corrigent les
-- travers du mix par défaut. Modifiables en jeu (Sauver écrase / ajoute).
local BUILTIN = {
    { key = "default",  name = "Défaut jeu",       nameEn = "Game default",
      values = { master = 100, dialogue = 100, sfx = 100, music = 100, radio = 100, phone = 100 } },
    { key = "dialogue", name = "Dialogues clairs", nameEn = "Clear dialogue",
      values = { master = 100, dialogue = 100, sfx = 75, music = 55, radio = 70, phone = 90 } },
    { key = "cinematic", name = "Cinématique",     nameEn = "Cinematic",
      values = { master = 100, dialogue = 100, sfx = 85, music = 80, radio = 75, phone = 85 } },
    { key = "combat",   name = "Combat",           nameEn = "Combat",
      values = { master = 100, dialogue = 95, sfx = 100, music = 45, radio = 40, phone = 70 } },
    { key = "driving",  name = "Conduite",         nameEn = "Driving",
      values = { master = 100, dialogue = 90, sfx = 80, music = 70, radio = 100, phone = 80 } },
    { key = "night",    name = "Nuit (discret)",   nameEn = "Night (quiet)",
      values = { master = 70, dialogue = 85, sfx = 65, music = 55, radio = 60, phone = 75 } },
}

local PRESETS_FILE = "presets.json"

--------------------------------------------------------------------------
-- Localisation
--------------------------------------------------------------------------

local LOCALES = {
    fr = {
        loaded       = "[BETTER MIX] Chargé. Ouvre la table de mixage (touche dédiée) ou GetMod(\"better_mix\").Help()",
        win_title    = "◤ BETTER MIX — table de mixage",
        win_hint     = "Rééquilibre les canaux, puis sauve ton préréglage.",
        win_presets  = "Préréglages :",
        win_custom   = "Mes préréglages :",
        win_name     = "Nom",
        win_save     = "Sauver",
        win_restore  = "Rétablir l'origine",
        win_close    = "Fermer",
        win_note     = "Astuce : les dialogues trop bas ? Monte « Dialogues », baisse « Musique ».",
        win_eq_note  = "Note : mixage par canaux (pas d'EQ par fréquences — non exposé par le jeu).",
        applied_preset = "Préréglage appliqué : %s",
        saved        = "Préréglage sauvegardé : %s",
        deleted      = "Préréglage supprimé : %s",
        restored     = "Réglages audio d'origine rétablis.",
        err_noname   = "Donne un nom au préréglage avant de sauver.",
        win_opened   = "Table de mixage : ouverte",
        win_closed   = "Table de mixage : fermée",
    },
    en = {
        loaded       = "[BETTER MIX] Loaded. Open the mixer (bound key) or GetMod(\"better_mix\").Help()",
        win_title    = "◤ BETTER MIX — mixing desk",
        win_hint     = "Re-balance the channels, then save your preset.",
        win_presets  = "Presets:",
        win_custom   = "My presets:",
        win_name     = "Name",
        win_save     = "Save",
        win_restore  = "Restore original",
        win_close    = "Close",
        win_note     = "Tip: dialogue too quiet? Raise \"Dialogue\", lower \"Music\".",
        win_eq_note  = "Note: per-channel mixing (no frequency EQ — the game doesn't expose one).",
        applied_preset = "Preset applied: %s",
        saved        = "Preset saved: %s",
        deleted      = "Preset deleted: %s",
        restored     = "Original audio settings restored.",
        err_noname   = "Name the preset before saving.",
        win_opened   = "Mixing desk: open",
        win_closed   = "Mixing desk: closed",
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
-- État
--------------------------------------------------------------------------

local M = {
    values = {},          -- id canal -> volume courant (0–100)
    original = nil,       -- instantané des volumes au chargement (pour Rétablir)
    userPresets = {},     -- { { name, values } … } chargés de presets.json
    windowOpen = false,
    windowDisabled = false,
    nameBuffer = "",
    pendingApply = false,
    applyTimer = 0,
}

local function clampVol(v)
    v = tonumber(v)
    if not v then return 0 end
    if v < 0 then v = 0 elseif v > 100 then v = 100 end
    return math.floor(v + 0.5)
end

--------------------------------------------------------------------------
-- Application via le SettingsSystem (comme le menu Audio du jeu)
--------------------------------------------------------------------------

local function settingsSystem()
    local sys
    pcall(function() sys = Game.GetSettingsSystem() end)
    return sys
end

-- Écrit un jeu de volumes dans les réglages du jeu. Renvoie le nb appliqué.
local function applyValues(values)
    local sys = settingsSystem()
    local n = 0
    for _, ch in ipairs(CONFIG.channels) do
        local target = values[ch.id]
        if target ~= nil then
            target = clampVol(target)
            M.values[ch.id] = target
            if sys then
                local ok = pcall(function() sys:GetVar(ch.group, ch.var):SetValue(target) end)
                if ok then n = n + 1 end
            end
        end
    end
    if sys then pcall(function() sys:ConfirmChanges() end) end
    return n
end

-- Lit les volumes ACTUELS du jeu (pour initialiser les curseurs et Rétablir)
local function captureCurrent()
    local sys = settingsSystem()
    local snap = {}
    for _, ch in ipairs(CONFIG.channels) do
        local v
        if sys then
            local ok, val = pcall(function() return sys:GetVar(ch.group, ch.var):GetValue() end)
            if ok and val ~= nil then v = val end
        end
        snap[ch.id] = (v ~= nil) and clampVol(v) or ch.default
    end
    return snap
end

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

--------------------------------------------------------------------------
-- Présets : présets d'usine + présets utilisateur (presets.json)
--------------------------------------------------------------------------

local function resolvedBuiltinName(b)
    return (LANG == "fr") and b.name or b.nameEn
end

-- Liste unifiée pour l'UI et l'API : présets d'usine puis présets utilisateur
local function listPresets()
    local out = {}
    for _, b in ipairs(BUILTIN) do
        out[#out + 1] = { name = resolvedBuiltinName(b), display = resolvedBuiltinName(b),
                          key = b.key, builtin = true, values = b.values }
    end
    for _, p in ipairs(M.userPresets) do
        out[#out + 1] = { name = p.name, display = p.name, builtin = false, values = p.values }
    end
    return out
end

-- Retrouve un préset par clé d'usine, nom fr/en d'usine, ou nom utilisateur
local function findPreset(q)
    q = tostring(q or "")
    for _, b in ipairs(BUILTIN) do
        if b.key == q or b.name == q or b.nameEn == q then return b.values, resolvedBuiltinName(b) end
    end
    for _, p in ipairs(M.userPresets) do
        if p.name == q then return p.values, p.name end
    end
    return nil
end

local function applyPreset(q)
    local vals, disp = findPreset(q)
    if not vals then return false end
    applyValues(vals)
    screenMessage(L.applied_preset:format(disp))
    print("[BETTER MIX] " .. L.applied_preset:format(disp))
    return true
end

local function sanitizeName(s)
    s = tostring(s or ""):gsub('[%c"{}%[%]]', '')
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if #s > 32 then s = s:sub(1, 32) end
    return s
end

local function savePresetsFile()
    pcall(function()
        local parts = {}
        for _, p in ipairs(M.userPresets) do
            local v = p.values
            parts[#parts + 1] = string.format(
                '{"name":"%s","master":%d,"dialogue":%d,"sfx":%d,"music":%d,"radio":%d,"phone":%d}',
                (p.name:gsub('"', "'")), clampVol(v.master), clampVol(v.dialogue),
                clampVol(v.sfx), clampVol(v.music), clampVol(v.radio), clampVol(v.phone))
        end
        local f = io.open(PRESETS_FILE, "w")
        if f then f:write("[\n" .. table.concat(parts, ",\n") .. "\n]"); f:close() end
    end)
end

local function loadPresets()
    M.userPresets = {}
    pcall(function()
        local f = io.open(PRESETS_FILE, "r")
        if not f then return end
        local raw = f:read("*a"); f:close()
        if not raw or #raw > 65536 then return end   -- garde-fou : fichier anormal ignoré
        for block in raw:gmatch('%b{}') do
            local name = block:match('"name"%s*:%s*"([^"]*)"')
            if name and name ~= "" then
                local vals = {}
                for _, ch in ipairs(CONFIG.channels) do
                    vals[ch.id] = clampVol(tonumber(block:match('"' .. ch.id .. '"%s*:%s*(%-?%d+)')) or ch.default)
                end
                M.userPresets[#M.userPresets + 1] = { name = name, values = vals }
            end
        end
    end)
end

-- Sauve les volumes courants comme préréglage utilisateur (écrase si le nom
-- existe déjà). Renvoie ok, message.
local function savePreset(name)
    name = sanitizeName(name)
    if name == "" then return false, L.err_noname end
    local vals = {}
    for _, ch in ipairs(CONFIG.channels) do
        vals[ch.id] = clampVol(M.values[ch.id] or ch.default)
    end
    for _, p in ipairs(M.userPresets) do
        if p.name == name then p.values = vals; savePresetsFile(); return true, L.saved:format(name) end
    end
    M.userPresets[#M.userPresets + 1] = { name = name, values = vals }
    savePresetsFile()
    return true, L.saved:format(name)
end

local function deletePreset(name)
    name = tostring(name or "")
    for i, p in ipairs(M.userPresets) do
        if p.name == name then
            table.remove(M.userPresets, i)
            savePresetsFile()
            return true
        end
    end
    return false
end

local function restoreOriginal()
    if not M.original then return 0 end
    local n = applyValues(M.original)
    screenMessage(L.restored)
    print("[BETTER MIX] " .. L.restored)
    return n
end

--------------------------------------------------------------------------
-- Fenêtre de mixage (ImGui) — logique dans les handlers, rendu ici seulement
--------------------------------------------------------------------------

local function renderWindow()
    local flags = ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoFocusOnAppearing
    ImGui.SetNextWindowPos(220, 200, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(340, 0, ImGuiCond.FirstUseEver)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.02, 0.02, 0.05, 0.92)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.30, 0.91, 0.96, 0.55)
    if ImGui.Begin("BETTER MIX", flags) then
        ImGui.TextColored(0.30, 0.91, 0.96, 1.0, L.win_title)
        ImGui.Text(L.win_hint)
        ImGui.Separator()

        -- un curseur par canal audio
        for _, ch in ipairs(CONFIG.channels) do
            local cur = M.values[ch.id] or ch.default
            local v, changed = ImGui.SliderInt(T(ch.label), cur, 0, 100)
            if changed then
                M.values[ch.id] = clampVol(v)
                if CONFIG.applyLive then M.pendingApply = true end
            end
        end

        ImGui.Separator()
        ImGui.Text(L.win_presets)
        for _, b in ipairs(BUILTIN) do
            if ImGui.Button(resolvedBuiltinName(b)) then applyPreset(b.key) end
        end

        if #M.userPresets > 0 then
            ImGui.Separator()
            ImGui.Text(L.win_custom)
            for _, p in ipairs(M.userPresets) do
                if ImGui.Button(p.name) then applyPreset(p.name) end
                ImGui.SameLine()
                if ImGui.Button("x##" .. p.name) then deletePreset(p.name) end
            end
        end

        ImGui.Separator()
        local txt = ImGui.InputText(L.win_name, M.nameBuffer, 32)
        M.nameBuffer = txt or M.nameBuffer
        ImGui.SameLine()
        if ImGui.Button(L.win_save) then
            local ok, msg = savePreset(M.nameBuffer)
            screenMessage(msg)
            if ok then M.nameBuffer = "" end
        end

        if ImGui.Button(L.win_restore) then restoreOriginal() end
        ImGui.SameLine()
        if ImGui.Button(L.win_close) then M.windowOpen = false end

        ImGui.Separator()
        ImGui.TextColored(0.66, 0.66, 0.72, 1.0, L.win_note)
        ImGui.TextColored(0.55, 0.55, 0.62, 1.0, L.win_eq_note)
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
    loadPresets()
    M.original = captureCurrent()
    for id, v in pairs(M.original) do M.values[id] = v end
    M.windowOpen = CONFIG.openOnStart and true or false
    print(L.loaded)
end)

-- Application throttlée : bouger un curseur marque un « à appliquer » ; on
-- écrit dans les réglages au plus une fois par applyThrottle (pas de spam de
-- ConfirmChanges pendant le glissement).
registerForEvent("onUpdate", function(delta)
    if not M.pendingApply then return end
    M.applyTimer = M.applyTimer + (delta or 0)
    if M.applyTimer < CONFIG.applyThrottle then return end
    M.applyTimer = 0
    M.pendingApply = false
    applyValues(M.values)
end)

registerForEvent("onDraw", function()
    if M.windowDisabled or not M.windowOpen then return end
    local ok, err = pcall(renderWindow)
    if not ok then
        M.windowDisabled = true
        pcall(function() ImGui.End() end)
        pcall(function() ImGui.PopStyleColor(2) end)
        print("[BETTER MIX] Fenêtre désactivée après une erreur ImGui : " .. tostring(err))
    end
end)

registerHotkey("bm_toggle", "BETTER MIX — ouvrir/fermer la table de mixage / toggle mixer", function()
    M.windowOpen = not M.windowOpen
    screenMessage(M.windowOpen and L.win_opened or L.win_closed)
end)

registerHotkey("bm_restore", "BETTER MIX — rétablir l'audio d'origine / restore original audio", function()
    restoreOriginal()
end)

--------------------------------------------------------------------------
-- API publique (console + tests)
--------------------------------------------------------------------------

return {
    -- volumes courants { master, dialogue, sfx, music, radio, phone }
    GetChannels = function()
        local out = {}
        for _, ch in ipairs(CONFIG.channels) do out[ch.id] = M.values[ch.id] or ch.default end
        return out
    end,
    -- règle un canal et l'applique immédiatement
    SetChannel = function(id, value)
        for _, ch in ipairs(CONFIG.channels) do
            if ch.id == id then
                M.values[id] = clampVol(value)
                applyValues({ [id] = M.values[id] })
                return M.values[id]
            end
        end
        return nil
    end,
    ApplyPreset = applyPreset,
    SavePreset  = savePreset,
    DeletePreset = deletePreset,
    ListPresets = function()
        local names = {}
        for _, p in ipairs(listPresets()) do names[#names + 1] = p.display end
        return names
    end,
    GetPreset = function(q)
        local vals = findPreset(q)
        if not vals then return nil end
        local out = {}
        for _, ch in ipairs(CONFIG.channels) do out[ch.id] = clampVol(vals[ch.id] or ch.default) end
        return out
    end,
    Restore = restoreOriginal,
    ReloadPresets = loadPresets,
    ToggleWindow = function() M.windowOpen = not M.windowOpen; return M.windowOpen end,
    ShowWindow = function() M.windowOpen = true end,
    HideWindow = function() M.windowOpen = false end,
    IsWindowOpen = function() return M.windowOpen end,
    Help = function()
        print("[BETTER MIX] Table de mixage audio — commandes :")
        print("  .ToggleWindow()      — ouvre/ferme la fenêtre de mixage")
        print("  .ApplyPreset(nom)    — 'dialogue','cinematic','combat','driving','night','default' ou un préréglage à toi")
        print("  .SetChannel(id, 0-100) — id : master, dialogue, sfx, music, radio, phone")
        print("  .SavePreset(nom) / .DeletePreset(nom) / .ListPresets()")
        print("  .Restore()           — rétablit les volumes d'origine")
        print("  Rappel : mixage par CANAUX (le jeu n'expose pas d'EQ par fréquences).")
    end,
}
