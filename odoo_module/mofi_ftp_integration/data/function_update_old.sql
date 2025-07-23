DROP FUNCTION IF EXISTS update_leasing_contract(bigint);
CREATE OR REPLACE FUNCTION public.update_leasing_contract(datid bigint)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        datas record;
        leas_cont record;
        leas_line record;
        ordertype int;
        suborder int;
        feetype int;
        paychan int;
        accjour int;
        currency int;
        fundtype int;
        chann int;
        loanpur int;
        branc int;
        leas_acc record;
        name_seq varchar;
        cpartner_id int;
        last_move record;
        amove int;
    BEGIN
        SELECT * FROM aggregation_table WHERE id = datid INTO datas;
        SELECT id FROM mofi_order_type WHERE code ilike datas.order_type INTO ordertype;
        SELECT id FROM mofi_suborder_type WHERE code ilike datas.sub_order_type INTO suborder;
        SELECT id FROM mofi_fee_type WHERE code ilike datas.fee_type INTO feetype;
        SELECT id FROM mofi_payment_channel WHERE code ilike datas.payment_channel INTO paychan;
        SELECT id FROM account_journal WHERE name->>'en_US' ilike datas.account_no INTO accjour;
        SELECT currency_id FROM account_journal WHERE name->>'en_US' ilike datas.account_no INTO currency;
        SELECT id FROM mofi_funding_type WHERE code ilike datas.funding_type INTO fundtype;
        SELECT id FROM mofi_branch WHERE code ilike datas.branch INTO branc;
        SELECT id FROM mofi_channel WHERE code ilike datas.channel INTO chann;
        SELECT id FROM mofi_loan_purpose WHERE code ilike datas.loan_purpose INTO loanpur;
        
        SELECT * FROM leasing_contract_line WHERE middleware_id = datas.id AND order_fee_id = datas.order_fee_id INTO leas_line;
        SELECT * FROM leasing_contract WHERE id = leas_line.contract_id INTO leas_cont;
        
        SELECT mla.id, debit_account_id, credit_account_id, account_journal_id, aj.code
        FROM mofi_leasing_account mla
        JOIN account_journal aj ON aj.id = mla.account_journal_id
        WHERE funding_type_id = fundtype AND channel_id = chann
        AND loan_purpose_id = loanpur AND is_restructure = datas.isrestructure
        AND fee_type_id = feetype LIMIT 1 INTO leas_acc;
        
        IF leas_line.account_move_id IS NOT NULL THEN
            --UPDATE account_move SET contract_id = null WHERE id = leas_line.account_move_id;
            SELECT * FROM account_move WHERE id = leas_line.account_move_id INTO last_move;
            IF leas_cont.status = 'active' THEN
                IF leas_acc.id IS NOT NULL THEN
                    SELECT 
                        CASE 
                            WHEN split_part(name, '/', 3) IS NOT NULL AND length(split_part(name, '/', 3)) = 0 THEN 1
                            WHEN split_part(name, '/', 2)::int = date_part('year', now() at time zone 'utc')::int THEN split_part(name, '/', 3)::int + 1
                            WHEN split_part(name, '/', 2)::int = date_part('year', make_date(split_part(name, '/', 2)::int, 1, 1))::int THEN split_part(name, '/', 3)::int + 1
                            ELSE 0
                        END as name_seq
                    FROM account_move WHERE journal_id = leas_acc.account_journal_id ORDER BY id desc LIMIT 1 INTO name_seq;

                    IF name_seq IS NULL THEN
                        name_seq := 1;
                    END IF;

                    SELECT commercial_partner_id FROM res_partner WHERE id = leas_cont.debtor_id INTO cpartner_id;

                    IF last_move.state = 'draft' THEN
                        UPDATE account_move SET date = leas_line.order_date, amount_total = leas_line.amount, amount_total_signed = leas_line.amount, amount_total_in_currency_signed = leas_line.amount WHERE id = last_move.id;
                        UPDATE account_move_line SET date = leas_line.order_date, debit = leas_line.amount, balance = leas_line.amount, amount_currency = leas_line.amount, amount_residual = leas_line.amount WHERE move_id = last_move.id and credit = 0;
                        UPDATE account_move_line SET date = leas_line.order_date, credit = leas_line.amount, balance = leas_line.amount, amount_currency = leas_line.amount, amount_residual = leas_line.amount WHERE move_id = last_move.id and debit = 0;
                        amove := last_move.id;
                    ELSE
                        INSERT INTO account_move(
                            id, name,
                            partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, currency_id,
                            sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
                            amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
                            date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
                            amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref
                        )
                        SELECT
                            nextval('account_move_id_seq'), concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')),
                            leas_cont.debtor_id, order_date, leas_acc.account_journal_id, 2, 1, currency,
                            concat(leas_acc.code, '/', date_part('year', order_date::date), '/'), 'entry', '', 0.00, 0.00, amount,
                            0.00, 0.00, datas.amount, 0.00, 
                            order_date::date, 'draft', 'not_paid', 'no', 'no_extract_requested', 2, now() at time zone 'utc', 2, now() at time zone 'utc',
                            amount, 0.00, cpartner_id, concat('Reversal of: ', last_move.name)
                        FROM aggregation_table WHERE id = datid 
                        ON CONFLICT(id)
                        DO NOTHING RETURNING ID INTO amove;

                        INSERT INTO account_move_line(
                            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                            move_name, parent_state, name, display_type, date, debit, credit, 
                            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                            create_uid, create_date, write_uid, write_date
                        )
                        SELECT
                            nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.debit_account_id, currency, leas_cont.debtor_id,
                            concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'draft', 'payment from query', 'product', order_date::date, amount, 0.00,
                            amount, amount, amount, 0.00, 1.00, 0.00,
                            0.00, 0.00, False, False, False,
                            2, now() at time zone 'utc', 2, now() at time zone 'utc'
                        FROM aggregation_table WHERE id = datid
                        ON CONFLICT(id)
                        DO NOTHING;

                        INSERT INTO account_move_line(
                            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                            move_name, parent_state, name, display_type, date, debit, credit, 
                            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                            create_uid, create_date, write_uid, write_date
                        )
                        SELECT
                            nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.credit_account_id, currency, leas_cont.debtor_id,
                            concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'draft', 'payment from query', 'product', order_date::date, 0.00, amount,
                            -1 * amount, -1 * amount, -1 * amount, 0.00, 1.00, 0.00,
                            0.00, 0.00, False, False, False,
                            2, now() at time zone 'utc', 2, now() at time zone 'utc'
                        FROM aggregation_table WHERE id = datid
                        ON CONFLICT(id)
                        DO NOTHING;
                    END IF;

                    UPDATE leasing_contract_line SET account_move_id = amove WHERE id = leas_line.id;
                ELSE
                    INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date)
                    VALUES ('ERROR: Update Loan Leasing', datas.id, datas.order_fee_id, datas.filename, 
                        concat('The Leasing Account with value "', datas.funding_type, ', ', 
                        datas.channel, ', ', datas.loan_purpose, ', ', datas.isrestructure, ', ', datas.fee_type, '" not found in ODOO'), 
                        now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc');
                END IF;
            END IF;
--             IF leas_acc.id IS NOT NULL THEN
--                 SELECT 
--                     CASE 
--                         WHEN split_part(name, '/', 3) IS NOT NULL AND length(split_part(name, '/', 3)) = 0 THEN 1
--                         WHEN split_part(name, '/', 2)::int = date_part('year', now())::int THEN split_part(name, '/', 3)::int + 1
--                         WHEN split_part(name, '/', 2)::int = date_part('year', make_date(split_part(name, '/', 2)::int, 1, 1))::int THEN split_part(name, '/', 3)::int + 1
--                         ELSE 0
--                     END as name_seq
--                 FROM account_move WHERE journal_id = leas_acc.account_journal_id ORDER BY id desc LIMIT 1 INTO name_seq;
                
--                 IF name_seq IS NULL THEN
--                     name_seq := 1;
--                 END IF;

--                 SELECT commercial_partner_id FROM res_partner WHERE id = leas_cont.debtor_id INTO cpartner_id;

--                 INSERT INTO account_move(
--                     id, name,
--                     partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, currency_id,
--                     sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
--                     amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
--                     date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
--                     amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref
--                 )
--                 SELECT
--                     nextval('account_move_id_seq'), concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')),
--                     leas_cont.debtor_id, order_date, leas_acc.account_journal_id, 2, 1, currency,
--                     concat(leas_acc.code, '/', date_part('year', order_date::date), '/'), 'entry', '', 0.00, 0.00, amount,
--                     0.00, 0.00, datas.amount, 0.00, 
--                     order_date::date, 'draft', 'not_paid', 'no', 'no_extract_requested', 2, now(), 2, now(),
--                     amount, 0.00, cpartner_id, leas_cont.name
--                 FROM aggregation_table WHERE id = datid 
--                 ON CONFLICT(id)
--                 DO NOTHING RETURNING ID INTO amove;

--                 INSERT INTO account_move_line(
--                     id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
--                     move_name, parent_state, name, display_type, date, debit, credit, 
--                     balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
--                     price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
--                     create_uid, create_date, write_uid, write_date
--                 )
--                 SELECT
--                     nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.debit_account_id, currency, leas_cont.debtor_id,
--                     concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'draft', 'payment from query', 'product', order_date::date, amount, 0.00,
--                     amount, amount, amount, 0.00, 1.00, 0.00,
--                     0.00, 0.00, False, False, False,
--                     2, now(), 2, now()
--                 FROM aggregation_table WHERE id = datid
--                 ON CONFLICT(id)
--                 DO NOTHING;

--                 INSERT INTO account_move_line(
--                     id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
--                     move_name, parent_state, name, display_type, date, debit, credit, 
--                     balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
--                     price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
--                     create_uid, create_date, write_uid, write_date
--                 )
--                 SELECT
--                     nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.credit_account_id, currency, leas_cont.debtor_id,
--                     concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'draft', 'payment from query', 'product', order_date::date, 0.00, amount,
--                     -1 * amount, -1 * amount, -1 * amount, 0.00, 1.00, 0.00,
--                     0.00, 0.00, False, False, False,
--                     2, now(), 2, now()
--                 FROM aggregation_table WHERE id = datid
--                 ON CONFLICT(id)
--                 DO NOTHING;

--                 UPDATE leasing_contract_line SET account_move_id = amove WHERE id = leas_line.id;
--             ELSE
--                 INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
--                 VALUES (concat('ERROR: Row: ', datas.id, ' & Order ID: ', datas.order_fee_id), datas.filename, 
--                     concat('The Leasing Account with value "', datas.funding_type, ', ', 
--                     datas.channel, ', ', datas.loan_purpose, ', ', datas.isrestructure, ', ', datas.fee_type, '" not found in ODOO'), 
--                     now(), True, now(), now());
--             END IF;
        END IF;
        
        IF leas_line.account_move_id IS NOT NULL THEN
            UPDATE leasing_contract_line SET
                order_type_id = ordertype, 
                suborder_type_id = suborder, 
                fee_type_id = feetype, 
                amount = datas.amount, 
                payment_channel_id = paychan,
                order_date = datas.order_date, 
                leasing_line_id = datas.order_id, 
                account_journal_id = accjour, 
                currency_id = currency,
                account_move_id = amove,
                write_date = now() at time zone 'utc'
            WHERE middleware_id = datas.id and order_fee_id = datas.order_fee_id;
        ELSE
            UPDATE leasing_contract_line SET
                order_type_id = ordertype, 
                suborder_type_id = suborder, 
                fee_type_id = feetype, 
                amount = datas.amount, 
                payment_channel_id = paychan,
                order_date = datas.order_date, 
                leasing_line_id = datas.order_id, 
                account_journal_id = accjour, 
                currency_id = currency,
                write_date = now() at time zone 'utc'
            WHERE middleware_id = datas.id and order_fee_id = datas.order_fee_id;
        END IF;
        UPDATE aggregation_table SET stage = 3 WHERE id = datid;
    END;
$$;

--select update_leasing_contract(360)
------------------------------------

DROP FUNCTION IF EXISTS update_leasing_payment(bigint);
CREATE OR REPLACE FUNCTION public.update_leasing_payment(datid bigint)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        datas record;
        leas_cont record;
        leas_line record;
        ordertype int;
        suborder int;
        feetype int;
        paychan int;
        accjour int;
        currency int;
        fundtype int;
        chann int;
        loanpur int;
        branc int;
        leas_acc record;
        name_seq varchar;
        cpartner_id int;
        last_move record;
        amove int;
    BEGIN
        SELECT * FROM aggregation_table WHERE id = datid INTO datas;
        SELECT id FROM mofi_order_type WHERE code ilike datas.order_type INTO ordertype;
        SELECT id FROM mofi_suborder_type WHERE code ilike datas.sub_order_type INTO suborder;
        SELECT id FROM mofi_fee_type WHERE code ilike datas.fee_type INTO feetype;
        SELECT id FROM mofi_payment_channel WHERE code ilike datas.payment_channel INTO paychan;
        SELECT id FROM account_journal WHERE name->>'en_US' ilike datas.account_no INTO accjour;
        SELECT currency_id FROM account_journal WHERE name->>'en_US' ilike datas.account_no INTO currency;
        SELECT id FROM mofi_funding_type WHERE code ilike datas.funding_type INTO fundtype;
        SELECT id FROM mofi_branch WHERE code ilike datas.branch INTO branc;
        SELECT id FROM mofi_channel WHERE code ilike datas.channel INTO chann;
        SELECT id FROM mofi_loan_purpose WHERE code ilike datas.loan_purpose INTO loanpur;
        
        SELECT * FROM leasing_contract_payment WHERE middleware_id = datas.id AND order_fee_id = datas.order_fee_id INTO leas_line;
        SELECT * FROM leasing_contract WHERE id = leas_line.contract_id INTO leas_cont;
        
        SELECT mla.id, debit_account_id, credit_account_id, account_journal_id, aj.code
        FROM mofi_leasing_account mla
        JOIN account_journal aj ON aj.id = mla.account_journal_id
        WHERE funding_type_id = fundtype AND channel_id = chann
        AND loan_purpose_id = loanpur AND is_restructure = datas.isrestructure
        AND fee_type_id = feetype LIMIT 1 INTO leas_acc;
        
        IF leas_line.account_move_id IS NOT NULL THEN
            --UPDATE account_move SET contract_id = null WHERE id = leas_line.account_move_id;
            SELECT * FROM account_move WHERE id = leas_line.account_move_id INTO last_move;
            IF leas_cont.status = 'active' THEN
                IF leas_acc.id IS NOT NULL THEN
                    SELECT 
                        CASE 
                            WHEN split_part(name, '/', 4) IS NOT NULL AND length(split_part(name, '/', 4)) = 0 THEN 1
                            WHEN split_part(name, '/', 2)::int = date_part('year', now() at time zone 'utc')::int THEN split_part(name, '/', 4)::int + 1
                            WHEN split_part(name, '/', 2)::int = date_part('year', make_date(split_part(name, '/', 2)::int, 1, 1))::int THEN split_part(name, '/', 4)::int + 1
                            ELSE 0
                        END as name_seq
                    FROM account_move WHERE journal_id = leas_acc.account_journal_id ORDER BY id desc LIMIT 1 INTO name_seq;

                    IF name_seq IS NULL THEN
                        name_seq := 1;
                    END IF;

                    SELECT commercial_partner_id FROM res_partner WHERE id = leas_cont.debtor_id INTO cpartner_id;
                    IF last_move.state = 'draft' THEN
                        UPDATE account_move SET date = leas_line.order_date, amount_total = leas_line.amount, amount_total_signed = leas_line.amount, amount_total_in_currency_signed = leas_line.amount WHERE id = last_move.id;
                        UPDATE account_move_line SET date = leas_line.order_date, debit = leas_line.amount, balance = leas_line.amount, amount_currency = leas_line.amount, amount_residual = leas_line.amount WHERE move_id = last_move.id and credit = 0;
                        UPDATE account_move_line SET date = leas_line.order_date, credit = leas_line.amount, balance = leas_line.amount, amount_currency = leas_line.amount, amount_residual = leas_line.amount WHERE move_id = last_move.id and debit = 0;
                        amove := last_move.id;
                    ELSE
                        INSERT INTO account_move(
                            id, name,
                            partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, currency_id,
                            sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
                            amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
                            date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
                            amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref
                        )
                        SELECT
                            nextval('account_move_id_seq'), concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')),
                            leas_cont.debtor_id, order_date, leas_acc.account_journal_id, 2, 1, currency,
                            concat(leas_acc.code, '/', date_part('year', order_date::date), '/'), 'entry', '', 0.00, 0.00, amount,
                            0.00, 0.00, datas.amount, 0.00, 
                            order_date::date, 'draft', 'not_paid', 'no', 'no_extract_requested', 2, now() at time zone 'utc', 2, now() at time zone 'utc',
                            amount, 0.00, cpartner_id, concat('Reversal of: ', last_move.name)
                        FROM aggregation_table WHERE id = datid 
                        ON CONFLICT(id)
                        DO NOTHING RETURNING ID INTO amove;

                        INSERT INTO account_move_line(
                            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                            move_name, parent_state, name, display_type, date, debit, credit, 
                            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                            create_uid, create_date, write_uid, write_date
                        )
                        SELECT
                            nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.debit_account_id, currency, leas_cont.debtor_id,
                            concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'draft', 'payment from query', 'product', order_date::date, amount, 0.00,
                            amount, amount, amount, 0.00, 1.00, 0.00,
                            0.00, 0.00, False, False, False,
                            2, now() at time zone 'utc', 2, now() at time zone 'utc'
                        FROM aggregation_table WHERE id = datid
                        ON CONFLICT(id)
                        DO NOTHING;

                        INSERT INTO account_move_line(
                            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                            move_name, parent_state, name, display_type, date, debit, credit, 
                            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                            create_uid, create_date, write_uid, write_date
                        )
                        SELECT
                            nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.credit_account_id, currency, leas_cont.debtor_id,
                            concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'draft', 'payment from query', 'product', order_date::date, 0.00, amount,
                            -1 * amount, -1 * amount, -1 * amount, 0.00, 1.00, 0.00,
                            0.00, 0.00, False, False, False,
                            2, now() at time zone 'utc', 2, now() at time zone 'utc'
                        FROM aggregation_table WHERE id = datid
                        ON CONFLICT(id)
                        DO NOTHING;
                    END IF;

                    UPDATE leasing_contract_payment SET account_move_id = amove WHERE id = leas_line.id;
                ELSE
                    INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date)
                    VALUES ('ERROR: Update Payment Leasing', datas.id, datas.order_fee_id, datas.filename, 
                        concat('The Leasing Account with value "', datas.funding_type, ', ', 
                        datas.channel, ', ', datas.loan_purpose, ', ', datas.isrestructure, ', ', datas.fee_type, '" not found in ODOO'), 
                        now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc');
                END IF;
            END IF;
        END IF;
        
        IF leas_line.account_move_id IS NOT NULL THEN
            UPDATE leasing_contract_payment SET
                order_type_id = ordertype, 
                suborder_type_id = suborder, 
                fee_type_id = feetype, 
                amount = datas.amount, 
                payment_channel_id = paychan,
                order_date = datas.order_date, 
                leasing_line_id = datas.order_id, 
                account_journal_id = accjour, 
                currency_id = currency,
                account_move_id = amove,
                write_date = now() at time zone 'utc'
            WHERE middleware_id = datas.id and order_fee_id = datas.order_fee_id;
        ELSE
            UPDATE leasing_contract_payment SET
                order_type_id = ordertype, 
                suborder_type_id = suborder, 
                fee_type_id = feetype, 
                amount = datas.amount, 
                payment_channel_id = paychan,
                order_date = datas.order_date, 
                leasing_line_id = datas.order_id, 
                account_journal_id = accjour, 
                currency_id = currency,
                write_date = now() at time zone 'utc'
            WHERE middleware_id = datas.id and order_fee_id = datas.order_fee_id;
        END IF;
        UPDATE aggregation_table SET stage = 3 WHERE id = datid;
    END;
$$;

--select update_leasing_payment(360)
------------------------------------