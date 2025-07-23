DROP FUNCTION IF EXISTS create_journal_reverse(int);
CREATE OR REPLACE FUNCTION public.create_journal_reverse(last_move_id int)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        name_sequence varchar;
        leasing_account_ids record;
        last_move_ids record;
        new_move_ids int;
        reconcile_name varchar;
        reconcile_id int;
        reconcile_ids record;
        account_ids record;
        lockdate varchar;
        journaldate timestamp;
    BEGIN
        SELECT * FROM account_move WHERE id = last_move_id INTO last_move_ids;
        SELECT * FROM account_journal WHERE id = last_move_ids.journal_id INTO leasing_account_ids;

        lockdate := get_lock_date_info();

        IF lockdate IS NOT NULL THEN
            IF last_move_ids.date <= lockdate::date THEN
                SELECT lockdate::date + interval '1 day' INTO journaldate;
            ELSE
                journaldate := last_move_ids.date::timestamp;
            END IF;
        ELSE
            journaldate := last_move_ids.date::timestamp;
        END IF;
        name_sequence := get_sequence_name_journal(last_move_ids.journal_id, journaldate::varchar);
        --
        INSERT INTO account_move(
            id, name,
            partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, currency_id,
            sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
            amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
            date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
            amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref, contract_ref, amortization_ref
        )
        SELECT
            nextval('account_move_id_seq'), name_sequence,
            partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, currency_id,
            concat(leasing_account_ids.code, '/', date_part('year', date), '/', date_part('month', date), '/'), move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
            amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
            journaldate::date, 'posted', payment_state, auto_post, extract_state, 2, now() at time zone 'utc', 2, now() at time zone 'utc',
            amount_total_signed, amount_untaxed_signed, commercial_partner_id, concat('Reversal of: ', name), contract_ref, amortization_ref
        FROM account_move WHERE id = last_move_id 
        ON CONFLICT(id)
        DO NOTHING RETURNING ID INTO new_move_ids;

        INSERT INTO account_move_line(
            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            move_name, parent_state, name, display_type, date, debit, credit, 
            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
            create_uid, create_date, write_uid, write_date, date_maturity, ref
        )
        SELECT
            nextval('account_move_line_id_seq'), new_move_ids, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            name_sequence, parent_state, name, display_type, date, credit, debit, 
            credit-debit, credit-debit, credit-debit, 0.00, 1.00, 0.00,
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
            2, now() at time zone 'utc', 2, now() at time zone 'utc', date_maturity, ref
        FROM account_move_line WHERE move_id = last_move_id AND credit = 0
        ON CONFLICT(id)
        DO NOTHING;

        INSERT INTO account_move_line(
            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            move_name, parent_state, name, display_type, date, debit, credit, 
            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
            create_uid, create_date, write_uid, write_date, date_maturity, ref
        )
        SELECT
            nextval('account_move_line_id_seq'), new_move_ids, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            name_sequence, parent_state, name, display_type, date, credit, debit, 
            credit-debit, credit-debit, credit-debit, 0.00, 1.00, 0.00,
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked,
            2, now() at time zone 'utc', 2, now() at time zone 'utc', date_maturity, ref
        FROM account_move_line WHERE move_id = last_move_id AND debit = 0
        ON CONFLICT(id)
        DO NOTHING;
        
        -- reconcile step
        SELECT nextval(concat('ir_sequence_', LPAD(id::varchar,3,'0'))) FROM ir_sequence WHERE code = 'account.reconcile' ORDER BY name DESC LIMIT 1 INTO reconcile_name;
        INSERT INTO account_full_reconcile (id, name, create_uid, create_date, write_uid, write_date)
            VALUES (nextval('account_full_reconcile_id_seq'), concat('A', reconcile_name), 2, now() at time zone 'utc', 2, now() at time zone 'utc') RETURNING id INTO reconcile_id;
        SELECT * FROM account_full_reconcile WHERE id = reconcile_id ORDER BY name DESC LIMIT 1 INTO reconcile_ids;

        SELECT aa.* FROM account_account aa JOIN account_move_line aml ON aml.account_id = aa.id WHERE aml.move_id = last_move_id AND aml.credit = 0 INTO account_ids;

        IF account_ids.account_type in ('asset_receivable', 'liability_payable') THEN
            UPDATE account_move_line SET reconciled = true, full_reconcile_id = reconcile_id, matching_number = reconcile_ids.name WHERE move_id = last_move_id AND credit = 0;
        END IF;
        SELECT aa.* FROM account_account aa JOIN account_move_line aml ON aml.account_id = aa.id WHERE aml.move_id = new_move_ids AND aml.debit = 0 INTO account_ids;
        IF account_ids.account_type in ('asset_receivable', 'liability_payable') THEN
            UPDATE account_move_line SET reconciled = true, full_reconcile_id = reconcile_id, matching_number = reconcile_ids.name WHERE move_id = new_move_ids AND debit = 0;
        END IF;

        SELECT nextval(concat('ir_sequence_', LPAD(id::varchar,3,'0'))) FROM ir_sequence WHERE code = 'account.reconcile' ORDER BY name DESC LIMIT 1 INTO reconcile_name;
        INSERT INTO account_full_reconcile (id, name, create_uid, create_date, write_uid, write_date)
            VALUES (nextval('account_full_reconcile_id_seq'), concat('A', reconcile_name), 2, now() at time zone 'utc', 2, now() at time zone 'utc') RETURNING id INTO reconcile_id;
        SELECT * FROM account_full_reconcile WHERE id = reconcile_id ORDER BY name DESC LIMIT 1 INTO reconcile_ids;

        SELECT aa.* FROM account_account aa JOIN account_move_line aml ON aml.account_id = aa.id WHERE aml.move_id = last_move_id AND aml.debit = 0 INTO account_ids;

        IF account_ids.account_type in ('asset_receivable', 'liability_payable') THEN
            UPDATE account_move_line SET reconciled = true, full_reconcile_id = reconcile_id, matching_number = reconcile_ids.name WHERE move_id = last_move_id AND debit = 0;
        END IF;
        SELECT aa.* FROM account_account aa JOIN account_move_line aml ON aml.account_id = aa.id WHERE aml.move_id = new_move_ids AND aml.credit = 0 INTO account_ids;
        IF account_ids.account_type in ('asset_receivable', 'liability_payable') THEN
            UPDATE account_move_line SET reconciled = true, full_reconcile_id = reconcile_id, matching_number = reconcile_ids.name WHERE move_id = new_move_ids AND credit = 0;
        END IF;
    END;
