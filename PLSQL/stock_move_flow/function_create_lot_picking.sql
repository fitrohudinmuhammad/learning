-- CREATE INDEX IF NOT EXISTS sale_order_id_idx ON sale_order(id);

DROP TABLE IF EXISTS so_temp;
CREATE TABLE so_temp(
	id bigserial,
	accounting_date timestamp,
	partner_id int,
    user_id int, 
    warehouse_id int,
    rule_id int,
    so_id int,
    so_name varchar,
	
    picking_id int,
    picking_name varchar,
    location_src_id int,
    location_dest_id int,
    picking_type_id int,
    procure_method varchar
);

DROP TABLE IF EXISTS soline_temp;
CREATE TABLE soline_temp(
	id bigserial,
    temp_id int,
	accounting_date timestamp,
	partner_id int,
    user_id int, 
    warehouse_id int,
    rule_id int,
    so_id int,
    so_name varchar,
	
    picking_id int,
    picking_name varchar,
    move_id int,
    move_line_id int,
    location_src_id int,
    location_dest_id int,
    picking_type_id int,
    
    product_id int,
    quantity float,
    uom_id int,
    procure_method varchar,
    product_quant_in float,
    product_move_in float,
    product_move_out float,
    product_on_hand float
);

DROP FUNCTION IF EXISTS generate_confirm_sales_lot(integer);
CREATE OR REPLACE FUNCTION public.generate_confirm_sales_lot(sale_id integer)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sorder record;
        soline record;
    BEGIN
        TRUNCATE so_temp;
        TRUNCATE soline_temp;

        FOR sorder IN SELECT * FROM sale_order WHERE state = 'draft' AND id = sale_id
        LOOP
            INSERT INTO so_temp (
                accounting_date,
                partner_id,
                user_id,
                warehouse_id,
                rule_id,
                so_id,
                so_name,

                picking_id,
                picking_name,
                location_src_id,
                location_dest_id,
                picking_type_id,
                procure_method
            )
            SELECT 
                sorder.date_order,
                sorder.partner_id,
                sorder.user_id,
                sorder.warehouse_id,
                sr.id,
                sorder.id,
                sorder.name,

                nextval('stock_picking_id_seq') as picking_id, 
                CONCAT('ir_sequence_', lpad(sequence_id::varchar, 3, '0')) as name,
                sr.location_src_id, 
                sr.location_id,
                sr.picking_type_id,
                sr.procure_method
            FROM stock_warehouse sw 
            JOIN stock_location_route slr ON slr.id  = sw.delivery_route_id 
            JOIN stock_rule sr ON sr.route_id = slr.id
            JOIN stock_picking_type spt ON spt.id = sr.picking_type_id 
            WHERE sw.id = sorder.warehouse_id
                AND slr.active is true 
                AND sr.active is true;
        END LOOP;

        FOR soline IN SELECT * FROM so_temp
        LOOP
            INSERT INTO soline_temp (
                accounting_date,
                partner_id,
                user_id,
                warehouse_id,
                rule_id,
                so_id,
                so_name,

                picking_id,
                picking_name,
                move_id,
                move_line_id,
                location_src_id,
                location_dest_id,
                picking_type_id,
                procure_method,
                product_id,
                uom_id,
                quantity
            )
            SELECT
                soline.accounting_date,
                soline.partner_id,
                soline.user_id,
                soline.warehouse_id,
                soline.rule_id,
                soline.so_id,
                soline.so_name,

                soline.picking_id,
                soline.picking_name,
                nextval('stock_move_id_seq') as move_id, 
                nextval('stock_move_line_id_seq') as move_line_id,
                soline.location_src_id,
                soline.location_dest_id,
                soline.picking_type_id,
                soline.procure_method,
                sol.product_id,
                sol.product_uom,
                sol.product_uom_qty
            FROM sale_order_line sol
            WHERE sol.order_id = soline.so_id;
        END LOOP;

        RAISE NOTICE 'Get Information of Quantity in Stock';
        PERFORM mapping_product_on_hand_lot();
        RAISE NOTICE 'Create Picking';
        PERFORM mapping_stock_picking();
        RAISE NOTICE 'Create Move';
        PERFORM mapping_stock_move();
        RAISE NOTICE 'Create Move Line';
        PERFORM mapping_stock_move_line_lot();
        RAISE NOTICE 'Linked Move';
        PERFORM generate_linked_move_table();
        RAISE NOTICE 'Update State Picking';
        PERFORM update_picking_state();

        UPDATE sale_order SET state = 'sale' WHERE id = sale_id;
        UPDATE sale_order_line SET state = 'sale' WHERE order_id = sale_id;
    END;
$$;

