CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

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

DROP FUNCTION IF EXISTS irradiation_trigger_event() CASCADE;
CREATE OR REPLACE FUNCTION irradiation_trigger_event() RETURNS TRIGGER AS $$
BEGIN
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
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_on_irradiation_machine ON irradiation_machine CASCADE;
CREATE TRIGGER trigger_on_irradiation_machine
AFTER INSERT OR UPDATE OR DELETE ON irradiation_machine
FOR EACH ROW
EXECUTE FUNCTION irradiation_trigger_event();

