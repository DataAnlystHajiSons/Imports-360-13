const STAGE_CONFIG = require('./temp-config.js');

const STAGE_ORDER = [
  'forecast', 'enlistment_verification', 'availability_confirmation', 'purchase_order', 'proforma', 
  'ip_number', 'lc_opening', 'bank_debit_advice', 'invoice', 'shipment_details_from_supplier',
  'freight_query', 'award_shipment', 'non_negotiable_docs', 'bank_endorsement', 'original_docs', 
  'send_to_clearing_agent', 'good_declaration', 'under_clearing_agent', 'warehouse', 'release_orders', 
  'gate_out', 'transportation', 'documents', 'bills'
];

let sqlCases = [];

STAGE_ORDER.forEach(stageKey => {
    const config = STAGE_CONFIG[stageKey];
    if (!config) return;
    
    let table = config.table;
    
    // documents is a special stage
    if (stageKey === 'documents' || config.isDocumentStage) {
        sqlCases.push(`        (CASE WHEN EXISTS (SELECT 1 FROM public.document d WHERE d.shipment_id = s.id) THEN 1 ELSE 0 END)`);
        return;
    }
    
    let conditions = [];
    if (config.fields) {
        config.fields.forEach(field => {
            if (field.readonly || field.name === 'id' || field.name === 'shipment_id') return;
            
            // For text/string types, must not be empty string
            if (field.type === 'text' || field.type === 'textarea') {
                conditions.push(`t.${field.name} IS NOT NULL AND t.${field.name}::text <> ''`);
            } else {
                conditions.push(`t.${field.name} IS NOT NULL`);
            }
        });
    }
    
    if (conditions.length > 0) {
        let conditionStr = conditions.join(' AND ');
        if (stageKey === 'forecast') {
            sqlCases.push(`        (CASE WHEN EXISTS (SELECT 1 FROM public.${table} t JOIN public.shipment_products sp ON t.product_variety_id = sp.product_variety_id WHERE sp.shipment_id = s.id AND ${conditionStr}) THEN 1 ELSE 0 END)`);
        } else {
            sqlCases.push(`        (CASE WHEN EXISTS (SELECT 1 FROM public.${table} t WHERE t.shipment_id = s.id AND ${conditionStr}) THEN 1 ELSE 0 END)`);
        }
    } else {
        // If there are no fields to check, just check for existence
        if (stageKey === 'forecast') {
             sqlCases.push(`        (CASE WHEN EXISTS (SELECT 1 FROM public.${table} t JOIN public.shipment_products sp ON t.product_variety_id = sp.product_variety_id WHERE sp.shipment_id = s.id) THEN 1 ELSE 0 END)`);
        } else {
            sqlCases.push(`        (CASE WHEN EXISTS (SELECT 1 FROM public.${table} t WHERE t.shipment_id = s.id) THEN 1 ELSE 0 END)`);
        }
    }
});

console.log(sqlCases.join(' +\n'));
