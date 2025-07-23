SELECT setval('ir_sequence_002', 26);
ALTER SEQUENCE sale_order_id_seq RESTART WITH 27;


DROP FUNCTION IF EXISTS func_generate_so() CASCADE;
CREATE OR REPLACE FUNCTION public.func_generate_so()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
    DECLARE
        so_id int;
        so_name varchar;
    BEGIN
        RAISE NOTICE 'START FUNCTION';

        TRUNCATE master_sale_order_tmp;
        
        SELECT nextval('sale_order_id_seq') INTO so_id;
        SELECT CONCAT('S', LPAD(nextval(CONCAT('ir_sequence_002'))::text, 5, '0')) INTO so_name;

        INSERT INTO master_sale_order_tmp (sale_id, so_name, sale_line_id, order_date, partner_id, product_id, 
            product_name, warehouse_id, qty, price, uom_id, pricelist_id, middleware_id)
        SELECT so_id, so_name, nextval('sale_order_line_id_seq'), tmp.order_date::date::timestamp, tmp.partner_id, pp.id,
            pt.name->>'en_US', 1, tmp.qty, pt.list_price, pt.uom_id, 1, tmp.id
        FROM sale_order_tmp_new tmp
        JOIN product_template pt on pt.default_code = tmp.product_code
        JOIN product_product pp on pt.id = pp.product_tmpl_id;

        PERFORM generate_so();
        PERFORM generate_soline();
		
		UPDATE master_sale_order_tmp SET stage = 2;
		
        RAISE NOTICE 'END FUNCTION';
		RETURN NEW;
    END;
$$;

DROP TRIGGER IF EXISTS trigger_generate_so ON sale_order_tmp CASCADE;
CREATE TRIGGER trigger_generate_so
AFTER INSERT ON sale_order_tmp
FOR EACH ROW
EXECUTE FUNCTION func_generate_so();


DROP FUNCTION IF EXISTS generate_so();
CREATE OR REPLACE FUNCTION public.generate_so()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        INSERT INTO sale_order (id, name, partner_id, date_order, company_id, 
            partner_invoice_id, partner_shipping_id, pricelist_id, warehouse_id, 
            picking_policy, state, create_uid, create_date, write_uid, write_date, 
			user_id, reference, note) 
        SELECT sale_id, so_name, partner_id, order_date, 1,
            partner_id, partner_id, pricelist_id, warehouse_id,
            'direct', 'draft', 1, now(), 1, now(), 1, 'DACO', 'Data from DACO'
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
            company_id, product_uom, price_unit, discount, name, customer_lead, state, middleware_id, middleware_unique_id)
        SELECT sale_line_id, sale_id, product_id, qty, 1, uom_id,
            price, 0.0, product_name, 0, 'draft', id, 1000 + id
        FROM master_sale_order_tmp_new;
    END;
$$;
