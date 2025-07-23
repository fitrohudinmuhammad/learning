import unittest
import psycopg2
import psycopg2.extras
import os
import datetime


class TestCmsAPPQuery(unittest.TestCase):
    def setUp(self):
        self.conn = psycopg2.connect(
            host=os.environ['POSTGRES_HOST'],
            database=os.environ['POSTGRES_DB'],
            user=os.environ['POSTGRES_USER'],
            password=os.environ['POSTGRES_PASSWORD']
        )
        self.cur = self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        self.prepare_tables()

    # def setUp(self):
    #     self.conn = psycopg2.connect(
    #         host="localhost",
    #         database="copia_unit_testing",
    #         user="postgres",
    #         password="postgres"
    #     )
    #     self.cur = self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    #     self.prepare_tables()

    def prepare_tables(self):
        self.prepare_source_tables()
        self.prepare_event_tables()
        self.prepare_trigger_event_table()
        self.prepare_sync_tables()
        self.prepare_destination_tables()

    def prepare_source_tables(self):
        xxx_table = """
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
        """
        self.cur.execute(xxx_table)

    def prepare_event_tables(self):
        xxx_event_table = """
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

        """
        self.cur.execute(xxx_event_table)

        xxx_event_queue = """CREATE TABLE daco_xxx_event_queue PARTITION OF daco_xxx_event FOR VALUES IN('queue');"""
        xxx_event_progress = """CREATE TABLE daco_xxx_event_progress PARTITION OF daco_xxx_event FOR VALUES IN('progress');"""
        xxx_event_done = """CREATE TABLE daco_xxx_event_done PARTITION OF daco_xxx_event FOR VALUES IN('done');"""
        xxx_event_skip = """CREATE TABLE daco_xxx_event_skip PARTITION OF daco_xxx_event FOR VALUES IN('skip');"""

        self.cur.execute(xxx_event_queue)
        self.cur.execute(xxx_event_progress)
        self.cur.execute(xxx_event_done)
        self.cur.execute(xxx_event_skip)

    def prepare_trigger_event_table(self):
        xxx_event_func = """
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
        """
        self.cur.execute(xxx_event_func)

        drop_xxx_event_trigger = """DROP TRIGGER IF EXISTS trigger_daco_xxx_event ON xxx CASCADE;"""
        self.cur.execute(drop_xxx_event_trigger)

        xxx_event_trigger = """
            CREATE TRIGGER trigger_daco_xxx_event
            AFTER INSERT OR DELETE OR UPDATE OF name, active, can_be_sold, active_products, products_limit, use_sp, sp_name, categories_domain, categories_limit
            ON xxx
            FOR EACH ROW
            EXECUTE FUNCTION process_daco_xxx_event();
        """
        self.cur.execute(xxx_event_trigger)

    def prepare_sync_tables(self):
        xxx_sync_table = """
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
        """
        self.cur.execute(xxx_sync_table)

        xxx_sync_queue = """CREATE TABLE daco_xxx_sync_queue PARTITION OF daco_xxx_sync FOR VALUES IN('queue');"""
        xxx_sync_progress = """CREATE TABLE daco_xxx_sync_progress PARTITION OF daco_xxx_sync FOR VALUES IN('progress');"""
        xxx_sync_done = """CREATE TABLE daco_xxx_sync_done PARTITION OF daco_xxx_sync FOR VALUES IN('done');"""
        xxx_sync_skip = """CREATE TABLE daco_xxx_sync_skip PARTITION OF daco_xxx_sync FOR VALUES IN('skip');"""
        xxx_sync_lock = """CREATE TABLE daco_xxx_sync_lock PARTITION OF daco_xxx_sync FOR VALUES IN('lock');"""

        self.cur.execute(xxx_sync_queue)
        self.cur.execute(xxx_sync_progress)
        self.cur.execute(xxx_sync_done)
        self.cur.execute(xxx_sync_skip)
        self.cur.execute(xxx_sync_lock)

    def prepare_destination_tables(self):
        xxx_api_table = """
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
        """

        self.cur.execute(xxx_api_table)

    def run_daco_integration(self):
        self.pull_data_from_event_table()
        self.send_data_to_sync_table()
        self.insert_into_destination_table()

    # 1st block postgres in DACO
    def pull_data_from_event_table(self):
        update_query = """
            UPDATE daco_xxx_event 
            SET state='progress'
            WHERE state='queue';
        """
        self.cur.execute(update_query)

    # 2nd block & #3rd block postgres in DACO
    def send_data_to_sync_table(self):
        insert_query = """
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
            INSERT INTO daco_xxx_sync
                (data)
            SELECT row_to_json(a) FROM
                (SELECT id,
                    seq,
                    tabname,
                    operation,
                    json_build_object('value', new_val::json) as new_val,
                    json_build_object('value', old_val::json) as old_val
                FROM update_daco_xxx_event ORDER BY seq ASC) AS a;
        """
        self.cur.execute(insert_query)

    # 4th block postgres in DACO
    def insert_into_destination_table(self):
        func_query = """
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
                            DELETE FROM xxx_api 
                            WHERE id = (data_loop.old_val ->> 'id')::int;
                        END IF;

                        -- update state to done after insert into product api
                        UPDATE daco_xxx_sync SET state = 'done' WHERE id = data_loop.id;
                    END LOOP;
                END;
            $$;
        """
        self.cur.execute(func_query)
        self.cur.execute("SELECT sync_xxx()")

    # ====================================
    # Scenario #1
    # ====================================
    # 1.1 create product xxx
    def test_create_product_xxx(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (1,'a', true, 'true', 'true',
                1, true, 'a', 'a', 1)
        """
        self.cur.execute(insert_query)

        self.run_daco_integration()

        self.cur.execute("SELECT * FROM xxx_api")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {
            'id': 1,
            'name': 'a',
            'active': True,
            'can_be_sold': 'true',
            'active_products': 'true',
            'products_limit': 1,
            'use_sp': True,
            'sp_name': 'a',
            'categories_domain': 'a',
            'categories_limit': 1,
            'daco_create_date': res[0].get('daco_create_date'),
            'daco_write_date': res[0].get('daco_write_date')
        }

        message = 'The data should be in xxx_api table'
        self.assertEqual(real_output, expected_output, message)

    # 1.2 update product xxx
    def test_update_product_xxx(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (2,'a2', true, 'true', 'true',
                2, true, 'a2', 'a2', 2)
        """
        self.cur.execute(insert_query)

        update_query = """
            UPDATE xxx SET
                name = 'a21',
                active = true,
                can_be_sold = '200'
            WHERE id = 2
        """
        self.cur.execute(update_query)

        self.run_daco_integration()

        self.cur.execute("SELECT * FROM xxx_api")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {
            'id': 2,
            'name': 'a21',
            'active': True,
            'can_be_sold': '200',
            'active_products': 'true',
            'products_limit': 2,
            'use_sp': True,
            'sp_name': 'a2',
            'categories_domain': 'a2',
            'categories_limit': 2,
            'daco_create_date': res[0].get('daco_create_date'),
            'daco_write_date': res[0].get('daco_write_date')
        }

        message = 'The data should be in xxx_api table updated'
        self.assertEqual(real_output, expected_output, message)

    # 1.3 delete product xxx
    def test_delete_product_xxx(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (3,'a3', true, 'true', 'true',
                3, true, 'a3', 'a3', 3)
        """
        self.cur.execute(insert_query)

        delete_query = """
            DELETE FROM xxx WHERE id = 3
        """
        self.cur.execute(delete_query)

        self.run_daco_integration()

        self.cur.execute("SELECT (COALESCE(count(*),0)) as data_count FROM xxx_api")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 0}

        message = "The data should no longer exist in the xxx_api table !"
        self.assertEqual(real_output, expected_output, message)

    # ====================================
    # Scenario #2
    # ====================================
    # 2.1 1 create event scenario
    def test_one_create_event(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (4,'a4', true, 'true', 'true',
                4, true, 'a4', 'a4', 4)
        """
        self.cur.execute(insert_query)

        self.run_daco_integration()

        self.cur.execute(
            "SELECT (COALESCE(count(*),0)) as data_count FROM daco_xxx_event where operation = 'INSERT'")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 1}

        message = 'There should be 1 record with operation INSERT in event table'
        self.assertEqual(real_output, expected_output, message)

    # 2.2 more than 1 create event scenario
    def test_more_than_one_create_event(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (5,'a5', true, 'true', 'true',
                5, true, 'a5', 'a5', 5)
        """
        self.cur.execute(insert_query)

        insert_query2 = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (6,'a6', true, 'true', 'true',
                6, true, 'a6', 'a6', 6)
        """
        self.cur.execute(insert_query2)

        self.run_daco_integration()

        self.cur.execute(
            "SELECT (COALESCE(count(*),0)) as data_count FROM daco_xxx_event where operation = 'INSERT'")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 2}

        message = 'There should be 2 record with operation INSERT in event table'
        self.assertEqual(real_output, expected_output, message)

    # 2.3 1 update event scenario
    def test_one_update_event(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (7,'a7', true, 'true', 'true',
                7, true, 'a7', 'a7', 7)
        """
        self.cur.execute(insert_query)

        update_query = """
            UPDATE xxx SET
                name = 'a27',
                active = true,
                can_be_sold = '700'
            WHERE id = 7
        """
        self.cur.execute(update_query)

        self.run_daco_integration()

        self.cur.execute(
            "SELECT (CO ALESCE(count(*),0)) as data_count FROM daco_xxx_event where operation = 'UPDATE'")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 1}

        message = 'There should be 1 record with operation UPDATE in event table'
        self.assertEqual(real_output, expected_output, message)

    # 2.4 more than 1 update event scenario
    def test_more_then_one_update_event(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (8,'a8', true, 'true', 'true',
                8, true, 'a8', 'a8', 8)
        """
        self.cur.execute(insert_query)

        update_query1 = """
            UPDATE xxx SET
                name = 'a81',
                active = true,
                can_be_sold = '800'
            WHERE id = 8
        """
        self.cur.execute(update_query1)

        update_query2 = """
            UPDATE xxx SET
                name = 'a91',
                active = true,
                can_be_sold = '900'
            WHERE id = 8
        """
        self.cur.execute(update_query2)

        self.run_daco_integration()

        self.cur.execute(
            "SELECT (COALESCE(count(*),0)) as data_count FROM daco_xxx_event where operation = 'UPDATE'")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 2}

        message = 'There should be 2 record with operation UPDATE in event table'
        self.assertEqual(real_output, expected_output, message)

    # 2.5 1 delete event scenario
    def test_one_delete_event(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (9,'a9', true, 'true', 'true',
                9, true, 'a9', 'a9', 9)
        """
        self.cur.execute(insert_query)

        delete_query = """
            DELETE FROM xxx WHERE id = 9
        """
        self.cur.execute(delete_query)

        self.run_daco_integration()

        self.cur.execute(
            "SELECT (COALESCE(count(*),0)) as data_count FROM daco_xxx_event where operation = 'DELETE'")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 1}

        message = 'There should be 1 record with operation DELETE in event table'
        self.assertEqual(real_output, expected_output, message)

    # 2.6 more than 1 delete event scenario
    def test_more_then_one_delete_event(self):
        insert_query1 = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (10,'a10', true, 'true', 'true',
                10, true, 'a10', 'a10', 10)
        """
        self.cur.execute(insert_query1)

        insert_query2 = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (11,'a11', true, 'true', 'true',
                11, true, 'a11', 'a11', 11)
        """
        self.cur.execute(insert_query2)

        delete_query1 = """
            DELETE FROM xxx WHERE id = 10
        """
        self.cur.execute(delete_query1)

        delete_query2 = """
            DELETE FROM xxx WHERE id = 11
        """
        self.cur.execute(delete_query2)

        self.run_daco_integration()

        self.cur.execute(
            "SELECT (COALESCE(count(*),0)) as data_count FROM daco_xxx_event where operation = 'DELETE'")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 2}

        message = 'There should be 2 record with operation DELETE in event table'
        self.assertEqual(real_output, expected_output, message)

    # ====================================
    # Scenario #3
    # ====================================
    # 3.1 create and update
    def test_create_update(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (12,'a12', true, 'true', 'true',
                12, true, 'a12', 'a12', 12)
        """
        self.cur.execute(insert_query)

        update_query = """
            UPDATE xxx SET
                name = 'a2112',
                active = true,
                can_be_sold = '1200'
            WHERE id = 12
        """
        self.cur.execute(update_query)

        self.run_daco_integration()

        # check in table event
        self.cur.execute(
            "SELECT (COALESCE(count(*),0)) as data_count FROM daco_xxx_event WHERE operation in ('INSERT','UPDATE')")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 2}

        message = 'There should be 2 record with operation INSERT AND UPDATE in event table'
        self.assertEqual(real_output, expected_output, message)

        # check in table xxx_api
        self.cur.execute("SELECT * FROM xxx_api")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {
            'id': 12,
            'name': 'a2112',
            'active': True,
            'can_be_sold': '1200',
            'active_products': 'true',
            'products_limit': 12,
            'use_sp': True,
            'sp_name': 'a12',
            'categories_domain': 'a12',
            'categories_limit': 12,
            'daco_create_date': res[0].get('daco_create_date'),
            'daco_write_date': res[0].get('daco_write_date')
        }

        message = 'The data should be in xxx_api table'
        self.assertEqual(real_output, expected_output, message)

    # 3.2/3.4 create, update and delete
    def test_create_update_delete(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (13,'a13', true, 'true', 'true',
                13, true, 'a13', 'a13', 13)
        """
        self.cur.execute(insert_query)

        update_query = """
            UPDATE xxx SET
                name = 'a2113',
                active = true,
                can_be_sold = '1300'
            WHERE id = 13
        """
        self.cur.execute(update_query)

        delete_query = """
            DELETE FROM xxx WHERE id = 13
        """
        self.cur.execute(delete_query)

        self.run_daco_integration()

        # check in table event
        self.cur.execute(
            "SELECT (COALESCE(count(*),0)) as data_count FROM daco_xxx_event WHERE operation in ('INSERT','UPDATE','DELETE')")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 3}

        message = 'There should be 3 record with operation INSERT, UPDATE AND DELETE in event table'
        self.assertEqual(real_output, expected_output, message)

        # check in table xxx_api
        self.cur.execute("SELECT (COALESCE(count(*),0)) as data_count FROM xxx_api")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 0}

        message = "The data should no longer exist in the xxx_api table !"
        self.assertEqual(real_output, expected_output, message)

    # 3.3 create and delete
    def test_create_delete(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (14,'a14', true, 'true', 'true',
                14, true, 'a14', 'a14', 14)
        """
        self.cur.execute(insert_query)

        delete_query = """
            DELETE FROM xxx WHERE id = 14
        """
        self.cur.execute(delete_query)

        self.run_daco_integration()

        # check in table event
        self.cur.execute(
            "SELECT (COALESCE(count(*),0)) as data_count FROM daco_xxx_event WHERE operation in ('INSERT','DELETE')")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 2}

        message = 'There should be 2 record with operation INSERT AND DELETE in event table'
        self.assertEqual(expected_output, real_output, message)

        # check in table xxx_api
        self.cur.execute("SELECT (COALESCE(count(*),0)) as data_count FROM xxx_api")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 0}

        message = "The data should no longer exist in the xxx_api table !"
        self.assertEqual(real_output, expected_output, message)

    # 4.1 insert, update column mapping xxx
    def test_insert_update_column_mapping_xxx(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (15,'a15', true, 'true', 'true',
                15, true, 'a15', 'a15', 15)
        """
        self.cur.execute(insert_query)

        update_query = """
            UPDATE xxx SET
                name = 'a2115',
                active = true,
                can_be_sold = '1500'
            WHERE id = 15
        """
        self.cur.execute(update_query)

        self.run_daco_integration()

        self.cur.execute(
            "SELECT (COALESCE (COUNT(*),0)) AS data_count FROM daco_xxx_event where operation in ('INSERT','UPDATE')")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 2}

        message = 'There should be 2 record with operation INSERT AND UPDATE in event table'
        self.assertEqual(real_output, expected_output, message)

    # 4.2 insert, update other column mapping xxx
    def test_insert_update_other_column_mapping_xxx(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (16, 'a16', true, 'true', 'true',
                16, true, 'a16', 'a16', 16)
        """
        self.cur.execute(insert_query)

        update_query = """
            UPDATE xxx SET
                name = 'a16',
                active = true,
                can_be_sold = '1600'
            WHERE id = 16
        """
        self.cur.execute(update_query)

        self.run_daco_integration()

        self.cur.execute("SELECT (COALESCE (COUNT(*),0)) AS data_count FROM daco_xxx_event")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 2}

        message = 'There should be 1 record with operation just INSERT in event table'
        self.assertEqual(expected_output, real_output, message)

    # 5.1 insert 2x to check duplciate insert to make sure the onconflict do update runs well
    def test_insert_double_id(self):
        insert_query = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (17,'a17', true, 'true', 'true',
                17, true, 'a17', 'a17', 17)
        """
        self.cur.execute(insert_query)

        insert_query2 = """
            INSERT INTO xxx
                (id, name, active, can_be_sold, active_products,
                products_limit, use_sp, sp_name, categories_domain, categories_limit) 
            VALUES (17,'a18', true, 'true', 'true',
                18, true, 'a18', 'a18', 18)
        """
        self.cur.execute(insert_query2)

        self.run_daco_integration()

        # check in table event have 2 record
        self.cur.execute("SELECT (COALESCE (COUNT(*),0)) AS data_count FROM daco_xxx_event")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 2}

        message = 'There should be 2 record with operation just INSERT in event table'
        self.assertEqual(real_output, expected_output, message)

        # check in table api just 1 record
        self.cur.execute("SELECT (COALESCE (COUNT(*),0)) AS data_count FROM xxx_api")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {'data_count': 1}

        message = 'There should be just 1 record successfully insert in event table, no duplicate'
        self.assertEqual(real_output, expected_output, message)

        # check on conflict do update runs well
        self.cur.execute("SELECT * FROM xxx_api")
        res = self.cur.fetchall()
        res = [dict(row) for row in res]

        real_output = res[0]
        expected_output = {
            'id': 17,
            'name': 'a18',
            'active': True,
            'can_be_sold': 'true',
            'active_products': 'true',
            'products_limit': 18,
            'use_sp': True,
            'sp_name': 'a18',
            'categories_domain': 'a18',
            'categories_limit': 18,
            'daco_create_date': res[0].get('daco_create_date'),
            'daco_write_date': res[0].get('daco_write_date')
        }

        message = 'The data should be in xxx_api table updated from insert in the second time'
        self.assertEqual(real_output, expected_output, message)

    def tearDown(self):
        self.cur.close()
        self.conn.close()
