DROP TABLE IF EXISTS payment_tmp;
CREATE TABLE payment_tmp(
    id serial,
    inv_id int,
    partner_id int,
    date timestamp,
    journal_id int,
    user_id int,
    currency_id int,
    account_id int,

    name varchar,
    sequence_prefix varchar,
    move_type varchar,
    payment_state varchar,
    auto_post varchar,
    extract_state varchar,
    label varchar,

    amount_untaxed numeric,
    amount_tax numeric,
    amount_total numeric
);

DROP FUNCTION IF EXISTS generate_register_payment_bank(integer);
CREATE OR REPLACE FUNCTION public.generate_register_payment_bank(invid integer)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        invoice record;
        name_seq varchar;
    BEGIN
        TRUNCATE payment_tmp;

        SELECT * FROM account_move WHERE id = invid AND state = 'posted' AND payment_state = 'not_paid' INTO invoice;
        SELECT
            CASE 
                WHEN split_part(name, '/', '2')::int = date_part('year', now())::int THEN split_part(name, '/', '3')::int + 1
                WHEN split_part(name, '/', '2')::int = date_part('year', make_date(split_part(name, '/', '2')::int,1,1))::int THEN split_part(name, '/', '3')::int + 1
                ELSE 0
            END as name_seq
        FROM account_move WHERE journal_id = 7 ORDER BY id desc LIMIT 1 INTO name_seq;

        INSERT INTO payment_tmp(
            inv_id, partner_id, date, journal_id, user_id, currency_id,
            name, sequence_prefix, move_type, payment_state, auto_post,
            extract_state, amount_untaxed, amount_tax, amount_total,
            account_id, label
        )
        SELECT
            nextval('account_move_id_seq'), invoice.partner_id, invoice.invoice_date_due, id, invoice.invoice_user_id, invoice.currency_id,
            concat(code,'/',date_part('year', now()),'/',LPAD(name_seq, 5, '0')), concat(code,'/',date_part('year', now()),'/'), 'entry', 'not_paid', 'no',
            'no_extract_requested', invoice.amount_untaxed, invoice.amount_tax, invoice.amount_total,
            default_account_id, 'payment from query'
        FROM account_journal 
        WHERE id = 7;

        PERFORM generate_invoice_bank();
        PERFORM generate_account_bank_statement();
    END;
$$;

DROP FUNCTION IF EXISTS generate_invoice_bank();
CREATE OR REPLACE FUNCTION public.generate_invoice_bank()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sus_account_id int;
        cpartner_id int;
    BEGIN
        SELECT suspense_account_id FROM account_journal aj JOIN payment_tmp pt ON pt.journal_id = aj.id INTO sus_account_id;
        SELECT commercial_partner_id FROM res_partner rs JOIN payment_tmp pt ON pt.partner_id = rs.id INTO cpartner_id;
        INSERT INTO account_move(
            id, name, partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, 
            currency_id, sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
            amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
            date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
            amount_total_signed, amount_untaxed_signed, commercial_partner_id
        )
        SELECT 
            inv_id, name, cpartner_id, now(), journal_id, user_id, 1,
            currency_id, sequence_prefix, move_type, '', 0.00, 0.00, amount_untaxed + amount_tax,
            0.00, 0.00, amount_untaxed + amount_tax, 0.00, make_date(date_part('year', now())::int,1,1), 
            'posted', 'not_paid', 'no', 'no_extract_requested', user_id, now(), user_id, now(),
            amount_untaxed + amount_tax, 0.00, cpartner_id
        FROM payment_tmp
        ON CONFLICT(id)
        DO NOTHING;
        
        -- debit move line
        INSERT INTO account_move_line(
            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            move_name, parent_state, name, display_type, date, debit, credit, 
            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
            create_uid, create_date, write_uid, write_date
        )
        SELECT
            nextval('account_move_line_id_seq'), inv_id, journal_id, 1, currency_id, account_id, currency_id, cpartner_id,
            name, 'posted', label, 'product', date::date, amount_total, 0.00,
            amount_total, amount_total, amount_total, 0.00, 1.00, 0.00,
            0.00, 0.00, False, False, False,
            user_id, now(), user_id, now()
        FROM payment_tmp
        ON CONFLICT(id)
        DO NOTHING;
        
        -- credit move line
        INSERT INTO account_move_line(
            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            move_name, parent_state, name, display_type, date, debit, credit, 
            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, 
            create_uid, create_date, write_uid, write_date
        )
        SELECT
            nextval('account_move_line_id_seq'), inv_id, journal_id, 1, currency_id, sus_account_id, currency_id, cpartner_id,
            name, 'posted', label, 'product', date::date, 0.00, amount_total, 
            amount_total * -1, amount_total * -1, 0.00, 0.00, 1.00, 0.00,
            0.00, 0.00, False, False, False,
            user_id, now(), user_id, now()
        FROM payment_tmp
        ON CONFLICT(id)
        DO NOTHING;
    END;
$$;

DROP FUNCTION IF EXISTS generate_account_bank_statement();
CREATE OR REPLACE FUNCTION public.generate_account_bank_statement()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        last_index int;
        cpartner_id int;
    BEGIN
        SELECT RIGHT(internal_index,10)::int FROM account_bank_statement_line ORDER BY id DESC LIMIT 1 INTO last_index;
        SELECT commercial_partner_id FROM res_partner rs JOIN payment_tmp pt ON pt.partner_id = rs.id INTO cpartner_id;
        INSERT INTO account_bank_statement_line (
            id, move_id, sequence, currency_id, payment_ref, partner_id,
            internal_index, amount, is_reconciled, amount_residual,
            amount_currency,
            create_uid, create_date, write_uid, write_date
        )
        SELECT
            nextval('account_bank_statement_line_id_seq'), inv_id, 1, currency_id, label, cpartner_id,
            concat(date_part('year', now()),'01012147483646',LPAD((last_index + 1)::varchar,10,'0')), amount_total, False, amount_total * -1,
            0.00,
            user_id, now(), user_id, now()
        FROM payment_tmp;
    END;
$$;
