---@diagnostic disable: undefined-global

local ESX = exports["es_extended"]:getSharedObject()
local HUDVisible = Config.HUD.visible
local PlayerJob = nil
local PlayerGrade = 0
local TableOccupancy = {}
local SmokingActive = false
local SmokeCount = 0
local CurrentTableId = nil
local TargetZones = {}

-- Registriere Keybinds (im Spiel änderbar)
RegisterKeyMapping('shisha:order', Config.Keybinds.order.label, 'keyboard', Config.Keybinds.order.key)
RegisterKeyMapping('shisha:cancel', Config.Keybinds.cancel.label, 'keyboard', Config.Keybinds.cancel.key)
RegisterKeyMapping('shisha:drink', Config.Keybinds.drink.label, 'keyboard', Config.Keybinds.drink.key)
RegisterKeyMapping('shisha:menu', Config.Keybinds.menu.label, 'keyboard', Config.Keybinds.menu.key)
RegisterKeyMapping('shisha:bossMenu', Config.Keybinds.bossMenu.label, 'keyboard', Config.Keybinds.bossMenu.key)
RegisterKeyMapping('shisha:toggleHUD', Config.Keybinds.toggleHUD.label, 'keyboard', Config.Keybinds.toggleHUD.key)
RegisterKeyMapping('shisha:smoke', Config.Keybinds.smoke.label, 'keyboard', Config.Keybinds.smoke.key)

local function Notify(data)
    if exports.ox_lib and exports.ox_lib.notify then
        exports.ox_lib:notify(data)
        return
    end

    TriggerEvent('chat:addMessage', {
        color = {255, 0, 0},
        multiline = true,
        args = {'Shisha', (data.title and data.title .. ': ' or '') .. (data.description or '')}
    })
end

local function UpdatePlayerJob(job)
    if not job then return end
    PlayerJob = job.name
    PlayerGrade = tonumber(job.grade) or 0
end

CreateThread(function()
    while not ESX.PlayerData or not ESX.PlayerData.job do Wait(250) end
    UpdatePlayerJob(ESX.PlayerData.job)
end)

RegisterNetEvent('esx:setJob', function(job)
    UpdatePlayerJob(job)
end)

RegisterNetEvent('esx:playerLoaded', function(playerData)
    if playerData then UpdatePlayerJob(playerData.job) end
end)

-- Prüfe ob Job erlaubt ist
function IsJobAllowed()
    if not Config.JobRequired then return true end
    
    if Config.UseMultipleJobs then
        for _, job in ipairs(Config.AllowedJobs) do
            if PlayerJob == job[1] and PlayerGrade >= job[2] then
                return true
            end
        end
        return false
    else
        return PlayerJob == Config.Job and PlayerGrade >= Config.JobGradeRequired
    end
end

-- Hole Job-Anforderungen als Text
function GetJobRequirementText()
    if not Config.JobRequired then return "Kein Job erforderlich" end

    if Config.UseMultipleJobs then
        local jobList = ""
        for _, job in ipairs(Config.AllowedJobs) do
            jobList = jobList .. job[1] .. " (Grade " .. job[2] .. "+), "
        end
        return string.sub(jobList, 1, -3)  -- Entferne letztes Komma
    else
        return Config.Job .. " (Grade " .. Config.JobGradeRequired .. "+)"
    end
end

-- Berechne Job-Rabatt für Items
function GetJobDiscount(itemType)
    if not Config.JobFunctions or not Config.JobFunctions.discounts then return 0 end
    if not Config.JobFunctions.discounts[itemType] then return 0 end

    local grade = math.min(PlayerGrade, 5)  -- Max Grade 5 für Rabatte
    return Config.JobFunctions.discounts[itemType][grade] or 0
end

-- Berechne effektiven Preis mit Job-Rabatt
function GetEffectivePrice(basePrice, itemType)
    local discount = GetJobDiscount(itemType)
    if discount > 0 then
        return math.floor(basePrice * (1 - discount / 100))
    end
    return basePrice
