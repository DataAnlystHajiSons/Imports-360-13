# 🚀 Real Data Integration Plan for Insights Section

## 📊 **Database Analysis for Insights**

Based on your schema, here's how to make the Alerts, Warnings, and Insights section fully data-driven:

## 🚨 **ALERTS Section - Critical Issues**

### **1. Overdue Shipments**
```sql
-- Query: Shipments that have exceeded expected duration
SELECT 
  s.reference_code,
  s.current_stage,
  s.created_at,
  sd.expected_duration_days,
  EXTRACT(DAY FROM (NOW() - s.created_at)) as days_elapsed,
  sup.name as supplier_name
FROM shipment s
JOIN stage_details sd ON s.current_stage = sd.stage_name
LEFT JOIN shipment_products sp ON s.id = sp.shipment_id
LEFT JOIN product_variety pv ON sp.product_variety_id = pv.id
LEFT JOIN supplier sup ON pv.supplier_id = sup.id
WHERE 
  s.status = 'active' 
  AND EXTRACT(DAY FROM (NOW() - s.created_at)) > sd.expected_duration_days
ORDER BY days_elapsed DESC
LIMIT 5;
```

### **2. Expiring Letters of Credit**
```sql
-- Query: LCs expiring within next 7 days
SELECT 
  lc.lc_number,
  s.reference_code,
  bc.lc_issuance_date,
  bc.lc_issuance_date + INTERVAL '30 days' as expiry_date,
  EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) as days_remaining
FROM letter_of_credit lc
JOIN shipment s ON lc.shipment_id = s.id
JOIN bank_charges bc ON s.id = bc.shipment_id
WHERE 
  bc.lc_issuance_date + INTERVAL '30 days' <= NOW() + INTERVAL '7 days'
  AND s.status = 'active'
ORDER BY days_remaining ASC
LIMIT 5;
```

### **3. Pending Documentation**
```sql
-- Query: Shipments missing required documents
SELECT 
  s.reference_code,
  s.current_stage,
  COUNT(d.id) as doc_count,
  sd.responsible_team
FROM shipment s
LEFT JOIN document d ON s.id = d.shipment_id
JOIN stage_details sd ON s.current_stage = sd.stage_name
WHERE 
  s.status = 'active'
  AND s.current_stage IN ('non_negotiable_docs', 'original_docs', 'send_to_clearing_agent')
GROUP BY s.id, s.reference_code, s.current_stage, sd.responsible_team
HAVING COUNT(d.id) = 0
ORDER BY s.created_at ASC
LIMIT 5;
```

## ⚠️ **WARNINGS Section - Proactive Monitoring**

### **1. Supplier Capacity Warnings**
```sql
-- Query: Suppliers with high shipment volume
SELECT 
  sup.name,
  COUNT(DISTINCT s.id) as active_shipments,
  COUNT(DISTINCT s.id) * 100.0 / 10 as capacity_percentage -- Assuming 10 is max capacity
FROM supplier sup
JOIN product_variety pv ON sup.id = pv.supplier_id
JOIN shipment_products sp ON pv.id = sp.product_variety_id
JOIN shipment s ON sp.shipment_id = s.id
WHERE s.status = 'active'
GROUP BY sup.id, sup.name
HAVING COUNT(DISTINCT s.id) >= 8 -- 80% capacity threshold
ORDER BY active_shipments DESC
LIMIT 5;
```

### **2. Stage Bottlenecks**
```sql
-- Query: Stages with too many shipments
SELECT 
  s.current_stage,
  sd.responsible_team,
  COUNT(*) as shipment_count,
  sd.expected_duration_days,
  AVG(EXTRACT(DAY FROM (NOW() - s.updated_at))) as avg_days_in_stage
FROM shipment s
JOIN stage_details sd ON s.current_stage = sd.stage_name
WHERE s.status = 'active'
GROUP BY s.current_stage, sd.responsible_team, sd.expected_duration_days
HAVING COUNT(*) > 5 -- More than 5 shipments in same stage
ORDER BY shipment_count DESC
LIMIT 5;
```

