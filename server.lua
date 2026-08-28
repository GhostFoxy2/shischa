---@diagnostic disable: undefined-global

local ESX = exports["es_extended"]:getSharedObject()

local MAX_XP_CAP = 50000 -- Sicherheitsbegrenzung für XP
local XP_PER_LEVEL = 100
local PlayerXP = {}
local PlayerSessions = {}
local PlayerCoal = {}
local RateLimits = {}
local RuntimeStats = {
    date = os.date('%Y-%m-%d'),
    moneyToday = 0,
    totalMoney = 0,
    sessionToday = 0
}

local function Notify(src, message, notificationType)
    TriggerClientEvent('shisha:notify', src, message, notificationType or 'inform')
end

local function IsFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function NormalizePrice(value)
    local price = tonumber(value)
    local maxPrice = (Config.Security and Config.Security.maxPrice) or 1000000
    if not IsFiniteNumber(price) or price < 0 or price > maxPrice then return nil end
    return math.floor(price)
end

local function RefreshDailyStats()
    local currentDate = os.date('%Y-%m-%d')
    if RuntimeStats.date ~= currentDate then
        RuntimeStats.date = currentDate
        RuntimeStats.moneyToday = 0
        RuntimeStats.sessionToday = 0
    end
end

local function CountEntries(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

-- Prüfe, ob ein Job serverseitig erlaubt ist.
local function IsJobAllowed(jobName, jobGrade)
    if not Config.JobRequired then return true end

    local grade = tonumber(jobGrade) or 0
    if Config.UseMultipleJobs then
        for _, job in ipairs(Config.AllowedJobs or {}) do
            if jobName == job[1] and grade >= (tonumber(job[2]) or 0) then
                return true
            end
        end
        return false
    end

    return jobName == Config.Job and grade >= (tonumber(Config.JobGradeRequired) or 0)
end

local function GetPlayerJob(xPlayer)
    if not xPlayer or not xPlayer.getJob then return nil end
    return xPlayer.getJob()
end

local function GetDiscountForPlayer(xPlayer, itemType)
    local job = GetPlayerJob(xPlayer)
    local discounts = Config.JobFunctions and Config.JobFunctions.discounts
    if not job or not discounts or not discounts[itemType] then return 0 end

    local grade = math.max(0, math.min(tonumber(job.grade) or 0, 5))
    local discount = tonumber(discounts[itemType][grade]) or 0
    return math.max(0, math.min(discount, 100))
end

local function GetEffectivePrice(xPlayer, basePrice, itemType)
    local price = NormalizePrice(basePrice)
    if not price then return nil end
    local discount = GetDiscountForPlayer(xPlayer, itemType)
    return math.floor(price * (1 - discount / 100))
end

local function IsItemAvailableForJob(xPlayer, itemName)
    local job = GetPlayerJob(xPlayer)
    if not job then return false end

    local requiredGrade
    for grade, items in pairs((Config.JobFunctions and Config.JobFunctions.exclusiveItems) or {}) do
        for _, configuredName in ipairs(items) do
            if configuredName == itemName then
                local numericGrade = tonumber(grade) or 0
                requiredGrade = requiredGrade and math.min(requiredGrade, numericGrade) or numericGrade
            end
        end
    end

    return not requiredGrade or (tonumber(job.grade) or 0) >= requiredGrade
end

local function IsPlayerNearTable(src, tableId)
    local tableConfig = Config.Tables[tonumber(tableId)]
    if not tableConfig then return false end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local maxDistance = (Config.Security and Config.Security.interactionDistance) or 4.0
    return #(GetEntityCoords(ped) - tableConfig.coords) <= maxDistance
end

local function IsPlayerNearAnyTable(src)
    for tableId in ipairs(Config.Tables) do
        if IsPlayerNearTable(src, tableId) then return true end
    end
    return false
end

local function CheckRateLimit(src, action, cooldownMs)
    local now = GetGameTimer()
    RateLimits[src] = RateLimits[src] or {}
    local allowedAt = RateLimits[src][action] or 0
    if now < allowedAt then return false end
    RateLimits[src][action] = now + cooldownMs
    return true
end

local function RecordRevenue(amount)
    RefreshDailyStats()
    RuntimeStats.moneyToday = RuntimeStats.moneyToday + amount
    RuntimeStats.totalMoney = RuntimeStats.totalMoney + amount
end

local function DepositSocietyMoney(amount)
    if amount <= 0 then return end
    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_shisha', function(account)
        if account then account.addMoney(amount) end
    end)
