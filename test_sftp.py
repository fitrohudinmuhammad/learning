import pysftp, ftplib
files = []
cnopts = pysftp.CnOpts()
cnopts.hostkeys = None
# with pysftp.Connection(host='aeonorange.dev.portcities.cc', username='pciuser', password='DpqvyIJv', port=22, cnopts=cnopts) as sftp:
with pysftp.Connection(host='127.0.0.1', username='mfit_avas', password='keamanan', port=None, cnopts=cnopts) as sftp:
# with pysftp.Connection(host='18.179.249.177', username='usmh', private_key='/opt/inforex/usmh.sftp.key', private_key_pass='Uds!wMph', port=22, cnopts=cnopts) as sftp:
    # print (sftp.listdir())
    # with sftp.cd('/tmp/ec_files'):
    #     sftp.put('/home/fitrohudin/ftp_server/local/ec/new_issue/00500_00077_0133_00000000000025.zip')
    #     sftp.put('/home/fitrohudin/ftp_server/local/ec/new_issue/00500_00077_0133_00000000000026.zip')
    #     sftp.put('/home/fitrohudin/ftp_server/local/ec/new_issue/00500_00077_0133_00000000000027.zip')
    #     sftp.put('/home/fitrohudin/ftp_server/local/ec/new_issue/00500_00077_0133_00000000000029.zip')
    #     sftp.put('/home/fitrohudin/ftp_server/local/ec/new_issue/00500_00077_0133_00000000000030.zip')
    #     sftp.put('/home/fitrohudin/ftp_server/local/ec/new_issue/00500_00077_0133_00000000000032.zip')
    #     sftp.put('/home/fitrohudin/ftp_server/local/ec/new_issue/00500_00077_0133_00000000000033.zip')
    #     sftp.put('/home/fitrohudin/ftp_server/local/ec/new_issue/00500_00077_0133_00000000000034.zip')
    #     sftp.put('/home/fitrohudin/ftp_server/local/ec/new_issue/00500_00077_0133_00000000000035.zip')
    #     sftp.put('/home/fitrohudin/ftp_server/local/ec/new_issue/00500_00077_0133_00000000000036.zip')
    # sftp.mkdir('ec_files')
    # print (sftp.getcwd())
    # sftp.put('/home/fitrohudin/ftp_server/local/ec/00100_09287_0191_00000000002380.zip')
    # print (sftp.listdir())
    # sftp.remove('/tmp/ec_files/500_0_20220421131550.zip')
    # for file in sftp.listdir_attr():
    #     print (file)
    sftp.cwd('/tmp/ec_files')
    print (sftp.listdir())
    sftp.close()

# y=0
# with open('/opt/master_data/squen.csv','w') as dest_files:
#     while True:
#         if y == 10000:
#             break
#         dest_files.write('DROP TABLE IF EXISTS maruetsu_low_temp_summary_on_process_'+ str(y).zfill(4) +';\n')
#         y += 1