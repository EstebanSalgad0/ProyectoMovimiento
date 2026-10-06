import sys
from pathlib import Path

DIR_SERVIDOR = Path(__file__).resolve().parents[1]
RAIZ = DIR_SERVIDOR.parent
DIR_FIXTURES = RAIZ / "compartido" / "fixtures"

if str(DIR_SERVIDOR) not in sys.path:
    sys.path.insert(0, str(DIR_SERVIDOR))
