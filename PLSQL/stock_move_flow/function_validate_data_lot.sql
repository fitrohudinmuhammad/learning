DROP FUNCTION IF EXISTS process_check_available_lot();
CREATE OR REPLACE FUNCTION public.process_check_available_lot()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sp record;
        on_hand record;
        move_ids record;
    BEGIN

        FOR sp in SELECT id, location_id, location_dest_id FROM stock_picking WHERE origin = 'testing_lot' AND state = 'confirmed'
        LOOP
            raise notice 'stock_picking %', sp;			
			FOR move_ids IN SELECT id, product_id, lot_id FROM stock_move_line WHERE picking_id = sp.id GROUP BY id, product_id, lot_id
			LOOP
				SELECT id, product_id, lot_id, sum(qty_done) as qty FROM stock_move_line WHERE product_id = move_ids.product_id AND state = 'done' AND location_dest_id = sp.location_id
				GROUP BY id, product_id, lot_id LIMIT 1 INTO on_hand;
				raise notice '%', on_hand;
				
				IF on_hand IS NOT NULL THEN
					INSERT INTO stock_move_line (
						id, picking_id, move_id, company_id, product_id, product_uom_id,
						product_qty, product_uom_qty, qty_done, date, location_id,
						location_dest_id, state, reference, lot_id,
						create_uid, create_date, write_uid, write_date
					) SELECT 
						nextval('stock_move_line_id_seq'), sp.id, sm.id, sm.company_id, sm.product_id, sm.product_uom,
						0, sm.product_uom_qty, 0, sm.date, sm.location_id, sm.location_dest_id,
						'assigned', reference, on_hand.lot_id, 1, now(), 1, now()
					FROM stock_move sm WHERE picking_id = sp.id;
					
					UPDATE stock_picking SET state = 'assigned' WHERE id = sp.id;
					UPDATE stock_move SET state = 'assigned' WHERE picking_id = sp.id;
					UPDATE stock_move_line SET product_uom_qty = 0, state = 'assigned' WHERE id = move_ids.id;
				END IF;
			END LOOP;
		END LOOP;
	END;
$$;

DROP FUNCTION IF EXISTS process_set_move_done_lot(varchar);
CREATE OR REPLACE FUNCTION public.process_set_move_done_lot(val_origin varchar)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sp record;
        moves_dest_id int;
        moves record;
        pickings_id int;
    BEGIN
        FOR sp in SELECT sml.* FROM stock_move sm JOIN stock_move_line sml ON sml.move_id = sm.id WHERE origin =val_origin AND sm.state = 'assigned'
        LOOP 
            RAISE notice 'Picking %', sp;
            RAISE notice 'Set Done Move and Move Line';

            UPDATE stock_picking SET state='done', write_uid = 1, write_date = now() WHERE id = sp.picking_id;
            UPDATE stock_move SET state='done', write_uid = 1, write_date = now() WHERE id = sp.move_id;
            UPDATE stock_move_line SET state='done', write_uid = 1, write_date = now() WHERE id = sp.id;
			
            UPDATE stock_quant sq 
            SET 
                quantity = sq.quantity - sml.product_uom_qty,
                write_uid = 1, 
                write_date = now()
            FROM 
                (SELECT smove.product_id, smove.location_id, SUM(slmove.product_uom_qty) as product_uom_qty
                FROM stock_move smove
				JOIN stock_move_line slmove ON slmove.move_id = smove.id AND slmove.lot_id = sp.lot_id
                WHERE smove.origin=val_origin AND smove.id = sp.move_id AND smove.state='done'
                GROUP BY smove.product_id, smove.location_id) 
                as sml
            WHERE 
                sq.product_id = sml.product_id AND
                sq.location_id = sml.location_id AND
				sq.lot_id = sp.lot_id;
				
			UPDATE stock_quant sq 
            SET 
                quantity = sq.quantity + sml.product_uom_qty,
                write_uid = 1, 
                write_date = now()
            FROM 
                (SELECT smove.product_id, smove.location_dest_id, SUM(slmove.product_uom_qty) as product_uom_qty
                FROM stock_move smove
				JOIN stock_move_line slmove ON slmove.move_id = smove.id AND slmove.lot_id = sp.lot_id
                WHERE smove.origin=val_origin AND smove.id = sp.move_id AND smove.state='done'
                GROUP BY smove.product_id, smove.location_dest_id) 
                as sml
            WHERE 
                sq.product_id = sml.product_id AND
                sq.location_id = sml.location_dest_id AND
				sq.lot_id = sp.lot_id;

            -- process 2
            -- INSERT STOCK QUANT JIKA 
            INSERT INTO stock_quant
			(product_id, company_id, location_id, quantity, reserved_quantity, in_date, lot_id, create_uid, create_date, write_uid, write_date)
            SELECT 
                sm.product_id, 1, sm.location_dest_id, SUM(slmove.product_uom_qty), SUM(slmove.product_uom_qty), now(), sp.lot_id, 1, NOW(), 1, NOW()
            FROM stock_move sm 
			JOIN stock_move_line slmove ON slmove.move_id = sm.id
            LEFT JOIN stock_quant q ON sm.product_id=q.product_id AND sm.location_dest_id=q.location_id AND q.lot_id = slmove.lot_id
            WHERE q.id IS NULL AND sm.origin=val_origin AND sm.id = sp.move_id AND sm.state='done' AND slmove.lot_id = sp.lot_id
            GROUP BY sm.product_id, sm.location_dest_id;
			
            UPDATE stock_move_line SET qty_done = product_uom_qty, product_uom_qty = 0 WHERE id = sp.id;

            SELECT move_dest_id FROM stock_move_move_rel WHERE move_orig_id = sp.move_id INTO moves_dest_id;
			raise notice 'moves_dest_id %', moves_dest_id;
            IF moves_dest_id IS NOT NULl THEN 
                SELECT picking_id FROM stock_move WHERE id = moves_dest_id INTO pickings_id;
				raise notice 'pickings_id %', pickings_id;
                
                UPDATE stock_picking SET state='assigned', write_uid = 1, write_date = now() WHERE id = pickings_id;
                UPDATE stock_move SET state='assigned', write_uid = 1, write_date = now() WHERE picking_id = pickings_id;
				UPDATE stock_move_line SET state='assigned', write_uid = 1, write_date = now() WHERE picking_id = pickings_id;

                INSERT INTO stock_move_line (
                    id, picking_id, move_id, company_id, product_id, product_uom_id,
                    product_qty, product_uom_qty, qty_done, date, location_id,
                    location_dest_id, state, reference, 
                    create_uid, create_date, write_uid, write_date, lot_id
                ) SELECT 
                    nextval('stock_move_line_id_seq'), pickings_id, moves_dest_id, sm.company_id, sm.product_id, sm.product_uom,
                    0, sp.product_uom_qty, 0, sm.date, sm.location_id, sm.location_dest_id,
                    'assigned', sm.reference, 1, now(), 1, now(), sp.lot_id
                FROM stock_move sm
				JOIN stock_move_line sml on sml.move_id = sm.id
				WHERE sm.id = sp.move_id AND sml.lot_id = sp.lot_id;
            END IF;
			RAISE NOTICE '--------';
        END LOOP;
    END;
$$;
