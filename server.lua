---@diagnostic disable: undefined-global

local ESX = exports["es_extended"]:getSharedObject()

local PlayerXP = {}
local PlayerSessions = {}

local function GetTableOccupancy()
    local occupancy = {}
    for _, session in pairs(PlayerSessions) do
        if type(session) == 'table' and session.tableId then
            occupancy[session.tableId] = true
        end
    end
    return occupancy
end

local function UpdateTableOccupancy()
    TriggerClientEvent('shisha:updateTableOccupancy', -1, GetTableOccupancy())
end

local function AddPlayerXP(src, amount)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- Berechne Job-XP-Multiplikator
    local multiplier = 1.0
    if Config.JobFunctions and Config.JobFunctions.xpMultiplier then
        local jobGrade = xPlayer.getJob().grade
        multiplier = Config.JobFunctions.xpMultiplier[jobGrade] or 1.0
    end

    local effectiveXP = math.floor(amount * multiplier)

    PlayerXP[src] = PlayerXP[src] or {xp = 0, level = 1}
    PlayerXP[src].xp = PlayerXP[src].xp + effectiveXP

    if PlayerXP[src].xp >= 100 then
        PlayerXP[src].xp = PlayerXP[src].xp - 100
        PlayerXP[src].level = PlayerXP[src].level + 1
        TriggerClientEvent('shisha:levelUp', src, PlayerXP[src].level)
        TriggerClientEvent('shisha:notify', src, "~g~Level Up! Neues Level: " .. PlayerXP[src].level, 'success')

        -- Prüfe auf Job-Progression Belohnungen
        if Config.JobFunctions and Config.JobFunctions.progressionRewards then
            local reward = Config.JobFunctions.progressionRewards[PlayerXP[src].level]
            if reward and reward.type == "bonus" then
                xPlayer.addMoney(reward.amount)
                TriggerClientEvent('shisha:notify', src, "~g~" .. reward.message, 'success')
            end
        end
    end

    TriggerClientEvent('shisha:updateHUD', src, PlayerXP[src])
end

-- Prüfe ob Job erlaubt ist
function IsJobAllowed(jobName, jobGrade)
    if not Config.JobRequired then return true end
    
    if Config.UseMultipleJobs then
        for _, job in ipairs(Config.AllowedJobs) do
            if jobName == job[1] and jobGrade >= job[2] then
                return true
            end
        end
        return false
    else
        return jobName == Config.Job and jobGrade >= Config.JobGradeRequired
    end
end

RegisterNetEvent('shisha:order', function(tableId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local table = Config.Tables[tableId]

    if not table then 
        TriggerClientEvent('shisha:notify', src, "~r~Tisch nicht gefunden", 'error')
        return 
    end

    if not xPlayer then return end

    -- Überprüfe Job-Anforderung
    if not IsJobAllowed(xPlayer.getJob().name, xPlayer.getJob().grade) then
        local jobText = "erforderlich"
        if Config.UseMultipleJobs then
            jobText = "Jobs: "
            for _, job in ipairs(Config.AllowedJobs) do
                jobText = jobText .. job[1] .. " (Grade " .. job[2] .. "+), "
            end
            jobText = string.sub(jobText, 1, -3)
        else
            jobText = "Job: " .. Config.Job .. " (Grade " .. Config.JobGradeRequired .. "+)"
        end
        TriggerClientEvent('shisha:notify', src, "~r~" .. jobText, 'error')
        return
    end

    if xPlayer.getMoney() < table.price then
        TriggerClientEvent('shisha:notify', src, "~r~Zu wenig Geld! Benötigt: $" .. table.price, 'error')
        return
    end

    local occupancy = GetTableOccupancy()
    if occupancy[tableId] then
        TriggerClientEvent('shisha:notify', src, "~r~Dieser Tisch ist bereits belegt", 'error')
        return
    end

    -- Check ob Spieler bereits in einer Session ist
    if PlayerSessions[src] then
        TriggerClientEvent('shisha:notify', src, "~r~Du bist bereits in einer Session", 'error')
        return
    end

    xPlayer.removeMoney(table.price)

    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_shisha', function(account)
        if account then
            account.addMoney(table.price)
        end
    end)

    PlayerSessions[src] = {tableId = tableId}
    UpdateTableOccupancy()
    TriggerClientEvent('shisha:startSession', src, tableId)
    TriggerClientEvent('shisha:notify', src, "~g~" .. table.label .. " gebucht!", 'success')
end)

