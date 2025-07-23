
class TranslateWebsite(http.Controller):
    @http.route('/translate', type='http')
    def get_data_html_text(self):
        odoo_version = service.common.exp_version()['server_version'][:2]
        print (odoo_version)
        if odoo_version == '15':
            request.env.cr.execute("""
                SELECT it.id, irv.name, it.lang, it.state, it.src, it.value
                FROM ir_ui_view irv
                JOIN ir_translation it ON it.res_id = irv.id
                WHERE irv.type = 'qweb' 
                    AND irv.key ilike '%web%'
                    AND it.src not ilike '%<%'
                    AND it.state = 'to_translate'
                    AND it.lang != 'en_US'
            """)
            datas = request.env.cr.fetchall()
            print (datas)
            for html in datas:
                prompt = """Translate the following 'English' text to 'Indonesian', 'Japanese', 'French', 'Spanish', 'Vietnamese', and 'Czech': '{}'
                            return it into a JSON without any additional sentence""".format(html[4])

                try:
                    response = openai.ChatCompletion.create(
                        model="gpt-3.5-turbo",
                        messages=[
                            {"role": "system", "content": "You are a helpful assistant that translates text."},
                            {"role": "user", "content": prompt}
                        ],
                        max_tokens=200,
                        n=1,
                        stop=None,
                        temperature=0.5,
                    )
                    result = response.choices[0].message.content.strip()
                    print (result)

                    data_json = json.loads(result)
                    if data_json.get('Indonesian') == 'None' or data_json.get('Japanese') == 'None':
                        print ('NONE')
                        break
                    
                    request.env.cr.execute("""
                        UPDATE ir_translation SET value = '%s', state = 'translated' WHERE id = %s and lang = 'id_ID'
                    """ % (data_json.get('Indonesian'), html[0]))
                    request.env.cr.execute("""
                        UPDATE ir_translation SET value = '%s', state = 'translated' WHERE id = %s and lang = 'ja_JP'
                    """ % (data_json.get('Japanese'), html[0]))
                except Exception:
                    continue
        elif odoo_version == '16':
            request.env.cr.execute("""
                SELECT id, arch_db->>'en_US' FROM ir_ui_view WHERE key ilike '%web%'
            """)
            datas = request.env.cr.fetchall()
            # print (datas)
            for html in datas:
                soup = BeautifulSoup(html[1], 'html.parser')
                paragraphs = [element for element in soup.find_all(string=True) if element.strip() != '']
                print (paragraphs)
                # for val in paragraphs:
                #     if not val.string.isnumeric():
                #         response = openai.Completion.create(
                #             model="text-davinci-003",
                #             prompt="""Please translate this sentence '{}' to Bahasa without any additional sentence""".format(val),
                #             temperature=0.6,
                #             max_tokens=450
                #         )
                #         nn = response['choices'][0]['text'].replace(' \n',',').replace('\n','').replace('  ','')
                #         val.string.replace_with(nn)
                # print (soup.prettify())
                # request.env.cr.execute("""
                #     UPDATE ir_ui_view SET arch_db = jsonb_set(arch_db, '{id_ID}', '{"id_ID": "%s"}', false) WHERE id = %s
                # """ % (soup.prettify().replace("'","").replace('"',"'"), html[0]))
                # tinggal update query
