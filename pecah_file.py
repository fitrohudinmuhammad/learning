
directory  = '/home/fitrohudin/Downloads/MLD/file_csv/cofi_files - cofi_files.csv.csv'

with open(directory, 'r') as files:
    lines = files.readlines()

num_output_files = (len(lines))
print (num_output_files)
line_chunks = [lines[i:i + 5000] for i in range(0, len(lines), 10000)]
# print (line_chunks)

for i, chunk in enumerate(line_chunks):
    output_filename = f"{'/tmp/c20231231'}_{i + 1}.csv"
    with open(output_filename, 'w') as output_file:
        output_file.writelines(chunk)
