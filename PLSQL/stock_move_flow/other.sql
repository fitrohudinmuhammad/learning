
DROP FUNCTION IF EXISTS process_set_move_done(integer);
CREATE OR REPLACE FUNCTION public.process_set_move_done(so_id integer)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sp record;
        moves_id int;
        next_move_id int;
        moves record;
        next_picking_id int;
        prod record;
        loc_des int;
        loc_sor int;
    BEGIN

        FOR sp in SELECT id, location_id, location_dest_id FROM stock_picking WHERE state = 'assigned' AND sale_id = so_id
        LOOP 
            RAISE notice 'Picking %', sp.id;
            RAISE notice 'Set Done Move and Move Line';

            UPDATE stock_picking SET state='done', write_uid = 1, write_date = now() WHERE id = sp.id;
            UPDATE stock_move SET state='done', write_uid = 1, write_date = now() WHERE picking_id = sp.id;
            UPDATE stock_move_line SET state='done', write_uid = 1, write_date = now(), qty_done = reserved_qty WHERE picking_id = sp.id;

            FOR prod in SELECT id, product_id, location_id, location_dest_id, SUM(product_uom_qty) as qty FROM stock_move WHERE picking_id = sp.id GROUP BY product_id, location_id, location_dest_id, id
            LOOP
                RAISE NOTICE '----';
                RAISE NOTICE 'Move %', prod.id;
                RAISE NOTICE 'DEST QUANT';
                -- PROSES 1
                -- UPDATE QUANT BY DEST LOCATION
                SELECT id FROM stock_quant WHERE product_id = prod.product_id AND location_id = prod.location_dest_id INTO loc_des;
                IF loc_des IS NULL THEN
                    RAISE NOTICE 'NOT YET CREATED';
                    INSERT INTO stock_quant(
                        product_id, company_id, location_id, 
                        quantity, reserved_quantity, in_date,
                        create_uid, create_date, write_uid, write_date)
                    VALUES (
                        prod.product_id, 1, prod.location_dest_id,
                        prod.qty, prod.qty, now(),
                        1, NOW(), 1, NOW());
                ELSE 
                    RAISE NOTICE 'CREATED';
                    UPDATE stock_quant sq 
                    SET 
                        quantity = sq.quantity + prod.qty,
                        reserved_quantity = sq.quantity + prod.qty,
                        write_uid = 1, 
                        write_date = now()
                    WHERE 
                        id = loc_des;
                END IF;
                
                RAISE NOTICE 'DEST %', loc_des;
                RAISE NOTICE 'SOURCE QUANT';
                -- PROSES 2
                -- UPDATE QUANT BY SOURCE LOCATION
                SELECT id FROM stock_quant WHERE product_id = prod.product_id AND location_id = prod.location_id INTO loc_sor;
                IF loc_sor IS NOT NULL THEN
                    UPDATE stock_quant sq 
                    SET 
                        quantity = sq.quantity - prod.qty,
                        reserved_quantity = sq.quantity - prod.qty,
                        write_uid = 1, 
                        write_date = now()
                    WHERE 
                        sq.product_id = prod.product_id AND
                        sq.location_id = prod.location_id;
                END IF;
                
                RAISE NOTICE 'SOURCE %', loc_sor;
                RAISE NOTICE 'CREATE NEW MOVE LINE';
                UPDATE stock_move SET quantity_done = product_uom_qty WHERE id = prod.id;
                UPDATE stock_move_line SET reserved_qty = 0, reserved_uom_qty = 0 WHERE move_id = prod.id;

                SELECT move_dest_id FROM stock_move_move_rel WHERE move_orig_id = prod.id INTO next_move_id;
                IF next_move_id IS NOT NULl THEN 
                    SELECT picking_id FROM stock_move WHERE id = next_move_id INTO next_picking_id;

                    UPDATE stock_picking SET state='assigned', write_uid = 1, write_date = now() WHERE id = next_picking_id;
                    UPDATE stock_move SET state='assigned', write_uid = 1, write_date = now() WHERE picking_id = next_picking_id;

                    INSERT INTO stock_move_line (
                        id, picking_id, move_id, company_id, product_id, product_uom_id,
                        reserved_qty, reserved_uom_qty, qty_done, date, location_id,
                        location_dest_id, state, reference, product_category_name,
                        create_uid, create_date, write_uid, write_date
                    ) SELECT 
                        nextval('stock_move_line_id_seq'), picking_id, sm.id, sm.company_id, sm.product_id, sm.product_uom,
                        sm.product_uom_qty, sm.product_uom_qty, 0, sm.date, sm.location_id, sm.location_dest_id,
                        'assigned', reference, pc.complete_name, 1, now(), 1, now()
                    FROM stock_move sm 
                    JOIN product_product pp ON pp.id = sm.product_id 
                    JOIN product_template pt ON pt.id = pp.product_tmpl_id
                    JOIN product_category pc ON pc.id = pt.categ_id 
                    WHERE sm.id = next_move_id;
                ELSE
                    UPDATE sale_order_line SET qty_delivered = prod.qty WHERE order_id = so_id AND product_id = prod.product_id;
                END IF;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
        RAISE exception 'Encountered an issue when updating stock move, stock move line, or stock quant';
    END;
$$;

--note
select generate_confirm_sales(57)
select process_set_move_done(57);
select process_set_move_ready(57);

select id, state from stock_picking where id in (146,147,148)
update stock_picking set state = 'confirmed' where id = 146
update stock_move set state = 'confirmed' where id = 307
select id, product_id, location_id, location_dest_id, product_qty, product_uom_qty, quantity_done from stock_move where picking_id in (146,147,148) order by picking_id
select id, product_id, location_id, location_dest_id, reserved_qty, reserved_uom_qty, qty_done from stock_move_line where picking_id in (146,147,148) order by picking_id
select product_id, location_id, quantity from stock_quant where product_id in (62,63) order by product_id, location_id
select * from sale_order_line limit 1
delete from stock_move_line where picking_id in (146,147,148)