### **3. Missing Shipment Details**
```sql
-- Query: Shipments without supplier details
SELECT 
  s.reference_code,
  s.current_stage,
  sup.name as supplier_name,
  ssd.readiness_date
FROM shipment s
JOIN shipment_products sp ON s.id = sp.shipment_id
JOIN product_variety pv ON sp.product_variety_id = pv.id
JOIN supplier sup ON pv.supplier_id = sup.id
LEFT JOIN supplier_shipment_details ssd ON s.id = ssd.shipment_id
WHERE 
  s.status = 'active'
  AND s.current_stage = 'shipment_details_from_supplier'
  AND ssd.id IS NULL
ORDER BY s.created_at ASC
LIMIT 5;
```

## 💡 **INSIGHTS Section - Business Intelligence**

### **1. Performance Trends**
```sql
-- Query: Monthly shipment completion trends
SELECT 
  DATE_TRUNC('month', s.updated_at) as month,
  COUNT(*) as completed_shipments,
  AVG(EXTRACT(DAY FROM (s.updated_at - s.created_at))) as avg_completion_days
FROM shipment s
WHERE 
  s.status = 'completed'
  AND s.updated_at >= NOW() - INTERVAL '6 months'
GROUP BY DATE_TRUNC('month', s.updated_at)
ORDER BY month DESC
LIMIT 3;
```

### **2. Top Performing Suppliers**
```sql
-- Query: Suppliers with best performance
SELECT 
  sup.name,
  COUNT(DISTINCT s.id) as total_shipments,
  COUNT(DISTINCT CASE WHEN s.status = 'completed' THEN s.id END) as completed_shipments,
  ROUND(COUNT(DISTINCT CASE WHEN s.status = 'completed' THEN s.id END) * 100.0 / COUNT(DISTINCT s.id), 2) as completion_rate
FROM supplier sup
JOIN product_variety pv ON sup.id = pv.supplier_id
JOIN shipment_products sp ON pv.id = sp.product_variety_id
JOIN shipment s ON sp.shipment_id = s.id
WHERE s.created_at >= NOW() - INTERVAL '3 months'
GROUP BY sup.id, sup.name
HAVING COUNT(DISTINCT s.id) >= 3
ORDER BY completion_rate DESC
LIMIT 5;
```

### **3. Cost Analysis**
```sql
-- Query: Average costs by shipment stage
SELECT 
  s.current_stage,
  COUNT(*) as shipment_count,
  AVG(bc.usd_amount) as avg_usd_amount,
  AVG(bc.rs) as avg_rs_amount
FROM shipment s
LEFT JOIN bank_charges bc ON s.id = bc.shipment_id
WHERE bc.usd_amount IS NOT NULL
GROUP BY s.current_stage
ORDER BY avg_usd_amount DESC
LIMIT 5;
```

## 🛠️ **Implementation Steps**

### **Step 1: Create Database Functions**

Create these PostgreSQL functions in your Supabase database:

