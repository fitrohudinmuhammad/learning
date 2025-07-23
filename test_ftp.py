import ftplib
import psycopg2

url = 'localhost'
username = 'avas'
password = 'keamanan'
local_path_file = '/opt/inforex/example.csv'
ftp_path_file = '/anomaly/example.csv'
columns = "order_fee_id, contract_number, status, loan_purpose, funding_type, branch, debtor_name, plat_number, channel, isrestructure, istest, order_id,  order_date, start_date, end_date, order_type, sub_order_type, fee_type, account_no, payment_channel, manual_pay, amount, description, filename, create_date"

ftp = ftplib.FTP(url)
ftp.login(username, password)

conn = psycopg2.connect(
            user='postgres',
            password='postgres',
            database='lintegration',
            host='localhost',
            port='5432')
cr = conn.cursor()
cr.execute("""copy (select %s from preparation_table where filename = '%s') to '/tmp/%s' delimiter ',' csv header""" % (columns, "20231023-1140.csv", "result-20231023-1140.csv"))

ftp.cwd('/success/')
with open('/tmp/result-20231023-1140.csv', "rb") as file:
    # use FTP's STOR command to upload the file
    ftp.storbinary(f"STOR {'result-20231023-1140.csv'}", file)

ftp.close()