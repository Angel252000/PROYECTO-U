const API_URL = 'http://localhost:3000/api';

// Navigation
function showSection(section) {
    document.getElementById('dashboard-section').classList.add('hidden');
    document.getElementById('pautas-section').classList.add('hidden');
    document.getElementById('gap-section').classList.add('hidden');
    document.getElementById('audit-section').classList.add('hidden');
    document.getElementById(`${section}-section`).classList.remove('hidden');

    if (section === 'dashboard') loadDashboard();
    if (section === 'pautas') loadPautas();
    if (section === 'gap') loadGapAnalysis();
    if (section === 'audit') loadAudit();
    if (section === 'mejora') loadPlanMejora();
}

// Load Dashboard Data
async function loadDashboard() {
    const res = await fetch(`${API_URL}/dashboard`);
    const data = await res.json();

    document.getElementById('overall-progress').innerText = `${data.overallProgress.toFixed(1)}%`;
    document.getElementById('pautas-evaluadas').innerText = `${data.pautasEvaluadas} / ${data.totalPautas}`;
    document.getElementById('total-score').innerText = `${data.totalObtainedScore.toFixed(1)} / ${data.totalMaxScore.toFixed(1)}`;

    renderRadarChart(data.dimStats);
    renderProgressBars(data.dimStats);
}

function renderRadarChart(dimStats) {
    const ctx = document.getElementById('radarChart').getContext('2d');
    const labels = Object.keys(dimStats).map(id => `Dim ${id}`);
    const values = Object.values(dimStats).map(s => (s.obtained / s.max) * 100);

    if (window.myRadarChart) window.myRadarChart.destroy();

    window.myRadarChart = new Chart(ctx, {
        type: 'radar',
        data: {
            labels: labels,
            datasets: [{
                label: '% Conformidad',
                data: values,
                backgroundColor: 'rgba(54, 162, 235, 0.2)',
                borderColor: 'rgb(54, 162, 235)',
                pointBackgroundColor: 'rgb(54, 162, 235)',
            }]
        },
        options: {
            scales: {
                r: {
                    angleLines: { display: false },
                    suggestedMin: 0,
                    suggestedMax: 100
                }
            }
        }
    });
}

function renderProgressBars(dimStats) {
    const container = document.getElementById('dim-progress-bars');
    container.innerHTML = '';

    Object.entries(dimStats).forEach(([id, stats]) => {
        const percent = (stats.obtained / stats.max) * 100;
        const html = `
            <div class="mb-4">
                <div class="flex justify-between mb-1">
                    <span class="text-sm font-medium">Dimensión ${id}</span>
                    <span class="text-sm font-medium">${percent.toFixed(1)}%</span>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-2.5">
                    <div class="bg-blue-600 h-2.5 rounded-full" style="width: ${percent}%"></div>
                </div>
            </div>
        `;
        container.innerHTML += html;
    });
}

