DROP FUNCTION IF EXISTS create_journal_leasing_lock_date(int, int, varchar);
CREATE OR REPLACE FUNCTION public.create_journal_leasing_lock_date(line_id int, leas_account_id int, lockdate varchar)
RETURNS INT
LANGUAGE plpgsql AS
$$
    DECLARE
        create_dates timestamp;
        name_sequence varchar;
        leasing_account_ids record;
        leasing_ids record;
        account_move_id int;
        currency int;
        com_partner_id int;
        debit_account_ids record;
        credit_account_ids record;
        acc_date date;

        feetypeids record;
        channelids record;
        accountno record;
        paychan record;
        odoo_lockdate varchar;
    BEGIN
        SELECT * FROM leasing_contract_line lcl JOIN leasing_contract lc ON lc.id = lcl.contract_id WHERE lcl.id = line_id INTO leasing_ids;
        SELECT commercial_partner_id FROM res_partner WHERE id = leasing_ids.debtor_id INTO com_partner_id;
        SELECT mla.id, debit_account_id, credit_account_id, mft.account_journal_id, aj.code, aj.currency_id
            FROM mofi_leasing_account mla
            JOIN mofi_fee_type mft ON mft.id = mla.fee_type_id
            JOIN account_journal aj ON aj.id = mft.account_journal_id
            WHERE mla.id = leas_account_id AND mla.active = true INTO leasing_account_ids;
        IF leasing_account_ids.id IS NOT NULL THEN
            SELECT * FROM account_account WHERE id = leasing_account_ids.debit_account_id INTO debit_account_ids;
            SELECT * FROM account_account WHERE id = leasing_account_ids.credit_account_id INTO credit_account_ids;

            odoo_lockdate :=  get_lock_date_info();
            SELECT CASE WHEN (leasing_ids.order_date + interval '7 hour')::date > odoo_lockdate::date THEN (leasing_ids.order_date + interval '7 hour')::date ELSE lockdate::date END INTO acc_date;

            name_sequence := get_sequence_name_journal(leasing_account_ids.account_journal_id, acc_date::varchar);

            SELECT * FROM mofi_fee_type WHERE id = leasing_ids.fee_type_id INTO feetypeids;
            SELECT * FROM mofi_channel WHERE id = leasing_ids.channel_id INTO channelids;
            SELECT * FROM account_journal WHERE id = leasing_ids.account_journal_id INTO accountno;
            SELECT * FROM mofi_payment_channel WHERE id = leasing_ids.payment_channel_id INTO paychan;

            IF leasing_ids.debtor_id IS NOT NULL THEN
                SELECT rc.currency_id FROM res_company rc JOIN res_partner rp ON rp.company_id = rc.id WHERE rp.id = leasing_ids.debtor_id INTO currency;
            ELSE
                SELECT currency_id FROM res_company WHERE id = 1 INTO currency;
            END IF;
            SELECT now() at time zone 'utc' INTO create_dates;
            --
            INSERT INTO account_move(
                id, name, partner_id, invoice_date_due, journal_id,
                invoice_user_id, company_id, currency_id, sequence_prefix,
                move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
                amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
                date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
                amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref, contract_ref
            ) VALUES (
                nextval('account_move_id_seq'), name_sequence, leasing_ids.debtor_id, acc_date, leasing_account_ids.account_journal_id,
                2, 1, currency, concat(leasing_account_ids.code, '/', date_part('year', acc_date), '/', date_part('month', acc_date), '/'),
                'entry', '', 0.00, 0.00, leasing_ids.amount,
                0.00, 0.00, leasing_ids.amount, 0.00,
                acc_date, 'posted', 'not_paid', 'no',
                'no_extract_requested', 2, create_dates, 2, create_dates,
                leasing_ids.amount, 0.00, com_partner_id, leasing_ids.name, leasing_ids.contract_id
            ) ON CONFLICT (id) DO NOTHING RETURNING ID INTO account_move_id;

            INSERT INTO account_move_line(
                id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                move_name, parent_state, name, display_type,
                date, debit, credit, 
                balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                create_uid, create_date, write_uid, write_date, date_maturity, ref
            ) VALUES (
                nextval('account_move_line_id_seq'), account_move_id, leasing_account_ids.account_journal_id, 1, currency, leasing_account_ids.debit_account_id, currency, leasing_ids.debtor_id,
                name_sequence, 'posted', concat(feetypeids.name, ' - ', channelids.name, ' - ', accountno.name->>'en_US', ' - ', paychan.name), 'product', 
                acc_date, leasing_ids.amount, 0.00,
                leasing_ids.amount, leasing_ids.amount, leasing_ids.amount, 0.00, 1.00, 0.00,
                0.00, 0.00, False, False, False,
                2, create_dates, 2, create_dates,
                CASE WHEN debit_account_ids.account_type = 'asset_receivable' THEN leasing_ids.end_date
                    WHEN debit_account_ids.account_type = 'liability_payable' THEN (leasing_ids.start_date + interval '30 day')::date
                    ELSE NULL END, leasing_ids.name
            ) ON CONFLICT(id) DO NOTHING;

            INSERT INTO account_move_line(
                id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                move_name, parent_state, name, display_type,
                date, debit, credit, 
                balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                create_uid, create_date, write_uid, write_date, date_maturity, ref
            ) VALUES (
                nextval('account_move_line_id_seq'), account_move_id, leasing_account_ids.account_journal_id, 1, currency, leasing_account_ids.credit_account_id, currency, leasing_ids.debtor_id,
                name_sequence, 'posted', concat(feetypeids.name, ' - ', channelids.name, ' - ', accountno.name->>'en_US', ' - ', paychan.name), 'product',
                acc_date, 0.00, leasing_ids.amount,
                -1 * leasing_ids.amount, -1 * leasing_ids.amount, -1 * leasing_ids.amount, 0.00, 1.00, 0.00,
                0.00, 0.00, False, False, False,
                2, create_dates, 2, create_dates, 
                CASE WHEN credit_account_ids.account_type = 'asset_receivable' THEN leasing_ids.end_date
                    WHEN credit_account_ids.account_type = 'liability_payable' THEN (leasing_ids.start_date + interval '30 day')::date
                    ELSE NULL END, leasing_ids.name
            )
            ON CONFLICT(id)
            DO NOTHING;
            
            RETURN account_move_id;
        ELSE
            RETURN null;
        END IF;
    END;
