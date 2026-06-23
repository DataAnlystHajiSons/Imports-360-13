/* insights-center.js - Shipment Centric Diagnostics Panel */

import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.43.4/+esm";

const supabase = createClient("https://sfknzqkiqxivzcualcau.supabase.co", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma256cWtpcXhpdnpjdWFsY2F1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3OTU0ODksImV4cCI6MjA3MjM3MTQ4OX0.JKjOS9NRdbVH1UanfqmBeHmMSnlWlZtDr-5LdKw5YaA");

const urlParams = new URLSearchParams(window.location.search);
const currentRef = urlParams.get('ref');
let shipmentData = null;

const STAGE_ORDER = [
  "forecast", "enlistment_verification", "availability_confirmation", "purchase_order", "proforma", 
  "ip_number", "lc_opening", "bank_debit_advice", "invoice", "shipment_details_from_supplier", 
  "freight_query", "award_shipment", "non_negotiable_docs", "bank_endorsement", "original_docs", 
  "send_to_clearing_agent", "good_declaration", "under_clearing_agent", "warehouse", "release_orders", 
  "gate_out", "transportation", "bills"
];

// Switch tabs inside Right Panel
window.switchTab = function(tabName) {
  document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
  const activeBtn = document.getElementById(`tab-${tabName}`);
  if (activeBtn) activeBtn.classList.add('active');

  document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
  const activePanel = document.getElementById(`content-${tabName}`);
  if (activePanel) activePanel.classList.add('active');

  const newUrl = window.location.pathname + `?ref=${currentRef}&tab=${tabName}`;
  window.history.pushState({ path: newUrl }, '', newUrl);
};

// Check query param for deep linking tabs
function checkDeepLink() {
  const tabParam = urlParams.get('tab');
  if (tabParam && ['alerts', 'warnings', 'insights'].includes(tabParam)) {
    switchTab(tabParam);
  }
}

// Convert stage key to Human-Readable Label
function formatStageLabel(stageKey) {
  const customLabels = {
    'proforma': 'Proforma Invoice',
    'invoice': 'Commercial Invoice',
    'lc_opening': 'LC Opening',
    'warehouse': 'Warehouse Arrival',
    'send_to_clearing_agent': 'Docs to Clearing Agent',
    'shipment_details_from_supplier': 'Shipment Details from Supplier',
    'bills': 'Costing Sheet / Bills'
  };
  if (customLabels[stageKey]) return customLabels[stageKey];
  return stageKey.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

// 1. Fetch details & render left panel timeline + computed bottleneck
async function runShipmentDiagnostics() {
  const timelineContainer = document.getElementById('timeline-list');
  try {
    // 1. Fetch shipment details from view
    const { data: viewData, error: viewError } = await supabase
      .from('v_shipments_with_all_details')
      .select('*')
      .eq('reference_code', currentRef);

    if (viewError) throw viewError;

    if (!viewData || viewData.length === 0) {
      document.getElementById('diagnostics-container').innerHTML = `
        <div class="empty-state">
          <i class="fas fa-search"></i>
          <h3>Shipment Not Found</h3>
          <p>The shipment reference code <strong>${currentRef || 'N/A'}</strong> could not be located in the database.</p>
        </div>`;
      return;
    }

    // Deduplicate view rows just in case
    shipmentData = viewData[0];

    // Populate header stats
    document.getElementById('header-ref').innerHTML = `<i class="fas fa-microscope"></i> Diagnostics & Investigation: ${shipmentData.reference_code}`;
    
    let productValue = 'N/A';
    let varietyValue = 'N/A';
    let supplierValue = 'N/A';
    if (shipmentData.product_variety && shipmentData.product_variety.length) {
        productValue = shipmentData.product_variety[0].product_name || 'N/A';
        varietyValue = shipmentData.product_variety[0].variety_name || 'N/A';
        supplierValue = shipmentData.product_variety[0].supplier?.name || 'N/A';
    }
    
    document.getElementById('meta-product').textContent = productValue;
    document.getElementById('meta-variety').textContent = varietyValue;
    document.getElementById('meta-supplier').textContent = supplierValue;
    document.getElementById('meta-progress').textContent = `${shipmentData.completed_milestones_count || 0}/${shipmentData.total_milestones_count || 23} milestones completed (${Math.round(((shipmentData.completed_milestones_count || 0) / (shipmentData.total_milestones_count || 23)) * 100)}%)`;

    // 2. Query target duration for current stage from database
    const { data: stageConfigs } = await supabase.from('stage_details').select('*');
    const currentStageConfig = stageConfigs?.find(cfg => cfg.stage_name === shipmentData.current_stage);
    const expectedDuration = currentStageConfig ? currentStageConfig.expected_duration_days : 5; // fallback to 5 days if missing

    // 3. Query audit log to find EXACT date they entered this stage
    const { data: auditLogs } = await supabase
      .from('audit_log')
      .select('at')
      .eq('shipment_id', shipmentData.id)
      .eq('to_stage', shipmentData.current_stage)
      .eq('action', 'advance_stage')
      .order('at', { ascending: false })
      .limit(1);

    const entryDate = auditLogs && auditLogs.length ? auditLogs[0].at : (shipmentData.latest_activity_at || shipmentData.created_at);
    
    // Compute stuck duration
    const today = new Date();
    const start = new Date(entryDate);
    const stuckDays = Math.floor((today - start) / (1000 * 60 * 60 * 24));

    // Render Timeline List
    const currentStageIndex = STAGE_ORDER.indexOf(shipmentData.current_stage);
    let timelineHtml = '';

    STAGE_ORDER.forEach((stageKey, idx) => {
        // We only render past stages and the current stage (hide future stages to keep view focused)
        if (idx > currentStageIndex) return;

        const isCompleted = idx < currentStageIndex;
        const isCurrent = idx === currentStageIndex;
        const isStuck = isCurrent && (stuckDays > expectedDuration);

        let stepClass = 'timeline-step';
        if (isCompleted) stepClass += ' completed';
        else if (isStuck) stepClass += ' bottleneck';
        else if (isCurrent) stepClass += ' current';

        let durationText = isCompleted ? 'Completed' : `${stuckDays} days in stage`;

        timelineHtml += `
          <div class="${stepClass}">
            <div class="step-header">
              <span class="step-title">${formatStageLabel(stageKey)}</span>
              <span class="step-duration">${durationText}</span>
            </div>
        `;

        if (isStuck) {
            timelineHtml += `
              <div class="bottleneck-box">
                <strong><i class="fas fa-exclamation-circle"></i> CRITICAL BOTTLENECK DETECTED</strong>
                This shipment has been stuck in the <strong>${formatStageLabel(stageKey)}</strong> stage for <strong>${stuckDays} days</strong>. 
                This violates the expected operational target of <strong>${expectedDuration} days</strong> for this stage.
                <p style="margin: 6px 0 0 0; font-size: 13px; color: #7f1d1d; opacity: 0.95;"><i class="fas fa-lightbulb"></i> Recommended Action: Review form inputs under Shipment Tracker or check required documents checklist.</p>
              </div>
            `;
        } else if (isCurrent) {
            timelineHtml += `
              <div style="background: var(--info-bg); border-left: 5px solid var(--info-color); border-radius: 8px; padding: 12px; margin-top: 10px; font-size: 14px; color: #1e40af;">
                <i class="fas fa-info-circle"></i> Active stage. Inside target threshold window (${stuckDays}/${expectedDuration} days elapsed).
              </div>
            `;
        }

        timelineHtml += `</div>`;
    });

    timelineContainer.innerHTML = timelineHtml;

  } catch (err) {
    console.error('Error running diagnostics:', err);
    timelineContainer.innerHTML = `<p class="error-message">Failed to calculate timeline diagnostics: ${err.message}</p>`;
  }
}

// 2. Fetch RPC cards and filter them by shipment reference
async function loadShipmentSpecificRPCCards() {
  const alertsContainer = document.getElementById('container-alerts');
  const warningsContainer = document.getElementById('container-warnings');
  const insightsContainer = document.getElementById('container-insights');

  try {
    // A. Load and filter Alerts
    const { data: alerts, error: alertsErr } = await supabase.rpc('get_critical_alerts');
    if (alertsErr) throw alertsErr;
    const shipmentAlerts = alerts?.filter(a => a.reference_code === currentRef) || [];
    document.getElementById('badge-alerts').textContent = shipmentAlerts.length;

    if (shipmentAlerts.length === 0) {
        alertsContainer.innerHTML = `
          <div class="empty-state">
            <i class="fas fa-check-circle" style="color: #10b981;"></i>
            <h3>No Critical Alerts</h3>
            <p>This shipment has no active overdue alarms or critical blocks.</p>
          </div>`;
    } else {
        alertsContainer.innerHTML = '';
        shipmentAlerts.forEach(a => {
            alertsContainer.innerHTML += `
              <div class="diagnostics-card ${a.priority || 'medium'}">
                <div class="card-icon"><i class="fas fa-exclamation-triangle"></i></div>
                <div class="card-content">
                  <h4>${a.title}</h4>
                  <p>${a.subtitle}</p>
                </div>
              </div>`;
        });
    }

    // B. Load and filter Warnings
    const { data: warnings, error: warningsErr } = await supabase.rpc('get_business_warnings');
    if (warningsErr) throw warningsErr;
    const shipmentWarnings = warnings?.filter(w => w.reference_code === currentRef) || [];
    document.getElementById('badge-warnings').textContent = shipmentWarnings.length;

    if (shipmentWarnings.length === 0) {
        warningsContainer.innerHTML = `
          <div class="empty-state">
            <i class="fas fa-shield-alt" style="color: #3b82f6;"></i>
            <h3>No Active Warnings</h3>
            <p>This shipment's operational details, capacities, and links are fully secure.</p>
          </div>`;
    } else {
        warningsContainer.innerHTML = '';
        shipmentWarnings.forEach(w => {
            warningsContainer.innerHTML += `
              <div class="diagnostics-card ${w.priority || 'medium'}">
                <div class="card-icon"><i class="fas fa-exclamation-circle"></i></div>
                <div class="card-content">
                  <h4>${w.title}</h4>
                  <p>${w.subtitle}</p>
                </div>
              </div>`;
        });
    }

    // C. Load and filter Insights
    const { data: insights, error: insightsErr } = await supabase.rpc('get_operational_insights');
    if (insightsErr) throw insightsErr;
    const shipmentInsights = insights?.filter(i => i.reference_code === currentRef) || [];
    document.getElementById('badge-insights').textContent = shipmentInsights.length;

    if (shipmentInsights.length === 0) {
        insightsContainer.innerHTML = `
          <div class="empty-state">
            <i class="fas fa-lightbulb" style="color: #f59e0b;"></i>
            <h3>No Optimization Suggestions</h3>
            <p>We have no custom operational recommendations for this shipment currently.</p>
          </div>`;
    } else {
        insightsContainer.innerHTML = '';
        shipmentInsights.forEach(i => {
            insightsContainer.innerHTML += `
              <div class="diagnostics-card info">
                <div class="card-icon"><i class="fas fa-lightbulb"></i></div>
                <div class="card-content">
                  <h4>${i.title}</h4>
                  <p>${i.subtitle}</p>
                </div>
              </div>`;
        });
    }

  } catch (err) {
     console.error('Error loading tab items:', err);
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

  if (!currentRef) {
    document.getElementById('diagnostics-container').innerHTML = `
      <div class="empty-state">
        <i class="fas fa-exclamation-circle" style="color: red;"></i>
        <h3>Missing Parameters</h3>
        <p>You must provide a shipment reference query param (e.g. <code>?ref=D-635</code>) to run the diagnostic dashboard.</p>
      </div>`;
    if (loader) loader.style.display = 'none';
    return;
  }

  // Load diagnostic timelines & related tab cards
  await Promise.all([
    runShipmentDiagnostics(),
    loadShipmentSpecificRPCCards()
  ]);

  // Handle deep-linking navigation defaults
  checkDeepLink();

  if (loader) loader.style.display = 'none';
};