end

-- Hole XP-Multiplikator basierend auf Job-Grad
function GetJobXPMultiplier()
    if not Config.JobFunctions or not Config.JobFunctions.xpMultiplier then return 1.0 end
    local grade = math.min(PlayerGrade, 5)  -- Max Grade 5 für Multiplikator
    return Config.JobFunctions.xpMultiplier[grade] or 1.0
end

-- Prüfe ob Item für Job-Grad verfügbar ist
function IsItemAvailableForJob(itemName, itemType)
    if not Config.JobFunctions or not Config.JobFunctions.exclusiveItems then return true end

    local exclusiveGrades = Config.JobFunctions.exclusiveItems
    for grade, items in pairs(exclusiveGrades) do
        if PlayerGrade >= grade then
            for _, item in ipairs(items) do
                if item == itemName then
                    return true
                end
            end
        end
    end

    -- Wenn Item nicht in exclusiveItems ist, ist es für alle verfügbar
    if itemType == "tray" then
        for grade, items in pairs(exclusiveGrades) do
            for _, item in ipairs(items) do
                if item == itemName then
                    return PlayerGrade >= grade
                end
            end
        end
        return true  -- Standard-Tabletts sind verfügbar
    elseif itemType == "mix" then
        for grade, items in pairs(exclusiveGrades) do
            for _, item in ipairs(items) do
                if item == itemName then
                    return PlayerGrade >= grade
                end
            end
        end
        return true  -- Standard-Mischungen sind verfügbar
    end

    return true
end

CreateThread(function()
    for i, tableConfig in pairs(Config.Tables) do
        local tableId = i
        local zoneId = exports.ox_target:addBoxZone({
            coords = tableConfig.coords,
            size = vec3(1.5,1.5,2.0),
            options = {
                {
                    label = 'Shisha bestellen (' .. tableConfig.label .. ')',
                    icon = "fa-smoking",
                    onSelect = function()
                        if not IsJobAllowed() then
                            Notify({
                                title = 'Shisha',
                                description = 'Erforderliche Jobs: ' .. GetJobRequirementText(),
                                type = 'error'
                            })
                            return
                        end
                        TriggerServerEvent('shisha:order', tableId)
                    end
                },
                {
                    label = 'Shisha-Menü öffnen',
                    icon = "fa-glass-martini",
                    onSelect = function()
                        if not IsJobAllowed() then
                            Notify({
                                title = 'Shisha',
                                description = 'Erforderliche Jobs: ' .. GetJobRequirementText(),
                                type = 'error'
                            })
                            return
                        end
                        OpenShishaMenu()
                    end
                }
            }
        })
        TargetZones[#TargetZones + 1] = zoneId
    end

    -- HUD-Konfiguration senden, falls aktiviert
    if Config.HUD.enabled then
        SendNUIMessage({
            action = "setHUDConfig",
            config = Config.HUD
        })
    end

    TriggerServerEvent('shisha:requestTableOccupancy')
end)

RegisterCommand('shisha:toggleHUD', function()
    ToggleHUD()
end)

function ToggleHUD()
    if not Config.HUD.enabled then return end
    HUDVisible = not HUDVisible
    SendNUIMessage({
        action = "toggleHUD",
        visible = HUDVisible
    })
end

function OpenShishaMenu()
    local menuData = lib.callback.await('shisha:getMenuData', false)
    if not menuData then return end

    SendNUIMessage({
        action = "openMenu",
        drinks = menuData.drinks or {},
        trays = menuData.trays or {},
        mixes = menuData.mixes or {},
        coal = menuData.coal or {},
        flavors = menuData.flavors or {},
        jobDiscounts = menuData.jobDiscounts or {}
    })
    SetNuiFocus(true, true)
end

-- Slash-Befehle registrieren
CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/shisha', Config.SlashCommands.shisha.label, {})
    TriggerEvent('chat:addSuggestion', '/hudon', Config.SlashCommands.hudon.label, {})
    TriggerEvent('chat:addSuggestion', '/hudoff', Config.SlashCommands.hudoff.label, {})
    TriggerEvent('chat:addSuggestion', '/help', Config.SlashCommands.help.label, {})
    TriggerEvent('chat:addSuggestion', '/drinks', Config.SlashCommands.drinks.label, {})
    TriggerEvent('chat:addSuggestion', '/mixes', Config.SlashCommands.mixes.label, {})
    TriggerEvent('chat:addSuggestion', '/trays', Config.SlashCommands.trays.label, {})
    TriggerEvent('chat:addSuggestion', '/flavors', 'Zeige verfügbare Shisha-Aromen', {})
    TriggerEvent('chat:addSuggestion', '/coal', Config.SlashCommands.coal.label, {})
    TriggerEvent('chat:addSuggestion', '/boss', Config.SlashCommands.boss.label, {})
end)

