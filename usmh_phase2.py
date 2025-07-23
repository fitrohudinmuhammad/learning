async def import_data_dat(self):
        local_dir = '/opt/m2_pos_files'
        local_csv_dir = '/opt/m2_csv_files/'
        path_file = None
        columns = [
            "tenant_classification", "comma_1", "cash_register_no", "comma_2", "transaction_series_no", "comma_3", 
            "transaction_date_start", "comma_4", "transaction_time_start", "comma_5", "regimai_identification",
            "comma_6", "return_identification", "comma_7", "division_code", "comma_8", "store_code", "comma_9",
            "date_of_the_day_of_the_cis_tube", "comma_10", "sales_amount_main_price", "comma_11", "quantity",
            "comma_12", "decimal_point", "comma_13", "registration_details_identification", "comma_14",
            "product_registration_operation_detailed_identification", "comma_15", "product_code_valid_number",
            "comma_16", "product_code", "comma_17", "gift_identification", "comma_18", "query_code_class", "comma_19", 
            "inquiry_code_department", "comma_20", "inquiry_code_single_item", "comma_21", "mission_sea_os_flag", 
            "comma_22", "sale_flag", "comma_23", "bundle_type", "comma_24", "time_sale_flag", "comma_25", "bundle_no", 
            "comma_26", "number_of_sets_1", "comma_27", "set_price_1", "comma_28", "number_of_establishments_1", 
            "comma_29", "discount_amount_1", "comma_30", "number_of_sets_2", "comma_31", "set_price_2", "comma_32", 
            "number_of_establishments_2", "comma_33", "discount_amount_2", "comma_34", "number_of_sets_3", "comma_35", 
            "set_price_3", "comma_36", "number_of_establishments_3", "comma_37", "discount_amount_3", "comma_38", 
            "with_or_without_discount_1", "comma_39", "with_or_without_discount_2", "comma_40", "stocon", "comma_41",
            "single_item_discount_1", "comma_42", "product_group_discount_1", "comma_43", "bundle",  "comma_44",
            "single_item_discount_2", "comma_45", "product_group_discount_2", "comma_46", "otome", "comma_47", "subtotal_discount_1", 
            "comma_48", "subtotal_discount_2", "comma_49", "usage_unit_price", "comma_50", "plan_no", "comma_51", "current_selling_price", 
            "comma_52", "business_day", "comma_53", "div", "comma_54", "omc_preferential_treatment_flag", "comma_55", 
            "tax_type_selling_price", "comma_56", "tax_rate", "comma_57", "store_food_and_drink_flag", "line_feed_code",
            "stage", "file_name", "create_date", "time", "code_upc2", "code_41", "code_upc1", "code_33", "class_code", "already_process_calculate", "unique_key"
        ] 
        
        files = os.listdir(local_dir)

        for file in files:
            if not os.path.isdir(file) and file.endswith('.dat'):
                os.rename(local_dir + '/' + file, local_csv_dir + file)
                extract_file = pathlib.Path(local_csv_dir + 'extract_' + file)
                with gzip.open(local_csv_dir + file, 'rb') as f_in:
                    with open(extract_file, 'wb') as f_out:
                        shutil.copyfileobj(f_in, f_out)

                path_file = pathlib.Path(local_csv_dir + file)
                local_path_normalize = pathlib.Path(local_csv_dir +'NORMALIZE_' + file)
                try:
                    self.normalize_data(local_path_normalize, extract_file)
                    extract_file.unlink()
                    # path_file.unlink()
                except Exception as e:
                    raise FileException(("The file " + file + " is unreadable : " + str(e)))

                try:
                    print ('Start Push Data')
                    with open(local_path_normalize, 'r') as f:
                        await self.push_data('maruetsu_pos_sales', f,
                                            csv_table=True,
                                            columns=columns)
                        f.close()
                except Exception as e:
                    raise FileException(("The file " + file + " cant insert to db : " + str(e)))
                
                await self.calculate_and_get_product()
    
    def normalize_data(self, local_path_normalize, path):
        print ('Normalize Data')
        tic = time.perf_counter()
        times = self.get_time_from_file(str(path)[26:33])
        create_date = datetime.now(tz=tz_tokyo).strftime('%Y-%m-%d %H:%M:%S')

        with open(path, 'rb') as file_path, open(local_path_normalize, 'w') as file_encod:
            lines = file_path.readlines()
            number_of_rows = 1
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
                new_line = new_line.decode('shift_jisx0213').replace('\n','') + ',7,'+ str(path)[26:53] +','+create_date+','+times

                product_code_replace = new_line[112:125].replace(' ','')
                product_code_zfill = product_code_replace.zfill(13)
                val_upce_to_upca = self.convert_UPCE_to_UPCA(product_code_zfill[-6:])

                code_41 = new_line[149:162][-7:]
                code_upc1 = '0' + product_code_zfill
                code_33 = product_code_zfill[-7:]

                query_code_class_replace = new_line[132:139].replace(' ','')
                query_code_class_zfill = query_code_class_replace.zfill(4) + '000'
                class_code = query_code_class_zfill.zfill(7)

                unique_key = str(path)[26:53] + str(number_of_rows)

                if new_line[:4] == '0000' and new_line[98:100] == '10':
                    file_encod.write(new_line + ',' + val_upce_to_upca + ',' + code_41 + ',' + code_upc1 + ',' + code_33 + ',' + class_code + ',t,' + unique_key + '\n')
                else:
                    file_encod.write(new_line + ',,,,,,f,' + unique_key + '\n')
                
                number_of_rows += 1
                    
            file_path.close()
            file_encod.close()
        toc = time.perf_counter()
        print(f"Normalize Data in {toc - tic:0.4f} seconds")
        print ('Normalize is Done')
    
    def get_time_from_file(self, filename):
        if filename == 'GUT009P':
            result = '060000'
        elif filename == 'GUT010P':
            result = '070000'
        elif filename == 'GUT011P':
            result = '080000'
        elif filename == 'GUT012P':
            result = '090000'
        elif filename == 'GUT013P':
            result = '100000'
        elif filename == 'GUT014P':
            result = '110000'
        elif filename == 'GUT015P':
            result = '120000'
        elif filename == 'GUT016P':
            result = '130000'
        elif filename == 'GUT017P':
            result = '140000'
        elif filename == 'GUT018P':
            result = '150000'
        elif filename == 'GUT019P':
            result = '160000'
        elif filename == 'GUT020P':
            result = '170000'
        elif filename == 'GUT021P':
            result = '180000'
        elif filename == 'GUT022P':
            result = '190000'
        elif filename == 'GUT023P':
            result = '200000'
        elif filename == 'GUT024P':
            result = '210000'
        elif filename == 'GUT025P':
            result = '220000'
        elif filename == 'GUT026P':
            result = '230000'
        elif filename == 'GUT027P':
            result = '240000'
        elif filename == 'GUT028P':
            result = '010000'
        elif filename == 'GUT029P':
            result = '020000'
        elif filename == 'GUT030P':
            result = '030000'
        else:
            result = '240000'
        return result

    # ================================================================
