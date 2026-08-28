window.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && document.getElementById('menu').style.display === 'block') {
        closeMenu();
    }
});

window.addEventListener('message', function(e){
    if(e.data.action==="updateHUD"){
        document.getElementById("level").innerText=e.data.level
        document.getElementById("xpbar").style.width=e.data.xp+"%"
    } else if(e.data.action==="setHUDConfig"){
        const config = e.data.config;
        document.documentElement.style.setProperty('--hud-x', config.position.x + 'px');
        document.documentElement.style.setProperty('--hud-y', config.position.y + 'px');
        document.documentElement.style.setProperty('--text-color', config.colors.text);
        document.documentElement.style.setProperty('--background-color', config.colors.background);
        document.documentElement.style.setProperty('--bar-bg', config.colors.barBackground);
        document.documentElement.style.setProperty('--xp-color', config.colors.xpBar);
        document.documentElement.style.setProperty('--hud-visible', config.visible ? 'block' : 'none');
    } else if(e.data.action==="openMenu"){
        const drinks = e.data.drinks;
        const trays = e.data.trays || {};
        const coal = e.data.coal || {};
        const mixes = e.data.mixes || {};
        const flavors = e.data.flavors;
        const jobDiscounts = e.data.jobDiscounts || {};
        showMenu(drinks, trays, coal, mixes, flavors, jobDiscounts);
    } else if(e.data.action==="openAdminMenu"){
        const config = e.data.config;
        showAdminMenu(config);
    } else if(e.data.action==="toggleHUD"){
        document.documentElement.style.setProperty('--hud-visible', e.data.visible ? 'block' : 'none');
    }
})

function showMenu(drinks, trays, coal, mixes, flavors, jobDiscounts) {
    const menu = document.getElementById('menu');
    const drinksDiv = document.getElementById('drinks');
    const traysDiv = document.getElementById('trays');
    const coalDiv = document.getElementById('coal');
    const mixesDiv = document.getElementById('mixes');
    const flavorsDiv = document.getElementById('flavors');

    drinksDiv.innerHTML = '<h3>Getränke</h3>';
    for (const [name, data] of Object.entries(drinks)) {
        const btn = document.createElement('button');
        let priceText = `$${data.price}`;
        if (data.originalPrice && data.price < data.originalPrice && jobDiscounts && jobDiscounts.drinks > 0) {
            const discountPercent = Math.round(jobDiscounts.drinks);
            priceText = `<span style="text-decoration: line-through; color: #888;">$${data.originalPrice}</span> $${data.price} (${discountPercent}% Rabatt)`;
        }
        btn.innerHTML = `${name} - ${priceText}`;
        btn.className = 'menu-btn';
        btn.onclick = () => {
            if (window.fetch) {
                fetch(`https://shisha_final/buyDrink`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ drink: name })
                }).catch(e => console.error('Fehler beim Kaufen:', e));
                closeMenu();
            }
        };
        drinksDiv.appendChild(btn);
    }

    traysDiv.innerHTML = '<h3>Tabletts</h3>';
    for (const [name, data] of Object.entries(trays)) {
        const btn = document.createElement('button');
        let priceText = `$${data.price}`;
        if (data.originalPrice && data.price < data.originalPrice && jobDiscounts && jobDiscounts.drinks > 0) {
            const discountPercent = Math.round(jobDiscounts.drinks);
            priceText = `<span style="text-decoration: line-through; color: #888;">$${data.originalPrice}</span> $${data.price} (${discountPercent}% Rabatt)`;
        }
        btn.innerHTML = `${name} - ${priceText}`;
        btn.className = 'menu-btn tray-btn';
        btn.onclick = () => {
            if (window.fetch) {
                fetch(`https://shisha_final/buyTray`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ tray: name })
                }).catch(e => console.error('Fehler beim Kaufen:', e));
                closeMenu();
            }
        };
        traysDiv.appendChild(btn);
        const desc = document.createElement('p');
        desc.textContent = data.description;
        desc.className = 'menu-description';
        traysDiv.appendChild(desc);
    }

    coalDiv.innerHTML = '<h3>Shisha-Kohle</h3>';
    if (coal && coal.name) {
        const btn = document.createElement('button');
        btn.textContent = `${coal.name} - $${coal.price}`;
        btn.className = 'menu-btn coal-btn';
        btn.onclick = () => {
            if (window.fetch) {
                fetch(`https://shisha_final/buyCoal`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' }
                }).catch(e => console.error('Fehler beim Kaufen:', e));
                closeMenu();
            }
        };
        coalDiv.appendChild(btn);
        const desc = document.createElement('p');
        desc.textContent = coal.description;
        desc.className = 'menu-description';
        coalDiv.appendChild(desc);
    } else {
        coalDiv.innerHTML += '<p>Keine Kohle verfügbar.</p>';
    }

    mixesDiv.innerHTML = '<h3>Alkohol-Mischungen</h3>';
    for (const [name, data] of Object.entries(mixes)) {
        const btn = document.createElement('button');
        let priceText = `$${data.price}`;
        if (data.originalPrice && data.price < data.originalPrice && jobDiscounts && jobDiscounts.drinks > 0) {
            const discountPercent = Math.round(jobDiscounts.drinks);
            priceText = `<span style="text-decoration: line-through; color: #888;">$${data.originalPrice}</span> $${data.price} (${discountPercent}% Rabatt)`;
        }
        btn.innerHTML = `${name} - ${priceText}`;
        btn.className = 'menu-btn mix-btn';
        btn.onclick = () => {
            if (window.fetch) {
                fetch(`https://shisha_final/buyMix`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ mix: name })
                }).catch(e => console.error('Fehler beim Kaufen:', e));
                closeMenu();
            }
        };
        mixesDiv.appendChild(btn);
    }

    flavorsDiv.innerHTML = '<h3>Aromen</h3>';
    for (const [name, data] of Object.entries(flavors)) {
        const btn = document.createElement('button');
        btn.textContent = `${name} - XP: ${data.xp}`;
        btn.className = 'menu-btn';
        btn.onclick = () => {
            if (window.fetch) {
                fetch(`https://shisha_final/buyFlavor`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ flavor: name })
                }).catch(e => console.error('Fehler beim Kaufen:', e));
                closeMenu();
            }
        };
        flavorsDiv.appendChild(btn);
    }

    menu.style.display = 'block';
}

