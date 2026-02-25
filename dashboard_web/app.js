const storageKey = 'sudvet-dashboard-config';
const sessionKey = 'sudvet-dashboard-session';

const els = {
  authView: document.getElementById('authView'),
  dashboardShell: document.getElementById('dashboardShell'),
  loginApiBaseUrl: document.getElementById('loginApiBaseUrl'),
  loginEmail: document.getElementById('loginEmail'),
  loginPassword: document.getElementById('loginPassword'),
  loginRole: document.getElementById('loginRole'),
  loginBtn: document.getElementById('loginBtn'),
  authStatus: document.getElementById('authStatus'),
  apiBaseUrl: document.getElementById('apiBaseUrl'),
  saveConfigBtn: document.getElementById('saveConfigBtn'),
  refreshBtn: document.getElementById('refreshBtn'),
  logoutBtn: document.getElementById('logoutBtn'),
  sessionUser: document.getElementById('sessionUser'),
  statusText: document.getElementById('statusText'),
  generatedAt: document.getElementById('generatedAt'),
  viewTitle: document.getElementById('viewTitle'),
  vetView: document.getElementById('vetView'),
  systemView: document.getElementById('systemView'),
  vetKpis: document.getElementById('vetKpis'),
  systemKpis: document.getElementById('systemKpis'),
  vetQueueBody: document.getElementById('vetQueueBody'),
  workerList: document.getElementById('workerList'),
  diseaseList: document.getElementById('diseaseList'),
  platformStatus: document.getElementById('platformStatus'),
};

let activeView = 'vet';
let currentSession = null;

const defaultConfig = {
  apiBaseUrl: 'http://127.0.0.1:8000',
};

