DROP FUNCTION IF EXISTS func_set_to_draft(int);
CREATE OR REPLACE FUNCTION public.func_set_to_draft(contract int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        contract_ids record;
        leasing_loan_ids record;
        leasing_payment_ids record;
        leasing_interest_ids record;
        leasing_amortization_ids record;
        leasing_amortization_line_ids record;
        account_move_ids record;
        eom_move_ids record;
        journal_move_ids record;
    BEGIN
        SELECT * FROM leasing_contract WHERE id = contract INTO contract_ids;
        FOR leasing_loan_ids IN SELECT * FROM leasing_contract_line WHERE contract_id = contract ORDER BY id
        LOOP
            SELECT * FROM account_move WHERE id = leasing_loan_ids.account_move_id INTO account_move_ids;
            IF account_move_ids.state = 'posted' THEN
                PERFORM unreconcile_journal(account_move_ids.id);
                PERFORM create_journal_reverse(account_move_ids.id);
            ELSE
                PERFORM create_log_message('account.move', account_move_ids.state, 'Cancel', account_move_ids.id, 'state');
                UPDATE account_move SET state = 'cancel' WHERE id = account_move_ids.id;
                UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = account_move_ids.id;
            END IF;
            UPDATE leasing_contract_line SET account_move_id = null, amortization_id = null, write_date = now() WHERE id = leasing_loan_ids.id;
        END LOOP;
        
        FOR leasing_payment_ids IN SELECT * FROM leasing_contract_payment WHERE contract_id = contract ORDER BY id
        LOOP
            SELECT * FROM account_move WHERE id = leasing_payment_ids.account_move_id INTO account_move_ids;
            IF account_move_ids.state = 'posted' THEN
                PERFORM unreconcile_journal(account_move_ids.id);
                PERFORM create_journal_reverse(account_move_ids.id);
            ELSE
                PERFORM create_log_message('account.move', account_move_ids.state, 'Cancel', account_move_ids.id, 'state');
                UPDATE account_move SET state = 'cancel' WHERE id = account_move_ids.id;
                UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = account_move_ids.id;
            END IF;
            UPDATE leasing_contract_payment SET account_move_id = null, write_date = now() at time zone 'utc' WHERE id = leasing_payment_ids.id;
        END LOOP;
        
        FOR leasing_interest_ids IN SELECT * FROM leasing_contract_interest WHERE contract_id = contract ORDER BY id
        LOOP
            SELECT * FROM account_move WHERE id = leasing_interest_ids.eom_account_move_id INTO eom_move_ids;
            SELECT * FROM account_move WHERE id = leasing_interest_ids.journal_account_move_id INTO journal_move_ids;
            IF eom_move_ids.state = 'posted' THEN
                PERFORM unreconcile_journal(eom_move_ids.id);
                PERFORM create_journal_reverse(eom_move_ids.id);
            ELSE
                PERFORM create_log_message('account.move', eom_move_ids.state, 'Cancel', eom_move_ids.id, 'state');
                UPDATE account_move SET state = 'cancel' WHERE id = eom_move_ids.id;
                UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = eom_move_ids.id;
            END IF;
            
            IF journal_move_ids.state = 'posted' THEN
                PERFORM unreconcile_journal(journal_move_ids.id);
                PERFORM create_journal_reverse(journal_move_ids.id);
            ELSE
                PERFORM create_log_message('account.move', journal_move_ids.state, 'Cancel', journal_move_ids.id, 'state');
                UPDATE account_move SET state = 'cancel' WHERE id = journal_move_ids.id;
                UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = journal_move_ids.id;
            END IF;
            UPDATE leasing_contract_interest SET eom_account_move_id = null, journal_account_move_id = null, write_date = now() at time zone 'utc' WHERE id = leasing_interest_ids.id;
        END LOOP;
        
        FOR leasing_amortization_ids IN SELECT * FROM mofi_leasing_amortization WHERE ca_contract_number_id = contract ORDER BY id
        LOOP
            FOR leasing_amortization_line_ids IN SELECT * FROM mofi_leasing_amortization_line WHERE amortization_id = leasing_amortization_ids.id
            LOOP
                SELECT * FROM account_move WHERE id = leasing_amortization_line_ids.account_move_id INTO account_move_ids;
                IF account_move_ids.state = 'posted' THEN
                    PERFORM unreconcile_journal(account_move_ids.id);
                    PERFORM create_journal_reverse(account_move_ids.id);
                ELSE
                    PERFORM create_log_message('account.move', account_move_ids.state, 'Cancel', account_move_ids.id, 'state');
                    UPDATE account_move SET state = 'cancel' WHERE id = account_move_ids.id;
                    UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = account_move_ids.id;
                END IF;
                UPDATE mofi_leasing_amortization_line SET account_move_id = NULL, write_date = now() WHERE id = leasing_amortization_line_ids.id;
            END LOOP;
            PERFORM create_log_message('mofi.leasing.amortization', leasing_amortization_ids.status, 'Cancel', leasing_amortization_ids.id, 'status');
            UPDATE mofi_leasing_amortization SET status = 'cancel' WHERE id = leasing_amortization_ids.id;
        END LOOP;
    END;
$$;

DROP FUNCTION IF EXISTS func_set_to_draft_with_date(int, varchar);
CREATE OR REPLACE FUNCTION public.func_set_to_draft_with_date(contract int, new_date varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        contract_ids record;
        leasing_loan_ids record;
        leasing_payment_ids record;
        leasing_interest_ids record;
        leasing_amortization_ids record;
        leasing_amortization_line_ids record;
        account_move_ids record;
        eom_move_ids record;
        journal_move_ids record;
        odoo_lockdate record;
    BEGIN
        SELECT * FROM leasing_contract WHERE id = contract INTO contract_ids;
        FOR leasing_loan_ids IN SELECT * FROM leasing_contract_line WHERE contract_id = contract ORDER BY id
        LOOP
            SELECT * FROM account_move WHERE id = leasing_loan_ids.account_move_id INTO account_move_ids;
            IF account_move_ids.state = 'posted' THEN
                PERFORM unreconcile_journal(account_move_ids.id);
                PERFORM create_journal_reverse_with_date(account_move_ids.id, new_date);
            ELSE
                PERFORM create_log_message('account.move', account_move_ids.state, 'Cancel', account_move_ids.id, 'state');
                UPDATE account_move SET state = 'cancel' WHERE id = account_move_ids.id;
                UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = account_move_ids.id;
            END IF;
            UPDATE leasing_contract_line SET account_move_id = null, amortization_id = null, write_date = now() at time zone 'utc' WHERE id = leasing_loan_ids.id;
        END LOOP;
        
        FOR leasing_payment_ids IN SELECT * FROM leasing_contract_payment WHERE contract_id = contract ORDER BY id
        LOOP
            SELECT * FROM account_move WHERE id = leasing_payment_ids.account_move_id INTO account_move_ids;
            IF account_move_ids.state = 'posted' THEN
                PERFORM unreconcile_journal(account_move_ids.id);
                PERFORM create_journal_reverse_with_date(account_move_ids.id, new_date);
            ELSE
                PERFORM create_log_message('account.move', account_move_ids.state, 'Cancel', account_move_ids.id, 'state');
                UPDATE account_move SET state = 'cancel' WHERE id = account_move_ids.id;
                UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = account_move_ids.id;
            END IF;
            UPDATE leasing_contract_payment SET account_move_id = null, write_date = now() at time zone 'utc' WHERE id = leasing_payment_ids.id;
        END LOOP;
        
        FOR leasing_interest_ids IN SELECT * FROM leasing_contract_interest WHERE contract_id = contract ORDER BY id
        LOOP
            SELECT * FROM account_move WHERE id = leasing_interest_ids.eom_account_move_id INTO eom_move_ids;
            SELECT * FROM account_move WHERE id = leasing_interest_ids.journal_account_move_id INTO journal_move_ids;
            IF eom_move_ids.state = 'posted' THEN
                PERFORM unreconcile_journal(eom_move_ids.id);
                PERFORM create_journal_reverse_with_date(eom_move_ids.id, new_date);
            ELSE
                PERFORM create_log_message('account.move', eom_move_ids.state, 'Cancel', eom_move_ids.id, 'state');
                UPDATE account_move SET state = 'cancel' WHERE id = eom_move_ids.id;
                UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = eom_move_ids.id;
            END IF;
            
            IF journal_move_ids.state = 'posted' THEN
                PERFORM unreconcile_journal(journal_move_ids.id);
                PERFORM create_journal_reverse_with_date(journal_move_ids.id, new_date);
            ELSE
                PERFORM create_log_message('account.move', journal_move_ids.state, 'Cancel', journal_move_ids.id, 'state');
                UPDATE account_move SET state = 'cancel' WHERE id = journal_move_ids.id;
                UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = journal_move_ids.id;
            END IF;
            UPDATE leasing_contract_interest SET eom_account_move_id = null, journal_account_move_id = null, write_date = now() WHERE id = leasing_interest_ids.id;
        END LOOP;
        
        FOR leasing_amortization_ids IN SELECT * FROM mofi_leasing_amortization WHERE ca_contract_number_id = contract ORDER BY id
        LOOP
            FOR leasing_amortization_line_ids IN SELECT * FROM mofi_leasing_amortization_line WHERE amortization_id = leasing_amortization_ids.id
            LOOP
                SELECT * FROM account_move WHERE id = leasing_amortization_line_ids.account_move_id INTO account_move_ids;
                IF account_move_ids.state = 'posted' THEN
                    PERFORM unreconcile_journal(account_move_ids.id);
                    PERFORM create_journal_reverse_with_date(account_move_ids.id, new_date);
                ELSE
                    PERFORM create_log_message('account.move', account_move_ids.state, 'Cancel', account_move_ids.id, 'state');
                    UPDATE account_move SET state = 'cancel' WHERE id = account_move_ids.id;
                    UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = account_move_ids.id;
                END IF;
                UPDATE mofi_leasing_amortization_line SET account_move_id = NULL, write_date = now() WHERE id = leasing_amortization_line_ids.id;
            END LOOP;
            PERFORM create_log_message('mofi.leasing.amortization', leasing_amortization_ids.status, 'Cancel', leasing_amortization_ids.id, 'status');
            UPDATE mofi_leasing_amortization SET status = 'cancel' WHERE id = leasing_amortization_ids.id;
        END LOOP;
    END;
$$;


DROP FUNCTION IF EXISTS func_set_to_draft_amortization(int);
CREATE OR REPLACE FUNCTION public.func_set_to_draft_amortization(amortization int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        leasing_amortization_ids record;
        leasing_amortization_line_ids record;
        account_move_ids record;
    BEGIN
        FOR leasing_amortization_ids IN SELECT * FROM mofi_leasing_amortization WHERE id = amortization ORDER BY id
        LOOP
            FOR leasing_amortization_line_ids IN SELECT * FROM mofi_leasing_amortization_line WHERE amortization_id = leasing_amortization_ids.id
            LOOP
                SELECT * FROM account_move WHERE id = leasing_amortization_line_ids.account_move_id INTO account_move_ids;
                IF account_move_ids.state = 'posted' THEN
                    PERFORM unreconcile_journal(account_move_ids.id);
                    PERFORM create_journal_reverse(account_move_ids.id);
                ELSE
                    PERFORM create_log_message('account.move', account_move_ids.state, 'Cancel', account_move_ids.id, 'state');
                    UPDATE account_move SET state = 'cancel' WHERE id = account_move_ids.id;
                    UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = account_move_ids.id;
                END IF;
                UPDATE mofi_leasing_amortization_line SET account_move_id = NULL, write_date = now() at time zone 'utc' WHERE id = leasing_amortization_line_ids.id;
            END LOOP;
            PERFORM create_log_message('mofi.leasing.amortization', leasing_amortization_ids.status, 'Draft', leasing_amortization_ids.id, 'status');
            UPDATE mofi_leasing_amortization SET status = 'draft' WHERE id = leasing_amortization_ids.id;
        END LOOP;
    END;
$$;

DROP FUNCTION IF EXISTS func_set_to_draft_amotization_with_date(int, varchar);
CREATE OR REPLACE FUNCTION public.func_set_to_draft_amotization_with_date(amortization int, new_date varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        leasing_amortization_ids record;
        leasing_amortization_line_ids record;
        account_move_ids record;
    BEGIN
        FOR leasing_amortization_ids IN SELECT * FROM mofi_leasing_amortization WHERE id = amortization ORDER BY id
        LOOP
            FOR leasing_amortization_line_ids IN SELECT * FROM mofi_leasing_amortization_line WHERE amortization_id = leasing_amortization_ids.id
            LOOP
                SELECT * FROM account_move WHERE id = leasing_amortization_line_ids.account_move_id INTO account_move_ids;
                IF account_move_ids.state = 'posted' THEN
                    PERFORM unreconcile_journal(account_move_ids.id);
                    PERFORM create_journal_reverse_with_date(account_move_ids.id, new_date);
                ELSE
                    PERFORM create_log_message('account.move', account_move_ids.state, 'Cancel', account_move_ids.id, 'state');
                    UPDATE account_move SET state = 'cancel' WHERE id = account_move_ids.id;
                    UPDATE account_move_line SET parent_state = 'cancel' WHERE move_id = account_move_ids.id;
                END IF;
                UPDATE mofi_leasing_amortization_line SET account_move_id = NULL, write_date = now() at time zone 'utc' WHERE id = leasing_amortization_line_ids.id;
            END LOOP;
            PERFORM create_log_message('mofi.leasing.amortization', leasing_amortization_ids.status, 'Draft', leasing_amortization_ids.id, 'status');
            UPDATE mofi_leasing_amortization SET status = 'cancel' WHERE id = leasing_amortization_ids.id;
        END LOOP;
    END;
$$;