function closeMenu() {
    document.getElementById('menu').style.display = 'none';
    document.getElementById('adminMenu').style.display = 'none';
    document.getElementById('bossMenu').style.display = 'none';
    if (window.fetch) {
        fetch(`https://shisha_final/closeMenu`, { method: 'POST' }).catch(e => console.error('Fehler beim Schließen:', e));
    }
}

function showAdminMenu(config) {
    const admin = document.getElementById('adminMenu');
    const content = document.getElementById('adminContent');
    content.innerHTML = '';

    const hudToggleBtn = document.createElement('button');
    hudToggleBtn.textContent = config.HUD.enabled ? 'HUD deaktivieren' : 'HUD aktivieren';
    hudToggleBtn.className = 'menu-btn';
    hudToggleBtn.onclick = () => sendAdminAction('toggleHudEnabled');
    content.appendChild(hudToggleBtn);

    const jobToggleBtn = document.createElement('button');
    jobToggleBtn.textContent = config.JobRequired ? 'Job-Anforderung deaktivieren' : 'Job-Anforderung aktivieren';
    jobToggleBtn.className = 'menu-btn';
    jobToggleBtn.onclick = () => sendAdminAction('toggleJobRequired');
    content.appendChild(jobToggleBtn);

    const jobNameBtn = document.createElement('button');
    jobNameBtn.textContent = 'Job ändern (' + config.Job + ')';
    jobNameBtn.className = 'menu-btn';
    jobNameBtn.onclick = () => {
        const jobName = prompt('Neuer Job-Name:', config.Job);
        if (jobName) sendAdminAction('setJob', { jobName });
    };
    content.appendChild(jobNameBtn);

    const jobGradeBtn = document.createElement('button');
    jobGradeBtn.textContent = 'Job-Grad ändern (' + config.JobGradeRequired + ')';
    jobGradeBtn.className = 'menu-btn';
    jobGradeBtn.onclick = () => {
        const grade = prompt('Neuer Job-Grad:', config.JobGradeRequired);
        if (grade !== null) sendAdminAction('setJobGrade', { grade: parseInt(grade, 10) || 0 });
    };
    content.appendChild(jobGradeBtn);

    const tableHeader = document.createElement('h3');
    tableHeader.textContent = 'Tisch-Preise';
    content.appendChild(tableHeader);
    Object.entries(config.Tables).forEach(([id, table]) => {
        const btn = document.createElement('button');
        btn.textContent = table.label + ' ($' + table.price + ')';
        btn.className = 'menu-btn';
        btn.onclick = () => {
            const price = prompt('Neuer Preis für ' + table.label + ':', table.price);
            if (price !== null) sendAdminAction('setTablePrice', { tableId: parseInt(id, 10), price: parseInt(price, 10) || table.price });
        };
        content.appendChild(btn);
    });

    const drinkHeader = document.createElement('h3');
    drinkHeader.textContent = 'Getränke';
    content.appendChild(drinkHeader);
    Object.entries(config.Drinks).forEach(([name, data]) => {
        const btn = document.createElement('button');
        btn.textContent = name + ' ($' + data.price + ')';
        btn.className = 'menu-btn';
        btn.onclick = () => {
            const price = prompt('Neuer Preis für ' + name + ':', data.price);
            if (price !== null) sendAdminAction('setDrinkPrice', { drinkName: name, price: parseInt(price, 10) || data.price });
        };
        content.appendChild(btn);
    });

    admin.style.display = 'block';
}

