import psycopg2, os

output_path = '/opt/oneweekod/'

for files in os.listdir(output_path):
    print (files)
    conn = psycopg2.connect(
        user='postgres', 
        password='postgres',
        host='localhost',
        port='5432',
        database='usmh_dev'
    )
    cr = conn.cursor()
    with open(output_path + files, 'r') as source_file:
        content = source_file.readlines()
        for line in content:
            ln = line.replace('\n','').split(',')
            cr.execute("""INSERT INTO od_files_temp (code, store_code, jan_code, qty, filename) VALUES ('%s', '%s', '%s', %s, '%s')""" % (ln[0], ln[1], ln[2], ln[3], files))
            conn.commit()
        print ('DONE')
    conn.close()
    # raise Exception();
    
# conn = psycopg2.connect(
#     user='celery', 
#     password='celeryadmin',
#     host='10.130.0.35',
#     port='5432',
#     database='kasumi_middleware'
# )
# cr = conn.cursor()
# cr.execute('SELECT * FROM stock_quant_by_store')
# res = cr.fetchall()
# print (res)