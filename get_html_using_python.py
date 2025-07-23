import requests
from bs4 import BeautifulSoup
import openai
import json

html = """
    <t name='Homepage' t-name='website.homepage'>
        <t t-call='website.layout'>
            <t t-set='pageName' t-value=''homepage''/>
            <div id='wrap' class='oe_structure oe_empty'>
                <section class='s_cover parallax s_parallax_is_fixed bg-black-50 pt96 pb96' data-scroll-background-ratio='1' data-snippet='s_cover'>
                    <span class='s_parallax_bg oe_img_bg' style='background-image: url('/web/image/website.s_cover_default_image'); background-position: 50% 0;'/>
                    <div class='o_we_bg_filter bg-black-50'/>
                    <div class='container s_allow_columns'>
                        <p class='lead' style='text-align: center;'>Tell what's the value for the <br/>customer for this feature</p>
                        <p class='lead' style='text-align: center;'>Tell what's the value for the <br/>customer for this feature</p>
                        <p class='lead' style='text-align: center;'>Tell what's the value for the <br/>customer for this feature</p>
                    </div>
                </section>
            </div>
        </t>
    </t>
"""

openai.api_key = "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"


soup = BeautifulSoup(html, 'html.parser')
# soup.prettify()
print (soup.get_text().strip())
print (soup.find_all(string=True))

paragrap = [element for element in soup.find_all(string=True) if element.strip() != '']
nparagrap = [element for element in soup.get_text().strip()]
print (paragrap)
print (nparagrap)
print ('==============')
paragraph = []
# for para in paragrap:
#     # print (type(para)
#     if not para.string.isnumeric():
#         # response = openai.Completion.create(
#         #     model="text-davinci-003",
#         #     prompt="""Please translate this sentence '{}' to Indonesian, Japanese, Spanish then put the result into json without any additional sentence""".format(para.replace('&nbsp;',' ')),
#         #     max_tokens=150
#         # )
#         prompt = """Translate the following 'English' text to 'Indonesian', 'Japanese', 'French', 'Spanish', 'Vietnamese', and 'Czech': "{}"
#                     then put the result into a JSON without any additional sentence""".format(para.replace("'","''"))
#         response = openai.ChatCompletion.create(
#             model="gpt-3.5-turbo",
#             messages=[
#                 {"role": "system", "content": "You are a helpful assistant that translates text."},
#                 {"role": "user", "content": prompt}
#             ],
#             max_tokens=200,
#             n=1,
#             stop=None,
#             temperature=0.5,
#         )
#         translation = response.choices[0].message.content.strip()
#         print (translation)
#         # print (json.loads(translation))
#         # with open('/opt/csv_files/hasil_chatGPT.txt', 'w') as file_chatgpt:
#         #     file_chatgpt.write(json.loads(translation) + '\n')
#         #     file_chatgpt.close()
#         # nn = response['choices'][0]['text'].replace(' \n',',').replace('\n','').replace('  ','')
#         # print (nn)
#         # # nn = "{,'Indonesian': 'Judul yang Menonjol',,'Japanese': 'キャッチ　ヘッドライン',,'Spanish': 'Encabezado llamativo'}".replace(",'","'").replace("'",'"')
#         # result = json.loads(nn)
#         # print (result.get('Japanese'))

        
# print(paragrap)
# #     # new = json.loads(nn)
# #     if not val.isnumeric():
# #         print (val, '==>', nn)
#         soup.find(string=val).replace_with(nn)
#         print ('================\n')
# print(soup.prettify())
# target = BeautifulSoup("sss", "xml")
# soup.find(text="Ini Judul").replace_with("target")
# print (soup)

# Find all the 'a' tags in the HTML
# links = []
# h2 = soup.find('h2')
# font = soup.find('h1')
# links.append(h2)
# links.append(font)

# # Print the links
# for link in links:
#     for val in link:
#         print ('-------------------')
#         print (val)
# print ('-------------------')


# response = openai.Completion.create(
#     model="text-davinci-003",
#     prompt=f"please translate 'selamat datang' to english, france, germany and put the result into json without any additional sentence",
#     temperature=0.6,
#     max_tokens=150
# )
# # print ("please translate 'selamat datang' to english, france, germany and put the results in json and without any additional sentence,")
# # jsons = []
# # # print (jsons.append(response['choices'][0]['text'].replace(' \n',',').replace('\n','')))
# # jsons.append(response['choices'][0]['text'].replace(' \n',',').replace('\n','').replace('  ','').replace('"',"'"))
# # print (jsons)
# nn = response['choices'][0]['text'].replace(' \n',',').replace('\n','').replace('  ','')
# print (nn)
# new = json.loads(nn)
# print (new.get('English'))
# # print (response["choices"][0]["text"].split(','))
# # print (len(response["choices"][0]["text"]))