RegisterCommand('shisha', function(source, args, rawCommand)
    if not IsJobAllowed() then
        Notify({
            title = 'Shisha',
            description = 'Erforderliche Jobs: ' .. GetJobRequirementText(),
            type = 'error'
        })
        return
    end
    OpenShishaMenu()
end)

RegisterCommand('hudon', function(source, args, rawCommand)
    if not Config.HUD.enabled then
        Notify({
            title = 'Shisha',
            description = 'HUD ist deaktiviert',
            type = 'error'
        })
        return
    end
    HUDVisible = true
    SendNUIMessage({
        action = "toggleHUD",
        visible = true
    })
    Notify({
        title = 'Shisha',
        description = 'HUD ist jetzt sichtbar',
        type = 'success'
    })
end)

RegisterCommand('hudoff', function(source, args, rawCommand)
    if not Config.HUD.enabled then
        Notify({
            title = 'Shisha',
            description = 'HUD ist deaktiviert',
            type = 'error'
        })
        return
    end
    HUDVisible = false
    SendNUIMessage({
        action = "toggleHUD",
        visible = false
    })
    Notify({
        title = 'Shisha',
        description = 'HUD ist jetzt verborgen',
        type = 'success'
    })
end)

RegisterCommand('help', function(source, args, rawCommand)
    Notify({
        title = 'Shisha',
        description = 'Verfügbare Commands: /shisha, /hudon, /hudoff, /drinks, /mixes, /flavors, /coal',
        type = 'inform'
    })
end)

RegisterCommand('drinks', function(source, args, rawCommand)
    local drinksList = 'Verfügbare Getränke:'
    for drink, data in pairs(Config.Drinks) do
        drinksList = drinksList .. '\n' .. drink .. ' - $' .. data.price
    end
    Notify({
        title = 'Shisha',
        description = drinksList,
        type = 'inform'
    })
end)

RegisterCommand('mixes', function(source, args, rawCommand)
    local mixList = 'Verfügbare Alkohol-Mischungen:'
    for mix, data in pairs(Config.AlcoholMixes) do
        mixList = mixList .. '\n' .. mix .. ' - $' .. data.price
    end
    Notify({
        title = 'Shisha',
        description = mixList,
        type = 'inform'
    })
end)

RegisterCommand('trays', function(source, args, rawCommand)
    local trayList = 'Verfügbare Tabletts:'
    for tray, data in pairs(Config.Trays) do
        trayList = trayList .. '\n' .. tray .. ' - $' .. data.price
    end
    Notify({
        title = 'Shisha',
        description = trayList,
        type = 'inform'
    })
end)

RegisterCommand('flavors', function(source, args, rawCommand)
    local flavorList = 'Verfügbare Shisha-Aromen:'
    for flavor, data in pairs(Config.Flavors) do
        flavorList = flavorList .. '\n' .. flavor .. ' - XP: ' .. data.xp
    end
    Notify({
        title = 'Shisha',
        description = flavorList,
        type = 'inform'
    })
end)

