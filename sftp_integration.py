import pysftp, ftplib
files = []
cnopts = pysftp.CnOpts()
cnopts.hostkeys = None

with pysftp.Connection(host='127.0.0.1', username='mfit_avas', password='keamanan', cnopts=cnopts) as sftp:
    sftp.cwd('/')
    print (sftp.listdir())
    sftp.close()