DROP TABLE IF EXISTS inv_temp;
CREATE TABLE inv_temp(
    id bigserial,
    inv_id int,
    so_id int,
    invoice_date timestamp,
    partner_id int,
    journal_id int,
    due_date timestamp,
    currency_id int,
    invoice_user_id int,
    sequence_prefix varchar,
    sequence int,
    name varchar,
    move_type varchar,
    invoice_origin varchar,
    amount_untaxed numeric,
    amount_tax numeric,
    payment_term_id int,
    commercial_partner_id int
);

DROP TABLE IF EXISTS invline_temp;
CREATE TABLE invline_temp(
    id bigserial,
    inv_id int,
    invline_id int,
    soline_id int,
    currency_id int,
    partner_id int,
    date timestamp,
    sequence int,

    account_id int,
    debit numeric,
    credit numeric,
    balance numeric,
    journal_id int,

    product_id int,
    product_uom_id int,
    name varchar,
    display_type varchar,
    qty numeric,
    price_unit numeric,
    discount numeric,
    amount_untaxed numeric,
    amount_total numeric,
    amount_tax numeric
);

DROP FUNCTION IF EXISTS generate_invoice(integer);
CREATE OR REPLACE FUNCTION public.generate_invoice(sale_id integer)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sorder record;
        slorder record;
        invid integer;
        journal integer;
        account integer;
        acc_tax integer;
        seq int;
        tax_ids record;
        tax record;
        cpartner_id int;
    BEGIN
        TRUNCATE inv_temp;
        TRUNCATE invline_temp;

        SELECT nextval('account_move_id_seq') INTO invid;
        
        SELECT * FROM sale_order WHERE state = 'sale' AND id = sale_id AND invoice_status = 'to invoice' INTO sorder;
        SELECT commercial_partner_id FROM res_partner WHERE id = sorder.partner_id INTO cpartner_id;
        INSERT INTO inv_temp (
            inv_id, so_id, partner_id, journal_id, due_date, currency_id,
            invoice_user_id, sequence_prefix, name, move_type, invoice_origin, amount_untaxed, amount_tax,
            payment_term_id, commercial_partner_id
        )
        SELECT 
            invid, sale_id, sorder.partner_id, aj.id, sorder.date_order, sorder.currency_id,
            sorder.user_id, '', '/', 'out_invoice', sorder.name, ROUND(sorder.amount_untaxed, 2), ROUND(sorder.amount_tax, 2),
            sorder.payment_term_id, cpartner_id
        FROM account_journal aj
        WHERE company_id = sorder.company_id
            AND type = 'sale';

        SELECT id FROM account_journal WHERE type='sale' INTO journal;
        SELECT default_account_id FROM account_journal WHERE id = journal INTO account;

        FOR slorder IN SELECT sol.* FROM sale_order_line sol WHERE order_id = sale_id AND invoice_status = 'to invoice'
        LOOP
            INSERT INTO invline_temp(
                inv_id, invline_id, soline_id, currency_id, partner_id, date, account_id,
                debit, credit, balance, journal_id, product_id, product_uom_id, name,
                display_type, qty, price_unit, discount, amount_untaxed, amount_total, amount_tax
            )
            SELECT
                invid, nextval('account_move_line_id_seq'), slorder.id, slorder.currency_id, sorder.partner_id, sorder.date_order, account, 
                0.00, ROUND(slorder.product_uom_qty * slorder.price_unit, 2), 0.00, journal, 
                slorder.product_id, slorder.product_uom, slorder.name, 'product', slorder.product_uom_qty,
                ROUND(slorder.price_unit, 2), ROUND(slorder.discount, 2), ROUND(slorder.product_uom_qty * slorder.price_unit, 2), ROUND(slorder.price_total, 2),
                ROUND(slorder.price_total - slorder.price_subtotal, 2);
            
            IF slorder.price_tax > 0 THEN
                FOR tax_ids IN SELECT at.* FROM product_product pp 
                    JOIN product_template pt ON pt.id = pp.product_tmpl_id 
                    JOIN product_taxes_rel ptr ON ptr.prod_id = pt.id
                    JOIN account_tax at ON at.id = ptr.tax_id
                    WHERE pp.id = slorder.product_id AND at.active = True
                    
                LOOP
                    SELECT account_id FROM account_tax_repartition_line WHERE invoice_tax_id = tax_ids.id AND repartition_type = 'tax' INTO acc_tax;
                    INSERT INTO invline_temp(
                        inv_id, invline_id, soline_id, currency_id, partner_id, date, account_id,
                        debit, credit, balance, journal_id, product_id, product_uom_id, name,
                        display_type, qty, price_unit, discount, amount_untaxed, amount_total, amount_tax
                    )
                    SELECT 
                        invid, nextval('account_move_line_id_seq'), null, slorder.currency_id, sorder.partner_id, sorder.date_order, acc_tax, 
                        0.0, 
                        CASE 
                            WHEN tax_ids.amount_type = 'fixed' THEN ROUND(tax_ids.amount, 2)
                            WHEN tax_ids.amount_type = 'percent' THEN ROUND(slorder.price_subtotal * (tax_ids.amount / 100), 2)
                            ELSE 0.0
                        END as taxes_amount,
                        0.0, journal, null, null, tax_ids.name, 'tax', 0.0, 0.0, 0.0, 0.0, 0.0, 0.0;
                END LOOP;
            END IF;
        END LOOP;

        UPDATE sale_order SET invoice_status = 'invoiced' WHERE id = sale_id;

        SELECT sequence FROM sale_order_line WHERE order_id = sale_id GROUP BY sequence INTO seq;
        UPDATE inv_temp SET sequence = seq;
        UPDATE invline_temp SET balance = debit-credit, sequence = seq;
        
        PERFORM generate_create_invoice();
        PERFORM generate_create_invoice_line();
        PERFORM sync_so_and_invoice();
    END;