// Load Pautas Data
async function loadPautas() {
    const res = await fetch(`${API_URL}/pautas`);
    const pautas = await res.json();
    const tbody = document.getElementById('pautas-table-body');
    tbody.innerHTML = '';

    pautas.forEach(p => {
        const statusColor = p.conformidad === 100 ? 'bg-green-500' : (p.conformidad === 50 ? 'bg-yellow-500' : 'bg-red-500');
        const tr = document.createElement('tr');
        tr.className = "border-b hover:bg-gray-50";
        tr.innerHTML = `
            <td class="py-3">${p.codigo}</td>
            <td class="py-3">${p.nombre}</td>
            <td class="py-3 font-bold">${p.categoria}</td>
            <td class="py-3">${p.conformidad !== null ? p.conformidad + '%' : 'N/A'}</td>
            <td class="py-3"><span class="traffic-light ${statusColor}"></span></td>
            <td class="py-3">
                <button onclick="openEvalModal(${p.id}, '${p.nombre}', ${p.conformidad}, '${p.argumentacion || ''}')" class="text-blue-600 hover:underline">Evaluar</button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

// Modal Logic
async function openEvalModal(id, nombre, conformidad, argumentacion) {
    document.getElementById('eval-pauta-id').value = id;
    document.getElementById('modal-title').innerText = `Evaluar: ${nombre}`;
    document.getElementById('eval-conformidad').value = conformidad || 100;
    document.getElementById('eval-argumentacion').value = argumentacion || '';

    // Cargar Guía Inteligente
    const res = await fetch(`${API_URL}/pautas/${id}`);
    const data = await res.json();
    const subContainer = document.getElementById('guia-subprocesos');
    subContainer.innerHTML = data.subprocesos.map(s => `<li>${s.descripcion}</li>`).join('');

    document.getElementById('eval-modal').classList.remove('hidden');
}

function closeModal() {
    document.getElementById('eval-modal').classList.add('hidden');
}

document.getElementById('eval-form').onsubmit = async (e) => {
    e.preventDefault();
    const pauta_id = document.getElementById('eval-pauta-id').value;
    const conformidad = document.getElementById('eval-conformidad').value;
    const argumentacion = document.getElementById('eval-argumentacion').value;
    const archivoInput = document.getElementById('eval-archivo');

    // Guardar evaluación
    const resEval = await fetch(`${API_URL}/evaluaciones`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pauta_id, conformidad, argumentacion })
    });

    // Subir archivo si existe
    if (resEval.ok && archivoInput.files.length > 0) {
        const formData = new FormData();
        formData.append('pauta_id', pauta_id);
        formData.append('archivo', archivoInput.files[0]);

        await fetch(`${API_URL}/evidencias`, {
            method: 'POST',
            body: formData
        });
    }

    if (resEval.ok) {
        closeModal();
        loadPautas();
        loadDashboard();
    }
};

async function loadGapAnalysis() {
    const res = await fetch(`${API_URL}/gap-analysis`);
    const data = await res.json();
    const tbody = document.getElementById('gap-table-body');
    tbody.innerHTML = '';

    data.forEach((p, index) => {
        const tr = document.createElement('tr');
        tr.className = "border-b";
        tr.innerHTML = `
            <td class="py-3 font-bold text-red-600">#${index + 1}</td>
            <td class="py-3">${p.codigo} - ${p.nombre}</td>
            <td class="py-3 font-bold">${p.categoria}</td>
            <td class="py-3">${p.gap}%</td>
            <td class="py-3 text-sm italic text-gray-600">Atender pauta de alto impacto</td>
        `;
        tbody.appendChild(tr);
    });
}

async function loadPlanMejora() {
    const [resMejora, resPautas] = await Promise.all([
        fetch(`${API_URL}/plan-mejora`),
        fetch(`${API_URL}/pautas`)
    ]);

    const mejoras = await resMejora.json();
    const pautas = await resPautas.json();

    // Fill Select
    const select = document.getElementById('mejora-pauta');
    select.innerHTML = '<option value="">Seleccione Pauta...</option>';
    pautas.forEach(p => {
        select.innerHTML += `<option value="${p.id}">${p.codigo} - ${p.nombre}</option>`;
    });

    // Fill Table
    const tbody = document.getElementById('mejora-table-body');
    tbody.innerHTML = '';
    mejoras.forEach(m => {
        const tr = document.createElement('tr');
        tr.className = "border-b";
        tr.innerHTML = `
            <td class="py-3">${m.codigo}</td>
            <td class="py-3">${m.actividad}</td>
            <td class="py-3">${m.responsable || 'N/A'}</td>
            <td class="py-3">${m.plazo || 'N/A'}</td>
            <td class="py-3 font-bold ${m.prioridad === 'Alta' ? 'text-red-600' : 'text-yellow-600'}">${m.prioridad}</td>
        `;
        tbody.appendChild(tr);
    });
}

document.getElementById('mejora-form').onsubmit = async (e) => {
    e.preventDefault();
    const pauta_id = document.getElementById('mejora-pauta').value;
    const actividad = document.getElementById('mejora-actividad').value;
    const responsable = document.getElementById('mejora-responsable').value;
    const plazo = document.getElementById('mejora-plazo').value;
    const recursos = document.getElementById('mejora-recursos').value;
    const prioridad = document.getElementById('mejora-prioridad').value;

    const res = await fetch(`${API_URL}/plan-mejora`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pauta_id, actividad, responsable, plazo, recursos, prioridad })
    });

    if (res.ok) {
        document.getElementById('mejora-form').reset();
        loadPlanMejora();
    }
};

async function loadAudit() {
    const res = await fetch(`${API_URL}/audit`);
    const data = await res.json();
    const container = document.getElementById('audit-report');
    container.innerHTML = '';

    if (data.length === 0) {
        container.innerHTML = '<p class="col-span-2 text-gray-500">No hay pautas evaluadas para auditar.</p>';
        return;
    }

    data.forEach(p => {
        const statusClass = p.status === 'verde' ? 'border-green-500' : (p.status === 'amarillo' ? 'border-yellow-500' : 'border-red-500');
        const html = `
            <div class="bg-white p-6 rounded-lg shadow border-l-4 ${statusClass}">
                <div class="flex justify-between items-start mb-2">
                    <h4 class="font-bold">${p.codigo} - ${p.nombre}</h4>
                    <span class="traffic-light bg-${p.status}-500"></span>
                </div>
                <p class="text-sm text-gray-600 mb-4">${p.argumentacion || 'Sin argumentación'}</p>
                <ul class="text-xs text-red-600">
                    ${p.missing.map(m => `<li>• ${m}</li>`).join('')}
                </ul>
            </div>
        `;
        container.innerHTML += html;
    });
}

// Initial load
loadDashboard();
