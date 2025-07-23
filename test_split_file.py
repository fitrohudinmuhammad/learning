import os

path_file = '/opt/inforex/BASICA_20220615/BASICA.dat'
encode_file_path = '/opt/master_data/encode_BASICA.CSV'
normalize_path = '/opt/master_data/500line.CSV'
x = 0 
y = 0
z = 250000
xy = 0
# + data[3830:6830] + b'\x2C'
# + data[1114:2114] + b'\x2C'

# with open(path_file,"rb") as BasicaFile:
#     while True:
#         line = BasicaFile.readline()
#         if not line:
#             break
#         xy += 1
#     print (xy)
#     xy += 1
#     while y <= xy:
#         print ('------------------',z,xy)
#         with open(path_file,"rb") as BasicaFiles:
#             with open('/opt/master_data/new_' + str(z) + '_files.CSV', 'w') as NormalizeFile:
#                 print (x,z)
#                 for data in BasicaFiles.readlines()[x:z]:
#                     lines = data[:13] + b'\x2C' + data[13:26] + b'\x2C' + data[26:35] + b'\x2C' + data[35:36] + b'\x2C' +\
#                         data[36:86] + b'\x2C' + data[86:136] + b'\x2C' + data[136:164] + b'\x2C' + data[164:192] + b'\x2C' +\
#                         data[192:207] + b'\x2C' + data[207:227] + b'\x2C' + data[227:267] + b'\x2C' + data[267:273] + b'\x2C' +\
#                         data[273:285] + b'\x2C' + data[285:286] + b'\x2C' + data[286:287] + b'\x2C' + data[287:288] + b'\x2C' +\
#                         data[288:289] + b'\x2C' + data[289:290] + b'\x2C' + data[290:291] + b'\x2C' + data[291:292] + b'\x2C' +\
#                         data[292:299] + b'\x2C' + data[299:306] + b'\x2C' + data[306:314] + b'\x2C' + data[314:320] + b'\x2C' +\
#                         data[320:322] + b'\x2C' + data[322:324] + b'\x2C' + data[324:326] + b'\x2C' + data[326:328] + b'\x2C' +\
#                         data[328:336] + b'\x2C' + data[336:340] + b'\x2C' + data[340:348] + b'\x2C' + data[348:352] + b'\x2C' +\
#                         data[352:360] + b'\x2C' + data[360:368] + b'\x2C' + data[368:376] + b'\x2C' + data[376:377] + b'\x2C' +\
#                         data[377:385] + b'\x2C' + data[385:388] + b'\x2C' + data[388:389] + b'\x2C' + data[389:390] + b'\x2C' +\
#                         data[390:391] + b'\x2C' + data[391:392] + b'\x2C' + data[392:393] + b'\x2C' + data[393:397] + b'\x2C' +\
#                         data[397:401] + b'\x2C' + data[401:405] + b'\x2C' + data[405:409] + b'\x2C' + data[409:415] + b'\x2C' +\
#                         data[415:423] + b'\x2C' + data[423:425] + b'\x2C' + data[425:427] + b'\x2C' + data[427:428] + b'\x2C' +\
#                         data[428:432] + b'\x2C' + data[432:436] + b'\x2C' + data[436:437] + b'\x2C' + data[437:438] + b'\x2C' +\
#                         data[438:439] + b'\x2C' + data[439:442] + b'\x2C' + data[442:482] + b'\x2C' + data[482:483] + b'\x2C' +\
#                         data[483:487] + b'\x2C' + data[487:493] + b'\x2C' + data[493:496] + b'\x2C' + data[496:498] + b'\x2C' +\
#                         data[498:500] + b'\x2C' + data[500:501] + b'\x2C' + data[501:504] + b'\x2C' + data[504:507] + b'\x2C' +\
#                         data[507:509] + b'\x2C' + data[509:549] + b'\x2C' + data[549:551] + b'\x2C' + data[551:553] + b'\x2C' +\
#                         data[553:573] + b'\x2C' + data[573:575] + b'\x2C' + data[575:595] + b'\x2C' + data[595:597] + b'\x2C' +\
#                         data[597:599] + b'\x2C' + data[599:601] + b'\x2C' + data[601:651] + b'\x2C' + data[651:654] + b'\x2C' +\
#                         data[654:655] + b'\x2C' + data[655:656] + b'\x2C' + data[656:669] + b'\x2C' + data[669:682] + b'\x2C' +\
#                         data[682:684] + b'\x2C' + data[684:685] + b'\x2C' + data[685:686] + b'\x2C' + data[686:687] + b'\x2C' +\
#                         data[687:688] + b'\x2C' + data[688:689] + b'\x2C' + data[689:690] + b'\x2C' + data[690:691] + b'\x2C' +\
#                         data[691:692] + b'\x2C' + data[692:693] + b'\x2C' + data[693:694] + b'\x2C' + data[694:695] + b'\x2C' +\
#                         data[695:696] + b'\x2C' + data[696:697] + b'\x2C' + data[697:706] + b'\x2C' + data[706:713] + b'\x2C' +\
#                         data[713:714] + b'\x2C' + data[714:715] + b'\x2C' + data[715:717] + b'\x2C' + data[717:718] + b'\x2C' +\
#                         data[718:732] + b'\x2C' + data[732:746] + b'\x2C' + data[746:760] + b'\x2C' + data[760:774] + b'\x2C' +\
#                         data[774:894] + b'\x2C' + data[894:934] + b'\x2C' + data[934:1114] + b'\x2C'  +\
#                         data[2114:2294] + b'\x2C' + data[2294:2474] + b'\x2C' + data[2474:2478] + b'\x2C' + data[2478:2480] + b'\x2C' +\
#                         data[2480:2780] + b'\x2C' + data[2780:3780] + b'\x2C' + data[3780:3830] + b'\x2C' +\
#                         data[6830:6832] + b'\x2C' + data[6832:6847] + b'\x2C' + data[6847:6850] + b'\x2C' + data[6850:6857] + b'\x2C' +\
#                         data[6857:6864] + b'\x2C' + data[6864:6865] + b'\x2C' + data[6865:7065] + b'\x2C' + data[7065:7165] + b'\x2C'
#                     lines = lines + data[7165:7365] + b'\x2C' + data[7365:7373] + b'\x2C' + data[7373:7375] + b'\x2C' + data[7375:7377] + b'\x2C' +\
#                         data[7377:7379] + b'\x2C' + data[7379:7381] + b'\x2C' + data[7381:7389] + b'\x2C' + data[7389:7396] + b'\x2C' +\
#                         data[7396:7404] + b'\x2C' + data[7404:7411] + b'\x2C' + data[7411:7419] + b'\x2C' + data[7419:7426] + b'\x2C' +\
#                         data[7426:7434] + b'\x2C' + data[7434:7442] + b'\x2C' + data[7442:7449] + b'\x2C' + data[7449:7457] + b'\x2C' +\
#                         data[7457:7464] + b'\x2C' + data[7464:7465] + b'\x2C' + data[7465:7466] + b'\x2C' + data[7466:7467] + b'\x2C' +\
#                         data[7467:7468] + b'\x2C' + data[7468:7469] + b'\x2C' + data[7469:7470] + b'\x2C' + data[7470:7471] + b'\x2C' +\
#                         data[7471:7472] + b'\x2C' + data[7472:7473] + b'\x2C' + data[7473:7474] + b'\x2C' + data[7474:]
#                     NormalizeFile.write(lines.decode('shift_jis', errors='replace'))
#                 # x += 1
#         if z > xy:
#             break
#         x = z + 1
#         z += 250001
#         y+=1

