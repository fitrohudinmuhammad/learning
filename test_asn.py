x = 0
encode_path = '/opt/csv_files/EN_OR_HACINQ_20220711.CSV'
with open('/opt/csv_files/OR_HACINQ_20220711.CSV', 'rb') as source_file:
    with open('/opt/csv_files/EN_OR_HACINQ_20220711.CSV', 'w') as dest_file:
        datas = source_file.readlines()[1:]
        while True:
            if x == len(datas):
                break
            temp_line = datas[x].replace(b'\r\n', b',OR_HACINQ_20220711.CSV\n').decode('cp932', errors='replace').split(',')
            temp_line[1] = temp_line[1].strip()

            temp_line[4] = temp_line[4].replace('/','-')
            temp_line[5] = temp_line[5].replace('/','-')
            temp_line[18] = temp_line[18].replace('/','-')
            temp_line[28] = temp_line[28].replace('/','-')
            temp_line[29] = temp_line[29].replace('/','-')

            if not temp_line[3]:
                temp_line[3] = '0'
            if not temp_line[11]:
                temp_line[11] = '0'
            if not temp_line[14]:
                temp_line[14] = '0'
            if not temp_line[15]:
                temp_line[15] = '0'
            if not temp_line[16]:
                temp_line[16] = '0'
            if not temp_line[30]:
                temp_line[30] = '0'
            if not temp_line[32]:
                temp_line[32] = '0'
            if not temp_line[33]:
                temp_line[33] = '0'
            
            data = ','.join(temp_line)
            dest_file.write(data)
            x += 1