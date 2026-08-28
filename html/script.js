const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'shisha_final';
const nuiUrl = endpoint => `https://${resourceName}/${endpoint}`;

window.addEventListener('keydown', function(e) {
    const menuOpen = ['menu', 'adminMenu', 'bossMenu'].some(id => document.getElementById(id).style.display === 'block');
    if (e.key === 'Escape' && menuOpen) {
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

function setProductButtonLabel(button, name, data, discountPercent) {
    button.textContent = `${name} - `;
    if (data.originalPrice && data.price < data.originalPrice && discountPercent > 0) {
        const original = document.createElement('span');
        original.style.textDecoration = 'line-through';
        original.style.color = '#888';
        original.textContent = `$${data.originalPrice}`;
        button.append(original, document.createTextNode(` $${data.price} (${Math.round(discountPercent)}% Rabatt)`));
    } else {
        button.append(document.createTextNode(`$${data.price}`));
    }
}

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
        setProductButtonLabel(btn, name, data, jobDiscounts.drinks || 0);
        btn.className = 'menu-btn';
        btn.onclick = () => {
            if (window.fetch) {
                fetch(nuiUrl('buyDrink'), {
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
        setProductButtonLabel(btn, name, data, jobDiscounts.drinks || 0);
        btn.className = 'menu-btn tray-btn';
        btn.onclick = () => {
            if (window.fetch) {
                fetch(nuiUrl('buyTray'), {
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
                fetch(nuiUrl('buyCoal'), {
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
        setProductButtonLabel(btn, name, data, jobDiscounts.drinks || 0);
        btn.className = 'menu-btn mix-btn';
        btn.onclick = () => {
            if (window.fetch) {
                fetch(nuiUrl('buyMix'), {
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
                fetch(nuiUrl('buyFlavor'), {
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
        fetch(nuiUrl('closeMenu'), { method: 'POST' }).catch(e => console.error('Fehler beim Schließen:', e));
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
        fetch(nuiUrl('adminAction'), {
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

function appendPriceRow(container, label, inputId, price, onSave) {
    const row = document.createElement('div');
    row.className = 'price-row';

    const name = document.createElement('span');
    name.textContent = label;
    const input = document.createElement('input');
    input.type = 'number';
    input.id = inputId;
    input.value = price;
    input.min = '0';
    input.max = '1000000';
    const button = document.createElement('button');
    button.textContent = 'Speichern';
    button.addEventListener('click', onSave);

    row.append(name, document.createTextNode(' '), input, document.createTextNode(' '), button);
    container.appendChild(row);
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
                const tableId = index + 1;
                appendPriceRow(tablePriceList, table.label, `tablePrice_${tableId}`, table.price, () => updateTablePrice(tableId));
            });
        }

        drinkPriceList.innerHTML = '';
        if (config.Drinks) {
            Object.entries(config.Drinks).forEach(([name, data]) => {
                const id = safeId(name);
                appendPriceRow(drinkPriceList, name, `drinkPrice_${id}`, data.price, () => updateDrinkPrice(id, name));
            });
        }

        trayPriceList.innerHTML = '';
        if (config.Trays) {
            Object.entries(config.Trays).forEach(([name, data]) => {
                const id = safeId(name);
                appendPriceRow(trayPriceList, name, `trayPrice_${id}`, data.price, () => updateTrayPrice(id, name));
            });
        }
        boss.style.display = 'block';
        loadStats();
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
        fetch(nuiUrl('bossAction'), {
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
        fetch(nuiUrl('bossAction'), {
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
        fetch(nuiUrl('bossAction'), {
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
        fetch(nuiUrl('bossAction'), {
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
        fetch(nuiUrl('bossAction'), {
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
        fetch(nuiUrl('bossAction'), {
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
        fetch(nuiUrl('bossAction'), {
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
        fetch(nuiUrl('bossAction'), {
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
