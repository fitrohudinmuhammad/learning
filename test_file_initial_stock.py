# inventory_date | store_code | product_code | quantity | cost_price
import gzip, shutil
from pathlib import Path

directory = '/opt/master_data/'
raw_file = '.DAT'
extract_file = 'ekstrak.csv'

with gzip.open(directory + raw_file, 'rb') as f_in:
    with open(directory + extract_file, 'wb') as f_out:
        shutil.copyfileobj(f_in, f_out)

path_file = Path(directory + extract_file)
normalize_path = Path('Normalize_' + directory + extract_file)

with open(path_file,"rb") as source_file:
    with open(normalize_path, 'w') as dest_file:
        while True:
            data = source_file.readline()
            if not data:
                break

            line = data.decode('cp932', errors='replace').replace('\n','').split(',')
            line[1] = line[1].zfill(4)
            line[2] = line[2].zfill(7)

            data = ','.join(line)
            # print (line)
            # raise Exception()
            dest_file.write(data + '\n')