RegisterNetEvent('shisha:buyDrink', function(drink)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local data = Config.Drinks[drink]

    if not data then
        TriggerClientEvent('shisha:notify', src, "~r~Getränk nicht gefunden", 'error')
        return
    end

    if not xPlayer then return end

    if xPlayer.getMoney() < data.price then
        TriggerClientEvent('shisha:notify', src, "~r~Zu wenig Geld! Preis: $" .. data.price, 'error')
        return
    end

    xPlayer.removeMoney(data.price)
    TriggerClientEvent('shisha:drinkEffect', src)
    TriggerClientEvent('shisha:notify', src, "~g~" .. drink .. " gekauft!", 'success')
end)

RegisterNetEvent('shisha:buyAlcoholMix', function(mix)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local data = Config.AlcoholMixes[mix]

    if not data then
        TriggerClientEvent('shisha:notify', src, "~r~Alkohol-Mischung nicht gefunden", 'error')
        return
    end

    if not xPlayer then return end

    if xPlayer.getMoney() < data.price then
        TriggerClientEvent('shisha:notify', src, "~r~Zu wenig Geld! Preis: $" .. data.price, 'error')
        return
    end

    xPlayer.removeMoney(data.price)
    TriggerClientEvent('shisha:drinkEffect', src, data.effect)
    AddPlayerXP(src, 15)
    TriggerClientEvent('shisha:notify', src, "~g~" .. mix .. " gekauft!", 'success')
end)

RegisterNetEvent('shisha:buyTray', function(tray)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local data = Config.Trays[tray]

    if not data then
        TriggerClientEvent('shisha:notify', src, "~r~Tablett nicht gefunden", 'error')
        return
    end

    if not xPlayer then return end

    if xPlayer.getMoney() < data.price then
        TriggerClientEvent('shisha:notify', src, "~r~Zu wenig Geld! Preis: $" .. data.price, 'error')
        return
    end

    xPlayer.removeMoney(data.price)
    TriggerClientEvent('shisha:trayEffect', src, data.effect)
    AddPlayerXP(src, data.xp or 5)
    TriggerClientEvent('shisha:notify', src, "~g~" .. tray .. " gekauft!", 'success')
end)

RegisterNetEvent('shisha:buyCoal', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local data = Config.Coal

    if not xPlayer then return end
    if not data then
        TriggerClientEvent('shisha:notify', src, "~r~Kohle-Konfiguration nicht gefunden", 'error')
        return
    end

    if xPlayer.getMoney() < data.price then
        TriggerClientEvent('shisha:notify', src, "~r~Zu wenig Geld! Preis: $" .. data.price, 'error')
        return
    end

    xPlayer.removeMoney(data.price)
    TriggerClientEvent('shisha:addCoal', src)
    TriggerClientEvent('shisha:notify', src, "~g~" .. data.name .. " gekauft!", 'success')
end)

RegisterNetEvent('shisha:buyFlavor', function(flavor)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local data = Config.Flavors[flavor]

    if not data then
        TriggerClientEvent('shisha:notify', src, "~r~Aroma nicht gefunden", 'error')
        return
    end

    if not xPlayer then return end

    -- Aromen kosten vielleicht Geld oder XP, hier kostenlos für Einfachheit
    TriggerClientEvent('shisha:flavorEffect', src, data.effect)
    TriggerClientEvent('shisha:notify', src, "~g~" .. flavor .. " Aroma aktiviert!", 'success')
end)

