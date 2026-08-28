---@diagnostic disable: undefined-global

Config = {}

-- Keybinds (im Spiel änderbar über die Einstellungen)
Config.Keybinds = {
    order = {key = "G", label = "Shisha bestellen", description = "Bestelle eine Shisha"},
    cancel = {key = "X", label = "Shisha beenden", description = "Beende die Shisha-Sitzung"},
    drink = {key = "H", label = "Getränk trinken", description = "Trinke ein Getränk"},
    menu = {key = "M", label = "Shisha Menü", description = "Öffne das Shisha-Menü"},
    bossMenu = {key = "B", label = "Boss-Menü", description = "Öffne das Boss-Menü"},
    toggleHUD = {key = "Z", label = "Shisha HUD umschalten", description = "Schalte das Shisha-HUD ein/aus"},
    smoke = {key = "E", label = "Shisha rauchen", description = "Ziehe an der Shisha"}
}

-- Boss-Menü Konfiguration
Config.BossMenu = {
    enabled = true,
    bossGradeRequired = 4,  -- Mindestens Grade 4 für Boss-Funktionen
    options = {
        "Spielergehaltsystem",
        "Mitglieder verwalten",
        "Kasse einsehen",
        "Einstellungen"
    }
}

Config.Job = "bartender"
Config.JobRequired = true  -- Nur Bartender-Job kann Shisha nutzen
Config.JobGradeRequired = 0  -- Mindestens Job-Grad 0 (alle Grade erlaubt)
Config.UseMultipleJobs = false  -- Nur einzelner Job, keine Mehrfach-Jobs

-- Job-spezifische Funktionen
Config.JobFunctions = {
    -- XP-Multiplikator basierend auf Job-Grad
    xpMultiplier = {
        [0] = 1.0,  -- Grade 0: normale XP
        [1] = 1.2,  -- Grade 1: 20% mehr XP
        [2] = 1.4,  -- Grade 2: 40% mehr XP
        [3] = 1.6,  -- Grade 3: 60% mehr XP
        [4] = 1.8,  -- Grade 4: 80% mehr XP
        [5] = 2.0   -- Grade 5+: 100% mehr XP
    },

    -- Job-spezifische Rabatte
    discounts = {
        drinks = {
            [0] = 0,    -- Grade 0: kein Rabatt
            [1] = 5,    -- Grade 1: 5% Rabatt
            [2] = 10,   -- Grade 2: 10% Rabatt
            [3] = 15,   -- Grade 3: 15% Rabatt
            [4] = 20,   -- Grade 4: 20% Rabatt
            [5] = 25    -- Grade 5+: 25% Rabatt
        },
        tables = {
            [0] = 0,    -- Grade 0: kein Rabatt
            [1] = 10,   -- Grade 1: 10% Rabatt
            [2] = 20,   -- Grade 2: 20% Rabatt
            [3] = 30,   -- Grade 3: 30% Rabatt
            [4] = 40,   -- Grade 4: 40% Rabatt
            [5] = 50    -- Grade 5+: 50% Rabatt
        }
    },

    -- Job-Progression Belohnungen
    progressionRewards = {
        [5] = {type = "bonus", amount = 100, message = "Job-Bonus: $100 für deine harte Arbeit!"},
        [10] = {type = "bonus", amount = 250, message = "Job-Bonus: $250 für deine Erfahrung!"},
        [15] = {type = "bonus", amount = 500, message = "Job-Bonus: $500 für deine Expertise!"},
        [20] = {type = "bonus", amount = 1000, message = "Job-Bonus: $1000 für deine Meisterschaft!"}
    },

    -- Job-spezifische Items (nur für bestimmte Grade verfügbar)
    exclusiveItems = {
        [3] = {"VIP Tablett"},      -- Ab Grade 3
        [4] = {"VIP Tablett", "Aroma Tablett"},  -- Ab Grade 4
        [5] = {"VIP Tablett", "Aroma Tablett", "Long Island Iced Tea"}  -- Ab Grade 5
    }
}

