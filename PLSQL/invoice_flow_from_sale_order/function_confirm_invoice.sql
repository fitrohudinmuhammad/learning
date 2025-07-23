DROP FUNCTION IF EXISTS generate_confirm_invoice(integer);
CREATE OR REPLACE FUNCTION public.generate_confirm_invoice(invid integer)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        invoice record;
        invoiceLine record;
        inv_name varchar;
        partner_name varchar;
        seq_number varchar;
        date_post boolean;
    BEGIN
        SELECT * FROM account_move WHERE id = invid INTO invoice;
        RAISE NOTICE '%', invoice;
        SELECT * FROM account_move_line WHERE move_id = invid ORDER BY id INTO invoiceLine;
        RAISE NOTICE '%',invoiceline;
        SELECT (sequence_number+1)::varchar FROM account_move 
        WHERE sequence_number is not null 
            AND date_part('year', date) = date_part('year', now()) 
            AND move_type = 'out_invoice'
        ORDER BY sequence_number desc limit 1 INTO seq_number;
        RAISE NOTICE '%',seq_number;
        SELECT concat('INV/',date_part('year', now()),'/',LPAD(seq_number,5,'0')) INTO inv_name;
        RAISE NOTICE '%',inv_name;
        SELECT display_name FROM res_partner WHERE id = invoice.partner_id INTO partner_name;
        RAISE NOTICE '%',partner_name;

        SELECT CASE WHEN now()::date > date THEN False
            ELSE True END AS post_date FROM account_move WHERE id = invoice.id INTO date_post;

        -- invoice_date = now()
        UPDATE account_move SET
            invoice_date = now(),
            sequence_prefix = concat('INV/',date_part('year', now()),'/'),
            name = inv_name,
            payment_reference = inv_name,
            state = 'posted',
            sequence_number = seq_number::int, 
            invoice_partner_display_name = partner_name,
            is_storno = True, 
            always_tax_exigible = False, 
            posted_before = date_post, 
            is_move_sent = False
        WHERE id = invoice.id;

        UPDATE account_move_line SET
            move_name = inv_name,
            parent_state = 'posted'
        WHERE move_id = invoice.id;

    END;
$$;