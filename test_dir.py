import os
import pathlib, shutil, gzip
import sys
import psycopg2

files = os.listdir('/opt/m2_pos_files')
local_dir = '/opt/m2_pos_files'
local_csv_dir = '/opt/m2_csv_files/'
# files = ['GUT030P-20220120000000.dat']

for file in files:
    if not os.path.isdir(file) and file.endswith('.dat') and len(file) == 26:
        os.rename(local_dir + '/' + file, local_csv_dir + file)
        extract_file = pathlib.Path(local_csv_dir + 'extract_' + file)
        with gzip.open(local_csv_dir + file, 'rb') as f_in:
            with open(extract_file, 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)

        path_file = pathlib.Path(local_csv_dir + file)
        # local_path_normalize = pathlib.Path(local_csv_dir +'NORMALIZE_' + file)

        try:
            num_rows = 0
            conn = psycopg2.connect(
                host='localhost',
                database='maruetsu_middleware_uat',
                user='postgres',
                password='postgres')
            with open(extract_file, 'r') as file_path:
                lines = file_path.readlines()
                for line in lines:
                    num_rows += 1
                # file_encod.write(str(file)+','+str(num_rows))
            curs = conn.cursor()
            curs.execute("""SELECT nama_fungsi(%s, %s)""", (str(file), num_rows))
            # curs.execute("""INSERT INTO table_compare(filename, number_of_rows) VALUES (%s, %s)""", (str(file), num_rows))
            conn.commit()
            conn.close()

            extract_file.unlink()
            # local_path_normalize.unlink()
        except Exception as e:
            raise Exception(("The file " + file + " is unreadable : " + str(e)))
        path_file.unlink()


drop table if exists temp_insert_sale_order;
CREATE TABLE temp_insert_sale_order (
  so_id integer,
  so_name varchar,
  create_date timestamp default now(),
  create_uid integer
);

DROP FUNCTION IF EXISTS record_blocking_query(varchar);
CREATE OR REPLACE FUNCTION record_blocking_query(nama varchar)
  RETURNS void 
  LANGUAGE plpgsql
  AS
$$
BEGIN
	iNSERT INTO temp_insert_sale_order (so_name) values (nama);
END;
$$
;

select record_blocking_query('wisnu');
select * from temp_insert_sale_order;
