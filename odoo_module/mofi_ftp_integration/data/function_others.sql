DROP FUNCTION IF EXISTS insert_logging_error(varchar, int, varchar);
CREATE OR REPLACE FUNCTION public.insert_logging_error(col varchar, order_fee int, fname varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    BEGIN
        INSERT INTO logging_integration (name, filename, description, log_time, error_status)
        VALUES (
            concat('ERROR: Order Fee ID ', order_fee), fname, concat('The columns ', col, ' not found in ODOO'), now() at time zone 'utc', True
        );
    END;
$$;

--select insert_logging_error('ww', 990, 'coba.csv')
-------------------------------------

DROP FUNCTION IF EXISTS checking_data_not_found(bigint, int);
CREATE OR REPLACE FUNCTION public.checking_data_not_found(datarec bigint, leas_id int)
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
        branc_cek int;
    BEGIN
        res:= false;
        SELECT * FROM aggregation_table WHERE id = datarec INTO dat;
        SELECT id FROM mofi_funding_type WHERE code ilike dat.funding_type INTO funtype;
        SELECT id FROM mofi_channel WHERE code ilike dat.channel INTO channels;
        SELECT id FROM mofi_order_type WHERE code ilike dat.order_type INTO ordertype;
        SELECT id FROM mofi_suborder_type WHERE code ilike dat.sub_order_type INTO suborder;
        SELECT id FROM mofi_fee_type WHERE code ilike dat.fee_type INTO feetype;
        SELECT id FROM account_journal WHERE technical_code ilike dat.account_no INTO accountno;
        SELECT id FROM mofi_payment_channel WHERE code ilike dat.payment_channel INTO payment;
        SELECT id FROM mofi_loan_purpose WHERE code ilike dat.loan_purpose INTO loanpur;
        SELECT id FROM mofi_branch WHERE code ilike dat.branch INTO branchs;

        IF funtype IS NOT null THEN
            IF channels IS NOT null THEN
                IF ordertype IS NOT null THEN
                    IF suborder IS NOT null THEN
                        IF feetype IS NOT null THEN
                            IF accountno IS NOT null THEN
                                IF loanpur IS NOT null THEN
                                    IF branchs IS NOT null THEN
                                        res:=True;
                                        UPDATE leasing_contract SET branch_id = branchs WHERE id = leas_id;
                                    ELSIF dat.branch IS NOT NULL AND length(dat.branch) > 0 THEN
                                        res:= True;
                                        INSERT INTO mofi_branch (name, code, active, create_uid, create_date, write_uid, write_date) VALUES (dat.branch, dat.branch, true, 1, now() at time zone 'utc', 1, now() at time zone 'utc') RETURNING ID INTO branc_cek;
                                        UPDATE leasing_contract SET branch_id = branc_cek WHERE id = leas_id;
                                    ELSE
                                        UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                                        INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date, active, create_uid, write_uid)
                                            VALUES ('ERROR: Master Data ', dat.id, dat.order_fee_id, dat.filename, concat('The columns Branch with value "', dat.branch, '" not found in ODOO'), now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc', true, 1, 1);
                                        DELETE FROM leasing_contract WHERE id = leas_id;
                                    END IF;
                                ELSE 
                                    UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                                    INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date, active, create_uid, write_uid)
                                        VALUES ('ERROR: Master Data ', dat.id, dat.order_fee_id, dat.filename, concat('The columns Loan Purpose with value "', dat.loan_purpose, '" not found in ODOO'), now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc', true, 1, 1);
                                    DELETE FROM leasing_contract WHERE id = leas_id;
                                END IF;
                            ELSE 
                                UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                                INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date, active, create_uid, write_uid)
                                    VALUES ('ERROR: Master Data ', dat.id, dat.order_fee_id, dat.filename, concat('The columns Account No with value "', dat.account_no, '" not found in ODOO'), now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc', true, 1, 1);
                                DELETE FROM leasing_contract WHERE id = leas_id;
                            END IF;
                        ELSE 
                            UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                            INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date, active, create_uid, write_uid)
                                VALUES ('ERROR: Master Data ', dat.id, dat.order_fee_id, dat.filename, concat('The columns Fee Type with value "', dat.fee_type, '" not found in ODOO'), now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc', true, 1, 1);
                            DELETE FROM leasing_contract WHERE id = leas_id;
                        END IF;
                    ELSE 
                        UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                        INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date, active, create_uid, write_uid)
                            VALUES ('ERROR: Master Data ', dat.id, dat.order_fee_id, dat.filename, concat('The columns Sub Order Type with value "', dat.sub_order_type, '" not found in ODOO'), now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc', true, 1, 1);
                        DELETE FROM leasing_contract WHERE id = leas_id;
                    END IF;
                ELSE 
                    UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                    INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date, active, create_uid, write_uid)
                        VALUES ('ERROR: Master Data ', dat.id, dat.order_fee_id, dat.filename, concat('The columns Order Type with value "', dat.order_type, '" not found in ODOO'), now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc', true, 1, 1);
                    DELETE FROM leasing_contract WHERE id = leas_id;
                END IF;
            ELSE 
                UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
                INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date, active, create_uid, write_uid)
                    VALUES ('ERROR: Master Data ', dat.id, dat.order_fee_id, dat.filename, concat('The columns Channel with value "', dat.channel, '" not found in ODOO'), now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc', true, 1, 1);
                DELETE FROM leasing_contract WHERE id = leas_id;
            END IF;
        ELSE 
            UPDATE aggregation_table SET stage = 4 WHERE id = dat.id;
            INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date, active, create_uid, write_uid)
                VALUES ('ERROR: Master Data ', dat.id, dat.order_fee_id, dat.filename, concat('The columns Funding Type with value "', dat.funding_type, '" not found in ODOO'), now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc', true, 1, 1);
            DELETE FROM leasing_contract WHERE id = leas_id;
        END IF;
        RETURN res;
    END;
$$;

--SELECT checking_data_not_found(1,2)
-------------------------------------

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
        END IF;
    END;
$$;

--select checking_contract_create(21)
-------------------------------------

DROP FUNCTION IF EXISTS process_update_stage_after_insert(varchar);
CREATE OR REPLACE FUNCTION public.process_update_stage_after_insert(fname varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    BEGIN
        UPDATE aggregation_table set stage = 3, is_create = false, is_update = false
        WHERE id in 
            (SELECT at.id FROM aggregation_table at 
            LEFT JOIN leasing_contract_line lcl ON lcl.middleware_id = at.id 
            LEFT JOIN leasing_contract_payment lcp ON lcp.middleware_id = at.id
            WHERE filename = fname AND stage = 1
            ORDER BY at.id);
    END;
$$;

select process_update_stage_after_insert('20240301_DeFi.csv')
-------------------------------------

DROP FUNCTION IF EXISTS get_sequence_name_journal(integer, varchar);
CREATE OR REPLACE FUNCTION public.get_sequence_name_journal(journalid integer, order_date varchar)
RETURNS character varying
LANGUAGE plpgsql
AS $$
    DECLARE
        sequence_ids record;
        sequence_range_ids record;
        results varchar;
        journal_ids record;
        new_seq varchar;
        current_sequence record;
    BEGIN
        raise notice '---sequence name journal---';
        SELECT * FROM account_journal WHERE id = journalid INTO journal_ids;
        SELECT * FROM ir_sequence WHERE split_part(prefix, '/', 1) = journal_ids.code INTO sequence_ids;

        IF sequence_ids.id IS NULL THEN
            INSERT INTO ir_sequence (name, code, implementation, prefix, active, use_date_range, number_next, number_increment, padding, create_uid, create_date, write_uid, write_date)
            VALUES (journal_ids.name, null, 'no_gap', concat(journal_ids.code,'/%(range_year)s/'), True, True, 1, 1, 4, 1, now() at time zone 'utc', 1, now() at time zone 'utc') RETURNING * INTO sequence_ids;

            INSERT INTO ir_sequence_date_range (sequence_id, number_next, date_from, date_to, create_uid, create_date, write_uid, write_date)
            VALUES (sequence_ids.id, 1, concat((date_part('year', order_date::date)::int)::varchar, '0101')::date, concat((date_part('year', order_date::date)::int)::varchar, '1231')::date, 1, now() at time zone 'utc', 1, now() at time zone 'utc')
            RETURNING * INTO sequence_range_ids;
        ELSE
            SELECT * FROM ir_sequence_date_range
            WHERE sequence_id = sequence_ids.id AND
                (order_date::date >= date_from AND order_date::date <= date_to) INTO sequence_range_ids;
        END IF;

        SELECT name
        FROM account_move WHERE journal_id = journalid AND split_part(name, '/', 2)::varchar = date_part('year', order_date::date)::varchar
        ORDER BY name DESC LIMIT 1 INTO current_sequence;
        raise notice '%',journal_ids;
        raise notice '%',sequence_ids;
        raise notice '%',sequence_range_ids;
        raise notice '%',current_sequence;

        IF sequence_range_ids.id IS NULL THEN
            INSERT INTO ir_sequence_date_range (sequence_id, number_next, date_from, date_to, create_uid, create_date, write_uid, write_date)
            VALUES (sequence_ids.id, 1, concat((date_part('year', order_date::date)::int)::varchar, '0101')::date, concat((date_part('year', order_date::date)::int)::varchar, '1231')::date, 1, now() at time zone 'utc', 1, now() at time zone 'utc')
            RETURNING * INTO sequence_range_ids;
        END IF;

        raise notice '%',length(sequence_range_ids.number_next::varchar) > sequence_ids.padding;
        IF current_sequence.name IS NOT NULL THEN
            IF length(sequence_range_ids.number_next::varchar) > sequence_ids.padding THEN
                UPDATE ir_sequence SET padding = padding + 1 WHERE id = sequence_ids.id;
                UPDATE ir_sequence_date_range SET number_next = number_next + 1 WHERE id = sequence_range_ids.id;
            ELSIF split_part(current_sequence.name,'/',3) = LPAD('9',sequence_ids.padding, '9') THEN
                UPDATE ir_sequence SET padding = padding + 1 WHERE id = sequence_ids.id;
                UPDATE ir_sequence_date_range SET number_next = number_next + 1 WHERE id = sequence_range_ids.id;
            ELSE
                UPDATE ir_sequence_date_range SET number_next = number_next + 1 WHERE id = sequence_range_ids.id;
            END IF;
        ELSE
            UPDATE ir_sequence_date_range SET number_next = number_next + 1  WHERE id = sequence_range_ids.id;
        END IF;
        SELECT * FROM ir_sequence WHERE id = sequence_ids.id INTO sequence_ids;
        SELECT * FROM ir_sequence_date_range WHERE id = sequence_range_ids.id INTO sequence_range_ids;
        new_seq := LPAD(sequence_range_ids.number_next::varchar, sequence_ids.padding, '0');
        
        results := concat(journal_ids.code, '/', date_part('year', order_date::date), '/', new_seq);
        raise notice '%', results;
        -- UPDATE ir_sequence_date_range SET number_next = number_next + 1  WHERE id = sequence_range_ids.id;
        RETURN results;
    END;
$$;

-------------------------------------

DROP FUNCTION IF EXISTS unreconcile();
CREATE OR REPLACE FUNCTION public.unreconcile()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        account_moves record;
    BEGIN
        FOR account_moves IN select move_id FROM account_move_line where matching_number is not null group by move_id order by move_id
        LOOP
            PERFORM unreconcile_journal(account_moves.move_id);
        END LOOP;
    END;
$$;

DROP FUNCTION IF EXISTS unreconcile_journal(integer);
CREATE OR REPLACE FUNCTION public.unreconcile_journal(last_move_id integer)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        move_status boolean;
        move_line_ids record;
        reconcile_id int;
        last_move_ids record;
    BEGIN
        SELECT CASE WHEN state = 'posted' THEN true ELSE false END as status FROM account_move WHERE id = last_move_id INTO move_status;
        SELECT * FROM account_move WHERE id = last_move_id INTO last_move_ids;
        IF move_status IS true THEN
            FOR move_line_ids IN SELECT * FROM account_move_line WHERE move_id = last_move_id ORDER BY id
            LOOP
                IF move_line_ids.reconciled IS TRUE THEN
                    reconcile_id := move_line_ids.full_reconcile_id;
                    UPDATE account_move SET state = 'posted' WHERE id in (SELECT move_id FROM account_move_line WHERE full_reconcile_id = reconcile_id);
                    UPDATE account_move_line SET parent_state = 'posted' WHERE id in (SELECT move_id FROM account_move_line WHERE full_reconcile_id = reconcile_id);
                    UPDATE account_move_line SET reconciled = false, full_reconcile_id = null, matching_number = null, parent_state = 'posted' WHERE full_reconcile_id = reconcile_id;
                    DELETE FROM account_full_reconcile WHERE id = reconcile_id;
                END IF;
            END LOOP;
        END IF;
        PERFORM create_log_message('account.move', last_move_ids.state, 'Posted', last_move_ids.id, 'state');
        UPDATE account_move SET state = 'posted' WHERE id = last_move_id;
    END;
$$;

---------------------------

DROP FUNCTION IF EXISTS create_log_message(varchar, varchar, varchar, int, varchar);
CREATE OR REPLACE FUNCTION public.create_log_message(table_name varchar, old_status varchar, new_status varchar, res_id int, field_name varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        message_id int;
        field_ids record;
    BEGIN
        SELECT imf.id, imf.field_description->>'en_US' as field_des, imf.ttype 
        FROM ir_model im JOIN ir_model_fields imf on imf.model_id = im.id 
        WHERE im.model = table_name AND imf.name = field_name INTO field_ids;
        
        INSERT INTO mail_message (id, res_id, model, message_type, email_from, reply_to, is_internal, date, create_uid, write_uid, create_date, write_date, author_id, subtype_id, email_add_signature, message_id, body)
        VALUES (nextval('mail_message_id_seq'), res_id, table_name, 'notification', '""Administrator"" <admin@example.com>', '""Administrator"" <admin@example.com>', true, now() at time zone 'UTC', 2, 2, now() at time zone 'UTC', now() at time zone 'UTC',
        3, 2, false, null, '')
        RETURNING id INTO message_id;
        
        old_status := concat(upper(substring(old_status from 1 for 1)), substring(old_status from 2 for length(old_status)));
        INSERT INTO mail_tracking_value (id, field, mail_message_id, tracking_sequence, field_desc, field_type, old_value_char, new_value_char, create_uid, write_uid, create_date, write_date)
        VALUES (nextval('mail_tracking_value_id_seq'), field_ids.id, message_id, 100, field_ids.field_des, field_ids.ttype, old_status, new_status, 2, 2, now() at time zone 'UTC', now() at time zone 'UTC');
    END;
$$;

---------------------------

DROP FUNCTION IF EXISTS generate_action_post_loan(int);
CREATE OR REPLACE FUNCTION public.generate_action_post_loan(contracts int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        loan_ids record;
        create_dates timestamp;
        entries record;
        name_sequence varchar;
    BEGIN
        SELECT now() at time zone 'utc' INTO create_dates;
        FOR loan_ids IN SELECT * FROM leasing_contract_line WHERE contract_id = contracts ORDER BY id
        LOOP
            IF loan_ids.account_move_id IS NOT NULL THEN
                SELECT * FROM account_move WHERE id = loan_ids.account_move_id INTO entries;
                name_sequence := get_sequence_name_journal(entries.journal_id, (loan_ids.order_date + interval '7 hour')::varchar);
                UPDATE account_move SET name = name_sequence, sequence_prefix = concat(split_part(name_sequence, '/', 1), '/', split_part(name_sequence, '/', 2), '/', split_part(name_sequence, '/', 3), '/'), state = 'posted', write_uid = 2, write_date = create_dates WHERE id = loan_ids.account_move_id AND state = 'draft';
                UPDATE account_move_line set parent_state = 'posted' WHERE move_id = loan_ids.account_move_id;
            END IF;
        END LOOP;
    END;
$$;

DROP FUNCTION IF EXISTS generate_action_post_payment(int);
CREATE OR REPLACE FUNCTION public.generate_action_post_payment(contracts int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        payment_ids record;
        create_dates timestamp;
        entries record;
        name_sequence varchar;
    BEGIN
        SELECT now() at time zone 'utc' INTO create_dates;
        FOR payment_ids IN SELECT * FROM leasing_contract_payment WHERE contract_id = contracts ORDER BY id
        LOOP
            IF payment_ids.account_move_id IS NOT NULL THEN
                SELECT * FROM account_move WHERE id = payment_ids.account_move_id INTO entries;
                name_sequence := get_sequence_name_journal(entries.journal_id, (payment_ids.order_date + interval '7 hour')::varchar);
                UPDATE account_move SET name = name_sequence, sequence_prefix = concat(split_part(name_sequence, '/', 1), '/', split_part(name_sequence, '/', 2), '/', split_part(name_sequence, '/', 3), '/'), state = 'posted', write_uid = 2, write_date = create_dates WHERE id = payment_ids.account_move_id AND state = 'draft';
                UPDATE account_move_line set parent_state = 'posted' WHERE move_id = payment_ids.account_move_id;
            END IF;
        END LOOP;
    END;
$$;

DROP FUNCTION IF EXISTS generate_action_post_interest(int);
CREATE OR REPLACE FUNCTION public.generate_action_post_interest(contracts int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        interest_eom_ids record;
        interest_journal_ids record;
        create_dates timestamp;
        entries record;
        name_sequence varchar;
    BEGIN
        SELECT now() at time zone 'utc' INTO create_dates;
        FOR interest_eom_ids IN SELECT * FROM leasing_contract_interest WHERE contract_id = contracts ORDER BY id
        LOOP
            IF interest_eom_ids.eom_account_move_id IS NOT NULL THEN
                SELECT * FROM account_move WHERE id = interest_eom_ids.account_move_id INTO entries;
                name_sequence := get_sequence_name_journal(entries.journal_id, (interest_eom_ids.order_date + interval '7 hour')::varchar);
                UPDATE account_move SET name = name_sequence, sequence_prefix = concat(split_part(name_sequence, '/', 1), '/', split_part(name_sequence, '/', 2), '/', split_part(name_sequence, '/', 3), '/'), state = 'posted', write_uid = 2, write_date = create_dates WHERE id = interest_eom_ids.eom_account_move_id AND state = 'draft';
                UPDATE account_move_line set parent_state = 'posted' WHERE move_id = interest_eom_ids.account_move_id;
            END IF;
        END LOOP;
        
        FOR interest_journal_ids IN SELECT * FROM leasing_contract_interest WHERE contract_id = contracts ORDER BY id
        LOOP
            IF interest_journal_ids.eom_account_move_id IS NOT NULL THEN
                SELECT * FROM account_move WHERE id = interest_journal_ids.account_move_id INTO entries;
                name_sequence := get_sequence_name_journal(entries.journal_id, (interest_journal_ids.order_date + interval '7 hour')::varchar);
                UPDATE account_move SET name = name_sequence, sequence_prefix = concat(split_part(name_sequence, '/', 1), '/', split_part(name_sequence, '/', 2), '/', split_part(name_sequence, '/', 3), '/'), state = 'posted', write_uid = 2, write_date = create_dates WHERE id = interest_journal_ids.eom_account_move_id AND state = 'draft';
                UPDATE account_move_line set parent_state = 'posted' WHERE move_id = interest_journal_ids.account_move_id;
            END IF;
        END LOOP;
    END;
$$;

DROP FUNCTION IF EXISTS set_to_post_journal_amortization(int);
CREATE OR REPLACE FUNCTION public.set_to_post_journal_amortization(amortizations int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        line_ids record;
        create_dates timestamp;
    BEGIN
        FOR line_ids IN SELECT * FROM mofi_leasing_amortization_line WHERE amortization_id = amortizations ORDER BY id
        LOOP
            SELECT now() at time zone 'utc' INTO create_dates;
            IF line_ids.account_move_id IS NOT NULL THEN
                IF line_ids.order_date < create_dates::date THEN
                    UPDATE account_move SET state = 'posted' WHERE id = line_ids.account_move_id;
                    UPDATE account_move_line SET parent_state = 'posted' WHERE move_id = line_ids.account_move_id;
                END IF;
            END IF;
        END LOOP;
    END;
$$;


DROP FUNCTION IF EXISTS get_lock_date_info();
CREATE OR REPLACE FUNCTION public.get_lock_date_info()
RETURNS varchar
LANGUAGE plpgsql AS
$$
    DECLARE
        odoo_lockdate varchar;
    BEGIN
        SELECT CASE 
            WHEN period_lock_date is null THEN fiscalyear_lock_date
            WHEN fiscalyear_lock_date is null THEN period_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int < 0 THEN period_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int > 0 THEN fiscalyear_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int = 0 THEN period_lock_date
            ELSE null END as lock_date
        FROM account_change_lock_date ORDER BY id DESC LIMIT 1 INTO odoo_lockdate;
        RETURN odoo_lockdate;
    END;
$$;


DROP FUNCTION IF EXISTS insert_master_data_contract(varchar);
CREATE OR REPLACE FUNCTION public.insert_master_data_contract(contr_name varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        datas record;
        fundtype int;
        chann int;
        branc int;
        loanpur int;

    BEGIN
        SELECT * FROM aggregation_table WHERE contract_number ilike contr_name LIMIT 1 INTO datas;
        SELECT id FROM mofi_funding_type WHERE code ilike datas.funding_type INTO fundtype;
        SELECT id FROM mofi_branch WHERE code ilike datas.branch INTO branc;
        SELECT id FROM mofi_channel WHERE code ilike datas.channel INTO chann;
        SELECT id FROM mofi_loan_purpose WHERE code ilike datas.loan_purpose INTO loanpur;

        UPDATE leasing_contract SET
            funding_type_id = fundtype,
            branch_id = branc,
            channel_id = chann,
            loan_purpose_id = loanpur
        WHERE name ilike contr_name;
    END;
$$;

DROP FUNCTION IF EXISTS check_exist_contract(varchar);
CREATE OR REPLACE FUNCTION public.check_exist_contract(fname varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        rec record;
        odoo_lockdate date;
    BEGIN
        SELECT CASE
            WHEN period_lock_date is null THEN fiscalyear_lock_date
            WHEN fiscalyear_lock_date is null THEN period_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int < 0 THEN period_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int > 0 THEN fiscalyear_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int = 0 THEN period_lock_date
            ELSE null END as lock_date
        FROM account_change_lock_date ORDER BY id DESC LIMIT 1 INTO odoo_lockdate;

        IF odoo_lockdate IS NOT NULL THEN
            FOR rec IN SELECT lc.id, contract_number, lc.status
                FROM aggregation_table at
                JOIN mofi_order_type mot ON mot.code = at.order_type
                JOIN leasing_contract lc ON at.contract_number = lc.name
                WHERE stage = 1 AND filename = fname AND is_loan_submission IS true AND at.order_date::date > odoo_lockdate
                GROUP BY lc.id, at.contract_number, lc.status
                ORDER BY lc.id
            LOOP
                IF rec.status = 'active' THEN
                    PERFORM reset_to_draft(rec.id);
                    PERFORM create_log_message('leasing.contract', rec.status, 'Draft', rec.id, 'status');
                    UPDATE leasing_contract SET status = 'draft' WHERE id = rec.id;
                END IF;
            END LOOP;
        ELSE
            FOR rec IN SELECT lc.id, contract_number, lc.status
                FROM aggregation_table at
                JOIN mofi_order_type mot ON mot.code = at.order_type
                JOIN leasing_contract lc ON at.contract_number = lc.name
                WHERE stage = 1 AND filename = fname AND is_loan_submission IS true
                GROUP BY lc.id, at.contract_number, lc.status
                ORDER BY lc.id
            LOOP
                IF rec.status = 'active' THEN
                    PERFORM reset_to_draft(rec.id);
                    PERFORM create_log_message('leasing.contract', rec.status, 'Draft', rec.id, 'status');
                    UPDATE leasing_contract SET status = 'draft' WHERE id = rec.id;
                END IF;
            END LOOP;
        END IF;
    END;
$$;

DROP FUNCTION IF EXISTS check_exist_debtor(varchar);
CREATE OR REPLACE FUNCTION public.check_exist_debtor(fname varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        odoo_lockdate date;
        rec record;
        datas record;
    BEGIN
        SELECT CASE
            WHEN period_lock_date is null THEN fiscalyear_lock_date
            WHEN fiscalyear_lock_date is null THEN period_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int < 0 THEN period_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int > 0 THEN fiscalyear_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int = 0 THEN period_lock_date
            ELSE null END as lock_date
        FROM account_change_lock_date ORDER BY id DESC LIMIT 1 INTO odoo_lockdate;

        IF odoo_lockdate IS NOT NULL THEN
            FOR rec IN SELECT debtor_name, debtor_id FROM aggregation_table WHERE filename = fname AND stage = 1 AND order_date::date > odoo_lockdate
                GROUP BY debtor_name, debtor_id ORDER BY debtor_name
            LOOP
                SELECT * FROM res_partner WHERE name = rec.debtor_name AND debtor_id = rec.debtor_id INTO datas;
                IF datas.id IS NOT NULL THEN
                    UPDATE res_partner SET debtor_id = rec.debtor_id WHERE name = rec.debtor_name;
                ELSE
                    INSERT INTO res_partner (name, create_date, write_date, type, is_company, display_name, active, company_id, debtor_id, create_uid, write_uid)
                    VALUES (rec.debtor_name, now() at time zone 'utc', now() at time zone 'utc', 'contact', false, rec.debtor_name, true, 1, rec.debtor_id, 1, 1);
                END IF;
            END LOOP;
        ELSE
            FOR rec IN SELECT debtor_name, debtor_id FROM aggregation_table WHERE filename = fname AND stage = 1 GROUP BY debtor_name, debtor_id ORDER BY debtor_name
            LOOP
                SELECT * FROM res_partner WHERE name = rec.debtor_name AND debtor_id = rec.debtor_id INTO datas;
                IF datas.id IS NOT NULL THEN
                    UPDATE res_partner SET debtor_id = rec.debtor_id WHERE name = rec.debtor_name;
                ELSE
                    INSERT INTO res_partner (name, create_date, write_date, type, is_company, display_name, active, company_id, debtor_id, create_uid, write_uid)
                    VALUES (rec.debtor_name, now() at time zone 'utc', now() at time zone 'utc', 'contact', false, rec.debtor_name, true, 1, rec.debtor_id, 1, 1);
                END IF;
            END LOOP;
        END IF;
    END;
$$;
