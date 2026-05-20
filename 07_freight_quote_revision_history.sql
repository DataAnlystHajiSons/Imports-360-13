-- 1. Add columns to freight_quote_response for tracking revisions
ALTER TABLE freight_quote_response
ADD COLUMN IF NOT EXISTS is_revised BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS previous_quote_data JSONB;

-- 2. Add an "unlock" endpoint/function for the admin to use
CREATE OR REPLACE FUNCTION unlock_freight_quote(p_quote_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- We'll delete the existing row so the frontend link (which uses eq('freight_query_id'))
    -- will act like it's a new submission, OR we keep it and flag it.
    -- Given the user wants history side-by-side, we must KEEP it, but tell the frontend
    -- that it's allowed to submit an update.
    -- Wait, the simplest way is to add an "is_unlocked" flag.
    RETURN true;
END;
$$;

-- Actually, a better approach for the DB schema:
ALTER TABLE freight_quote_response
ADD COLUMN IF NOT EXISTS is_unlocked BOOLEAN DEFAULT false;

-- Add function to unlock
CREATE OR REPLACE FUNCTION request_quote_revision(p_quote_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE freight_quote_response 
    SET is_unlocked = true 
    WHERE id = p_quote_id;
    
    RETURN true;
END;
$$;
