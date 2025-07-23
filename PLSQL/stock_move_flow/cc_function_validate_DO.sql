DROP FUNCTION IF EXISTS generate_validate_delivery_order(integer);
CREATE OR REPLACE FUNCTION public.generate_validate_delivery_order(sale_id integer)
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        SELECT process_set_move_ready(sale_id);
        SELECT process_set_move_done(sale_id);
    END;
$$;

DROP FUNCTION IF EXISTS process_set_move_ready(integer);
CREATE OR REPLACE FUNCTION public.process_set_move_ready(so_id integer)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        picking record;
        on_hand record;
        products record;
    BEGIN
        FOR picking in SELECT id, location_id FROM stock_picking WHERE state = 'confirmed' AND sale_id = so_id
        LOOP
            RAISE NOTICE 'Picking %', picking;
            FOR products IN SELECT product_id FROM stock_move WHERE picking_id = picking.id
            LOOP
                RAISE NOTICE 'Move %', products;
                SELECT product_id, sum(quantity) as qty 
                FROM stock_quant 
                WHERE product_id = products.product_id AND location_id = picking.location_id 
                GROUP BY product_id INTO on_hand;
                RAISE NOTICE 'QTY %', on_hand;
                
                IF on_hand.qty > 0 THEN 
                    RAISE NOTICE 'Products %', on_hand.product_id;
                    INSERT INTO stock_move_line (
                        id, picking_id, move_id, company_id, product_id, product_uom_id,
                        reserved_qty, reserved_uom_qty, qty_done, date, location_id,
                        location_dest_id, state, reference, product_category_name,
                        create_uid, create_date, write_uid, write_date
                    ) SELECT 
                        nextval('stock_move_line_id_seq'), picking.id, sm.id, sm.company_id, on_hand.product_id, sm.product_uom,
                        CASE WHEN sm.product_uom_qty > on_hand.qty IS TRUE THEN on_hand.qty ELSE sm.product_uom_qty END, 
                        CASE WHEN sm.product_uom_qty > on_hand.qty IS TRUE THEN on_hand.qty ELSE sm.product_uom_qty END, 
                        0, sm.date, sm.location_id, sm.location_dest_id,
                        'assigned', reference, pc.complete_name, 1, now(), 1, now()
                    FROM stock_move sm 
                    JOIN product_product pp ON pp.id = sm.product_id 
                    JOIN product_template pt ON pt.id = pp.product_tmpl_id
                    JOIN product_category pc ON pc.id = pt.categ_id 
                    WHERE picking_id = picking.id AND product_id = products.product_id;
                    
                    UPDATE stock_picking SET state = 'assigned', write_uid = 1, write_date = now() WHERE id = picking.id;
                    UPDATE stock_move SET state = 'assigned', write_uid = 1, write_date = now() WHERE picking_id = picking.id AND product_id = products.product_id;
                END IF;
            END LOOP;
        END LOOP;
    END;