RegisterNetEvent('shisha:addXP', function(amount)
    local src = source

    PlayerXP[src] = PlayerXP[src] or {xp = 0, level = 1}
    PlayerXP[src].xp = PlayerXP[src].xp + amount

    if PlayerXP[src].xp >= 100 then
        PlayerXP[src].xp = 0
        PlayerXP[src].level = PlayerXP[src].level + 1
        TriggerClientEvent('shisha:levelUp', src, PlayerXP[src].level)
        TriggerClientEvent('shisha:notify', src, "~g~Level Up! Neues Level: " .. PlayerXP[src].level, 'success')
    end

    TriggerClientEvent('shisha:updateHUD', src, PlayerXP[src])
end)

RegisterNetEvent('shisha:endSession', function()
    local src = source
    if PlayerSessions[src] then
        PlayerSessions[src] = nil
        UpdateTableOccupancy()
        TriggerClientEvent('shisha:notify', src, "~y~Session beendet", 'info')
    end
end)

RegisterNetEvent('shisha:cancelSession', function()
    local src = source
    if PlayerSessions[src] then
        PlayerSessions[src] = nil
        UpdateTableOccupancy()
        TriggerClientEvent('shisha:notify', src, "~y~Shisha-Sitzung abgebrochen", 'info')
    else
        TriggerClientEvent('shisha:notify', src, "~y~Du hast keine aktive Shisha-Sitzung.", 'info')
    end
end)

RegisterNetEvent('shisha:requestTableOccupancy', function()
    local src = source
    TriggerClientEvent('shisha:updateTableOccupancy', src, GetTableOccupancy())
end)

-- Admin Command um alle Sessions zu sehen
TriggerEvent('chat:addSuggestion', '/shisha_sessions', 'Zeige alle aktiven Shisha-Sessions (Admin Command)')

RegisterCommand('shisha_sessions', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    local activeSessions = {}
    for playerId, _ in pairs(PlayerSessions) do
        local player = ESX.GetPlayerFromId(playerId)
        if player then
            table.insert(activeSessions, 'Spieler: ' .. player.getName() .. ' (ID: ' .. playerId .. ')')
        end
    end

    if #activeSessions == 0 then
        TriggerClientEvent('chat:addMessage', source, {args = {'~g~SHISHA', 'Keine aktiven Sessions'}})
    else
        TriggerClientEvent('chat:addMessage', source, {args = {'~g~SHISHA', 'Aktive Sessions:'}})
        for _, session in ipairs(activeSessions) do
            TriggerClientEvent('chat:addMessage', source, {args = {'', session}})
        end
    end
end, false)

-- Admin Command zum Ändern von Tisch-Preisen
TriggerEvent('chat:addSuggestion', '/shisha_price', 'Ändere Tisch-Preis: /shisha_price [tableId] [price]')

RegisterCommand('shisha_price', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    local tableId = tonumber(args[1])
    local price = tonumber(args[2])

    if not tableId or not price then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~FEHLER', 'Syntax: /shisha_price [tableId] [price]'}})
        return
    end

    if Config.Tables[tableId] then
        Config.Tables[tableId].price = price
        TriggerClientEvent('chat:addMessage', source, {args = {'~g~SHISHA', 'Preis für Tisch ' .. tableId .. ' auf $' .. price .. ' geändert'}})
    else
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~FEHLER', 'Tisch ' .. tableId .. ' nicht gefunden'}})
    end
end, false)

-- Admin Command zum Ändern von Getränk-Preisen
TriggerEvent('chat:addSuggestion', '/shisha_drink_price', 'Ändere Getränk-Preis: /shisha_drink_price [name] [price]')

RegisterCommand('shisha_drink_price', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    local drinkName = args[1]
    local price = tonumber(args[2])

    if not drinkName or not price then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~FEHLER', 'Syntax: /shisha_drink_price [name] [price]'}})
        return
    end

    if Config.Drinks[drinkName] then
        Config.Drinks[drinkName].price = price
        TriggerClientEvent('chat:addMessage', source, {args = {'~g~SHISHA', 'Preis für ' .. drinkName .. ' auf $' .. price .. ' geändert'}})
    else
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~FEHLER', 'Getränk ' .. drinkName .. ' nicht gefunden'}})
    end
end, false)

