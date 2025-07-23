DROP TABLE IF EXISTS deliver_transactions;
CREATE TABLE deliver_transactions(
	id bigserial,
	accounting_date timestamp,
	quantity float,
	unit_price float,
	partner_id int,
    warehouse_id int,
    rule_id int,
	
    picking_id int,
    picking_name varchar,
    move_id int,
    move_line_id int,
    location_src_id int,
    location_dest_id int,
    picking_type_id int,
    product_code varchar,
    uom_id int,
    procure_method varchar,
    product_quant_in float,
    product_move_in float,
    product_move_out float
);

DROP FUNCTION IF EXISTS generate_materialized_view_deliver();
CREATE OR REPLACE FUNCTION public.generate_materialized_view_deliver()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        TRUNCATE deliver_transactions;
		
		INSERT INTO deliver_transactions (
            accounting_date,
            quantity,
            unit_price,
            partner_id,
            warehouse_id,
            rule_id,
            
            picking_id,
            picking_name,
            move_id,
            move_line_id,
            location_src_id,
            location_dest_id,
            picking_type_id,
            product_code,
            uom_id,
            procure_method)
		SELECT 
			now(),
			2,
			10,
			12,
            sw.id,
            sr.id,
			
			nextval('stock_picking_id_seq') as picking_id, 
            CONCAT('ir_sequence_', lpad(sequence_id::varchar, 3, '0')) as name,
			nextval('stock_move_id_seq') as move_id, 
			nextval('stock_move_line_id_seq') as move_line_id,
			sr.location_src_id, 
			sr.location_id,
            sr.picking_type_id,
			'0000001',
			1,
            sr.procure_method
		FROM stock_warehouse sw 
			JOIN stock_location_route slr ON slr.id  = sw.delivery_route_id 
			JOIN stock_rule sr ON sr.route_id = slr.id
            JOIN stock_picking_type spt ON spt.id = sr.picking_type_id 
			WHERE sw.company_id = 1 
                AND slr.active is true 
                AND sr.active is true;

        PERFORM deliver_main_process();

	END;
$$;

DROP FUNCTION IF EXISTS deliver_main_process();
CREATE OR REPLACE FUNCTION public.deliver_main_process()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        RAISE notice 'Create product on hand: IN PROGRESS..';
        PERFORM mapping_product_on_hand();
        RAISE notice 'Create product on hand: FINISH';

        RAISE notice 'Create stock picking: IN PROGRESS..';
        PERFORM mapping_stock_picking();
        RAISE notice 'Create stock picking: FINISH';

        -- mapping stock move
        RAISE notice 'Create stock move: IN PROGRESS..';
        PERFORM mapping_stock_move();
        RAISE notice 'Create stock move: FINISH';

        -- mapping stock move line
        RAISE notice 'Create stock move line: IN PROGRESS..';
        PERFORM mapping_stock_move_line();
        RAISE notice 'Create stock move line: FINISH';

        RAISE notice 'Create linked move: IN PROGRESS..';
        PERFORM generate_linked_move_table();
        RAISE notice 'Create linked move: FINISH';

    END;
$$;

DROP FUNCTION IF EXISTS mapping_product_on_hand();
CREATE OR REPLACE FUNCTION public.mapping_product_on_hand()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        quant_in float;
        move_out float;
        move_in float;
        dev_tran record;
    begin
        FOR dev_tran in select product_code, picking_id from deliver_transactions
        LOOP
            RAISE NOTICE 'PRODUCT : %', dev_tran.product_code;

            SELECT sum(product_uom_qty) FROM stock_move 
            WHERE product_id in (SELECT id FROM product_product WHERE default_code = dev_tran.product_code)  
                AND location_dest_id in (SELECT location_src_id FROM deliver_transactions WHERE picking_id = dev_tran.picking_id)
                AND state = 'done' INTO move_in;
            
            RAISE NOTICE 'Move IN : %', move_in;

            SELECT sum(product_uom_qty) FROM stock_move 
            WHERE product_id in (SELECT id FROM product_product WHERE default_code = dev_tran.product_code)  
                AND location_dest_id not in (SELECT location_src_id FROM deliver_transactions WHERE picking_id = dev_tran.picking_id)
                AND state = 'done' INTO move_out;

            RAISE NOTICE 'Move OUT : %', move_out;

            SELECT sum(quantity) FROM stock_quant
            WHERE product_id in (SELECT id FROM product_product WHERE default_code = dev_tran.product_code)  
                AND location_id in (SELECT location_src_id FROM deliver_transactions WHERE picking_id = dev_tran.picking_id)
            INTO quant_in;

            RAISE NOTICE 'Quant IN : %', quant_in;

            UPDATE deliver_transactions 
            SET product_quant_in = quant_in, 
                product_move_out = move_out,
                product_move_in = move_in
            WHERE picking_id = dev_tran.picking_id;
        END LOOP;
    END;
$$;

