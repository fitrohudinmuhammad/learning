-- Step 1: Create notification on Odoo DB
DROP TABLE IF EXISTS ecommerce_sale_order_notification;
CREATE TABLE ecommerce_sale_order_notification(
    unique_key varchar,
    db_name varchar,
    db_port varchar,
    db_host varchar,
    db_user varchar,
    db_password varchar
);
INSERT INTO ecommerce_sale_order_notification (unique_key) VALUES ('ecommerce_sale_order_notification');

-- Step 1.1: Extra condition (make sure columns exist)
-- Middleware ID
ALTER TABLE sale_order 
    ADD COLUMN IF NOT EXISTS md_sale_header_id BIGINT NOT NULL,
    ADD COLUMN IF NOT EXISTS md_vtlog_id BIGINT NOT NULL,
    ADD COLUMN IF NOT EXISTS md_smart_pos_id BIGINT NOT NULL;

ALTER TABLE sale_order_line
    ADD COLUMN IF NOT EXISTS md_line_item_id SMALLINT NOT NULL;

-- Step 3: Create function for temporary table data
-- Sale Order Mapping
DROP FUNCTION IF EXISTS generate_materialized_view_ecommerce_sale_order();
CREATE OR REPLACE FUNCTION generate_materialized_view_ecommerce_sale_order()
RETURNS trigger
LANGUAGE plpgsql
AS $$
    DECLARE
		sales_header_unique_name text;
        sales_header_unique_id integer;
	BEGIN
        PERFORM dblink_connect('dbname='||NEW.db_name||' port='||NEW.db_port||' host='||NEW.db_host||' user='||NEW.db_user||' password='||NEW.db_password||'');

		SELECT
            rows.sales_header_unique_name,
            rows.sales_header_unique_id
        INTO sales_header_unique_name,
            sales_header_unique_id
        FROM 
            dblink('dbname='||NEW.db_name||' port='||NEW.db_port||' host='||NEW.db_host||' user='||NEW.db_user||' password='||NEW.db_password||'',
            'SELECT 
                id as id_var,
                id as id_int
            FROM
                sales_header WHERE stage = 1
            LIMIT 1')
        AS rows
            (
                sales_header_unique_name varchar,
                sales_header_unique_id integer
            );

		RAISE notice 'TRIGER STATUS: Running..';
        RAISE notice 'Detected by AFTER UPDATE ON ecommerce_sale_order_notification';
        RAISE notice 'CREATING UNIQUE temp table..';

        EXECUTE format(
            'CREATE TABLE %I(
                md_sale_header_id int8 NOT NULL,
                md_vtlog_id int8 NOT NULL,
                md_smart_pos_id int8 NOT NULL,
                md_line_item_id int8 NOT NULL,
                md_payment_id int8 NOT NULL,
                md_acs_credit_id int8 NOT NULL,
                store_code varchar NULL,
                terminal_no int4 NULL,
                transaction_type int4 NULL,
                company_code varchar NOT NULL,
                client_order_ref int8 NULL,
                "name" varchar NOT NULL,
                order_date timestamp NULL,
                amount_untaxed numeric NULL,
                amount_sale_total numeric NULL,
                amount_non_sales numeric NULL,
                amount_tax numeric NULL,
                discount_amount numeric NULL,
                total_qty int4 NULL,
                checker_name varchar NULL,
                amount_total decimal NULL,
                partner_name varchar NULL,
                sequence int4 NULL,
                entry_type varchar NULL,
                product_code varchar NULL,
                price_unit numeric NULL,
                unit_price_for_purchase numeric NULL,
                product_uom_qty int4 NULL,
                discount_total numeric NULL,
                discount_divided numeric NULL,
                tax_divided numeric NULL,
                description_special_sale varchar NULL,
                price_subtotal numeric NULL,
                price_type varchar NULL,
                uom varchar NULL,
                is_tax_exempted bool NULL,
                is_cancelled bool NULL,
                priority_type int2 NULL,
                ref_business_date timestamp NULL,
                line_no varchar,
                payment_code varchar,
                payment_sub_code varchar,
                payment_summary_group_code varchar,
                payment_summary_group_description varchar,
                face_amount varchar,
                deposit_amount varchar,
                amount varchar,
                ticket_count varchar,
                ticket_no_change_amount varchar,
                description varchar,
                ticket_change_amount varchar,
                is_revenue_stamp_target varchar,
                tax_divided_payment varchar,
                voided_tran_cash_deposit_amount varchar,
                is_point_prohibition boolean,
                is_restore_payment boolean,
                input_deposit_amount varchar,
                non_count_for_sales varchar,
                order_id varchar,
                shop_id varchar,
                sale_order_id int8 NOT NULL,
                sale_order_line_id int8 NOT NULL,
                sale_payment_info_id int8 NOT NULL,
                product_id bigint NULL,
                product_status varchar NULL
            )', 
            'ecommerce_sale_order_middleware_temp_' || sales_header_unique_name );

        EXECUTE format(
            'INSERT INTO %I
            SELECT 
                -- 7 select dari as rows from db link middleware
                rows.*,
                nextval(''sale_order_id_seq'') as sale_order_id,
                nextval(''sale_order_line_id_seq'') as sale_order_line_id,
                nextval(''sale_payment_info_id_seq'') as sale_payment_info_id,
                pp.id as product_id,
                CASE WHEN pp.barcode is NULL THEN ''Product Not Found''
                    ELSE NULL
                END AS product_status
            FROM
                dblink(''dbname='||NEW.db_name||' port='||NEW.db_port||' host='||NEW.db_host||' user='||NEW.db_user||' password='||NEW.db_password||''',
                    format(''SELECT 
                                sh.id::bigint,
                                vt.id::bigint,
                                spm.id::bigint,
                                li.id::bigint,
                                p.id::bigint,
                                ac.id::bigint,
                                vt.store_code,
                                vt.terminal_no::int,
                                vt.transaction_type::int,
                                vt.company_code,
                                vt.receipt_no::int,
                                sh.transaction_no::varchar,
                                sh.reference_data_time::timestamp,
                                sh.total_amount::float,
                                sh.total_amount_with_taxes::float,
                                sh.total_amount_for_non_count_for_sales::float,
                                sh.taxes_amount::float,
                                sh.discounts_amount::float,
                                sh.total_quantity::float,
                                sh.checker_name,
                                sh.auto_promotion_purchase_amount::float,
                                spm.member_id,
                                li.line_item_no::int,
                                li.entry_type,
                                li.item_code,
                                case when li.unit_price_overrided::float != 0
                                    then li.unit_price_overrided ::float
                                    when li.unit_price_overrided::float = 0 and li.unit_price_for_special_sale::float != 0
                                    then li.unit_price_for_special_sale::float 
                                    else li.unit_price_normal::float 
                                end as price_unit,
                                li.unit_price_for_purchase::decimal,
                                li.quantity::int,
                                li.discount_total::decimal,
                                li.discount_divided::decimal,
                                li.tax_divided::decimal,
                                li.description_for_special_sale,
                                li.amount::decimal,%L
                                li.price_type,
                                ''''Units'''',
                                li.is_tax_exempted::bool,
                                li.is_canceled::bool,
                                li.priorisudo systemctl status sshty_type::smallint,
                                sh.ref_business_date,
                                p.line_no,
                                p.payment_code,
                                p.payment_sub_code,
                                p.payment_summary_group_code,
                                p.payment_summary_group_description,
                                p.face_amount,
                                p.deposit_amount,
                                p.amount,
                                p.ticket_count,
                                p.ticket_no_change_amount,
                                p.description,
                                p.ticket_change_amount,
                                p.is_revenue_stamp_target,
                                p.tax_divided,
                                p.voided_tran_cash_deposit_amount,
                                p.is_point_prohibition,
                                p.is_restore_payment,
                                p.input_deposit_amount,
                                p.non_count_for_sales,
                                ac.order_id,
                                ac.shop_id
                            FROM sales_header sh
                            JOIN vtlog_transfer vt ON vt.transaction_no = sh.transaction_no
                            JOIN smart_pos_member spm ON spm.transaction_no::int = sh.transaction_no::int
                            JOIN line_item li ON li.transaction_no::int = sh.transaction_no::int
                            JOIN payment p ON p.transaction_no::int = sh.transaction_no::int         
                            JOIN acs_credit ac ON ac.transaction_no::int = sh.transaction_no::int
                            WHERE sh.stage = 1 AND spm.stage = 1 AND vt.stage = 1 AND li.stage = 1 AND p.stage = 1 AND ac.stage = 1 AND sh.id::varchar = %L'', sales_header_unique_name
                        )
                    ) AS rows (
                                md_sale_header_id bigint,
                                md_vtlog_id bigint,
                                md_smart_pos_id bigint,
                                md_line_item_id bigint,
                                md_payment_id bigint,
                                md_acs_credit_id bigint,
                                store_code varchar,
                                terminal_no int,
                                transaction_type int,
                                company_code varchar,
                                client_order_ref bigint,
                                name varchar ,
                                order_date timestamp ,
                                amount_untaxed decimal ,
                                amount_sale_total decimal ,
                                total_amount_for_non_count_for_sales decimal,
                                amount_tax decimal ,
                                discount_amount decimal ,
                                total_qty int,
                                checker_name varchar,
                                amount_total decimal,
                                partner_name varchar,
                                sequence int,
                                entry_type varchar,
                                product_code varchar,
                                price_unit decimal,
                                unit_price_for_purchase decimal,
                                product_uom_qty int,
                                discount_total decimal ,
                                discount_divided decimal ,
                                tax_divided decimal ,
                                description_special_sale varchar ,
                                price_subtotal decimal ,
                                price_type varchar ,
                                uom varchar,
                                is_tax_exempted boolean,
                                is_cancelled boolean,
                                priority_type smallint,
                                ref_business_date timestamp,
                                line_no varchar,
                                payment_code varchar,
                                payment_sub_code varchar,
                                payment_summary_group_code varchar,
                                payment_summary_group_description varchar,
                                face_amount varchar,
                                deposit_amount varchar,
                                amount varchar,
                                ticket_count varchar,
                                ticket_no_change_amount varchar,
                                description varchar,
                                ticket_change_amount varchar,
                                is_revenue_stamp_target varchar,
                                tax_divided_payment varchar,
                                voided_tran_cash_deposit_amount varchar,
                                is_point_prohibition boolean,
                                is_restore_payment boolean,
                                input_deposit_amount varchar,
                                non_count_for_sales varchar,
                                order_id varchar,
                                shop_id varchar
                            )
            LEFT JOIN product_product pp on pp.barcode = rows.product_code',
            'ecommerce_sale_order_middleware_temp_' || sales_header_unique_name;

        PERFORM dblink_disconnect();
				
        -- Call main mapping process
        PERFORM ecommerce_sale_order_main_process();

        RETURN NEW;

        RAISE notice 'generate_materialized_view_ecommerce_sale_order End at: %', now();
    END;
$$;

-- Step 4: Create main mapping process
DROP FUNCTION IF EXISTS ecommerce_sale_order_main_process();
CREATE OR REPLACE FUNCTION ecommerce_sale_order_main_process()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN

        -- WAREHOUSE GENERATOR
        RAISE notice 'Looking for warehouse id: IN PROGRESS.. ';
        PERFORM generate_ecommerce_stock_warehouse();
        RAISE notice 'Check / Generate warehouse id: OKE';

        -- RAISE notice 'ecommerce_sale_order_main_process Start at: %', now();
        RAISE notice 'Create sale order: IN PROGRESS..';
        PERFORM mapping_ecommerce_sale_order();
        RAISE notice 'Create sale order: OKE';

        RAISE notice 'Create sale order line: IN PROGRESS..';
        PERFORM mapping_ecommerce_sale_order_line();
        RAISE notice 'Create sale order line: OKE';

        RAISE notice 'Create sale payment info: IN PROGRESS..';
        PERFORM mapping_ecommerce_sale_payment_info();
        RAISE notice 'Create sale payment info: OKE';

    END;
$$;

-- Step 5: Create trigger for the notification table
DROP TRIGGER IF EXISTS trigger_ecommerce_sale_order_notification ON ecommerce_sale_order_notification CASCADE;
CREATE TRIGGER trigger_ecommerce_sale_order_notification
AFTER UPDATE 
ON ecommerce_sale_order_notification
FOR EACH ROW
EXECUTE FUNCTION generate_materialized_view_ecommerce_sale_order();

-- Step 6: Create sub-function for each mapping
-- Step 6.0: Generate Warehouse ID
DROP FUNCTION IF EXISTS generate_ecommerce_stock_warehouse();
CREATE OR REPLACE FUNCTION generate_ecommerce_stock_warehouse()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        -- RAISE notice 'generate_stock_warehouse Start at: %', now();

        INSERT INTO stock_warehouse(
            name, 
            active,
            company_id, 
            view_location_id, 
            lot_stock_id, 
            code, 
            reception_steps, 
            delivery_steps,
            store_code
        )
        SELECT 
            esomt.store_code,
            TRUE,
            rc.id,
            '7',
            '8',
            esomt.store_code,
            'one_step',
            'ship_only',
            esomt.store_code
        FROM 
            ecommerce_sale_order_middleware_temp esomt
        JOIN
            res_company rc ON esomt.company_code = rc.company_code
        LEFT JOIN 
            stock_warehouse sw ON sw.store_code = esomt.store_code
        WHERE
            sw.store_code is NULL
        ON CONFLICT(name, company_id) DO NOTHING
        ;
        -- RAISE notice 'generate_stock_warehouse End at: %', now();
    END;
$$;

-- Step 6.1: Sale Order
DROP FUNCTION IF EXISTS mapping_ecommerce_sale_order();
CREATE OR REPLACE FUNCTION mapping_ecommerce_sale_order()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        -- RAISE notice 'mapping_sale_order_ec Start at: %', now();
        -- Update sale_order id
        UPDATE 
            ecommerce_sale_order_middleware_temp ec_sale_order
        SET 
            sale_order_id = tmp.sale_order_id
        FROM (
                SELECT 
                    min(sale_order_id) as sale_order_id , 
                    name
                FROM 
                    ecommerce_sale_order_middleware_temp 
                GROUP BY name
            ) as tmp
        WHERE 
            ec_sale_order.name = tmp.name;

        WITH res AS (
            SELECT 
                    esomt.sale_order_id, 
                    esomt.md_sale_header_id,
                    esomt.md_vtlog_id,
                    esomt.md_smart_pos_id,
                    sw.id as warehouse_id,
                    esomt.partner_name ,
                    esomt.company_code ,
                    rc.id,
                    rc.guest_id AS partner_id_alt,
                    rp.id AS partner_id_res,            
                    esomt.terminal_no,
                    esomt.transaction_type,
                    esomt.client_order_ref,
                    esomt.name,
                    esomt.order_date,
                    esomt.amount_untaxed,
                    esomt.amount_sale_total,
                    esomt.amount_non_sales,
                    esomt.amount_tax,
                    esomt.discount_amount,
                    esomt.total_qty,
                    esomt.checker_name,
                    esomt.amount_total,
                    esomt.ref_business_date,
                    esomt.order_id,
                    esomt.shop_id
                FROM 
                    ecommerce_sale_order_middleware_temp esomt
                JOIN
                    res_company rc ON esomt.company_code = rc.company_code
                LEFT JOIN
                    res_partner rp ON rp."name" = esomt.partner_name
                LEFT JOIN 
                    stock_warehouse sw ON sw.store_code = esomt.store_code
                    )
            INSERT INTO sale_order (
                    id, 
                    md_sale_header_id,
                    md_vtlog_id,
                    md_smart_pos_id,
                    warehouse_id,
                    company_id ,
                    partner_id,
                    partner_invoice_id,
                    partner_shipping_id,
                    pricelist_id,
                    picking_policy,
                    state,
                    terminal_no,
                    transaction_type,
                    client_order_ref,
                    name,
                    date_order,
                    order_date,
                    amount_untaxed,
                    amount_sale_total,
                    amount_non_sales,
                    amount_tax,
                    discount_amount,
                    total_qty,
                    checker_name,
                    amount_total,
                    ref_business_date,
                    order_id,
                    shop_id,
                    create_uid,
                    write_uid)
            SELECT 
                res.sale_order_id, 
                res.md_sale_header_id,
                res.md_vtlog_id,
                res.md_smart_pos_id,
                res.warehouse_id,
                res.id AS company_id ,
                CASE WHEN res.partner_id_res IS NULL
                    THEN res.partner_id_alt
                    ELSE res.partner_id_res
                END AS partner_id,
                CASE WHEN res.partner_id_res IS NULL
                    THEN res.partner_id_alt
                    ELSE res.partner_id_res
                END AS partner_invoice_id,
                CASE WHEN res.partner_id_res IS NULL
                    THEN res.partner_id_alt
                    ELSE res.partner_id_res
                END AS partner_shipping_id,
                1,
                'direct',
                'sale',
                res.terminal_no,
                res.transaction_type,
                res.client_order_ref,
                res.name,
                res.order_date as date_order,
                res.order_date,
                res.amount_untaxed,
                res.amount_sale_total,
                res.amount_non_sales,
                res.amount_tax,
                res.discount_amount,
                res.total_qty,
                res.checker_name,
                res.amount_total,
                res.ref_business_date,
                res.order_id,
                res.shop_id,
                1,
                1
            FROM res
            ON CONFLICT(id) DO NOTHING
                ;

        -- RAISE notice 'mapping_sale_order_ec End at: %', now();
    END;
$$;

-- Step 6.2: Sale Order Line
DROP FUNCTION IF EXISTS mapping_ecommerce_sale_order_line();
CREATE OR REPLACE FUNCTION mapping_ecommerce_sale_order_line()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        -- RAISE notice 'mapping_sale_order_ec_line Start at: %', now();

        INSERT INTO sale_order_line(
            md_line_item_id,
            id,
            order_id,
            name,
            sequence,
            product_id,
            state,
            product_uom_qty,
            entry_type,
            discount_total,
            discount_divided,
            tax_divided,
            description_special_sale,
            price_subtotal,
            price_type,
            price_unit,
            unit_price_for_purchase,
            customer_lead,
            product_uom,
            is_tax_exempted,
            is_cancelled,
            priority_type,
            create_uid,
            write_uid
        )
        SELECT 
            distinct on (esomt.md_line_item_id) md_line_item_id,
            esomt.sale_order_line_id,
            esomt.sale_order_id,
            CASE WHEN esomt.product_status IS NOT NULL THEN esomt.product_code::varchar || ' ' || esomt.name::varchar
                ELSE esomt.name::varchar
            END AS name,
            esomt.sequence,
            CASE WHEN esomt.product_id IS NULL THEN rc.product_id 
                ELSE esomt.product_id
            END AS product_id,
            'sale',
            esomt.product_uom_qty,
            esomt.entry_type,
            esomt.discount_total,
            esomt.discount_divided,
            esomt.tax_divided,
            esomt.description_special_sale,
            esomt.price_subtotal,
            esomt.price_type,
            esomt.price_unit,
            esomt.unit_price_for_purchase,
            0,
            uu.id as product_uom,
            esomt.is_tax_exempted,
            esomt.is_cancelled,
            esomt.priority_type,
            1,
            1
        FROM 
            ecommerce_sale_order_middleware_temp esomt
        JOIN uom_uom uu ON uu.name = esomt.uom
        JOIN res_company rc ON esomt.company_code = rc.company_code
        ;
        -- RAISE notice 'mapping_sale_order_ec_line End at: %', now();
    END;
$$;

-- Step 6.3: Sale Payment Info
DROP FUNCTION IF EXISTS mapping_ecommerce_sale_payment_info();
CREATE OR REPLACE FUNCTION mapping_ecommerce_sale_payment_info()
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        -- RAISE notice 'mapping_sale_payment_ec Start at: %', now();

        INSERT INTO sale_payment_info(
            md_payment_id,
            id,
            order_id,
            line_no,
            payment_code,
            payment_sub_code,
            payment_summary_group_code,
            payment_summary_group_description,
            face_amount,
            deposit_amount,
            amount,
            ticket_count,
            ticket_no_change_amount,
            description,
            ticket_change_amount,
            is_revenue_stamp_target,
            tax_divided,
            voided_tran_cash_deposit_amount,
            is_point_prohibition,
            is_restore_payment,
            input_deposit_amount,
            non_count_for_sales
        )
        SELECT 
            esomt.md_payment_id,
            esomt.sale_payment_info_id,
            esomt.sale_order_id,
            esomt.line_no,
            esomt.payment_code,
            esomt.payment_sub_code,
            esomt.payment_summary_group_code,
            esomt.payment_summary_group_description,
            esomt.face_amount,
            esomt.deposit_amount,
            esomt.amount,
            esomt.ticket_count,
            esomt.ticket_no_change_amount,
            esomt.description,
            esomt.ticket_change_amount,
            esomt.is_revenue_stamp_target,
            esomt.tax_divided_payment,
            esomt.voided_tran_cash_deposit_amount,
            esomt.is_point_prohibition,
            esomt.is_restore_payment,
            esomt.input_deposit_amount,
            esomt.non_count_for_sales
        FROM 
            ecommerce_sale_order_middleware_temp esomt
        ;
        -- RAISE notice 'mapping_sale_order_ec_line End at: %', now();
    END;
$$;

