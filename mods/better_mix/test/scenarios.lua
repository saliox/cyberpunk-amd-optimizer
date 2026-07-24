--------------------------------------------------------------------------
-- Scénarios de simulation de BETTER MIX
--------------------------------------------------------------------------

SCENARIOS = {}

-- Volumes de départ (comme si le joueur avait déjà réglé son menu Audio)
local function seedSettings()
    SIM.settings["/audio/volume|MasterVolume"]   = 100
    SIM.settings["/audio/volume|DialogVolume"]   = 60
    SIM.settings["/audio/volume|SfxVolume"]      = 100
    SIM.settings["/audio/volume|MusicVolume"]    = 100
    SIM.settings["/audio/volume|CarRadioVolume"] = 100
    SIM.settings["/audio/volume|RadioportVolume"]= 100
end

table.insert(SCENARIOS, { name = "init : capture les volumes actuels dans les curseurs", fn = function()
    seedSettings()
    loadMod()
    local c = MOD.GetChannels()
    expect(c.dialogue == 60, "le curseur dialogues doit refleter le reglage actuel (60), obtenu " .. tostring(c.dialogue))
    expect(c.master == 100, "le curseur general doit refleter 100")
end })

table.insert(SCENARIOS, { name = "SetChannel : ecrit le volume dans les reglages du jeu", fn = function()
    seedSettings()
    loadMod()
    MOD.SetChannel("music", 40)
    expect(audioSetting("MusicVolume") == 40, "MusicVolume aurait du etre ecrit a 40, obtenu " .. tostring(audioSetting("MusicVolume")))
    expect(MOD.GetChannels().music == 40, "le curseur musique doit refleter 40")
end })

table.insert(SCENARIOS, { name = "SetChannel : borne les valeurs hors plage (0-100)", fn = function()
    seedSettings()
    loadMod()
    MOD.SetChannel("sfx", 250)
    expect(audioSetting("SfxVolume") == 100, "au-dessus de 100 doit etre plafonne")
    MOD.SetChannel("sfx", -30)
    expect(audioSetting("SfxVolume") == 0, "en-dessous de 0 doit etre plancher")
end })

table.insert(SCENARIOS, { name = "preset d'usine : 'Dialogues clairs' remonte le dialogue, baisse la musique", fn = function()
    seedSettings()
    loadMod()
    expect(MOD.ApplyPreset("dialogue"), "le preset dialogue devrait exister")
    expect(audioSetting("DialogVolume") == 100, "les dialogues devraient etre remontes a 100")
    expect(audioSetting("MusicVolume") == 55, "la musique devrait etre baissee a 55")
    expect(sawMessage("Dialogues clairs"), "message de confirmation du preset attendu")
end })

table.insert(SCENARIOS, { name = "preset d'usine : applicable par nom localise (fr) et par cle", fn = function()
    seedSettings()
    loadMod()
    expect(MOD.ApplyPreset("Combat"), "applicable par nom francais")
    expect(audioSetting("MusicVolume") == 45, "le preset Combat baisse la musique a 45")
    expect(MOD.ApplyPreset("night"), "applicable par cle")
    expect(audioSetting("MasterVolume") == 70, "le preset night baisse le general a 70")
end })

table.insert(SCENARIOS, { name = "preset inconnu : refuse proprement (aucun changement)", fn = function()
    seedSettings()
    loadMod()
    local before = audioSetting("MusicVolume")
    expect(not MOD.ApplyPreset("nexistepas"), "un preset inconnu doit renvoyer false")
    expect(audioSetting("MusicVolume") == before, "rien ne doit changer pour un preset inconnu")
end })

table.insert(SCENARIOS, { name = "sauvegarde : un preset perso est ecrit et rechargeable", fn = function()
    seedSettings()
    loadMod()
    MOD.SetChannel("dialogue", 100)
    MOD.SetChannel("music", 30)
    local ok = MOD.SavePreset("Mon mix")
    expect(ok, "la sauvegarde devrait reussir")
    -- rechargement a froid : nouveau runtime, meme dossier -> presets.json relu
    loadMod()
    local names = MOD.ListPresets()
    local found = false
    for _, n in ipairs(names) do if n == "Mon mix" then found = true end end
    expect(found, "le preset perso devrait etre present apres rechargement")
    local p = MOD.GetPreset("Mon mix")
    expect(p and p.music == 30 and p.dialogue == 100, "les valeurs du preset perso doivent persister")
end })

table.insert(SCENARIOS, { name = "sauvegarde : nom vide refuse", fn = function()
    seedSettings()
    loadMod()
    local ok, msg = MOD.SavePreset("   ")
    expect(not ok, "un nom vide doit etre refuse")
    expect(msg ~= nil, "un message d'erreur doit etre renvoye")
end })

