import pytz
from pathlib import Path
import cProfile, pstats, io
from pstats import SortKey
from functools import wraps

import time
from reader import feed

from datetime import datetime
tz_tokyo = pytz.timezone('Asia/Tokyo')

def main():
    tic = time.perf_counter()
    normalize_data()
    toc = time.perf_counter()
    print(f"Downloaded the tutorial in {toc - tic:0.4f} seconds")

def profile(func):
    def wrapper(*args, **kwargs):
        pr = cProfile.Profile()
        pr.enable()
        retval = func(*args, **kwargs)
        pr.disable()
        s = io.StringIO()
        sortby = SortKey.CUMULATIVE  # 'cumulative'
        ps = pstats.Stats(pr, stream=s).sort_stats(sortby)
        ps.print_stats()
        print(s.getvalue())
        return retval

    return wrapper

# @profile
def normalize_data():
    local_path_normalize = '/opt/csv_files/NORMALIZE_GUT015P-20210801123000.dat'
    path = '/opt/csv_files/GUT015P-20210801123000.dat'
    time = get_time_from_file()
    create_date = datetime.now(tz=tz_tokyo).strftime('%Y-%m-%d %H:%M:%S')
    
    with open(path, 'rb') as file_path, open(local_path_normalize, 'w') as file_encod:
        lines = file_path.readlines()
        for line in lines:
            line = line.replace(b',', b' ')
            line = line.replace(b'\x00', b' ')
            line = line.replace(b'\x8f', b'')

            new_line = line[0:4] + b'\x2C' + line[4:5] + b'\x2C' + line[5:9] + b'\x2C' + line[9:10] + b'\x2C' + line[10:14] + b'\x2C' + line[14:15] + b'\x2C' + \
                        line[15:23] + b'\x2C' + line[23:24] + b'\x2C' + line[24:30] + b'\x2C' + line[30:31] + b'\x2C' + line[31:32] + b'\x2C' + line[32:33] + b'\x2C' + \
                        line[33:34] + b'\x2C' + line[34:35] + b'\x2C' + line[35:39] + b'\x2C' + line[39:40] + b'\x2C' + line[40:44] + b'\x2C' + line[44:45] + b'\x2C' + \
                        line[45:53] + b'\x2C' + line[53:54] + b'\x2C' + line[54:63] + b'\x2C' + line[63:64] + b'\x2C' + line[64:69] + b'\x2C' + line[69:70] + b'\x2C' + \
                        line[70:71] + b'\x2C' + line[71:72] + b'\x2C' + line[72:74] + b'\x2C' + line[74:75] + b'\x2C' + line[75:77] + b'\x2C' + line[77:78] + b'\x2C' + \
                        line[78:79] + b'\x2C' + line[79:80] + b'\x2C' + line[80:93] + b'\x2C' + line[93:94] + b'\x2C' + line[94:95] + b'\x2C' + line[95:96] + b'\x2C' + \
                        line[96:103] + b'\x2C' + line[103:104] + b'\x2C' + line[104:108] + b'\x2C' + line[108:109] + b'\x2C' + line[109:122] + b'\x2C' + line[122:123] + b'\x2C' + \
                        line[123:124] + b'\x2C' + line[124:125] + b'\x2C' + line[125:126] + b'\x2C' + line[126:127] + b'\x2C' + line[127:129] + b'\x2C' + line[129:130] + b'\x2C' + \
                        line[130:131] + b'\x2C' + line[131:132] + b'\x2C' + line[132:136] + b'\x2C' + line[136:137] + b'\x2C' + line[137:141] + b'\x2C' + line[141:142] + b'\x2C' + \
                        line[142:149] + b'\x2C' + line[149:150] + b'\x2C' + line[150:154] + b'\x2C' + line[154:155] + b'\x2C' + line[155:164] + b'\x2C' + line[164:165] + b'\x2C' + \
                        line[165:169] + b'\x2C' + line[169:170] + b'\x2C' + line[170:177] + b'\x2C' + line[177:178] + b'\x2C' + line[178:182] + b'\x2C' + line[182:183] + b'\x2C' + \
                        line[183:192] + b'\x2C' + line[192:193] + b'\x2C' + line[193:197] + b'\x2C' + line[197:198] + b'\x2C' + line[198:205] + b'\x2C' + line[205:206] + b'\x2C' + \
                        line[206:210] + b'\x2C' + line[210:211] + b'\x2C' + line[211:220] + b'\x2C' + line[220:221] + b'\x2C' + line[221:222] + b'\x2C' + line[222:223] + b'\x2C' + \
                        line[223:224] + b'\x2C' + line[224:225] + b'\x2C' + line[225:235] + b'\x2C' + line[235:236] + b'\x2C' + line[236:246] + b'\x2C' + line[246:247] + b'\x2C' + \
                        line[247:257] + b'\x2C' + line[257:258] + b'\x2C' + line[258:268] + b'\x2C' + line[268:269] + b'\x2C' + line[269:279] + b'\x2C' + line[279:280] + b'\x2C' + \
                        line[280:290] + b'\x2C' + line[290:291] + b'\x2C' + line[291:301] + b'\x2C' + line[301:302] + b'\x2C' + line[302:312] + b'\x2C' + line[312:313] + b'\x2C' + \
                        line[313:323] + b'\x2C' + line[323:324] + b'\x2C' + line[324:325] + b'\x2C' + line[325:326] + b'\x2C' + line[326:346] + b'\x2C' + line[346:347] + b'\x2C' + \
                        line[347:356] + b'\x2C' + line[356:357] + b'\x2C' + line[357:365] + b'\x2C' + line[365:366] + b'\x2C' + line[366:370] + b'\x2C' + line[370:371] + b'\x2C' + \
                        line[371:372] + b'\x2C' + line[372:373] + b'\x2C' + line[373:375] + b'\x2C' + line[375:376] + b'\x2C' + line[376:378] + b'\x2C' + line[378:379] + b'\x2C' + \
                        line[379:380] + b'\x2C' + line[380:381]
            new_line = new_line.decode('shift_jisx0213').replace('\n','') + ','+ str(path)[23:50] +','+create_date+','+time

            product_code_replace = new_line[112:125].replace(' ','')
            product_code_zfill = product_code_replace.zfill(13)
            val_upce_to_upca = convert_UPCE_to_UPCA(product_code_zfill[-6:])

            code_41 = new_line[149:162][-7:]
            code_upc1 = '0' + product_code_zfill
            code_33 = product_code_zfill[-7:]

            query_code_class_replace = new_line[132:139].replace(' ','')
            query_code_class_zfill = query_code_class_replace.zfill(4) + '000'
            class_code = query_code_class_zfill.zfill(7)

            if new_line[:4] == '0000' and new_line[98:100] == '10':
                file_encod.write(new_line + ',' + val_upce_to_upca + ',' + code_41 + ',' + code_upc1 + ',' + code_33 + ',' + class_code + ',t\n')
            else:
                file_encod.write(new_line + ',,,,,,f\n')
                
        file_path.close()
        file_encod.close()

