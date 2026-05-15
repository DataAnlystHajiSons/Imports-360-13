-- Step 1: Add the new commodity_id column to the measurement_unit table
ALTER TABLE public.measurement_unit
ADD COLUMN commodity_id uuid;

-- Step 2: Update the new commodity_id column with the corresponding id from the commodity table
UPDATE public.measurement_unit mu
SET commodity_id = c.id
FROM public.commodity c
WHERE mu.commodity::text = c.name;

-- Step 3: Add the foreign key constraint
ALTER TABLE public.measurement_unit
ADD CONSTRAINT measurement_unit_commodity_id_fkey
FOREIGN KEY (commodity_id) REFERENCES public.commodity(id);

-- Step 4: Drop the old commodity column
ALTER TABLE public.measurement_unit
DROP COLUMN commodity;