$$;

---------------------------

DROP FUNCTION IF EXISTS create_journal_payment_lock_date(int, int, varchar);
CREATE OR REPLACE FUNCTION public.create_journal_payment_lock_date(line_id int, leas_account_id int, lockdate varchar)
RETURNS INT
LANGUAGE plpgsql AS
$$
    DECLARE
        create_dates timestamp;
        name_sequence varchar;
        leasing_account_ids record;
        leasing_ids record;
        account_move_id int;
        currency int;
        com_partner_id int;
        debit_account_ids record;
        credit_account_ids record;
        acc_date date;

        feetypeids record;
        channelids record;
        accountno record;
        paychan record;
        odoo_lockdate varchar;
    BEGIN
        SELECT * FROM leasing_contract_payment lcl JOIN leasing_contract lc ON lc.id = lcl.contract_id WHERE lcl.id = line_id INTO leasing_ids;
        SELECT commercial_partner_id FROM res_partner WHERE id = leasing_ids.debtor_id INTO com_partner_id;
        SELECT mla.id, debit_account_id, credit_account_id, mft.account_journal_id, aj.code, aj.currency_id
            FROM mofi_leasing_account mla
            JOIN mofi_fee_type mft ON mft.id = mla.fee_type_id
            JOIN account_journal aj ON aj.id = mft.account_journal_id
            WHERE mla.id = leas_account_id AND mla.active = true INTO leasing_account_ids;
        IF leasing_account_ids.id IS NOT NULL THEN
            SELECT * FROM account_account WHERE id = leasing_account_ids.debit_account_id INTO debit_account_ids;
            SELECT * FROM account_account WHERE id = leasing_account_ids.credit_account_id INTO credit_account_ids;

            odoo_lockdate :=  get_lock_date_info();
            SELECT CASE WHEN (leasing_ids.order_date + interval '7 hour')::date > odoo_lockdate::date THEN (leasing_ids.order_date + interval '7 hour')::date ELSE lockdate::date END INTO acc_date;

            name_sequence := get_sequence_name_journal(leasing_account_ids.account_journal_id, acc_date::varchar);

            SELECT * FROM mofi_fee_type WHERE id = leasing_ids.fee_type_id INTO feetypeids;
            SELECT * FROM mofi_channel WHERE id = leasing_ids.channel_id INTO channelids;
            SELECT * FROM account_journal WHERE id = leasing_ids.account_journal_id INTO accountno;
            SELECT * FROM mofi_payment_channel WHERE id = leasing_ids.payment_channel_id INTO paychan;

            IF leasing_ids.debtor_id IS NOT NULL THEN
                SELECT rc.currency_id FROM res_company rc JOIN res_partner rp ON rp.company_id = rc.id WHERE rp.id = leasing_ids.debtor_id INTO currency;
            ELSE
                SELECT currency_id FROM res_company WHERE id = 1 INTO currency;
            END IF;
            SELECT now() at time zone 'utc' INTO create_dates;
            --
            INSERT INTO account_move(
                id, name, partner_id, invoice_date_due, journal_id,
                invoice_user_id, company_id, currency_id, sequence_prefix,
                move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
                amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
                date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
                amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref, contract_ref
            ) VALUES (
                nextval('account_move_id_seq'), name_sequence, leasing_ids.debtor_id, acc_date, leasing_account_ids.account_journal_id,
                2, 1, currency, concat(leasing_account_ids.code, '/', date_part('year', acc_date), '/', date_part('month', acc_date), '/'),
                'entry', '', 0.00, 0.00, leasing_ids.amount,
                0.00, 0.00, leasing_ids.amount, 0.00,
                acc_date, 'posted', 'not_paid', 'no',
                'no_extract_requested', 2, create_dates, 2, create_dates,
                leasing_ids.amount, 0.00, com_partner_id, leasing_ids.name, leasing_ids.contract_id
            ) ON CONFLICT (id) DO NOTHING RETURNING ID INTO account_move_id;

            INSERT INTO account_move_line(
                id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                move_name, parent_state, name, display_type,
                date, debit, credit, 
                balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                create_uid, create_date, write_uid, write_date, date_maturity, ref
            ) VALUES (
                nextval('account_move_line_id_seq'), account_move_id, leasing_account_ids.account_journal_id, 1, currency, leasing_account_ids.debit_account_id, currency, leasing_ids.debtor_id,
                name_sequence, 'posted', concat(feetypeids.name, ' - ', channelids.name, ' - ', accountno.name->>'en_US', ' - ', paychan.name), 'product', 
                acc_date, leasing_ids.amount, 0.00,
                leasing_ids.amount, leasing_ids.amount, leasing_ids.amount, 0.00, 1.00, 0.00,
                0.00, 0.00, False, False, False,
                2, create_dates, 2, create_dates,
                CASE WHEN debit_account_ids.account_type = 'asset_receivable' THEN leasing_ids.end_date
                    WHEN debit_account_ids.account_type = 'liability_payable' THEN (leasing_ids.start_date + interval '30 day')::date
                    ELSE NULL END, leasing_ids.name
            ) ON CONFLICT(id) DO NOTHING;

            INSERT INTO account_move_line(
                id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                move_name, parent_state, name, display_type,
                date, debit, credit, 
                balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                create_uid, create_date, write_uid, write_date, date_maturity, ref
            ) VALUES (
                nextval('account_move_line_id_seq'), account_move_id, leasing_account_ids.account_journal_id, 1, currency, leasing_account_ids.credit_account_id, currency, leasing_ids.debtor_id,
                name_sequence, 'posted', concat(feetypeids.name, ' - ', channelids.name, ' - ', accountno.name->>'en_US', ' - ', paychan.name), 'product',
                acc_date, 0.00, leasing_ids.amount,
                -1 * leasing_ids.amount, -1 * leasing_ids.amount, -1 * leasing_ids.amount, 0.00, 1.00, 0.00,
                0.00, 0.00, False, False, False,
                2, create_dates, 2, create_dates, 
                CASE WHEN credit_account_ids.account_type = 'asset_receivable' THEN leasing_ids.end_date
                    WHEN credit_account_ids.account_type = 'liability_payable' THEN (leasing_ids.start_date + interval '30 day')::date
                    ELSE NULL END, leasing_ids.name
            )
            ON CONFLICT(id)
            DO NOTHING;
            
            RETURN account_move_id;
        ELSE
            RETURN null;
        END IF;
    END;