function loadSession() {
  const raw = localStorage.getItem(sessionKey);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function saveSession(session) {
  localStorage.setItem(sessionKey, JSON.stringify(session));
}

function clearSession() {
  localStorage.removeItem(sessionKey);
  currentSession = null;
}

function loadConfig() {
  const raw = localStorage.getItem(storageKey);
  if (!raw) {
    return { ...defaultConfig };
  }
  try {
    return { ...defaultConfig, ...JSON.parse(raw) };
  } catch {
    return { ...defaultConfig };
  }
}

function saveConfig(config) {
  localStorage.setItem(storageKey, JSON.stringify(config));
}

function normalizeBaseUrl(baseUrl) {
  return (baseUrl || '').trim().replace(/\/+$/, '');
}

function urgencyOf(item) {
  const prediction = (item.prediction || '').toLowerCase();
  const confidence = Number(item.confidence || 0);
  if (!prediction) return 'Medium';
  if (prediction.includes('normal') && confidence >= 0.8) return 'Low';
  if (confidence < 0.65) return 'Medium';
  if (prediction.includes('lsd') || prediction.includes('fmd') || prediction.includes('cbpp')) {
    return 'High';
  }
  return 'Medium';
}

function diseaseKey(item) {
  const prediction = (item.prediction || '').toLowerCase();
  if (!prediction) return 'unknown';
  if (prediction.includes('normal')) return 'normal';
  if (prediction.includes('lsd')) return 'lsd';
  if (prediction.includes('fmd')) return 'fmd';
  if (prediction.includes('ecf')) return 'ecf';
  if (prediction.includes('cbpp')) return 'cbpp';
  return 'unknown';
}

function setStatus(message, isError = false) {
  els.statusText.textContent = message;
  els.statusText.style.color = isError ? '#ffd2d2' : '#afc0e9';
}

function setAuthStatus(message, isError = false) {
  els.authStatus.textContent = message;
  els.authStatus.style.color = isError ? '#c43b3b' : '#6b7280';
}

function isRoleAllowed(role) {
  return role === 'vet' || role === 'admin';
}

function isSessionExpired(session) {
  const expiresAt = Number(session?.expiresAt || 0);
  return !expiresAt || Date.now() >= expiresAt;
}

function applySessionUi(session) {
  const userEmail = session?.user?.email || '-';
  const userRole = session?.dashboardRole ? session.dashboardRole.toUpperCase() : '-';
  els.sessionUser.textContent = `Signed in as: ${userEmail} (${userRole})`;
}

function showDashboard(session) {
  els.authView.classList.add('hidden');
  els.dashboardShell.classList.remove('hidden');
  applySessionUi(session);
}

function showAuth() {
  els.dashboardShell.classList.add('hidden');
  els.authView.classList.remove('hidden');
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, options);
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Request failed ${response.status}: ${text || 'Unknown error'}`);
  }
  return response.json();
}

async function login() {
  const apiBaseUrl = normalizeBaseUrl(els.loginApiBaseUrl.value);
  const email = els.loginEmail.value.trim();
  const password = els.loginPassword.value;
  const dashboardRole = els.loginRole.value;

  if (!apiBaseUrl || !email || !password) {
    setAuthStatus('API URL, email, and password are required.', true);
    return;
  }
  if (!isRoleAllowed(dashboardRole)) {
    setAuthStatus('Only vet/admin dashboard roles are allowed.', true);
    return;
  }

  els.loginBtn.disabled = true;
  setAuthStatus('Signing in...');

  try {
    const payload = { email, password };
    let data;
    try {
      data = await fetchJson(`${apiBaseUrl}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    } catch {
      data = await fetchJson(`${apiBaseUrl}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    }

    const token = data.token || data.access_token;
    const refreshToken = data.refreshToken || data.refresh_token || '';
    const ttlSeconds = Number(data.accessTokenExpiresInSeconds || 1800);
    const user = data.user || { email };

    if (!token) {
      throw new Error('Login succeeded but no access token was returned.');
    }

    const session = {
      token,
      refreshToken,
      user,
      dashboardRole,
      apiBaseUrl,
      expiresAt: Date.now() + ttlSeconds * 1000,
    };

    currentSession = session;
    saveSession(session);
    saveConfig({ apiBaseUrl: session.apiBaseUrl });
    els.apiBaseUrl.value = session.apiBaseUrl;
    showDashboard(session);
    setAuthStatus('Login successful.');
    await refreshData();
  } catch (error) {
    setAuthStatus(error.message || 'Login failed.', true);
  } finally {
    els.loginBtn.disabled = false;
  }
}

async function tryRefreshSession(session) {
  if (!session?.refreshToken) return null;
  const apiBaseUrl = normalizeBaseUrl(session.apiBaseUrl);
  if (!apiBaseUrl) return null;

  const payload = { refreshToken: session.refreshToken };
  try {
    let data;
    try {
      data = await fetchJson(`${apiBaseUrl}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    } catch {
      data = await fetchJson(`${apiBaseUrl}/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    }

    const token = data.token || data.access_token;
    const refreshToken = data.refreshToken || data.refresh_token || session.refreshToken;
    const ttlSeconds = Number(data.accessTokenExpiresInSeconds || 1800);
    if (!token) return null;

    const next = {
      ...session,
      token,
      refreshToken,
      expiresAt: Date.now() + ttlSeconds * 1000,
    };
    saveSession(next);
    return next;
  } catch {
    return null;
  }
}

async function ensureSession() {
  if (!currentSession) return false;
  if (!isRoleAllowed(currentSession.dashboardRole)) {
    logout('Role is not allowed for dashboard access.');
    return false;
  }
  if (!isSessionExpired(currentSession)) {
    return true;
  }
  const refreshed = await tryRefreshSession(currentSession);
  if (!refreshed) {
    logout('Session expired. Please sign in again.');
    return false;
  }
  currentSession = refreshed;
  applySessionUi(currentSession);
  return true;
}

function logout(message = 'Logged out.') {
  clearSession();
  showAuth();
  setAuthStatus(message);
}

async function apiGet(path, config) {
  const baseUrl = normalizeBaseUrl(config.apiBaseUrl);
  if (!baseUrl) {
    throw new Error('API Base URL is required.');
  }
  const headers = {};
  if (config.authToken && config.authToken.trim()) {
    headers.Authorization = `Bearer ${config.authToken.trim()}`;
  }
  const response = await fetch(`${baseUrl}${path}`, { headers });
  if (response.status === 401) {
    throw new Error('Unauthorized. Please sign in again.');
  }
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Request failed ${response.status}: ${text || 'Unknown error'}`);
  }
  return response.json();
}

