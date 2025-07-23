DROP FUNCTION IF EXISTS reset_to_draft(int);
CREATE OR REPLACE FUNCTION public.reset_to_draft(leas_contract_id int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        contract_ids record;
        leasing_loan_ids record;
        leasing_payment_ids record;
        leasing_interest_ids record;
        amortization_ids record;
        amortization_line_ids record;
        loan_move_ids record;
        eom_move_ids record;
        journal_move_ids record;
        data_aggregation record;
        vnew_move int;
        vcpartner_id int;
        vordertype int;
        vsuborder int;
        vfeetype int;
        vpaymentchannel int;
        vaccountjournal int;
        vfundtype int;
        vchannel int;
        vloanpurpose int;
        vbranch int;
        currency int;
    BEGIN
        SELECT * FROM leasing_contract WHERE id = leas_contract_id INTO contract_ids;
        SELECT commercial_partner_id FROM res_partner WHERE id = contract_ids.debtor_id INTO vcpartner_id;
        -- loan line
        FOR leasing_loan_ids IN SELECT * FROM leasing_contract_line WHERE contract_id = contract_ids.id ORDER BY ID
        LOOP
            SELECT * FROM aggregation_table WHERE id = leasing_loan_ids.middleware_id INTO data_aggregation;
            SELECT id FROM mofi_order_type WHERE code ilike data_aggregation.order_type INTO vordertype;
            SELECT id FROM mofi_suborder_type WHERE code ilike data_aggregation.sub_order_type INTO vsuborder;
            SELECT id FROM mofi_fee_type WHERE code ilike data_aggregation.fee_type INTO vfeetype;
            SELECT id FROM mofi_payment_channel WHERE code ilike data_aggregation.payment_channel INTO vpaymentchannel;
            SELECT id FROM account_journal WHERE technical_code ilike data_aggregation.account_no INTO vaccountjournal;
            SELECT id FROM mofi_funding_type WHERE code ilike data_aggregation.funding_type INTO vfundtype;
            SELECT id FROM mofi_branch WHERE code ilike data_aggregation.branch INTO vbranch;
            SELECT id FROM mofi_channel WHERE code ilike data_aggregation.channel INTO vchannel;
            SELECT id FROM mofi_loan_purpose WHERE code ilike data_aggregation.loan_purpose INTO vloanpurpose;
            SELECT * FROM account_move WHERE id = leasing_loan_ids.account_move_id INTO loan_move_ids;
            
            IF contract_ids.debtor_id IS NOT NULL THEN
                SELECT rc.currency_id FROM res_company rc JOIN res_partner rp ON rp.company_id = rc.id WHERE rp.id = contract_ids.debtor_id INTO currency;
            ELSE
                SELECT currency_id FROM res_company WHERE id = 1 INTO currency;
            END IF;

            IF loan_move_ids.id IS NOT NULL THEN
                IF loan_move_ids.state = 'posted' THEN
                    PERFORM unreconcile_journal(loan_move_ids.id);
                    PERFORM create_journal_reverse(loan_move_ids.id);
                ELSE
                    PERFORM create_log_message('account.move', loan_move_ids.state, 'Cancel', loan_move_ids.id, 'status');
                    UPDATE account_move SET 
                        state = 'cancel',
                        write_date = now()
                        WHERE id = loan_move_ids.id;
                    UPDATE account_move_line SET
                        parent_state = 'cancel',
                        write_date = now()
                        WHERE move_id = loan_move_ids.id;
                END IF;
            END IF;
            
            UPDATE leasing_contract_line SET
                order_type_id = vordertype, 
                suborder_type_id = vsuborder, 
                fee_type_id = vfeetype, 
                amount = data_aggregation.amount, 
                payment_channel_id = vpaymentchannel,
                order_date = data_aggregation.order_date, 
                leasing_line_id = data_aggregation.order_id, 
                account_journal_id = vaccountjournal, 
                currency_id = currency,
                account_move_id = null,
                write_date = now() at time zone 'utc'
            WHERE id = leasing_loan_ids.id;
        END LOOP;
        
        -- payment
        FOR leasing_payment_ids IN SELECT * FROM leasing_contract_payment WHERE contract_id = contract_ids.id ORDER BY ID
        LOOP
            SELECT * FROM aggregation_table WHERE id = leasing_payment_ids.middleware_id INTO data_aggregation;
            SELECT id FROM mofi_order_type WHERE code ilike data_aggregation.order_type INTO vordertype;
            SELECT id FROM mofi_suborder_type WHERE code ilike data_aggregation.sub_order_type INTO vsuborder;
            SELECT id FROM mofi_fee_type WHERE code ilike data_aggregation.fee_type INTO vfeetype;
            SELECT id FROM mofi_payment_channel WHERE code ilike data_aggregation.payment_channel INTO vpaymentchannel;
            SELECT id FROM account_journal WHERE technical_code ilike data_aggregation.account_no INTO vaccountjournal;
            SELECT id FROM mofi_funding_type WHERE code ilike data_aggregation.funding_type INTO vfundtype;
            SELECT id FROM mofi_branch WHERE code ilike data_aggregation.branch INTO vbranch;
            SELECT id FROM mofi_channel WHERE code ilike data_aggregation.channel INTO vchannel;
            SELECT id FROM mofi_loan_purpose WHERE code ilike data_aggregation.loan_purpose INTO vloanpurpose;
            SELECT * FROM account_move WHERE id = leasing_payment_ids.account_move_id INTO loan_move_ids;
            
            IF contract_ids.debtor_id IS NOT NULL THEN
                SELECT rc.currency_id FROM res_company rc JOIN res_partner rp ON rp.company_id = rc.id WHERE rp.id = contract_ids.debtor_id INTO currency;
            ELSE
                SELECT currency_id FROM res_company WHERE id = 1 INTO currency;
            END IF;

            IF loan_move_ids.id IS NOT NULL THEN
                IF loan_move_ids.state = 'posted' THEN
                    PERFORM unreconcile_journal(loan_move_ids.id);
                    PERFORM create_journal_reverse(loan_move_ids.id);
                ELSE
                    PERFORM create_log_message('account.move', loan_move_ids.state, 'Cancel', loan_move_ids.id, 'state');
                    UPDATE account_move SET 
                        state = 'cancel',
                        write_date = now() at time zone 'utc'
                        WHERE id = loan_move_ids.id;
                    UPDATE account_move_line SET
                        parent_state = 'cancel',
                        write_date = now() at time zone 'utc'
                        WHERE move_id = loan_move_ids.id;
                END IF;
            END IF;
            UPDATE leasing_contract_payment SET
                order_type_id = vordertype, 
                suborder_type_id = vsuborder, 
                fee_type_id = vfeetype, 
                amount = data_aggregation.amount, 
                payment_channel_id = vpaymentchannel,
                order_date = data_aggregation.order_date, 
                leasing_line_id = data_aggregation.order_id, 
                account_journal_id = vaccountjournal, 
                currency_id = currency,
                account_move_id = null,
                write_date = now() at time zone 'utc'
            WHERE id = leasing_payment_ids.id;
        END LOOP;
        
        FOR leasing_interest_ids IN SELECT * FROM leasing_contract_interest WHERE contract_id = contract_ids.id ORDER BY ID
        LOOP
            SELECT * FROM account_move WHERE id = leasing_interest_ids.eom_account_move_id INTO eom_move_ids;
            SELECT * FROM account_move WHERE id = leasing_interest_ids.journal_account_move_id INTO journal_move_ids;
            
            IF leasing_interest_ids.eom_account_move_id IS NOT NULL THEN
                IF eom_move_ids.state = 'posted' THEN
                    PERFORM unreconcile_journal(eom_move_ids.id);
                    PERFORM create_journal_reverse(eom_move_ids.id);
                ELSE
                    PERFORM create_log_message('account.move', eom_move_ids.state, 'Cancel', eom_move_ids.id, 'state');
                    UPDATE account_move SET 
                        state = 'cancel',
                        write_date = now() at time zone 'utc'
                        WHERE id = eom_move_ids.id;
                    UPDATE account_move_line SET
                        parent_state = 'cancel',
                        write_date = now() at time zone 'utc'
                        WHERE move_id = eom_move_ids.id;
                END IF;
            END IF;
            
            IF leasing_interest_ids.journal_account_move_id IS NOT NULL THEN
                IF eom_move_ids.state = 'posted' THEN
                    PERFORM unreconcile_journal(journal_move_ids.id);
                    PERFORM create_journal_reverse(journal_move_ids.id);
                ELSE
                    PERFORM create_log_message('account.move', journal_move_ids.state, 'Cancel', journal_move_ids.id, 'state');
                    UPDATE account_move SET 
                        state = 'cancel',
                        write_date = now() at time zone 'utc'
                        WHERE id = journal_move_ids.id;
                    UPDATE account_move_line SET
                        parent_state = 'cancel',
                        write_date = now() at time zone 'utc'
                        WHERE move_id = journal_move_ids.id;
                END IF;
            END IF;
            UPDATE leasing_contract_interest SET
                eom_account_move_id = null,
                journal_account_move_id = null,
                write_date = now() at time zone 'utc'
            WHERE id = leasing_interest_ids.id;
        END LOOP;
        
        FOR amortization_ids IN SELECT * FROM mofi_leasing_amortization WHERE ca_contract_number_id = contract_ids.id
        LOOP
            FOR amortization_line_ids IN SELECT * FROM mofi_leasing_amortization_line WHERE amortization_id = amortization_ids.id
            LOOP
                SELECT * FROM account_move WHERE id = amortization_line_ids.id INTO loan_move_ids;
                
                IF amortization_line_ids.account_move_id IS NOT NULL THEN
                    IF loan_move_ids.state = 'posted' THEN
                        PERFORM unreconcile_journal(journal_move_ids.id);
                        PERFORM create_journal_reverse(journal_move_ids.id);
                    ELSE
                        PERFORM create_log_message('account.move', loan_move_ids.state, 'Cancel', loan_move_ids.id, 'state');
                        UPDATE account_move SET 
                            state = 'cancel',
                            write_date = now() at time zone 'utc'
                            WHERE id = loan_move_ids.id;
                        UPDATE account_move_line SET
                            parent_state = 'cancel',
                            write_date = now() at time zone 'utc'
                            WHERE move_id = loan_move_ids.id;
                    END IF;
                END IF;
                
                UPDATE mofi_leasing_amortization_line SET account_move_id = NULL, write_date = now() at time zone 'utc' WHERE id = amortization_line_ids.id;
            END LOOP;
            PERFORM create_log_message('mofi.leasing.amortization', amortization_ids.status, 'Cancel', amortization_ids.id, 'status');
            UPDATE mofi_leasing_amortization SET status = 'canceled' WHERE id = amortization_ids.id;
        END LOOP;
        
    END;
$$;
