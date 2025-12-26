// Pilot Logbook NUI JavaScript
let logbookData = null;
let flightLog = [];

// Listen for NUI messages from Lua
window.addEventListener('message', function(event) {
    const data = event.data;

    switch(data.action) {
        case 'openLogbook':
            openLogbook(data.stats, data.flights, data.incidents);
            break;
        case 'closeLogbook':
            closeLogbook();
            break;
        case 'updateStats':
            updateStats(data.stats);
            break;
    }
});

// Close with ESC key
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeLogbook();
    }
});

// Tab navigation
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', function() {
        const tabId = this.dataset.tab;

        // Update active tab button
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        this.classList.add('active');

        // Show corresponding content
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        document.getElementById(tabId).classList.add('active');
    });
});

// Flight filter
document.getElementById('flight-filter').addEventListener('change', function() {
    filterFlights(this.value);
});

function openLogbook(stats, flights, incidents) {
    logbookData = stats;
    flightLog = flights || [];

    document.getElementById('logbook-container').classList.remove('hidden');

    updateStats(stats);
    populateFlights(flights);
    populateRatings(stats.type_ratings || []);
    populateIncidents(incidents || [], stats);
}

function closeLogbook() {
    document.getElementById('logbook-container').classList.add('hidden');

    // Notify Lua
    fetch('https://dps-airlines/closeLogbook', {
        method: 'POST',
        body: JSON.stringify({})
    });
}

function updateStats(stats) {
    if (!stats) return;

    // Pilot name
    document.getElementById('pilot-name').textContent = stats.name || 'Pilot';

    // Main hours
    document.getElementById('total-hours').textContent = formatHours(stats.total_hours);
    document.getElementById('pic-hours').textContent = formatHours(stats.pic_hours);
    document.getElementById('night-hours').textContent = formatHours(stats.night_hours);
    document.getElementById('ifr-hours').textContent = formatHours(stats.ifr_hours);

    // Landings
    document.getElementById('day-landings').textContent = stats.day_landings || 0;
    document.getElementById('night-landings').textContent = stats.night_landings || 0;
    document.getElementById('hard-landings').textContent = stats.hard_landings || 0;

    // Hours breakdown
    const passengerHours = parseFloat(stats.passenger_hours) || 0;
    const cargoHours = parseFloat(stats.cargo_hours) || 0;
    const charterHours = parseFloat(stats.charter_hours) || 0;
    const ferryHours = parseFloat(stats.ferry_hours) || 0;
    const totalTypeHours = passengerHours + cargoHours + charterHours + ferryHours;

    if (totalTypeHours > 0) {
        document.getElementById('bar-passenger').style.width = (passengerHours / totalTypeHours * 100) + '%';
        document.getElementById('bar-cargo').style.width = (cargoHours / totalTypeHours * 100) + '%';
        document.getElementById('bar-charter').style.width = (charterHours / totalTypeHours * 100) + '%';
        document.getElementById('bar-ferry').style.width = (ferryHours / totalTypeHours * 100) + '%';
    }

    document.getElementById('passenger-hours').textContent = formatHours(passengerHours);
    document.getElementById('cargo-hours').textContent = formatHours(cargoHours);
    document.getElementById('charter-hours').textContent = formatHours(charterHours);
    document.getElementById('ferry-hours').textContent = formatHours(ferryHours);

    // License
    const licenseEl = document.getElementById('license-type');
    const license = (stats.license_type || 'student').toUpperCase();
    licenseEl.textContent = license;
    licenseEl.className = 'license-badge ' + (stats.license_type || 'student');

    // Reputation
    document.getElementById('reputation').textContent = stats.reputation || 0;

    // Earnings
    document.getElementById('total-earnings').textContent = '$' + formatNumber(stats.total_earnings || 0);
}

function populateFlights(flights) {
    const container = document.getElementById('flight-entries');
    container.innerHTML = '';

    if (!flights || flights.length === 0) {
        container.innerHTML = '<div class="flight-entry" style="justify-content: center; color: #666;">No flights recorded yet</div>';
        return;
    }

    flights.forEach(flight => {
        const entry = document.createElement('div');
        entry.className = 'flight-entry';
        entry.dataset.type = flight.flight_type;

        const date = flight.departure_time ? formatDate(flight.departure_time) : 'N/A';
        const route = `${flight.departure_airport || '???'} → ${flight.arrival_airport || '???'}`;
        const aircraft = flight.aircraft_model || 'Unknown';
        const time = formatHours(flight.flight_time) + 'h';
        const type = capitalizeFirst(flight.flight_type || 'unknown');
        const landing = flight.landing_quality || 'normal';
        const payment = '$' + formatNumber(flight.payment || 0);

        entry.innerHTML = `
            <span>${date}</span>
            <span class="route">${route}</span>
            <span>${aircraft}</span>
            <span>${time}</span>
            <span>${type}</span>
            <span class="landing-quality ${landing}">${landing}</span>
            <span class="payment">${payment}</span>
        `;

        container.appendChild(entry);
    });
}

