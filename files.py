import psycopg2, codecs

conn = psycopg2.connect(
    user='postgres', 
    password='postgres',
    host='localhost',
    port='5432',
    database='usmh_dev'
)
cr = conn.cursor()
output_path = '/opt/master_data/'

# ################  1  ################
# sql_output_item = """COPY (select * from item_master where is_sent_ftp = False) TO STDOUT WITH CSV DELIMITER '\t'"""
# with open(output_path + 'source_file_with_encrypt_16-be.csv', 'w') as f_output:
#     f_output.write('þÿ')
#     cr.copy_expert(sql_output_item, f_output)
            
# ################  2  ################
# with open(output_path + 'source_file_without_encrypt.csv', 'rb') as source_file:
# 	with open(output_path + 'desti_file2.csv', 'w') as dest_file:
# 		dest_file.write('þÿ' + codecs.decode(source_file.read(), encoding='utf-16be', errors='ignore'))

################  3  ################
with open(output_path + 'source_file_without_encrypt.csv', 'r') as source_file:
    with open(output_path + 'desti_file4.csv', 'w', encoding='utf-16-be') as dest_file:
        content = source_file.readlines()
        for line in content:
            dest_file.write('\ufeff')
            dest_file.write(line)
		# dest_file.write(b'\xfe \xff' + codecs.encode(source_file.read(), encoding='utf-16be', errors='ignore'))