DROP FUNCTION IF EXISTS mapping_product_on_hand_lot();
CREATE OR REPLACE FUNCTION public.mapping_product_on_hand_lot()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        quant_in float;
        move_out float;
        move_in float;
        qty_on_hand float;
        data_line record;
    begin
        FOR data_line IN SELECT * FROM soline_temp
        LOOP
            RAISE NOTICE 'PRODUCT : %', data_line.product_id;
            qty_on_hand := 0;
            SELECT sum(sml.qty_done) FROM stock_move_line sml, stock_production_lot spl 
            WHERE sml.lot_id = spl.id
                AND sml.product_id = data_line.product_id
                AND sml.location_dest_id in (SELECT location_src_id FROM soline_temp WHERE picking_id = data_line.picking_id)
                AND sml.state = 'done' 
            INTO move_in;
            
            RAISE NOTICE 'Move IN : %', move_in;

            SELECT sum(sml.qty_done) FROM stock_move_line sml, stock_production_lot spl  
            WHERE sml.lot_id = spl.id
                AND sml.product_id = data_line.product_id
                AND sml.location_dest_id not in (SELECT location_src_id FROM soline_temp WHERE picking_id = data_line.picking_id)
                AND state = 'done' 
            INTO move_out;

            RAISE NOTICE 'Move OUT : %', move_out;

            SELECT sum(sq.quantity) FROM stock_quant sq, product_product pp, stock_production_lot spl
            WHERE pp.id = sq.product_id
                AND spl.id = sq.lot_id
                AND sq.product_id = data_line.product_id
                AND sq.location_id in (SELECT location_src_id FROM soline_temp WHERE picking_id = data_line.picking_id)
            INTO quant_in;

            RAISE NOTICE 'Quant IN : %', quant_in;

            SELECT sum(sq.quantity) FROM stock_quant sq, stock_production_lot spl
            WHERE spl.id = sq.lot_id
                AND sq.product_id = data_line.product_id
                AND sq.location_id in (SELECT lot_stock_id FROM stock_warehouse WHERE id = data_line.warehouse_id)
            INTO qty_on_hand;

            IF qty_on_hand IS NULL THEN
                qty_on_hand := 0;
            END IF;

            RAISE NOTICE 'Quant On Hand : %', qty_on_hand;

            UPDATE soline_temp 
            SET product_quant_in = quant_in, 
                product_move_out = move_out,
                product_move_in = move_in,
                product_on_hand = qty_on_hand
            WHERE id = data_line.id;
        END LOOP;
    END;
$$;

DROP FUNCTION IF EXISTS generate_linked_move_table();
CREATE OR REPLACE FUNCTION public.generate_linked_move_table()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        counter int;
        temp_data record;
        moves_orig_id int;
        moves_dest_id int;
    BEGIN
        FOR temp_data IN SELECT array_agg(id) as ids, count(*) as ln FROM soline_temp GROUP BY product_id
		LOOP
			raise notice 'check len data %', temp_data;
			counter := 1;
			WHILE counter < temp_data.ln LOOP
				SELECT move_id FROM soline_temp dt WHERE id = temp_data.ids[counter] INTO moves_orig_id;
				SELECT move_id FROM soline_temp dt WHERE id = temp_data.ids[counter+1] INTO moves_dest_id;

				INSERT INTO stock_move_move_rel (move_orig_id, move_dest_id) VALUES (moves_orig_id, moves_dest_id);
				counter := counter + 1;
			END LOOP;
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
            sale_id,

            create_uid, 
            create_date, 
            write_uid, 
            write_date
        )
        SELECT
            picking_id,
            CONCAT(ir.prefix, LPAD(nextval(dt.picking_name)::text, 5, '0')) as name,
            dt.so_name,
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
                WHEN sequence_code = 'IN' THEN 'assigned'
                WHEN procure_method = 'make_to_stock' THEN 'assigned'
                ELSE 'waiting' 
            END as state,
            dt.so_id,

            1, 
            now(), 
            1, 
            now()
        FROM so_temp dt
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
                WHEN sequence_code = 'IN' THEN 'assigned'
                WHEN procure_method = 'make_to_stock' AND product_on_hand > 0 THEN 'assigned'
                WHEN procure_method = 'make_to_stock' AND product_on_hand = 0 THEN 'confirmed'
                ELSE 'waiting' 
            END as state,
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
        FROM soline_temp dt
        JOIN stock_picking_type spt ON spt.id = dt.picking_type_id
        JOIN stock_picking sp ON sp.id = dt.picking_id
        JOIN product_product pp ON pp.id = dt.product_id
        JOIN product_template pt ON pt.id = pp.product_tmpl_id
        ON CONFLICT(id)
        DO NOTHING;

    END;
$$;

