--------------------------------------------------------------------------
-- Stubs CET minimaux pour simuler LATENCY OPTIMIZER hors du jeu.
-- Charge le vrai init.lua, alimente des frametimes synthétiques, et vérifie
-- la MESURE (FPS, 1% low, saccades, cap conseillé) et l'application des
-- réglages (best-effort) via un SettingsSystem enregistreur.
--------------------------------------------------------------------------

SIM = {
    settings = {},   -- "group|var" -> valeur écrite
    messages = {},
    logs = {},
    imgui = { push = 0, pop = 0, beginN = 0, endN = 0, textThrows = false },
    languageValue = "fr-fr",
}

Vector4 = { new = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end }
SimpleScreenMessage = { new = function() return {} end }
function ToVariant(x) return x end

Game = {
    GetAllBlackboardDefs = function()
        return { UI_Notifications = { OnscreenMessage = "OnscreenMessage" } }
    end,
    GetBlackboardSystem = function()
        return { Get = function(self, def)
            return { SetVariant = function(self2, slot, variant)
                if variant and variant.message then table.insert(SIM.messages, variant.message) end
            end }
        end }
    end,
    GetSettingsSystem = function()
        return {
            GetVar = function(self, group, var)
                local key = group .. "|" .. var
                return {
                    SetValue = function(self2, value) SIM.settings[key] = value end,
                    GetValue = function(self2)
                        if key == "/language|OnScreen" then return SIM.languageValue end
                        return SIM.settings[key]
                    end,
                }
            end,
            ConfirmChanges = function(self) end,
        }
    end,
}

ImGui = {
    SetNextWindowPos = function() end,
    PushStyleColor = function(...) SIM.imgui.push = SIM.imgui.push + 1 end,
    PopStyleColor = function(n) SIM.imgui.pop = SIM.imgui.pop + (n or 1) end,
    Begin = function(...) SIM.imgui.beginN = SIM.imgui.beginN + 1; return true end,
    End = function() SIM.imgui.endN = SIM.imgui.endN + 1 end,
    TextColored = function(...) if SIM.imgui.textThrows then error("bad Text") end end,
    Text = function(...) if SIM.imgui.textThrows then error("bad Text") end end,
    Separator = function() end,
    PlotLines = function(...) SIM.imgui.plots = (SIM.imgui.plots or 0) + 1
        if SIM.imgui.textThrows then error("bad PlotLines") end end,
}
ImGuiWindowFlags = { NoTitleBar = 1, AlwaysAutoResize = 2, NoFocusOnAppearing = 4, NoNav = 8 }
ImGuiCond = { FirstUseEver = 1 }
ImGuiCol = { WindowBg = 1, Border = 2 }
function GetDisplayResolution() return 1920, 1080 end

EVENTS, HOTKEYS = {}, {}
function registerForEvent(name, fn) EVENTS[name] = fn end
function registerHotkey(id, label, fn) HOTKEYS[id] = fn end

print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    table.insert(SIM.logs, table.concat(parts, " "))
end

function loadMod()
    MOD = dofile(INIT_PATH)
    if EVENTS.onInit then EVENTS.onInit() end
    return MOD
end

-- Simule une frame de durée dt secondes (déclenche onUpdate)
function frame(dt) if EVENTS.onUpdate then EVENTS.onUpdate(dt) end end
function draw()   if EVENTS.onDraw  then EVENTS.onDraw()    end end
function press(id) HOTKEYS[id]() end

-- Alimente n frames à un FPS constant
function feedFps(fps, seconds)
    local dt = 1 / fps
    local n = math.floor(fps * seconds)
    for _ = 1, n do frame(dt) end
end

function expect(cond, msg)
    if not cond then error(msg or "assertion échouée", 2) end
end

function approx(a, b, tol)
    return math.abs(a - b) <= (tol or 0.5)
end
