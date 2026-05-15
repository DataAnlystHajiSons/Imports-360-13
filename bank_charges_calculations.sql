-- Issuance Calculations
CREATE OR REPLACE FUNCTION public.calculate_issuance_percentages()
RETURNS TRIGGER AS $$
DECLARE
    bank_charge_rs numeric;
BEGIN
    -- Get the rs value from the bank_charges table
    SELECT bc.rs INTO bank_charge_rs
    FROM public.bank_charges bc
    WHERE bc.id = NEW.bank_charges_id;

    -- Calculate percentages
    IF bank_charge_rs IS NOT NULL AND bank_charge_rs > 0 THEN
        IF NEW.services_charges_amount IS NOT NULL THEN
            NEW.services_charges_per := (NEW.services_charges_amount / bank_charge_rs) * 100;
        END IF;
        IF NEW.swift_amount IS NOT NULL THEN
            NEW.swift_percentage := (NEW.swift_amount / bank_charge_rs) * 100;
        END IF;
    END IF;

    IF NEW.services_charges_amount IS NOT NULL AND NEW.services_charges_amount > 0 THEN
        IF NEW.fed_amount IS NOT NULL THEN
            NEW.fed_per := (NEW.fed_amount / NEW.services_charges_amount) * 100;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS issuance_before_insert_update ON public.issuance;
CREATE TRIGGER issuance_before_insert_update
BEFORE INSERT OR UPDATE ON public.issuance
FOR EACH ROW
EXECUTE FUNCTION public.calculate_issuance_percentages();

-- Amendment Calculations
CREATE OR REPLACE FUNCTION public.calculate_amendment_percentages()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.amendment_charges_amount IS NOT NULL AND NEW.amendment_charges_amount > 0 THEN
        IF NEW.fed_amount IS NOT NULL THEN
            NEW.fed_per := (NEW.fed_amount / NEW.amendment_charges_amount) * 100;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS amendment_before_insert_update ON public.amendment;
CREATE TRIGGER amendment_before_insert_update
BEFORE INSERT OR UPDATE ON public.amendment
FOR EACH ROW
EXECUTE FUNCTION public.calculate_amendment_percentages();

-- Final Payment Calculations
CREATE OR REPLACE FUNCTION public.calculate_final_payment_percentages()
RETURNS TRIGGER AS $$
DECLARE
    bank_charge_rs numeric;
BEGIN
    -- Get the rs value from the bank_charges table
    SELECT bc.rs INTO bank_charge_rs
    FROM public.bank_charges bc
    WHERE bc.id = NEW.bank_charges_id;

    -- Calculate percentages
    IF bank_charge_rs IS NOT NULL AND bank_charge_rs > 0 THEN
        IF NEW.services_charges_amount IS NOT NULL THEN
            NEW.services_charges_per := (NEW.services_charges_amount / bank_charge_rs) * 100;
        END IF;
    END IF;

    IF NEW.services_charges_amount IS NOT NULL AND NEW.services_charges_amount > 0 THEN
        IF NEW.fed_amount IS NOT NULL THEN
            NEW.fed_per := (NEW.fed_amount / NEW.services_charges_amount) * 100;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS final_payment_before_insert_update ON public.final_payment;
CREATE TRIGGER final_payment_before_insert_update
BEFORE INSERT OR UPDATE ON public.final_payment
FOR EACH ROW
EXECUTE FUNCTION public.calculate_final_payment_percentages();

-- Bank Charges RS Calculation
CREATE OR REPLACE FUNCTION public.calculate_rs_value()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.usd_amount IS NOT NULL AND NEW.rate IS NOT NULL THEN
        NEW.rs := NEW.usd_amount * NEW.rate;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS bank_charges_before_insert_update_rs ON public.bank_charges;
CREATE TRIGGER bank_charges_before_insert_update_rs
BEFORE INSERT OR UPDATE ON public.bank_charges
FOR EACH ROW
EXECUTE FUNCTION public.calculate_rs_value();