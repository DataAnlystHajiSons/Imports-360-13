-- ============================================================================
-- SQL Script to Add Multiple Columns to Supplier Shipment Details
-- ============================================================================
-- This script adds new columns to the supplier_shipment_details table:
-- - inco_terms (Incoterms)
-- - address (Supplier address)
-- - origin (Origin location)
-- - container_type (carton/pallet)
-- - net_weight (Net weight)
-- Note: gross_weight already exists in the schema
-- ============================================================================

-- Step 1: Add the inco_terms column
-- ============================================================================

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'supplier_shipment_details' 
        AND column_name = 'inco_terms'
    ) THEN
        ALTER TABLE public.supplier_shipment_details 
        ADD COLUMN inco_terms TEXT;
        
        RAISE NOTICE 'Column inco_terms added successfully';
    ELSE
        RAISE NOTICE 'Column inco_terms already exists';
    END IF;
END $$;

-- Step 2: Add the address column
-- ============================================================================

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'supplier_shipment_details' 
        AND column_name = 'address'
    ) THEN
        ALTER TABLE public.supplier_shipment_details 
        ADD COLUMN address TEXT;
        
        RAISE NOTICE 'Column address added successfully';
    ELSE
        RAISE NOTICE 'Column address already exists';
    END IF;
END $$;

-- Step 3: Add the origin column
-- ============================================================================

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'supplier_shipment_details' 
        AND column_name = 'origin'
    ) THEN
        ALTER TABLE public.supplier_shipment_details 
        ADD COLUMN origin TEXT;
        
        RAISE NOTICE 'Column origin added successfully';
    ELSE
        RAISE NOTICE 'Column origin already exists';
    END IF;
END $$;

-- Step 4: Add the container_type column
-- ============================================================================

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'supplier_shipment_details' 
        AND column_name = 'container_type'
    ) THEN
        ALTER TABLE public.supplier_shipment_details 
        ADD COLUMN container_type TEXT;
        
        RAISE NOTICE 'Column container_type added successfully';
    ELSE
        RAISE NOTICE 'Column container_type already exists';
    END IF;
END $$;

-- Step 5: Add the net_weight column
-- ============================================================================

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'supplier_shipment_details' 
        AND column_name = 'net_weight'
    ) THEN
        ALTER TABLE public.supplier_shipment_details 
        ADD COLUMN net_weight NUMERIC;
        
        RAISE NOTICE 'Column net_weight added successfully';
    ELSE
        RAISE NOTICE 'Column net_weight already exists';
    END IF;
END $$;

-- Step 6: Add check constraints
-- ============================================================================

DO $$
BEGIN
    -- Drop inco_terms constraint if it exists (for re-running the script)
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'supplier_shipment_details_inco_terms_check'
        AND table_name = 'supplier_shipment_details'
    ) THEN
        ALTER TABLE public.supplier_shipment_details 
        DROP CONSTRAINT supplier_shipment_details_inco_terms_check;
        RAISE NOTICE 'Existing inco_terms constraint dropped';
    END IF;
    
    -- Add the inco_terms check constraint
    ALTER TABLE public.supplier_shipment_details 
    ADD CONSTRAINT supplier_shipment_details_inco_terms_check 
    CHECK (inco_terms IN ('EXW', 'FOB', 'CFR', 'DDP', 'FCA', 'CPT'));
    
    RAISE NOTICE 'Inco_terms check constraint added successfully';
END $$;

DO $$
BEGIN
    -- Drop container_type constraint if it exists
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'supplier_shipment_details_container_type_check'
        AND table_name = 'supplier_shipment_details'
    ) THEN
        ALTER TABLE public.supplier_shipment_details 
        DROP CONSTRAINT supplier_shipment_details_container_type_check;
        RAISE NOTICE 'Existing container_type constraint dropped';
    END IF;
    
    -- Add the container_type check constraint
    ALTER TABLE public.supplier_shipment_details 
    ADD CONSTRAINT supplier_shipment_details_container_type_check 
    CHECK (container_type IN ('carton', 'pallet'));
    
    RAISE NOTICE 'Container_type check constraint added successfully';
END $$;

-- Step 7: Add comments to columns for documentation
-- ============================================================================

COMMENT ON COLUMN public.supplier_shipment_details.inco_terms IS 
'Incoterms (International Commercial Terms) for the shipment. 
Valid values depend on mode of transport:
- Sea: EXW, FOB, CFR, DDP
- Air: EXW, FCA, CPT, DDP';

COMMENT ON COLUMN public.supplier_shipment_details.address IS 
'Supplier pickup/shipping address for this shipment';

COMMENT ON COLUMN public.supplier_shipment_details.origin IS 
'Country or location of origin for the shipment';

COMMENT ON COLUMN public.supplier_shipment_details.container_type IS 
'Type of container: carton or pallet';

COMMENT ON COLUMN public.supplier_shipment_details.net_weight IS 
'Net weight of the shipment in kg (excluding packaging)';

COMMENT ON COLUMN public.supplier_shipment_details.gross_weight IS 
'Gross weight of the shipment in kg (including packaging)';

-- Step 8: Verification Queries
-- ============================================================================

-- Verify all new columns were added
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'supplier_shipment_details'
  AND column_name IN ('inco_terms', 'address', 'origin', 'container_type', 'net_weight')
ORDER BY column_name;

-- Verify the constraints
SELECT 
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND table_name = 'supplier_shipment_details'
  AND constraint_name IN (
    'supplier_shipment_details_inco_terms_check',
    'supplier_shipment_details_container_type_check'
  );

-- ============================================================================
-- Script Completion Notice
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Script completed successfully!';
    RAISE NOTICE 'Added columns to supplier_shipment_details:';
    RAISE NOTICE '  - inco_terms (TEXT)';
    RAISE NOTICE '  - address (TEXT)';
    RAISE NOTICE '  - origin (TEXT)';
    RAISE NOTICE '  - container_type (TEXT with constraint)';
    RAISE NOTICE '  - net_weight (NUMERIC)';
    RAISE NOTICE '========================================';
END $$;
