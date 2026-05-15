-- ========================================================================
-- Migration: Update stage_edge table for new workflow
-- Purpose: Reflect merged LC stage and prepare for CFR skip logic
-- ========================================================================

-- Step 1: Remove old LC stage edges
DELETE FROM public.stage_edge 
WHERE from_stage = 'lc_opening'::stage 
AND to_stage = 'lc_shared_with_supplier'::stage;

DELETE FROM public.stage_edge 
WHERE from_stage = 'lc_shared_with_supplier'::stage 
AND to_stage = 'invoice'::stage;

-- Step 2: Add direct edge from lc_opening to invoice
INSERT INTO public.stage_edge (from_stage, to_stage)
VALUES ('lc_opening'::stage, 'invoice'::stage)
ON CONFLICT (from_stage, to_stage) DO NOTHING;

-- Step 3: Verify the complete updated workflow
-- The workflow should now be:
-- forecast → enlistment_verification → availability_confirmation → proforma → 
-- purchase_order → ip_number → lc_opening → invoice → 
-- shipment_details_from_supplier → freight_query → award_shipment → 
-- original_docs → non_negotiable_docs → bank_endorsement → 
-- send_to_clearing_agent → under_clearing_agent → release_orders → 
-- gate_out → transportation → warehouse → bills

-- Display the current stage flow for verification
WITH RECURSIVE stage_flow AS (
  SELECT 
    from_stage::text as stage, 
    to_stage::text as next_stage,
    1 as level
  FROM public.stage_edge
  WHERE from_stage = 'forecast'::stage
  
  UNION ALL
  
  SELECT 
    se.from_stage::text, 
    se.to_stage::text,
    sf.level + 1
  FROM public.stage_edge se
  JOIN stage_flow sf ON se.from_stage::text = sf.next_stage
  WHERE sf.level < 25  -- Prevent infinite loops
)
SELECT 
  level as stage_order,
  stage as current_stage,
  next_stage
FROM stage_flow
ORDER BY level;

-- Note: Stages shipment_details_from_supplier, freight_query, and award_shipment
-- will be auto-skipped by stage_requirements_met() function when inco_term = 'CFR'

-- Migration completed
SELECT 'Stage edges updated successfully for merged LC workflow' as migration_status;