-- Admin Command zum Ändern der Job-Anforderung
TriggerEvent('chat:addSuggestion', '/shisha_job', 'Ändere Job-Anforderung: /shisha_job [true/false] [jobName] [grade]')

RegisterCommand('shisha_job', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    local jobRequired = args[1]
    local jobName = args[2] or Config.Job
    local jobGrade = tonumber(args[3]) or 0

    if jobRequired == 'true' then
        Config.JobRequired = true
        Config.Job = jobName
        Config.JobGradeRequired = jobGrade
        TriggerClientEvent('chat:addMessage', source, {args = {'~g~SHISHA', 'Job erforderlich: ' .. jobName .. ' (Grade ' .. jobGrade .. '+)'}})
    elseif jobRequired == 'false' then
        Config.JobRequired = false
        TriggerClientEvent('chat:addMessage', source, {args = {'~g~SHISHA', 'Job-Anforderung deaktiviert'}})
    else
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~FEHLER', 'Syntax: /shisha_job [true/false] [jobName] [grade]'}})
    end
end, false)

-- Admin Command um Shisha-Config zu sehen
TriggerEvent('chat:addSuggestion', '/shisha_config', 'Zeige aktuelle Shisha-Konfiguration')

RegisterCommand('shisha_config', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA CONFIG', '═════════════════════'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', 'Job erforderlich: ' .. tostring(Config.JobRequired)}})
    if Config.JobRequired then
        TriggerClientEvent('chat:addMessage', source, {args = {'', 'Job: ' .. Config.Job .. ' | Grade: ' .. Config.JobGradeRequired .. '+'}})
    end
    TriggerClientEvent('chat:addMessage', source, {args = {'', 'Tische: ' .. #Config.Tables}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', 'Getränke: ' .. #Config.Drinks}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', 'Aromen: ' .. #Config.Flavors}})
    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA CONFIG', '═════════════════════'}})
end, false)

-- Admin Command zum Anzeigen aller Tische
TriggerEvent('chat:addSuggestion', '/shisha_tables', 'Zeige alle Tische mit Preisen')

RegisterCommand('shisha_tables', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA TISCHE', '═════════════════════'}})
    for i, table in ipairs(Config.Tables) do
        TriggerClientEvent('chat:addMessage', source, {args = {'', 'ID: ' .. i .. ' | ' .. table.label .. ' | Preis: $' .. table.price}})
    end
    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA TISCHE', '═════════════════════'}})
end, false)

-- Admin Command zum Anzeigen aller Getränke
TriggerEvent('chat:addSuggestion', '/shisha_drinks', 'Zeige alle Getränke mit Preisen')

RegisterCommand('shisha_drinks', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA GETRÄNKE', '═════════════════════'}})
    for name, data in pairs(Config.Drinks) do
        TriggerClientEvent('chat:addMessage', source, {args = {'', name .. ' | Preis: $' .. data.price}})
    end
    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA GETRÄNKE', '═════════════════════'}})
end, false)

-- Admin Command zum Anzeigen aller Aromen
TriggerEvent('chat:addSuggestion', '/shisha_flavors', 'Zeige alle Aromen')

RegisterCommand('shisha_flavors', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA AROMEN', '═════════════════════'}})
    for name, data in pairs(Config.Flavors) do
        TriggerClientEvent('chat:addMessage', source, {args = {'', name .. ' | XP: ' .. data.xp .. ' | Effekt: ' .. data.effect}})
    end
    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA AROMEN', '═════════════════════'}})
end, false)

-- Admin Command zum Anzeigen aller Admin-Commands
TriggerEvent('chat:addSuggestion', '/shisha_help', 'Zeige alle Admin-Commands für Shisha')

RegisterCommand('shisha_help', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA ADMIN COMMANDS', '═════════════════════'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', '/shisha_config - Zeige Konfiguration'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', '/shisha_sessions - Zeige aktive Sessions'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', '/shisha_price [id] [price] - Ändere Tisch-Preis'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', '/shisha_drink_price [name] [price] - Ändere Getränk-Preis'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', '/shisha_job [true/false] [name] [grade] - Ändere Job'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', '/shisha_tables - Zeige alle Tische'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', '/shisha_drinks - Zeige alle Getränke'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', '/shisha_flavors - Zeige alle Aromen'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA ADMIN COMMANDS', '═════════════════════'}})
end, false)

