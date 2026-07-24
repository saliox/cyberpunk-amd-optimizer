--------------------------------------------------------------------------
-- Stubs CET minimaux pour simuler BETTER MIX hors du jeu.
-- Charge le vrai init.lua, simule le SettingsSystem (volumes audio) et une
-- table de mixage ImGui scriptable (curseurs / boutons forçables), et vérifie
-- l'application des volumes + la gestion des préréglages (fichier presets.json
-- réel dans un dossier temporaire).
--------------------------------------------------------------------------

SIM = {
    settings = {},   -- "group|var" -> valeur écrite (les volumes audio)
    messages = {},
    logs = {},
    -- ImGui scriptable : sliderReturn[label]=valeur force un changement de
    -- curseur ; buttonPress[label]=true déclenche UN clic ; inputReturn[label]
    -- force le texte saisi.
    imgui = { push = 0, pop = 0, beginN = 0, endN = 0, textThrows = false,
              buttons = 0, sliders = 0,
              sliderReturn = {}, buttonPress = {}, inputReturn = {} },
    languageValue = "fr-fr",
}

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
            ConfirmChanges = function(self) SIM.confirmed = (SIM.confirmed or 0) + 1 end,
        }
    end,
}

ImGui = {
    SetNextWindowPos  = function() end,
    SetNextWindowSize = function() end,
    PushStyleColor = function(...) SIM.imgui.push = SIM.imgui.push + 1 end,
    PopStyleColor  = function(n) SIM.imgui.pop = SIM.imgui.pop + (n or 1) end,
    Begin = function(...) SIM.imgui.beginN = SIM.imgui.beginN + 1; return true end,
    End   = function() SIM.imgui.endN = SIM.imgui.endN + 1 end,
    Text        = function(...) if SIM.imgui.textThrows then error("bad Text") end end,
    TextColored = function(...) if SIM.imgui.textThrows then error("bad Text") end end,
    Separator = function() end,
    SameLine  = function() end,
    Spacing   = function() end,
    -- SliderInt(label, cur, min, max) -> (valeur, changed). sliderReturn force.
    SliderInt = function(label, cur, mn, mx)
        SIM.imgui.sliders = SIM.imgui.sliders + 1
        if SIM.imgui.textThrows then error("bad Slider") end
        local forced = SIM.imgui.sliderReturn[label]
        if forced ~= nil then return forced, true end
        return cur, false
    end,
    -- Button(label) -> pressed. buttonPress[label]=true déclenche un seul clic.
    Button = function(label, ...)
        SIM.imgui.buttons = SIM.imgui.buttons + 1
        if SIM.imgui.buttonPress[label] then
            SIM.imgui.buttonPress[label] = nil   -- un seul clic
            return true
        end
        return false
    end,
    -- InputText(label, text, size) -> (texte, changed). inputReturn force.
    InputText = function(label, text, size)
        local forced = SIM.imgui.inputReturn[label]
        if forced ~= nil then return forced, true end
        return text, false
    end,
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

function frame(dt) if EVENTS.onUpdate then EVENTS.onUpdate(dt) end end
function draw()    if EVENTS.onDraw  then EVENTS.onDraw()    end end
function press(id) if not HOTKEYS[id] then error("hotkey absent : " .. id) end HOTKEYS[id]() end

-- volume réellement écrit dans les réglages du jeu pour un canal
function audioSetting(var) return SIM.settings["/audio/volume|" .. var] end

function sawMessage(fragment)
    for _, m in ipairs(SIM.messages) do
        if tostring(m):find(fragment, 1, true) then return true end
    end
    return false
end

function expect(cond, msg)
    if not cond then error(msg or "assertion échouée", 2) end
end
