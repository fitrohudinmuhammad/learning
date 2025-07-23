DROP TABLE IF EXISTS sale_order_tmp;
CREATE TABLE sale_order_tmp
(
    id serial,
    order_date varchar,
    partner_id int,
    product_code varchar,
    qty float,
    filename varchar,
    create_date timestamp default now(),
    stage int default 1
)partition by list (stage);

CREATE TABLE sale_order_tmp_new PARTITION OF sale_order_tmp FOR VALUES IN (1);
CREATE TABLE sale_order_tmp_process PARTITION OF sale_order_tmp FOR VALUES IN (2);
CREATE TABLE sale_order_tmp_done PARTITION OF sale_order_tmp FOR VALUES IN (3);

CREATE INDEX IF NOT EXISTS sale_order_tmp_order_date_idx ON sale_order_tmp(order_date);
CREATE INDEX IF NOT EXISTS sale_order_tmp_create_date_idx ON sale_order_tmp(create_date);
CREATE INDEX IF NOT EXISTS sale_order_tmp_filename_idx ON sale_order_tmp(filename);
CREATE INDEX IF NOT EXISTS sale_order_tmp_product_code_idx ON sale_order_tmp(product_code);

ALTER TABLE sale_order ADD IF NOT EXISTS COLUMN middleware_id int;
ALTER TABLE sale_order ADD IF NOT EXISTS COLUMN middleware_unique_id int;

ALTER TABLE sale_order_line ADD IF NOT EXISTS COLUMN middleware_id int;
ALTER TABLE sale_order_line ADD IF NOT EXISTS COLUMN middleware_unique_id int;

DROP TABLE IF EXISTS master_sale_order_tmp;
CREATE TABLE master_sale_order_tmp(
    id serial,
    sale_id int,
    so_name varchar,
    sale_line_id int,
    order_date timestamp,
    partner_id int,
    product_id int,
    product_name varchar,
	warehouse_id int,
    qty float,
    price float,
    uom_id int,
    pricelist_id int,
    create_date timestamp default now(),
    middleware_id int,
    stage int default 1
)partition by list(stage);

CREATE TABLE master_sale_order_tmp_new PARTITION OF master_sale_order_tmp FOR VALUES IN (1);
CREATE TABLE master_sale_order_tmp_process PARTITION OF master_sale_order_tmp FOR VALUES IN (2);
CREATE TABLE master_sale_order_tmp_done PARTITION OF master_sale_order_tmp FOR VALUES IN (3);

CREATE INDEX IF NOT EXISTS master_sale_order_tmp_order_date_idx ON master_sale_order_tmp(order_date);
CREATE INDEX IF NOT EXISTS master_sale_order_tmp_so_name_idx ON master_sale_order_tmp(so_name);
CREATE INDEX IF NOT EXISTS master_sale_order_tmp_product_id_idx ON master_sale_order_tmp(product_id);
CREATE INDEX IF NOT EXISTS master_sale_order_tmp_product_name_idx ON master_sale_order_tmp(product_name);
CREATE INDEX IF NOT EXISTS master_sale_order_tmp_create_date_idx ON master_sale_order_tmp(create_date);

DROP FUNCTION IF EXISTS generate_so_from_daco() CASCADE;
CREATE OR REPLACE FUNCTION public.generate_so_from_daco()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
    BEGIN
        RAISE NOTICE 'START FUNCTION';
        
        IF TG_OP = 'INSERT' THEN
            RAISE NOTICE 'INSERT';
            INSERT INTO master_sale_order_tmp (sale_id, so_name, sale_line_id, order_date, partner_id, product_id, 
                product_name, warehouse_id, qty, price, uom_id, pricelist_id, middleware_id)
            SELECT nextval('sale_order_id_seq'), CONCAT('S', LPAD(nextval(CONCAT('ir_sequence_002'))::text, 5, '0')) as so_name, 
                nextval('sale_order_line_id_seq'), tmp.order_date::date::timestamp, tmp.partner_id, pp.id,
                pt.name->>'en_US', 1, tmp.qty, pt.list_price, pt.uom_id, 1, tmp.id
            FROM sale_order_tmp_new tmp
            JOIN product_template pt on pt.default_code = tmp.product_code
            JOIN product_product pp on pt.id = pp.product_tmpl_id;
            
            PERFORM generate_so();
            PERFORM generate_soline();
            UPDATE master_sale_order_tmp SET stage = 2;
            RETURN NEW;
        ELSE
            RAISE NOTICE 'ELSE';
            UPDATE sale_order_tmp_new SET stage = 2;
        END IF;
        
        RAISE NOTICE 'END FUNCTION';
        RETURN NEW;
    END;
$$;

DROP TRIGGER IF EXISTS trigger_generate_so ON sale_order_tmp CASCADE;
CREATE TRIGGER trigger_generate_so
AFTER INSERT ON sale_order_tmp
FOR EACH ROW
EXECUTE FUNCTION generate_so_from_daco();

DROP FUNCTION IF EXISTS generate_so();
CREATE OR REPLACE FUNCTION public.generate_so()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        INSERT INTO sale_order (id, name, partner_id, date_order, company_id, 
            partner_invoice_id, partner_shipping_id, pricelist_id, warehouse_id, 
            picking_policy, state, create_uid, create_date, write_uid, write_date, 
            user_id, reference, note, amount_total) 
        SELECT sale_id, so_name, partner_id, order_date, 1,
            partner_id, partner_id, pricelist_id, warehouse_id,
            'direct', 'draft', 1, now(), 1, now(), 2, 'DACO', 'Data from DACO',
            sum(price*qty)
        FROM master_sale_order_tmp_new
        GROUP BY sale_id, so_name, partner_id, order_date,
            partner_id, partner_id, pricelist_id, warehouse_id
        ON CONFLICT(id)
        DO NOTHING;
    END;
$$;


DROP FUNCTION IF EXISTS generate_soline();
CREATE OR REPLACE FUNCTION public.generate_soline()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        INSERT INTO sale_order_line (id, order_id, product_id, product_uom_qty, 
            company_id, product_uom, price_unit, discount, name, customer_lead, state, 
            middleware_id, middleware_unique_id, price_subtotal)
        SELECT sale_line_id, sale_id, product_id, qty, 1, uom_id,
            price, 0.0, product_name, 0, 'draft', id, 1000 + id, qty*price
        FROM master_sale_order_tmp_new
        ON CONFLICT(id)
        DO NOTHING;
    END;
$$;