DROP FUNCTION IF EXISTS mapping_stock_move_line_lot();
CREATE OR REPLACE FUNCTION public.mapping_stock_move_line_lot()
RETURNS void
LANGUAGE plpgsql
AS $$
	DECLARE
		data_prod record;
		datas record;
    BEGIN
		FOR data_prod IN SELECT product_id FROM soline_temp GROUP BY product_id
		LOOP
			SELECT so.id as temp_id, so.quantity as temp_qty, sq.* FROM soline_temp so 
			JOIN stock_quant sq ON sq.product_id = so.product_id AND sq.location_id = so.location_src_id 
			JOIN stock_production_lot spl ON spl.id = sq.lot_id 
			WHERE sq.quantity > 0 AND procure_method = 'make_to_stock' AND product_on_hand > 0 AND so.product_id = data_prod.product_id ORDER BY sq.quantity desc INTO datas;
			RAISE NOTICE '% : %', datas.temp_qty, datas.quantity;
			IF datas.quantity >= datas.temp_qty THEN
				RAISE NOTICE 'Harus 1 data';
				INSERT INTO stock_move_line(
					id, picking_id, move_id, company_id, product_id, product_uom_id, product_qty, 
					product_uom_qty, qty_done, date, location_id, location_dest_id, state, reference,
					lot_id, create_uid, create_date, write_uid, write_date
				)
				SELECT
					nextval('stock_move_line_id_seq'), picking_id, move_id, 1, dt.product_id, dt.uom_id, 0, 
					CASE 
						WHEN dt.quantity >= product_on_hand AND dt.quantity = sq.quantity THEN product_on_hand
						WHEN dt.quantity >= product_on_hand AND dt.quantity > sq.quantity THEN sq.quantity
						WHEN dt.quantity < product_on_hand AND dt.quantity < sq.quantity THEN dt.quantity 
						ELSE dt.quantity 
					END as product_uom_qty,
					0, dt.accounting_date::timestamp, dt.location_src_id, dt.location_dest_id, 
					CASE
						WHEN procure_method = 'make_to_stock' AND product_on_hand > 0 THEN 'assigned'
						WHEN procure_method = 'make_to_stock' AND product_on_hand = 0 THEN 'confirmed'
						ELSE 'waiting' 
					END as state,
					sp.name,	spl.id, 1, now(), 1, now()
				FROM soline_temp dt
				JOIN stock_picking_type spt ON spt.id = dt.picking_type_id
				JOIN stock_picking sp ON sp.id = dt.picking_id
				JOIN stock_quant sq ON sq.product_id = dt.product_id AND sq.location_id = dt.location_src_id
				JOIN stock_production_lot spl ON spl.id = sq.lot_id
				WHERE procure_method = 'make_to_stock' 
					AND product_on_hand > 0 
					AND sq.quantity > 0 
					AND sq.quantity >= dt.quantity 
					AND dt.product_id = data_prod.product_id
				ORDER BY spl.id
				ON CONFLICT(id)
				DO NOTHING;
			ELSE
				RAISE NOTICE 'Harus 2 Data';
				INSERT INTO stock_move_line(
					id, picking_id, move_id, company_id, product_id, product_uom_id, product_qty, 
					product_uom_qty, qty_done, date, location_id, location_dest_id, state, reference,
					lot_id, create_uid, create_date, write_uid, write_date
				)
				SELECT
					nextval('stock_move_line_id_seq'), picking_id, move_id, 1, dt.product_id, dt.uom_id, 0, 
					CASE 
						WHEN dt.quantity >= product_on_hand AND dt.quantity = sq.quantity THEN product_on_hand
						WHEN dt.quantity >= product_on_hand AND dt.quantity > sq.quantity THEN sq.quantity
						WHEN dt.quantity < product_on_hand AND dt.quantity < sq.quantity THEN dt.quantity 
						ELSE dt.quantity 
					END as product_uom_qty,
					0, dt.accounting_date::timestamp, dt.location_src_id, dt.location_dest_id, 
					CASE
						WHEN procure_method = 'make_to_stock' AND product_on_hand > 0 THEN 'assigned'
						WHEN procure_method = 'make_to_stock' AND product_on_hand = 0 THEN 'confirmed'
						ELSE 'waiting' 
					END as state,
					sp.name,	spl.id, 1, now(), 1, now()
				FROM soline_temp dt
				JOIN stock_picking_type spt ON spt.id = dt.picking_type_id
				JOIN stock_picking sp ON sp.id = dt.picking_id
				JOIN stock_quant sq ON sq.product_id = dt.product_id AND sq.location_id = dt.location_src_id
				JOIN stock_production_lot spl ON spl.id = sq.lot_id
				WHERE procure_method = 'make_to_stock' 
					AND product_on_hand > 0 
					AND sq.quantity > 0 
					AND dt.product_id = data_prod.product_id
				ORDER BY spl.id
				ON CONFLICT(id)
				DO NOTHING;
			END IF;
		END LOOP;
	END;
$$;

DROP FUNCTION IF EXISTS update_picking_state();
CREATE OR REPLACE FUNCTION public.update_picking_state()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        res int;
        tmp record;
    BEGIN
        FOR tmp IN SELECT * FROM so_temp WHERE procure_method = 'make_to_stock'
        LOOP 
            SELECT sp.id FROM so_temp sp JOIN stock_move_line sml ON sml.picking_id = sp.picking_id
            WHERE sp.picking_id = tmp.picking_id AND sp.procure_method = 'make_to_stock'
            INTO res;
            raise notice '%', res;

            IF res IS NULL THEN
                UPDATE stock_picking SET state = 'confirmed' WHERE id = tmp.picking_id;
            END IF;
        END LOOP;
    END;
$$;