listdir = os.listdir('/opt/master_data/new_files')
for file in listdir:
    with open('/opt/master_data/new_files/' + file,"r") as EncodeFile:
        with open('/opt/master_data/ready_files/' + file, 'w') as NormalizeFile:
            while True:
                data = EncodeFile.readline()
                if not data:
                    break
                temp_line = data.split(',')
                temp_line[133] = temp_line[133][:6]
                temp_line[135] = temp_line[135][:6]
                temp_line[140] = temp_line[140][:6]
                temp_line[142] = temp_line[142][:6]
                # temp_line[3] = temp_line[3].replace('1','3')

                if temp_line[86] == ' ':
                    temp_line[86] = 'f'
                if temp_line[87] == ' ':
                    temp_line[87] = 'f'
                if temp_line[88] == ' ':
                    temp_line[88] = 'f'
                if temp_line[89] == ' ':
                    temp_line[89] = 'f'
                if temp_line[90] == ' ':
                    temp_line[90] = 'f'
                if temp_line[91] == ' ':
                    temp_line[91] = 'f'
                if temp_line[92] == ' ':
                    temp_line[92] = 'f'
                if temp_line[93] == ' ':
                    temp_line[93] = 'f'
                if temp_line[94] == ' ':
                    temp_line[94] = 'f'
                if temp_line[95] == ' ':
                    temp_line[95] = 'f'
                if temp_line[96] == ' ':
                    temp_line[96] = 'f'
                if temp_line[97] == ' ':
                    temp_line[97] = 'f'

                if temp_line[22] == '        ':
                    temp_line[22] = ''
                if temp_line[28] == '        ':
                    temp_line[28] = ''
                if temp_line[30] == '        ':
                    temp_line[30] = ''
                if temp_line[32] == '        ':
                    temp_line[32] = ''
                if temp_line[33] == '        ':
                    temp_line[33] = ''
                if temp_line[34] == '        ':
                    temp_line[34] = ''
                if temp_line[132] == '        ':
                    temp_line[132] = ''
                if temp_line[134] == '        ':
                    temp_line[134] = ''
                if temp_line[139] == '        ':
                    temp_line[139] = ''
                if temp_line[141] == '        ':
                    temp_line[141] = ''

                if temp_line[35] == ' ':
                    temp_line[35] = ''
                if temp_line[38] == ' ':
                    temp_line[38] = ''
                if temp_line[39] == ' ':
                    temp_line[39] = ''
                if temp_line[65] == ' ':
                    temp_line[65] = ''

                if temp_line[24] == '  ':
                    temp_line[24] = ''
                if temp_line[25] == '  ':
                    temp_line[25] = ''
                if temp_line[26] == '  ':
                    temp_line[26] = ''
                if temp_line[27] == '  ':
                    temp_line[27] = ''
                if temp_line[49] == '  ':
                    temp_line[49] = ''
                if temp_line[71] == '  ':
                    temp_line[71] = ''
                if temp_line[115] == '  ':
                    temp_line[115] = ''

                if temp_line[29] == '    ':
                    temp_line[29] = ''
                elif temp_line[29] == 'A   ':
                    temp_line[29] = ''
                elif temp_line[29] == 'B   ':
                    temp_line[29] = ''
                elif temp_line[29] == 'C   ':
                    temp_line[29] = ''
                if temp_line[31] == '    ':
                    temp_line[31] = ''
                elif temp_line[31] == 'A   ':
                    temp_line[31] = ''
                elif temp_line[31] == 'B   ':
                    temp_line[31] = ''
                elif temp_line[31] == 'C   ':
                    temp_line[31] = ''
                if temp_line[60] == '    ':
                    temp_line[60] = ''

                
                if temp_line[113] == '0000':
                    temp_line[113] = ''
                
                data = ','.join(temp_line)
                NormalizeFile.write(data)


with open('/opt/inforex/check_list.csv',"rb") as BasicaFile:
    x = 1
    last_line = None
    line = BasicaFile.readlines()
    print (line[2:5])