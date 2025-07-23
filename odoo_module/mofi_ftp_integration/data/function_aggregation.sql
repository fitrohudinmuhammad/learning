DROP FUNCTION IF EXISTS process_aggregation_data(varchar);
CREATE OR REPLACE FUNCTION public.process_aggregation_data(file_name varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        prow record;
        column_name TEXT;
    BEGIN
        FOR prow IN SELECT id, order_fee_id, REPLACE(REPLACE(order_date, 'T', ' '), 'Z', ' ') as order_date, REPLACE(REPLACE(start_date, 'T', ' '), 'Z', ' ') as start_date, REPLACE(REPLACE(end_date, 'T', ' '), 'Z', ' ') as end_date, isrestructure, istest, amount FROM preparation_table_new_row WHERE filename = file_name ORDER BY id
        LOOP
            BEGIN
                raise notice '%', prow;
                IF regexp_match(SUBSTRING(prow.order_date FROM 1 FOR 19), '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') IS NULL THEN
                    INSERT INTO logging_integration(name, filename, description, log_time, error_status, order_fee_id, create_uid, create_date, write_uid, write_date, active)
                    VALUES ('Error: Data validation', file_name, concat('The error occurred in column order_date: ', prow.order_date), now(), true, prow.order_fee_id, 1, now() at time zone 'utc', 1, now() at time zone 'utc', true);
                    UPDATE preparation_table SET mark_as_done = TRUE WHERE id = prow.id;
                    RAISE NOTICE 'Error %', prow;
                END IF;

                IF regexp_match(SUBSTRING(prow.start_date FROM 1 FOR 19), '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') IS NULL THEN
                    INSERT INTO logging_integration(name, filename, description, log_time, error_status, order_fee_id, create_uid, create_date, write_uid, write_date, active)
                    VALUES ('Error: Data validation', file_name, concat('The error occurred in column start_date: ', prow.start_date), now(), true, prow.order_fee_id, 1, now() at time zone 'utc', 1, now() at time zone 'utc', true);
                    UPDATE preparation_table SET mark_as_done = TRUE WHERE id = prow.id;
                    RAISE NOTICE 'Error %', prow;
                END IF;

                IF regexp_match(SUBSTRING(prow.end_date FROM 1 FOR 19), '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') IS NULL THEN
                    INSERT INTO logging_integration(name, filename, description, log_time, error_status, order_fee_id, create_uid, create_date, write_uid, write_date, active)
                    VALUES ('Error: Data validation', file_name, concat('The error occurred in column end_date: ', prow.end_date), now(), true, prow.order_fee_id, 1, now() at time zone 'utc', 1, now() at time zone 'utc', true);
                    UPDATE preparation_table SET mark_as_done = TRUE WHERE id = prow.id;
                    RAISE NOTICE 'Error %', prow;
                END IF;

                IF prow.amount ~ '^-?\d+(\.\d+)?$' IS false THEN
                    INSERT INTO logging_integration(name, filename, description, log_time, error_status, order_fee_id, create_uid, create_date, write_uid, write_date, active)
                    VALUES ('Error: Data validation', file_name, concat('The error occurred in column amount: ', prow.amount), now(), true, prow.order_fee_id, 1, now() at time zone 'utc', 1, now() at time zone 'utc', true);
                    UPDATE preparation_table SET mark_as_done = TRUE WHERE id = prow.id;
                    RAISE NOTICE 'Error %', prow;
                END IF;

                IF prow.isrestructure NOT IN ('True', 'False', 't', 'f', '1', '0') THEN
                    INSERT INTO logging_integration(name, filename, description, log_time, error_status, order_fee_id, create_uid, create_date, write_uid, write_date, active)
                    VALUES ('Error: Data validation', file_name, concat('The error occurred in column isrestructure: ', prow.isrestructure), now(), true, prow.order_fee_id, 1, now() at time zone 'utc', 1, now() at time zone 'utc', true);
                    UPDATE preparation_table SET mark_as_done = TRUE WHERE id = prow.id;
                    RAISE NOTICE 'Error %', prow;
                END IF;

                IF prow.istest NOT IN ('True', 'False', 't', 'f', '1', '0') THEN
                    INSERT INTO logging_integration(name, filename, description, log_time, error_status, order_fee_id, create_uid, create_date, write_uid, write_date, active)
                    VALUES ('Error: Data validation', file_name, concat('The error occurred in column istest: ', prow.istest), now(), true, prow.order_fee_id, 1, now() at time zone 'utc', 1, now() at time zone 'utc', true);
                    UPDATE preparation_table SET mark_as_done = TRUE WHERE id = prow.id;
                    RAISE NOTICE 'Error %', prow;
                END IF;
            END;
        END LOOP;
        
        INSERT INTO aggregation_table (
            order_fee_id, contract_number, loan_purpose,
            funding_type, branch, debtor_name, plat_number,
            channel, isrestructure, istest, order_id, order_date,
            start_date, end_date, order_type, sub_order_type,
            fee_type, account_no, payment_channel,
            amount, description, filename, is_create, is_update, mca_number, debtor_id)
        SELECT 
            order_fee_id, contract_number, loan_purpose,
            funding_type, case when length(branch) = 0 THEN NULL else branch end,
            debtor_name, plat_number,
            channel, isrestructure::boolean, istest::boolean,
            order_id, SUBSTRING(order_date FROM 1 FOR 19)::timestamp,
            SUBSTRING(start_date FROM 1 FOR 19)::timestamp, SUBSTRING(end_date FROM 1 FOR 19)::timestamp, order_type, sub_order_type,
            fee_type, account_no, payment_channel,
            amount::float, description, filename, True, False, mca_number, debtor_id
        FROM 
            preparation_table_new_row 
        WHERE 
            filename = file_name
        ON CONFLICT (order_fee_id)
        DO UPDATE 
            SET 
                contract_number = EXCLUDED.contract_number,
                loan_purpose = EXCLUDED.loan_purpose,
                funding_type = EXCLUDED.funding_type,
                branch = EXCLUDED.branch,
                debtor_id = EXCLUDED.debtor_id,
                debtor_name = EXCLUDED.debtor_name,
                plat_number = EXCLUDED.plat_number,
                channel = EXCLUDED.channel,
                isrestructure = EXCLUDED.isrestructure,
                istest = EXCLUDED.istest,
                order_id = EXCLUDED.order_id,
                order_date = EXCLUDED.order_date,
                start_date = EXCLUDED.start_date,
                end_date = EXCLUDED.end_date,
                order_type = EXCLUDED.order_type,
                sub_order_type = EXCLUDED.sub_order_type,
                fee_type = EXCLUDED.fee_type,
                account_no = EXCLUDED.account_no,
                payment_channel = EXCLUDED.payment_channel,
                amount = EXCLUDED.amount,
                description = EXCLUDED.description,
                filename = EXCLUDED.filename,
                is_create = False,
                is_update = True,
                stage = 1,
                mca_number = EXCLUDED.mca_number;
        UPDATE preparation_table SET mark_as_done = TRUE;

        PERFORM checking_data_sync(file_name);
    END;
$$;

DROP FUNCTION IF EXISTS checking_data_sync(varchar);
CREATE OR REPLACE FUNCTION public.checking_data_sync(file_name varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        order_ids record;
        leasing_data int;
        payment_data int;
    BEGIN
        FOR order_ids IN SELECT * FROM aggregation_table WHERE filename = file_name ORDER BY id
        LOOP
            IF order_ids.is_update = True THEN
                SELECT lcl.middleware_id FROM leasing_contract lc
                    JOIN leasing_contract_line lcl on lcl.contract_id = lc.id
                    WHERE lcl.middleware_id = order_ids.id LIMIT 1 INTO leasing_data;
                SELECT lcl.middleware_id FROM leasing_contract lc
                    JOIN leasing_contract_payment lcl on lcl.contract_id = lc.id
                    WHERE lcl.middleware_id = order_ids.id LIMIT 1 INTO payment_data;
                IF leasing_data IS NULL AND payment_data IS NULL THEN
                    UPDATE aggregation_table SET is_create = True, is_update = False
                    WHERE id = order_ids.id;
                ELSIF leasing_data IS NOT NULL AND payment_data IS NULL THEN
                END IF;
            END IF;
        END LOOP;
    END;
$$;

--select checking_data_sync('20231209_1021_upd_payment_only.csv')
-- select process_aggregation_data('20240220_DeFi.csv')