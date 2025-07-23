CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

ALTER TABLE irradiation_machine ADD COLUMN IF NOT EXISTS daco_id text;

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

CREATE INDEX IF NOT EXISTS daco_xxx_event_seq_index ON daco_xxx_event(seq);
CREATE INDEX IF NOT EXISTS daco_xxx_event_schemaname_index ON daco_xxx_event(schemaname);
CREATE INDEX IF NOT EXISTS daco_xxx_event_tabname_index ON daco_xxx_event(tabname);
CREATE INDEX IF NOT EXISTS daco_xxx_event_operation_index ON daco_xxx_event(operation);
CREATE INDEX IF NOT EXISTS daco_xxx_event_state_val_index ON daco_xxx_event(state);

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

CREATE INDEX IF NOT EXISTS daco_xxx_event_seq_index ON daco_xxx_event(seq);
CREATE INDEX IF NOT EXISTS daco_xxx_event_operation_index ON daco_xxx_event(operation);
CREATE INDEX IF NOT EXISTS daco_xxx_event_data_index ON daco_xxx_event(data);
CREATE INDEX IF NOT EXISTS daco_xxx_event_state_index ON daco_xxx_event(state);
CREATE INDEX IF NOT EXISTS daco_xxx_event_source_id_index ON daco_xxx_event(source_id);

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

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

DROP FUNCTION IF EXISTS sync_xxx;
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
            IF data_loop.operation = 'INSERT' THEN
                IF data_loop.table_name = 'irradiation_machine' THEN
                    INSERT INTO irradiation_machine(
                        id, name, technology_id, model, serial_number, branch, daco_id
                    ) VALUES (
                        nextval('irradiation_machine_id_seq'),
                        data_loop.new_val ->> 'name',
                        (data_loop.new_val ->> 'technology_id')::int,
                        data_loop.new_val ->> 'model',
                        data_loop.new_val ->> 'serial_number',
                        data_loop.new_val ->> 'branch',
                        data_loop.new_val ->> 'id'
                    );
                END IF;
            ELSEIF data_loop.operation = 'UPDATE' THEN
                UPDATE irradiation_machine SET 
                    name = data_loop.new_val ->> 'name',
                    technology_id = (data_loop.new_val ->> 'technology_id')::int,
                    model = data_loop.new_val ->> 'model',
                    serial_number = data_loop.new_val ->> 'serial_number',
                    branch = data_loop.new_val ->> 'branch'
                WHERE daco_id = data_loop.old_val ->> 'id';
            ELSEIF data_loop.operation = 'DELETE' THEN
                -- delete process when operation is delete
                DELETE FROM irradiation_machine WHERE daco_id = data_loop.old_val ->> 'id';
            END IF;

            -- update state to done after insert into product api
            UPDATE daco_xxx_sync SET state = 'done' WHERE id = data_loop.id;
        END LOOP;
    END;
$$;
