"""Compare the implemented status templates to the pinned SV text dump."""
import json
import re
import sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]) / 'common'
script = (root / 'scripts/lang.gd').read_text()
records = json.loads((root / 'docs/sv_status_dialog/source-lines.json').read_text())
for lang, suffix in [('ko', 'kor'), ('en', 'eng')]:
    lines = (source / f'common_{suffix}.txt').read_text().splitlines()
    for record in records:
        row = re.search(r'^\t"' + record['key'] + r'": (.+),$', script, re.M).group(1)
        actual = json.loads(row)[lang]
        expected = lines[record['line'] - 1].replace('[VAR 0102(0000)]', '%s').replace('[VAR 1900(0001)]', '{은/는}').replace('\\n', '\n').replace('\\r', '')
        assert actual == expected, (lang, record['key'])
    print(lang, len(records), 'templates match original text and line breaks')