$$;

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
        
        backorder_option boolean := 'False';
        new_picking_id int;
        new_picking_name varchar;
        new_move_id int;
        new_qty float := 0.0;
        old_qty float := 0.0;
    BEGIN
        SELECT id, location_id, location_dest_id FROM stock_picking WHERE state = 'assigned' AND sale_id = so_id into sp;
        RAISE notice 'Picking %', sp;
        
        RAISE notice 'Set Done Move and Move Line';
        UPDATE stock_picking SET state='done', write_uid = 1, write_date = now() WHERE id = sp.id;
        UPDATE stock_move SET state='done', write_uid = 1, write_date = now() WHERE picking_id = sp.id;
        UPDATE stock_move_line SET state='done', write_uid = 1, write_date = now(), qty_done = reserved_qty WHERE picking_id = sp.id;
        
        FOR prod in SELECT product_id, location_id, SUM(product_uom_qty) as qty FROM stock_move WHERE picking_id = sp.id GROUP BY product_id, location_id
        LOOP
            RAISE NOTICE '%', prod;
            SELECT CASE WHEN sm.product_uom_qty::int > sq.quantity::int IS TRUE THEN 'True' ELSE 'False' END
            FROM stock_move sm
            JOIN stock_quant sq ON sq.product_id = sm.product_id AND sq.location_id = sm.location_id
            WHERE picking_id = sp.id AND sm.product_id = prod.product_id AND sm.location_id = prod.location_id INTO backorder_option;
            
            EXIT WHEN backorder_option = True;
        END LOOP;
        
        RAISE NOTICE 'BACKORDER? %', backorder_option;
        
        IF backorder_option THEN
            SELECT nextval('stock_picking_id_seq') INTO new_picking_id;

            SELECT CONCAT(ir.prefix, LPAD(nextval(CONCAT('ir_sequence_', lpad(sequence_id::varchar, 3, '0')))::text, 5, '0')) 
            FROM stock_picking spo
                JOIN stock_picking_type spt ON spt.id = spo.picking_type_id
                JOIN ir_sequence ir ON ir.id = spt.sequence_id
            WHERE spo.id = sp.id
            INTO new_picking_name;
            
            RAISE NOTICE 'NEW PICKING %', new_picking_id;
            RAISE NOTICE 'NEW PICK NAME %', new_picking_name;
            
            RAISE NOTICE 'Create new picking backorder';
            INSERT INTO stock_picking (
                id, name, origin, note, move_type, 
                scheduled_date, date, date_done, location_id, 
                location_dest_id, picking_type_id, company_id, user_id, state,
                create_uid, create_date, write_uid, write_date, backorder_id, sale_id,
                partner_id
            )
            SELECT 
                new_picking_id, new_picking_name, origin, note, move_type, 
                scheduled_date, date, date_done, location_id, 
                location_dest_id, picking_type_id, company_id, user_id, 'confirmed', 
                1, now(), 1, now(), sp.id, so_id, partner_id
            FROM stock_picking 
            WHERE id = sp.id;
        END IF;
        
        FOR prod in SELECT id, product_id, location_id, location_dest_id, SUM(product_uom_qty) as qty FROM stock_move WHERE picking_id = sp.id GROUP BY product_id, location_id, location_dest_id, id
        LOOP
            RAISE NOTICE '-- START --';
            RAISE NOTICE 'Move % with product %', prod.id, prod.product_id;
            
            SELECT 
            CASE 
                WHEN SUM(sm.product_uom_qty)::int > SUM(sq.quantity)::int IS TRUE THEN 'True'
                ELSE 'False' 
            END AS backorder
            FROM stock_move sm
            JOIN stock_quant sq ON sm.product_id = sq.product_id AND sq.location_id = sm.location_id
            WHERE sm.picking_id = sp.id 
                AND sq.location_id = prod.location_id 
                AND sq.product_id = prod.product_id 
                AND sq.location_id = sp.location_id
            INTO backorder_option;
            RAISE NOTICE 'BACKORDER MOVE %',backorder_option;
            
            IF backorder_option THEN
                SELECT reserved_qty FROM stock_move_line WHERE move_id = prod.id INTO new_qty;
                old_qty := prod.qty;
                UPDATE stock_move SET product_uom_qty = new_qty WHERE id = prod.id;
                RAISE NOTICE 'QTY quant % >< move %', new_qty, old_qty;
                SELECT nextval('stock_move_id_seq') INTO new_move_id;
            END IF; 
            
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
                    CASE WHEN backorder_option IS TRUE THEN new_qty ELSE prod.qty END, 
                    CASE WHEN backorder_option IS TRUE THEN new_qty ELSE prod.qty END,
                    now(), 1, NOW(), 1, NOW());
            ELSE 
                RAISE NOTICE 'CREATED';
                IF backorder_option THEN
                    UPDATE stock_quant sq 
                    SET 
                        quantity = sq.quantity + new_qty,
                        reserved_quantity = sq.quantity + new_qty,
                        write_uid = 1, 
                        write_date = now()
                    WHERE 
                        id = loc_des;
                ELSE
                    UPDATE stock_quant sq 
                    SET 
                        quantity = sq.quantity + prod.qty,
                        reserved_quantity = sq.quantity + prod.qty,
                        write_uid = 1, 
                        write_date = now()
                    WHERE 
                        id = loc_des;
                END IF;
            END IF;

            RAISE NOTICE 'DEST %', loc_des;
            RAISE NOTICE 'SOURCE QUANT';
            -- PROSES 2
            -- UPDATE QUANT BY SOURCE LOCATION
            SELECT id FROM stock_quant WHERE product_id = prod.product_id AND location_id = prod.location_id INTO loc_sor;
            IF loc_sor IS NOT NULL THEN
                RAISE NOTICE 'UPDATE SOURCE LOC';
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
            RAISE NOTICE 'OLD MOVE % >< NEW MOVE % >< BACKORDER MOVE %', prod.id, next_move_id, new_move_id;
            IF next_move_id IS NOT NULl THEN 
                SELECT picking_id FROM stock_move WHERE id = next_move_id INTO next_picking_id;
                
                IF backorder_option THEN
                    UPDATE stock_picking SET state='assigned', write_uid = 1, write_date = now() WHERE id = next_picking_id;
                    UPDATE stock_move SET state='partially_available', write_uid = 1, write_date = now() WHERE picking_id = next_picking_id;
                ELSE
                    UPDATE stock_picking SET state='assigned', write_uid = 1, write_date = now() WHERE id = next_picking_id;
                    UPDATE stock_move SET state='assigned', write_uid = 1, write_date = now() WHERE picking_id = next_picking_id;
                END IF;

                INSERT INTO stock_move_line (
                    id, picking_id, move_id, company_id, product_id, product_uom_id,
                    reserved_qty, reserved_uom_qty, qty_done, date, location_id,
                    location_dest_id, state, reference, product_category_name,
                    create_uid, create_date, write_uid, write_date
                ) SELECT 
                    nextval('stock_move_line_id_seq'), sm.picking_id, sm.id, sm.company_id, sm.product_id, sm.product_uom,
                    CASE WHEN backorder_option IS TRUE THEN new_qty ELSE sm.product_uom_qty END, 
                    CASE WHEN backorder_option IS TRUE THEN new_qty ELSE sm.product_uom_qty END, 
                    0, sm.date, sm.location_id, sm.location_dest_id,
                    CASE WHEN backorder_option IS TRUE THEN 'partially_available' ELSE 'assigned' END, 
                    reference, pc.complete_name, 1, now(), 1, now()
                FROM stock_move sm 
                JOIN product_product pp ON pp.id = sm.product_id 
                JOIN product_template pt ON pt.id = pp.product_tmpl_id
                JOIN product_category pc ON pc.id = pt.categ_id 
                WHERE sm.id = next_move_id;
                
                
            ELSE
                UPDATE sale_order_line SET qty_delivered = prod.qty WHERE order_id = so_id AND product_id = prod.product_id;
            END IF;
            
            IF backorder_option THEN
                RAISE NOTICE 'BACKORDER PROCESS';
                
                RAISE NOTICE 'Create new move backorder';
                INSERT INTO stock_move(
                    id, picking_id, name, sequence, priority, date, company_id,
                    product_id, product_qty, product_uom_qty, product_uom, 
                    location_id, location_dest_id, state, price_unit, origin, procure_method, 
                    scrapped, picking_type_id, reference, warehouse_id, rule_id,
                    create_uid, create_date, write_uid, write_date, sale_line_id, partner_id
                )
                SELECT
                    new_move_id, new_picking_id, pt.name->>'en_US', sm.sequence, sm.priority, date, sm.company_id,
                    sm.product_id, old_qty - new_qty as product_qty, old_qty - new_qty as product_uom_qty,
                    sm.product_uom, sm.location_id, sm.location_dest_id, 'confirmed', sm.price_unit, sm.origin, sm.procure_method, 
                    sm.scrapped, sm.picking_type_id, new_picking_name, sm.warehouse_id, sm.rule_id, 
                    1, now(), 1, now(), sm.sale_line_id, sm.partner_id
                FROM stock_move sm
                JOIN product_product pp ON pp.id = sm.product_id
                JOIN product_template pt ON pt.id = pp.product_tmpl_id
                WHERE sm.id = prod.id;
                
                IF next_move_id IS NOT NULL THEN
                    INSERT INTO stock_move_move_rel(move_orig_id, move_dest_id) VALUES (new_move_id, next_move_id);
                END IF;
            END IF;
            RAISE NOTICE '-- END --';
        END LOOP;
    END;
$$;