def get_time_from_file():
    for file in Path('/opt/csv_files/').iterdir():
        files = str(file)[-26:]
        if files[:-19] == 'GUT009P':
            result = '060000'
            break
        elif files[:-19] == 'GUT010P':
            result = '070000'
            break
        elif files[:-19] == 'GUT011P':
            result = '080000'
            break
        elif files[:-19] == 'GUT012P':
            result = '090000'
            break
        elif files[:-19] == 'GUT013P':
            result = '100000'
            break
        elif files[:-19] == 'GUT014P':
            result = '110000'
            break
        elif files[:-19] == 'GUT015P':
            result = '120000'
            break
        elif files[:-19] == 'GUT016P':
            result = '130000'
            break
        elif files[:-19] == 'GUT017P':
            result = '140000'
            break
        elif files[:-19] == 'GUT018P':
            result = '150000'
            break
        elif files[:-19] == 'GUT019P':
            result = '160000'
            break
        elif files[:-19] == 'GUT020P':
            result = '170000'
            break
        elif files[:-19] == 'GUT021P':
            result = '180000'
            break
        elif files[:-19] == 'GUT022P':
            result = '190000'
            break
        elif files[:-19] == 'GUT023P':
            result = '200000'
            break
        elif files[:-19] == 'GUT024P':
            result = '210000'
            break
        elif files[:-19] == 'GUT025P':
            result = '220000'
            break
        elif files[:-19] == 'GUT026P':
            result = '230000'
            break
        elif files[:-19] == 'GUT027P':
            result = '240000'
            break
        elif files[:-19] == 'GUT028P':
            result = '010000'
            break
        elif files[:-19] == 'GUT029P':
            result = '020000'
            break
        elif files[:-19] == 'GUT030P':
            result = '030000'
            break
        else:
            result = '240000'
    return result

def calc_check_digit(value):
    check_digit=0
    odd_pos=True
    for char in str(value)[::-1]:
        if odd_pos:
            check_digit+=int(char)*3
        else:
            check_digit+=int(char)
        odd_pos=not odd_pos
    check_digit=check_digit % 10
    check_digit=10-check_digit
    check_digit=check_digit % 10
    return check_digit

def convert_UPCE_to_UPCA(upce_value): # YANG DI PANGGIL DAN KASI PARAMETER
    middle_digits = ''
    mfrnum = ''
    itemnum = ''
    if len(upce_value)==6:
        middle_digits=upce_value
    elif len(upce_value)==7:
        middle_digits=upce_value[:6]
    elif len(upce_value)==8:
        middle_digits=upce_value[1:7]
    else:
        return False

    d1,d2,d3,d4,d5,d6=list(middle_digits)
    if d6 in ["0","1","2"]:
        mfrnum=d1+d2+d6+"00"
        itemnum="00"+d3+d4+d5
    elif d6=="3":
        mfrnum=d1+d2+d3+"00"
        itemnum="000"+d4+d5                
    elif d6=="4":
        mfrnum=d1+d2+d3+d4+"0"
        itemnum="0000"+d5        
    else:
        mfrnum=d1+d2+d3+d4+d5
        itemnum="0000"+d6

    newmsg="0"+mfrnum+itemnum
    check_digit=calc_check_digit(newmsg)

    return newmsg+str(check_digit)

if __name__ == "__main__":
    # cProfile.run('main()')
    main()