$$;

DROP FUNCTION IF EXISTS generate_create_invoice();
CREATE OR REPLACE FUNCTION public.generate_create_invoice()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        
        INSERT INTO account_move(
            id, name, partner_id, invoice_date_due, journal_id, invoice_user_id, company_id, 
            currency_id, sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_total, 
            amount_residual, amount_tax_signed, amount_total_in_currency_signed, amount_residual_signed,
            date, state, payment_state, auto_post, extract_state, create_uid, create_date, write_uid, write_date,
            amount_total_signed, amount_untaxed_signed, partner_shipping_id, commercial_partner_id,
			invoice_payment_term_id
        )
        SELECT 
            inv_id, '/', partner_id, 
            CASE 
                WHEN apt.name->>'en_US' = '15 Days' THEN (it.due_date + interval '15 day')::date
                WHEN apt.name->>'en_US' = '21 Days' THEN (it.due_date + interval '21 day')::date
                WHEN apt.name->>'en_US' = '30 Days' THEN (it.due_date + interval '30 day')::date
                WHEN apt.name->>'en_US' = '45 Days' THEN (it.due_date + interval '45 day')::date
                WHEN apt.name->>'en_US' = '2 Months' THEN (it.due_date + interval '2 month')::date
                WHEN apt.name->>'en_US' = 'End of Following Month' THEN (date_trunc('month', it.due_date) + interval '1 month' - interval '1 day')::date
                else it.due_date::date
            END AS due_date, 
            journal_id, invoice_user_id, 1,
            currency_id, sequence_prefix, move_type, invoice_origin, amount_untaxed, amount_tax, amount_untaxed + amount_tax,
            amount_untaxed + amount_tax, amount_tax, amount_untaxed + amount_tax, amount_untaxed + amount_tax, 
            due_date::date, 'draft', 'not_paid', 'no', 'no_extract_requested', 1, now(), 1, now(),
            amount_untaxed + amount_tax, amount_untaxed, partner_id, commercial_partner_id,
			payment_term_id
        FROM inv_temp it
        JOIN account_payment_term apt ON apt.id = it.payment_term_id
        ON CONFLICT(id)
        DO NOTHING;
    END;
$$;

DROP FUNCTION IF EXISTS generate_create_invoice_line();
CREATE OR REPLACE FUNCTION public.generate_create_invoice_line()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        tax_info boolean;
    BEGIN
        -- create invoice line for each product (credit)
        INSERT INTO account_move_line(
            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            product_id, product_uom_id, move_name, parent_state, name, display_type, date, debit, credit, 
            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
            price_subtotal, price_total, discount, tax_tag_invert, reconciled, blocked, is_downpayment,
            create_uid, create_date, write_uid, write_date, sequence
        )
        SELECT
            invline_id, inv_id, journal_id, 1, currency_id, account_id, currency_id, partner_id,
            product_id, product_uom_id, '/', 'draft', name, display_type, date::date, debit, credit,
            balance, balance, debit, debit, qty, price_unit,
            qty * price_unit, qty * price_unit, discount, 
            False, False, False, False,
            1, now(), 1, now(), sequence
        FROM invline_temp
        ON CONFLICT(id)
        DO NOTHING;

        -- create invoice line for account receivable (debit)
        INSERT INTO account_move_line(
            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            product_id, product_uom_id, move_name, parent_state, name, display_type, date, debit, credit, 
            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
            price_subtotal, price_total, discount, tax_tag_invert, reconciled, blocked, is_downpayment,
            create_uid, create_date, write_uid, write_date, sequence
        )
        SELECT
            nextval('account_move_line_id_seq'), inv_id, journal_id, 1, currency_id, 6, currency_id, partner_id,
            null, null, '/', 'draft', '', 'payment_term', date::date, sum(credit), 0,
            sum(balance), sum(balance), sum(debit), sum(debit), 0, 0,
            0, 0, 0, False, False, False, False,
            1, now(), 1, now(), sequence
        FROM invline_temp
        GROUP BY inv_id, journal_id, currency_id, currency_id, partner_id, date, sequence
        ON CONFLICT(id)
        DO NOTHING;

        -- update column tax_tag_invert to line with display tax and product have tax
        UPDATE account_move_line SET tax_tag_invert = True
        WHERE id in (SELECT invline_id FROM invline_temp) 
            AND display_type IN ('tax','product') 
            AND product_id IN (SELECT pp.id FROM product_product pp 
                            JOIN product_template pt ON pt.id = pp.product_tmpl_id 
                            JOIN product_taxes_rel ptr ON ptr.prod_id = pt.id 
                            JOIN invline_temp tmp ON tmp.product_id = pp.id);

        UPDATE account_move_line SET tax_tag_invert = True
        WHERE id in (SELECT invline_id FROM invline_temp) 
            AND display_type = 'tax';

        -- insert data tax into account move line
        INSERT INTO account_move_line_account_tax_rel (account_move_line_id, account_tax_id)
        SELECT tmp.invline_id, ptr.tax_id
        FROM product_product pp 
            JOIN product_template pt ON pt.id = pp.product_tmpl_id 
            JOIN product_taxes_rel ptr ON ptr.prod_id = pt.id 
            JOIN invline_temp tmp ON tmp.product_id = pp.id;

    END;
$$;

DROP FUNCTION IF EXISTS sync_so_and_invoice();
CREATE OR REPLACE FUNCTION public.sync_so_and_invoice()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        INSERT INTO sale_order_line_invoice_rel (order_line_id, invoice_line_id)
        SELECT soline_id, invline_id FROM invline_temp WHERE soline_id IS NOT NULL;
    END;
$$;