$$;

--select create_journal_reverse(4720);
-------------------------------------

DROP FUNCTION IF EXISTS create_journal_reverse_with_date(int, varchar);
CREATE OR REPLACE FUNCTION public.create_journal_reverse_with_date(last_move_id int, new_date varchar)
RETURNS VOID
LANGUAGE plpgsql AS
$$
    DECLARE
        name_sequence varchar;
        leasing_account_ids record;
        last_move_ids record;
        new_move_ids int;
        reconcile_name varchar;
        reconcile_id int;
        reconcile_ids record;
        account_ids record;
    BEGIN
        SELECT * FROM account_move WHERE id = last_move_id INTO last_move_ids;
        SELECT * FROM account_journal WHERE id = last_move_ids.journal_id INTO leasing_account_ids;
        name_sequence := get_sequence_name_journal(last_move_ids.journal_id, new_date::varchar);
        --
        INSERT INTO account_move(
            id, name,
            partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, currency_id,
            sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
            amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
            date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
            amount_total_signed, amount_untaxed_signed, commercial_partner_id, ref, contract_ref, amortization_ref
        )
        SELECT
            nextval('account_move_id_seq'), name_sequence,
            partner_id, new_date::date, journal_id, invoice_user_id, company_id, currency_id,
            concat(leasing_account_ids.code, '/', date_part('year', new_date::date), '/', date_part('month', new_date::date), '/'), move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
            amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
            new_date::date, 'posted', payment_state, auto_post, extract_state, 2, now() at time zone 'utc', 2, now() at time zone 'utc',
            amount_total_signed, amount_untaxed_signed, commercial_partner_id, concat('Reversal of: ', name), contract_ref, amortization_ref
        FROM account_move WHERE id = last_move_id 
        ON CONFLICT(id)
        DO NOTHING RETURNING ID INTO new_move_ids;

        INSERT INTO account_move_line(
            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            move_name, parent_state, name, display_type, date, debit, credit, 
            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
            create_uid, create_date, write_uid, write_date, date_maturity, ref
        )
        SELECT
            nextval('account_move_line_id_seq'), new_move_ids, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            name_sequence, parent_state, name, display_type, new_date::date, credit, debit, 
            credit-debit, credit-debit, credit-debit, 0.00, 1.00, 0.00,
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
            2, now() at time zone 'utc', 2, now() at time zone 'utc', date_maturity, ref
        FROM account_move_line WHERE move_id = last_move_id AND credit = 0
        ON CONFLICT(id)
        DO NOTHING;

        INSERT INTO account_move_line(
            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            move_name, parent_state, name, display_type, date, debit, credit, 
            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
            create_uid, create_date, write_uid, write_date, date_maturity, ref
        )
        SELECT
            nextval('account_move_line_id_seq'), new_move_ids, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            name_sequence, parent_state, name, display_type, new_date::date, credit, debit, 
            credit-debit, credit-debit, credit-debit, 0.00, 1.00, 0.00,
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked,
            2, now()  at time zone 'utc', 2, now() at time zone 'utc', date_maturity, ref
        FROM account_move_line WHERE move_id = last_move_id AND debit = 0
        ON CONFLICT(id)
        DO NOTHING;

        -- reconcile step
        SELECT nextval(concat('ir_sequence_', LPAD(id::varchar,3,'0'))) FROM ir_sequence WHERE code = 'account.reconcile' ORDER BY name DESC LIMIT 1 INTO reconcile_name;
        INSERT INTO account_full_reconcile (id, name, create_uid, create_date, write_uid, write_date)
            VALUES (nextval('account_full_reconcile_id_seq'), concat('A', reconcile_name), 2, now() at time zone 'utc', 2, now() at time zone 'utc') RETURNING id INTO reconcile_id;
        SELECT * FROM account_full_reconcile WHERE id = reconcile_id ORDER BY name DESC LIMIT 1 INTO reconcile_ids;

        SELECT aa.* FROM account_account aa JOIN account_move_line aml ON aml.account_id = aa.id WHERE aml.move_id = last_move_id AND aml.credit = 0 INTO account_ids;

        IF account_ids.account_type in ('asset_receivable', 'liability_payable') THEN
            UPDATE account_move_line SET reconciled = true, full_reconcile_id = reconcile_id, matching_number = reconcile_ids.name WHERE move_id = last_move_id AND credit = 0;		
        END IF;
        SELECT aa.* FROM account_account aa JOIN account_move_line aml ON aml.account_id = aa.id WHERE aml.move_id = new_move_ids AND aml.debit = 0 INTO account_ids;
        IF account_ids.account_type in ('asset_receivable', 'liability_payable') THEN
            UPDATE account_move_line SET reconciled = true, full_reconcile_id = reconcile_id, matching_number = reconcile_ids.name WHERE move_id = new_move_ids AND debit = 0;		
        END IF;

        SELECT nextval(concat('ir_sequence_', LPAD(id::varchar,3,'0'))) FROM ir_sequence WHERE code = 'account.reconcile' ORDER BY name DESC LIMIT 1 INTO reconcile_name;
        INSERT INTO account_full_reconcile (id, name, create_uid, create_date, write_uid, write_date)
            VALUES (nextval('account_full_reconcile_id_seq'), concat('A', reconcile_name), 2, now() at time zone 'utc', 2, now() at time zone 'utc') RETURNING id INTO reconcile_id;
        SELECT * FROM account_full_reconcile WHERE id = reconcile_id ORDER BY name DESC LIMIT 1 INTO reconcile_ids;

        SELECT aa.* FROM account_account aa JOIN account_move_line aml ON aml.account_id = aa.id WHERE aml.move_id = last_move_id AND aml.debit = 0 INTO account_ids;

        IF account_ids.account_type in ('asset_receivable', 'liability_payable') THEN
            UPDATE account_move_line SET reconciled = true, full_reconcile_id = reconcile_id, matching_number = reconcile_ids.name WHERE move_id = last_move_id AND debit = 0;
        END IF;
        SELECT aa.* FROM account_account aa JOIN account_move_line aml ON aml.account_id = aa.id WHERE aml.move_id = new_move_ids AND aml.credit = 0 INTO account_ids;
        IF account_ids.account_type in ('asset_receivable', 'liability_payable') THEN
            UPDATE account_move_line SET reconciled = true, full_reconcile_id = reconcile_id, matching_number = reconcile_ids.name WHERE move_id = new_move_ids AND credit = 0;
        END IF;
    END;
$$;
