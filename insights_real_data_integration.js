// ================================================
// REAL DATA INTEGRATION FOR INSIGHTS SECTION
// Replace the static content in admin-dashboard.html
// ================================================

// Load real alerts data
async function loadAlertsData() {
  try {
    const { data, error } = await supabase.rpc('get_critical_alerts');
    
    if (error) {
      console.error('Error loading alerts:', error);
      return;
    }
    
    updateAlertsUI(data || []);
    document.getElementById('alerts-count').textContent = data?.length || 0;
  } catch (err) {
    console.error('Failed to load alerts:', err);
  }
}

// Load real warnings data  
async function loadWarningsData() {
  try {
    const { data, error } = await supabase.rpc('get_business_warnings');
    
    if (error) {
      console.error('Error loading warnings:', error);
      return;
    }
    
    updateWarningsUI(data || []);
    document.getElementById('warnings-count').textContent = data?.length || 0;
  } catch (err) {
    console.error('Failed to load warnings:', err);
  }
}

// Load real insights data
async function loadInsightsData() {
  try {
    const { data, error } = await supabase.rpc('get_business_insights');
    
    if (error) {
      console.error('Error loading insights:', error);
      return;
    }
    
    updateInsightsUI(data || []);
    document.getElementById('insights-count').textContent = data?.length || 0;
  } catch (err) {
    console.error('Failed to load insights:', err);
  }
}

// Update alerts UI with real data
function updateAlertsUI(alerts) {
  const container = document.getElementById('alerts-content');
  container.innerHTML = '';
  
  if (alerts.length === 0) {
    container.innerHTML = `
      <div class="insight-item">
        <div class="item-icon positive">
          <i class="fas fa-check-circle"></i>
        </div>
        <div class="item-content">
          <p class="item-title">No critical alerts</p>
          <p class="item-subtitle">All shipments are on track</p>
        </div>
      </div>
    `;
    return;
  }
  
  alerts.forEach(alert => {
    const item = document.createElement('div');
    item.className = 'insight-item';
    item.innerHTML = `
      <div class="item-icon ${alert.priority}">
        <i class="fas fa-circle"></i>
      </div>
      <div class="item-content">
        <p class="item-title">${alert.title}</p>
        <p class="item-subtitle">${alert.subtitle}</p>
      </div>
      <div class="item-action">
        <button class="action-link" onclick="handleAlertAction('${alert.type}', '${alert.reference_code}')">
          ${alert.reference_code ? 'View' : 'Details'}
        </button>
      </div>
    `;
    container.appendChild(item);
  });
}

// Update warnings UI with real data
function updateWarningsUI(warnings) {
  const container = document.getElementById('warnings-content');
  container.innerHTML = '';
  
  if (warnings.length === 0) {
    container.innerHTML = `
      <div class="insight-item">
        <div class="item-icon positive">
          <i class="fas fa-check-circle"></i>
        </div>
        <div class="item-content">
          <p class="item-title">No warnings</p>
          <p class="item-subtitle">All systems operating normally</p>
        </div>
      </div>
    `;
    return;
  }
  
  warnings.forEach(warning => {
    const item = document.createElement('div');
    item.className = 'insight-item';
    item.innerHTML = `
      <div class="item-icon warning">
        <i class="fas fa-circle"></i>
      </div>
      <div class="item-content">
        <p class="item-title">${warning.title}</p>
        <p class="item-subtitle">${warning.subtitle}</p>
      </div>
      <div class="item-action">
        <button class="action-link" onclick="handleWarningAction('${warning.type}', '${warning.reference_code}')">
          Details
        </button>
      </div>
    `;
    container.appendChild(item);
  });
}

// Update insights UI with real data
function updateInsightsUI(insights) {
  const container = document.getElementById('insights-content');
  container.innerHTML = '';
  
  if (insights.length === 0) {
    container.innerHTML = `
      <div class="insight-item">
        <div class="item-icon neutral">
          <i class="fas fa-chart-line"></i>
        </div>
        <div class="item-content">
          <p class="item-title">Gathering insights</p>
          <p class="item-subtitle">More data needed for analysis</p>
        </div>
      </div>
    `;
    return;
  }
  
  insights.forEach(insight => {
    const item = document.createElement('div');
    item.className = 'insight-item';
    item.innerHTML = `
      <div class="item-icon ${insight.priority}">
        <i class="fas fa-circle"></i>
      </div>
      <div class="item-content">
        <p class="item-title">${insight.title}</p>
        <p class="item-subtitle">${insight.subtitle}</p>
      </div>
      <div class="item-action">
        <button class="action-link" onclick="handleInsightAction('${insight.type}', '${insight.reference_code}')">
          ${getInsightActionLabel(insight.type)}
        </button>
      </div>
    `;
    container.appendChild(item);
  });
}

// Get appropriate action label for insights
function getInsightActionLabel(type) {
  switch(type) {
    case 'performance': return 'Report';
    case 'top_supplier': return 'View';
    case 'seasonal': return 'Plan';
    default: return 'Explore';
  }
}

// Handle alert actions
function handleAlertAction(type, referenceCode) {
  switch(type) {
    case 'overdue':
      if (referenceCode) {
        // Navigate to specific shipment
        window.location.href = `shipment-details.html?ref=${referenceCode}`;
      }
      break;
    case 'lc_expiring':
      if (referenceCode) {
        // Navigate to shipment with LC details
        window.location.href = `shipment-details.html?ref=${referenceCode}&focus=lc`;
      }
      break;
    case 'pending_docs':
      // Filter shipments by documentation stage
      document.getElementById('shipment-search').value = '';
      const stageFilter = document.getElementById('status-filter');
      if (stageFilter) {
        stageFilter.value = 'active';
      }
      loadShipments('', { status: 'active' });
      showNotification('Filtered shipments requiring documentation', 'info');
      break;
    default:
      showNotification('Opening detailed alert information', 'info');
  }
}

