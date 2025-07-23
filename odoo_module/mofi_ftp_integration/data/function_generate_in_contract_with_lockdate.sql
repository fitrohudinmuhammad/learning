DROP FUNCTION IF EXISTS generate_loan_lock_date(int, varchar);
CREATE OR REPLACE FUNCTION public.generate_loan_lock_date(contracts int, lockdate varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        line_ids record;
        leasing_account_ids record;
        account_move_ids int;
    BEGIN
        FOR line_ids IN SELECT lcl.id as line_id, funding_type_id, channel_id, loan_purpose_id, is_restructure, fee_type_id, amount, debtor_id
            FROM leasing_contract lc JOIN leasing_contract_line lcl ON lcl.contract_id = lc.id WHERE lc.id = contracts AND lcl.account_move_id IS NULL ORDER BY lcl.id
        LOOP
            SELECT * FROM mofi_leasing_account
            WHERE funding_type_id = line_ids.funding_type_id AND channel_id = line_ids.channel_id
            AND loan_purpose_id = line_ids.loan_purpose_id AND is_restructure = line_ids.is_restructure
            AND fee_type_id = line_ids.fee_type_id AND active = true LIMIT 1 INTO leasing_account_ids;

            IF leasing_account_ids.id IS NOT NULL AND line_ids.debtor_id IS NOT NULL THEN
                account_move_ids := create_journal_leasing_lock_date(line_ids.line_id, leasing_account_ids.id, lockdate);
                UPDATE leasing_contract_line SET account_move_id = account_move_ids WHERE id = line_ids.line_id;
            END IF;
        END LOOP;
    END;
$$;

---------------------------

DROP FUNCTION IF EXISTS generate_payment_lock_date(int, varchar);
CREATE OR REPLACE FUNCTION public.generate_payment_lock_date(contracts int, lockdate varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        line_ids record;
        leasing_account_ids record;
        account_move_ids int;
    BEGIN
        FOR line_ids IN SELECT lcl.id as line_id, funding_type_id, channel_id, loan_purpose_id, is_restructure, fee_type_id, amount, debtor_id
            FROM leasing_contract lc JOIN leasing_contract_payment lcl ON lcl.contract_id = lc.id WHERE lc.id = contracts AND lcl.account_move_id IS NULL ORDER BY lcl.id
        LOOP
            SELECT * FROM mofi_leasing_account
            WHERE funding_type_id = line_ids.funding_type_id AND channel_id = line_ids.channel_id
            AND loan_purpose_id = line_ids.loan_purpose_id AND is_restructure = line_ids.is_restructure
            AND fee_type_id = line_ids.fee_type_id AND active = true LIMIT 1 INTO leasing_account_ids;

            IF leasing_account_ids.id IS NOT NULL AND line_ids.debtor_id IS NOT NULL THEN
                account_move_ids := create_journal_payment_lock_date(line_ids.line_id, leasing_account_ids.id, lockdate);
                UPDATE leasing_contract_payment SET account_move_id = account_move_ids WHERE id = line_ids.line_id;
            END IF;
        END LOOP;
    END;
$$;

--select generate_payment(48);
---------------------------

DROP FUNCTION IF EXISTS generate_interest_lock_date(int, varchar);
CREATE OR REPLACE FUNCTION public.generate_interest_lock_date(contracts int, lockdate varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        line_ids record;
        leasing_account_ids record;
        account_move_ids int;
    BEGIN
        FOR line_ids IN SELECT lcl.id as line_id, funding_type_id, channel_id, loan_purpose_id, is_restructure, fee_type_id, interest_to_eom, interest_to_due_date, debtor_id,
            eom_account_move_id, journal_account_move_id
            FROM leasing_contract lc JOIN leasing_contract_interest lcl ON lcl.contract_id = lc.id WHERE lc.id = contracts ORDER BY lcl.id
        LOOP
            SELECT * FROM mofi_leasing_account
            WHERE funding_type_id = line_ids.funding_type_id AND channel_id = line_ids.channel_id
            AND loan_purpose_id = line_ids.loan_purpose_id AND is_restructure = line_ids.is_restructure
            AND fee_type_id = line_ids.fee_type_id AND active = true LIMIT 1 INTO leasing_account_ids;

            IF line_ids.eom_account_move_id IS NULL AND line_ids.interest_to_eom != 0.00 THEN
                IF leasing_account_ids.id IS NOT NULL AND line_ids.debtor_id IS NOT NULL THEN
                    account_move_ids := create_journal_interest_eom_lock_date(line_ids.line_id, leasing_account_ids.id, lockdate);
                    UPDATE leasing_contract_interest SET eom_account_move_id = account_move_ids WHERE id = line_ids.line_id;
                END IF;
            END IF;

            IF line_ids.journal_account_move_id IS NULL AND line_ids.interest_to_due_date != 0.00 THEN
                IF leasing_account_ids.id IS NOT NULL AND line_ids.debtor_id IS NOT NULL THEN
                    account_move_ids := create_journal_interest_journal_lock_date(line_ids.line_id, leasing_account_ids.id, lockdate);
                    UPDATE leasing_contract_interest SET journal_account_move_id = account_move_ids WHERE id = line_ids.line_id;
                END IF;
            END IF;
        END LOOP;
    END;
$$;

--select generate_interest(48);
---------------------------

DROP FUNCTION IF EXISTS generate_amortization_journal_lock_date(int, varchar);
CREATE OR REPLACE FUNCTION public.generate_amortization_journal_lock_date(amortizations int, lockdate varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        line_ids record;
        fee_type_ids record;
        account_move_ids int;
        leas_account_ids record;
        contract_ids record;
    BEGIN
        SELECT lc.* FROM leasing_contract lc JOIN mofi_leasing_amortization mla ON mla.ca_contract_number_id = lc.id WHERE mla.id = 7 INTO contract_ids;
        FOR line_ids IN SELECT mla.id as id, mlal.id as line_id, fee_type_id, amount, account_move_id, debtor_id
            FROM mofi_leasing_amortization mla JOIN mofi_leasing_amortization_line mlal ON mlal.amortization_id = mla.id WHERE mla.id = amortizations ORDER BY mlal.id
        LOOP
            SELECT * FROM mofi_fee_type WHERE id = line_ids.fee_type_id INTO fee_type_ids;

            SELECT *
            FROM mofi_leasing_account
            WHERE fee_type_id = line_ids.fee_type_id
                AND funding_type_id = contract_ids.funding_type_id
                AND channel_id = line_ids.channel_id
                AND loan_purpose_id = contract_ids.loan_purpose_id
                AND is_restructure = contract_ids.is_restructure
                AND active = true
                AND (debit_account_amortization_id IS NOT NULL AND credit_account_amortization_id IS NOT NULL) INTO leas_account_ids;

            IF line_ids.account_move_id IS NULL THEN
                IF fee_type_ids.id IS NOT NULL AND line_ids.debtor_id IS NOT NULL THEN
                    IF leas_account_ids.id IS NOT NULL THEN
                        account_move_ids := create_journal_amortization_lock_date(line_ids.line_id, fee_type_ids.id, lockdate);
                        raise notice '%', account_move_ids;
                        UPDATE mofi_leasing_amortization_line SET account_move_id = account_move_ids WHERE id = line_ids.line_id;
                    END IF;
                END IF;
            END IF;
        END LOOP;
    END;
$$;

-- select generate_amortization_journal(198)
---------------------------