DROP FUNCTION IF EXISTS process_insert_data_to_odoo(varchar);
CREATE OR REPLACE FUNCTION public.process_insert_data_to_odoo(fname varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        odoo_lockdate date;
        rec record;
        vals record;
        leas_cont record;
        leas_id int;
        scs_row int;
        check_data boolean;
    BEGIN
        SELECT CASE
            WHEN period_lock_date is null THEN fiscalyear_lock_date
            WHEN fiscalyear_lock_date is null THEN period_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int < 0 THEN period_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int > 0 THEN fiscalyear_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int = 0 THEN period_lock_date
            ELSE null END as lock_date
        FROM account_change_lock_date ORDER BY id DESC LIMIT 1 INTO odoo_lockdate;
        RAISE NOTICE 'Lock Date: %', odoo_lockdate;

        IF odoo_lockdate IS NULL THEN
            PERFORM check_exist_contract(fname);
            PERFORM check_exist_debtor(fname);

            -- create new contract
            FOR rec IN SELECT contract_number FROM aggregation_table WHERE stage = 1 AND filename = fname AND contract_number NOT IN (SELECT name FROM leasing_contract)
                GROUP BY contract_number ORDER BY contract_number
            LOOP
                INSERT INTO leasing_contract (name, plat, is_restructure, is_test, status, start_date, end_date, mca_number, funding_type_id,
                    channel_id, branch_id, debtor_id, loan_purpose_id, create_uid, create_date, write_uid, write_date)
                SELECT contract_number, plat_number, isrestructure, istest, 'draft', start_date, end_date, mca_number, mft.id,
                    mc.id, mb.id, rp.id, mlp.id, 1, now() at time zone 'utc', 1, now() at time zone 'utc'
                FROM aggregation_table at
                JOIN mofi_funding_type mft ON mft.code ilike at.funding_type
                JOIN mofi_channel mc ON mc.code ilike at.channel
                JOIN mofi_branch mb ON mb.code ilike at.branch
                JOIN res_partner rp ON rp.name ilike at.debtor_name AND rp.debtor_id ilike at.debtor_id
                JOIN mofi_loan_purpose mlp ON mlp.code ilike at.loan_purpose
                WHERE contract_number ilike rec.contract_number ORDER BY at.id desc LIMIT 1;
            END LOOP;
            raise notice 'contract done';

            -- create new loan entries
            FOR rec IN SELECT at.id as agid, at.is_update, at.is_create, at.order_date, lc.id as lcid, at.order_fee_id, mot.is_loan_submission
                FROM aggregation_table at
                JOIN mofi_order_type mot on mot.code ilike at.order_type
                JOIN leasing_contract lc ON lc.name ilike at.contract_number
                WHERE stage = 1 AND filename = fname
                ORDER BY at.id
            LOOP
                check_data := checking_data_not_found(rec.agid, rec.lcid);
                IF check_data IS true THEN
                    IF rec.is_loan_submission IS true THEN
                        IF rec.is_update is true THEN
                            PERFORM update_data_loan_leasing(rec.agid);
                        ELSE
                            PERFORM insert_leasing_loan(rec.agid, rec.lcid);
                        END IF;
                    ELSE
                        IF rec.is_update = True THEN
                            PERFORM update_data_payment_leasing(rec.agid);
                        ELSE
                            PERFORM insert_leasing_payment(rec.agid, rec.lcid);
                        END IF;
                    END IF;
                END IF;
            END LOOP;
            raise notice 'done';

        ELSE
            PERFORM check_exist_contract(fname);
            PERFORM check_exist_debtor(fname);
            UPDATE aggregation_table SET stage = 2 WHERE id in (SELECT id FROM aggregation_table WHERE order_date::date <= lock_odoodate AND stage = 1 AND filename = fname);
            INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status, create_date, write_date, active, create_uid, write_uid)
            SELECT
                'ERROR: Data less than Lock Date with ID ', id, order_fee_id, fname, 'Data less than Lock Date', now() at time zone 'utc', True, now() at time zone 'utc', now() at time zone 'utc', true, 1, 1
            FROM aggregation_table WHERE id in (SELECT id FROM aggregation_table WHERE order_date::date <= lock_odoodate AND stage = 1 AND filename = fname);

            FOR rec IN SELECT contract_number FROM aggregation_table WHERE stage = 1 AND filename = fname AND contract_number NOT IN (SELECT name FROM leasing_contract) AND order_date::date > odoo_lockdate
                GROUP BY contract_number ORDER BY contract_number
            LOOP
                INSERT INTO leasing_contract (name, plat, is_restructure, is_test, status, start_date, end_date, mca_number, funding_type_id, channel_id, branch_id, debtor_id, loan_purpose_id, create_uid, create_date, write_uid, write_date)
                SELECT contract_number, plat_number, isrestructure, istest, 'draft', start_date, end_date, mca_number, mft.id, mc.id, mb.id, rp.id, mlp.id, 1, now() at time zone 'utc', 1, now() at time zone 'utc'
                FROM aggregation_table at
                JOIN mofi_funding_type mft ON mft.code ilike at.funding_type
                JOIN mofi_channel mc ON mc.code ilike at.channel
                JOIN mofi_branch mb ON mb.code ilike at.branch
                JOIN res_partner rp ON rp.name ilike at.debtor_name AND rp.debtor_id ilike at.debtor_id
                JOIN mofi_loan_purpose mlp ON mlp.code ilike at.loan_purpose
                WHERE contract_number ilike rec.contract_number ORDER BY at.id desc LIMIT 1;
            END LOOP;
            raise notice 'contract done';

            FOR rec IN SELECT at.id as agid, at.is_update, at.is_create, at.order_date, lc.id as lcid, at.order_fee_id, mot.is_loan_submission
                FROM aggregation_table at
                JOIN mofi_order_type mot on mot.code ilike at.order_type
                JOIN leasing_contract lc ON lc.name ilike at.contract_number
                WHERE stage = 1 AND filename = fname AND at.order_date::date > odoo_lockdate
                ORDER BY at.id
            LOOP
                check_data := checking_data_not_found(rec.agid, rec.lcid);
                IF check_data IS true THEN
                    IF rec.is_loan_submission IS true THEN
                        IF rec.is_update is true THEN
                            PERFORM update_data_loan_leasing(rec.agid);
                        ELSE
                            PERFORM insert_leasing_loan(rec.agid, rec.lcid);
                        END IF;
                    ELSE
                        IF rec.is_update = True THEN
                            PERFORM update_data_payment_leasing(rec.agid);
                        ELSE
                            PERFORM insert_leasing_payment(rec.agid, rec.lcid);
                        END IF;
                    END IF;
                END IF;
            END LOOP;

            raise notice 'done';
        END IF;

        SELECT count(*) FROM aggregation_table WHERE filename = fname and stage = 3 INTO scs_row;
        UPDATE logging_integration SET dest_number_of_rows = scs_row, write_date = now() at time zone 'utc'
        WHERE filename = fname and receive_status = True;

        FOR rec IN SELECT id FROM leasing_contract WHERE name IN (SELECT contract_number FROM aggregation_table WHERE filename ilike fname GROUP BY contract_number)
            ORDER BY id
        LOOP
            PERFORM generate_loan(rec.id);
            PERFORM generate_payment(rec.id);
        END LOOP;
    END;
$$;

--select process_insert_data_to_odoo('20240222_DeFi.csv')