
            # try:
            #     logging.info('Start Push Rows Middleware')
            #     conns = psycopg2.connect(
            #         user=config['MIDDLEWARE_DB']['username'], 
            #         password=config['MIDDLEWARE_DB']['passwd'],
            #         database=config['MIDDLEWARE_DB']['database'],
            #         host=config['MIDDLEWARE_DB']['url'], 
            #         port=config['MIDDLEWARE_DB']['port'])
            #     curs = conns.cursor()
            #     curs.execute("""INSERT INTO maruetsu_filename_counter_row(file_name, number_of_rows) VALUES (%s, %s)""", (self.filename, 4))
            #     conns.commit()
            #     conns.close()
            #     local_path_normalize.unlink()
            #     logging.info('End Push Rows Middleware')
            # except Exception as e:
            #     logging.info('Failed Insert Data Rows')
            #     raise FTPOperationalException(e)

            # conns = psycopg2.connect(
            #     user=config['MIDDLEWARE_DB']['username'], 
            #     password=config['MIDDLEWARE_DB']['passwd'],
            #     database=config['MIDDLEWARE_DB']['database'],
            #     host=config['MIDDLEWARE_DB']['url'], 
            #     port=config['MIDDLEWARE_DB']['port'])
            # curs = conns.cursor()
            # curs.execute("""SELECT count(*) from %s WHERE file_name = '%s' GROUP BY file_name""" % (table_name, self.filename))
            # middleware_rows = curs.fetchall()
            # conns.commit()
            # conns.close()
            # num_rows = 4
            # print (middleware_rows[0][0], num_rows)
            # if middleware_rows[0][0] != num_rows:
            #     logging.info('Filename not correct')
            #     if self.ftp_home_dir == '/duplicate/':
            #         logging.info('Move to Anomaly Directory')
            #         self.cr.ftp_conn.rename(self.on_process_directory + self.filename, '/anomaly/' + self.filename[:-4] + '.dat')
            #         self.cr.ftp_conn.rename(self.on_process_directory + self.trigger_filename, '/anomaly/' + self.trigger_filename[:-3] + '.ok')
            #     elif self.ftp_home_dir == '/inbound/':
            #         logging.info('Move to Duplicate Directory')
            #         self.cr.ftp_conn.rename(self.on_process_directory + self.filename, '/duplicate/' + self.filename[:-4] + '-x.dat')
            #         self.cr.ftp_conn.rename(self.on_process_directory + self.trigger_filename, '/duplicate/' + self.trigger_filename[:-3] + '-x.ok')
            #     logging.info('Delete data in middleware')
            #     conns = psycopg2.connect(
            #         user=config['MIDDLEWARE_DB']['username'], 
            #         password=config['MIDDLEWARE_DB']['passwd'],
            #         database=config['MIDDLEWARE_DB']['database'],
            #         host=config['MIDDLEWARE_DB']['url'], 
            #         port=config['MIDDLEWARE_DB']['port'])
            #     curs = conns.cursor()
            #     curs.execute("""DELETE FROM %s WHERE file_name = '%s'""" % (table_name, self.filename))
            #     curs.execute("""DELETE FROM %s WHERE file_name = '%s'""" % ('maruetsu_filename_counter_row', self.filename))
            #     conns.commit()
            #     conns.close()
            #     raise Exception('File %s is Duplicate ' % self.filename)