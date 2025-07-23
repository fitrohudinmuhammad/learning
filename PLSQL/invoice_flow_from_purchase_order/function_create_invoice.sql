DROP TABLE IF EXISTS poinv_temp;
CREATE TABLE poinv_temp(
    id bigserial,
    inv_id int,
    po_id int,
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

DROP TABLE IF EXISTS poinvline_temp;
CREATE TABLE poinvline_temp(
    id bigserial,
    inv_id int,
    invline_id int,
    poline_id int,
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
    amount_untaxed numeric,
    amount_total numeric,
    amount_tax numeric
);

DROP FUNCTION IF EXISTS generate_invoice_po(integer);
CREATE OR REPLACE FUNCTION public.generate_invoice_po(purchase_id integer)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        porder record;
        plorder record;
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
        SELECT * FROM purchase_order WHERE state = 'purchase' AND id = purchase_id AND invoice_status = 'to invoice' INTO porder;
        SELECT commercial_partner_id FROM res_partner WHERE id = porder.partner_id INTO cpartner_id;

        INSERT INTO poinv_temp (
            inv_id, po_id, partner_id, journal_id, due_date, currency_id,
            invoice_user_id, sequence_prefix, name, move_type, invoice_origin, amount_untaxed, amount_tax,
            payment_term_id, commercial_partner_id
        )
        SELECT 
            invid, purchase_id, porder.partner_id, aj.id, porder.date_order, porder.currency_id,
            porder.user_id, '', '/', 'in_invoice', porder.name, ROUND(porder.amount_untaxed, 2), ROUND(porder.amount_tax, 2),
            porder.payment_term_id, cpartner_id
        FROM account_journal aj
        WHERE company_id = porder.company_id
            AND type = 'purchase';

        SELECT id FROM account_journal WHERE type='purchase' INTO journal;
        SELECT default_account_id FROM account_journal WHERE id = journal INTO account;

        FOR plorder IN SELECT pol.* FROM purchase_order_line pol WHERE order_id = purchase_id
        LOOP
            INSERT INTO poinvline_temp(
                inv_id, invline_id, poline_id, currency_id, partner_id, date, account_id,
                debit, credit, balance, journal_id, product_id, product_uom_id, name,
                display_type, qty, price_unit, amount_untaxed, amount_total, amount_tax
            )
            SELECT
                invid, nextval('account_move_line_id_seq'), plorder.id, plorder.currency_id, porder.partner_id, porder.date_planned, account, 
                ROUND((plorder.product_uom_qty)::int * plorder.price_unit, 2), 0.00, ROUND((plorder.product_uom_qty)::int * plorder.price_unit, 2), journal, 
                plorder.product_id, plorder.product_uom, plorder.name, 'product', plorder.product_uom_qty::int,
                ROUND(plorder.price_unit, 2), ROUND((plorder.product_uom_qty)::int * plorder.price_unit, 2), 
                ROUND(plorder.price_total, 2), ROUND(plorder.price_total - plorder.price_subtotal, 2);
            
            IF plorder.price_tax > 0 THEN
                FOR tax_ids IN SELECT at.* FROM product_product pp 
                    JOIN product_template pt ON pt.id = pp.product_tmpl_id 
                    JOIN product_supplier_taxes_rel ptr ON ptr.prod_id = pt.id
                    JOIN account_tax at ON at.id = ptr.tax_id
                    WHERE pp.id = plorder.product_id AND at.active = True
                    
                LOOP
                    SELECT account_id FROM account_tax_repartition_line WHERE invoice_tax_id = tax_ids.id AND repartition_type = 'tax' INTO acc_tax;
                    INSERT INTO poinvline_temp(
                        inv_id, invline_id, poline_id, currency_id, partner_id, date, account_id,
                        debit, credit, balance, journal_id, product_id, product_uom_id, name,
                        display_type, qty, price_unit, amount_untaxed, amount_total, amount_tax
                    )
                    SELECT 
                        invid, nextval('account_move_line_id_seq'), null, plorder.currency_id, porder.partner_id, porder.date_order, acc_tax, 
                        CASE 
                            WHEN tax_ids.amount_type = 'fixed' THEN ROUND(tax_ids.amount, 2)
                            WHEN tax_ids.amount_type = 'percent' THEN ROUND(plorder.price_subtotal * (tax_ids.amount / 100), 2)
                            ELSE 0.0
                        END as taxes_amount,
                        0.0, 0.0, journal, null, null, tax_ids.name, 'tax', 0.0, 0.0, 0.0, 0.0, 0.0;
                END LOOP;
            END IF;
        END LOOP;

        UPDATE purchase_order SET invoice_status = 'to invoice' WHERE id = 15 purchase_id;

        SELECT sequence FROM purchase_order_line WHERE order_id = purchase_id GROUP BY sequence INTO seq;
        UPDATE inv_temp SET sequence = seq;
        UPDATE invline_temp SET balance = debit-credit, sequence = seq;
    END;
$$;

DROP FUNCTION IF EXISTS generate_create_purchase_invoice();
CREATE OR REPLACE FUNCTION public.generate_create_purchase_invoice()
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
        FROM poinv_temp it
        JOIN account_payment_term apt ON apt.id = it.payment_term_id
        ON CONFLICT(id)
        DO NOTHING;
    END;
$$;

DROP FUNCTION IF EXISTS generate_create_purchase_invoice_line();
CREATE OR REPLACE FUNCTION public.generate_create_purchase_invoice_line()
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
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, is_downpayment,
            create_uid, create_date, write_uid, write_date, sequence, purchase_line_id
        )
        SELECT
            invline_id, inv_id, journal_id, 1, currency_id, account_id, currency_id, partner_id,
            product_id, product_uom_id, '/', 'draft', name, display_type, date::date, debit, credit,
            balance, balance, credit, credit, qty, price_unit,
            qty * price_unit, qty * price_unit, 
            False, False, False, False,
            1, now(), 1, now(), sequence, poline_id
        FROM poinvline_temp
        ON CONFLICT(id)
        DO NOTHING;

        -- create invoice line for account payable (debit)
        INSERT INTO account_move_line(
            id, move_id, journal_id, company_id, company_currency_id, account_id, currency_id, partner_id,
            product_id, product_uom_id, move_name, parent_state, name, display_type, date, debit, credit, 
            balance, amount_currency, amount_residual, amount_residual_currency, quantity, price_unit, 
            price_subtotal, price_total, tax_tag_invert, reconciled, blocked, is_downpayment,
            create_uid, create_date, write_uid, write_date, sequence
        )
        SELECT
            nextval('account_move_line_id_seq'), inv_id, journal_id, 1, currency_id, 14, currency_id, partner_id,
            null, null, '/', 'draft', '', 'payment_term', date::date, 0, sum(debit),
            sum(balance), sum(balance), sum(credit), sum(credit), 0, 0,
            0, 0, False, False, False, False,
            1, now(), 1, now(), sequence
        FROM poinvline_temp
        GROUP BY inv_id, journal_id, currency_id, currency_id, partner_id, date, sequence
        ON CONFLICT(id)
        DO NOTHING;

        -- update column tax_tag_invert to line with display tax and product have tax
        UPDATE account_move_line SET tax_tag_invert = True
        WHERE id in (SELECT invline_id FROM invline_temp) 
            AND display_type IN ('tax','product') 
            AND product_id IN (SELECT pp.id FROM product_product pp 
                            JOIN product_template pt ON pt.id = pp.product_tmpl_id 
                            JOIN product_supplier_taxes_rel ptr ON ptr.prod_id = pt.id 
                            JOIN poinvline_temp tmp ON tmp.product_id = pp.id);

        UPDATE account_move_line SET tax_tag_invert = True
        WHERE id in (SELECT invline_id FROM poinvline_temp) 
            AND display_type = 'tax';

        -- insert data tax into account move line
        INSERT INTO account_move_line_account_tax_rel (account_move_line_id, account_tax_id)
        SELECT tmp.invline_id, ptr.tax_id
        FROM product_product pp 
            JOIN product_template pt ON pt.id = pp.product_tmpl_id 
            JOIN product_supplier_taxes_rel ptr ON ptr.prod_id = pt.id 
            JOIN poinvline_temp tmp ON tmp.product_id = pp.id;
    END;
$$;

DROP FUNCTION IF EXISTS sync_po_and_invoice();
CREATE OR REPLACE FUNCTION public.sync_po_and_invoice()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        INSERT INTO account_move_purchase_order_rel (purchase_order_id, account_move_id)
        SELECT po_id, inv_id FROM poinv_temp;

        UPDATE purchase_order SET invoice_count = 1 WHERE id = (SELECT po_id FROM poinv_temp);
    END;
$$;