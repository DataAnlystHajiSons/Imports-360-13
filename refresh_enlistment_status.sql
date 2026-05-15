CREATE OR REPLACE FUNCTION public.refresh_enlistment_status()
RETURNS void AS $
BEGIN
    UPDATE public.forecast f
    SET enlistment_status = EXISTS (
        SELECT 1
        FROM public.verification_list vl
        WHERE vl.crop_id = f.product_variety_id
    )
    WHERE f.enlistment_status IS DISTINCT FROM EXISTS (
        SELECT 1 
        FROM public.verification_list vl 
        WHERE vl.crop_id = f.product_variety_id
    );
END;
$ LANGUAGE plpgsql;