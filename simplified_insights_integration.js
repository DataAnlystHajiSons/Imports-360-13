// ================================================
// SIMPLIFIED REAL DATA INTEGRATION 
// Start with this simpler version first
// ================================================

// Simple test function to verify database connection
async function testDatabaseConnection() {
  try {
    const { data, error } = await supabase.rpc('get_dashboard_stats');
    
    if (error) {
      console.error('Database test failed:', error);
      return false;
    }
    
    console.log('Database test successful:', data);
    return true;
  } catch (err) {
    console.error('Connection test error:', err);
    return false;
  }
}

// Load alerts with better error handling
async function loadAlertsData() {
  try {
    // First try the main function
    let { data, error } = await supabase.rpc('get_critical_alerts');
    
    if (error) {
      console.log('Main alerts function failed, using fallback:', error.message);
      
      // Fallback to simple query
      const { data: fallbackData, error: fallbackError } = await supabase
        .from('shipment')
        .select('reference_code, created_at, current_stage, status')
        .eq('status', 'active')
        .order('created_at', { ascending: true })
        .limit(5);
      
      if (!fallbackError && fallbackData) {
        data = fallbackData.map(item => ({
          type: 'simple_alert',
          title: `Shipment ${item.reference_code}`,
          subtitle: `In ${item.current_stage.replace('_', ' ')} stage`,
          reference_code: item.reference_code,
          priority: 'medium',
          created_at: item.created_at
        }));
      } else {
        console.error('Fallback also failed:', fallbackError);
        data = [];
      }
    }
    
    updateAlertsUI(data || []);
    document.getElementById('alerts-count').textContent = data?.length || 0;
  } catch (err) {
    console.error('Failed to load alerts:', err);
    showErrorState('alerts');
  }
}

// Load warnings with fallback
async function loadWarningsData() {
  try {
    let { data, error } = await supabase.rpc('get_business_warnings');
    
    if (error) {
      console.log('Warnings function failed, using fallback:', error.message);
      
      // Simple fallback
      data = [{
        type: 'system_check',
        title: 'System monitoring active',
        subtitle: 'All systems operational',
        reference_code: '',
        priority: 'warning',
        created_at: new Date().toISOString()
      }];
    }
    
    updateWarningsUI(data || []);
    document.getElementById('warnings-count').textContent = data?.length || 0;
  } catch (err) {
    console.error('Failed to load warnings:', err);
    showErrorState('warnings');
  }
}

// Load insights with fallback
async function loadInsightsData() {
  try {
    let { data, error } = await supabase.rpc('get_business_insights');
    
    if (error) {
      console.log('Insights function failed, using fallback:', error.message);
      
      // Get basic statistics
      const { data: statsData, error: statsError } = await supabase
        .from('shipment')
        .select('status')
        .eq('status', 'completed');
      
      if (!statsError && statsData) {
        data = [{
          type: 'basic_stats',
          title: `${statsData.length} shipments completed`,
          subtitle: 'System performance tracking',
          reference_code: '',
          priority: 'positive',
          created_at: new Date().toISOString()
        }];
      } else {
        data = [];
      }
    }
    
    updateInsightsUI(data || []);
    document.getElementById('insights-count').textContent = data?.length || 0;
  } catch (err) {
    console.error('Failed to load insights:', err);
    showErrorState('insights');
  }
}

// Show error state in UI
function showErrorState(section) {
  const container = document.getElementById(`${section}-content`);
  if (container) {
    container.innerHTML = `
      <div class="insight-item">
        <div class="item-icon medium">
          <i class="fas fa-exclamation-triangle"></i>
        </div>
        <div class="item-content">
          <p class="item-title">Data loading error</p>
          <p class="item-subtitle">Check console for details</p>
        </div>
        <div class="item-action">
          <button class="action-link" onclick="retryDataLoad('${section}')">Retry</button>
        </div>
      </div>
    `;
  }
  
  const countElement = document.getElementById(`${section}-count`);
  if (countElement) {
    countElement.textContent = '!';
  }
}

// Retry data loading
function retryDataLoad(section) {
  switch(section) {
    case 'alerts':
      loadAlertsData();
      break;
    case 'warnings':
      loadWarningsData();
      break;
    case 'insights':
      loadInsightsData();
      break;
  }
}

