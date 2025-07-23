DROP FUNCTION IF EXISTS process_set_move_ready();
CREATE OR REPLACE FUNCTION public.process_set_move_ready()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sp record;
        on_hand record;
        prod_id record;
    BEGIN

        FOR sp in SELECT id, location_id FROM stock_picking WHERE origin = 'testing' AND state = 'confirmed'
        LOOP
            raise notice 'Picking %', sp;

            SELECT product_id FROM stock_move WHERE picking_id = sp.id INTO prod_id;

            SELECT product_id, sum(quantity) as qty FROM stock_quant WHERE product_id = prod_id.product_id AND location_id = sp.location_id 
            GROUP BY product_id INTO on_hand;
			
			raise notice 'Product %', prod_id;
			raise notice 'On Hand %', on_hand;
			IF on_hand.qty > 0 THEN 
				INSERT INTO stock_move_line (
					id, picking_id, move_id, company_id, product_id, product_uom_id,
					product_qty, product_uom_qty, qty_done, date, location_id,
					location_dest_id, state, reference, 
					create_uid, create_date, write_uid, write_date
				) SELECT 
					nextval('stock_move_line_id_seq'), sp.id, sm.id, sm.company_id, on_hand.product_id, sm.product_uom,
					0, sm.product_uom_qty, 0, sm.date, sm.location_id, sm.location_dest_id,
					'assigned', reference, 1, now(), 1, now()
				FROM stock_move sm WHERE picking_id = sp.id;
				UPDATE stock_picking SET state = 'assigned', write_uid = 1, write_date = now() WHERE id = sp.id;
				UPDATE stock_move SET state = 'assigned', write_uid = 1, write_date = now() WHERE picking_id = sp.id;
			END IF;
		END LOOP;
	END;
$$;


DROP FUNCTION IF EXISTS process_set_move_done();
CREATE OR REPLACE FUNCTION public.process_set_move_done()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sp record;
        moves_id int;
        moves_dest_id int;
        moves record;
        pickings_id int;
    BEGIN

        FOR sp in SELECT id, location_id, location_dest_id FROM stock_picking WHERE origin = 'testing' AND state = 'assigned'
        LOOP 
            RAISE notice 'Picking %', sp.id;
            RAISE notice 'Set Done Move and Move Line';

            UPDATE stock_picking SET state='done', write_uid = 1, write_date = now() WHERE id = sp.id;
            UPDATE stock_move SET state='done', write_uid = 1, write_date = now() WHERE picking_id = sp.id;
            UPDATE stock_move_line SET state='done', write_uid = 1, write_date = now() WHERE picking_id = sp.id;

            UPDATE stock_quant sq 
            SET 
                quantity = sq.quantity - sml.product_uom_qty,
                write_uid = 1, 
                write_date = now()
            FROM 
                (SELECT product_id, location_id, SUM(product_uom_qty) as product_uom_qty
                FROM stock_move
                WHERE origin='testing' AND picking_id = sp.id AND state='done'
                GROUP BY product_id, location_id) 
                as sml
            WHERE 
                sq.product_id = sml.product_id AND
                sq.location_id = sml.location_id;

            -- process 2
            -- INSERT STOCK QUANT JIKA 
            INSERT INTO stock_quant(
                product_id, 
                company_id, 
                location_id, 
                quantity, 
                reserved_quantity,
                in_date,

                create_uid, 
                create_date, 
                write_uid, 
                write_date)
            SELECT 
                sm.product_id, 
                1,
                sm.location_dest_id, 
                SUM(sm.product_uom_qty), 
                SUM(sm.product_uom_qty), 
                now(),
                
                1, 
                NOW(), 
                1, 
                NOW()
            FROM stock_move sm 
            LEFT JOIN stock_quant q ON sm.product_id=q.product_id AND sm.location_dest_id=q.location_id
            WHERE q.id IS NULL AND origin='testing' AND picking_id = sp.id AND state='done'
            GROUP BY sm.product_id, sm.location_dest_id;

            UPDATE stock_move_line SET qty_done = product_uom_qty, product_uom_qty = 0 WHERE picking_id = sp.id;

            SELECT id FROM stock_move where picking_id = sp.id INTO moves_id;
            SELECT move_dest_id FROM stock_move_move_rel WHERE move_orig_id = moves_id INTO moves_dest_id;
            IF move_dest_id IS NOT NULl THEN 
                SELECT picking_id FROM stock_move WHERE id = moves_dest_id INTO pickings_id;
                
                UPDATE stock_picking SET state='assigned', write_uid = 1, write_date = now() WHERE id = pickings_id;
                UPDATE stock_move SET state='assigned', write_uid = 1, write_date = now() WHERE picking_id = pickings_id;

                INSERT INTO stock_move_line (
                    id, picking_id, move_id, company_id, product_id, product_uom_id,
                    product_qty, product_uom_qty, qty_done, date, location_id,
                    location_dest_id, state, reference, 
                    create_uid, create_date, write_uid, write_date
                ) SELECT 
                    nextval('stock_move_line_id_seq'), picking_id, sm.id, sm.company_id, product_id, sm.product_uom,
                    0, sm.product_uom_qty, 0, sm.date, sm.location_id, sm.location_dest_id,
                    'assigned', reference, 1, now(), 1, now()
                FROM stock_move sm WHERE id = moves_dest_id;
            END IF;
        END LOOP;
    END;
$$;
