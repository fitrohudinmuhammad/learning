DROP FUNCTION IF EXISTS process_check_availability(varchar);
CREATE OR REPLACE FUNCTION public.process_check_availability(val_origin varchar)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sp record;
        on_hand record;
        move_line_id int;
    BEGIN

        FOR sp in SELECT * FROM stock_move WHERE origin = val_origin AND state = 'confirmed'
        LOOP
            RAISE NOTICE 'Picking %', sp;

            SELECT product_id, sum(quantity) as qty 
            FROM stock_quant 
            WHERE product_id = sp.product_id AND location_id = sp.location_id 
            GROUP BY product_id INTO on_hand;
			
			RAISE NOTICE 'Product %', sp.product_id;
			RAISE NOTICE 'On Hand %', on_hand;
			IF on_hand.qty > 0 THEN 
                SELECT id FROM stock_move_line WHERE picking_id = sp.picking_id INTO move_line_id;
				raise notice '%', move_line_id;
                IF move_line_id IS NULL THEN
                    INSERT INTO stock_move_line (
                        id, picking_id, move_id, company_id, product_id, product_uom_id,
                        product_qty, product_uom_qty, qty_done, date, location_id,
                        location_dest_id, state, reference, 
                        create_uid, create_date, write_uid, write_date
                    ) SELECT 
                        nextval('stock_move_line_id_seq'), sp.picking_id, sm.id, sm.company_id, on_hand.product_id, sm.product_uom,
                        0, case when sm.product_uom_qty > on_hand.qty then sm.product_uom_qty - on_hand.qty
                        when sm.product_uom_qty < on_hand.qty then sm.product_uom_qty
                        else on_hand.qty end, 
                        0, sm.date, sm.location_id, sm.location_dest_id,
                        'assigned', reference, 1, now(), 1, now()
                    FROM stock_move sm WHERE sm.id = sp.id;
                ELSE
                    UPDATE stock_move_line SET state = 'assigned', write_uid = 1, write_date = now() WHERE picking_id = sp.picking_id;
                END IF;

				UPDATE stock_picking SET state = 'assigned', write_uid = 1, write_date = now() WHERE id = sp.picking_id;
				UPDATE stock_move SET state = 'assigned', write_uid = 1, write_date = now() WHERE id = sp.id;
			END IF;
            RAISE NOTICE '--------';
		END LOOP;
	END;
$$;