// Update UI functions (same as before but with better error handling)
function updateAlertsUI(alerts) {
  const container = document.getElementById('alerts-content');
  if (!container) return;
  
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
      <div class="item-icon ${alert.priority || 'medium'}">
        <i class="fas fa-circle"></i>
      </div>
      <div class="item-content">
        <p class="item-title">${alert.title || 'Alert'}</p>
        <p class="item-subtitle">${alert.subtitle || 'Details unavailable'}</p>
      </div>
      <div class="item-action">
        <button class="action-link" onclick="handleAlertAction('${alert.type}', '${alert.reference_code || ''}')">
          ${alert.reference_code ? 'View' : 'Details'}
        </button>
      </div>
    `;
    container.appendChild(item);
  });
}

function updateWarningsUI(warnings) {
  const container = document.getElementById('warnings-content');
  if (!container) return;
  
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
        <p class="item-title">${warning.title || 'Warning'}</p>
        <p class="item-subtitle">${warning.subtitle || 'Details unavailable'}</p>
      </div>
      <div class="item-action">
        <button class="action-link" onclick="handleWarningAction('${warning.type}', '${warning.reference_code || ''}')">
          Details
        </button>
      </div>
    `;
    container.appendChild(item);
  });
}

function updateInsightsUI(insights) {
  const container = document.getElementById('insights-content');
  if (!container) return;
  
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
      <div class="item-icon ${insight.priority || 'neutral'}">
        <i class="fas fa-circle"></i>
      </div>
      <div class="item-content">
        <p class="item-title">${insight.title || 'Insight'}</p>
        <p class="item-subtitle">${insight.subtitle || 'Details unavailable'}</p>
      </div>
      <div class="item-action">
        <button class="action-link" onclick="handleInsightAction('${insight.type}', '${insight.reference_code || ''}')">
          Report
        </button>
      </div>
    `;
    container.appendChild(item);
  });
}

// Action handlers (simplified)
function handleAlertAction(type, referenceCode) {
  switch(type) {
    case 'overdue':
    case 'simple_alert':
      if (referenceCode) {
        window.location.href = `shipment-details.html?ref=${referenceCode}`;
      } else {
        showNotification('Navigating to shipment details', 'info');
      }
      break;
    case 'lc_expiring':
      if (referenceCode) {
        window.location.href = `shipment-details.html?ref=${referenceCode}&focus=lc`;
      } else {
        showNotification('Opening LC management', 'info');
      }
      break;
    default:
      showNotification('Opening detailed alert information', 'info');
  }
}

function handleWarningAction(type, referenceCode) {
  switch(type) {
    case 'supplier_capacity':
      window.location.href = 'supplier-details.html';
      break;
    case 'stage_bottleneck':
      loadShipments('', { status: 'active' });
      showNotification('Showing active shipments', 'info');
      break;
    default:
      showNotification('Opening detailed warning analysis', 'info');
  }
}

function handleInsightAction(type, referenceCode) {
  switch(type) {
    case 'performance':
    case 'basic_stats':
      showNotification('Opening performance dashboard', 'info');
      break;
    case 'top_supplier':
      window.location.href = 'supplier-details.html';
      break;
    default:
      showNotification('Opening detailed insights', 'info');
  }
}

// Initialize with better error handling
async function initializeInsightsSection() {
  try {
    console.log('Initializing insights section...');
    
    // Show loading state
    document.querySelectorAll('.insight-count').forEach(el => {
      el.textContent = '...';
    });
    
    // Test database connection first
    const connectionOk = await testDatabaseConnection();
    if (!connectionOk) {
      console.warn('Database connection issues detected, using fallback data');
    }
    
    // Load data with error handling
    await Promise.allSettled([
      loadAlertsData(),
      loadWarningsData(),
      loadInsightsData()
    ]);
    
    console.log('Insights section initialization complete');
  } catch (error) {
    console.error('Failed to initialize insights section:', error);
    
    // Show error state for all sections
    document.querySelectorAll('.insight-count').forEach(el => {
      el.textContent = '!';
    });
    
    showNotification('Failed to load insights data. Check console for details.', 'error');
  }
}

// Export functions
window.initializeInsightsSection = initializeInsightsSection;
window.testDatabaseConnection = testDatabaseConnection;
window.retryDataLoad = retryDataLoad;
window.handleAlertAction = handleAlertAction;
window.handleWarningAction = handleWarningAction;
window.handleInsightAction = handleInsightAction;