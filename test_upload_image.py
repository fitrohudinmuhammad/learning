# import os, ftplib

# ftp = ftplib.FTP('usmh-fm.prod.apcod.jp', 'inforex_admin', 'm2L(Xb,rb+7zC6kP')
# # usmh-fm.prod.apcod.jp
# # inforex_admin
# # m2L(Xb,rb+7zC6kP
# path_files = '/opt/inforex/GK_20220614'
# # ftp.cwd('images')
# for file in os.listdir(path_files):
#     print (file)
#     if file[:3] in ftp.nlst('/images'):
#         filepath = path_files + '/' + file
#         with open(filepath, 'rb') as files:
#             ftp.storbinary(f"STOR /images/{file[:3]}/{file}", files)
#     else:
#         ftp.mkd('/images/' + file[:3])
#         filepath = path_files + '/' + file
#         with open(filepath, 'rb') as files:
#             ftp.storbinary(f"STOR /images/{file[:3]}/{file}", files)
import psycopg2


x = 0
with open('/opt/inforex/IMAGELIST.csv', 'r') as image_list:
    with open('/opt/inforex/dest_IMAGELIST.csv', 'w') as dest_image_list:
        while True:
            image = image_list.readline()
            if not image:
                break
            data = image.split(',')
            conn = psycopg2.connect(
                user='postgres',
                password='postgres',
                database='usmh_dev',
                host='localhost',
                port='5432'
            )
            cr = conn.cursor()
            cr.execute("""SELECT kyotu_hincd FROM link WHERE kyotu_hincd = '""" + data [0] + """' and makerpbcd = '""" + data[1] + """' and makercd = '""" + data[2] + """'""")
            res = cr.fetchall()
            print (res)
            if res:
                print (data[0], data[1], data[2])
                print (res)
            x+=1