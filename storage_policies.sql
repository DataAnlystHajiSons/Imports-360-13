CREATE POLICY "Service role can access shipment-docs"
ON storage.objects FOR SELECT
TO service_role
USING ( bucket_id = 'shipment-docs' );
