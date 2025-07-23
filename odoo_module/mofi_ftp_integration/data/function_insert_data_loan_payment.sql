DROP FUNCTION IF EXISTS insert_leasing_loan(bigint, int);
CREATE OR REPLACE FUNCTION public.insert_leasing_loan(datid bigint, leasid int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        datas record;
        leas_line int;
        ordertype int;
        suborder int;
        paychan int;
        accjour int;
        currency int;
        feetypeids record;
        contract_ids record;
    BEGIN
        SELECT * FROM aggregation_table WHERE id = datid INTO datas;
        SELECT id FROM mofi_order_type WHERE code ilike datas.order_type INTO ordertype;
        SELECT id FROM mofi_suborder_type WHERE code ilike datas.sub_order_type INTO suborder;
        SELECT id FROM mofi_payment_channel WHERE code ilike datas.payment_channel INTO paychan;
        SELECT id FROM account_journal WHERE technical_code ilike datas.account_no INTO accjour;
        SELECT currency_id FROM res_company WHERE id = 1 INTO currency;
        SELECT * FROM mofi_fee_type WHERE code ilike datas.fee_type INTO feetypeids;

        SELECT * FROM leasing_contract WHERE id = leasid INTO contract_ids;
        INSERT INTO leasing_contract_line (
            contract_id, order_type_id, suborder_type_id, fee_type_id, amount, payment_channel_id,
            order_date, leasing_line_id, account_journal_id, currency_id, middleware_id, order_fee_id,
            create_date, write_date, amortization, create_uid, write_uid
        )
        VALUES (
            leasid, ordertype, suborder, feetypeids.id, datas.amount, paychan, datas.order_date, datas.order_id,
            accjour, currency, datas.id, datas.order_fee_id, now() at time zone 'utc', now() at time zone 'utc', feetypeids.is_amortization, 1, 1
        ) RETURNING ID INTO leas_line;

        UPDATE aggregation_table SET stage = 3 WHERE id = datid;
    END;
$$;

--select insert_leasing_loan(107, 47)
-------------------------------------

DROP FUNCTION IF EXISTS insert_leasing_payment(bigint, int);
CREATE OR REPLACE FUNCTION public.insert_leasing_payment(datid bigint, leasid int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        datas record;
        leas_line int;
        ordertype int;
        suborder int;
        feetype int;
        paychan int;
        accjour int;
        currency int;
    BEGIN
        SELECT * FROM aggregation_table WHERE id = datid INTO datas;
        SELECT id FROM mofi_order_type WHERE code ilike datas.order_type INTO ordertype;
        SELECT id FROM mofi_suborder_type WHERE code ilike datas.sub_order_type INTO suborder;
        SELECT id FROM mofi_fee_type WHERE code ilike datas.fee_type INTO feetype;
        SELECT id FROM mofi_payment_channel WHERE code ilike datas.payment_channel INTO paychan;
        SELECT id FROM account_journal WHERE technical_code ilike datas.account_no INTO accjour;
        SELECT currency_id FROM res_company WHERE id = 1 INTO currency;

        INSERT INTO leasing_contract_payment (
            contract_id, order_type_id, suborder_type_id, fee_type_id, amount, payment_channel_id,
            order_date, leasing_line_id, account_journal_id, currency_id, middleware_id, order_fee_id,
            create_date, write_date, create_uid, write_uid
        )
        VALUES (
            leasid, ordertype, suborder, feetype, datas.amount, paychan, datas.order_date, datas.order_id,
            accjour, currency, datas.id, datas.order_fee_id, now() at time zone 'utc', now() at time zone 'utc', 1, 1
        ) RETURNING ID INTO leas_line;

        UPDATE aggregation_table SET stage = 3 WHERE id = datid;
    END;
$$;