// Handle warning actions
function handleWarningAction(type, referenceCode) {
  switch(type) {
    case 'supplier_capacity':
      window.location.href = 'supplier-details.html';
      break;
    case 'stage_bottleneck':
      // Filter shipments by active status to show bottlenecks
      document.getElementById('shipment-search').value = '';
      loadShipments('', { status: 'active' });
      showNotification('Showing active shipments to identify bottlenecks', 'info');
      break;
    case 'missing_details':
      // Filter to show shipments needing supplier details
      document.getElementById('shipment-search').value = 'supplier details';
      loadShipments('supplier details', { status: 'active' });
      showNotification('Showing shipments needing supplier details', 'info');
      break;
    default:
      showNotification('Opening detailed warning analysis', 'info');
  }
}

// Handle insight actions
function handleInsightAction(type, referenceCode) {
  switch(type) {
    case 'performance':
      // Could open performance dashboard or show detailed metrics
      showNotification('Opening performance analytics dashboard', 'info');
      break;
    case 'top_supplier':
      window.location.href = 'supplier-details.html';
      break;
    case 'seasonal':
      // Could open forecasting or planning tools
      showNotification('Opening seasonal planning dashboard', 'info');
      break;
    default:
      showNotification('Opening detailed insights analysis', 'info');
  }
}

// Enhanced view all functions with real data context
function viewAllAlerts() {
  // Could navigate to a dedicated alerts page or filter current view
  document.getElementById('shipment-search').value = '';
  loadShipments('', { status: 'active' });
  showNotification('Showing all active shipments for alert analysis', 'info');
}

function viewAllWarnings() {
  // Could navigate to a dedicated warnings dashboard
  showNotification('Opening comprehensive warnings dashboard', 'info');
}

function viewAllInsights() {
  // Could navigate to a business intelligence dashboard
  showNotification('Opening business insights dashboard', 'info');
}

// Initialize real data loading for insights section
async function initializeInsightsSection() {
  try {
    // Show loading state
    document.querySelectorAll('.insight-count').forEach(el => {
      el.textContent = '...';
    });
    
    // Load all data in parallel
    await Promise.all([
      loadAlertsData(),
      loadWarningsData(),
      loadInsightsData()
    ]);
    
    console.log('Insights section loaded with real data');
  } catch (error) {
    console.error('Failed to initialize insights section:', error);
    
    // Show error state
    document.querySelectorAll('.insight-count').forEach(el => {
      el.textContent = '!';
    });
  }
}

// Real-time updates for insights
function setupInsightsRealTimeUpdates() {
  // Refresh insights every 5 minutes
  setInterval(initializeInsightsSection, 5 * 60 * 1000);
  
  // Listen for real-time changes on shipments
  supabase
    .channel('shipments-insights')
    .on('postgres_changes', 
      { event: '*', schema: 'public', table: 'shipment' }, 
      (payload) => {
        console.log('Shipment change detected, refreshing insights...');
        // Debounce the refresh to avoid too many calls
        clearTimeout(window.insightsRefreshTimeout);
        window.insightsRefreshTimeout = setTimeout(initializeInsightsSection, 2000);
      }
    )
    .on('postgres_changes', 
      { event: '*', schema: 'public', table: 'letter_of_credit' }, 
      (payload) => {
        console.log('LC change detected, refreshing alerts...');
        clearTimeout(window.alertsRefreshTimeout);
        window.alertsRefreshTimeout = setTimeout(loadAlertsData, 1000);
      }
    )
    .subscribe();
}

// Enhanced notification system for insights
function showInsightNotification(message, type = 'info', action = null) {
  const notification = document.createElement('div');
  notification.className = `notification notification-${type}`;
  
  let actionButton = '';
  if (action) {
    actionButton = `<button onclick="${action.handler}" style="margin-left: 10px; padding: 4px 8px; background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.3); border-radius: 4px; color: inherit; cursor: pointer;">${action.label}</button>`;
  }
  
  notification.innerHTML = `
    <div class="notification-content">
      <i class="fas ${type === 'info' ? 'fa-info-circle' : type === 'success' ? 'fa-check-circle' : 'fa-exclamation-triangle'}"></i>
      <span>${message}</span>
      ${actionButton}
    </div>
  `;
  
  document.body.appendChild(notification);
  
  // Animate in
  setTimeout(() => notification.classList.add('show'), 100);
  
  // Auto remove after 5 seconds (longer for actionable notifications)
  setTimeout(() => {
    notification.classList.remove('show');
    setTimeout(() => notification.remove(), 300);
  }, action ? 8000 : 4000);
}

// Export functions for global access
window.initializeInsightsSection = initializeInsightsSection;
window.setupInsightsRealTimeUpdates = setupInsightsRealTimeUpdates;
window.handleAlertAction = handleAlertAction;
window.handleWarningAction = handleWarningAction;
window.handleInsightAction = handleInsightAction;
window.viewAllAlerts = viewAllAlerts;
window.viewAllWarnings = viewAllWarnings;
window.viewAllInsights = viewAllInsights;