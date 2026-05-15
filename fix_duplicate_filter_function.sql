-- This script removes the old, outdated version of the filter_shipments function.
DROP FUNCTION IF EXISTS public.filter_shipments(text,uuid,uuid,uuid,text,text,text,text,text);