$$;

---------------------------

DROP FUNCTION IF EXISTS create_journal_interest_eom_lock_date(int, int, varchar);
CREATE OR REPLACE FUNCTION public.create_journal_interest_eom_lock_date(line_id int, leas_account_id int, lockdate varchar)
RETURNS INT
LANGUAGE plpgsql AS
$$
    DECLARE
        create_dates timestamp;
        name_sequence varchar;
        leasing_account_ids record;
        leasing_ids record;
        account_move_id int;
        currency int;
        com_partner_id int;
        debit_account_ids record;
        credit_account_ids record;
        ccek varchar;
        acc_date date;

        feetypeids record;
        channelids record;
        odoo_lockdate varchar;
    BEGIN
        SELECT * FROM leasing_contract_interest lcl JOIN leasing_contract lc ON lc.id = lcl.contract_id WHERE lcl.id = line_id INTO leasing_ids;
        SELECT commercial_partner_id FROM res_partner WHERE id = leasing_ids.debtor_id INTO com_partner_id;
        SELECT mla.id, debit_account_id, credit_account_id, mft.account_journal_id, aj.code, aj.currency_id
            FROM mofi_leasing_account mla
            JOIN mofi_fee_type mft ON mft.id = mla.fee_type_id
            JOIN account_journal aj ON aj.id = mft.account_journal_id
            WHERE mla.id = leas_account_id AND mla.active = true INTO leasing_account_ids;
        IF leasing_account_ids.id IS NOT NULL THEN
            SELECT * FROM account_account WHERE id = leasing_account_ids.debit_account_id INTO debit_account_ids;
            SELECT * FROM account_account WHERE id = leasing_account_ids.credit_account_id INTO credit_account_ids;

            odoo_lockdate :=  get_lock_date_info();
            SELECT CASE WHEN (leasing_ids.order_date + interval '7 hour')::date > odoo_lockdate::date THEN (leasing_ids.order_date + interval '7 hour')::date ELSE lockdate::date END INTO acc_date;

            name_sequence := get_sequence_name_journal(leasing_account_ids.account_journal_id, acc_date::varchar);

            SELECT * FROM mofi_fee_type WHERE id = leasing_ids.fee_type_id INTO feetypeids;
            SELECT * FROM mofi_channel WHERE id = leasing_ids.channel_id INTO channelids;

            IF leasing_ids.debtor_id IS NOT NULL THEN
                SELECT rc.currency_id FROM res_company rc JOIN res_partner rp ON rp.company_id = rc.id WHERE rp.id = leasing_ids.debtor_id INTO currency;
            ELSE
                SELECT currency_id FROM res_company WHERE id = 1 INTO currency;
            END IF;
            SELECT now() at time zone 'utc' INTO create_dates;

            --
            INSERT INTO account_move(
                id, name, partner_id, invoice_date_due, journal_id,
                invoice_user_id, company_id, currency_id, sequence_prefix,
                move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
                amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
                date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
                amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref, contract_ref
            ) VALUES (
                nextval('account_move_id_seq'), name_sequence, leasing_ids.debtor_id, acc_date, leasing_account_ids.account_journal_id,
                2, 1, currency, concat(leasing_account_ids.code, '/', date_part('year', acc_date), '/', date_part('month', acc_date), '/'),
                'entry', '', 0.00, 0.00, leasing_ids.interest_to_eom,
                0.00, 0.00, leasing_ids.interest_to_eom, 0.00,
                acc_date, case when acc_date < create_dates::date then 'posted' else 'draft' end, 
                'not_paid', case when acc_date < create_dates::date then 'no' else 'at_date' end,
                'no_extract_requested', 2, create_dates, 2, create_dates,
                leasing_ids.interest_to_eom, 0.00, com_partner_id, leasing_ids.name, leasing_ids.contract_id
            ) ON CONFLICT (id) DO NOTHING RETURNING ID INTO account_move_id;

            INSERT INTO account_move_line(
                id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                move_name, parent_state, name, display_type,
                date, debit, credit, 
                balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                create_uid, create_date, write_uid, write_date, date_maturity, ref
            ) VALUES (
                nextval('account_move_line_id_seq'), account_move_id, leasing_account_ids.account_journal_id, 1, currency, leasing_account_ids.debit_account_id, currency, leasing_ids.debtor_id,
                name_sequence, case when acc_date < create_dates::date then 'posted' else 'draft' end, concat(feetypeids.name, ' - ', channelids.name), 'product', 
                acc_date, leasing_ids.interest_to_eom, 0.00,
                leasing_ids.interest_to_eom, leasing_ids.interest_to_eom, leasing_ids.interest_to_eom, 0.00, 1.00, 0.00,
                0.00, 0.00, False, False, False,
                2, create_dates, 2, create_dates,
                CASE WHEN debit_account_ids.account_type = 'asset_receivable' THEN leasing_ids.end_date
                    WHEN debit_account_ids.account_type = 'liability_payable' THEN (leasing_ids.start_date + interval '30 day')::date
                    ELSE NULL END, leasing_ids.name
            ) ON CONFLICT(id) DO NOTHING;

            INSERT INTO account_move_line(
                id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                move_name, parent_state, name, display_type,
                date, debit, credit, 
                balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                create_uid, create_date, write_uid, write_date, date_maturity, ref
            ) VALUES (
                nextval('account_move_line_id_seq'), account_move_id, leasing_account_ids.account_journal_id, 1, currency, leasing_account_ids.credit_account_id, currency, leasing_ids.debtor_id,
                name_sequence, case when acc_date < create_dates::date then 'posted' else 'draft' end, concat(feetypeids.name, ' - ', channelids.name), 'product',
                acc_date, 0.00, leasing_ids.interest_to_eom,
                -1 * leasing_ids.interest_to_eom, -1 * leasing_ids.interest_to_eom, -1 * leasing_ids.interest_to_eom, 0.00, 1.00, 0.00,
                0.00, 0.00, False, False, False,
                2, create_dates, 2, create_dates, 
                CASE WHEN credit_account_ids.account_type = 'asset_receivable' THEN leasing_ids.end_date
                    WHEN credit_account_ids.account_type = 'liability_payable' THEN (leasing_ids.start_date + interval '30 day')::date
                    ELSE NULL END, leasing_ids.name
            )
            ON CONFLICT(id)
            DO NOTHING;
            
            RETURN account_move_id;
        ELSE
            RETURN null;
        END IF;
    END;
