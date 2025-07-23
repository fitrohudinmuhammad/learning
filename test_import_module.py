import importlib, os, sys
from pathlib import Path

HOME_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, os.path.abspath(str(HOME_DIR) + '/usmh_middleware/andrew'))

i = importlib.import_module("usmh-middleware")
print (sys.path, i)