RegisterCommand('shisha_admin', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and xPlayer.getGroup and xPlayer.getGroup() == 'admin' then
        local adminConfig = {
            JobRequired = Config.JobRequired,
            Job = Config.Job,
            JobGradeRequired = Config.JobGradeRequired,
            HUD = { enabled = Config.HUD.enabled },
            Tables = {},
            Drinks = {},
            Flavors = {}
        }

        for i, tbl in ipairs(Config.Tables) do
            table.insert(adminConfig.Tables, {id = i, label = tbl.label, price = tbl.price})
        end
        for name, data in pairs(Config.Drinks) do
            adminConfig.Drinks[name] = {price = data.price}
        end
        for name, data in pairs(Config.Flavors) do
            adminConfig.Flavors[name] = {xp = data.xp, effect = data.effect}
        end

        TriggerClientEvent('shisha:openAdminMenu', source, adminConfig)
    else
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
    end
end, false)

RegisterNetEvent('shisha:adminAction', function(action, payload)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', src, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    if action == 'toggleHudEnabled' then
        Config.HUD.enabled = not Config.HUD.enabled
        TriggerClientEvent('shisha:notify', src, '~g~HUD ' .. (Config.HUD.enabled and 'aktiviert' or 'deaktiviert'), 'success')
    elseif action == 'toggleJobRequired' then
        Config.JobRequired = not Config.JobRequired
        TriggerClientEvent('shisha:notify', src, '~g~Job-Anforderung ' .. (Config.JobRequired and 'aktiviert' or 'deaktiviert'), 'success')
    elseif action == 'setJob' and payload and payload.jobName then
        Config.Job = tostring(payload.jobName)
        TriggerClientEvent('shisha:notify', src, '~g~Job geändert auf: ' .. Config.Job, 'success')
    elseif action == 'setJobGrade' and payload and payload.grade ~= nil then
        Config.JobGradeRequired = tonumber(payload.grade) or 0
        TriggerClientEvent('shisha:notify', src, '~g~Job-Grad geändert auf: ' .. Config.JobGradeRequired, 'success')
    elseif action == 'setTablePrice' and payload and payload.tableId and payload.price then
        if Config.Tables[payload.tableId] then
            Config.Tables[payload.tableId].price = tonumber(payload.price) or Config.Tables[payload.tableId].price
            TriggerClientEvent('shisha:notify', src, '~g~Preis für Tisch ' .. payload.tableId .. ' aktualisiert', 'success')
        else
            TriggerClientEvent('shisha:notify', src, '~r~Tisch nicht gefunden', 'error')
        end
    elseif action == 'setDrinkPrice' and payload and payload.drinkName and payload.price then
        if Config.Drinks[payload.drinkName] then
            Config.Drinks[payload.drinkName].price = tonumber(payload.price) or Config.Drinks[payload.drinkName].price
            TriggerClientEvent('shisha:notify', src, '~g~Preis für ' .. payload.drinkName .. ' aktualisiert', 'success')
        else
            TriggerClientEvent('shisha:notify', src, '~r~Getränk nicht gefunden', 'error')
        end
    else
        TriggerClientEvent('shisha:notify', src, '~r~Unbekannte Admin-Aktion', 'error')
    end

    TriggerClientEvent('shisha:setConfig', -1, {
        JobRequired = Config.JobRequired,
        Job = Config.Job,
        JobGradeRequired = Config.JobGradeRequired,
        HUD = { enabled = Config.HUD.enabled }
    })
end)