$$;

---------------------------

DROP FUNCTION IF EXISTS create_journal_interest_journal_lock_date(int, int, varchar);
CREATE OR REPLACE FUNCTION public.create_journal_interest_journal_lock_date(line_id int, leas_account_id int, lockdate varchar)
RETURNS INT
LANGUAGE plpgsql AS
$$
    DECLARE
        create_dates timestamp;
        name_sequence varchar;
        leasing_account_ids record;
        leasing_ids record;
        account_move_id int;
        currency int;
        com_partner_id int;
        debit_account_ids record;
        credit_account_ids record;
        acc_date date;

        feetypeids record;
        channelids record;
        odoo_lockdate varchar;
    BEGIN
        SELECT * FROM leasing_contract_interest lcl JOIN leasing_contract lc ON lc.id = lcl.contract_id WHERE lcl.id = line_id INTO leasing_ids;
        SELECT commercial_partner_id FROM res_partner WHERE id = leasing_ids.debtor_id INTO com_partner_id;
        SELECT mla.id, debit_account_id, credit_account_id, mft.account_journal_id, aj.code, aj.currency_id
            FROM mofi_leasing_account mla
            JOIN mofi_fee_type mft ON mft.id = mla.fee_type_id
            JOIN account_journal aj ON aj.id = mft.account_journal_id
            WHERE mla.id = leas_account_id AND mla.active = true INTO leasing_account_ids;
        IF leasing_account_ids.id IS NOT NULL THEN
            SELECT * FROM account_account WHERE id = leasing_account_ids.debit_account_id INTO debit_account_ids;
            SELECT * FROM account_account WHERE id = leasing_account_ids.credit_account_id INTO credit_account_ids;

            odoo_lockdate :=  get_lock_date_info();
            SELECT CASE WHEN (leasing_ids.order_date + interval '7 hour')::date > odoo_lockdate::date THEN (leasing_ids.order_date + interval '7 hour')::date ELSE lockdate::date END INTO acc_date;

            name_sequence := get_sequence_name_journal(leasing_account_ids.account_journal_id, acc_date::varchar);

            SELECT * FROM mofi_fee_type WHERE id = leasing_ids.fee_type_id INTO feetypeids;
            SELECT * FROM mofi_channel WHERE id = leasing_ids.channel_id INTO channelids;

            IF leasing_ids.debtor_id IS NOT NULL THEN
                SELECT rc.currency_id FROM res_company rc JOIN res_partner rp ON rp.company_id = rc.id WHERE rp.id = leasing_ids.debtor_id INTO currency;
            ELSE
                SELECT currency_id FROM res_company WHERE id = 1 INTO currency;
            END IF;
            SELECT now() at time zone 'utc' INTO create_dates;
            --
            INSERT INTO account_move(
                id, name, partner_id, invoice_date_due, journal_id,
                invoice_user_id, company_id, currency_id, sequence_prefix,
                move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
                amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
                date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
                amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref, contract_ref
            ) VALUES (
                nextval('account_move_id_seq'), name_sequence, leasing_ids.debtor_id, acc_date, leasing_account_ids.account_journal_id,
                2, 1, currency, concat(leasing_account_ids.code, '/', date_part('year', acc_date), '/', date_part('month', acc_date), '/'),
                'entry', '', 0.00, 0.00, leasing_ids.interest_to_due_date,
                0.00, 0.00, leasing_ids.interest_to_due_date, 0.00,
                acc_date, case when acc_date < create_dates::date then 'posted' else 'draft' end,
                'not_paid', case when acc_date < create_dates::date then 'no' else 'at_date' end,
                'no_extract_requested', 2, create_dates, 2, create_dates,
                leasing_ids.interest_to_due_date, 0.00, com_partner_id, leasing_ids.name, leasing_ids.contract_id
            ) ON CONFLICT (id) DO NOTHING RETURNING ID INTO account_move_id;

            INSERT INTO account_move_line(
                id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                move_name, parent_state, name, display_type,
                date, debit, credit, 
                balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                create_uid, create_date, write_uid, write_date, date_maturity, ref
            ) VALUES (
                nextval('account_move_line_id_seq'), account_move_id, leasing_account_ids.account_journal_id, 1, currency, leasing_account_ids.debit_account_id, currency, leasing_ids.debtor_id,
                name_sequence, case when acc_date < create_dates::date then 'posted' else 'draft' end, concat(feetypeids.name, ' - ', channelids.name), 'product', 
                acc_date, leasing_ids.interest_to_due_date, 0.00,
                leasing_ids.interest_to_due_date, leasing_ids.interest_to_due_date, leasing_ids.interest_to_due_date, 0.00, 1.00, 0.00,
                0.00, 0.00, False, False, False,
                2, create_dates, 2, create_dates,
                CASE WHEN debit_account_ids.account_type = 'asset_receivable' THEN leasing_ids.end_date
                    WHEN debit_account_ids.account_type = 'liability_payable' THEN (leasing_ids.start_date + interval '30 day')::date
                    ELSE NULL END, leasing_ids.name
            ) ON CONFLICT(id) DO NOTHING;

            INSERT INTO account_move_line(
                id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                move_name, parent_state, name, display_type,
                date, debit, credit, 
                balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
                price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
                create_uid, create_date, write_uid, write_date, date_maturity, ref
            ) VALUES (
                nextval('account_move_line_id_seq'), account_move_id, leasing_account_ids.account_journal_id, 1, currency, leasing_account_ids.credit_account_id, currency, leasing_ids.debtor_id,
                name_sequence, case when acc_date < create_dates::date then 'posted' else 'draft' end, concat(feetypeids.name, ' - ', channelids.name), 'product',
                acc_date, 0.00, leasing_ids.interest_to_due_date,
                -1 * leasing_ids.interest_to_due_date, -1 * leasing_ids.interest_to_due_date, -1 * leasing_ids.interest_to_due_date, 0.00, 1.00, 0.00,
                0.00, 0.00, False, False, False,
                2, create_dates, 2, create_dates, 
                CASE WHEN credit_account_ids.account_type = 'asset_receivable' THEN leasing_ids.end_date
                    WHEN credit_account_ids.account_type = 'liability_payable' THEN (leasing_ids.start_date + interval '30 day')::date
                    ELSE NULL END, leasing_ids.name
            )
            ON CONFLICT(id)
            DO NOTHING;
            
            RETURN account_move_id;
        ELSE
            RETURN null;
        END IF;
    END;