function sendAdminAction(action, payload = {}) {
    if (window.fetch) {
        fetch(`https://shisha_final/adminAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action, payload })
        }).catch(e => console.error('Fehler beim Admin-Action:', e));
    }
}

if (document.getElementById('closeMenu')) {
    document.getElementById('closeMenu').onclick = closeMenu;
}
if (document.getElementById('closeAdminMenu')) {
    document.getElementById('closeAdminMenu').onclick = closeMenu;
}
if (document.getElementById('closeBossMenu')) {
    document.getElementById('closeBossMenu').onclick = closeBossMenu;
}

function safeId(name) {
    return name.toString().replace(/[^a-zA-Z0-9_-]/g, '_');
}

function showBossMenu(config) {
    const boss = document.getElementById('bossMenu');
    if (boss) {
        document.getElementById('jobRequired').checked = config.JobRequired || false;
        document.getElementById('jobName').value = config.Job || 'bartender';
        document.getElementById('jobGrade').value = config.JobGradeRequired || 0;
        document.getElementById('serverHour').value = typeof config.currentHour === 'number' ? config.currentHour : 12;
        document.getElementById('serverMinute').value = typeof config.currentMinute === 'number' ? config.currentMinute : 0;
        document.getElementById('allTablePrice').value = config.Tables && config.Tables[1] ? config.Tables[1].price : 250;
        document.getElementById('coalPrice').value = config.Coal && config.Coal.price ? config.Coal.price : 50;

        const tablePriceList = document.getElementById('tablePriceList');
        const drinkPriceList = document.getElementById('drinkPriceList');
        const trayPriceList = document.getElementById('trayPriceList');

        tablePriceList.innerHTML = '';
        if (config.Tables) {
            config.Tables.forEach((table, index) => {
                const row = document.createElement('div');
                row.className = 'price-row';
                row.innerHTML = `<span>${table.label}</span> <input type="number" id="tablePrice_${index + 1}" value="${table.price}" min="0"> <button onclick="updateTablePrice(${index + 1})">Speichern</button>`;
                tablePriceList.appendChild(row);
            });
        }

        drinkPriceList.innerHTML = '';
        if (config.Drinks) {
            Object.entries(config.Drinks).forEach(([name, data]) => {
                const id = safeId(name);
                const row = document.createElement('div');
                row.className = 'price-row';
                row.innerHTML = `<span>${name}</span> <input type="number" id="drinkPrice_${id}" value="${data.price}" min="0"> <button onclick="updateDrinkPrice('${id}', '${name}')">Speichern</button>`;
                drinkPriceList.appendChild(row);
            });
        }

        trayPriceList.innerHTML = '';
        if (config.Trays) {
            Object.entries(config.Trays).forEach(([name, data]) => {
                const id = safeId(name);
                const row = document.createElement('div');
                row.className = 'price-row';
                row.innerHTML = `<span>${name}</span> <input type="number" id="trayPrice_${id}" value="${data.price}" min="0"> <button onclick="updateTrayPrice('${id}', '${name}')">Speichern</button>`;
                trayPriceList.appendChild(row);
            });
        }

        document.getElementById('keyMenu').value = config.KeyBindings ? config.KeyBindings.menu : 244;
        document.getElementById('keyBossMenu').value = config.KeyBindings ? config.KeyBindings.bossMenu : 244;
        document.getElementById('keyBossModifier').value = config.KeyBindings ? config.KeyBindings.bossMenuModifier : 21;
        document.getElementById('keyToggleHUD').value = config.KeyBindings ? config.KeyBindings.toggleHUD : 20;
        document.getElementById('keySmoke').value = config.KeyBindings ? config.KeyBindings.smoke : 38;
        boss.style.display = 'block';
        loadStats();
    }
}

function updateBossKeyBindings() {
    const keyMenu = parseInt(document.getElementById('keyMenu').value, 10) || 244;
    const keyBossMenu = parseInt(document.getElementById('keyBossMenu').value, 10) || 244;
    const keyBossModifier = parseInt(document.getElementById('keyBossModifier').value, 10) || 21;
    const keyToggleHUD = parseInt(document.getElementById('keyToggleHUD').value, 10) || 20;
    const keySmoke = parseInt(document.getElementById('keySmoke').value, 10) || 38;

    if (window.fetch) {
        fetch(`https://shisha_final/bossAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'updateKeyBindings', menu: keyMenu, bossMenu: keyBossMenu, bossMenuModifier: keyBossModifier, toggleHUD: keyToggleHUD, smoke: keySmoke })
        }).catch(e => console.error('Fehler bei Tastatur-Update:', e));
    }
}