function filterFlights(type) {
    const entries = document.querySelectorAll('.flight-entry');
    entries.forEach(entry => {
        if (type === 'all' || entry.dataset.type === type) {
            entry.style.display = 'grid';
        } else {
            entry.style.display = 'none';
        }
    });
}

function populateRatings(ratings) {
    const container = document.getElementById('ratings-grid');

    // All possible aircraft
    const allAircraft = [
        { name: 'luxor', label: 'Luxor', icon: 'fa-plane' },
        { name: 'shamal', label: 'Shamal', icon: 'fa-plane' },
        { name: 'nimbus', label: 'Nimbus', icon: 'fa-plane' },
        { name: 'miljet', label: 'Miljet', icon: 'fa-jet-fighter' },
        { name: 'velum', label: 'Velum', icon: 'fa-plane-departure' },
        { name: 'velum2', label: 'Velum 5-Seater', icon: 'fa-plane-departure' },
        { name: 'cuban800', label: 'Cuban 800', icon: 'fa-plane' },
        { name: 'duster', label: 'Duster', icon: 'fa-plane-up' },
        { name: 'mammatus', label: 'Mammatus', icon: 'fa-plane' },
        { name: 'stunt', label: 'Mallard', icon: 'fa-plane' },
        { name: 'vestra', label: 'Vestra', icon: 'fa-jet-fighter' },
        { name: 'howard', label: 'Howard NX-25', icon: 'fa-plane' }
    ];

    container.innerHTML = '';

    allAircraft.forEach(aircraft => {
        const isUnlocked = ratings.includes(aircraft.name);
        const card = document.createElement('div');
        card.className = `rating-card ${isUnlocked ? 'unlocked' : 'locked'}`;

        card.innerHTML = `
            <i class="fas ${aircraft.icon}"></i>
            <h4>${aircraft.label}</h4>
            <span>${isUnlocked ? 'CERTIFIED' : 'NOT CERTIFIED'}</span>
        `;

        container.appendChild(card);
    });
}

function populateIncidents(incidents, stats) {
    // Safety status
    const crashes = stats.crashes || 0;
    const totalIncidents = stats.incidents || 0;
    const emergencies = stats.emergencies_handled || 0;

    document.getElementById('crash-count').textContent = crashes;
    document.getElementById('incident-count').textContent = totalIncidents;
    document.getElementById('emergency-count').textContent = emergencies;

    // Calculate safety rating
    const safetyEl = document.getElementById('safety-status');
    let safetyClass = 'excellent';
    let safetyText = 'EXCELLENT';

    if (crashes > 3) {
        safetyClass = 'poor';
        safetyText = 'POOR';
    } else if (crashes > 1 || totalIncidents > 5) {
        safetyClass = 'fair';
        safetyText = 'FAIR';
    } else if (crashes > 0 || totalIncidents > 2) {
        safetyClass = 'good';
        safetyText = 'GOOD';
    }

    safetyEl.className = 'safe-badge ' + safetyClass;
    safetyEl.textContent = safetyText;

    // Incident list
    const container = document.getElementById('incident-list');
    container.innerHTML = '';

    if (!incidents || incidents.length === 0) {
        container.innerHTML = '<div class="incident-item"><i class="fas fa-check-circle" style="color: #4ecca3;"></i><div class="incident-info"><h5>Clean Record</h5><p>No incidents or emergencies on file</p></div></div>';
        return;
    }

    incidents.forEach(incident => {
        const item = document.createElement('div');
        item.className = `incident-item ${incident.resolved ? 'resolved' : ''}`;

        const icon = getIncidentIcon(incident.type);
        const date = incident.date ? formatDate(incident.date) : '';

        item.innerHTML = `
            <i class="fas ${icon}"></i>
            <div class="incident-info">
                <h5>${incident.title || incident.type}</h5>
                <p>${incident.description || ''}</p>
            </div>
            <span class="incident-date">${date}</span>
        `;

        container.appendChild(item);
    });
}

function getIncidentIcon(type) {
    const icons = {
        'crash': 'fa-plane-slash',
        'engine_fire': 'fa-fire',
        'gear_failure': 'fa-cog',
        'fuel_leak': 'fa-gas-pump',
        'electrical': 'fa-bolt',
        'hydraulic': 'fa-water',
        'hard_landing': 'fa-arrow-down',
        'emergency': 'fa-exclamation-triangle'
    };
    return icons[type] || 'fa-exclamation-circle';
}

// Utility functions
function formatHours(hours) {
    const h = parseFloat(hours) || 0;
    return h.toFixed(1);
}

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function formatDate(dateStr) {
    const date = new Date(dateStr);
    if (isNaN(date)) return dateStr;
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function capitalizeFirst(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}
