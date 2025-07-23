DROP TABLE IF EXISTS table_tmp;
CREATE TABLE table_tmp(
    id serial,
    accounting_date varchar,
    partner_id int,
    product_code varchar,
    product_description varchar,
    qty float,
    location_id int,
    location_dest_id int,
    filename varchar,
    create_date timestamp default now(),
    stage int default 1
)partition by list (stage);

CREATE TABLE table_tmp_new PARTITION OF table_tmp FOR VALUES IN (1);
CREATE TABLE table_tmp_process PARTITION OF table_tmp FOR VALUES IN (2);
CREATE TABLE table_tmp_done PARTITION OF table_tmp FOR VALUES IN (3);

CREATE INDEX IF NOT EXISTS table_tmp_accounting_date_idx ON table_tmp(accounting_date);
CREATE INDEX IF NOT EXISTS table_tmp_create_date_idx ON table_tmp(create_date);
CREATE INDEX IF NOT EXISTS table_tmp_filename_idx ON table_tmp(filename);
CREATE INDEX IF NOT EXISTS table_tmp_product_code_idx ON table_tmp(product_code);

ALTER TABLE stock_move ADD COLUMN middleware_id int;
ALTER TABLE stock_move ADD COLUMN middleware_unique_id int;

ALTER TABLE stock_move_line ADD COLUMN middleware_id int;
ALTER TABLE stock_move_line ADD COLUMN middleware_unique_id int;

DROP TABLE IF EXISTS master_table_tmp;
CREATE TABLE master_table_tmp(
    id serial,
    picking_id int,
    move_id int,
    move_line_id int,
    move_date timestamp,
    partner_id int,
    product_id int,
    product_name varchar,
	warehouse_id int,
    qty float,
    uom_id int,
    picking_type_id int,
    location_id int,
    location_dest_id int,
    create_date timestamp default now(),
    middleware_id int
);

DROP FUNCTION IF EXISTS func_insert_do();
CREATE OR REPLACE FUNCTION public.func_insert_do()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        picking record;
    BEGIN
        RAISE NOTICE 'START FUNCTION';
		
		TRUNCATE master_table_tmp;
		
        SELECT sr.picking_type_id as type_id, nextval('stock_picking_id_seq') as id, sw.id as warehouse_id
        FROM stock_warehouse sw 
        JOIN stock_rule sr ON sr.route_id = sw.delivery_route_id 
        JOIN stock_picking_type spt ON spt.id = sr.picking_type_id 
        JOIN table_tmp_new tmp ON tmp.location_id = sr.location_src_id AND tmp.location_dest_id = sr.location_dest_id
        WHERE sr.active is true AND sw.company_id = 1 INTO picking;

        INSERT INTO master_table_tmp (move_id, move_line_id, move_date, partner_id, 
            product_id, product_name, qty, uom_id, picking_type_id, location_id, location_dest_id, middleware_id,
            picking_id, warehouse_id)
        SELECT nextval('stock_move_id_seq'), nextval('stock_move_line_id_seq'), tmp.accounting_date::date::timestamp, tmp.partner_id,
            pp.id, pt.name->>'en_US', tmp.qty, pt.uom_id, picking.type_id, tmp.location_id, tmp.location_dest_id, tmp.id,
            picking.id, picking.warehouse_id
        FROM table_tmp_new tmp
        JOIN product_template pt on pt.default_code = tmp.product_code
        JOIN product_product pp on pt.id = pp.product_tmpl_id;
		
		UPDATE table_tmp SET stage = 2;

		PERFORM generate_stock_picking();
        PERFORM generate_stock_move();
        PERFORM generate_stock_move_line();
        
        UPDATE table_tmp SET stage = 3;

        RAISE NOTICE 'END FUNCTION';
    END;
$$;	

-- Generate Stock Picking
DROP FUNCTION IF EXISTS generate_stock_picking();
CREATE OR REPLACE FUNCTION public.generate_stock_picking()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        INSERT INTO stock_picking(id, name, origin, note, scheduled_date, date, 
            date_done, location_id, location_dest_id, picking_type_id, company_id, 
            user_id, state, partner_id, create_uid, create_date, write_uid, write_date,
			move_type
        )
        SELECT picking_id, CONCAT(ir.prefix, LPAD(nextval(CONCAT('ir_sequence_', lpad(sequence_id::varchar, 3, '0')))::text, 5, '0')) as name,
            'DACO', 'Data from daco apps', move_date, move_date,
            move_date, tmp.location_id, tmp.location_dest_id, tmp.picking_type_id, 1, 1, 'assigned',
            tmp.partner_id, 1, now(), 1, now(), 'make_to_stock'
        FROM master_table_tmp tmp
        JOIN stock_picking_type spt ON spt.id = tmp.picking_type_id
        JOIN ir_sequence ir ON ir.id = spt.sequence_id
		GROUP BY picking_id, move_date, tmp.location_id, tmp.location_dest_id, ir.prefix, sequence_id, tmp.picking_type_id, tmp.partner_id
        ON CONFLICT(id)
        DO NOTHING;
    END;
$$;

-- Generate Stock Move
DROP FUNCTION IF EXISTS generate_stock_move();
CREATE OR REPLACE FUNCTION generate_stock_move()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        RAISE NOTICE 'Start Generating Stock Move';
        INSERT INTO stock_move(id, product_id, name, picking_type_id, location_id, location_dest_id, priority, state,
            product_uom, date, product_uom_qty, product_qty, middleware_unique_id, middleware_id,
            procure_method, company_id, create_uid, create_date, write_uid, write_date, origin, reference, picking_id)
        SELECT move_id, product_id, product_name, picking_type_id, location_id, location_dest_id, '1', 'assigned',
            uom_id, move_date, qty, qty, 1000 + middleware_id, middleware_id,
            'make_to_stock', 1, 1, now(), 1, now(), 'DACO', 'DACO', picking_id
        FROM master_table_tmp;
    END;
$$;

-- Generate Stock Move Line
DROP FUNCTION IF EXISTS generate_stock_move_line();
CREATE OR REPLACE FUNCTION generate_stock_move_line()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        RAISE NOTICE 'Start Generating Stock Move Line';
        INSERT INTO stock_move_line(id, product_id, move_id, location_id, location_dest_id, state,
            product_uom_id, date, reserved_uom_qty, reserved_qty, qty_done, middleware_unique_id, middleware_id,
            company_id, create_uid, create_date, write_uid, write_date, reference, picking_id)
        SELECT move_line_id, product_id, move_id, location_id, location_dest_id, 'assigned',
            uom_id, move_date, qty, qty, 0, 1000 + middleware_id, middleware_id,
            1, 1, now(), 1, now(), 'DACO', picking_id
        FROM master_table_tmp;
    END;
$$;

