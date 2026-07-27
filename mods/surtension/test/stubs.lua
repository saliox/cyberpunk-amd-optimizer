--------------------------------------------------------------------------
-- Stubs de l'environnement CET / Codeware pour simuler SURTENSION
-- hors du jeu. Charge le vrai init.lua et pilote la mission frame par
-- frame. Valide la LOGIQUE du mod — pas les signatures réelles des API.
--------------------------------------------------------------------------

SIM = {
    simTime = 0,            -- temps de jeu simulé (secondes)
    wall = 1000000,         -- horloge murale simulée (os.time)
    player = { present = true, x = 0, y = 0, z = 0 },
    entities = {},          -- id -> { bornAt, dead, defeated, deleted }
    nextEntityId = 1,
    spawnDelay = 0.5,       -- latence de matérialisation des spawns
    messages = {},          -- tous les SimpleScreenMessage affichés
    sounds = {},
    logs = {},              -- sorties print() du mod
    mappins = {},
    mappinSeq = 0,
    effects = {},           -- effets de statut actifs sur le joueur
    dilation = nil,         -- dernier SetTimeDilation
    gameTime = { h = 14, m = 0 },
    timeSets = {},          -- historique des SetGameTimeByHMS
    weatherCalls = {},      -- "set:<état>" / "reset"
    inventory = {},
    vehicles = {},
    exp = {},
    imgui = { push = 0, pop = 0, beginN = 0, endN = 0, progressThrows = false, texts = {} },
    languageValue = "fr-fr",
}

--------------------------------------------------------------------------
-- Types valeur / enums
--------------------------------------------------------------------------

Vector4 = { new = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end }
Quaternion = { new = function() return {} end }
TweakDBID = { new = function(s) return s end }
SimpleScreenMessage = { new = function() return {} end }
MappinData = { new = function() return {} end }
DynamicEntitySpec = { new = function() return {} end }
function ToVariant(x) return x end
gamedataMappinVariant = { QuestGiverVariant = 1, ExclamationMarkVariant = 2 }

StatusEffectHelper = {
    RemoveStatusEffect = function(player, name)
        SIM.effects[name] = nil
    end,
}

--------------------------------------------------------------------------
-- Systèmes de jeu
--------------------------------------------------------------------------

local entitySystem = {
    CreateEntity = function(self, spec)
        local id = SIM.nextEntityId
        SIM.nextEntityId = id + 1
        SIM.entities[id] = {
            id = id, bornAt = SIM.simTime + SIM.spawnDelay,
            dead = false, defeated = false, deleted = false,
            record = spec.recordID,
        }
        return id
    end,
    GetEntity = function(self, id)
        local e = SIM.entities[id]
        if not e or e.deleted or SIM.simTime < e.bornAt then return nil end
        return {
            IsDead = function() return e.dead end,
            IsDefeated = function() return e.defeated end,
        }
    end,
    DeleteEntity = function(self, id)
        local e = SIM.entities[id]
        if e then e.deleted = true end
    end,
    DeleteTagged = function(self, tag)
        for _, e in pairs(SIM.entities) do e.deleted = true end
    end,
}

Game = {
    GetPlayer = function()
        if not SIM.player.present then return nil end
        return {
            GetWorldPosition = function(self)
                return { x = SIM.player.x, y = SIM.player.y, z = SIM.player.z, w = 1 }
            end,
            GetEntityID = function(self) return 1 end,
        }
    end,
    SetTimeDilation = function(v) SIM.dilation = v end,
    AddToInventory = function(item, qty)
        SIM.inventory[item] = (SIM.inventory[item] or 0) + (qty or 1)
    end,
    AddExp = function(kind, amount)
        SIM.exp[kind] = (SIM.exp[kind] or 0) + amount
    end,
    GetAllBlackboardDefs = function()
        return { UI_Notifications = { OnscreenMessage = "OnscreenMessage" } }
    end,
    GetBlackboardSystem = function()
        return { Get = function(self, def)
            return { SetVariant = function(self2, slot, variant, flag)
                if variant and variant.message then
                    table.insert(SIM.messages, variant.message)
                end
            end }
        end }
    end,
    GetAudioSystem = function()
        return { Play = function(self, ev) table.insert(SIM.sounds, ev) end }
    end,
    GetMappinSystem = function()
        return {
            RegisterMappin = function(self, data, pos)
                SIM.mappinSeq = SIM.mappinSeq + 1
                SIM.mappins[SIM.mappinSeq] = pos
                return SIM.mappinSeq
            end,
            UnregisterMappin = function(self, id) SIM.mappins[id] = nil end,
        }
    end,
    GetDynamicEntitySystem = function() return entitySystem end,
    GetStatusEffectSystem = function()
        return { ApplyStatusEffect = function(self, entityId, name)
            SIM.effects[name] = true
        end }
    end,
    GetTimeSystem = function()
        return {
            SetGameTimeByHMS = function(self, h, m, s)
                SIM.gameTime = { h = h, m = m }
                table.insert(SIM.timeSets, { h = h, m = m })
            end,
            GetGameTime = function(self)
                local h, m = SIM.gameTime.h, SIM.gameTime.m
                return {
                    Hours = function(self2) return h end,
                    Minutes = function(self2) return m end,
                }
            end,
        }
    end,
    GetWeatherSystem = function()
        return {
            SetWeather = function(self, name, blend, prio)
                table.insert(SIM.weatherCalls, "set:" .. tostring(name))
            end,
            ResetWeather = function(self, force)
                table.insert(SIM.weatherCalls, "reset")
            end,
        }
    end,
    GetVehicleSystem = function()
        return { EnablePlayerVehicle = function(self, v, a, b) SIM.vehicles[v] = true end }
    end,
    GetSettingsSystem = function()
        return { GetVar = function(self, path, group)
            return { GetValue = function(self2) return SIM.languageValue end }
        end }
    end,
}

