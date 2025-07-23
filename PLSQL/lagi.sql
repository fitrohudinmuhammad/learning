DROP FUNCTION IF EXISTS build_materialized_view_for_master_data_account_master(varchar, varchar, varchar, varchar, varchar, varchar, varchar);
CREATE OR REPLACE FUNCTION public.build_materialized_view_for_master_data_account_master(db_name varchar, db_port varchar, db_host varchar, db_user varchar, db_password varchar, destination_store varchar, filename_with_suffix varchar)
RETURNS void
LANGUAGE plpgsql
AS $$
    BEGIN
        -- middleware
        DROP MATERIALIZED VIEW IF EXISTS middleware_table_master_data CASCADE;
        EXECUTE FORMAT ('CREATE MATERIALIZED VIEW middleware_table_master_data AS 
                            select
                                count(*) as count
                            from 
                                master_data_account_master
                            where 
                                file_name = %L', filename_with_suffix
                    );

        --master data store
        TRUNCATE odoo_master_data_table;

        INSERT INTO odoo_master_data_table
        SELECT
            rows.*
        FROM
            dblink('dbname='||db_name||' port='||db_port||' host='||db_host||' user='||db_user||' password='||db_password||'',
                    format('select
                                count(*) as count
                            from 
                                res_partner
                            where 
                                middleware_id is not null and
                                file_name = %L', filename_with_suffix
                        )
                    ) AS rows (
                        count float
                    );
    END;
$$;