end

local function ChargePlayer(src, xPlayer, amount)
    local price = NormalizePrice(amount)
    if not price then
        Notify(src, '~r~Ungültiger Preis', 'error')
        return false
    end
    if xPlayer.getMoney() < price then
        Notify(src, '~r~Zu wenig Geld! Preis: $' .. price, 'error')
        return false
    end

    xPlayer.removeMoney(price)
    DepositSocietyMoney(price)
    RecordRevenue(price)
    return true, price
end

local function ValidateCustomer(src, requireSession)
    local xPlayer = ESX.GetPlayerFromId(src)
    local job = GetPlayerJob(xPlayer)
    if not xPlayer or not job then return nil end
    if not IsJobAllowed(job.name, job.grade) then
        Notify(src, '~r~Du hast nicht den erforderlichen Job', 'error')
        return nil
    end

    if requireSession then
        local session = PlayerSessions[src]
        if not session or not IsPlayerNearTable(src, session.tableId) then
            Notify(src, '~r~Du benötigst eine aktive Shisha-Session am Tisch', 'error')
            return nil
        end
    elseif not IsPlayerNearAnyTable(src) then
        Notify(src, '~r~Du musst dich an einem Shisha-Tisch befinden', 'error')
        return nil
    end

    local cooldown = (Config.Security and Config.Security.purchaseCooldownMs) or 500
    if not CheckRateLimit(src, 'purchase', cooldown) then
        Notify(src, '~y~Bitte warte einen Moment', 'inform')
        return nil
    end
    return xPlayer
end

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
    local numericAmount = tonumber(amount)
    if not xPlayer or not IsFiniteNumber(numericAmount) or numericAmount <= 0 then return end
    numericAmount = math.min(math.floor(numericAmount), 1000)

    -- Berechne Job-XP-Multiplikator
    local multiplier = 1.0
    if Config.JobFunctions and Config.JobFunctions.xpMultiplier then
        local jobGrade = math.max(0, math.min(tonumber(xPlayer.getJob().grade) or 0, 5))
        multiplier = Config.JobFunctions.xpMultiplier[jobGrade] or 1.0
    end

    local effectiveXP = math.floor(numericAmount * multiplier)
    local state = PlayerXP[src] or {total = 0, xp = 0, level = 1}
    local oldLevel = state.level
    state.total = math.min((state.total or 0) + effectiveXP, MAX_XP_CAP)
    state.level = math.floor(state.total / XP_PER_LEVEL) + 1
    state.xp = state.total % XP_PER_LEVEL
    PlayerXP[src] = state

    if state.level > oldLevel then
        for newLevel = oldLevel + 1, state.level do
            TriggerClientEvent('shisha:levelUp', src, newLevel)
            local reward = Config.JobFunctions and Config.JobFunctions.progressionRewards and Config.JobFunctions.progressionRewards[newLevel]
            if reward and reward.type == "bonus" then
                xPlayer.addMoney(reward.amount)
                Notify(src, "~g~" .. reward.message, 'success')
            end
        end
    end

    TriggerClientEvent('shisha:updateHUD', src, {xp = state.xp, level = state.level})
end

