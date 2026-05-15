-- ============================================================================
-- Test Script for Updated Shipment Completion Logic
-- ============================================================================
-- This script tests the new completion logic to ensure it works correctly
-- ============================================================================

-- Test Scenario 1: Shipment at 'bills' stage with per_unit_rate > 0
-- Expected: Should mark as completed
DO $$
DECLARE
    v_test_shipment_id uuid;
    v_shipment_status status;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST 1: Shipment at bills stage with per_unit_rate > 0';
    RAISE NOTICE '========================================';
    
    -- Get a shipment that is at 'bills' stage (or create a test one)
    SELECT id INTO v_test_shipment_id
    FROM public.shipment
    WHERE current_stage = 'bills'
    LIMIT 1;
    
    IF v_test_shipment_id IS NULL THEN
        RAISE NOTICE 'No shipment at bills stage found. Skipping test.';
    ELSE
        RAISE NOTICE 'Testing with shipment: %', v_test_shipment_id;
        
        -- Insert or update costing with per_unit_rate > 0
        INSERT INTO public.costing (shipment_id, per_unit_rate, total, total_cost, qty)
        VALUES (v_test_shipment_id, 100.50, 1000, 1200, 10)
        ON CONFLICT (shipment_id) 
        DO UPDATE SET per_unit_rate = 100.50, total = 1000, total_cost = 1200, qty = 10;
        
        -- Check if shipment is now completed
        SELECT status INTO v_shipment_status
        FROM public.shipment
        WHERE id = v_test_shipment_id;
        
        IF v_shipment_status = 'completed' THEN
            RAISE NOTICE '✅ TEST PASSED: Shipment marked as completed';
        ELSE
            RAISE WARNING '❌ TEST FAILED: Shipment status is %, expected completed', v_shipment_status;
        END IF;
    END IF;
END $$;

-- Test Scenario 2: Shipment NOT at 'bills' stage with per_unit_rate > 0
-- Expected: Should NOT mark as completed
DO $$
DECLARE
    v_test_shipment_id uuid;
    v_shipment_status status;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST 2: Shipment NOT at bills stage with per_unit_rate > 0';
    RAISE NOTICE '========================================';
    
    -- Get a shipment that is NOT at 'bills' stage
    SELECT id INTO v_test_shipment_id
    FROM public.shipment
    WHERE current_stage != 'bills'
    LIMIT 1;
    
    IF v_test_shipment_id IS NULL THEN
        RAISE NOTICE 'No shipment found that is not at bills stage. Skipping test.';
    ELSE
        RAISE NOTICE 'Testing with shipment: %', v_test_shipment_id;
        
        -- Insert or update costing with per_unit_rate > 0
        INSERT INTO public.costing (shipment_id, per_unit_rate, total, total_cost, qty)
        VALUES (v_test_shipment_id, 100.50, 1000, 1200, 10)
        ON CONFLICT (shipment_id) 
        DO UPDATE SET per_unit_rate = 100.50, total = 1000, total_cost = 1200, qty = 10;
        
        -- Check if shipment is still active
        SELECT status INTO v_shipment_status
        FROM public.shipment
        WHERE id = v_test_shipment_id;
        
        IF v_shipment_status != 'completed' THEN
            RAISE NOTICE '✅ TEST PASSED: Shipment NOT marked as completed (status: %)', v_shipment_status;
        ELSE
            RAISE WARNING '❌ TEST FAILED: Shipment was marked as completed when it should not be';
        END IF;
    END IF;
END $$;

-- Test Scenario 3: Shipment at 'bills' stage with per_unit_rate = 0
-- Expected: Should NOT mark as completed
DO $$
DECLARE
    v_test_shipment_id uuid;
    v_shipment_status status;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST 3: Shipment at bills stage with per_unit_rate = 0';
    RAISE NOTICE '========================================';
    
    -- Get a shipment that is at 'bills' stage
    SELECT id INTO v_test_shipment_id
    FROM public.shipment
    WHERE current_stage = 'bills'
    LIMIT 1;
    
    IF v_test_shipment_id IS NULL THEN
        RAISE NOTICE 'No shipment at bills stage found. Skipping test.';
    ELSE
        RAISE NOTICE 'Testing with shipment: %', v_test_shipment_id;
        
        -- Update shipment to active first (in case it was completed)
        UPDATE public.shipment
        SET status = 'active'
        WHERE id = v_test_shipment_id;
        
        -- Insert or update costing with per_unit_rate = 0
        INSERT INTO public.costing (shipment_id, per_unit_rate, total, total_cost, qty)
        VALUES (v_test_shipment_id, 0, 1000, 1200, 0)
        ON CONFLICT (shipment_id) 
        DO UPDATE SET per_unit_rate = 0, total = 1000, total_cost = 1200, qty = 0;
        
        -- Check if shipment is still active
        SELECT status INTO v_shipment_status
        FROM public.shipment
        WHERE id = v_test_shipment_id;
        
        IF v_shipment_status != 'completed' THEN
            RAISE NOTICE '✅ TEST PASSED: Shipment NOT marked as completed (status: %)', v_shipment_status;
        ELSE
            RAISE WARNING '❌ TEST FAILED: Shipment was marked as completed when per_unit_rate = 0';
        END IF;
    END IF;
END $$;

-- Test Scenario 4: Shipment at 'bills' stage with per_unit_rate NULL
-- Expected: Should NOT mark as completed
DO $$
DECLARE
    v_test_shipment_id uuid;
    v_shipment_status status;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST 4: Shipment at bills stage with per_unit_rate = NULL';
    RAISE NOTICE '========================================';
    
    -- Get a shipment that is at 'bills' stage
    SELECT id INTO v_test_shipment_id
    FROM public.shipment
    WHERE current_stage = 'bills'
    LIMIT 1;
    
    IF v_test_shipment_id IS NULL THEN
        RAISE NOTICE 'No shipment at bills stage found. Skipping test.';
    ELSE
        RAISE NOTICE 'Testing with shipment: %', v_test_shipment_id;
        
        -- Update shipment to active first
        UPDATE public.shipment
        SET status = 'active'
        WHERE id = v_test_shipment_id;
        
        -- Insert or update costing with per_unit_rate = NULL
        INSERT INTO public.costing (shipment_id, per_unit_rate, total, total_cost, qty)
        VALUES (v_test_shipment_id, NULL, 1000, 1200, 10)
        ON CONFLICT (shipment_id) 
        DO UPDATE SET per_unit_rate = NULL, total = 1000, total_cost = 1200, qty = 10;
        
        -- Check if shipment is still active
        SELECT status INTO v_shipment_status
        FROM public.shipment
        WHERE id = v_test_shipment_id;
        
        IF v_shipment_status != 'completed' THEN
            RAISE NOTICE '✅ TEST PASSED: Shipment NOT marked as completed (status: %)', v_shipment_status;
        ELSE
            RAISE WARNING '❌ TEST FAILED: Shipment was marked as completed when per_unit_rate = NULL';
        END IF;
    END IF;
END $$;

RAISE NOTICE '========================================';
RAISE NOTICE 'ALL TESTS COMPLETED';
RAISE NOTICE '========================================';