Config.Tables = {
    {label = "Tisch 1", type = "normal", price = 250, coords = vector3(-428.9441, 24.5340, 46.2943), seats = {vector4(-428.5, 24.0, 46.2943, 51.3164), vector4(-429.3, 25.0, 46.2943, 231.3164)}},
    {label = "Tisch 2", type = "normal", price = 250, coords = vector3(-432.9746, 24.4173, 46.2952), seats = {vector4(-432.5, 23.9, 46.2952, 356.7802), vector4(-433.4, 24.9, 46.2952, 176.7802)}},
    {label = "Tisch 3", type = "normal", price = 250, coords = vector3(-430.7282, 38.9769, 46.3820), seats = {vector4(-430.3, 38.4, 46.3820, 66.8904), vector4(-431.2, 39.5, 46.3820, 246.8904)}},
    {label = "Tisch 4", type = "normal", price = 250, coords = vector3(-431.9087, 43.1415, 46.3823), seats = {vector4(-431.5, 42.6, 46.3823, 304.1481), vector4(-432.4, 43.7, 46.3823, 124.1481)}},
    {label = "Tisch 5", type = "normal", price = 250, coords = vector3(-418.1376, 34.3025, 46.2940), seats = {vector4(-417.7, 33.8, 46.2940, 287.7238), vector4(-418.6, 34.8, 46.2940, 107.7238)}},
    {label = "Tisch 6", type = "normal", price = 250, coords = vector3(-407.8784, 34.4360, 46.2940), seats = {vector4(-407.4, 33.9, 46.2940, 168.7679), vector4(-408.4, 34.9, 46.2940, 348.7679)}},
    {label = "Tisch 7", type = "normal", price = 250, coords = vector3(-418.8462, 26.2307, 46.2940), seats = {vector4(-418.4, 25.7, 46.2940, 261.1076), vector4(-419.3, 26.8, 46.2940, 81.1076)}},
    {label = "Tisch 8", type = "normal", price = 250, coords = vector3(-408.9950, 29.6752, 52.8665), seats = {vector4(-408.5, 29.1, 52.8665, 216.8647), vector4(-409.5, 30.2, 52.8665, 36.8647)}},
    {label = "Tisch 9", type = "normal", price = 250, coords = vector3(-411.1136, 25.0826, 52.8870), seats = {vector4(-410.7, 24.5, 52.8870, 96.0008), vector4(-411.6, 25.6, 52.8870, 276.0008)}},
    {label = "Tisch 10", type = "normal", price = 250, coords = vector3(-417.8315, 24.4529, 52.8755), seats = {vector4(-417.4, 23.9, 52.8755, 234.8602), vector4(-418.3, 25.0, 52.8755, 54.8602)}},
    {label = "Tisch 11", type = "normal", price = 250, coords = vector3(-437.4520, 26.9815, 52.8771), seats = {vector4(-437.0, 26.4, 52.8771, 79.1510), vector4(-438.0, 27.5, 52.8771, 259.1510)}},
    {label = "Tisch 12", type = "vip", price = 500, coords = vector3(-443.1327, 26.4419, 53.3554), seats = {vector4(-442.7, 25.9, 53.3554, 325.1949), vector4(-443.6, 27.0, 53.3554, 145.1949)}},
    {label = "Tisch 13", type = "vip", price = 500, coords = vector3(-449.6718, 26.6501, 52.8771), seats = {vector4(-449.2, 26.1, 52.8771, 9.4489), vector4(-450.2, 27.2, 52.8771, 189.4489)}},
    {label = "Tisch 14", type = "vip", price = 500, coords = vector3(-454.5701, 27.0629, 52.8771), seats = {vector4(-454.1, 26.5, 52.8771, 39.6708), vector4(-455.1, 27.6, 52.8771, 219.6708)}},
    {label = "Tisch 15", type = "vip", price = 500, coords = vector3(-459.5786, 28.6547, 52.8768), seats = {vector4(-459.1, 28.1, 52.8768, 71.3522), vector4(-460.2, 29.2, 52.8768, 251.3522)}},
    {label = "Tisch 16", type = "vip", price = 500, coords = vector3(-460.4026, 38.7639, 52.8771), seats = {vector4(-460.0, 38.2, 52.8771, 289.9674), vector4(-460.9, 39.3, 52.8771, 109.9674)}},
    {label = "Tisch 17", type = "vip", price = 500, coords = vector3(-454.6274, 37.5753, 53.0075), seats = {vector4(-454.2, 37.0, 53.0075, 322.7400), vector4(-455.1, 38.1, 53.0075, 142.7400)}},
    {label = "Tisch 18", type = "vip", price = 500, coords = vector3(-449.2474, 38.2976, 52.8771), seats = {vector4(-448.8, 37.7, 52.8771, 221.4361), vector4(-449.8, 38.8, 52.8771, 41.4361)}},
    {label = "Tisch 19", type = "vip", price = 500, coords = vector3(-443.3042, 38.1218, 52.8770), seats = {vector4(-442.9, 37.6, 52.8770, 254.5866), vector4(-443.8, 38.7, 52.8770, 74.5866)}},
    {label = "Tisch 20", type = "vip", price = 500, coords = vector3(-438.0356, 37.8936, 52.8759), seats = {vector4(-437.6, 37.3, 52.8759, 266.6771), vector4(-438.6, 38.4, 52.8759, 86.6771)}},
    {label = "Tisch 21", type = "vip", price = 500, coords = vector3(-431.8387, 37.2643, 52.8771), seats = {vector4(-431.4, 36.7, 52.8771, 100.2411), vector4(-432.4, 37.8, 52.8771, 280.2411)}}
}