function closeBossMenu() {
    closeMenu();
}

function updateBossConfig() {
    const jobRequired = document.getElementById('jobRequired').checked;
    const jobName = document.getElementById('jobName').value;
    const jobGrade = parseInt(document.getElementById('jobGrade').value) || 0;
    
    if (window.fetch) {
        fetch(`https://shisha_final/bossAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'updateConfig', jobRequired, jobName, jobGrade })
        }).catch(e => console.error('Fehler bei Config-Update:', e));
    }
}

function updateServerTime() {
    const hour = parseInt(document.getElementById('serverHour').value, 10);
    const minute = parseInt(document.getElementById('serverMinute').value, 10);

    if (isNaN(hour) || isNaN(minute)) {
        console.error('Ungültige Zeitangabe');
        return;
    }

    if (window.fetch) {
        fetch(`https://shisha_final/bossAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'setServerTime', hour, minute })
        }).catch(e => console.error('Fehler beim Setzen der Serverzeit:', e));
    }
}

function updateTablePrice(tableId) {
    const input = document.getElementById(`tablePrice_${tableId}`);
    const price = parseInt(input.value, 10);
    if (isNaN(price)) {
        console.error('Ungültiger Tischpreis');
        return;
    }
    if (window.fetch) {
        fetch(`https://shisha_final/bossAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'updateTablePrice', tableId, price })
        }).catch(e => console.error('Fehler beim Aktualisieren des Tischpreises:', e));
    }
}

function setAllTablePrices() {
    const price = parseInt(document.getElementById('allTablePrice').value, 10);
    if (isNaN(price)) {
        console.error('Ungültiger Preis für alle Tische');
        return;
    }
    if (window.fetch) {
        fetch(`https://shisha_final/bossAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'setAllTablePrices', price })
        }).catch(e => console.error('Fehler beim Aktualisieren aller Tischpreise:', e));
    }
}

function updateDrinkPrice(drinkId, drinkName) {
    const input = document.getElementById(`drinkPrice_${drinkId}`);
    const price = parseInt(input.value, 10);
    if (isNaN(price)) {
        console.error('Ungültiger Getränkepreis');
        return;
    }
    if (window.fetch) {
        fetch(`https://shisha_final/bossAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'updateDrinkPrice', drinkName, price })
        }).catch(e => console.error('Fehler beim Aktualisieren des Getränkepreises:', e));
    }
}

function updateTrayPrice(trayId, trayName) {
    const input = document.getElementById(`trayPrice_${trayId}`);
    const price = parseInt(input.value, 10);
    if (isNaN(price)) {
        console.error('Ungültiger Tablettpreis');
        return;
    }
    if (window.fetch) {
        fetch(`https://shisha_final/bossAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'updateTrayPrice', trayName, price })
        }).catch(e => console.error('Fehler beim Aktualisieren des Tablettpreises:', e));
    }
}

function updateCoalPrice() {
    const price = parseInt(document.getElementById('coalPrice').value, 10);
    if (isNaN(price)) {
        console.error('Ungültiger Kohlepreis');
        return;
    }
    if (window.fetch) {
        fetch(`https://shisha_final/bossAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'updateCoalPrice', price })
        }).catch(e => console.error('Fehler beim Aktualisieren des Kohlepreises:', e));
    }
}

function loadStats() {
    const statsDiv = document.getElementById('statsContent');
    statsDiv.innerHTML = '<p>Statistiken werden geladen...</p>';
    if (window.fetch) {
        fetch(`https://shisha_final/bossAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'getStats' })
        }).catch(e => {
            statsDiv.innerHTML = '<p>Fehler beim Laden der Statistiken</p>';
            console.error('Fehler:', e);
        });
    }
}

window.addEventListener('message', function(e){
    if (e.data.action === 'openBossMenu') {
        showBossMenu(e.data.config);
    } else if (e.data.action === 'bossStats') {
        const statsDiv = document.getElementById('statsContent');
        const stats = e.data.stats || {};
        statsDiv.innerHTML = `
            <p>Aktive Spieler: ${stats.activePlayers || 0}</p>
            <p>Heute verdient: $${stats.moneyToday || 0}</p>
            <p>Gesamt verdient: $${stats.totalMoney || 0}</p>
            <p>Sessions heute: ${stats.sessionToday || 0}</p>
        `;
    }
});