RegisterCommand('coal', function(source, args, rawCommand)
    Notify({
        title = 'Shisha Kohle',
        description = Config.Coal.name .. ': $' .. Config.Coal.price .. '\n' .. Config.Coal.description,
        type = 'inform'
    })
end)

RegisterCommand('myjob', function(source, args, rawCommand)
    if PlayerJob then
        local jobText = 'Job: ' .. PlayerJob .. ' (Grade: ' .. PlayerGrade .. ')'
        local canUse = IsJobAllowed()
        local status = canUse and '✓ Du kannst Shisha nutzen' or '✗ Du kannst Shisha NICHT nutzen'
        
        Notify({
            title = 'Job Info',
            description = jobText .. '\n\n' .. status .. '\n\nErfordert: ' .. GetJobRequirementText(),
            type = canUse and 'success' or 'error'
        })
    else
        Notify({
            title = 'Job Info',
            description = 'Kein Job gefunden',
            type = 'error'
        })
    end
end)

RegisterCommand('boss', function(source, args, rawCommand)
    TriggerServerEvent('shisha:openBossMenu')
end)

local function ResetSmokingState(clearTasks)
    SmokingActive = false
    SmokeCount = 0
    CurrentTableId = nil
    if clearTasks then ClearPedTasks(PlayerPedId()) end
end

RegisterNetEvent('shisha:startSession', function(tableId, canSmoke)
    local ped = PlayerPedId()
    local tableConfig = Config.Tables[tonumber(tableId)]
    if not tableConfig or not tableConfig.seats or not tableConfig.seats[1] then return end
    local seat = tableConfig.seats[1]

    SetEntityCoords(ped, seat.x, seat.y, seat.z)
    SetEntityHeading(ped, seat.w)
    TaskStartScenarioAtPosition(ped, "PROP_HUMAN_SEAT_CHAIR", seat.x, seat.y, seat.z-1.0, seat.w, 0, true, true)

    CurrentTableId = tonumber(tableId)
    SmokingActive = canSmoke == true
    SmokeCount = 0
end)

RegisterNetEvent('shisha:coalReady', function()
    if not CurrentTableId then return end
    SmokingActive = true
    SmokeCount = 0
    Notify({title = 'Shisha', description = 'Kohle ist bereit. Du kannst jetzt rauchen.', type = 'success'})
end)

RegisterCommand('shisha:smoke', function()
    if not SmokingActive then
        Notify({title = 'Shisha', description = 'Du hast keine aktive Session mit Kohle.', type = 'error'})
        return
    end
    TriggerServerEvent('shisha:smoke')
end)

RegisterNetEvent('shisha:performSmoke', function(smokeCount)
    if not SmokingActive then return end
    SmokeCount = tonumber(smokeCount) or SmokeCount
    Smoke(PlayerPedId())
end)

RegisterNetEvent('shisha:sessionCompleted', function()
    Notify({title = 'Shisha', description = 'Session abgeschlossen!', type = 'success'})
    ResetSmokingState(true)
end)

RegisterNetEvent('shisha:sessionEnded', function()
    ResetSmokingState(true)
end)

function Smoke(ped)
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do Wait(0) end
    UseParticleFxAssetNextCall("core")

    StartParticleFxNonLoopedOnEntityBone(
        "exp_grd_smoke",
        ped,
        0.0,0.02,0.0,
        0.0,0.0,0.0,
        GetPedBoneIndex(ped,31086),
        1.2,
        false,false,false
    )
end

