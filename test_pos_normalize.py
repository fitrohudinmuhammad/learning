from datetime import datetime
import pytz
tz_tokyo = pytz.timezone('Asia/Tokyo')

create_date = datetime.now(tz=tz_tokyo).strftime('%Y-%m-%d %H:%M:%S')
times = ''
transaction_datetime = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
with open('/tmp/gut001p.dat','rb') as source_file:
    with open('/tmp/norm_gut001p.csv', 'w') as dest_file:
        lines = source_file.readlines()
        for line in lines:
            dest_file.write(line.decode('shift_jisx0213', errors='replace').replace('\n','') + ',,' + str('filename_GUT') + ',' + create_date + ',' + times + ',' + transaction_datetime + ',,,,,,f\n')