function renderKpis(container, rows) {
  container.innerHTML = rows
    .map(
      (row) => `
      <article class="kpi-card">
        <p>${row.label}</p>
        <h3>${row.value}</h3>
      </article>
    `
    )
    .join('');
}

function renderVetQueue(inbox) {
  if (!inbox.length) {
    els.vetQueueBody.innerHTML = '<tr><td colspan="5">No cases in vet queue.</td></tr>';
    return;
  }

  const rank = { High: 3, Medium: 2, Low: 1 };
  inbox.sort((a, b) => {
    const ua = urgencyOf(a);
    const ub = urgencyOf(b);
    if (rank[ub] !== rank[ua]) return rank[ub] - rank[ua];
    return new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime();
  });

  els.vetQueueBody.innerHTML = inbox
    .slice(0, 50)
    .map((item) => {
      const urgency = urgencyOf(item);
      const badgeClass = urgency.toLowerCase();
      const animal = item.animalName || item.animalTag || 'Quick Case';
      const chw = item.chwOwnerName || item.chwOwnerEmail || 'Unknown CHW';
      const vet = item.assignedVetName || item.assignedVetEmail || 'Unassigned';
      return `
        <tr>
          <td>${animal}</td>
          <td>${item.prediction || 'Unknown'}</td>
          <td><span class="badge ${badgeClass}">${urgency}</span></td>
          <td>${chw}</td>
          <td>${vet}</td>
        </tr>
      `;
    })
    .join('');
}

function renderWorkerLoad(inbox) {
  const counts = new Map();
  for (const item of inbox) {
    const worker = item.chwOwnerName || item.chwOwnerEmail || 'Unknown CHW';
    counts.set(worker, (counts.get(worker) || 0) + 1);
  }

  const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 12);
  if (!sorted.length) {
    els.workerList.innerHTML = '<li><span>No workload data</span><strong>0</strong></li>';
    return;
  }

  els.workerList.innerHTML = sorted
    .map(([worker, total]) => `<li><span>${worker}</span><strong>${total}</strong></li>`)
    .join('');
}

function renderDiseaseDistribution(cases) {
  const counts = new Map();
  for (const item of cases) {
    const key = diseaseKey(item);
    counts.set(key, (counts.get(key) || 0) + 1);
  }

  const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]);
  if (!sorted.length) {
    els.diseaseList.innerHTML = '<li>No disease analytics yet</li>';
    return;
  }

  els.diseaseList.innerHTML = sorted
    .map(([disease, total]) => `<li>${disease.toUpperCase()}: ${total}</li>`)
    .join('');
}

function renderSystemStatus({ pendingCount, cases, animals, baseUrl }) {
  const failed = cases.filter((item) => (item.status || '').toLowerCase() === 'failed').length;
  const offlineRisk = pendingCount > 0 || failed > 0 ? 'Needs attention' : 'Healthy';

  const rows = [
    ['Backend', baseUrl || '-'],
    ['Queue State', `${pendingCount} pending sync`],
    ['Failure State', `${failed} failed cases`],
    ['Overall', offlineRisk],
    ['Animals Managed', `${animals.length}`],
  ];

  els.platformStatus.innerHTML = rows
    .map(([label, value]) => `<li><span>${label}</span><strong>${value}</strong></li>`)
    .join('');
}

