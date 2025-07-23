import ftplib

FTP = ftplib.FTP(host='localhost')
FTP.login(user='avas', passwd='keamanan')

data = FTP.mlsd('/on_process')
for file in data:
    print (file)
    if file[1].get('size') == '0':
        print (file[0])

FTP.close()
print (FTP)