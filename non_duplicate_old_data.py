import ftplib, sys, os, pathlib
import psycopg2, logging, gzip, shutil

sys.path.insert(0, os.path.abspath(os.path.join(os.path.curdir, '..')))

from ftp_integration import setting

def push_data_old_data():
    config = setting.config()
    conns = psycopg2.connect(
        user=config['MIDDLEWARE_DB']['username'], 
        password=config['MIDDLEWARE_DB']['passwd'],
        database=config['MIDDLEWARE_DB']['database'],
        host=config['MIDDLEWARE_DB']['url'], 
        port=config['MIDDLEWARE_DB']['port'])
    curs = conns.cursor()
    logging.info('Insert Data')
    curs.execute("""SELECT ftp_success_dir FROM ftp_server WHERE server_key IN ('ftp_maruetsu_disposal', 'ftp_maruetsu_pos_sale', 'ftp_maruetsu_inventory_adjustment', 'ftp_maruetsu_purchasing', 'ftp_maruetsu_single_inventory')""")
    datas = curs.fetchall()
    print (datas)
    conns.close()

def insert_number_of_rows():
    config = setting.config()
    filename = None
    num_rows = None
    ftp_dir = '/Initial/initial_11_oct' # iki penyesuaian ya, enake di gawe list opo piye?
    
    ftp = ftplib.FTP(
        host='usmh-fm.prod.apcod.jp')
    ftp.login(
        user='maruetsu_store', 
        passwd="""9"At'c3+""")
    datas = ftp.mlsd(ftp_dir)
    for data in datas:
        if data[1].get('type') == 'file' and data[0].endswith('.dat'):
            filename = data[0]
            ftp_file = ftp_dir + '/' + filename
            local_dir = '/opt/m2_files/'
            extract_file = pathlib.Path('/opt/m2_files/extract_' + filename)
            file_dat = pathlib.Path(local_dir + filename)
            with open(local_dir + filename, 'wb') as fp:
                ftp.retrbinary('RETR %s' % ftp_file, fp.write)
            
            # with gzip.open(local_dir + filename, 'rb') as f_in:
            #     with open(extract_file, 'wb') as f_out:
            #         shutil.copyfileobj(f_in, f_out)

            # with open(local_dir + filename, 'rb') as ef:
            #     lines = ef.readlines()
            #     num_rows = len(lines)
            # extract_file.unlink()
            # file_dat.unlink()
            # print (filename, num_rows)

            # conns = psycopg2.connect(
            #     user=config['MIDDLEWARE_DB']['username'], 
            #     password=config['MIDDLEWARE_DB']['passwd'],
            #     database=config['MIDDLEWARE_DB']['database'],
            #     host=config['MIDDLEWARE_DB']['url'], 
            #     port=config['MIDDLEWARE_DB']['port'])
            # curs = conns.cursor()
            # logging.info('Insert Data')
            # curs.execute("""INSERT INTO maruetsu_old_filename_counter_row(file_name, number_of_rows, directory) VALUES ('%s', %s, '%s')""" % (filename, num_rows, ftp_dir))
            # conns.commit()
            # conns.close()
            
    ftp.quit()

def move_file():
    config = setting.config()
    conns = psycopg2.connect(
        user=config['MIDDLEWARE_DB']['username'], 
        password=config['MIDDLEWARE_DB']['passwd'],
        database=config['MIDDLEWARE_DB']['database'],
        host=config['MIDDLEWARE_DB']['url'], 
        port=config['MIDDLEWARE_DB']['port'])
    curs = conns.cursor()
    logging.info('Insert Data')
    curs.execute("""SELECT id, file_name FROM maruetsu_old_filename_counter_row WHERE is_duplicate = True""")
    datas = curs.fetchall()
    print (datas)
    conns.close()

insert_number_of_rows()
# move_file()