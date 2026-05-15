-- ============================================================================
-- Product Management & Audit System
-- ============================================================================
-- Purpose: Allow users to manage products on existing shipments with full
--          change tracking (who, what, when)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CREATE PRODUCT CHANGE LOG TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shipment_products_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id uuid NOT NULL REFERENCES public.shipment(id) ON DELETE CASCADE,
  product_variety_id uuid NOT NULL REFERENCES public.product_variety(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('added', 'removed', 'quantity_changed', 'unit_changed', 'rate_changed', 'amount_changed')),
  
  -- Old values (NULL for 'added' action)
  old_quantity numeric,
  old_unit text,
  old_rate numeric,
  old_amount numeric,
  
  -- New values (NULL for 'removed' action)
  new_quantity numeric,
  new_unit text,
  new_rate numeric,
  new_amount numeric,
  
  -- Audit fields
  changed_by uuid REFERENCES public.app_user(id),
  changed_at timestamp with time zone DEFAULT now(),
  change_reason text,
  
  -- Metadata
  metadata jsonb DEFAULT '{}'::jsonb,
  
  CONSTRAINT shipment_products_audit_check 
    CHECK (
      (action = 'added' AND new_quantity IS NOT NULL) OR
      (action = 'removed' AND old_quantity IS NOT NULL) OR
      (action IN ('quantity_changed', 'unit_changed', 'rate_changed', 'amount_changed'))
    )
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_shipment_products_audit_shipment 
  ON public.shipment_products_audit(shipment_id);
  
CREATE INDEX IF NOT EXISTS idx_shipment_products_audit_product 
  ON public.shipment_products_audit(product_variety_id);
  
CREATE INDEX IF NOT EXISTS idx_shipment_products_audit_changed_at 
  ON public.shipment_products_audit(changed_at DESC);
  
CREATE INDEX IF NOT EXISTS idx_shipment_products_audit_changed_by 
  ON public.shipment_products_audit(changed_by);

COMMENT ON TABLE public.shipment_products_audit IS 
  'Tracks all changes to shipment products including additions, removals, and modifications';

