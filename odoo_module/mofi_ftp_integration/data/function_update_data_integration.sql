DROP FUNCTION IF EXISTS update_data_loan_leasing(bigint);
CREATE OR REPLACE FUNCTION public.update_data_loan_leasing(datid bigint)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        data_aggregation record;
        vordertype int;
        vsuborder int;
        vfeetype int;
        vpaymentchannel int;
        vaccountjournal int;
        currency int;
    BEGIN
        SELECT * FROM aggregation_table WHERE id = datid INTO data_aggregation;
        SELECT id FROM mofi_order_type WHERE code ilike data_aggregation.order_type INTO vordertype;
        SELECT id FROM mofi_suborder_type WHERE code ilike data_aggregation.sub_order_type INTO vsuborder;
        SELECT id FROM mofi_fee_type WHERE code ilike data_aggregation.fee_type INTO vfeetype;
        SELECT id FROM mofi_payment_channel WHERE code ilike data_aggregation.payment_channel INTO vpaymentchannel;
        SELECT id FROM account_journal WHERE technical_code ilike data_aggregation.account_no INTO vaccountjournal;
        SELECT currency_id FROM res_company WHERE id = 1 INTO currency;

        UPDATE leasing_contract_line SET
            order_type_id = vordertype,
            suborder_type_id = vsuborder,
            fee_type_id = vfeetype,
            amount = data_aggregation.amount,
            payment_channel_id = vpaymentchannel,
            order_date = data_aggregation.order_date,
            leasing_line_id = data_aggregation.order_id,
            account_journal_id = vaccountjournal,
            account_move_id = null,
            currency_id = currency,
            write_date = now() at time zone 'utc'
        WHERE middleware_id = data_aggregation.id AND order_fee_id = data_aggregation.order_fee_id;

        UPDATE aggregation_table SET stage = 3 WHERE id = datid;

    END;
$$;

--select update_data_loan_leasing(244)
--------------------------------------

DROP FUNCTION IF EXISTS update_data_payment_leasing(bigint);
CREATE OR REPLACE FUNCTION public.update_data_payment_leasing(datid bigint)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        data_aggregation record;
        loan_ids record;
        vordertype int;
        vsuborder int;
        vfeetype int;
        vpaymentchannel int;
        vaccountjournal int;
        currency int;
        move_ids record;
    BEGIN
        SELECT * FROM aggregation_table WHERE id = datid INTO data_aggregation;
        SELECT id FROM mofi_order_type WHERE code ilike data_aggregation.order_type INTO vordertype;
        SELECT id FROM mofi_suborder_type WHERE code ilike data_aggregation.sub_order_type INTO vsuborder;
        SELECT id FROM mofi_fee_type WHERE code ilike data_aggregation.fee_type INTO vfeetype;
        SELECT id FROM mofi_payment_channel WHERE code ilike data_aggregation.payment_channel INTO vpaymentchannel;
        SELECT id FROM account_journal WHERE technical_code ilike data_aggregation.account_no INTO vaccountjournal;

        SELECT * FROM leasing_contract_payment WHERE middleware_id = data_aggregation.id AND order_fee_id = data_aggregation.order_fee_id INTO loan_ids;
        SELECT currency_id FROM res_company WHERE id = 1 INTO currency;

        IF loan_ids.account_move_id IS NOT NULL THEN
            SELECT * FROM account_move WHERE id = loan_ids.account_move_id INTO move_ids;
            IF move_ids.state = 'posted' THEN
                PERFORM unreconcile_journal(move_ids.id);
                UPDATE account_move
                    SET state = 'draft'
                WHERE id = move_ids.id;
                UPDATE account_move_line
                    SET parent_state = 'draft'
                WHERE move_id = move_ids.id;
                DELETE FROM account_move WHERE id = move_ids.id;
                DELETE FROM account_move_line WHERE move_id = move_ids.id;
            ELSE
                DELETE FROM account_move WHERE id = move_ids.id;
                DELETE FROM account_move_line WHERE move_id = move_ids.id;
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
            account_move_id = NULL,
            currency_id = currency,
            write_date = now() at time zone 'utc'
        WHERE id = loan_ids.id AND middleware_id = data_aggregation.id;

        UPDATE aggregation_table SET stage = 3 WHERE id = datid;

    END;
$$;

--select update_data_payment_leasing(244)
--------------------------------------
