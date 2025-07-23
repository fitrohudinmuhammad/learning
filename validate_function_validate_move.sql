DROP FUNCTION IF EXISTS process_set_move_ready();
CREATE OR REPLACE FUNCTION public.process_set_move_ready()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        sp record;
    BEGIN

        FOR sp in SELECT id FROM stock_picking WHERE origin = 'testing' AND state = 'confirmed'
        LOOP
            raise notice 'Picking %', sp.id;

            SELECT sum(product_uom_qty) FROM stock_move 
            WHERE product_id in (SELECT id FROM product_product WHERE default_code = dev_tran.product_code)  
                AND location_dest_id in (SELECT location_src_id FROM deliver_transactions WHERE picking_id = dev_tran.picking_id)
                AND state = 'done' INTO move_in;

            UPDATE stock_picking spi
            SET state = 'assigned', write_uid = 1, write_date = now()
            FROM (
                SELECT picking_id FROM stock_move sm WHERE spi.product_id = sm.product_id AND state = 'done' GROUP BY picking_id
            )
            WHERE id = sp.id;

            UPDATE stock_move
            SET state = 'assigned', write_uid = 1, write_date = now()
            WHERE picking_id = sp.id;

            UPDATE stock_move_line
            SET state = 'assigned', write_uid = 1, write_date = now()
            WHERE picking_id = sp.id;
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

            UPDATE stock_picking SET state='done' WHERE id = sp.id;
            UPDATE stock_move SET state='done' WHERE picking_id = sp.id;
            UPDATE stock_move_line SET state='done' WHERE picking_id = sp.id;

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
            WHERE origin='testing' AND picking_id = sp.id AND state='done'
            GROUP BY sm.product_id, sm.location_dest_id;

            SELECT id FROM stock_move where picking_id = sp.id INTO moves_id;
            SELECT move_dest_id FROM stock_move_move_rel WHERE move_orig_id = moves_id INTO moves_dest_id;
            
            SELECT picking_id FROM stock_move WHERE id = moves_dest_id INTO pickings_id;

            UPDATE stock_picking SET state='assigned' WHERE id = pickings_id;
            UPDATE stock_move SET state='assigned' WHERE picking_id = pickings_id;
            UPDATE stock_move_line SET state='assigned' WHERE picking_id = pickings_id;
        END LOOP;

    END;
$$;