# FUNCTION UPCE TO UPCA
# ================================================================
    def calc_check_digit(self, value):
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

    def convert_UPCE_to_UPCA(self, upce_value): # YANG DI PANGGIL DAN KASI PARAMETER
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
        check_digit=self.calc_check_digit(newmsg)

        return newmsg+str(check_digit)


    async def push_data(self, table_name, path_file, csv_table=False, columns=False):
        config = setting.config()
        conn = await asyncpg.connect(
                user=config['MIDDLEWARE_DB']['username'],
                password=config['MIDDLEWARE_DB']['passwd'],
                database=config['MIDDLEWARE_DB']['database'],
                host=config['MIDDLEWARE_DB']['url'],
                port=config['MIDDLEWARE_DB']['port'])

        await conn.copy_to_table(table_name,
                                     source=path_file.name,
                                     format='csv',
                                     columns=columns,
                                     null="NULL")

        await conn.close()

    async def calculate_and_get_product(self):
        config = setting.config()
        try:
            conn = await asyncpg.connect(
                user=config['MIDDLEWARE_DB']['username'],
                password=config['MIDDLEWARE_DB']['passwd'],
                database=config['MIDDLEWARE_DB']['database'],
                host=config['MIDDLEWARE_DB']['url'],
                port=config['MIDDLEWARE_DB']['port'])

            print ('Start Calculation')
            tic = time.perf_counter()
            await conn.execute("SELECT pos_calculation_columns()")
            toc = time.perf_counter()
            print ('End Calculation')
            print (f"Calculation in {toc - tic:0.4f} seconds")

            await conn.close()
        except Exception as e:
            logger.warning(e)
            raise FileException(("The file cant calculate: " + str(e)))

        try:
            conn = await asyncpg.connect(
                user=config['MIDDLEWARE_DB']['username'],
                password=config['MIDDLEWARE_DB']['passwd'],
                database=config['MIDDLEWARE_DB']['database'],
                host=config['MIDDLEWARE_DB']['url'],
                port=config['MIDDLEWARE_DB']['port'])

            print ('Start Get Product')
            tic = time.perf_counter()
            await conn.execute("SELECT pos_get_product_code_logic()")
            toc = time.perf_counter()
            print ('End Get Product')
            print (f"Get Product in {toc - tic:0.4f} seconds")
            
            await conn.close()
        except Exception as e:
            logger.warning(e)
            raise FileException(("The file cant calculate: " + str(e)))