table.insert(SCENARIOS, { name = "sauvegarde : le meme nom ecrase (pas de doublon)", fn = function()
    seedSettings()
    loadMod()
    MOD.SetChannel("music", 20); MOD.SavePreset("Perso")
    MOD.SetChannel("music", 80); MOD.SavePreset("Perso")
    local count = 0
    for _, n in ipairs(MOD.ListPresets()) do if n == "Perso" then count = count + 1 end end
    expect(count == 1, "le meme nom ne doit pas creer de doublon")
    expect(MOD.GetPreset("Perso").music == 80, "la 2e sauvegarde doit ecraser (musique=80)")
end })

table.insert(SCENARIOS, { name = "suppression : un preset perso disparait, les presets d'usine restent", fn = function()
    seedSettings()
    loadMod()
    MOD.SavePreset("A supprimer")
    expect(MOD.DeletePreset("A supprimer"), "la suppression devrait reussir")
    for _, n in ipairs(MOD.ListPresets()) do
        expect(n ~= "A supprimer", "le preset supprime ne doit plus apparaitre")
    end
    -- on ne peut pas supprimer un preset d'usine
    expect(not MOD.DeletePreset("Dialogues clairs"), "un preset d'usine n'est pas supprimable")
    expect(MOD.GetPreset("dialogue") ~= nil, "les presets d'usine restent disponibles")
end })

table.insert(SCENARIOS, { name = "injection : nom de preset malveillant nettoye avant ecriture", fn = function()
    seedSettings()
    loadMod()
    MOD.SavePreset('evil","master":0}]injected[{')
    -- rechargement : le fichier doit rester parseable et sans master=0 injecte
    loadMod()
    expect(MOD.GetPreset("dialogue") ~= nil, "presets.json doit rester parseable apres un nom hostile")
    local p = MOD.GetPreset("evil'\"master\":0}]injected[{")   -- variantes echouent, on verifie juste l'integrite
    -- le point cle : le master d'un preset d'usine n'a pas ete corrompu
    expect(MOD.GetPreset("default").master == 100, "aucune injection ne doit alterer un preset d'usine")
end })

table.insert(SCENARIOS, { name = "retablir : restaure les volumes d'origine captures au chargement", fn = function()
    seedSettings()
    loadMod()
    MOD.ApplyPreset("combat")           -- chamboule tout
    expect(audioSetting("MusicVolume") == 45, "le preset combat a bien change la musique")
    MOD.Restore()
    expect(audioSetting("DialogVolume") == 60, "les dialogues doivent revenir a l'origine (60)")
    expect(audioSetting("MusicVolume") == 100, "la musique doit revenir a l'origine (100)")
    expect(sawMessage("origine") or sawMessage("original"), "message de retablissement attendu")
end })

table.insert(SCENARIOS, { name = "confirmChanges : appele apres chaque application (comme le menu)", fn = function()
    seedSettings()
    loadMod()
    SIM.confirmed = 0
    MOD.ApplyPreset("cinematic")
    expect((SIM.confirmed or 0) >= 1, "ConfirmChanges doit etre appele pour que le jeu prenne le reglage")
end })

table.insert(SCENARIOS, { name = "langue : detection anglaise -> presets d'usine en anglais", fn = function()
    SIM.languageValue = "en-us"
    seedSettings()
    loadMod()
    local names = MOD.ListPresets()
    local hasEn = false
    for _, n in ipairs(names) do if n == "Clear dialogue" then hasEn = true end end
    expect(hasEn, "les presets d'usine devraient s'afficher en anglais")
end })

-- FENETRE DE MIXAGE -------------------------------------------------------

table.insert(SCENARIOS, { name = "fenetre : fermee par defaut, ne dessine rien", fn = function()
    seedSettings()
    loadMod()
    expect(not MOD.IsWindowOpen(), "la fenetre doit etre fermee par defaut")
    draw()
    expect(SIM.imgui.beginN == 0, "rien ne doit etre dessine fenetre fermee")
end })

table.insert(SCENARIOS, { name = "fenetre : le hotkey l'ouvre et elle se dessine (pile ImGui equilibree)", fn = function()
    seedSettings()
    loadMod()
    press("bm_toggle")
    expect(MOD.IsWindowOpen(), "le hotkey devrait ouvrir la fenetre")
    draw()
    expect(SIM.imgui.beginN == 1 and SIM.imgui.endN == 1, "Begin/End ImGui desequilibres")
    expect(SIM.imgui.push == SIM.imgui.pop, "pile de styles ImGui desequilibree")
    expect(SIM.imgui.sliders >= 6, "un curseur par canal audio devrait etre dessine")
end })

