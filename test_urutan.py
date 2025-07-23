list = ['GUT509P-20220628000010.dat', 'GUT514P-20220629000020.dat', 'GUT516P-20220628000001.dat']
res = []
x = 0
while True:
    if x == len(list):
        break
    # print (list[x])
    if list[x][:7] in ('GUT514P', 'GUT516P', 'GUT518P'):
        res.append('LF'+list[x])
    elif list[x][:7] in ('GUT515P', 'GUT517P', 'GUT519P'):
        res.append('LS'+list[x])
    elif list[x][:7] in ('GUT502P', 'GUT505P', 'GUT508P', 'GUT511P'):
        res.append('NF'+list[x])
    elif list[x][:7] in ('GUT503P', 'GUT506P', 'GUT509P', 'GUT5i12P'):
        res.append('NS'+list[x])
    elif list[x][:7] in ('GUT504P', 'GUT507P', 'GUT510P', 'GUT513P'):
        res.append('NT'+list[x])
    # print (res)
    x += 1

print (res)
print (sorted(res))
rr = []
for r in sorted(res):
    rr.append(r[2:])
print (rr)

# for r in res:
#     print (r[2:9])


# list = ['123456_1.jpg','123456_2.jpg','123456_3.jpg','333333_1.jpg', '444444_1.jpg', '444444_2.jpg']

# while True:
#     if x == len(list):
#         break
#     rest = list[x].split('_')[1].split('.')
#     # print (rest[0], rest[1])
#     if rest[0] == '3':
#         print (list[x])
#     x += 1