CREATE OR REPLACE FUNCTION public.calculate_insurance_values()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculation for amount
    IF NEW.value IS NOT NULL AND NEW.rate IS NOT NULL THEN
        NEW.amount := NEW.value * NEW.rate;
    END IF;

    -- Calculation for ten_perc
    IF NEW.amount IS NOT NULL THEN
        NEW.ten_perc := NEW.amount * 0.10;
    END IF;

    -- Calculation for total_value
    IF NEW.amount IS NOT NULL AND NEW.ten_perc IS NOT NULL THEN
        NEW.total_value := NEW.amount + NEW.ten_perc;
    END IF;

    -- Calculation for marine_amount
    IF NEW.total_value IS NOT NULL AND NEW.marine_perc IS NOT NULL THEN
        NEW.marine_amount := NEW.total_value * (NEW.marine_perc / 100);
    END IF;

    -- Calculation for war_amount
    IF NEW.total_value IS NOT NULL AND NEW.war_perc IS NOT NULL THEN
        NEW.war_amount := NEW.total_value * (NEW.war_perc / 100);
    END IF;

    -- Calculation for fif_amount
    IF NEW.marine_amount IS NOT NULL AND NEW.war_amount IS NOT NULL AND NEW.asc_1 IS NOT NULL AND NEW.fif_perc IS NOT NULL THEN
        NEW.fif_amount := (NEW.marine_amount + NEW.war_amount + NEW.asc_1) * NEW.fif_perc;
    END IF;

    -- Calculation for sts_amount
    IF NEW.marine_amount IS NOT NULL AND NEW.war_amount IS NOT NULL AND NEW.asc_1 IS NOT NULL AND NEW.sts_perc IS NOT NULL THEN
        NEW.sts_amount := (NEW.marine_amount + NEW.war_amount + NEW.asc_1) * NEW.sts_perc;
    END IF;

    -- Calculation for grand_total
    IF NEW.marine_amount IS NOT NULL AND NEW.war_amount IS NOT NULL AND NEW.asc_1 IS NOT NULL AND NEW.fif_amount IS NOT NULL AND NEW.sts_amount IS NOT NULL AND NEW.stamp IS NOT NULL THEN
        NEW.grand_total := (NEW.marine_amount + NEW.war_amount + NEW.asc_1) + NEW.fif_amount + NEW.sts_amount + NEW.stamp;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS insurance_before_insert_update ON public.insurance;
CREATE TRIGGER insurance_before_insert_update
BEFORE INSERT OR UPDATE ON public.insurance
FOR EACH ROW
EXECUTE FUNCTION public.calculate_insurance_values();
