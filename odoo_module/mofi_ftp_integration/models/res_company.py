from odoo import models, fields, api, _
import ftplib
import logging
import pathlib
import os
from datetime import date, datetime
import pysftp
from odoo.exceptions import AccessError, ValidationError

logger = logging.getLogger(__name__)


class ResCompany(models.Model):
    _inherit = "res.company"

    name_ftp = fields.Char()
    host_ftp = fields.Char()
    port_ftp = fields.Integer()
    username_ftp = fields.Char()
    password_ftp = fields.Char()
    ftp_active = fields.Boolean()

    private_selected = fields.Boolean(default=False)
    private_key = fields.Char()
    private_key_pass = fields.Char(related="password_ftp")
    sftp_active = fields.Boolean()

    ftp_home_dir = fields.Char(default="/", required=True)
    ftp_inbound_dir = fields.Char(default="/inbound/", required=True)
    ftp_on_process_dir = fields.Char(default="/on_process/", required=True)
    ftp_success_dir = fields.Char(default="/success/", required=True)
    ftp_anomaly_dir = fields.Char(default="/anomaly/", required=True)
    ftp_duplicate_dir = fields.Char(default="/duplicate/", required=True)
    local_directory = fields.Char(required=True, default="/opt/csv_files/")
    table_name = fields.Char()
    filename = fields.Char()
    columns = fields.Text()

    # FTP Section
    def connection_to_ftp(self):
        for rec in self.env.user.company_id:
            if rec.ftp_active:
                if not rec.host_ftp:
                    raise ValidationError('Please Fill host name')
                if not rec.username_ftp:
                    raise ValidationError('Please Fill username')
                if not rec.password_ftp:
                    raise ValidationError('Please Fill password')
                try:
                    ftp = ftplib.FTP(rec.host_ftp)
                    ftp.login(rec.username_ftp, rec.password_ftp)
                    logger.info("===============")
                    logger.info('FTP Connected')
                    return ftp
                except Exception as e:
                    logger.exception('Connection is wrong for %s' %
                                     rec.host_ftp)
                    raise AccessError(e)
            else:
                logger.error('Your FTP Not Active')

    def ftp_on_process_handler(self, ftp_conn, file):
        company = self.env.user.company_id
        ftp_file = company.ftp_inbound_dir + file
        if ftp_file.endswith(('.csv', '.CSV')):
            with open(company.local_directory + file, 'wb') as handle:
                logger.info("Opened file success: %s" % file)
                ftp_conn.retrbinary('RETR %s' % ftp_file, handle.write)
        logger.info('Download Files %s' % file)
        self.ftp_move_csv_on_process(ftp_conn, file, company.ftp_inbound_dir,
                                     target_dir=company.ftp_on_process_dir)

    def ftp_pull_data(self, ftp_conn):
        company = self.env.user.company_id
        datas = ftp_conn.mlsd(company.ftp_inbound_dir)
        files = []
        found = False
        for file in datas:
            if file[1].get('type') == 'dir':
                continue
            elif file[1].get('type') == 'file'\
                    and file[0].endswith(('.csv', '.CSV')):
                rec = file[0]
                found = True
                files.append(rec)
        if found:
            for file in files:
                self.ftp_on_process_handler(ftp_conn, file)

    def ftp_create_directory_if_not_exists(self, ftp_conn, dir):
        try:
            ftp_conn.cwd(dir)
        except Exception:
            ftp_conn.mkd(dir)
            ftp_conn.cwd(dir)
        return True

    def ftp_move_csv(self, ftp_conn, filename, origin_path, dest_path,
                     use_timestamp=False):
        origin_file = f'{origin_path}{filename}'
        dest_file = f'{dest_path}{filename}'
        logger.info("Moving file:%s from %s to %s" %
                    (filename, origin_path, dest_path))
        logger.info("Move_csv Renaming:%s-->%s" % (origin_file, dest_file))
        logger.info("===================================")
        ftp_conn.rename(origin_file, dest_file)

    def ftp_move_csv_on_process(self, ftp_conn, filename, origin_path,
                                target_dir=None, use_timestamp=False):
        company = self.env.user.company_id
        ftp_conn.cwd(company.ftp_home_dir)
        if not target_dir:
            target_dir = company.ftp_on_process_dir
        elif target_dir[:-1] != '/':
            target_dir = target_dir + '/'
        if origin_path[-1] != '/':
            origin_path += '/'
        logger.info("Move CSV On Process: Filename: %s, Origin_path:%s" %
                    (filename, origin_path))
        on_process_path = target_dir
        self.ftp_create_directory_if_not_exists(ftp_conn, on_process_path)
        try:
            self.ftp_move_csv(ftp_conn, filename, origin_path, on_process_path,
                              use_timestamp=use_timestamp)
        except Exception as e:
            logger.error('--------------------------------------')
            logger.error('Move to on process failed Put back file %s from %s'
                         ' to %s' % (filename, on_process_path, origin_path))
            logger.error('The file ' + filename + ' is unreadable')
            logger.error('--------------------------------------')
            self.ftp_move_csv_anomaly(ftp_conn, filename, origin_path, '/anomaly/')

    def ftp_move_csv_anomaly(self, ftp_conn, filename, origin_path,
                             target_dir=None, use_timestamp=False):
        company = self.env.user.company_id
        ftp_conn.cwd(company.ftp_home_dir)
        if not target_dir:
            target_dir = company.ftp_anomaly_dir
        elif target_dir[:-1] != '/':
            target_dir = target_dir + '/'
        if origin_path[-1] != '/':
            origin_path += '/'
        logger.info("Move CSV Anomaly: Filename: %s, Origin_path:%s" %
                    (filename, origin_path))
        anomaly_path = target_dir
        self.ftp_create_directory_if_not_exists(ftp_conn, anomaly_path)
        self.ftp_move_csv(ftp_conn, filename, origin_path, anomaly_path,
                          use_timestamp=use_timestamp)

    def ftp_move_csv_success(self, ftp_conn, filename, origin_path,
                             target_dir=None, use_timestamp=False):
        company = self.env.user.company_id
        ftp_conn.cwd(company.ftp_home_dir)
        if not target_dir:
            target_dir = company.ftp_success_dir
        elif target_dir[:-1] != '/':
            target_dir = target_dir + '/'
        if origin_path[-1] != '/':
            origin_path += '/'
        logger.info("Move CSV Success: Filename: %s, Origin_path:%s" %
                    (filename, origin_path))
        success_path = target_dir
        self.ftp_create_directory_if_not_exists(ftp_conn, success_path)
        try:
            self.ftp_move_csv(ftp_conn, filename, origin_path, success_path,
                              use_timestamp=use_timestamp)
        except Exception as e:
            logger.error('--------------------------------------')
            logger.error('Move to anomaly failed Put back file %s from %s to'
                         ' %s' % (filename, origin_path, '/anomaly/'))
            logger.error('The file ' + filename + ' is unreadable')
            logger.error('--------------------------------------')
            ftp_conn.rename(origin_path + filename, '/anomaly/' + filename)

    def ftp_push_data_to_middleware(self, ftp_conn, table_name, filename=False, columns=False):
        company = self.env.user.company_id
        logger.info('Start Push into Middleware')
        success = True
        if not filename:
            raise ValidationError('File not Found')
        new_file = self.normalize_data(company.local_directory, filename)
        filepath = pathlib.Path(company.local_directory + filename)
        nfilepath = pathlib.Path(new_file)

        ftp_conn.close()
        try:
            self.insert_into_mid_table(table_name, new_file, columns)
            self.env.cr.execute("""
                SELECT process_aggregation_data('%s');
            """ % (filename))
        except Exception as e:
            logger.error(e)
            success = False

        ftp_conn = self.connection_to_ftp()
        if success:
            logger.info('Success')
            if os.path.isfile(filepath):
                filepath.unlink()
            if os.path.isfile(nfilepath):
                nfilepath.unlink()
            # if company.ftp_active:
            #     ftp_conn.delete(company.ftp_on_process_dir + filename)
            # elif company.sftp_active:
            #     ftp_conn.remove(company.ftp_on_process_dir + filename)
            self.ftp_move_csv_success(
                ftp_conn, filename, company.ftp_on_process_dir,
                company.ftp_success_dir)
        else:
            logger.info('Fail')
            self.ftp_move_csv_anomaly(
                ftp_conn, filename, company.ftp_on_process_dir,
                company.ftp_anomaly_dir)
            if os.path.isfile(filepath):
                filepath.unlink()
            if os.path.isfile(nfilepath):
                nfilepath.unlink()
            self.env.cr.execute("""
                INSERT INTO logging_integration (name, filename, description, log_time,
                    error_status, active) VALUES ('%s', '%s', '%s', now(), true, true)
            """ % ('ERROR: File cant process', filename, 'File cant processing'))
        # else:
        #     self.ftp_move_csv(ftp_conn, filename, company.ftp_on_process_dir, company.ftp_duplicate_dir)
        #     if os.path.isfile(filepath):
        #         filepath.unlink()
        #     if os.path.isfile(nfilepath):
        #         nfilepath.unlink()

    def action_ftp_pull_data(self):
        company = self.env.user.company_id
        ftp_conn = self.connection_to_ftp()
        self.ftp_pull_data(ftp_conn)
        files_directory = os.listdir(company.local_directory)
        today = datetime.now().strftime("%Y%m%d")

        if company.filename in files_directory:
            res_file = 'result-' + company.filename
            filepath = pathlib.Path(company.local_directory + company.filename)
            if not self.checking_data_available(ftp_conn, company.table_name, company.filename):
                self.ftp_move_csv(
                    ftp_conn, company.filename,
                    company.ftp_on_process_dir,
                    company.ftp_duplicate_dir)
                logger.info('File %s duplicate, then move to Duplicate Directory' % company.filename)
                if os.path.isfile(filepath):
                    filepath.unlink()
            else:
                self.ftp_push_data_to_middleware(
                    ftp_conn, company.table_name,
                    filename=company.filename,
                    columns=company.columns)

                logger.info('Process Insert Data to Odoo')
                self.env.cr.execute("""
                    SELECT process_insert_data_to_odoo('%s');
                """ % (company.filename))

                logger.info('Process Update stage')
                self.env.cr.execute("""
                    SELECT process_update_stage_after_insert('%s')
                """ % (company.filename))

                self.env.cr.commit()
                self.env.cr.execute("""
                    SELECT contract_number
                    FROM aggregation_table
                    WHERE filename = '%s'  AND stage = 3
                    GROUP BY contract_number ORDER by contract_number;
                """ % (company.filename))
                data_contract = self.env.cr.fetchall()
                if data_contract:
                    for contract in data_contract:
                        if self.env['leasing.contract'].search([('name', 'in', contract)]).status in ('draft', 'active'):
                            ctx = {
                                'source': 'wrapper',
                                'filename': company.filename,
                                'contract_number': contract,
                            }
                            self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(ctx).action_reconcile_loan_entries()
                            self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(ctx).action_reconcile_payment_entries()
                            # self.env['leasing.contract'].search([('name', 'in', contract)]).generate_amortization()
                            self.env['leasing.contract'].search([('name', 'in', contract)]).write({'status': 'active'})
                            context = {
                                'termination_date': date.today(),
                                'termination_note': 'Termination From Wrapper'
                            }
                            self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(context)._action_termination()

                try:
                    ftp_conn = self.connection_to_ftp()
                    self.generate_result_files(company.filename, res_file)
                    ftp_conn.cwd('/success/')
                    with open('/tmp/' + res_file, "rb") as file:
                        ftp_conn.storbinary(f"STOR {res_file}", file)
                except Exception as e:
                    logger.error(e)
                # self.remove_file_not_use(ftp_conn, company)
        else:
            for file in files_directory:
                if file[:8] == today \
                        and file.endswith(('.csv', '.CSV')):
                    res_file = 'result-' + file
                    filepath = pathlib.Path(company.local_directory + file)
                    if not self.checking_data_available(ftp_conn, company.table_name, file):
                        self.ftp_move_csv(
                            ftp_conn, file,
                            company.ftp_on_process_dir,
                            company.ftp_duplicate_dir)
                        logger.info('File %s duplicate, then move to Duplicate Directory' % file)
                        if os.path.isfile(filepath):
                            filepath.unlink()
                    else:
                        self.ftp_push_data_to_middleware(
                            ftp_conn, company.table_name,
                            filename=file,
                            columns=company.columns)

                        logger.info('Process Insert Data to Odoo')
                        self.env.cr.execute("""
                            SELECT process_insert_data_to_odoo('%s');
                        """ % (file))

                        logger.info('Process Update stage')
                        self.env.cr.execute("""
                                SELECT process_update_stage_after_insert('%s')
                            """ % (file))

                        self.env.cr.commit()
                        self.env.cr.execute("""
                            SELECT contract_number
                            FROM aggregation_table
                            WHERE filename = '%s' AND stage = 3
                            GROUP BY contract_number ORDER by contract_number;
                        """ % (file))
                        data_contract = self.env.cr.fetchall()
                        if data_contract:
                            for contract in data_contract:
                                if self.env['leasing.contract'].search([('name', 'in', contract)]).status in ('draft', 'active'):
                                    ctx = {
                                        'source': 'wrapper',
                                        'filename': file,
                                        'contract_number': contract,
                                    }
                                    # self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(ctx).action_reconcile_loan_entries()
                                    # self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(ctx).action_reconcile_payment_entries()
                                    # self.env['leasing.contract'].search([('name', 'in', contract)]).generate_amortization()
                                    self.env['leasing.contract'].search([('name', 'in', contract)]).write({'status': 'active'})
                                    # context = {
                                    #     'termination_date': date.today(),
                                    #     'termination_note': 'Termination From Wrapper'
                                    # }
                                    # self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(context)._action_termination()

                        # try:
                        #     ftp_conn = self.connection_to_ftp()
                        #     self.generate_result_files(file, res_file)
                        #     ftp_conn.cwd('/success/')
                        #     with open('/tmp/' + res_file, "rb") as file:
                        #         ftp_conn.storbinary(f"STOR {res_file}", file)
                        # except Exception as e:
                        #     logger.error(e)
        self.remove_file_not_use(ftp_conn, company)

    def refresh_connection_ftp(self):
        logger.info('Checking connection')
        ftp = self.connection_to_ftp()
        if ftp:
            logger.info('Connected')
            ftp.close()

    # GLOBAL
    def checking_file_receive(self):
        logger.info('Checking File Receive')
        company = self.env.user.company_id
        today = datetime.now().strftime("%Y%m%d")
        if company.ftp_active:
            ftp_conn = self.connection_to_ftp()
            ftp_conn.cwd(company.ftp_home_dir)
            for file in ftp_conn.mlsd(company.ftp_home_dir):
                if file[1].get('type') == 'file' and file[0].endswith(('.csv', '.CSV')):
                    if file[0] == company.filename or file[0][:8] == today:
                        try:
                            ftp_conn.rename(company.ftp_home_dir + file[0], company.ftp_inbound_dir + file[0])
                            self.env.cr.execute("""
                                INSERT INTO logging_integration (name, filename, receive_date, receive_status, create_date, write_date, active)
                                VALUES ('%s', '%s', now(), true, now(), now(), true)
                            """ % ('SUCCESS: File Receive', file[0]))
                        except Exception as e:
                            logger.error(e)
        elif company.sftp_active:
            sftp_conn = self.connection_to_sftp()
            sftp_conn.cwd(company.ftp_home_dir)
            for file in sftp_conn.listdir(company.ftp_home_dir):
                if file.endswith(('.csv', '.CSV')) and file[:8] == today:
                    logger.info(file, today)
                    try:
                        sftp_conn.rename(company.ftp_home_dir + file, company.ftp_inbound_dir + file)
                        self.env.cr.execute("""
                            INSERT INTO logging_integration (name, filename, receive_date, receive_status, create_date, write_date, active)
                            VALUES ('%s', '%s', now(), true, now(), now(), true)
                        """ % ('SUCCESS: File Receive', file))
                    except Exception as e:
                        logger.error(e)

    def remove_file_not_use(self, ftp_conn, company):
        logger.info('Removing File not Use')
        files_directory = os.listdir(company.local_directory)
        filepath = pathlib.Path(company.local_directory)
        logger.info(files_directory)
        if files_directory:
            for file in files_directory:
                pathlib.Path(company.local_directory + file).unlink()
                ftp_conn.rename('/on_process/' + file, '/inbound/' + file)

    def checking_data_available(self, ftp_conn, table_name, filename):
        logger.info('Checking the Files')
        self.env.cr.execute("""
            SELECT filename FROM %s WHERE filename ilike '%s' GROUP BY filename
        """ % (table_name, filename))
        data_available = self.env.cr.fetchall()
        if data_available:
            logger.error('Data with file %s is available' % filename)
            return False
        return True

    def insert_into_mid_table(self, table_name, path_file, columns):
        logger.info('Insert data')
        with open(path_file, 'r') as files:
            lines = files.readlines()
            for line in lines:
                try:
                    self.env.cr.execute("""
                        INSERT INTO %s (%s) values ('%s)
                    """ % (table_name, columns.replace("'", ""), line))
                except Exception as e:
                    logger.error(e)
                    logger.error(line)
            files.close()

    def normalize_data(self, local_path_normalize, filename):
        logger.info('Normalize Data')
        create_date = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        rows = 0

        with open(local_path_normalize + filename, 'r') as file_path,\
                open(local_path_normalize + 'NORMALIZE_' + filename, 'w')\
                as file_normalize:
            lines = file_path.readlines()[1:]
            for line in lines:
                rows += 1
                line = line.replace(',Active,', ',active,')
                line = line.replace(',Yes,Yes,', ',True,True,')
                line = line.replace(',No,No,', ',False,False,')
                line = line.replace(',Yes,No,', ',True,False,')
                line = line.replace(',No,Yes,', ',False,True,')
                line = line.replace("'", '`')
                line = line.replace('"', '')
                line = line.replace(",", "','")
                nline = line.replace('\n', ' ') + "', '" + filename + "', '"\
                    + create_date + "'\n"
                file_normalize.write(nline)
            file_normalize.close()
            file_path.close()
        try:
            self.env.cr.execute("""
                UPDATE logging_integration SET src_number_of_rows = %s WHERE filename = '%s'
            """ % (rows, filename))
        except Exception as e:
            try:
                self.env.cr.execute("""
                    UPDATE logging_integration SET name = %s, description = %s WHERE filename = '%s'
                """ % ('Error: Normalization ' + filename, e, filename))
            except Exception as e:
                logger.error(e)
        return local_path_normalize + 'NORMALIZE_' + filename

    def insert_into_odoo(self, ftp_conn, connection):
        self.env.cr.execute("""
            SELECT process_insert_data_to_odoo()
        """)

    def generate_result_files(self, filename, res_file):
        logger.info('Generate Result Files %s', filename)
        self.env.cr.execute("""
            COPY (
                SELECT
                    CASE
                        WHEN mark_as_done is false then 0
                        WHEN mark_as_done is true and stage = 2 then 1 -- less than lock date
                        WHEN mark_as_done is true and stage = 3 then 2 -- success
                        WHEN mark_as_done is true and stage = 4 then 3 -- master data not found
                        ELSE 5
                    END AS result,
                    pt.order_fee_id, pt.contract_number, pt.loan_purpose,
                    pt.funding_type, pt.branch, pt.mca_number, pt.debtor_id,
                    pt.debtor_name, pt.plat_number, pt.channel,
                    pt.isrestructure, pt.istest, pt.order_id,
                    pt.order_date, pt.start_date,
                    pt.end_date, pt.order_type, pt.sub_order_type,
                    pt.fee_type, pt.account_no,
                    pt.payment_channel, pt.amount, pt.description
                FROM preparation_table pt
                LEFT JOIN aggregation_table at on at.order_fee_id = pt.order_fee_id
                WHERE pt.filename = '%s'
                GROUP by pt.order_fee_id, pt.contract_number, pt.loan_purpose,
                    pt.funding_type, pt.branch, pt.mca_number, pt.debtor_id,
                    pt.debtor_name, pt.plat_number, pt.channel,
                    pt.isrestructure, pt.istest, pt.order_id,
                    pt.order_date, pt.start_date,
                    pt.end_date, pt.order_type, pt.sub_order_type,
                    pt.fee_type, pt.account_no,
                    pt.payment_channel, pt.amount, pt.description, mark_as_done, stage
                ORDER BY pt.order_fee_id
            ) TO '/tmp/%s' DELIMITER ',' CSV HEADER
        """ % (filename, res_file))
        self.env.cr.execute("""
            UPDATE preparation_table SET mark_as_done = True WHERE mark_as_done = False;
        """)

    # SFTP Section
    def connection_to_sftp(self):
        for rec in self.env.user.company_id:
            if rec.sftp_active:
                if not rec.host_ftp:
                    raise ValidationError('Please Fill host name')
                if not rec.username_ftp:
                    raise ValidationError('Please Fill username')
                if not rec.password_ftp:
                    raise ValidationError('Please Fill password')
                try:
                    cnopts = pysftp.CnOpts()
                    cnopts.hostkeys = None
                    if rec.private_selected:
                        sftpConnect = pysftp.Connection(
                            host=rec.host_ftp,
                            username=rec.username_ftp,
                            private_key=rec.private_key,
                            private_key_pass=rec.private_key_pass,
                            port=22,
                            cnopts=cnopts)
                    else:
                        sftpConnect = pysftp.Connection(
                            host=rec.host_ftp,
                            username=rec.username_ftp,
                            password=rec.password_ftp,
                            cnopts=cnopts)
                    logger.info('===============')
                    logger.info('SFTP Connected')
                    return sftpConnect
                except Exception as e:
                    logger.exception(
                        'Connection is wrong for %s' %
                        rec.host_ftp)
                    raise AccessError(e)
            else:
                logger.error('Your SFTP Not Active')

    def sftp_on_process_handler(self, sftp_conn, file):
        company = self.env.user.company_id
        sftp_file = company.ftp_inbound_dir + file
        if sftp_file.endswith(('.csv', '.CSV')):
            sftp_conn.get(sftp_file, company.local_directory + file)
        logger.info('Download Files %s' % file)
        self.sftp_move_csv_on_process(
            sftp_conn, file, company.ftp_inbound_dir,
            target_dir=company.ftp_on_process_dir)

    def sftp_pull_data(self, sftp_conn):
        company = self.env.user.company_id
        datas = sftp_conn.listdir(company.ftp_inbound_dir)
        files = []
        found = False
        for file in datas:
            if file.endswith(('.csv', '.CSV')):
                found = True
                files.append(file)
        if found:
            for file in files:
                self.sftp_on_process_handler(sftp_conn, file)

    def sftp_create_directory_if_not_exists(self, sftp_conn, dir):
        try:
            sftp_conn.cwd(dir)
        except Exception:
            sftp_conn.mkdir(dir)
            sftp_conn.cwd(dir)
        return True

    def sftp_move_csv(self, sftp_conn, filename, origin_path, dest_path,
                      use_timestamp=False):
        origin_file = f'{origin_path}{filename}'
        dest_file = f'{dest_path}{filename}'
        logger.info("Moving file:%s from %s to %s" %
                    (filename, origin_path, dest_path))
        logger.info("Move_csv Renaming:%s-->%s" % (origin_file, dest_file))
        logger.info("===================================")
        sftp_conn.rename(origin_file, dest_file)

    def sftp_move_csv_on_process(self, sftp_conn, filename, origin_path,
                                 target_dir=None, use_timestamp=False):
        company = self.env.user.company_id
        sftp_conn.cwd(company.ftp_home_dir)
        if not target_dir:
            target_dir = company.ftp_on_process_dir
        elif target_dir[:-1] != '/':
            target_dir = target_dir + '/'
        if origin_path[:-1] != '/':
            origin_path += '/'
        logger.info("Move CSV_on_process: Filename: %s, Origin_path:%s" %
                    (filename, origin_path))
        on_process_path = target_dir
        self.sftp_create_directory_if_not_exists(sftp_conn, on_process_path)
        try:
            self.sftp_move_csv(sftp_conn, filename, origin_path, on_process_path,
                               use_timestamp=use_timestamp)
        except Exception as e:
            logger.error('--------------------------------------')
            logger.error('Move to on process failed Put back file %s from %s'
                         ' to %s' % (filename, origin_path, '/anomaly/'))
            logger.error('The file ' + filename + ' is unreadable')
            logger.error('--------------------------------------')
            sftp_conn.rename(origin_path + filename, '/anomaly/' + filename)

    def sftp_move_csv_success(self, sftp_conn, filename, origin_path,
                              target_dir=None, use_timestamp=False):
        company = self.env.user.company_id
        sftp_conn.cwd(company.ftp_home_dir)
        if not target_dir:
            target_dir = company.ftp_success_dir
        elif target_dir[:-1] != '/':
            target_dir = target_dir + '/'
        if origin_path[:-1] != '/':
            origin_path += '/'
        logger.info("Move CSV Success: Filename: %s, Origin_path:%s" %
                    (filename, origin_path))
        success_path = target_dir
        self.sftp_create_directory_if_not_exists(sftp_conn, success_path)
        try:
            self.sftp_move_csv(sftp_conn, filename, origin_path, success_path,
                               use_timestamp=use_timestamp)
        except Exception as e:
            logger.error('--------------------------------------')
            logger.error('Move to success failed Put back file %s from %s'
                         ' to %s' % (filename, origin_path, '/anomaly/'))
            logger.error('The file ' + filename + ' is unreadable')
            logger.error('--------------------------------------')
            sftp_conn.rename(origin_path + filename, '/anomaly/' + filename)

    def sftp_move_csv_anomaly(self, sftp_conn, filename, origin_path,
                              target_dir=None, use_timestamp=False):
        company = self.env.user.company_id
        sftp_conn.cwd(company.ftp_home_dir)
        if not target_dir:
            target_dir = company.ftp_anomaly_dir
        elif target_dir[:-1] != '/':
            target_dir = target_dir + '/'
        if origin_path[:-1] != '/':
            origin_path += '/'
        logger.info("Move CSV Anomaly: Filename: %s, Origin_path:%s" %
                    (filename, origin_path))
        anomaly_path = target_dir
        self.sftp_create_directory_if_not_exists(sftp_conn, anomaly_path)
        self.sftp_move_csv(sftp_conn, filename, origin_path, anomaly_path,
                           use_timestamp=use_timestamp)

    def sftp_push_data_to_middleware(self, sftp_conn, table_name,
                                     filename=False, columns=False):
        company = self.env.user.company_id
        logger.info('Start Push into Middleware')
        success = True
        if not filename:
            raise ValidationError('File not Found')
        new_file = self.normalize_data(company.local_directory, filename)
        filepath = pathlib.Path(company.local_directory + filename)
        nfilepath = pathlib.Path(new_file)

        sftp_conn.close()
        try:
            self.insert_into_mid_table(table_name, new_file, columns)
            self.env.cr.execute("""
                SELECT process_aggregation_data('%s');
            """ % (filename))
        except Exception as e:
            logger.error(e)
            success = False

        sftp_conn = self.connection_to_sftp()
        if success:
            if os.path.isfile(filepath):
                filepath.unlink()
            if os.path.isfile(nfilepath):
                nfilepath.unlink()
            # sftp_conn.remove(company.ftp_on_process_dir + filename)
            self.sftp_move_csv_success(
                sftp_conn, filename, company.ftp_on_process_dir,
                company.ftp_success_dir)
        else:
            if os.path.isfile(filepath):
                filepath.unlink()
            if os.path.isfile(nfilepath):
                nfilepath.unlink()
            self.sftp_move_csv_anomaly(
                sftp_conn, filename, company.ftp_on_process_dir,
                company.ftp_anomaly_dir)
            self.env.cr.execute("""
                INSERT INTO logging_integration (name, filename, description, log_time, error_status, active)
                    VALUES ('%s', '%s', '%s', now(), true, true)
            """ % ('ERROR: File cant process', filename, 'File cant processing'))

    def action_sftp_pull_data(self):
        company = self.env.user.company_id
        sftp_conn = self.connection_to_sftp()
        self.sftp_pull_data(sftp_conn)
        files_directory = os.listdir(company.local_directory)
        today = datetime.now().strftime("%Y%m%d")
        if company.filename in files_directory:
            res_file = 'result-' + company.filename
            filepath = pathlib.Path(company.local_directory + company.filename)
            if not self.checking_data_available(sftp_conn, company.table_name, company.filename):
                self.sftp_move_csv(
                    sftp_conn, company.filename,
                    company.sftp_on_process_dir,
                    company.sftp_duplicate_dir)
                logger.info('File %s duplicate, then move to Duplicate Directory' % company.filename)
                if os.path.isfile(filepath):
                    filepath.unlink()
            else:
                self.sftp_push_data_to_middleware(
                    sftp_conn, company.table_name,
                    filename=company.filename,
                    columns=company.columns)

                logger.info('Process Insert Data to Odoo')
                self.env.cr.execute("""
                    SELECT process_insert_data_to_odoo('%s');
                """ % (company.filename))

                logger.info('Process Update Stage')
                self.env.cr.execute("""
                    SELECT process_update_stage_after_insert('%s')
                """ % (company.filename))
                self.env.cr.commit()

                self.env.cr.execute("""
                    SELECT contract_number
                    FROM aggregation_table
                    WHERE filename = '%s' AND stage = 3
                    GROUP BY contract_number ORDER by contract_number;
                """ % (company.filename))
                data_contract = self.env.cr.fetchall()
                if data_contract:
                    for contract in data_contract:
                        if self.env['leasing.contract'].search([('name', 'in', contract)]).status in ('draft', 'active'):
                            ctx = {
                                'source': 'wrapper',
                                'filename': company.filename,
                                'contract_number': contract,
                            }
                            self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(ctx).action_reconcile_loan_entries()
                            self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(ctx).action_reconcile_payment_entries()
                            # self.env['leasing.contract'].search([('name', 'in', contract)]).generate_amortization()
                            self.env['leasing.contract'].search([('name', 'in', contract)]).write({'status': 'active'})
                            context = {
                                'termination_date': date.today(),
                                'termination_note': 'Termination From Wrapper'
                            }
                            self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(context)._action_termination()
                # try:
                #     sftp_conn = self.connection_to_sftp()
                #     self.generate_result_files(company.filename, res_file)
                #     sftp_conn.cwd(company.ftp_success_dir)
                #     sftp_conn.put('/tmp/' + res_file)
                # except Exception as e:
                #     logger.error(e)
        else:
            for file in files_directory:
                if file[:8] == today\
                        and file.endswith(('.csv', '.CSV')):
                    res_file = 'result-' + file
                    filepath = pathlib.Path(company.local_directory + file)
                    if not self.checking_data_available(sftp_conn, company.table_name, file):
                        self.sftp_move_csv(
                            sftp_conn, file,
                            company.sftp_on_process_dir,
                            company.sftp_duplicate_dir)
                        logger.info('File %s duplicate, then move to Duplicate Directory' % file)
                        if os.path.isfile(filepath):
                            filepath.unlink()
                    else:
                        self.sftp_push_data_to_middleware(
                            sftp_conn, company.table_name,
                            filename=file,
                            columns=company.columns)

                        logger.info('Process Insert Data to Odoo')
                        self.env.cr.execute("""
                            SELECT process_insert_data_to_odoo('%s');
                        """ % (file))

                        logger.info('Process Update Stage')
                        self.env.cr.execute("""
                            SELECT process_update_stage_after_insert('%s')
                        """ % (file))
                        self.env.cr.commit()

                        self.env.cr.execute("""
                            SELECT contract_number
                            FROM aggregation_table
                            WHERE filename = '%s' AND stage = 3
                            GROUP BY contract_number ORDER by contract_number;
                        """ % (file))
                        data_contract = self.env.cr.fetchall()
                        if data_contract:
                            for contract in data_contract:
                                if self.env['leasing.contract'].search([('name', 'in', contract)]).status in ('draft', 'active'):
                                    ctx = {
                                        'source': 'wrapper',
                                        'filename': file,
                                        'contract_number': contract,
                                    }
                                    self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(ctx).action_reconcile_loan_entries()
                                    self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(ctx).action_reconcile_payment_entries()
                                    # self.env['leasing.contract'].search([('name', 'in', contract)]).generate_amortization()
                                    self.env['leasing.contract'].search([('name', 'in', contract)]).write({'status': 'active'})
                                    context = {
                                        'termination_date': date.today(),
                                        'termination_note': 'Termination From Wrapper'
                                    }
                                    self.env['leasing.contract'].search([('name', 'in', contract)]).with_context(context)._action_termination()
                        # try:
                        #     sftp_conn = self.connection_to_sftp()
                        #     self.generate_result_files(file, res_file)
                        #     sftp_conn.cwd(company.ftp_success_dir)
                        #     sftp_conn.put('/tmp/' + res_file)
                        # except Exception as e:
                        #     logger.error(e)
        self.remove_file_not_use(sftp_conn, company)

    def refresh_connection_sftp(self):
        logger.info('Checking connection')
        sftp = self.connection_to_sftp()
        if sftp:
            logger.info('Connected')
            sftp.close()