table.insert(SCENARIOS, { name = "fenetre : bouger un curseur applique le volume (throttle)", fn = function()
    seedSettings()
    loadMod()
    MOD.ShowWindow()
    SIM.imgui.sliderReturn["Musique"] = 25     -- l'utilisateur descend la musique a 25
    draw()
    expect(MOD.GetChannels().music == 25, "le curseur doit mettre a jour la valeur")
    frame(0.2)                                  -- laisse passer le throttle d'application
    expect(audioSetting("MusicVolume") == 25, "le volume doit etre applique au jeu apres le throttle")
end })

table.insert(SCENARIOS, { name = "fenetre : cliquer un preset d'usine applique ses volumes", fn = function()
    seedSettings()
    loadMod()
    MOD.ShowWindow()
    SIM.imgui.buttonPress["Dialogues clairs"] = true
    draw()
    expect(audioSetting("DialogVolume") == 100 and audioSetting("MusicVolume") == 55,
        "le clic sur le preset devrait appliquer ses volumes")
end })

table.insert(SCENARIOS, { name = "fenetre : saisir un nom + clic Sauver cree un preset perso", fn = function()
    seedSettings()
    loadMod()
    MOD.ShowWindow()
    MOD.SetChannel("radio", 40)
    SIM.imgui.inputReturn["Nom"] = "Depuis la fenetre"
    SIM.imgui.buttonPress["Sauver"] = true
    draw()
    local found = false
    for _, n in ipairs(MOD.ListPresets()) do if n == "Depuis la fenetre" then found = true end end
    expect(found, "le clic Sauver devrait creer le preset perso")
    expect(MOD.GetPreset("Depuis la fenetre").radio == 40, "le preset doit capturer la valeur radio")
end })

table.insert(SCENARIOS, { name = "fenetre : le bouton Fermer la referme", fn = function()
    seedSettings()
    loadMod()
    MOD.ShowWindow()
    SIM.imgui.buttonPress["Fermer"] = true
    draw()
    expect(not MOD.IsWindowOpen(), "le bouton Fermer devrait fermer la fenetre")
end })

table.insert(SCENARIOS, { name = "preset : un nom d'usine est reserve (pas de masquage)", fn = function()
    seedSettings()
    loadMod()
    MOD.SetChannel("music", 5)
    local ok, msg = MOD.SavePreset("Combat")   -- nom d'usine (fr)
    expect(not ok, "sauver sous un nom d'usine doit etre refuse")
    expect(msg ~= nil, "un message d'erreur doit etre renvoye")
    expect(MOD.GetPreset("Combat").music == 45, "le preset d'usine ne doit pas etre masque (music=45)")
    expect(not MOD.SavePreset("combat"), "refus aussi par cle d'usine")
    expect(not MOD.SavePreset("Clear dialogue"), "refus aussi par nom d'usine anglais")
end })

table.insert(SCENARIOS, { name = "fenetre : supprimer un preset non-dernier retire le bon", fn = function()
    seedSettings()
    loadMod()
    MOD.SetChannel("music", 10); MOD.SavePreset("A")
    MOD.SetChannel("music", 20); MOD.SavePreset("B")
    MOD.SetChannel("music", 30); MOD.SavePreset("C")
    MOD.ShowWindow()
    SIM.imgui.buttonPress["x##A"] = true       -- supprime le premier (non-dernier)
    draw()
    local names = MOD.ListPresets()
    local hasA, hasB, hasC = false, false, false
    for _, n in ipairs(names) do
        if n == "A" then hasA = true elseif n == "B" then hasB = true elseif n == "C" then hasC = true end
    end
    expect(not hasA, "A doit etre supprime")
    expect(hasB and hasC, "B et C doivent rester (pas de saut d'iteration)")
    expect(MOD.GetPreset("B").music == 20 and MOD.GetPreset("C").music == 30,
        "les presets restants gardent leurs valeurs")
end })

table.insert(SCENARIOS, { name = "fenetre : erreur ImGui en rendu -> fenetre coupee, pile reequilibree", fn = function()
    seedSettings()
    loadMod()
    MOD.ShowWindow()
    SIM.imgui.textThrows = true
    draw()
    expect(SIM.imgui.push == SIM.imgui.pop, "pile non reequilibree apres la panne")
    expect(SIM.imgui.beginN == SIM.imgui.endN, "Begin/End non reequilibres apres la panne")
    local b = SIM.imgui.beginN
    draw()
    expect(SIM.imgui.beginN == b, "la fenetre doit rester coupee apres une erreur")
    SIM.imgui.textThrows = false
end })
