import zipfile, shutil, os, pathlib


folder = '/opt/csv_files'

file_paths = []

# crawling through directory and subdirectories
for root, directories, files in os.walk(folder):
    for filename in files:
        # join the two strings in order to form the full filepath.
        filepath = os.path.join(root, filename)
        file_paths.append(filepath)

# with zipfile.ZipFile('/opt/file.zip', 'w') as zip:
#     for file in file_paths:
#         zip.write(file)

# shutil.make_archive('/opt/csv', 'zip', folder)
print (os.geteuid(), os.getgid())