--------------------------------------------------------------------------
-- ImGui / affichage
--------------------------------------------------------------------------

ImGui = {
    SetNextWindowPos = function() end,
    PushStyleColor = function(...) SIM.imgui.push = SIM.imgui.push + 1 end,
    PopStyleColor = function(n) SIM.imgui.pop = SIM.imgui.pop + (n or 1) end,
    Begin = function(...) SIM.imgui.beginN = SIM.imgui.beginN + 1; return true end,
    End = function() SIM.imgui.endN = SIM.imgui.endN + 1 end,
    TextColored = function(...)
        local a = { ... }; local s = a[#a]
        if type(s) == "string" then SIM.imgui.texts[#SIM.imgui.texts + 1] = s end
    end,
    Text = function(s)
        if type(s) == "string" then SIM.imgui.texts[#SIM.imgui.texts + 1] = s end
    end,
    Separator = function() end,
    ProgressBar = function(...)
        if SIM.imgui.progressThrows then error("bad ProgressBar binding") end
    end,
}
ImGuiWindowFlags = { NoTitleBar = 1, AlwaysAutoResize = 2, NoFocusOnAppearing = 4, NoNav = 8 }
ImGuiCond = { FirstUseEver = 1 }
ImGuiCol = { WindowBg = 1, Border = 2, PlotHistogram = 3 }
function GetDisplayResolution() return 1920, 1080 end

--------------------------------------------------------------------------
-- CET : événements, hotkeys, print, horloge
--------------------------------------------------------------------------

EVENTS, HOTKEYS = {}, {}
function registerForEvent(name, fn) EVENTS[name] = fn end
function registerHotkey(id, label, fn) HOTKEYS[id] = fn end

print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    table.insert(SIM.logs, table.concat(parts, " "))
end

os.time = function() return math.floor(SIM.wall) end

--------------------------------------------------------------------------
-- Aides de scénario
--------------------------------------------------------------------------

function loadMod()
    MOD = dofile(INIT_PATH)
    if EVENTS.onInit then EVENTS.onInit() end
    return MOD
end

function tick(dt)
    SIM.simTime = SIM.simTime + dt
    SIM.wall = SIM.wall + dt
    if EVENTS.onUpdate then EVENTS.onUpdate(dt) end
end

function tickFor(seconds, dt)
    dt = dt or 0.1
    local t = 0
    while t < seconds - 1e-9 do
        tick(dt)
        t = t + dt
    end
end

function draw()
    SIM.imgui.texts = {}          -- ne garde que le texte du dessin courant
    if EVENTS.onDraw then EVENTS.onDraw() end
end

-- vrai si le HUD vient de dessiner un texte contenant `fragment`
function sawHudText(fragment)
    for _, s in ipairs(SIM.imgui.texts) do
        if s:find(fragment, 1, true) then return true end
    end
    return false
end

function press(id)
    local fn = HOTKEYS[id]
    if not fn then error("hotkey absent : " .. id) end
    fn()
end

function teleport(p) SIM.player.x, SIM.player.y, SIM.player.z = p.x, p.y, p.z end

function killAll()
    for _, e in pairs(SIM.entities) do
        if not e.deleted then e.dead = true end
    end
end

function defeatAll()
    for _, e in pairs(SIM.entities) do
        if not e.deleted then e.defeated = true end
    end
end

function spawnedCount()
    local n = 0
    for _, e in pairs(SIM.entities) do n = n + 1 end
    return n
end

function lastMessage() return SIM.messages[#SIM.messages] end

function sawMessage(fragment)
    for _, m in ipairs(SIM.messages) do
        if m:find(fragment, 1, true) then return true end
    end
    return false
end

function sawWeather(call)
    for _, w in ipairs(SIM.weatherCalls) do
        if w == call then return true end
    end
    return false
end

function sawLog(fragment)
    for _, m in ipairs(SIM.logs) do
        if m:find(fragment, 1, true) then return true end
    end
    return false
end

function activeMappins()
    local n = 0
    for _ in pairs(SIM.mappins) do n = n + 1 end
    return n
end

function expect(cond, msg)
    if not cond then error(msg or "assertion échouée", 2) end
end