async function refreshData() {
  const sessionOk = await ensureSession();
  if (!sessionOk) {
    return;
  }

  const config = {
    apiBaseUrl: els.apiBaseUrl.value,
    authToken: currentSession?.token || '',
  };
  saveConfig(config);

  setStatus('Loading dashboard data...');

  try {
    const [inbox, cases, animals, pendingCount] = await Promise.all([
      apiGet('/vet/inbox?limit=200', config).catch(() => []),
      apiGet('/cases?limit=500', config).catch(() => []),
      apiGet('/animals', config).catch(() => []),
      apiGet('/cases/pending-count', config).catch(() => 0),
    ]);

    const highUrgency = inbox.filter((item) => urgencyOf(item) === 'High').length;
    const unassigned = inbox.filter(
      (item) => !(item.assignedVetName || item.assignedVetEmail)
    ).length;
    const pendingGlobal = cases.filter(
      (item) => (item.status || '').toLowerCase() === 'pending'
    ).length;
    const failedGlobal = cases.filter((item) => (item.status || '').toLowerCase() === 'failed').length;

    renderKpis(els.vetKpis, [
      { label: 'Cases in Vet Queue', value: inbox.length },
      { label: 'High Urgency', value: highUrgency },
      { label: 'Unassigned Cases', value: unassigned },
      { label: 'Pending (Global)', value: pendingGlobal },
    ]);

    renderKpis(els.systemKpis, [
      { label: 'Total Cases', value: cases.length },
      { label: 'Registered Animals', value: animals.length },
      { label: 'Pending Sync Queue', value: pendingCount },
      { label: 'Failed Cases', value: failedGlobal },
    ]);

    renderVetQueue(inbox);
    renderWorkerLoad(inbox);
    renderDiseaseDistribution(cases);
    renderSystemStatus({ pendingCount, cases, animals, baseUrl: config.apiBaseUrl });

    const now = new Date();
    els.generatedAt.textContent = `Last updated: ${now.toLocaleString()}`;
    setStatus('Dashboard data loaded successfully.');
  } catch (error) {
    if ((error.message || '').toLowerCase().includes('unauthorized')) {
      logout('Session is invalid. Please sign in again.');
      return;
    }
    setStatus(error.message || 'Failed to load data.', true);
  }
}

function setView(view) {
  activeView = view;
  const menuItems = document.querySelectorAll('.menu-item');
  menuItems.forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.view === view);
  });

  els.vetView.classList.toggle('active', view === 'vet');
  els.systemView.classList.toggle('active', view === 'system');
  els.viewTitle.textContent = view === 'vet' ? 'Vet Dashboard' : 'System Management Dashboard';
}

function init() {
  const config = loadConfig();
  els.loginApiBaseUrl.value = config.apiBaseUrl;
  els.apiBaseUrl.value = config.apiBaseUrl;

  document.querySelectorAll('.menu-item').forEach((btn) => {
    btn.addEventListener('click', () => setView(btn.dataset.view));
  });

  els.loginBtn.addEventListener('click', login);
  els.loginPassword.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      login();
    }
  });

  els.saveConfigBtn.addEventListener('click', () => {
    const normalized = normalizeBaseUrl(els.apiBaseUrl.value);
    if (currentSession) {
      currentSession.apiBaseUrl = normalized;
      saveSession(currentSession);
    }
    saveConfig({ apiBaseUrl: normalized });
    els.loginApiBaseUrl.value = normalized;
    setStatus('Connection settings saved.');
  });

  els.refreshBtn.addEventListener('click', refreshData);
  els.logoutBtn.addEventListener('click', () => logout('Signed out.'));

  setView(activeView);

  const session = loadSession();
  if (session && isRoleAllowed(session.dashboardRole)) {
    currentSession = session;
    els.apiBaseUrl.value = session.apiBaseUrl || config.apiBaseUrl;
    els.loginApiBaseUrl.value = session.apiBaseUrl || config.apiBaseUrl;
    showDashboard(session);
    refreshData();
  } else {
    showAuth();
  }
}

init();
