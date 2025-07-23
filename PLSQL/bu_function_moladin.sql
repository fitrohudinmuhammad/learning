DROP FUNCTION IF EXISTS insert_logging_error(varchar, int, varchar);
CREATE OR REPLACE FUNCTION public.insert_logging_error(col varchar, order_fee int, fname varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    BEGIN
        INSERT INTO logging_integration (name, filename, description, log_time, error_status)
        VALUES (
            concat('ERROR: Order Fee ID ', order_fee), fname, concat('The columns ', col, ' not found in ODOO'), now(), True
        );
    END;
$$;
--select insert_logging_error('ww', 990, 'coba.csv')

--------------------------------------

DROP FUNCTION IF EXISTS insert_leasing_loan(bigint, int);
CREATE OR REPLACE FUNCTION public.insert_leasing_loan(datid bigint, leasid int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        datas record;
        leas_cont record;
        leas_line int;
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
        amove int;
        amovelinedebit int;
        amovelinecredit int;
    BEGIN
        RAISE NOTICE 'START';
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
        
        UPDATE leasing_contract SET 
        funding_type_id = fundtype, 
        branch_id = branc,
        channel_id = chann,
        loan_purpose_id = loanpur,
        note = datas.description
        WHERE id = leasid;
        
        SELECT * FROM leasing_contract WHERE id = leasid INTO leas_cont;
        
        INSERT INTO leasing_contract_line (
        contract_id, order_type_id, suborder_type_id, fee_type_id, amount, payment_channel_id,
        order_date, leasing_line_id, account_journal_id, currency_id, middleware_id, order_fee_id,
        create_date, write_date
        )
        VALUES (
        leasid, ordertype, suborder, feetype, datas.amount, paychan, datas.order_date, datas.order_id,
        accjour, currency, datas.id, datas.order_fee_id, now(), now()
        ) RETURNING ID INTO leas_line;
        
        UPDATE aggregation_table SET stage = 3 WHERE id = datid;
        
        SELECT mla.id, debit_account_id, credit_account_id, account_journal_id, aj.code, aj.currency_id FROM mofi_leasing_account mla
        JOIN account_journal aj ON aj.id = mla.account_journal_id
        WHERE funding_type_id = fundtype AND channel_id = chann
        AND loan_purpose_id = loanpur AND is_restructure = datas.isrestructure
        AND fee_type_id = feetype LIMIT 1 INTO leas_acc;
        
        raise notice '%', leas_acc;
--         IF leas_acc.id is not null THEN
--             raise notice 'masuk';
--             SELECT 
--                 CASE 
--                     WHEN split_part(name, '/', 3) IS NOT NULL AND length(split_part(name, '/', 3)) = 0 THEN 1
--                     WHEN split_part(name, '/', 2)::int = date_part('year', now())::int THEN split_part(name, '/', 3)::int + 1
--                     WHEN split_part(name, '/', 2)::int = date_part('year', make_date(split_part(name, '/', 2)::int, 1, 1))::int THEN split_part(name, '/', 3)::int + 1
--                     ELSE 0
--                 END as name_seq
--             FROM account_move WHERE journal_id = leas_acc.account_journal_id ORDER BY id desc LIMIT 1 INTO name_seq;
            
--             IF name_seq IS NULL THEN
--                     name_seq := 1;
--                 ELSE
--                     raise notice '%', name_seq;
--                 END IF;

--             SELECT commercial_partner_id FROM res_partner WHERE id = leas_cont.debtor_id INTO cpartner_id;

--             INSERT INTO account_move(
--                 id, name,
--                 partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, currency_id,
--                 sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
--                 amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
--                 date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
--                 amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref
--             )
--             SELECT
--                 nextval('account_move_id_seq'), concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')),
--                 leas_cont.debtor_id, order_date, leas_acc.account_journal_id, 2, 1, currency,
--                 concat(leas_acc.code, '/', date_part('year', order_date::date), '/'), 'entry', '', 0.00, 0.00, amount,
--                 0.00, 0.00, datas.amount, 0.00, 
--                 order_date::date, 'posted', 'not_paid', 'no', 'no_extract_requested', 2, now(), 2, now(),
--                 amount, 0.00, cpartner_id, leas_cont.name
--             FROM aggregation_table WHERE id = datid 
--             ON CONFLICT(id)
--             DO NOTHING RETURNING ID INTO amove;

--             INSERT INTO account_move_line(
--                 id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
--                 move_name, parent_state, name, display_type, date, debit, credit, 
--                 balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
--                 price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
--                 create_uid, create_date, write_uid, write_date
--             )
--             SELECT
--                 nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.debit_account_id, currency, leas_cont.debtor_id,
--                 concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'posted', 'payment from query', 'product', order_date::date, amount, 0.00,
--                 amount, amount, amount, 0.00, 1.00, 0.00,
--                 0.00, 0.00, False, False, False,
--                 2, now(), 2, now()
--             FROM aggregation_table WHERE id = datid
--             ON CONFLICT(id)
--             DO NOTHING RETURNING ID into amovelinedebit;
            
--             INSERT INTO account_move_line(
--                 id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
--                 move_name, parent_state, name, display_type, date, debit, credit, 
--                 balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
--                 price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
--                 create_uid, create_date, write_uid, write_date
--             )
--             SELECT
--                 nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.credit_account_id, currency, leas_cont.debtor_id,
--                 concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'posted', 'payment from query', 'product', order_date::date, 0.00, amount,
--                 -1 * amount, -1 * amount, 0.00, 0.00, 1.00, 0.00,
--                 0.00, 0.00, False, False, False,
--                 2, now(), 2, now()
--             FROM aggregation_table WHERE id = datid
--             ON CONFLICT(id)
--             DO NOTHING RETURNING ID into amovelinecredit;
            
--             UPDATE leasing_contract_line SET account_move_id = amove WHERE id = leas_line;
--             raise notice '%', leas_line;
--             raise notice '%', amove;
--         ELSE
--             raise notice 'tidak';
--             INSERT INTO logging_integration (name, filename, description, log_time, error_status)
--             VALUES (concat('ERROR: Row: ', datas.id, ' & Order ID: ', datas.order_fee_id), datas.filename, 
--                     concat('The Leasing Account with value "', datas.funding_type, ', ', datas.channel, ', ', datas.loan_purpose, ', ', datas.isrestructure, ', ', datas.fee_type, '" not found in ODOO'), now(), True);
--         END IF;
    END;
$$;

--select insert_leasing_loan(107, 47)


DROP FUNCTION IF EXISTS insert_leasing_payment(bigint, int);
CREATE OR REPLACE FUNCTION public.insert_leasing_payment(datid bigint, leasid int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        datas record;
        leas_cont record;
        leas_line int;
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
        amove int;
        amovelinedebit int;
        amovelinecredit int;
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
        
        UPDATE leasing_contract SET 
            funding_type_id = fundtype, 
            branch_id = branc,
            channel_id = chann,
            loan_purpose_id = loanpur,
            note = datas.description
        WHERE id = leasid;
        
        INSERT INTO leasing_contract_payment (
            contract_id, order_type_id, suborder_type_id, fee_type_id, amount, payment_channel_id,
            order_date, leasing_line_id, account_journal_id, currency_id, middleware_id, order_fee_id,
            create_date, write_date
        )
        VALUES (
            leasid, ordertype, suborder, feetype, datas.amount, paychan, datas.order_date, datas.order_id,
            accjour, currency, datas.id, datas.order_fee_id, now(), now()
        ) RETURNING ID INTO leas_line;
        UPDATE aggregation_table SET stage = 3 WHERE id = datid;
        
        SELECT * FROM leasing_contract WHERE id = leasid INTO leas_cont;
        
        SELECT mla.id, debit_account_id, credit_account_id, account_journal_id, aj.code, aj.currency_id FROM mofi_leasing_account mla
        JOIN account_journal aj ON aj.id = mla.account_journal_id
        WHERE funding_type_id = fundtype AND channel_id = chann
        AND loan_purpose_id = loanpur AND is_restructure = datas.isrestructure
        AND fee_type_id = feetype LIMIT 1 INTO leas_acc;
        
        raise notice '%', leas_acc;
--         IF leas_acc.id is not null THEN
--             raise notice 'masuk';
--             SELECT 
--                 CASE 
--                     WHEN split_part(name, '/', 3) IS NOT NULL AND length(split_part(name, '/', 3)) = 0 THEN 1
--                     WHEN split_part(name, '/', 2)::int = date_part('year', now())::int THEN split_part(name, '/', 3)::int + 1
--                     WHEN split_part(name, '/', 2)::int = date_part('year', make_date(split_part(name, '/', 2)::int, 1, 1))::int THEN split_part(name, '/', 3)::int + 1
--                     ELSE 0
--                 END as name_seq
--             FROM account_move WHERE journal_id = leas_acc.account_journal_id ORDER BY id desc LIMIT 1 INTO name_seq;
            
--             IF name_seq IS NULL THEN
--                     name_seq := 1;
--                 ELSE
--                     raise notice '%', name_seq;
--                 END IF;

--             SELECT commercial_partner_id FROM res_partner WHERE id = leas_cont.debtor_id INTO cpartner_id;

--             INSERT INTO account_move(
--                 id, name,
--                 partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, currency_id,
--                 sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
--                 amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
--                 date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
--                 amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref
--             )
--             SELECT
--                 nextval('account_move_id_seq'), concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')),
--                 leas_cont.debtor_id, order_date, leas_acc.account_journal_id, 2, 1, currency,
--                 concat(leas_acc.code, '/', date_part('year', order_date::date), '/'), 'entry', '', 0.00, 0.00, amount,
--                 0.00, 0.00, datas.amount, 0.00, 
--                 order_date::date, 'posted', 'not_paid', 'no', 'no_extract_requested', 2, now(), 2, now(),
--                 amount, 0.00, cpartner_id, leas_cont.name
--             FROM aggregation_table WHERE id = datid 
--             ON CONFLICT(id)
--             DO NOTHING RETURNING ID INTO amove;

--             INSERT INTO account_move_line(
--                 id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
--                 move_name, parent_state, name, display_type, date, debit, credit, 
--                 balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
--                 price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
--                 create_uid, create_date, write_uid, write_date
--             )
--             SELECT
--                 nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.debit_account_id, currency, leas_cont.debtor_id,
--                 concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'posted', 'payment from query', 'product', order_date::date, amount, 0.00,
--                 amount, amount, amount, 0.00, 1.00, 0.00,
--                 0.00, 0.00, False, False, False,
--                 2, now(), 2, now()
--             FROM aggregation_table WHERE id = datid
--             ON CONFLICT(id)
--             DO NOTHING RETURNING ID into amovelinedebit;
            
--             INSERT INTO account_move_line(
--                 id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
--                 move_name, parent_state, name, display_type, date, debit, credit, 
--                 balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
--                 price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
--                 create_uid, create_date, write_uid, write_date
--             )
--             SELECT
--                 nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, leas_acc.currency_id, leas_acc.credit_account_id, leas_acc.currency_id, leas_cont.debtor_id,
--                 concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'posted', 'payment from query', 'product', order_date::date, 0.00, amount,
--                 -1 * amount, -1 * amount, 0.00, 0.00, 1.00, 0.00,
--                 0.00, 0.00, False, False, False,
--                 2, now(), 2, now()
--             FROM aggregation_table WHERE id = datid
--             ON CONFLICT(id)
--             DO NOTHING RETURNING ID into amovelinecredit;
            
--             UPDATE leasing_contract_payment SET account_move_id = amove WHERE id = leas_line;
--             raise notice '%', leas_line;
--             raise notice '%', amove;
--         ELSE
--             raise notice 'tidak';
--             INSERT INTO logging_integration (name, filename, description, log_time, error_status)
--             VALUES (concat('ERROR: Row: ', datas.id, ' & Order ID: ', datas.order_fee_id), datas.filename, 
--                     concat('The Leasing Account with value "', datas.funding_type, ', ', datas.channel, ', ', datas.loan_purpose, ', ', datas.isrestructure, ', ', datas.fee_type, '" not found in ODOO'), now(), True);
--         END IF;
    END;
$$;

--select insert_leas_payment(14,2)


--------------------------------------

DROP FUNCTION IF EXISTS checking_data_not_found(int, int);
CREATE OR REPLACE FUNCTION public.checking_data_not_found(datarec int, leas_id int)
RETURNS BOOLEAN
LANGUAGE plpgsql AS
$$
    DECLARE
        res boolean;
        dat record;
        funtype int;
        channels int;
        loanpur int;
        branchs int;
        ordertype int;
        suborder int;
        feetype int;
        payment int;
        accountno int;
        leas_id int;
    BEGIN
        res:= false;
        SELECT * FROM aggregation_table WHERE id = datarec INTO dat;
        SELECT id FROM mofi_funding_type WHERE code ilike dat.funding_type INTO funtype;
        SELECT id FROM mofi_channel WHERE code ilike dat.channel INTO channels;
        SELECT id FROM mofi_order_type WHERE code ilike dat.order_type INTO ordertype;
        SELECT id FROM mofi_suborder_type WHERE code ilike dat.sub_order_type INTO suborder;
        SELECT id FROM mofi_fee_type WHERE code ilike dat.fee_type INTO feetype;
        SELECT id FROM account_account WHERE name->>'en_US' ilike dat.account_no INTO accountno;
        SELECT id FROM mofi_payment_channel WHERE code ilike dat.payment_channel INTO payment;
        SELECT id FROM mofi_loan_purpose WHERE code ilike dat.loan_purpose INTO loanpur;
		raise notice '%',funtype;
		raise notice '%',channels;
		raise notice '%',ordertype;
		raise notice '%',suborder;
		raise notice '%',feetype;
		raise notice '%',accountno;
		raise notice '%',payment;
		raise notice '%',loanpur;
        RAISE NOTICE 'Check Master Data';
        IF funtype IS NOT null THEN
            IF channels IS NOT null THEN
                IF ordertype IS NOT null THEN
                    IF suborder IS NOT null THEN
                        IF feetype IS NOT null THEN
                            IF accountno IS NOT null THEN
                                IF loanpur IS NOT null THEN
                                    res:=True;
                                ELSE 
                                    UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                                    INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
                                        VALUES (concat('ERROR: Row: ', dat.id, ' with Order Fee ID: ', dat.order_fee_id), dat.filename, concat('The columns Loan Purpose with value "', dat.loan_purpose, '" not found in ODOO'), now(), True, now(), now());
                                    DELETE FROM leasing_contract WHERE id = leas_id;
                                    RAISE NOTICE 'Loan Purpose IS NULL';
                                END IF;
                            ELSE 
                                UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                                INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
                                    VALUES (concat('ERROR: Row:', dat.id, ' with Order Fee ID: ', dat.order_fee_id), dat.filename, concat('The columns Account No with value "', dat.account_no, '" not found in ODOO'), now(), True, now(), now());
                                DELETE FROM leasing_contract WHERE id = leas_id;
                                RAISE NOTICE 'Account No IS NULL';
                            END IF;
                        ELSE 
                            UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                            INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
                                VALUES (concat('ERROR: Row: ', dat.id, ' with Order Fee ID: ', dat.order_fee_id), dat.filename, concat('The columns Fee Type with value "', dat.fee_type, '" not found in ODOO'), now(), True, now(), now());
                            DELETE FROM leasing_contract WHERE id = leas_id;
                            RAISE NOTICE 'Fee Type IS NULL';
                        END IF;
                    ELSE 
                        UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                        INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
                            VALUES (concat('ERROR: Row: ', dat.id, ' with Order Fee ID: ', dat.order_fee_id), dat.filename, concat('The columns Sub Order Type with value "', dat.sub_order_type, '" not found in ODOO'), now(), True, now(), now());
                        DELETE FROM leasing_contract WHERE id = leas_id;
                        RAISE NOTICE 'Sub Order Type IS NULL';
                    END IF;
                ELSE 
                    UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                    INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
                        VALUES (concat('ERROR: Row: ', dat.id, ' with Order Fee ID: ', dat.order_fee_id), dat.filename, concat('The columns Order Type with value "', dat.order_type, '" not found in ODOO'), now(), True, now(), now());
                    DELETE FROM leasing_contract WHERE id = leas_id;
                    RAISE NOTICE 'Order Type IS NULL';
                END IF;
            ELSE 
                UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
                    VALUES (concat('ERROR: Row: ', dat.id, ' with Order Fee ID: ', dat.order_fee_id), dat.filename, concat('The columns Channel with value "', dat.channel, '" not found in ODOO'), now(), True, now(), now());
                DELETE FROM leasing_contract WHERE id = leas_id;
                RAISE NOTICE 'Channel IS NULL';
            END IF;
        ELSE 
            UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
            INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
                VALUES (concat('ERROR: Row: ', dat.id, ' with Order Fee ID: ', dat.order_fee_id), dat.filename, concat('The columns Funding Type with value "', dat.funding_type, '" not found in ODOO'), now(), True, now(), now());
            DELETE FROM leasing_contract WHERE id = leas_id;
            RAISE NOTICE 'Funding Type IS NULL';
        END IF;
        RETURN res;
    END;
$$;

--SELECT checking_data_not_found(1,2)

--------------------------------------


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
		acc_debit_type int;
		acc_credit_type int;
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
							WHEN split_part(name, '/', 2)::int = date_part('year', now())::int THEN split_part(name, '/', 3)::int + 1
							WHEN split_part(name, '/', 2)::int = date_part('year', make_date(split_part(name, '/', 2)::int, 1, 1))::int THEN split_part(name, '/', 3)::int + 1
							ELSE 0
						END as name_seq
					FROM account_move WHERE journal_id = leas_acc.account_journal_id ORDER BY id desc LIMIT 1 INTO name_seq;

					IF name_seq IS NULL THEN
						name_seq := 1;
					ELSE
						raise notice '%', name_seq;
					END IF;

					SELECT commercial_partner_id FROM res_partner WHERE id = leas_cont.debtor_id INTO cpartner_id;

					IF last_move.state = 'draft' THEN
						UPDATE account_move SET date = leas_line.order_date, amount_total = leas_line.amount, amount_total_signed = leas_line.amount, amount_total_in_currency_signed = leas_line.amount WHERE id = last_move.id;
						UPDATE account_move_line SET date = leas_line.order_date, debit = leas_line.amount, balance = leas_line.amount, amount_currency = leas_line.amount, amount_residual = leas_line.amount WHERE move_id = last_move.id and credit = 0;
						UPDATE account_move_line SET date = leas_line.order_date, credit = leas_line.amount, balance = leas_line.amount, amount_currency = leas_line.amount, amount_residual = leas_line.amount WHERE move_id = last_move.id and debit = 0;
						amove := last_move.id;
					ELSE
						SELECT CASE WHEN account_type = 'asset_receivable' THEN 1 WHEN account_type = 'liability_payable' THEN 2 ELSE 3 END as data FROM account_account WHERE id = leas_acc.debit_account_id INTO acc_debit_type;
						SELECT CASE WHEN account_type = 'asset_receivable' THEN 1 WHEN account_type = 'liability_payable' THEN 2 ELSE 3 END as data FROM account_account WHERE id = leas_acc.credit_account_id INTO acc_credit_type;
						FOR move_line IN SELECT * FROM account_move_line WHERE move_id = last_move.id ORDER BY id
						LOOP
							IF move_line.reconciled IS true THEN
								UPDATE account_move_line SET reconciled = false, full_reconcile_id = null WHERE full_reconcile_id = move_line.full_reconcile_id;
								DELETE FROM account_full_reconcile WHERE id = move_line.full_reconcile_id;
							ELSE
								raise notice 'Belum di reconcile';
							END IF:
						END LOOP;
						
						INSERT INTO account_move(
							id, name,
							partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, currency_id,
							sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
							amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
							date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
							amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref, reserved_entry_id
						)
						SELECT
							nextval('account_move_id_seq'), concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')),
							leas_cont.debtor_id, order_date, leas_acc.account_journal_id, 2, 1, currency,
							concat(leas_acc.code, '/', date_part('year', order_date::date), '/'), 'entry', '', 0.00, 0.00, amount,
							0.00, 0.00, datas.amount, 0.00, 
							order_date::date, 'draft', 'not_paid', 'no', 'no_extract_requested', 2, now(), 2, now(),
							amount, 0.00, cpartner_id, concat('Reversal of: ', last_move.name, last_move.id)
						FROM aggregation_table WHERE id = datid 
						ON CONFLICT(id)
						DO NOTHING RETURNING ID INTO amove;

						INSERT INTO account_move_line(
							id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
							move_name, parent_state, name, display_type, date, debit, credit, 
							balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
							price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
							create_uid, create_date, write_uid, write_date, due_date
						)
						SELECT
							nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.debit_account_id, currency, leas_cont.debtor_id,
							concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'draft', 'payment from query', 'product', order_date::date, amount, 0.00,
							amount, amount, amount, 0.00, 1.00, 0.00,
							0.00, 0.00, False, False, False,
							2, now(), 2, now(), CASE WHEN acc_debit_type = 1 THEN end_date WHEN acc_debit_type = 2 THEN order_date ELSE null END AS due_date
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
							concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'draft', 'payment from query', 'product', order_date::date, 0.00, amount
							-1 * amount, -1 * amount, 0.00, 0.00, 1.00, 0.00,
							0.00, 0.00, False, False, False,
							2, now(), 2, now(), CASE WHEN acc_credit_type = 1 THEN end_date WHEN acc_credit_type = 2 THEN order_date ELSE null END AS due_date
						FROM aggregation_table WHERE id = datid
						ON CONFLICT(id)
						DO NOTHING;
					END IF;

					UPDATE leasing_contract_line SET account_move_id = amove WHERE id = leas_line.id;
				ELSE
					INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
					VALUES (concat('ERROR: Row: ', datas.id, '& Order ID: ', datas.order_fee_id), datas.filename, 
						concat('The Leasing Account with value "', datas.funding_type, ', ', 
						datas.channel, ', ', datas.loan_purpose, ', ', datas.isrestructure, ', ', datas.fee_type, '" not found in ODOO'), 
						now(), True, now(), now());
				END IF;
			ELSE
				RAISE NOTICE 'Continue';
			END IF;
        ELSE
			RAISE NOTICE 'Continue';
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
--                 ELSE
--                     raise notice '%', name_seq;
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
--                     -1 * amount, -1 * amount, 0.00, 0.00, 1.00, 0.00,
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
                write_date = now()
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
                write_date = now()
            WHERE middleware_id = datas.id and order_fee_id = datas.order_fee_id;
        END IF;
        UPDATE aggregation_table SET stage = 3 WHERE id = datid;
    END;
$$;

--select update_leasing_contract(360)


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
							WHEN split_part(name, '/', 3) IS NOT NULL AND length(split_part(name, '/', 3)) = 0 THEN 1
							WHEN split_part(name, '/', 2)::int = date_part('year', now())::int THEN split_part(name, '/', 3)::int + 1
							WHEN split_part(name, '/', 2)::int = date_part('year', make_date(split_part(name, '/', 2)::int, 1, 1))::int THEN split_part(name, '/', 3)::int + 1
							ELSE 0
						END as name_seq
					FROM account_move WHERE journal_id = leas_acc.account_journal_id ORDER BY id desc LIMIT 1 INTO name_seq;

					IF name_seq IS NULL THEN
						name_seq := 1;
					ELSE
						raise notice '%', name_seq;
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
							order_date::date, 'draft', 'not_paid', 'no', 'no_extract_requested', 2, now(), 2, now(),
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
							2, now(), 2, now()
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
							-1 * amount, -1 * amount, 0.00, 0.00, 1.00, 0.00,
							0.00, 0.00, False, False, False,
							2, now(), 2, now()
						FROM aggregation_table WHERE id = datid
						ON CONFLICT(id)
						DO NOTHING;
					END IF;

					UPDATE leasing_contract_payment SET account_move_id = amove WHERE id = leas_line.id;
				ELSE
					INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
					VALUES (concat('ERROR: Row: ', datas.id, ' & Order ID: ', datas.order_fee_id), datas.filename, 
						concat('The Leasing Account with value "', datas.funding_type, ', ', 
						datas.channel, ', ', datas.loan_purpose, ', ', datas.isrestructure, ', ', datas.fee_type, '" not found in ODOO'), 
						now(), True, now(), now());
				END IF;
			ELSE
				RAISE NOTICE 'Continue';
			END IF;
         ELSE
		 	RAISE NOTICE ' Continue';
-- 			IF leas_cont = 'active' THEN
-- 				IF leas_acc.id IS NOT NULL THEN
-- 					SELECT 
-- 						CASE 
-- 							WHEN split_part(name, '/', 3) IS NOT NULL AND length(split_part(name, '/', 3)) = 0 THEN 1
-- 							WHEN split_part(name, '/', 2)::int = date_part('year', now())::int THEN split_part(name, '/', 3)::int + 1
-- 							WHEN split_part(name, '/', 2)::int = date_part('year', make_date(split_part(name, '/', 2)::int, 1, 1))::int THEN split_part(name, '/', 3)::int + 1
-- 							ELSE 0
-- 						END as name_seq
-- 					FROM account_move WHERE journal_id = leas_acc.account_journal_id ORDER BY id desc LIMIT 1 INTO name_seq;

-- 					IF name_seq IS NULL THEN
-- 						name_seq := 1;
-- 					ELSE
-- 						raise notice '%', name_seq;
-- 					END IF;

-- 					SELECT commercial_partner_id FROM res_partner WHERE id = leas_cont.debtor_id INTO cpartner_id;

-- 					INSERT INTO account_move(
-- 						id, name,
-- 						partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, currency_id,
-- 						sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
-- 						amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
-- 						date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
-- 						amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref
-- 					)
-- 					SELECT
-- 						nextval('account_move_id_seq'), concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')),
-- 						leas_cont.debtor_id, order_date, leas_acc.account_journal_id, 2, 1, currency,
-- 						concat(leas_acc.code, '/', date_part('year', order_date::date), '/'), 'entry', '', 0.00, 0.00, amount,
-- 						0.00, 0.00, datas.amount, 0.00, 
-- 						order_date::date, 'draft', 'not_paid', 'no', 'no_extract_requested', 2, now(), 2, now(),
-- 						amount, 0.00, cpartner_id, leas_cont.name
-- 					FROM aggregation_table WHERE id = datid 
-- 					ON CONFLICT(id)
-- 					DO NOTHING RETURNING ID INTO amove;

-- 					INSERT INTO account_move_line(
-- 						id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
-- 						move_name, parent_state, name, display_type, date, debit, credit, 
-- 						balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
-- 						price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
-- 						create_uid, create_date, write_uid, write_date
-- 					)
-- 					SELECT
-- 						nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.debit_account_id, currency, leas_cont.debtor_id,
-- 						concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'draft', 'payment from query', 'product', order_date::date, amount, 0.00,
-- 						amount, amount, amount, 0.00, 1.00, 0.00,
-- 						0.00, 0.00, False, False, False,
-- 						2, now(), 2, now()
-- 					FROM aggregation_table WHERE id = datid
-- 					ON CONFLICT(id)
-- 					DO NOTHING;

-- 					INSERT INTO account_move_line(
-- 						id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
-- 						move_name, parent_state, name, display_type, date, debit, credit, 
-- 						balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
-- 						price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
-- 						create_uid, create_date, write_uid, write_date
-- 					)
-- 					SELECT
-- 						nextval('account_move_line_id_seq'), amove, leas_acc.account_journal_id, 1, currency, leas_acc.credit_account_id, currency, leas_cont.debtor_id,
-- 						concat(leas_acc.code, '/', date_part('year', order_date::date), '/', LPAD(name_seq, 5, '0')), 'draft', 'payment from query', 'product', order_date::date, 0.00, amount,
-- 						-1 * amount, -1 * amount, 0.00, 0.00, 1.00, 0.00,
-- 						0.00, 0.00, False, False, False,
-- 						2, now(), 2, now()
-- 					FROM aggregation_table WHERE id = datid
-- 					ON CONFLICT(id)
-- 					DO NOTHING;

-- 					UPDATE leasing_contract_payment SET account_move_id = amove WHERE id = leas_line.id;
-- 				ELSE
-- 					INSERT INTO logging_integration (name, filename, description, log_time, error_status, create_date, write_date)
-- 					VALUES (concat('ERROR: Row: ', datas.id, ' & Order ID: ', datas.order_fee_id), datas.filename, 
-- 						concat('The Leasing Account with value "', datas.funding_type, ', ', 
-- 						datas.channel, ', ', datas.loan_purpose, ', ', datas.isrestructure, ', ', datas.fee_type, '" not found in ODOO'), 
-- 						now(), True, now(), now());
-- 				END IF;
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
                write_date = now()
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
                write_date = now()
            WHERE middleware_id = datas.id and order_fee_id = datas.order_fee_id;
        END IF;
        UPDATE aggregation_table SET stage = 3 WHERE id = datid;
    END;
$$;

--select update_leasing_payment(360)

--

DROP FUNCTION IF EXISTS checking_contract_create(int);
CREATE OR REPLACE FUNCTION public.checking_contract_create(leasid int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        loan_ids int;
        payment_ids int;
    BEGIN
        SELECT id FROM leasing_contract_line WHERE contract_id = leasid LIMIT 1 INTO loan_ids;
        SELECT id FROM leasing_contract_payment WHERE contract_id = leasid LIMIT 1 INTO payment_ids;
        IF loan_ids IS NULL AND payment_ids IS NULL THEN
            DELETE FROM leasing_contract WHERE id = leasid;
        ELSE
            raise notice 'Created';
        END IF;
    END;
$$;

--select checking_contract_create(21)


--

DROP FUNCTION IF EXISTS process_update_stage_after_insert(varchar);
CREATE OR REPLACE FUNCTION public.process_update_stage_after_insert(fname varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    BEGIN
        UPDATE aggregation_table set stage = 3, is_create = false, is_update = false
        WHERE id in 
            (SELECT middleware_id FROM leasing_contract_line 
                WHERE write_date >= concat(current_date, ' 00:00:00')::timestamp 
                    AND write_date < concat(current_date, ' 23:59:59')::timestamp
            ) AND stage = 1 AND filename = fname;
            
        UPDATE aggregation_table set stage = 3, is_create = false, is_update = false
        WHERE id in 
            (SELECT middleware_id FROM leasing_contract_payment 
                WHERE write_date >= concat(current_date, ' 00:00:00')::timestamp 
                    AND write_date < concat(current_date, ' 23:59:59')::timestamp
            ) AND stage = 1 AND filename = fname;
            
        --UPDATE aggregation_table SET is_create = false, is_update = false
        --WHERE stage = 1 AND filename = fname;
    END;
$$;

--select process_update_stage_after_insert('20231102-1140.csv')
