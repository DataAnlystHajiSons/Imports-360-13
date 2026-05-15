-- ============================================================================
-- Missing Backend Function: stage_requirements_met
-- ============================================================================
-- This function is called by advance_stage but was missing from the backend.
-- It validates whether a shipment can advance to the specified stage.

CREATE OR REPLACE FUNCTION public.stage_requirements_met(
    p_shipment_id uuid,
    p_to_stage public.stage
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    -- Variables for validation
    v_current_year integer;
    v_product_variety_id uuid;
    v_forecast_exists boolean;
    v_enlistment_status boolean;
    v_stage_checklist_done boolean;
    v_previous_stage public.stage;
    v_previous_stage_done boolean;
BEGIN
    -- Get current year
    v_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    
    -- Get the first product variety from shipment (for multi-product support later)
    SELECT sp.product_variety_id INTO v_product_variety_id
    FROM public.shipment_products sp
    WHERE sp.shipment_id = p_shipment_id
    LIMIT 1;
    
    -- If no product variety found, cannot validate requirements
    IF v_product_variety_id IS NULL THEN
        RETURN false;
    END IF;
    
    -- Stage-specific requirements validation
    CASE p_to_stage
        -- =================================================================
        -- FORECAST STAGE: Always allow (starting stage)
        -- =================================================================
        WHEN 'forecast' THEN
            RETURN true;
            
        -- =================================================================
        -- ENLISTMENT VERIFICATION STAGE
        -- Requirement: Product must exist in forecast table for current year
        -- =================================================================
        WHEN 'enlistment_verification' THEN
            SELECT EXISTS(
                SELECT 1 FROM public.forecast f
                WHERE f.product_variety_id = v_product_variety_id
                AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
            ) INTO v_forecast_exists;
            
            RETURN v_forecast_exists;
            
        -- =================================================================
        -- AVAILABILITY CONFIRMATION STAGE  
        -- Requirement: enlistment_status must be true in forecast table
        -- =================================================================
        WHEN 'availability_confirmation' THEN
            SELECT COALESCE(f.enlistment_status, false) INTO v_enlistment_status
            FROM public.forecast f
            WHERE f.product_variety_id = v_product_variety_id
            AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
            LIMIT 1;
            
            RETURN v_enlistment_status;
            
        -- =================================================================
        -- ALL OTHER STAGES: Check if previous stage is completed
        -- Uses the v_shipment_stage_checklist view for validation
        -- =================================================================
        WHEN 'purchase_order' THEN
            -- Check if availability_confirmation is done
            SELECT COALESCE(availability_confirmation_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'proforma' THEN
            -- Check if purchase_order is done
            SELECT COALESCE(purchase_order_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'invoice' THEN
            -- Check if proforma is done
            SELECT COALESCE(proforma_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'ip_number' THEN
            -- Check if invoice is done
            SELECT COALESCE(invoice_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'lc_opening' THEN
            -- Check if ip_number is done
            SELECT COALESCE(ip_number_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'lc_shared_with_supplier' THEN
            -- Check if lc_opening is done
            SELECT COALESCE(lc_opening_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'shipment_details_from_supplier' THEN
            -- Check if lc_shared_with_supplier is done
            SELECT COALESCE(lc_shared_with_supplier_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'freight_query' THEN
            -- Check if shipment_details_from_supplier is done
            SELECT COALESCE(shipment_details_from_supplier_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'award_shipment' THEN
            -- Check if freight_query is done
            SELECT COALESCE(freight_query_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'non_negotiable_docs' THEN
            -- Check if award_shipment is done
            SELECT COALESCE(award_shipment_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'original_docs' THEN
            -- Check if non_negotiable_docs is done
            SELECT COALESCE(non_negotiable_docs_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'bank_endorsement' THEN
            -- Check if original_docs is done
            SELECT COALESCE(original_docs_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'send_to_clearing_agent' THEN
            -- Check if bank_endorsement is done
            SELECT COALESCE(bank_endorsement_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'under_clearing_agent' THEN
            -- Check if send_to_clearing_agent is done
            SELECT COALESCE(send_to_clearing_agent_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'release_orders' THEN
            -- Check if under_clearing_agent is done
            SELECT COALESCE(under_clearing_agent_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'gate_out' THEN
            -- Check if release_orders is done
            SELECT COALESCE(release_orders_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'transportation' THEN
            -- Check if gate_out is done
            SELECT COALESCE(gate_out_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'warehouse' THEN
            -- Check if transportation is done
            SELECT COALESCE(transportation_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        WHEN 'bills' THEN
            -- Check if warehouse is done
            SELECT COALESCE(warehouse_done, false) INTO v_previous_stage_done
            FROM public.v_shipment_stage_checklist
            WHERE shipment_id = p_shipment_id;
            
            RETURN v_previous_stage_done;
            
        -- =================================================================
        -- DEFAULT: Unknown stage
        -- =================================================================
        ELSE
            -- For unknown stages, return false to prevent progression
            RETURN false;
    END CASE;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return false for safety
        RAISE WARNING 'Error in stage_requirements_met for shipment % to stage %: %', 
                     p_shipment_id, p_to_stage, SQLERRM;
        RETURN false;
END;
$$;

-- ============================================================================
-- Add helpful comments for documentation
-- ============================================================================
COMMENT ON FUNCTION public.stage_requirements_met(uuid, public.stage) IS 
'Validates whether a shipment can advance to the specified stage. 
- forecast: Always allowed (starting stage)
- enlistment_verification: Requires product in forecast table for current year
- availability_confirmation: Requires enlistment_status = true in forecast
- All other stages: Requires previous stage to be completed (checked via v_shipment_stage_checklist)';

-- ============================================================================
-- Grant necessary permissions (adjust as needed for your setup)
-- ============================================================================
-- GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO authenticated;
-- GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO service_role;