# import codecs, psycopg2, pysftp, logging, pathlib
# from distutils.log import error

# source_file = open('/home/fitrohudin/ftp_server/local/inforex/BASICA/BASICA.dat', 'rb')
# datas = source_file.readlines()
# # print (datas)
# print ('---------------------------------\n')
# for data in datas:
#     print (data.replace(b'\n',b'').decode('shift_jis'))
#     print ('=================================\n')

#     break
    # print (data.replace(b'\n',b'').decode('cp932', errors='replace').replace('ﾂ',''))
    # print ('?????????????????????????????????\n')
# print (b'\xc2\x82P'.decode('cp932'))

from tomlkit import integer


path_file = '/opt/inforex/BASICA_20220615/LINK.dat'
normalize_path = '/opt/master_data/LINK.CSV'
x = 0
with open(path_file,"rb") as BasicaFiles:
    with open(normalize_path, 'w') as NormalizeFile:
        while True:
            data = BasicaFiles.readline()
            if not data:
                break

#             # check_1 = data[:13] + b'\x2C' + data[13:26] + b'\x2C' + data[26:35] + b'\x2C' + data[35:36] + b'\x2C' +\
#             #     data[36:86] + b'\x2C' + data[86:136] + b'\x2C' + data[136:164] + b'\x2C' + data[164:192] + b'\x2C' +\
#             #     data[192:207] + b'\x2C' + data[207:227] + b'\x2C' + data[227:267] + b'\x2C' + data[267:273] + b'\x2C' +\
#             #     data[273:285] + b'\x2C' + data[285:292] + b'\x2C' +\
#             #     data[292:299] + b'\x2C' + data[299:306] + b'\x2C' + data[306:314] + b'\x2C' + data[314:320] + b'\x2C' +\
#             #     data[320:322] + b'\x2C' + data[322:324] + b'\x2C' + data[324:326] + b'\x2C' + data[326:328] + b'\x2C' +\
#             #     data[328:336] + b'\x2C' + data[336:340] + b'\x2C' + data[340:348] + b'\x2C' + data[348:352] + b'\x2C' +\
#             #     data[352:360] + b'\x2C' + data[360:368] + b'\x2C' + data[368:376] + b'\x2C' + data[376:377] + b'\x2C' +\
#             #     data[377:385] + b'\x2C' + data[385:388] + b'\x2C' + data[388:393] + b'\x2C' + data[393:397] + b'\x2C' +\
#             #     data[397:401] + b'\x2C' + data[401:405] + b'\x2C' + data[405:409] + b'\x2C' + data[409:415] + b'\x2C' +\
#             #     data[415:423] + b'\x2C' + data[423:425] + b'\x2C' + data[425:427] + b'\x2C' + data[427:428] + b'\x2C' +\
#             #     data[428:432] + b'\x2C' + data[432:436] + b'\x2C' + data[436:437] + b'\x2C' + data[437:438] + b'\x2C' +\
#             #     data[438:439] + b'\x2C' + data[439:442] + b'\x2C' + data[442:482] + b'\x2C' + data[482:483] + b'\x2C' +\
#             #     data[483:487] + b'\x2C' + data[487:493] + b'\x2C' + data[493:496] + b'\x2C' + data[496:498] + b'\x2C' +\
#             #     data[498:500] + b'\x2C' + data[500:501] + b'\x2C' + data[501:504] + b'\x2C' + data[504:507] + b'\x2C' +\
#             #     data[507:509] + b'\x2C' + data[509:549] + b'\x2C' + data[549:551] + b'\x2C' + data[551:553] + b'\x2C' +\
#             #     data[553:573] + b'\x2C' + data[573:575] + b'\x2C' + data[575:595] + b'\x2C' + data[595:597] + b'\x2C' +\
#             #     data[597:599] + b'\x2C' + data[599:601] + b'\x2C' + data[601:651] + b'\x2C' + data[651:654] + b'\x2C' +\
#             #     data[654:655] + b'\x2C' + data[655:656] + b'\x2C' + data[656:669] + b'\x2C' + data[669:682] + b'\x2C' +\
#             #     data[682:684] + b'\x2C' + data[684:697] + b'\x2C' + data[697:706] + b'\x2C' + data[706:713] + b'\x2C' +\
#             #     data[713:714] + b'\x2C' + data[714:715] + b'\x2C' + data[715:717] + b'\x2C' + data[717:718] + b'\x2C' +\
#             #     data[718:732] + b'\x2C' + data[732:746] + b'\x2C' + data[746:760] + b'\x2C' + data[760:774] + b'\x2C' +\
#             #     data[774:894] + b'\x2C' + data[894:934] + b'\x2C' + data[934:1114] + b'\x2C' + data[1114:2114] + b'\x2C' +\
#             #     data[2114:2294] + b'\x2C' + data[2294:2474] + b'\x2C' + data[2474:2478] + b'\x2C' + data[2478:2480] + b'\x2C' +\
#             #     data[2480:2780] + b'\x2C' + data[2780:3780] + b'\x2C' + data[3780:3830] + b'\x2C' +\
#             #     data[6830:6832] + b'\x2C' + data[6832:6847] + b'\x2C' + data[6847:6850] + b'\x2C' + data[6850:6857] + b'\x2C' +\
#             #     data[6857:6864] + b'\x2C' + data[6864:6865] + b'\x2C' + data[6865:7065] + b'\x2C' + data[7065:7165] + b'\x2C' +\
#             #     data[7165:7365] + b'\x2C' + data[7365:7373] + b'\x2C' + data[7373:7375] + b'\x2C' + data[7375:7377] + b'\x2C' +\
#             #     data[7377:7379] + b'\x2C' + data[7379:7381] + b'\x2C' + data[7381:7389] + b'\x2C' + data[7389:7396] + b'\x2C' +\
#             #     data[7396:7404] + b'\x2C' + data[7404:7411] + b'\x2C' + data[7411:7419] + b'\x2C' + data[7419:7426] + b'\x2C' +\
#             #     data[7426:7434] + b'\x2C' + data[7434:7442] + b'\x2C' + data[7442:7449] + b'\x2C' + data[7449:7457] + b'\x2C' +\
#             #     data[7457:7464] + b'\x2C' + data[7464:]

            check_1 = data[:13] + b'\x2C' + data[13:26] + b'\x2C' + data[26:35] + b'\x2C' + data[35:51] + b'\x2C' +\
                    data[51:55] + b'\x2C' + data[55:59] + b'\x2C' + data[59:61] + b'\x2C' + data[61:62] + b'\x2C' +\
                    data[62:64] + b'\x2C' + data[64:68] + b'\x2C' + data[68:69] + b'\x2C' + data[69:76] + b'\x2C' +\
                    data[76:77] + b'\x2C' + data[77:90] + b'\x2C' + data[90:103] + b'\x2C' + data[103:116] + b'\x2C' +\
                    data[116:122] + b'\x2C' + data[122:129] + b'\x2C' + data[129:133] + b'\x2C' + data[133:137] + b'\x2C' +\
                    data[137:141] + b'\x2C' + data[141:143] + b'\x2C' + data[143:149] + b'\x2C' + data[149:156] + b'\x2C' +\
                    data[156:160] + b'\x2C' + data[160:164] + b'\x2C' + data[164:168] + b'\x2C' + data[168:172] + b'\x2C' +\
                    data[172:176] + b'\x2C' + data[176:177] + b'\x2C' + data[177:179] + b'\x2C' + data[179:194] + b'\x2C' +\
                    data[194:197] + b'\x2C' + data[197:212] + b'\x2C' + data[212:220] + b'\x2C' + data[220:222] + b'\x2C' +\
                    data[222:224] + b'\x2C' + data[224:232] + b'\x2C' + data[232:238] + b'\x2C' + data[239:247] + b'\x2C' +\
                    data[247:253] + b'\x2C' + data[254:262] + b'\x2C' + data[262:269] + b'\x2C' + data[269:277] + b'\x2C' +\
                    data[277:285] + b'\x2C' + data[285:291] + b'\x2C' + data[292:300] + b'\x2C' + data[300:306] + b'\x2C' +\
                    data[307:308] + b'\x2C' + data[308:309] + b'\x2C' + data[309:310] + b'\x2C' + data[310:311] + b'\x2C' +\
                    data[311:312] + b'\x2C' + data[312:313] + b'\x2C' + data[313:314] + b'\x2C' + data[314:315] + b'\x2C' +\
                    data[315:316] + b'\x2C' + data[316:317] + b'\x2C' + data[317:]
            NormalizeFile.write(check_1.decode('shift_jis', errors='replace'))
            x += 1

with open(normalize_path, 'r') as NormalizeFile:
    with open('/opt/master_data/norm_link.csv', 'w') as destFile:
         while True:
            data = NormalizeFile.readline()
            if not data:
                break

            temp_line = data.split(',')
            if not temp_line[11].isnumeric():
                temp_line[11] = '0000000'
            temp_line[38] = temp_line[38][:6]
            temp_line[40] = temp_line[40][:6]
            temp_line[45] = temp_line[45][:6]
            temp_line[47] = temp_line[47][:6]
            data = ','.join(temp_line)
            destFile.write(data)