DROP FUNCTION IF EXISTS mapping_stock_picking();
CREATE OR REPLACE FUNCTION public.mapping_stock_picking()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        INSERT INTO stock_picking(
            id, 
            name, 
            origin, 
            note, 
            move_type, 
            scheduled_date,
            date, 
            date_done, 
            location_id, 
            location_dest_id, 
            picking_type_id,
            company_id, 
            user_id, 
            state,

            create_uid, 
            create_date, 
            write_uid, 
            write_date
        )
        SELECT
            picking_id,
            CONCAT(ir.prefix, LPAD(nextval(dt.picking_name)::text, 5, '0')) as name,
            'testing',
            '',
            dt.procure_method,
            accounting_date::timestamp,
            accounting_date::timestamp,
            accounting_date::timestamp,
            dt.location_src_id, 
            dt.location_dest_id, 
            dt.picking_type_id, 
            1, 
            1, 
            CASE
                WHEN procure_method = 'make_to_stock' AND product_quant_in IS NOT NULL AND dt.quantity < product_quant_in THEN 'assigned'
                WHEN procure_method = 'make_to_stock' AND product_quant_in IS NOT NULL AND dt.quantity > product_quant_in THEN 'confirmed'
                WHEN procure_method = 'make_to_stock' AND product_quant_in IS NULL THEN 'confirmed'
                ELSE 'waiting' END as state,

            1, 
            now(), 
            1, 
            now()
        FROM deliver_transactions dt
        JOIN stock_picking_type spt ON spt.id = dt.picking_type_id
        JOIN ir_sequence ir ON ir.id = spt.sequence_id
        ON CONFLICT(id)
        DO NOTHING;

    END;
$$;

DROP FUNCTION IF EXISTS mapping_stock_move();
CREATE OR REPLACE FUNCTION public.mapping_stock_move()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        INSERT INTO stock_move(
            id, 
            picking_id, 
            name, 
            sequence, 
            priority, 
            date, 
            company_id,
            product_id, 
            product_qty, 
            product_uom_qty, 
            product_uom,
            location_id, 
            location_dest_id,
            state,
            price_unit, 
            origin, 
            procure_method, 
            scrapped, 
            picking_type_id,
            reference,
            warehouse_id,
            rule_id,

            create_uid, 
            create_date, 
            write_uid, 
            write_date
        )
        SELECT
            move_id,
            picking_id,
            CASE WHEN pt.default_code IS NULL THEN pt.name
                ELSE CONCAT('[',pt.default_code,'] ',pt.name) end as name,
            1, 
            1, 
            accounting_date::timestamp, 
            1,
            pp.id, 
            abs(dt.quantity), 
            abs(dt.quantity), 
            dt.uom_id,
            dt.location_src_id, 
            dt.location_dest_id, 
            CASE
                WHEN procure_method = 'make_to_stock' AND product_quant_in IS NOT NULL AND dt.quantity < product_quant_in THEN 'assigned'
                WHEN procure_method = 'make_to_stock' AND product_quant_in IS NOT NULL AND dt.quantity > product_quant_in THEN 'confirmed'
                WHEN procure_method = 'make_to_stock' AND product_quant_in IS NULL THEN 'confirmed'
                ELSE 'waiting' END as state,
            pt.list_price, 
            sp.origin, 
            dt.procure_method, 
            False, 
            dt.picking_type_id,
            sp.name,
            dt.warehouse_id,
            dt.rule_id,

            1, 
            now(), 
            1, 
            now()
        FROM deliver_transactions dt
        JOIN stock_picking sp ON sp.id = dt.picking_id
        JOIN product_product pp ON pp.default_code = dt.product_code
        JOIN product_template pt ON pt.id = pp.product_tmpl_id;

    END;
$$;

DROP FUNCTION IF EXISTS mapping_stock_move_line();
CREATE OR REPLACE FUNCTION public.mapping_stock_move_line()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN

        INSERT INTO stock_move_line(
            id, 
            picking_id, 
            move_id, 
            company_id, 
            product_id, 
            product_uom_id,
            product_qty, 
            product_uom_qty, 
            qty_done, 
            date, 
            location_id,
            location_dest_id, 
            state, 
            reference,

            create_uid, 
            create_date, 
            write_uid, 
            write_date
        )
        SELECT
            move_line_id, 
            picking_id, 
            move_id, 
            1, 
            pp.id, 
            dt.uom_id,
            0, 
            abs(dt.quantity), 
            0,
            accounting_date::timestamp,
            dt.location_src_id, 
            dt.location_dest_id, 
            CASE
                WHEN procure_method = 'make_to_stock' AND product_quant_in IS NOT NULL THEN 'assigned'
                WHEN procure_method = 'make_to_stock' AND product_quant_in IS NULL THEN 'confirmed'
                ELSE 'waiting' END as state,

            sp.origin,

            1, 
            now(), 
            1, 
            now()

        FROM deliver_transactions dt
        JOIN stock_picking sp ON sp.id = dt.picking_id
        JOIN product_product pp ON pp.default_code = dt.product_code
        WHERE product_quant_in IS NOT NULL;

    END;
$$;

DROP FUNCTION IF EXISTS generate_linked_move_table();
CREATE OR REPLACE FUNCTION public.generate_linked_move_table()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        counter int := 1;
        len_data record;
        moves_orig_id int;
        moves_dest_id int;
    BEGIN
        SELECT array_agg(id) as ids, count(*) as ln FROM deliver_transactions INTO len_data;
        raise notice 'check len data %', len_data;
        IF len_data.ln > 1 THEN
            WHILE counter < len_data.ln LOOP
                SELECT move_id FROM deliver_transactions dt WHERE id = len_data.ids[counter] INTO moves_orig_id;
                SELECT move_id FROM deliver_transactions dt WHERE id = len_data.ids[counter+1] INTO moves_dest_id;
            
                INSERT INTO stock_move_move_rel (move_orig_id, move_dest_id) VALUES (moves_orig_id, moves_dest_id);
                counter := counter + 1;
            END LOOP;
        END IF;
    END;
$$;