-- ----------------------------------------------------------------------------
-- 2. CREATE TRIGGER FUNCTION FOR AUTOMATIC AUDIT LOGGING
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_shipment_product_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get current user (with fallback)
  BEGIN
    v_user_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_user_id := NULL;
  END;

  -- Handle INSERT (product added)
  IF (TG_OP = 'INSERT') THEN
    INSERT INTO public.shipment_products_audit (
      shipment_id,
      product_variety_id,
      action,
      new_quantity,
      new_unit,
      new_rate,
      new_amount,
      changed_by,
      metadata
    ) VALUES (
      NEW.shipment_id,
      NEW.product_variety_id,
      'added',
      NEW.quantity,
      NEW.unit,
      NEW.rate,
      NEW.amount,
      v_user_id,
      jsonb_build_object(
        'trigger', 'auto',
        'operation', TG_OP
      )
    );
    RETURN NEW;
  END IF;

  -- Handle DELETE (product removed)
  IF (TG_OP = 'DELETE') THEN
    INSERT INTO public.shipment_products_audit (
      shipment_id,
      product_variety_id,
      action,
      old_quantity,
      old_unit,
      old_rate,
      old_amount,
      changed_by,
      metadata
    ) VALUES (
      OLD.shipment_id,
      OLD.product_variety_id,
      'removed',
      OLD.quantity,
      OLD.unit,
      OLD.rate,
      OLD.amount,
      v_user_id,
      jsonb_build_object(
        'trigger', 'auto',
        'operation', TG_OP
      )
    );
    RETURN OLD;
  END IF;

  -- Handle UPDATE (product modified)
  IF (TG_OP = 'UPDATE') THEN
    -- Log quantity changes
    IF (OLD.quantity IS DISTINCT FROM NEW.quantity) THEN
      INSERT INTO public.shipment_products_audit (
        shipment_id,
        product_variety_id,
        action,
        old_quantity,
        new_quantity,
        old_unit,
        new_unit,
        old_rate,
        new_rate,
        old_amount,
        new_amount,
        changed_by,
        metadata
      ) VALUES (
        NEW.shipment_id,
        NEW.product_variety_id,
        'quantity_changed',
        OLD.quantity,
        NEW.quantity,
        OLD.unit,
        NEW.unit,
        OLD.rate,
        NEW.rate,
        OLD.amount,
        NEW.amount,
        v_user_id,
        jsonb_build_object(
          'trigger', 'auto',
          'operation', TG_OP,
          'field_changed', 'quantity'
        )
      );
    END IF;

    -- Log unit changes
    IF (OLD.unit IS DISTINCT FROM NEW.unit) THEN
      INSERT INTO public.shipment_products_audit (
        shipment_id,
        product_variety_id,
        action,
        old_quantity,
        new_quantity,
        old_unit,
        new_unit,
        old_rate,
        new_rate,
        old_amount,
        new_amount,
        changed_by,
        metadata
      ) VALUES (
        NEW.shipment_id,
        NEW.product_variety_id,
        'unit_changed',
        OLD.quantity,
        NEW.quantity,
        OLD.unit,
        NEW.unit,
        OLD.rate,
        NEW.rate,
        OLD.amount,
        NEW.amount,
        v_user_id,
        jsonb_build_object(
          'trigger', 'auto',
          'operation', TG_OP,
          'field_changed', 'unit'
        )
      );
    END IF;

    -- Log rate changes
    IF (OLD.rate IS DISTINCT FROM NEW.rate) THEN
      INSERT INTO public.shipment_products_audit (
        shipment_id,
        product_variety_id,
        action,
        old_quantity,
        new_quantity,
        old_unit,
        new_unit,
        old_rate,
        new_rate,
        old_amount,
        new_amount,
        changed_by,
        metadata
      ) VALUES (
        NEW.shipment_id,
        NEW.product_variety_id,
        'rate_changed',
        OLD.quantity,
        NEW.quantity,
        OLD.unit,
        NEW.unit,
        OLD.rate,
        NEW.rate,
        OLD.amount,
        NEW.amount,
        v_user_id,
        jsonb_build_object(
          'trigger', 'auto',
          'operation', TG_OP,
          'field_changed', 'rate'
        )
      );
    END IF;

    -- Log amount changes
    IF (OLD.amount IS DISTINCT FROM NEW.amount) THEN
      INSERT INTO public.shipment_products_audit (
        shipment_id,
        product_variety_id,
        action,
        old_quantity,
        new_quantity,
        old_unit,
        new_unit,
        old_rate,
        new_rate,
        old_amount,
        new_amount,
        changed_by,
        metadata
      ) VALUES (
        NEW.shipment_id,
        NEW.product_variety_id,
        'amount_changed',
        OLD.quantity,
        NEW.quantity,
        OLD.unit,
        NEW.unit,
        OLD.rate,
        NEW.rate,
        OLD.amount,
        NEW.amount,
        v_user_id,
        jsonb_build_object(
          'trigger', 'auto',
          'operation', TG_OP,
          'field_changed', 'amount'
        )
      );
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. CREATE TRIGGER ON SHIPMENT_PRODUCTS TABLE
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_log_shipment_product_changes ON public.shipment_products;

CREATE TRIGGER trigger_log_shipment_product_changes
  AFTER INSERT OR UPDATE OR DELETE ON public.shipment_products
  FOR EACH ROW
  EXECUTE FUNCTION public.log_shipment_product_changes();

COMMENT ON TRIGGER trigger_log_shipment_product_changes ON public.shipment_products IS
  'Automatically logs all changes to shipment products for audit trail';

-- ----------------------------------------------------------------------------
-- 4. CREATE VIEW FOR PRODUCT CHANGE HISTORY
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_shipment_products_history AS
SELECT 
  spa.id,
  spa.shipment_id,
  s.reference_code as shipment_reference,
  spa.product_variety_id,
  pv.product_name,
  pv.variety_name,
  c.name as commodity_name,
  spa.action,
  spa.old_quantity,
  spa.old_unit,
  spa.old_rate,
  spa.old_amount,
  spa.new_quantity,
  spa.new_unit,
  spa.new_rate,
  spa.new_amount,
  spa.changed_by,
  au.full_name as changed_by_name,
  au.email as changed_by_email,
  au.role as changed_by_role,
  spa.changed_at,
  spa.change_reason,
  spa.metadata,
  -- Calculate differences
  CASE 
    WHEN spa.action = 'quantity_changed' THEN spa.new_quantity - spa.old_quantity
    ELSE NULL
  END as quantity_difference,
  CASE 
    WHEN spa.action = 'rate_changed' THEN spa.new_rate - spa.old_rate
    ELSE NULL
  END as rate_difference,
  CASE 
    WHEN spa.action = 'amount_changed' THEN spa.new_amount - spa.old_amount
    ELSE NULL
  END as amount_difference