RegisterNetEvent('shisha:drinkEffect', function(effect)
    if effect == "DrunkBoost" then
        ShakeGameplayCam("DRUNK_SHAKE", 1.5)
        Notify({ title = 'Shisha', description = 'Alkohol-Mix: starke Wirkung!', type = 'success' })
        SetTimeout(8000, function()
            ShakeGameplayCam("DRUNK_SHAKE", 0.0)
        end)
    elseif effect == "DreamyVision" then
        SetTimecycleModifier("drug_flying_base")
        Notify({ title = 'Shisha', description = 'Alkohol-Mix: träumerische Sicht!', type = 'success' })
        SetTimeout(10000, function()
            ClearTimecycleModifier()
        end)
    elseif effect == "BitterGlow" then
        ShakeGameplayCam("DRUNK_SHAKE", 1.0)
        SetTimecycleModifier("hud_def_blur")
        Notify({ title = 'Shisha', description = 'Alkohol-Mix: intensives Erlebnis!', type = 'success' })
        SetTimeout(7000, function()
            ShakeGameplayCam("DRUNK_SHAKE", 0.0)
            ClearTimecycleModifier()
        end)
    else
        ShakeGameplayCam("DRUNK_SHAKE", 1.2)
        SetTimeout(5000, function()
            ShakeGameplayCam("DRUNK_SHAKE", 0.0)
        end)
    end
end)

RegisterNetEvent('shisha:flavorEffect', function(effect)
    if effect == "RaceTurbo" then
        -- Sprint-Boost
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.3)
        Notify({
            title = 'Shisha',
            description = 'Minze-Aroma: Sprint-Boost aktiviert!',
            type = 'success'
        })
        SetTimeout(30000, function()
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            Notify({
                title = 'Shisha',
                description = 'Sprint-Boost beendet',
                type = 'inform'
            })
        end)
    elseif effect == "DrugsTrevorClownsFight" then
        -- Visueller Effekt
        SetTimecycleModifier("drug_flying_base")
        Notify({
            title = 'Shisha',
            description = 'Traube-Aroma: Visueller Effekt aktiviert!',
            type = 'success'
        })
        SetTimeout(20000, function()
            ClearTimecycleModifier()
            Notify({
                title = 'Shisha',
                description = 'Visueller Effekt beendet',
                type = 'inform'
            })
        end)
    elseif effect == "SmoothSlide" then
        SetTimecycleModifier("rply_aop_gas_fog")
        Notify({
            title = 'Shisha',
            description = 'Wassermelone-Aroma: sanfter Nebel aktiviert!',
            type = 'success'
        })
        SetTimeout(15000, function()
            ClearTimecycleModifier()
        end)
    elseif effect == "AppleSizzle" then
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.2)
        Notify({
            title = 'Shisha',
            description = 'Apfel-Aroma: leichter Energieschub!',
            type = 'success'
        })
        SetTimeout(20000, function()
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        end)
    elseif effect == "WarmGlow" then
        SetTimecycleModifier("spectator5")
        Notify({
            title = 'Shisha',
            description = 'Vanille-Aroma: warmer Schein aktiviert!',
            type = 'success'
        })
        SetTimeout(15000, function()
            ClearTimecycleModifier()
        end)
    elseif effect == "CherryBliss" then
        SetTimecycleModifier("spectator3")
        Notify({
            title = 'Shisha',
            description = 'Kirsche-Aroma: glückseliges Feeling!',
            type = 'success'
        })
        SetTimeout(18000, function()
            ClearTimecycleModifier()
        end)
    elseif effect == "CitrusBuzz" then
        ShakeGameplayCam("DRUNK_SHAKE", 0.8)
        Notify({
            title = 'Shisha',
            description = 'Zitrone-Aroma: frischer Kick aktiviert!',
            type = 'success'
        })
        SetTimeout(12000, function()
            ShakeGameplayCam("DRUNK_SHAKE", 0.0)
        end)
    elseif effect == "TropicalFade" then
        SetTimecycleModifier("rply_sunrise")
        Notify({
            title = 'Shisha',
            description = 'Kokos-Aroma: tropisches Flair!',
            type = 'success'
        })
        SetTimeout(18000, function()
            ClearTimecycleModifier()
        end)
    end
