-- table xxx
DROP TABLE IF EXISTS xxx;
CREATE TABLE IF NOT EXISTS xxx(
    id int,
    name varchar,
    active boolean,
    can_be_sold varchar,
    active_products varchar,
    products_limit int,
    use_sp boolean,
    sp_name varchar,
    categories_domain varchar,
    categories_limit int
);

-- table daco_xxx_event
DROP TABLE IF EXISTS daco_xxx_event;
CREATE TABLE daco_xxx_event (
    id text default md5(random()::text || clock_timestamp()::text),
    seq serial,
    tstamp timestamp DEFAULT now(),
    schemaname text,
    tabname text,
    operation text,
    who text DEFAULT current_user,
    new_val json,
    old_val json,
    state text DEFAULT 'queue',
    hash_val text
)
PARTITION BY LIST(state);

CREATE TABLE daco_xxx_event_queue PARTITION OF daco_xxx_event FOR VALUES IN('queue');
CREATE TABLE daco_xxx_event_progress PARTITION OF daco_xxx_event FOR VALUES IN('progress');
CREATE TABLE daco_xxx_event_done PARTITION OF daco_xxx_event FOR VALUES IN('done');
CREATE TABLE daco_xxx_event_skip PARTITION OF daco_xxx_event FOR VALUES IN('skip');

-- table daco_xxx_sync
DROP TABLE IF EXISTS daco_xxx_sync;
CREATE TABLE daco_xxx_sync (
    id text default md5(random()::text || clock_timestamp()::text),
    seq serial,
    tstamp timestamp DEFAULT now(),
    operation text,
    data text,
    state text DEFAULT 'queue',
    source_id int
)
partition by list(state);

CREATE TABLE daco_xxx_sync_queue PARTITION OF daco_xxx_sync FOR VALUES IN('queue');
CREATE TABLE daco_xxx_sync_progress PARTITION OF daco_xxx_sync FOR VALUES IN('progress');
CREATE TABLE daco_xxx_sync_done PARTITION OF daco_xxx_sync FOR VALUES IN('done');
CREATE TABLE daco_xxx_sync_skip PARTITION OF daco_xxx_sync FOR VALUES IN('skip');
CREATE TABLE daco_xxx_sync_lock PARTITION OF daco_xxx_sync FOR VALUES IN('lock');

-- table xxx_api
DROP TABLE IF EXISTS xxx_api;
CREATE TABLE xxx_api(
    id int,
    name varchar,
    active boolean,
    can_be_sold varchar,
    active_products varchar,
    products_limit int,
    use_sp boolean,
    sp_name varchar,
    categories_domain varchar,
    categories_limit int,

    daco_create_date timestamp default now(),
    daco_write_date timestamp default now(),

    unique(id)
);

CREATE INDEX IF NOT EXISTS xxx_api_id_brin_idx on xxx_api USING BRIN (id);

-- function process_daco_xxx_event
DROP FUNCTION IF EXISTS process_daco_xxx_event() CASCADE;
CREATE OR REPLACE FUNCTION process_daco_xxx_event()
RETURNS trigger
LANGUAGE plpgsql
AS $$
    BEGIN
        INSERT INTO daco_xxx_event(
            schemaname,
            tabname, 
            operation, 
            new_val, 
            old_val
        )VALUES(
            TG_TABLE_SCHEMA, 
            TG_RELNAME, 
            TG_OP, 
            row_to_json(NEW), 
            row_to_json(OLD)
        );
        RETURN NEW;
    END;
$$;

DROP TRIGGER IF EXISTS trigger_daco_xxx_event ON xxx CASCADE;
CREATE TRIGGER trigger_daco_xxx_event
AFTER INSERT OR DELETE OR UPDATE OF name, active, can_be_sold, active_products, products_limit, use_sp, sp_name, categories_domain, categories_limit
ON xxx
FOR EACH ROW
EXECUTE FUNCTION process_daco_xxx_event();

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

UPDATE daco_xxx_event 
SET state='progress'
WHERE state='queue';

WITH update_daco_xxx_event AS (
    UPDATE daco_xxx_event
    SET state='done'
    WHERE seq IN (
        SELECT seq FROM daco_xxx_event_progress
        WHERE operation IN  ('INSERT','UPDATE', 'DELETE')
        ORDER BY seq ASC
        LIMIT 100
    ) AND state='progress'
    RETURNING *
)
INSERT INTO daco_xxx_sync (data)
SELECT row_to_json(a) FROM
    (SELECT id,
        seq,
        tabname,
        operation,
        json_build_object('value', new_val::json) as new_val,
        json_build_object('value', old_val::json) as old_val
    FROM update_daco_xxx_event ORDER BY seq ASC) AS a;

CREATE OR REPLACE FUNCTION sync_xxx()
RETURNS void
LANGUAGE plpgsql
AS $$
    DECLARE
        data_loop record;
    BEGIN
        FOR data_loop IN 
            SELECT id, 
                data::jsonb ->> 'id' as source_id, 
                data::jsonb ->> 'seq' as seq, 
                data::jsonb ->> 'tabname' as table_name, 
                data::jsonb ->> 'operation' as operation, 
                ((data::jsonb ->> 'new_val')::jsonb ->> 'value')::jsonb as new_val, 
                ((data::jsonb ->> 'old_val')::jsonb ->> 'value')::jsonb as old_val
            FROM daco_xxx_sync_queue order by seq asc
        LOOP
            IF data_loop.operation IN ('INSERT','UPDATE') THEN
                IF data_loop.table_name = 'xxx' THEN
                    INSERT INTO xxx_api(
                        id, name, active, can_be_sold, active_products,
                        products_limit, use_sp, sp_name, categories_domain, categories_limit
                    ) VALUES (
                        (data_loop.new_val ->> 'id')::int,
                        data_loop.new_val ->> 'name',
                        (data_loop.new_val ->> 'active')::boolean,
                        data_loop.new_val ->> 'can_be_sold',
                        data_loop.new_val ->> 'active_products',
                        (data_loop.new_val ->> 'products_limit')::int,
                        (data_loop.new_val ->> 'use_sp')::boolean,
                        data_loop.new_val ->> 'sp_name',
                        data_loop.new_val ->> 'categories_domain',
                        (data_loop.new_val ->> 'categories_limit')::int
                    ) 
                    ON CONFLICT(id)
                    DO UPDATE SET
                        name = data_loop.new_val ->> 'name',
                        active = (data_loop.new_val ->> 'active')::boolean,
                        can_be_sold = data_loop.new_val ->> 'can_be_sold',
                        active_products = data_loop.new_val ->> 'active_products',
                        products_limit = (data_loop.new_val ->> 'products_limit')::int,
                        use_sp = (data_loop.new_val ->> 'use_sp')::boolean,
                        sp_name = data_loop.new_val ->> 'sp_name',
                        categories_domain = data_loop.new_val ->> 'categories_domain',
                        categories_limit = (data_loop.new_val ->> 'categories_limit')::int,
                        daco_write_date = now();
                END IF;
            ELSEIF data_loop.operation = 'DELETE' THEN
                -- delete process when operation is delete
                DELETE FROM xxx_api WHERE id = (data_loop.old_val ->> 'id')::int;
            END IF;

            -- update state to done after insert into product api
            UPDATE daco_xxx_sync SET state = 'done' WHERE id = data_loop.id;
        END LOOP;
    END;
$$;