FROM public.shipment_products_audit spa
LEFT JOIN public.shipment s ON spa.shipment_id = s.id
LEFT JOIN public.product_variety pv ON spa.product_variety_id = pv.id
LEFT JOIN public.commodity c ON pv.commodity_id = c.id
LEFT JOIN public.app_user au ON spa.changed_by = au.id
ORDER BY spa.changed_at DESC;

COMMENT ON VIEW public.v_shipment_products_history IS
  'Comprehensive view of product change history with user details and calculated differences';

-- ----------------------------------------------------------------------------
-- 5. CREATE FUNCTION TO GET PRODUCT HISTORY FOR A SHIPMENT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_shipment_product_history(
  p_shipment_id uuid,
  p_limit integer DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  product_name text,
  variety_name text,
  action text,
  old_quantity numeric,
  old_unit text,
  new_quantity numeric,
  new_unit text,
  changed_by_name text,
  changed_at timestamp with time zone,
  change_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    h.id,
    h.product_name,
    h.variety_name,
    h.action,
    h.old_quantity,
    h.old_unit,
    h.new_quantity,
    h.new_unit,
    h.changed_by_name,
    h.changed_at,
    h.change_reason
  FROM public.v_shipment_products_history h
  WHERE h.shipment_id = p_shipment_id
  ORDER BY h.changed_at DESC
  LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION public.get_shipment_product_history IS
  'Retrieves product change history for a specific shipment';

-- ----------------------------------------------------------------------------
-- 6. CREATE FUNCTION TO ADD PRODUCT TO EXISTING SHIPMENT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.add_product_to_shipment(
  p_shipment_id uuid,
  p_product_variety_id uuid,
  p_quantity numeric,
  p_unit text,
  p_rate numeric DEFAULT NULL,
  p_amount numeric DEFAULT NULL,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_result jsonb;
BEGIN
  -- Get current user
  BEGIN
    v_user_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'User not authenticated';
  END;

  -- Validate shipment exists
  IF NOT EXISTS (SELECT 1 FROM public.shipment WHERE id = p_shipment_id) THEN
    RAISE EXCEPTION 'Shipment % not found', p_shipment_id;
  END IF;

  -- Validate product variety exists
  IF NOT EXISTS (SELECT 1 FROM public.product_variety WHERE id = p_product_variety_id) THEN
    RAISE EXCEPTION 'Product variety % not found', p_product_variety_id;
  END IF;

  -- Check if product already exists in shipment
  IF EXISTS (
    SELECT 1 FROM public.shipment_products 
    WHERE shipment_id = p_shipment_id 
    AND product_variety_id = p_product_variety_id
  ) THEN
    RAISE EXCEPTION 'Product already exists in this shipment. Use update function instead.';
  END IF;

  -- Insert the product (trigger will log this automatically)
  INSERT INTO public.shipment_products (
    shipment_id,
    product_variety_id,
    quantity,
    unit,
    rate,
    amount
  ) VALUES (
    p_shipment_id,
    p_product_variety_id,
    p_quantity,
    p_unit,
    p_rate,
    p_amount
  );

  -- Update the audit log with reason if provided
  IF p_reason IS NOT NULL THEN
    UPDATE public.shipment_products_audit
    SET change_reason = p_reason
    WHERE shipment_id = p_shipment_id
    AND product_variety_id = p_product_variety_id
    AND action = 'added'
    AND changed_at = (
      SELECT MAX(changed_at) 
      FROM public.shipment_products_audit 
      WHERE shipment_id = p_shipment_id 
      AND product_variety_id = p_product_variety_id
    );
  END IF;

  v_result := jsonb_build_object(
    'success', true,
    'message', 'Product added successfully',
    'shipment_id', p_shipment_id,
    'product_variety_id', p_product_variety_id
  );

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.add_product_to_shipment IS
  'Adds a new product to an existing shipment with audit tracking';

-- ----------------------------------------------------------------------------
-- 7. CREATE FUNCTION TO REMOVE PRODUCT FROM SHIPMENT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.remove_product_from_shipment(
  p_shipment_id uuid,
  p_product_variety_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_result jsonb;
BEGIN
  -- Get current user
  BEGIN
    v_user_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'User not authenticated';
  END;

  -- Validate product exists in shipment
  IF NOT EXISTS (
    SELECT 1 FROM public.shipment_products 
    WHERE shipment_id = p_shipment_id 
    AND product_variety_id = p_product_variety_id
  ) THEN
    RAISE EXCEPTION 'Product not found in this shipment';
  END IF;

  -- Delete the product (trigger will log this automatically)
  DELETE FROM public.shipment_products
  WHERE shipment_id = p_shipment_id
  AND product_variety_id = p_product_variety_id;

  -- Update the audit log with reason if provided
  IF p_reason IS NOT NULL THEN
    UPDATE public.shipment_products_audit
    SET change_reason = p_reason
    WHERE shipment_id = p_shipment_id
    AND product_variety_id = p_product_variety_id
    AND action = 'removed'
    AND changed_at = (
      SELECT MAX(changed_at) 
      FROM public.shipment_products_audit 
      WHERE shipment_id = p_shipment_id 
      AND product_variety_id = p_product_variety_id
    );
  END IF;

  v_result := jsonb_build_object(
    'success', true,
    'message', 'Product removed successfully',
    'shipment_id', p_shipment_id,
    'product_variety_id', p_product_variety_id
  );

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.remove_product_from_shipment IS
  'Removes a product from an existing shipment with audit tracking';

-- ----------------------------------------------------------------------------
-- 8. CREATE FUNCTION TO UPDATE PRODUCT IN SHIPMENT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_shipment_product(
  p_shipment_id uuid,
  p_product_variety_id uuid,
  p_quantity numeric DEFAULT NULL,
  p_unit text DEFAULT NULL,
  p_rate numeric DEFAULT NULL,
  p_amount numeric DEFAULT NULL,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_result jsonb;
  v_current_record record;
BEGIN
  -- Get current user
  BEGIN
    v_user_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'User not authenticated';
  END;

  -- Get current product data
  SELECT * INTO v_current_record
  FROM public.shipment_products
  WHERE shipment_id = p_shipment_id
  AND product_variety_id = p_product_variety_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product not found in this shipment';
  END IF;

  -- Update only the fields that were provided
  UPDATE public.shipment_products
  SET 
    quantity = COALESCE(p_quantity, quantity),
    unit = COALESCE(p_unit, unit),
    rate = COALESCE(p_rate, rate),
    amount = COALESCE(p_amount, amount)
  WHERE shipment_id = p_shipment_id
  AND product_variety_id = p_product_variety_id;

  -- Update the audit log with reason if provided
  IF p_reason IS NOT NULL THEN
    UPDATE public.shipment_products_audit
    SET change_reason = p_reason
    WHERE shipment_id = p_shipment_id
    AND product_variety_id = p_product_variety_id
    AND changed_at >= NOW() - INTERVAL '1 second';
  END IF;

  v_result := jsonb_build_object(
    'success', true,
    'message', 'Product updated successfully',
    'shipment_id', p_shipment_id,
    'product_variety_id', p_product_variety_id
  );

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.update_shipment_product IS
  'Updates product details in an existing shipment with audit tracking';

-- ----------------------------------------------------------------------------
-- 9. GRANT PERMISSIONS (adjust based on your RLS policies)
-- ----------------------------------------------------------------------------
-- Grant access to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.shipment_products_audit TO authenticated;
GRANT SELECT ON public.v_shipment_products_history TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_shipment_product_history TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_product_to_shipment TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_product_from_shipment TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_shipment_product TO authenticated;

-- ----------------------------------------------------------------------------
-- 10. CREATE RLS POLICIES
-- ----------------------------------------------------------------------------
ALTER TABLE public.shipment_products_audit ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view audit logs for shipments they have access to
CREATE POLICY "Users can view product audit logs"
  ON public.shipment_products_audit
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.shipment s
      WHERE s.id = shipment_products_audit.shipment_id
      -- Add additional access control based on your requirements
    )
  );

-- Policy: System can insert audit logs
CREATE POLICY "System can insert product audit logs"
  ON public.shipment_products_audit
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '✅ Product Management & Audit System created successfully!';
  RAISE NOTICE '📋 Features enabled:';
  RAISE NOTICE '   - Product change tracking (add/remove/update)';
  RAISE NOTICE '   - Automatic audit logging via triggers';
  RAISE NOTICE '   - Change history view';
  RAISE NOTICE '   - Helper functions for product management';
  RAISE NOTICE '🔐 RLS policies enabled for security';
END $$;