```sql
-- Function to get critical alerts
CREATE OR REPLACE FUNCTION get_critical_alerts()
RETURNS TABLE (
  type text,
  title text,
  subtitle text,
  reference_code text,
  priority text,
  created_at timestamp with time zone
) AS $$
BEGIN
  RETURN QUERY
  -- Overdue shipments
  SELECT 
    'overdue' as type,
    'Shipment ' || s.reference_code || ' overdue' as title,
    'Expected delivery: ' || EXTRACT(DAY FROM (NOW() - s.created_at)) || ' days ago' as subtitle,
    s.reference_code,
    CASE 
      WHEN EXTRACT(DAY FROM (NOW() - s.created_at)) > 7 THEN 'critical'
      WHEN EXTRACT(DAY FROM (NOW() - s.created_at)) > 3 THEN 'high'
      ELSE 'medium'
    END as priority,
    s.created_at
  FROM shipment s
  JOIN stage_details sd ON s.current_stage = sd.stage_name
  WHERE 
    s.status = 'active' 
    AND EXTRACT(DAY FROM (NOW() - s.created_at)) > sd.expected_duration_days
  ORDER BY EXTRACT(DAY FROM (NOW() - s.created_at)) DESC
  LIMIT 3
  
  UNION ALL
  
  -- Expiring LCs
  SELECT 
    'lc_expiring' as type,
    'LC expiring in ' || EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) || ' days' as title,
    lc.lc_number || ' requires attention' as subtitle,
    s.reference_code,
    CASE 
      WHEN EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) <= 2 THEN 'critical'
      WHEN EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) <= 5 THEN 'high'
      ELSE 'medium'
    END as priority,
    bc.created_at
  FROM letter_of_credit lc
  JOIN shipment s ON lc.shipment_id = s.id
  JOIN bank_charges bc ON s.id = bc.shipment_id
  WHERE 
    bc.lc_issuance_date + INTERVAL '30 days' <= NOW() + INTERVAL '7 days'
    AND s.status = 'active'
  ORDER BY EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) ASC
  LIMIT 2;
END;
$$ LANGUAGE plpgsql;

-- Function to get warnings
CREATE OR REPLACE FUNCTION get_business_warnings()
RETURNS TABLE (
  type text,
  title text,
  subtitle text,
  reference_code text,
  priority text,
  created_at timestamp with time zone
) AS $$
BEGIN
  RETURN QUERY
  -- Supplier capacity warnings
  SELECT 
    'supplier_capacity' as type,
    'Supplier availability low' as title,
    sup.name || ' capacity at ' || ROUND(COUNT(DISTINCT s.id) * 100.0 / 10, 0) || '%' as subtitle,
    '' as reference_code,
    'warning' as priority,
    MAX(s.created_at) as created_at
  FROM supplier sup
  JOIN product_variety pv ON sup.id = pv.supplier_id
  JOIN shipment_products sp ON pv.id = sp.product_variety_id
  JOIN shipment s ON sp.shipment_id = s.id
  WHERE s.status = 'active'
  GROUP BY sup.id, sup.name
  HAVING COUNT(DISTINCT s.id) >= 7
  ORDER BY COUNT(DISTINCT s.id) DESC
  LIMIT 2
  
  UNION ALL
  
  -- Stage bottlenecks
  SELECT 
    'stage_bottleneck' as type,
    'Stage bottleneck detected' as title,
    COUNT(*) || ' shipments in ' || REPLACE(s.current_stage, '_', ' ') as subtitle,
    '' as reference_code,
    'warning' as priority,
    MAX(s.updated_at) as created_at
  FROM shipment s
  WHERE s.status = 'active'
  GROUP BY s.current_stage
  HAVING COUNT(*) > 5
  ORDER BY COUNT(*) DESC
  LIMIT 3;
END;
$$ LANGUAGE plpgsql;

-- Function to get business insights
CREATE OR REPLACE FUNCTION get_business_insights()
RETURNS TABLE (
  type text,
  title text,
  subtitle text,
  reference_code text,
  priority text,
  created_at timestamp with time zone
) AS $$
BEGIN
  RETURN QUERY
  -- Performance improvements
  SELECT 
    'performance' as type,
    'Efficiency improved ' || ROUND(
      (COUNT(CASE WHEN s.updated_at >= NOW() - INTERVAL '1 month' THEN 1 END) * 100.0 / 
       NULLIF(COUNT(CASE WHEN s.updated_at >= NOW() - INTERVAL '2 months' AND s.updated_at < NOW() - INTERVAL '1 month' THEN 1 END), 0)) - 100, 0
    ) || '%' as title,
    'Processing time improved this month' as subtitle,
    '' as reference_code,
    'positive' as priority,
    MAX(s.updated_at) as created_at
  FROM shipment s
  WHERE s.status = 'completed'
  HAVING COUNT(*) > 0
  LIMIT 1
  
  UNION ALL
  
  -- Top suppliers
  SELECT 
    'top_supplier' as type,
    'Top performer: ' || sup.name as title,
    ROUND(COUNT(CASE WHEN s.status = 'completed' THEN 1 END) * 100.0 / COUNT(*), 0) || '% completion rate' as subtitle,
    '' as reference_code,
    'positive' as priority,
    MAX(s.created_at) as created_at
  FROM supplier sup
  JOIN product_variety pv ON sup.id = pv.supplier_id
  JOIN shipment_products sp ON pv.id = sp.product_variety_id
  JOIN shipment s ON sp.shipment_id = s.id
  WHERE s.created_at >= NOW() - INTERVAL '3 months'
  GROUP BY sup.id, sup.name
  HAVING COUNT(*) >= 3
  ORDER BY COUNT(CASE WHEN s.status = 'completed' THEN 1 END) * 100.0 / COUNT(*) DESC
  LIMIT 2;
END;
$$ LANGUAGE plpgsql;
```

