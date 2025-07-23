DROP FUNCTION IF EXISTS process_insert_data_to_odoo(varchar);
CREATE OR REPLACE FUNCTION public.process_insert_data_to_odoo(fname varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        odoo_lockdate date;
        data_contract record;
        data_aggregation record;
        debtor int;
        leas_id int;
        leas_cont record;
        check_data boolean;
        scs_row int;
        branc_cek int;
        ordertype record;
    BEGIN
        -- START
        SELECT CASE 
            WHEN period_lock_date is null THEN fiscalyear_lock_date
            WHEN fiscalyear_lock_date is null THEN period_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int < 0 THEN period_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int > 0 THEN fiscalyear_lock_date
            WHEN extract(day from age(period_lock_date, fiscalyear_lock_date))::int = 0 THEN period_lock_date
            ELSE null END as lock_date
        FROM account_change_lock_date ORDER BY id DESC LIMIT 1 INTO odoo_lockdate;
        RAISE NOTICE 'Lock Date: %', odoo_lockdate;

        PERFORM check_exist_contract(fname);

        FOR data_contract IN SELECT contract_number, loan_purpose, funding_type, branch, debtor_name, plat_number, channel, isrestructure, istest, start_date, end_date, mca_number, debtor_id
            FROM aggregation_table WHERE stage = 1 AND filename = fname
            GROUP BY contract_number, loan_purpose, funding_type, branch, debtor_name, plat_number, channel, isrestructure, istest,start_date, end_date, mca_number, debtor_id
            ORDER BY contract_number
        LOOP
            RAISE NOTICE 'Contract %', data_contract.contract_number;
            SELECT * FROM leasing_contract WHERE name ilike data_contract.contract_number INTO leas_cont;
            IF leas_cont.id IS NOT NULL AND leas_cont.status not in ('close', 'canceled') THEN
                leas_id := leas_cont.id;
            ELSIF leas_cont.id IS NULL THEN
                INSERT INTO leasing_contract (name, plat, is_restructure, is_test, status, start_date, end_date, mca_number, create_uid, create_date, write_uid, write_date)
                VALUES (data_contract.contract_number, data_contract.plat_number, data_contract.isrestructure, data_contract.istest, 'draft', data_contract.start_date, data_contract.end_date, data_contract.mca_number,
                    1, now() at time zone 'utc', 1, now() at time zone 'utc')
                RETURNING id INTO leas_id;
            ELSE
                leas_id := NULL;
            END IF;

            IF leas_id IS NOT NULL THEN
                SELECT id FROM res_partner WHERE name ilike data_contract.debtor_name AND debtor_id = data_contract.debtor_id INTO debtor;
                SELECT id FROM mofi_branch WHERE code ilike data_contract.branch INTO branc_cek;
                IF debtor IS NULL AND length(data_contract.debtor_name) > 0 THEN
                    INSERT INTO res_partner (name, create_date, write_date, type, is_company, display_name, active, company_id, debtor_id, create_uid, write_uid)
                        VALUES (data_contract.debtor_name, now() at time zone 'utc', now() at time zone 'utc', 'contact', false, data_contract.debtor_name, true, 1, data_contract.debtor_id, 1, 1)
                        RETURNING id INTO debtor;
                    UPDATE leasing_contract SET debtor_id = debtor WHERE id = leas_id;
                ELSE
                    UPDATE leasing_contract SET debtor_id = debtor WHERE id = leas_id;
                END IF;

                -- IF branc_cek IS NULL AND data_contract.branch IS NOT NULL THEN
                --     INSERT INTO mofi_branch (name,code,active) VALUES (data_contract.branch, data_contract.branch, true) RETURNING ID INTO branc_cek;
                --     UPDATE leasing_contract SET branch_id = branc_cek WHERE id = leas_id;
                -- ELSE
                --     UPDATE leasing_contract SET branch_id = branc_cek WHERE id = leas_id;
                -- END IF;
                PERFORM insert_master_data_contract(data_contract.contract_number);

                FOR data_aggregation IN SELECT * FROM aggregation_table WHERE stage = 1 AND contract_number = data_contract.contract_number ORDER BY id
                LOOP
                    SELECT * FROM mofi_order_type WHERE code ilike data_aggregation.order_type INTO ordertype;
                    IF odoo_lockdate IS NOT NULL THEN
                        RAISE NOTICE 'Lock Date Not NULL';
                        IF data_aggregation.order_date::date > odoo_lockdate  THEN
                            check_data := checking_data_not_found(data_aggregation.id, leas_id);
                            IF check_data is true THEN
                                IF data_aggregation.is_update = True THEN
                                    IF ordertype.is_loan_submission IS TRUE THEN
                                        PERFORM update_data_loan_leasing(data_aggregation.id);
                                    ELSE
                                        PERFORM update_data_payment_leasing(data_aggregation.id);
                                    END IF;
                                ELSE 
                                    IF ordertype.is_loan_submission IS TRUE THEN
                                        PERFORM insert_leasing_loan(data_aggregation.id, leas_id);
                                    ELSE
                                        PERFORM insert_leasing_payment(data_aggregation.id, leas_id);
                                    END IF;
                                END IF;
                            END IF;
                        -- ELSIF odoo_lockdate = data_aggregation.order_date THEN
                        --     check_data := checking_data_not_found(data_aggregation.id, leas_id);
                        --     RAISE NOTICE 'Check Data Equal Lock Date';
                        --     IF check_data is true THEN
                        --         RAISE NOTICE 'Continue Checking True';
                        --         IF data_aggregation.is_update = True THEN
                        --             RAISE NOTICE 'Data Update Equal Lock Date';
                        --             IF ordertype.is_loan_submission IS TRUE THEN
                        --                 PERFORM update_data_loan_leasing(data_aggregation.id);
                        --             ELSE
                        --                 PERFORM update_data_payment_leasing(data_aggregation.id);
                        --             END IF;
                        --         ELSE 
                        --             RAISE NOTICE 'Data Baru Equal Lock Date';
                        --             IF ordertype.is_loan_submission IS TRUE THEN
                        --                 PERFORM insert_leasing_loan(data_aggregation.id, leas_id);
                        --             ELSE
                        --                 PERFORM insert_leasing_payment(data_aggregation.id, leas_id);
                        --             END IF;
                        --         END IF;
                        --     END IF;
                        ELSE
                            UPDATE aggregation_table SET stage = 2 WHERE id = data_aggregation.id;
                            INSERT INTO logging_integration (name, row_id, order_fee_id, filename, description, log_time, error_status,
                                create_date, write_date, active, create_uid, write_uid)
                            VALUES (
                                'ERROR: Data less than Lock Date with ID ', data_aggregation.id, data_aggregation.order_fee_id, data_aggregation.filename, 'Data less than Lock Date',
                                now() at time zone 'utc', True, now() at time zone,'utc', now() at time zone 'utc', true, 1, 1
                            );
                        END IF;
                    ELSE
                        RAISE NOTICE 'Without Lock Date';
                        check_data := checking_data_not_found(data_aggregation.id, leas_id);
                        IF check_data is true THEN
                            IF data_aggregation.is_update = True THEN
                                IF ordertype.is_loan_submission IS TRUE THEN
                                    PERFORM update_data_loan_leasing(data_aggregation.id);
                                ELSE
                                    PERFORM update_data_payment_leasing(data_aggregation.id);
                                END IF;
                            ELSE 
                                IF ordertype.is_loan_submission IS TRUE THEN
                                    PERFORM insert_leasing_loan(data_aggregation.id, leas_id);
                                ELSE
                                    PERFORM insert_leasing_payment(data_aggregation.id, leas_id);
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                END LOOP;
                PERFORM checking_contract_create(leas_id);
                IF leas_id IS NOT NULL THEN
                    PERFORM generate_loan(leas_id);
                    PERFORM generate_payment(leas_id);
                    -- PERFORM generate_interest(leas_id);
                END IF;
            ELSE
                UPDATE aggregation_table SET stage = 2 WHERE filename = fname;
            END IF;
        END LOOP;
        SELECT count(*) FROM aggregation_table WHERE filename = fname and stage = 3 INTO scs_row;
        UPDATE logging_integration SET dest_number_of_rows = scs_row, write_date = now() at time zone 'utc'
        WHERE filename = fname and receive_status = True;
    END;
$$;

--select process_insert_data_to_odoo('20231121-1440_upd.csv');
--------------------------------------------------------------------