lib.callback.register('shisha:getMenuData', function(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    local job = GetPlayerJob(xPlayer)
    if not xPlayer or not job or not IsJobAllowed(job.name, job.grade) then
        Notify(src, '~r~Du hast nicht den erforderlichen Job', 'error')
        return nil
    end
    if not IsPlayerNearAnyTable(src) then
        Notify(src, '~r~Du musst dich an einem Shisha-Tisch befinden', 'error')
        return nil
    end

    local result = {
        drinks = {},
        trays = {},
        mixes = {},
        coal = Config.Coal,
        flavors = Config.Flavors,
        jobDiscounts = {
            drinks = GetDiscountForPlayer(xPlayer, 'drinks'),
            tables = GetDiscountForPlayer(xPlayer, 'tables')
        }
    }

    for name, data in pairs(Config.Drinks) do
        result.drinks[name] = {price = GetEffectivePrice(xPlayer, data.price, 'drinks'), originalPrice = data.price}
    end
    for name, data in pairs(Config.Trays) do
        if IsItemAvailableForJob(xPlayer, name) then
            result.trays[name] = {
                price = GetEffectivePrice(xPlayer, data.price, 'drinks'), originalPrice = data.price,
                description = data.description, effect = data.effect, xp = data.xp
            }
        end
    end
    for name, data in pairs(Config.AlcoholMixes) do
        if IsItemAvailableForJob(xPlayer, name) then
            result.mixes[name] = {
                price = GetEffectivePrice(xPlayer, data.price, 'drinks'), originalPrice = data.price,
                description = data.description, effect = data.effect, xp = data.xp
            }
        end
    end

    return result
end)

RegisterNetEvent('shisha:order', function(rawTableId)
    local src = source
    local tableId = tonumber(rawTableId)
    if not tableId or tableId % 1 ~= 0 then
        Notify(src, '~r~Ungültiger Tisch', 'error')
        return
    end

    local tableConfig = Config.Tables[tableId]
    local xPlayer = ESX.GetPlayerFromId(src)
    local job = GetPlayerJob(xPlayer)
    if not tableConfig or not xPlayer or not job then return end
    if not CheckRateLimit(src, 'order', 1000) then return end
    if not IsJobAllowed(job.name, job.grade) then
        Notify(src, '~r~Du hast nicht den erforderlichen Job', 'error')
        return
    end
    if not IsPlayerNearTable(src, tableId) then
        Notify(src, '~r~Du bist zu weit von diesem Tisch entfernt', 'error')
        return
    end
    if GetTableOccupancy()[tableId] then
        Notify(src, '~r~Dieser Tisch ist bereits belegt', 'error')
        return
    end
    if PlayerSessions[src] then
        Notify(src, '~r~Du bist bereits in einer Session', 'error')
        return
    end

    local price = GetEffectivePrice(xPlayer, tableConfig.price, 'tables')
    local paid, chargedPrice = ChargePlayer(src, xPlayer, price)
    if not paid then return end

    local hasCoal = (PlayerCoal[src] or 0) > 0
    if hasCoal then PlayerCoal[src] = PlayerCoal[src] - 1 end
    PlayerSessions[src] = {tableId = tableId, active = hasCoal, smokeCount = 0}
    RefreshDailyStats()
    RuntimeStats.sessionToday = RuntimeStats.sessionToday + 1
    UpdateTableOccupancy()
    TriggerClientEvent('shisha:startSession', src, tableId, hasCoal)
    Notify(src, '~g~' .. tableConfig.label .. ' für $' .. chargedPrice .. ' gebucht!', 'success')
    if not hasCoal then Notify(src, '~y~Kaufe Kohle, um mit dem Rauchen zu beginnen', 'inform') end
end)

RegisterNetEvent('shisha:buyDrink', function(drink)
    local src = source
    local data = type(drink) == 'string' and Config.Drinks[drink]
    if not data then Notify(src, '~r~Getränk nicht gefunden', 'error') return end
    local xPlayer = ValidateCustomer(src, false)
    if not xPlayer then return end
    if not ChargePlayer(src, xPlayer, GetEffectivePrice(xPlayer, data.price, 'drinks')) then return end
    TriggerClientEvent('shisha:drinkEffect', src, data.effect)
    Notify(src, '~g~' .. drink .. ' gekauft!', 'success')
end)

RegisterNetEvent('shisha:buyAlcoholMix', function(mix)
    local src = source
    local data = type(mix) == 'string' and Config.AlcoholMixes[mix]
    if not data then Notify(src, '~r~Alkohol-Mischung nicht gefunden', 'error') return end
    local xPlayer = ValidateCustomer(src, false)
    if not xPlayer or not IsItemAvailableForJob(xPlayer, mix) then
        if xPlayer then Notify(src, '~r~Dein Job-Grad reicht für diesen Artikel nicht aus', 'error') end
        return
    end
    if not ChargePlayer(src, xPlayer, GetEffectivePrice(xPlayer, data.price, 'drinks')) then return end
    TriggerClientEvent('shisha:drinkEffect', src, data.effect)
    AddPlayerXP(src, data.xp or 15)
    Notify(src, '~g~' .. mix .. ' gekauft!', 'success')
end)

RegisterNetEvent('shisha:buyTray', function(tray)
    local src = source
    local data = type(tray) == 'string' and Config.Trays[tray]
    if not data then Notify(src, '~r~Tablett nicht gefunden', 'error') return end
    local xPlayer = ValidateCustomer(src, false)
    if not xPlayer or not IsItemAvailableForJob(xPlayer, tray) then
        if xPlayer then Notify(src, '~r~Dein Job-Grad reicht für diesen Artikel nicht aus', 'error') end
        return
    end
    if not ChargePlayer(src, xPlayer, GetEffectivePrice(xPlayer, data.price, 'drinks')) then return end
    TriggerClientEvent('shisha:trayEffect', src, data.effect)
    AddPlayerXP(src, data.xp or 5)
    Notify(src, '~g~' .. tray .. ' gekauft!', 'success')
end)

RegisterNetEvent('shisha:buyCoal', function()
    local src = source
    local xPlayer = ValidateCustomer(src, false)
    if not xPlayer or not Config.Coal then return end
    if not ChargePlayer(src, xPlayer, Config.Coal.price) then return end

    local session = PlayerSessions[src]
    if session and not session.active and IsPlayerNearTable(src, session.tableId) then
        session.active = true
        session.smokeCount = 0
        TriggerClientEvent('shisha:coalReady', src)
    else
        PlayerCoal[src] = (PlayerCoal[src] or 0) + (tonumber(Config.Coal.uses) or 1)
        TriggerClientEvent('shisha:addCoal', src)
    end
    Notify(src, '~g~' .. Config.Coal.name .. ' gekauft!', 'success')
end)

RegisterNetEvent('shisha:buyFlavor', function(flavor)
    local src = source
    local data = type(flavor) == 'string' and Config.Flavors[flavor]
    if not data then Notify(src, '~r~Aroma nicht gefunden', 'error') return end
    if not ValidateCustomer(src, true) then return end
    local session = PlayerSessions[src]
    if session.flavor then
        Notify(src, '~y~Für diese Session wurde bereits ein Aroma gewählt', 'inform')
        return
    end
    session.flavor = flavor
    TriggerClientEvent('shisha:flavorEffect', src, data.effect)
    AddPlayerXP(src, data.xp or 0)
    Notify(src, '~g~' .. flavor .. ' Aroma aktiviert!', 'success')
end)

RegisterNetEvent('shisha:smoke', function()
    local src = source
    local session = PlayerSessions[src]
    if not session or not session.active then
        Notify(src, '~r~Du benötigst eine aktive Session mit Kohle', 'error')
        return
    end
    if not IsPlayerNearTable(src, session.tableId) then
        Notify(src, '~r~Du bist zu weit von deinem Tisch entfernt', 'error')
        return
    end

    local cooldown = (Config.Security and Config.Security.smokeCooldownMs) or 3000
    if not CheckRateLimit(src, 'smoke', cooldown) then
        Notify(src, '~y~Warte kurz bis zum nächsten Zug', 'inform')
        return
    end

    local maxSmokes = (Config.Security and Config.Security.maxSmokesPerSession) or 5
    session.smokeCount = (session.smokeCount or 0) + 1
    AddPlayerXP(src, (Config.Security and Config.Security.smokeXP) or 10)
    TriggerClientEvent('shisha:performSmoke', src, session.smokeCount, maxSmokes)

    if session.smokeCount >= maxSmokes then
        PlayerSessions[src] = nil
        UpdateTableOccupancy()
        TriggerClientEvent('shisha:sessionCompleted', src)
    end
end)

local function EndPlayerSession(src, message)
    if not PlayerSessions[src] then return false end
    PlayerSessions[src] = nil
    UpdateTableOccupancy()
    TriggerClientEvent('shisha:sessionEnded', src)
    Notify(src, message, 'inform')
    return true
end

RegisterNetEvent('shisha:endSession', function()
    EndPlayerSession(source, '~y~Session beendet')
end)

RegisterNetEvent('shisha:cancelSession', function()
    if not EndPlayerSession(source, '~y~Shisha-Sitzung abgebrochen') then
        Notify(source, '~y~Du hast keine aktive Shisha-Sitzung.', 'inform')
    end
end)

RegisterNetEvent('shisha:requestTableOccupancy', function()
    local src = source
    TriggerClientEvent('shisha:updateTableOccupancy', src, GetTableOccupancy())
    local state = PlayerXP[src] or {xp = 0, level = 1}
    TriggerClientEvent('shisha:updateHUD', src, {xp = state.xp or 0, level = state.level or 1})
end)

AddEventHandler('playerDropped', function()
    local src = source
    local hadSession = PlayerSessions[src] ~= nil
    PlayerSessions[src] = nil
    PlayerXP[src] = nil
    PlayerCoal[src] = nil
    RateLimits[src] = nil
    if hadSession then UpdateTableOccupancy() end
end)

-- Admin Command um alle Sessions zu sehen
TriggerEvent('chat:addSuggestion', '/shisha_sessions', 'Zeige alle aktiven Shisha-Sessions (Admin Command)')

RegisterCommand('shisha_sessions', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= 'admin' then
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
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    local tableId = tonumber(args[1])
    local price = NormalizePrice(args[2])

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
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    local drinkName = args[1]
    local price = NormalizePrice(args[2])

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
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= 'admin' then
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
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA CONFIG', '═════════════════════'}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', 'Job erforderlich: ' .. tostring(Config.JobRequired)}})
    if Config.JobRequired then
        TriggerClientEvent('chat:addMessage', source, {args = {'', 'Job: ' .. Config.Job .. ' | Grade: ' .. Config.JobGradeRequired .. '+'}})
    end
    TriggerClientEvent('chat:addMessage', source, {args = {'', 'Tische: ' .. #Config.Tables}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', 'Getränke: ' .. CountEntries(Config.Drinks)}})
    TriggerClientEvent('chat:addMessage', source, {args = {'', 'Aromen: ' .. CountEntries(Config.Flavors)}})
    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA CONFIG', '═════════════════════'}})
end, false)

-- Admin Command zum Anzeigen aller Tische
TriggerEvent('chat:addSuggestion', '/shisha_tables', 'Zeige alle Tische mit Preisen')

RegisterCommand('shisha_tables', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= 'admin' then
        TriggerClientEvent('chat:addMessage', source, {args = {'~r~ADMIN', 'Du hast keine Berechtigung!'}})
        return
    end

    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA TISCHE', '═════════════════════'}})
    for i, tableConfig in ipairs(Config.Tables) do
        TriggerClientEvent('chat:addMessage', source, {args = {'', 'ID: ' .. i .. ' | ' .. tableConfig.label .. ' | Preis: $' .. tableConfig.price}})
    end
    TriggerClientEvent('chat:addMessage', source, {args = {'~b~SHISHA TISCHE', '═════════════════════'}})
end, false)

-- Admin Command zum Anzeigen aller Getränke
TriggerEvent('chat:addSuggestion', '/shisha_drinks', 'Zeige alle Getränke mit Preisen')

RegisterCommand('shisha_drinks', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= 'admin' then
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
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= 'admin' then
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
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= 'admin' then
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

    payload = type(payload) == 'table' and payload or {}

    if action == 'toggleHudEnabled' then
        Config.HUD.enabled = not Config.HUD.enabled
        Notify(src, '~g~HUD ' .. (Config.HUD.enabled and 'aktiviert' or 'deaktiviert'), 'success')
    elseif action == 'toggleJobRequired' then
        Config.JobRequired = not Config.JobRequired
        Notify(src, '~g~Job-Anforderung ' .. (Config.JobRequired and 'aktiviert' or 'deaktiviert'), 'success')
    elseif action == 'setJob' and payload.jobName then
        local jobName = tostring(payload.jobName)
        if jobName:match('^[%w_%-]+$') and #jobName <= 32 then
            Config.Job = jobName
            Notify(src, '~g~Job geändert auf: ' .. Config.Job, 'success')
        else
            Notify(src, '~r~Ungültiger Job-Name', 'error')
        end
    elseif action == 'setJobGrade' and payload.grade ~= nil then
        local grade = tonumber(payload.grade)
        if IsFiniteNumber(grade) and grade >= 0 and grade <= 100 then
            Config.JobGradeRequired = math.floor(grade)
            Notify(src, '~g~Job-Grad geändert auf: ' .. Config.JobGradeRequired, 'success')
        else
            Notify(src, '~r~Ungültiger Job-Grad', 'error')
        end
    elseif action == 'setTablePrice' then
        local tableId = tonumber(payload.tableId)
        local price = NormalizePrice(payload.price)
        if tableId and tableId % 1 == 0 and price and Config.Tables[tableId] then
            Config.Tables[tableId].price = price
            Notify(src, '~g~Preis für Tisch ' .. tableId .. ' aktualisiert', 'success')
        else
            Notify(src, '~r~Ungültiger Tisch oder Preis', 'error')
        end
    elseif action == 'setDrinkPrice' then
        local drinkName = type(payload.drinkName) == 'string' and payload.drinkName
        local price = NormalizePrice(payload.price)
        if drinkName and price and Config.Drinks[drinkName] then
            Config.Drinks[drinkName].price = price
            Notify(src, '~g~Preis für ' .. drinkName .. ' aktualisiert', 'success')
        else
            Notify(src, '~r~Ungültiges Getränk oder Preis', 'error')
        end
    else
        Notify(src, '~r~Unbekannte Admin-Aktion', 'error')
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
        Notify(src, 'Du hast keine Berechtigung!', 'error')
        return
    end

    data = type(data) == 'table' and data or {}

    local adminOnly = action == 'updateConfig' or action == 'setServerTime' or action == 'updateKeyBindings'
    if adminOnly and not isAdmin then
        Notify(src, 'Nur Admins dürfen diese globale Einstellung ändern!', 'error')
        return
    end

    if action == 'updateConfig' then
        if type(data.jobRequired) == 'boolean' then Config.JobRequired = data.jobRequired end
        if data.jobName then
            local jobName = tostring(data.jobName)
            if not jobName:match('^[%w_%-]+$') or #jobName > 32 then
                Notify(src, '~r~Ungültiger Job-Name', 'error')
                return
            end
            Config.Job = jobName
        end
        if data.jobGrade ~= nil then
            local grade = tonumber(data.jobGrade)
            if not IsFiniteNumber(grade) or grade < 0 or grade > 100 then
                Notify(src, '~r~Ungültiger Job-Grad', 'error')
                return
            end
            Config.JobGradeRequired = math.floor(grade)
        end
        
        Notify(src, '~g~Konfiguration aktualisiert!', 'success')
        TriggerClientEvent('shisha:setConfig', -1, {
            JobRequired = Config.JobRequired,
            Job = Config.Job,
            JobGradeRequired = Config.JobGradeRequired,
            HUD = { enabled = Config.HUD.enabled }
        })
    
    elseif action == 'updateTablePrice' then
        local tableId = tonumber(data.tableId)
        local price = NormalizePrice(data.price)
        if tableId and tableId % 1 == 0 and price and Config.Tables[tableId] then
            Config.Tables[tableId].price = price
            Notify(src, '~g~Preis für Tisch ' .. tableId .. ' auf $' .. price .. ' gesetzt!', 'success')
        else
            Notify(src, '~r~Ungültige Tisch-ID oder Preis', 'error')
        end
    elseif action == 'setAllTablePrices' then
        local price = NormalizePrice(data.price)
        if price then
            for i, _ in ipairs(Config.Tables) do
                Config.Tables[i].price = price
            end
            Notify(src, '~g~Alle Tischpreise auf $' .. price .. ' gesetzt!', 'success')
        else
            Notify(src, '~r~Ungültiger Preis', 'error')
        end
    elseif action == 'updateDrinkPrice' then
        local drinkName = tostring(data.drinkName or '')
        local price = NormalizePrice(data.price)
        if drinkName ~= '' and price and Config.Drinks[drinkName] then
            Config.Drinks[drinkName].price = price
            Notify(src, '~g~Preis für ' .. drinkName .. ' auf $' .. price .. ' gesetzt!', 'success')
        else
            Notify(src, '~r~Ungültiges Getränk oder Preis', 'error')
        end
    elseif action == 'updateTrayPrice' then
        local trayName = tostring(data.trayName or '')
        local price = NormalizePrice(data.price)
        if trayName ~= '' and price and Config.Trays[trayName] then
            Config.Trays[trayName].price = price
            Notify(src, '~g~Preis für ' .. trayName .. ' auf $' .. price .. ' gesetzt!', 'success')
        else
            Notify(src, '~r~Ungültiges Tablett oder Preis', 'error')
        end
    elseif action == 'updateCoalPrice' then
        local price = NormalizePrice(data.price)
        if price then
            Config.Coal.price = price
            Notify(src, '~g~Kohlepreis auf $' .. price .. ' gesetzt!', 'success')
        else
            Notify(src, '~r~Ungültiger Kohlepreis', 'error')
        end
    elseif action == 'getStats' then
        RefreshDailyStats()
        local stats = {
            activePlayers = 0,
            moneyToday = RuntimeStats.moneyToday,
            totalMoney = RuntimeStats.totalMoney,
            sessionToday = RuntimeStats.sessionToday
        }
        
        for _, _ in pairs(PlayerSessions) do
            stats.activePlayers = stats.activePlayers + 1
        end
        
        TriggerClientEvent('shisha:bossStats', src, stats)
    elseif action == 'setServerTime' then
        local hour = tonumber(data.hour) or 12
        local minute = tonumber(data.minute) or 0
        if hour < 0 then hour = 0 elseif hour > 23 then hour = 23 end
        if minute < 0 then minute = 0 elseif minute > 59 then minute = 59 end

        TriggerClientEvent('shisha:setTime', -1, hour, minute)
        Notify(src, string.format('Serverzeit gesetzt auf %02d:%02d', hour, minute), 'success')
    elseif action == 'updateKeyBindings' then
        Notify(src, '~y~Tasten werden von jedem Spieler in den FiveM-Einstellungen geändert', 'inform')
    else
        Notify(src, '~r~Unbekannte Boss-Aktion', 'error')
    end
end)