### **Step 2: Update JavaScript Functions**

Replace the static data loading with these functions in your `admin-dashboard.html`:

```javascript
// Load real alerts data
async function loadAlertsData() {
  const { data, error } = await supabase.rpc('get_critical_alerts');
  
  if (error) {
    console.error('Error loading alerts:', error);
    return;
  }
  
  updateAlertsUI(data);
  document.getElementById('alerts-count').textContent = data.length;
}

// Load real warnings data  
async function loadWarningsData() {
  const { data, error } = await supabase.rpc('get_business_warnings');
  
  if (error) {
    console.error('Error loading warnings:', error);
    return;
  }
  
  updateWarningsUI(data);
  document.getElementById('warnings-count').textContent = data.length;
}

// Load real insights data
async function loadInsightsData() {
  const { data, error } = await supabase.rpc('get_business_insights');
  
  if (error) {
    console.error('Error loading insights:', error);
    return;
  }
  
  updateInsightsUI(data);
  document.getElementById('insights-count').textContent = data.length;
}

// Update UI functions
function updateAlertsUI(alerts) {
  const container = document.getElementById('alerts-content');
  container.innerHTML = '';
  
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
        <button class="action-link" onclick="viewShipment('${alert.reference_code}')">View</button>
      </div>
    `;
    container.appendChild(item);
  });
}

function updateWarningsUI(warnings) {
  const container = document.getElementById('warnings-content');
  container.innerHTML = '';
  
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
        <button class="action-link" onclick="handleWarningAction('${warning.type}')">Details</button>
      </div>
    `;
    container.appendChild(item);
  });
}

function updateInsightsUI(insights) {
  const container = document.getElementById('insights-content');
  container.innerHTML = '';
  
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
        <button class="action-link" onclick="handleInsightAction('${insight.type}')">Report</button>
      </div>
    `;
    container.appendChild(item);
  });
}

// Initialize real data loading
async function initializeInsightsSection() {
  await Promise.all([
    loadAlertsData(),
    loadWarningsData(), 
    loadInsightsData()
  ]);
}

// Call this in your main initialization
initializeInsightsSection();
```

### **Step 3: Add Real-time Updates**

```javascript
// Refresh insights every 5 minutes
setInterval(initializeInsightsSection, 5 * 60 * 1000);

// Listen for real-time changes
supabase
  .channel('shipments')
  .on('postgres_changes', 
    { event: '*', schema: 'public', table: 'shipment' }, 
    () => {
      // Refresh insights when shipments change
      initializeInsightsSection();
    }
  )
  .subscribe();
```

### **Step 4: Enhanced Navigation Functions**

```javascript
function handleWarningAction(type) {
  switch(type) {
    case 'supplier_capacity':
      window.location.href = 'supplier-details.html';
      break;
    case 'stage_bottleneck':
      // Filter shipments by problematic stage
      document.getElementById('shipment-search').value = '';
      loadShipments('', { status: 'active' });
      break;
    default:
      showNotification('Opening detailed analysis', 'info');
  }
}

function handleInsightAction(type) {
  switch(type) {
    case 'performance':
      // Could open a performance dashboard
      showNotification('Opening performance analytics', 'info');
      break;
    case 'top_supplier':
      window.location.href = 'supplier-details.html';
      break;
    default:
      showNotification('Opening detailed insights', 'info');
  }
}
```

## 🚀 **Implementation Priority**

### **Phase 1 (Immediate)**
1. Create the database functions in Supabase
2. Update JavaScript to load real data
3. Test with your existing data

### **Phase 2 (Next Week)**
1. Add real-time subscriptions
2. Enhance navigation based on data types
3. Add more sophisticated business rules

### **Phase 3 (Future)**
1. Machine learning insights
2. Predictive analytics
3. Custom alert thresholds

This implementation will make your Insights section fully dynamic and provide real business value by surfacing actual issues, bottlenecks, and opportunities from your shipment data.