end)

RegisterNetEvent('shisha:levelUp', function(level)
    Notify({
        title = 'Shisha',
        description = 'Level Up! Neues Level: ' .. level,
        type = 'success'
    })
end)

RegisterNetEvent('shisha:updateHUD', function(data)
    if Config.HUD.enabled then
        SendNUIMessage({
            action="updateHUD",
            level=data.level,
            xp=data.xp
        })
    end
end)

RegisterNetEvent('shisha:notify', function(message, notificationType)
    if message then
        local notifyType = 'inform'
        if notificationType == 'success' then
            notifyType = 'success'
        elseif notificationType == 'error' then
            notifyType = 'error'
        end
        Notify({
            title = 'Shisha',
            description = message,
            type = notifyType
        })
    end
end)

RegisterNetEvent('shisha:addCoal', function()
    Notify({
        title = 'Shisha',
        description = 'Du hast Shisha-Kohle gekauft. Du kannst jetzt rauchen.',
        type = 'success'
    })
end)

RegisterNetEvent('shisha:trayEffect', function(effect)
    if effect == "TrayCarry" then
        Notify({
            title = 'Shisha',
            description = 'Dein Tablett ist bereit. Service läuft!',
            type = 'success'
        })
    elseif effect == "TrayVIP" then
        Notify({
            title = 'Shisha',
            description = 'VIP-Tablett ist eingetroffen. Extra stylish!',
            type = 'success'
        })
    elseif effect == "TrayAroma" then
        Notify({
            title = 'Shisha',
            description = 'Aroma-Tablett liefert deinen Geschmack stilvoll.',
            type = 'success'
        })
    end
end)

