-- Migration: 26_add_cancellation_reason_to_shipment.sql
-- Description: Add cancellation_reason column to shipment table

-- Step 1: Add cancellation_reason column to shipment table
ALTER TABLE public.shipment ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- Step 2: Comment on column
COMMENT ON COLUMN public.shipment.cancellation_reason IS 'Mandatory reason explaining why the shipment was cancelled';
