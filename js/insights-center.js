/* insights-center.js */

import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.43.4/+esm";

const supabase = createClient("https://sfknzqkiqxivzcualcau.supabase.co", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma256cWtpcXhpdnpjdWFsY2F1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3OTU0ODksImV4cCI6MjA3MjM3MTQ4OX0.JKjOS9NRdbVH1UanfqmBeHmMSnlWlZtDr-5LdKw5YaA");

// Tab state and counts
let activeTab = 'alerts';
let alertsCount = 0;
let warningsCount = 0;
let insightsCount = 0;

// Tab switcher handler
window.switchTab = function(tabName) {
  // Update buttons
  document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
  const activeBtn = document.getElementById(`tab-${tabName}`);
  if (activeBtn) activeBtn.classList.add('active');

  // Update panels
  document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
  const activePanel = document.getElementById(`content-${tabName}`);
  if (activePanel) activePanel.classList.add('active');

  activeTab = tabName;
  
  // Update URL parameter silently to support bookmarks and deep links
  const newUrl = window.location.pathname + `?tab=${tabName}`;
  window.history.pushState({ path: newUrl }, '', newUrl);
};

// Check query param for deep linking
function checkDeepLink() {
  const urlParams = new URLSearchParams(window.location.search);
  const tabParam = urlParams.get('tab');
  if (tabParam && ['alerts', 'warnings', 'insights'].includes(tabParam)) {
    switchTab(tabParam);
  }
}

// Fetch and render critical alerts
async function loadAlerts() {
  const grid = document.getElementById('grid-alerts');
  try {
    const { data, error } = await supabase.rpc('get_critical_alerts');
    if (error) throw error;

    alertsCount = data?.length || 0;
    document.getElementById('badge-alerts').textContent = alertsCount;

    if (!data || data.length === 0) {
      grid.innerHTML = `
        <div class="empty-state">
          <i class="fas fa-check-circle" style="color: #10b981;"></i>
          <h3>All Clear!</h3>
          <p>No critical active alerts or overdue shipments currently require your attention.</p>
        </div>`;
      return;
    }

    grid.innerHTML = '';
    data.forEach(alert => {
      const priorityClass = alert.priority || 'medium';
      const card = document.createElement('div');
      card.className = `insight-card ${priorityClass}`;
      card.onclick = () => {
         if (alert.reference_code) {
             window.location.href = `shipment-details.html?ref=${alert.reference_code}&focus=${alert.type}`;
         }
      };

      card.innerHTML = `
        <div class="card-main">
          <div class="card-icon-wrapper">
            <i class="fas fa-exclamation-triangle"></i>
          </div>
          <div class="card-body">
            <h3>${alert.title || 'Alert'}</h3>
            <p>${alert.subtitle || 'Details unavailable'}</p>
          </div>
        </div>
        <div class="card-meta">
          <span class="meta-pill">${priorityClass}</span>
          <i class="fas fa-chevron-right action-arrow"></i>
        </div>
      `;
      grid.appendChild(card);
    });
  } catch (err) {
    console.error('Error loading alerts:', err);
    grid.innerHTML = `<div class="empty-state"><i class="fas fa-exclamation-circle" style="color: red;"></i><h3>Load Error</h3><p>Could not fetch critical alerts from server: ${err.message}</p></div>`;
  }
}

// Fetch and render business warnings
async function loadWarnings() {
  const grid = document.getElementById('grid-warnings');
  try {
    const { data, error } = await supabase.rpc('get_business_warnings');
    if (error) throw error;

    warningsCount = data?.length || 0;
    document.getElementById('badge-warnings').textContent = warningsCount;

    if (!data || data.length === 0) {
      grid.innerHTML = `
        <div class="empty-state">
          <i class="fas fa-shield-alt" style="color: #3b82f6;"></i>
          <h3>All Secure</h3>
          <p>No operational capacity blocks or workflow warnings have been detected.</p>
        </div>`;
      return;
    }

    grid.innerHTML = '';
    data.forEach(warning => {
      const priorityClass = warning.priority || 'medium';
      const card = document.createElement('div');
      card.className = `insight-card ${priorityClass}`;
      card.onclick = () => {
         if (warning.reference_code) {
             window.location.href = `shipment-details.html?ref=${warning.reference_code}&focus=${warning.type}`;
         } else if (warning.type === 'supplier_capacity') {
             window.location.href = 'supplier-details.html';
         }
      };

      card.innerHTML = `
        <div class="card-main">
          <div class="card-icon-wrapper">
            <i class="fas fa-exclamation-circle"></i>
          </div>
          <div class="card-body">
            <h3>${warning.title || 'Warning'}</h3>
            <p>${warning.subtitle || 'Details unavailable'}</p>
          </div>
        </div>
        <div class="card-meta">
          <span class="meta-pill">${priorityClass}</span>
          <i class="fas fa-chevron-right action-arrow"></i>
        </div>
      `;
      grid.appendChild(card);
    });
  } catch (err) {
    console.error('Error loading warnings:', err);
    grid.innerHTML = `<div class="empty-state"><i class="fas fa-exclamation-circle" style="color: red;"></i><h3>Load Error</h3><p>Could not fetch operational warnings from server: ${err.message}</p></div>`;
  }
}

// Fetch and render operational insights
async function loadInsights() {
  const grid = document.getElementById('grid-insights');
  try {
    const { data, error } = await supabase.rpc('get_operational_insights');
    if (error) throw error;

    insightsCount = data?.length || 0;
    document.getElementById('badge-insights').textContent = insightsCount;

    if (!data || data.length === 0) {
      grid.innerHTML = `
        <div class="empty-state">
          <i class="fas fa-lightbulb" style="color: #f59e0b;"></i>
          <h3>No New Insights</h3>
          <p>Your import metrics look perfectly optimized. Keep up the great work!</p>
        </div>`;
      return;
    }

    grid.innerHTML = '';
    data.forEach(insight => {
      const card = document.createElement('div');
      card.className = `insight-card info`; // Insights are always informative
      card.onclick = () => {
         if (insight.reference_code) {
             window.location.href = `shipment-details.html?ref=${insight.reference_code}&focus=${insight.type}`;
         }
      };

      card.innerHTML = `
        <div class="card-main">
          <div class="card-icon-wrapper">
            <i class="fas fa-lightbulb"></i>
          </div>
          <div class="card-body">
            <h3>${insight.title || 'Operational Insight'}</h3>
            <p>${insight.subtitle || 'Details unavailable'}</p>
          </div>
        </div>
        <div class="card-meta">
          <span class="meta-pill">info</span>
          <i class="fas fa-chevron-right action-arrow"></i>
        </div>
      `;
      grid.appendChild(card);
    });
  } catch (err) {
    console.error('Error loading insights:', err);
    grid.innerHTML = `<div class="empty-state"><i class="fas fa-exclamation-circle" style="color: red;"></i><h3>Load Error</h3><p>Could not fetch operational insights from server: ${err.message}</p></div>`;
  }
}

// Initialize Page
window.onload = async () => {
  const loader = document.getElementById('loader');
  if (loader) loader.style.display = 'block';

  // Auth Verification
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    window.location.href = 'login.html';
    return;
  }

  // Load all tab datasets in parallel
  await Promise.all([
    loadAlerts(),
    loadWarnings(),
    loadInsights()
  ]);

  // Handle deep-linking navigation defaults
  checkDeepLink();

  if (loader) loader.style.display = 'none';
};