DROP FUNCTION IF EXISTS process_set_move_done(varchar);
CREATE OR REPLACE FUNCTION public.process_set_move_done(val_origin varchar)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sp record;
        moves_id int;
        moves_dest_id int;
        moves record;
        pickings_id int;
        backorder_option boolean;
        qty_old float;
        qty_new float;
    BEGIN

        FOR sp IN SELECT * FROM stock_move WHERE origin = val_origin AND state = 'assigned'
        LOOP 
            RAISE notice 'Picking %', sp.picking_id;
            RAISE notice 'Set Done Move and Move Line';
			backorder_option := 'False';

            SELECT case when SUM(sm.product_uom_qty)::int < SUM(sq.quantity)::int IS TRUE then 'False' else 'True' end as backorder 
			FROM stock_move sm
            JOIN stock_quant sq ON sm.product_id = sq.product_id
            WHERE sq.location_id = sm.location_id AND sm.id = sp.id INTO backorder_option;

            qty_old := 0;
            qty_new := 0;
			
			RAISE NOTICE 'Backorder Option %', backorder_option;
			
			SELECT product_uom_qty FROM stock_move WHERE id = sp.id INTO qty_old;

            IF backorder_option THEN
                -- if the data create backorder
                UPDATE stock_move sm SET product_uom_qty = sml.product_uom_qty FROM stock_move_line sml where sml.move_id = sp.id;
                SELECT product_uom_qty FROM stock_move WHERE id = sp.id INTO qty_new;
            END IF;
			
			RAISE NOTICE 'OLD : %, NEW : %', qty_old, qty_new;

            UPDATE stock_picking SET state='done', write_uid = 1, write_date = now() WHERE id = sp.picking_id;
            UPDATE stock_move SET state='done', write_uid = 1, write_date = now() WHERE id = sp.id;
            UPDATE stock_move_line SET state='done', write_uid = 1, write_date = now() WHERE move_id = sp.id;

            UPDATE stock_quant sq 
            SET 
                quantity = sq.quantity - sml.product_uom_qty,
                write_uid = 1, 
                write_date = now()
            FROM 
                (SELECT product_id, location_id, SUM(product_uom_qty) as product_uom_qty
                FROM stock_move sm
                WHERE origin=val_origin AND id = sp.id AND state='done'
                GROUP BY product_id, location_id) 
                as sml
            WHERE 
                sq.product_id = sml.product_id AND
                sq.location_id = sml.location_id;

            UPDATE stock_quant sq 
            SET 
                quantity = sq.quantity + sml.product_uom_qty,
                write_uid = 1, 
                write_date = now()
            FROM 
                (SELECT product_id, location_dest_id, SUM(product_uom_qty) as product_uom_qty
                FROM stock_move sm
                WHERE origin=val_origin AND id = sp.id AND state='done'
                GROUP BY product_id, location_dest_id) 
                as sml
            WHERE 
                sq.product_id = sml.product_id AND
                sq.location_id = sml.location_dest_id;

			-- INSERT STOCK QUANT JIKA TIDAK ADA 
            INSERT INTO stock_quant 
			(product_id, company_id, location_id, quantity, reserved_quantity, in_date, create_uid, create_date, write_uid, write_date)
            SELECT 
                sm.product_id, 1, sm.location_dest_id, SUM(sm.product_uom_qty), SUM(sm.product_uom_qty), now(), 1, NOW(), 1,NOW()
            FROM stock_move sm 
            LEFT JOIN stock_quant q ON sm.product_id=q.product_id AND sm.location_dest_id=q.location_id
            WHERE q.id IS NULL AND origin=val_origin AND sm.id = sp.id AND state='done'
            GROUP BY sm.product_id, sm.location_dest_id;

            UPDATE stock_move_line SET qty_done = product_uom_qty, product_uom_qty = 0 WHERE move_id = sp.id;

            -- SELECT id FROM stock_move where id = sp.id INTO moves_id;
            SELECT move_dest_id FROM stock_move_move_rel WHERE move_orig_id = sp.id INTO moves_dest_id;
			RAISE NOTICE 'Moves_id %', sp.id;
			RAISE NOTICE 'Moves_dest_id %', moves_dest_id;
			IF moves_dest_id IS NOT NULL THEN
				SELECT picking_id FROM stock_move WHERE id = moves_dest_id INTO pickings_id;
				RAISE NOTICE 'Picking Dest %', pickings_id;
				
				RAISE NOTICE 'Create new move line dest';
				INSERT INTO stock_move_line (
					id, picking_id, move_id, company_id, product_id, product_uom_id,
					product_qty, product_uom_qty, qty_done, date, location_id,
					location_dest_id, state, reference, 
					create_uid, create_date, write_uid, write_date) 
				SELECT 
					nextval('stock_move_line_id_seq'), picking_id, sm.id, sm.company_id, product_id, sm.product_uom,
					0, sm.product_uom_qty, 0, sm.date, sm.location_id, sm.location_dest_id,
					'assigned', reference, 1, now(), 1, now()
				FROM stock_move sm WHERE id = moves_dest_id;
			ELSE
				pickings_id := NULL;
			END IF;
            
            IF backorder_option THEN
				RAISE NOTICE 'Get Backorder';
				
                DROP TABLE IF EXISTS backorder_view;
                CREATE TABLE backorder_view (
                    picking_id bigint,
                    move_id bigint,
                    pick_id bigint,
					pick_name varchar
                );
                INSERT INTO backorder_view(picking_id, move_id, pick_id, pick_name)  
				SELECT
					nextval('stock_picking_id_seq'), 
					nextval('stock_move_id_seq'), 
					sp.picking_id, 
					CONCAT(ir.prefix, LPAD(nextval(CONCAT('ir_sequence_', lpad(sequence_id::varchar, 3, '0')))::text, 5, '0')) as name
				FROM stock_picking spo
                JOIN stock_picking_type spt ON spt.id = spo.picking_type_id
                JOIN ir_sequence ir ON ir.id = spt.sequence_id
				WHERE spo.id = sp.picking_id;
                
				RAISE NOTICE 'Create new picking backorder';
                INSERT INTO stock_picking (
                    id, name, origin, note, move_type, scheduled_date, date, date_done, location_id, 
                    location_dest_id, picking_type_id, company_id, user_id, state,
                    create_uid, create_date, write_uid, write_date, backorder_id, sale_id
                )
                SELECT 
                    bv.picking_id, bv.pick_name,
                    spo.origin, spo.note, spo.move_type, spo.scheduled_date, spo.date,
                    spo.date_done, spo.location_id, spo.location_dest_id, spo.picking_type_id,
                    spo.company_id, spo.user_id, 'confirmed', 1, now(), 1, now(), sp.picking_id, sale_id
                FROM stock_picking spo
                JOIN backorder_view bv ON bv.pick_id = spo.id
                WHERE spo.id = sp.picking_id;
				
				RAISE NOTICE 'Create new move backorder';
                INSERT INTO stock_move(
                    id, picking_id, name, sequence, priority, date, company_id,
                    product_id, product_qty, product_uom_qty, product_uom, location_id, 
                    location_dest_id, state, price_unit, origin, procure_method, 
                    scrapped, picking_type_id, reference, warehouse_id, rule_id,
                    create_uid, create_date, write_uid, write_date, sale_line_id
                )
                SELECT
                    bv.move_id, bv.picking_id,
                    CASE 
                        WHEN pt.default_code IS NULL THEN pt.name
                        ELSE CONCAT('[',pt.default_code,'] ',pt.name) 
                    END AS name,
                    smo.sequence, smo.priority, smo.date, smo.company_id,
                    smo.product_id, qty_old - qty_new as product_qty, qty_old - qty_new as product_uom_qty,
                    smo.product_uom, smo.location_id, smo.location_dest_id, 'confirmed',
                    smo.price_unit, smo.origin, smo.procure_method, smo.scrapped, smo.picking_type_id, bv.pick_name, 
                    smo.warehouse_id, smo.rule_id, 1, now(), 1, now(), sale_line_id
                FROM stock_move smo
                JOIN product_product pp ON pp.id = smo.product_id
                JOIN product_template pt ON pt.id = pp.product_tmpl_id
				JOIN backorder_view bv ON bv.pick_id = smo.picking_id
                WHERE smo.id = sp.id;
				
				raise notice 'Update data New Picking %', pickings_id;
				IF pickings_id IS NOT NULL THEN
					UPDATE stock_picking SET state='assigned', write_uid = 1, write_date = now() WHERE id = pickings_id;
					UPDATE stock_move SET state='partially_available', write_uid = 1, write_date = now() WHERE picking_id = pickings_id;
					UPDATE stock_move_line SET state='partially_available', write_uid = 1, write_date = now() WHERE picking_id = pickings_id;
				END IF;
				
                IF moves_dest_id IS NOT NULL THEN
                    INSERT INTO stock_move_move_rel (move_orig_id, move_dest_id) 
                    SELECT move_id, moves_dest_id
                    FROM backorder_view;
                END IF;
			ELSE
				RAISE NOTICE 'Not Get Backorder';
				IF pickings_id IS NOT NULl THEN 
					UPDATE stock_picking SET state='assigned', write_uid = 1, write_date = now() WHERE id = pickings_id;
					UPDATE stock_move SET state='assigned', write_uid = 1, write_date = now() WHERE picking_id = pickings_id;
					UPDATE stock_move_line SET state='assigned', write_uid = 1, write_date = now() WHERE picking_id = pickings_id;
				END IF;
            END IF;
			RAISE NOTICE '-----------s';
        END LOOP;
    END;
$$;

