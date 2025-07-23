DROP FUNCTION IF EXISTS set_asn_moves_as_done_training(varchar, varchar);
CREATE OR REPLACE FUNCTION set_asn_moves_as_done_training(_store_code character varying, date_now character varying)
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        locations record;
    BEGIN
        RAISE notice 'TRIGER STATUS: Running mark ASN moves as done';

        SELECT w.receipt_oc_picking_type_id as picking_type_id, default_location_src_id as location_id, default_location_dest_id as location_dest_id
        FROM stock_picking_type t JOIN stock_warehouse w ON t.id=w.receipt_oc_picking_type_id WHERE w.active=true AND w.store_code=_store_code LIMIT 1
        INTO locations;
        IF locations IS NULL THEN
            RAISE exception 'Can not find related warehouse %', _store_code;
        END IF;

        RAISE notice 'TRIGER STATUS: Running Done Stock Move';
        -- Update state of stock move
        UPDATE stock_move SET state='done' 
        WHERE origin='ASN_DATA' 
            AND location_dest_id=locations.location_dest_id 
            AND date::DATE = date date_now
            AND middleware_id in 
                (
                    SELECT 
                        asn_data.id 
                    FROM
                        dblink('dbname=kasumi_middleware port=5432 host=10.130.0.35 user=celery password=celeryadmin',
                        format('SELECT id FROM asn_aggregation WHERE store_code=%L AND stage = 2', _store_code)) 
                    AS asn_data (id bigint)
                );

        RAISE notice 'TRIGER STATUS: Running Done Stock Move Line';
        -- Update stock move line
        UPDATE stock_move_line SET state='done' 
        WHERE reference='ASN_DATA' 
            AND location_dest_id=locations.location_dest_id 
            AND date::DATE = date date_now
            AND middleware_id in 
                (
                    SELECT 
                        asn_data.id 
                    FROM
                        dblink('dbname=kasumi_middleware port=5432 host=10.130.0.35 user=celery password=celeryadmin',
                        format('SELECT id FROM asn_aggregation WHERE store_code=%L AND stage = 2', _store_code)) 
                    AS asn_data (id bigint)
                );

        RAISE notice 'TRIGER STATUS: Running Done Stock Quant';
        -- Update Quant for destination
        UPDATE stock_quant q SET quantity=quantity + asn_moves.product_uom_qty,
            reserved_quantity=reserved_quantity + asn_moves.product_uom_qty, write_date=NOW()
        FROM (SELECT product_id, location_dest_id, SUM(product_uom_qty) as product_uom_qty
            FROM stock_move
            WHERE origin='ASN_DATA' AND location_dest_id=locations.location_dest_id
                AND date::DATE=date date_now AND state='done'
            GROUP BY product_id, location_dest_id) AS asn_moves
        WHERE q.product_id=asn_moves.product_id AND q.location_id=asn_moves.location_dest_id;

        -- Create new quant for destination if necessary
        INSERT INTO stock_quant (product_id, company_id, location_id, quantity, reserved_quantity,
            create_uid, create_date, write_uid, write_date)
        SELECT sm.product_id, 1, locations.location_dest_id, SUM(sm.product_uom_qty), SUM(sm.product_uom_qty), 1, NOW(), 1, NOW()
        FROM stock_move sm LEFT JOIN stock_quant q ON sm.product_id=q.product_id AND sm.location_dest_id=q.location_id
        WHERE origin='ASN_DATA' AND sm.location_dest_id=locations.location_dest_id
            AND date::DATE=date date_now AND state='done' AND q.id IS NULL
        GROUP BY sm.product_id, sm.location_dest_id;

        -- Update quant for source location
        UPDATE stock_quant q SET quantity=quantity - asn_moves.product_uom_qty,
            reserved_quantity=reserved_quantity - asn_moves.product_uom_qty, write_date=NOW()
        FROM (SELECT product_id, location_id, SUM(product_uom_qty) as product_uom_qty
            FROM stock_move
            WHERE origin='ASN_DATA' AND location_id=locations.location_id
                AND date::DATE=date date_now AND state='done'
            GROUP BY product_id, location_id) AS asn_moves
        WHERE q.product_id=asn_moves.product_id AND q.location_id=asn_moves.location_id;

        -- Create new quant for source location if necessary
        INSERT INTO stock_quant (product_id, company_id, location_id, quantity, reserved_quantity,
            create_uid, create_date, write_uid, write_date)
        SELECT sm.product_id, 1, locations.location_id, -1 * SUM(sm.product_uom_qty), 0, 1, NOW(), 1, NOW()
        FROM stock_move sm LEFT JOIN stock_quant q ON sm.product_id=q.product_id AND sm.location_id=q.location_id
        WHERE origin='ASN_DATA' AND sm.location_id=locations.location_id
            AND date::DATE=date date_now AND state='done' AND q.id IS NULL
        GROUP BY sm.product_id, sm.location_id;

        RAISE notice 'TRIGER STATUS: Running Done master';

        TRUNCATE master_closing_asn_aggregation;

        INSERT INTO master_closing_asn_aggregation (middleware_id)
        SELECT middleware_id 
        FROM stock_move 
        WHERE origin='ASN_DATA' 
            AND location_dest_id=locations.location_dest_id 
            AND date::DATE = date date_now
            AND state = 'done';
        
        UPDATE master_closing_asn_aggregation SET store_code = _store_code;

    -- EXCEPTION
    --     WHEN OTHERS THEN
    --     RAISE exception 'Encountered an issue when updating stock move, stock move line, or stock quant';
    END;
$$;