RegisterNetEvent('shisha:openAdminMenu', function(config)
    SendNUIMessage({
        action = "openAdminMenu",
        config = config
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('shisha:setConfig', function(newConfig)
    if newConfig and type(newConfig) == 'table' then
        if newConfig.JobRequired ~= nil then Config.JobRequired = newConfig.JobRequired end
        if newConfig.Job ~= nil then Config.Job = newConfig.Job end
        if newConfig.JobGradeRequired ~= nil then Config.JobGradeRequired = newConfig.JobGradeRequired end
        if newConfig.HUD and type(newConfig.HUD) == 'table' then
            Config.HUD = Config.HUD or {}
            if newConfig.HUD.enabled ~= nil then Config.HUD.enabled = newConfig.HUD.enabled end
            if newConfig.HUD.position then Config.HUD.position = newConfig.HUD.position end
            if newConfig.HUD.colors then Config.HUD.colors = newConfig.HUD.colors end
            if newConfig.HUD.visible ~= nil then Config.HUD.visible = newConfig.HUD.visible end
        end
    end
end)

RegisterNetEvent('shisha:updateTableOccupancy', function(occupancy)
    if type(occupancy) == 'table' then
        TableOccupancy = occupancy
    end
end)

RegisterNUICallback('buyDrink', function(data, cb)
    if data and data.drink then
        TriggerServerEvent('shisha:buyDrink', data.drink)
    end
    cb('ok')
end)

RegisterNUICallback('buyFlavor', function(data, cb)
    if data and data.flavor then
        TriggerServerEvent('shisha:buyFlavor', data.flavor)
    end
    cb('ok')
end)

RegisterNUICallback('buyMix', function(data, cb)
    if data and data.mix then
        TriggerServerEvent('shisha:buyAlcoholMix', data.mix)
    end
    cb('ok')
end)

RegisterNUICallback('buyTray', function(data, cb)
    if data and data.tray then
        TriggerServerEvent('shisha:buyTray', data.tray)
    end
    cb('ok')
end)

-- Keybind-Event-Handler
RegisterCommand('shisha:order', function()
    if IsJobAllowed() then
        OpenShishaMenu()
    else
        Notify({
            title = 'Shisha',
            description = 'Du benötigst den Job: ' .. GetJobRequirementText(),
            type = 'error'
        })
    end
end)

RegisterCommand('shisha:cancel', function()
    TriggerServerEvent('shisha:cancelSession')
end)

RegisterCommand('shisha:drink', function()
    Notify({
        title = 'Shisha',
        description = 'Öffne das Shisha-Menü und kaufe ein Getränk, bevor du es trinkst.',
        type = 'inform'
    })
end)

RegisterCommand('shisha:menu', function()
    if IsJobAllowed() then
        OpenShishaMenu()
    else
        Notify({
            title = 'Shisha',
            description = 'Du benötigst den Job: ' .. GetJobRequirementText(),
            type = 'error'
        })
    end
end)

RegisterCommand('shisha:bossMenu', function()
    if not Config.BossMenu.enabled then
        Notify({
            title = 'Shisha',
            description = 'Boss-Menü ist deaktiviert',
            type = 'error'
        })
        return
    end

    -- Die endgültige Rechteprüfung erfolgt serverseitig (inklusive Admins).
    TriggerServerEvent('shisha:openBossMenu')
end)

RegisterNUICallback('buyCoal', function(data, cb)
    TriggerServerEvent('shisha:buyCoal')
    cb('ok')
end)

RegisterNUICallback('adminAction', function(data, cb)
    if data and data.action then
        TriggerServerEvent('shisha:adminAction', data.action, data.payload or {})
    end
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('bossAction', function(data, cb)
    if data and data.action then
        TriggerServerEvent('shisha:bossAction', data.action, data)
    end
    cb('ok')
end)

RegisterNetEvent('shisha:openBossMenu', function(config)
    local hour = GetClockHours()
    local minute = GetClockMinutes()
    config = config or {}
    config.currentHour = hour
    config.currentMinute = minute

    SendNUIMessage({
        action = "openBossMenu",
        config = config
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('shisha:setTime', function(hour, minute)
    local h = tonumber(hour) or 12
    local m = tonumber(minute) or 0
    if h < 0 then h = 0 elseif h > 23 then h = 23 end
    if m < 0 then m = 0 elseif m > 59 then m = 59 end
    NetworkOverrideClockTime(h, m, 0)
end)

RegisterNetEvent('shisha:bossStats', function(stats)
    SendNUIMessage({
        action = "bossStats",
        stats = stats
    })
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    local camCoord = GetGameplayCamCoords()
    local distance = #(camCoord - vector3(x, y, z))
    local scale = math.max(0.4, 1.0 / distance)

    SetTextScale(0.35 * scale, 0.35 * scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(1)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(_x, _y)
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local isNearAnyTable = false

        for tableId, tableConfig in pairs(Config.Tables) do
            local distance = #(playerCoords - tableConfig.coords)
            if distance <= 30.0 then
                isNearAnyTable = true
            local occupied = TableOccupancy[tableId]
            local colorR, colorG, colorB = 0, 255, 0
            local text = "Tisch frei"
            if occupied then
                colorR, colorG, colorB = 255, 0, 0
                text = "Tisch belegt"
            end

                DrawMarker(1, tableConfig.coords.x, tableConfig.coords.y, tableConfig.coords.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 0.5, colorR, colorG, colorB, 100, false, false, 2, false, nil, nil, false)
                DrawText3D(tableConfig.coords.x, tableConfig.coords.y, tableConfig.coords.z + 0.8, text)
            end
        end

        Wait(isNearAnyTable and 0 or 750)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    ClearTimecycleModifier()
    ShakeGameplayCam('DRUNK_SHAKE', 0.0)
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    ClearPedTasks(PlayerPedId())

    for _, zoneId in ipairs(TargetZones) do
        exports.ox_target:removeZone(zoneId)
    end
end)