RegisterNetEvent('shisha:openBossMenu', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    -- Prüfe ob Admin oder Boss (Job-Grade)
    local isAdmin = xPlayer and xPlayer.getGroup and xPlayer.getGroup() == 'admin'
    local isBoss = xPlayer and xPlayer.getJob and xPlayer.getJob().name == Config.Job and xPlayer.getJob().grade >= Config.BossMenu.bossGradeRequired
    
    if not (isAdmin or isBoss) then
        TriggerClientEvent('shisha:notify', src, 'Du hast keine Berechtigung für das Boss-Menü!', 'error')
        return
    end

    local bossConfig = {
        JobRequired = Config.JobRequired,
        Job = Config.Job,
        JobGradeRequired = Config.JobGradeRequired,
        HUD = { enabled = Config.HUD.enabled },
        KeyBindings = Config.KeyBindings,
        Tables = Config.Tables,
        Drinks = Config.Drinks,
        Trays = Config.Trays,
        Coal = Config.Coal,
        Flavors = Config.Flavors,
        isBoss = isBoss,
        isAdmin = isAdmin
    }

    TriggerClientEvent('shisha:openBossMenu', src, bossConfig)
end)

RegisterNetEvent('shisha:bossAction', function(action, data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    -- Prüfe ob Admin oder Boss (Job-Grade)
    local isAdmin = xPlayer and xPlayer.getGroup and xPlayer.getGroup() == 'admin'
    local isBoss = xPlayer and xPlayer.getJob and xPlayer.getJob().name == Config.Job and xPlayer.getJob().grade >= Config.BossMenu.bossGradeRequired
    
    if not (isAdmin or isBoss) then
        TriggerClientEvent('shisha:notify', src, 'Du hast keine Berechtigung!', 'error')
        return
    end

    -- Nur Admins dürfen bestimmte Aktionen durchführen
    if action == 'updateConfig' and not isAdmin then
        TriggerClientEvent('shisha:notify', src, 'Nur Admins können die Konfiguration ändern!', 'error')
        return
    end

    if action == 'updateConfig' then
        if data.jobRequired ~= nil then Config.JobRequired = data.jobRequired end
        if data.jobName then Config.Job = tostring(data.jobName) end
        if data.jobGrade ~= nil then Config.JobGradeRequired = tonumber(data.jobGrade) or 0 end
        
        TriggerClientEvent('shisha:notify', src, '~g~Konfiguration aktualisiert!', 'success')
        TriggerClientEvent('shisha:setConfig', -1, {
            JobRequired = Config.JobRequired,
            Job = Config.Job,
            JobGradeRequired = Config.JobGradeRequired,
            HUD = { enabled = Config.HUD.enabled },
            KeyBindings = Config.KeyBindings
        })
    
    elseif action == 'updateTablePrice' then
        local tableId = tonumber(data.tableId)
        local price = tonumber(data.price)
        if tableId and price and Config.Tables[tableId] then
            Config.Tables[tableId].price = price
            TriggerClientEvent('shisha:notify', src, '~g~Preis für Tisch ' .. tableId .. ' auf $' .. price .. ' gesetzt!', 'success')
        else
            TriggerClientEvent('shisha:notify', src, '~r~Ungültige Tisch-ID oder Preis', 'error')
        end
    elseif action == 'setAllTablePrices' then
        local price = tonumber(data.price)
        if price then
            for i, _ in ipairs(Config.Tables) do
                Config.Tables[i].price = price
            end
            TriggerClientEvent('shisha:notify', src, '~g~Alle Tischpreise auf $' .. price .. ' gesetzt!', 'success')
        else
            TriggerClientEvent('shisha:notify', src, '~r~Ungültiger Preis', 'error')
        end
    elseif action == 'updateDrinkPrice' then
        local drinkName = tostring(data.drinkName or '')
        local price = tonumber(data.price)
        if drinkName ~= '' and price and Config.Drinks[drinkName] then
            Config.Drinks[drinkName].price = price
            TriggerClientEvent('shisha:notify', src, '~g~Preis für ' .. drinkName .. ' auf $' .. price .. ' gesetzt!', 'success')
        else
            TriggerClientEvent('shisha:notify', src, '~r~Ungültiges Getränk oder Preis', 'error')
        end
    elseif action == 'updateTrayPrice' then
        local trayName = tostring(data.trayName or '')
        local price = tonumber(data.price)
        if trayName ~= '' and price and Config.Trays[trayName] then
            Config.Trays[trayName].price = price
            TriggerClientEvent('shisha:notify', src, '~g~Preis für ' .. trayName .. ' auf $' .. price .. ' gesetzt!', 'success')
        else
            TriggerClientEvent('shisha:notify', src, '~r~Ungültiges Tablett oder Preis', 'error')
        end
    elseif action == 'updateCoalPrice' then
        local price = tonumber(data.price)
        if price then
            Config.Coal.price = price
            TriggerClientEvent('shisha:notify', src, '~g~Kohlepreis auf $' .. price .. ' gesetzt!', 'success')
        else
            TriggerClientEvent('shisha:notify', src, '~r~Ungültiger Kohlepreis', 'error')
        end
    elseif action == 'getStats' then
        local stats = {
            activePlayers = 0,
            moneyToday = 0,
            totalMoney = 0,
            sessionToday = 0
        }
        
        for _, _ in pairs(PlayerSessions) do
            stats.activePlayers = stats.activePlayers + 1
            stats.sessionToday = stats.sessionToday + 1
        end
        
        TriggerClientEvent('shisha:bossStats', src, stats)
    elseif action == 'setServerTime' then
        local hour = tonumber(data.hour) or 12
        local minute = tonumber(data.minute) or 0
        if hour < 0 then hour = 0 elseif hour > 23 then hour = 23 end
        if minute < 0 then minute = 0 elseif minute > 59 then minute = 59 end

        TriggerClientEvent('shisha:setTime', -1, hour, minute)
        TriggerClientEvent('shisha:notify', src, string.format('Serverzeit gesetzt auf %02d:%02d', hour, minute), 'success')
    elseif action == 'updateKeyBindings' then
        Config.KeyBindings = Config.KeyBindings or {}
        if data.menu ~= nil then Config.KeyBindings.menu = tonumber(data.menu) or Config.KeyBindings.menu end
        if data.bossMenu ~= nil then Config.KeyBindings.bossMenu = tonumber(data.bossMenu) or Config.KeyBindings.bossMenu end
        if data.bossMenuModifier ~= nil then Config.KeyBindings.bossMenuModifier = tonumber(data.bossMenuModifier) or Config.KeyBindings.bossMenuModifier end
        if data.toggleHUD ~= nil then Config.KeyBindings.toggleHUD = tonumber(data.toggleHUD) or Config.KeyBindings.toggleHUD end
        if data.smoke ~= nil then Config.KeyBindings.smoke = tonumber(data.smoke) or Config.KeyBindings.smoke end
        Config.MenuKey = Config.KeyBindings.menu
        Config.BossMenuKey = Config.KeyBindings.bossMenu
        Config.BossMenuModifier = Config.KeyBindings.bossMenuModifier
        Config.ToggleHUDKey = Config.KeyBindings.toggleHUD
        Config.SmokeKey = Config.KeyBindings.smoke

        TriggerClientEvent('shisha:notify', src, '~g~Tastenbelegung aktualisiert!', 'success')
        TriggerClientEvent('shisha:setConfig', -1, {
            JobRequired = Config.JobRequired,
            Job = Config.Job,
            JobGradeRequired = Config.JobGradeRequired,
            HUD = { enabled = Config.HUD.enabled },
            KeyBindings = Config.KeyBindings
        })
    end
end)
