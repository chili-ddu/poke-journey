"""Verify growth wording after substituting SV variables and inflection controls."""
import json
import re
import sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
script = (root / 'scripts/lang.gd').read_text()
for lang, suffix in [('ko', 'kor'), ('en', 'eng')]:
    lines = (Path(sys.argv[1]) / 'common' / f'common_{suffix}.txt').read_text().splitlines()
    for key, line in [('learned',6977), ('grew',8610), ('exp_gained',8585), ('exp_gained_one',8585)]:
        expected = lines[line-1]
        replacements = {'[VAR 010C(0000)]':'%s', '[VAR 0102(0000)]':'%s', '[VAR 0107(0001)]':'%s', '[VAR 1900(0001)]':'{은/는}', '[VAR 1900(0002)]':'{을/를}', '[VAR 0202(0001)]':'%d', '[VAR 1900(0005)]로':'{으로/로}', '[VAR 0206(0001,0000)]':'%d', '[VAR 0206(0001,002C)]':'%d', '[VAR 1101(0001,0100)]s': '' if key.endswith('_one') else 's', '\\n':'\n'}
        for before, after in replacements.items(): expected = expected.replace(before, after)
        actual = json.loads(re.search(r'^\t"'+key+r'": (.+),$',script,re.M).group(1))[lang]
        assert actual == expected, (lang,key,actual,expected)
    print(lang, '4 growth templates match (number grouping control normalized)')