Config.Drinks = {
    ["Cocktail"] = {price = 100}
}

Config.AlcoholMixes = {
    ["Long Island Iced Tea"] = {price = 180, description = "Starker Mix aus Rum, Wodka & Zitrone", effect = "DrunkBoost", xp = 20},
    ["Sex on the Beach"] = {price = 160, description = "Fruchtig-süßer Cocktail mit Schuss", effect = "DreamyVision", xp = 18},
    ["Whiskey Sour"] = {price = 140, description = "Klassischer Whiskey-Mix mit Zitrusnote", effect = "BitterGlow", xp = 15}
}

Config.Trays = {
    ["Standard Tablett"] = {price = 60, description = "Ein klassisches Tablett für Getränke und Zubehör", effect = "TrayCarry", xp = 5},
    ["VIP Tablett"] = {price = 110, description = "Elegantes Tablett für die VIP-Behandlung", effect = "TrayVIP", xp = 10},
    ["Aroma Tablett"] = {price = 85, description = "Tablett mit zusätzlicher Aromabehälterung", effect = "TrayAroma", xp = 7}
}

Config.Coal = {
    price = 50,
    name = "Shisha Kohle",
    description = "Kohle für die Shisha-Session",
    uses = 1
}

Config.Flavors = {
    ["Minze"] = {effect="RaceTurbo", xp=5},
    ["Traube"] = {effect="DrugsTrevorClownsFight", xp=10},
    ["Wassermelone"] = {effect="SmoothSlide", xp=8},
    ["Apfel"] = {effect="AppleSizzle", xp=9},
    ["Vanille"] = {effect="WarmGlow", xp=7},
    ["Kirsche"] = {effect="CherryBliss", xp=11},
    ["Zitrone"] = {effect="CitrusBuzz", xp=6},
    ["Kokos"] = {effect="TropicalFade", xp=12}
}

Config.KeyBindings = {
    menu = 244,           -- M-Taste zum Öffnen des Shisha-Menüs
    bossMenu = 244,       -- M-Taste zusammen mit Modifier zum Boss-Menü
    bossMenuModifier = 21,-- LINKER SHIFT für Boss + M
    toggleHUD = 20,       -- Z-Taste zum HUD umschalten
    smoke = 38            -- E-Taste zum Rauchen
}

Config.MenuKey = Config.KeyBindings.menu
Config.BossMenuKey = Config.KeyBindings.bossMenu
Config.BossMenuModifier = Config.KeyBindings.bossMenuModifier
Config.ToggleHUDKey = Config.KeyBindings.toggleHUD
Config.SmokeKey = Config.KeyBindings.smoke

Config.HUD = {
    enabled = true,  -- Aktiviert/deaktiviert das HUD komplett
    position = {x = 50, y = 50},  -- Position von links/unten
    colors = {
        background = "rgba(0,0,0,0.7)",
        text = "white",
        barBackground = "#333",
        xpBar = "lime"
    },
    visible = true  -- Standard-Sichtbarkeit
}

Config.SlashCommands = {
    shisha = {label = "Öffne das Shisha-Menü", icon = "fa-smoking"},
    hudon = {label = "Schalte das HUD an"},
    hudoff = {label = "Schalte das HUD aus"},
    help = {label = "Zeige verfügbare Befehle"},
    drinks = {label = "Zeige verfügbare Getränke"},
    mixes = {label = "Zeige verfügbare Alkohol-Mischungen"},
    trays = {label = "Zeige verfügbare Tabletts"},
    flavors = {label = "Zeige verfügbare Aromen"},
    coal = {label = "Zeige Kohle-Info"},
    boss = {label = "Öffne das Boss-Verwaltungsmenü"}
}