$$;

-- select create_journal_interest_eom(2153, 291)
---------------------------

DROP FUNCTION IF EXISTS create_journal_amortization_lock_date(int, int, varchar);
CREATE OR REPLACE FUNCTION public.create_journal_amortization_lock_date(line_id int, feetype int, lockdate varchar)
RETURNS INT
LANGUAGE plpgsql AS
$$
    DECLARE
        create_dates timestamp;
        name_sequence varchar;
        leasing_account_ids record;
        amortization_ids record;
        account_move_id int;
        currency int;
        com_partner_id int;
        debit_account_ids record;
        credit_account_ids record;
        acc_date date;
        leasing_ids record;

        feetypeids record;
        channelids record;
        odoo_lockdate varchar;
    BEGIN
        SELECT mla.*, mlal.id as line_id, amount, order_date FROM mofi_leasing_amortization_line mlal JOIN mofi_leasing_amortization mla ON mla.id = mlal.amortization_id WHERE mlal.id = line_id INTO amortization_ids;
        SELECT commercial_partner_id FROM res_partner WHERE id = amortization_ids.debtor_id INTO com_partner_id;
        SELECT * FROM leasing_contract WHERE id = amortization_ids.ca_contract_number_id INTO leasing_ids;
        SELECT mft.amortization_account_journal_id as journalid, mla.debit_account_amortization_id as debitacc, mla.credit_account_amortization_id as creditacc, aj.*
            FROM mofi_leasing_account mla
            JOIN mofi_fee_type mft ON mla.fee_type_id = mft.id
            JOIN account_journal aj ON aj.id = mft.amortization_account_journal_id
            WHERE mft.id = feetype
                AND mla.funding_type_id = leasing_ids.funding_type_id
                AND mla.channel_id = amortization_ids.channel_id
                AND mla.loan_purpose_id = leasing_ids.loan_purpose_id
                AND mla.is_restructure = leasing_ids.is_restructure AND mla.active = true INTO leasing_account_ids;

        IF leasing_account_ids.journalid IS NOT NULL THEN
            SELECT * FROM account_account WHERE id = leasing_account_ids.debitacc INTO debit_account_ids;
            SELECT * FROM account_account WHERE id = leasing_account_ids.creditacc INTO credit_account_ids;

            odoo_lockdate :=  get_lock_date_info();
            SELECT CASE WHEN (amortization_ids.order_date + interval '7 hour')::date > odoo_lockdate::date THEN (amortization_ids.order_date + interval '7 hour')::date ELSE lockdate::date END INTO acc_date;

            name_sequence := get_sequence_name_journal(leasing_account_ids.journalid, acc_date::varchar);

            SELECT * FROM mofi_fee_type WHERE id = feetype INTO feetypeids;
            SELECT * FROM mofi_channel WHERE id = leasing_ids.channel_id INTO channelids;

            IF amortization_ids.debtor_id IS NOT NULL THEN
                SELECT rc.currency_id FROM res_company rc JOIN res_partner rp ON rp.company_id = rc.id WHERE rp.id = amortization_ids.debtor_id INTO currency;
            ELSE
                SELECT currency_id FROM res_company WHERE id = 1 INTO currency;
            END IF;
            SELECT now() at time zone 'utc' INTO create_dates;
            --
            INSERT INTO account_move(
                id, name, partner_id, invoice_date_due, journal_id,
                invoice_user_id, company_id, currency_id, sequence_prefix,
                move_type, invoice_origin, amount_untaxed, amount_tax, amount_total,
                amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
                date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
                amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref, contract_ref, amortization_ref
            ) VALUES (---------------------------
                nextval('account_move_id_seq'), name_sequence, amortization_ids.debtor_id, acc_date, leasing_account_ids.journalid,
                2, 1, currency, concat(leasing_account_ids.code, '/', date_part('year', acc_date), '/', date_part('month', acc_date), '/'),
                'entry', '', 0.00, 0.00, amortization_ids.amount,
                0.00, 0.00, amortization_ids.amount, 0.00,
                acc_date, case when acc_date::date < create_dates::date then 'posted' else 'draft' end,
                'not_paid', case when acc_date::date < create_dates::date then 'no' else 'at_date' end,
                'no_extract_requested', 2, create_dates, 2, create_dates,
                amortization_ids.amount, 0.00, com_partner_id, amortization_ids.name, amortization_ids.ca_contract_number_id, amortization_ids.id
            ) ON CONFLICT (id) DO NOTHING RETURNING ID INTO account_move_id;

            INSERT INTO account_move_line(
                id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                move_name, parent_state, name, display_type,
                date, debit, credit,
                balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit,
                price_subtotal, price_total, tax_tag_invert, reconciled, blocked,
                create_uid, create_date, write_uid, write_date, date_maturity, ref
            ) VALUES (
                nextval('account_move_line_id_seq'), account_move_id, leasing_account_ids.journalid, 1, currency, leasing_account_ids.debitacc, currency, amortization_ids.debtor_id,
                name_sequence, case when acc_date::date < create_dates::date then 'posted' else 'draft' end, concat('Amortization - ', feetypeids.name, ' - ', channelids.name), 'product',
                acc_date, amortization_ids.amount, 0.00,
                amortization_ids.amount, amortization_ids.amount, amortization_ids.amount, 0.00, 1.00, 0.00,
                0.00, 0.00, False, False, False,
                2, create_dates, 2, create_dates,
                CASE WHEN debit_account_ids.account_type = 'asset_receivable' THEN amortization_ids.end_date
                    WHEN debit_account_ids.account_type = 'liability_payable' THEN (amortization_ids.start_date + interval '30 day')::date
                    ELSE NULL END, amortization_ids.name
            ) ON CONFLICT(id) DO NOTHING;

            INSERT INTO account_move_line(
                id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
                move_name, parent_state, name, display_type,
                date, debit, credit,
                balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit,
                price_subtotal, price_total, tax_tag_invert, reconciled, blocked,
                create_uid, create_date, write_uid, write_date, date_maturity, ref
            ) VALUES (
                nextval('account_move_line_id_seq'), account_move_id, leasing_account_ids.journalid, 1, currency, leasing_account_ids.creditacc, currency, amortization_ids.debtor_id,
                name_sequence, case when acc_date::date < create_dates::date then 'posted' else 'draft' end, concat('Amortization - ', feetypeids.name, ' - ', channelids.name), 'product',
                acc_date, 0.00, amortization_ids.amount,
                -1 * amortization_ids.amount, -1 * amortization_ids.amount, -1 * amortization_ids.amount, 0.00, 1.00, 0.00,
                0.00, 0.00, False, False, False,
                2, create_dates, 2, create_dates, 
                CASE WHEN credit_account_ids.account_type = 'asset_receivable' THEN amortization_ids.end_date
                    WHEN credit_account_ids.account_type = 'liability_payable' THEN (amortization_ids.start_date + interval '30 day')::date
                    ELSE NULL END, amortization_ids.name
            )
            ON CONFLICT(id)
            DO NOTHING;
            
            RETURN account_move_id;
        ELSE
            RETURN null;
        END IF;
    END;
$$;

---------------------------