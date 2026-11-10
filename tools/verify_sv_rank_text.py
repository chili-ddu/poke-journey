"""Compare rank templates with a checkout of Pokemon-Project-com/sv-text."""
import json
import re
import sys
from pathlib import Path

project = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
s = (project / 'scripts/lang.gd').read_text()
keys = ['stat_rose', 'stat_sharp_rose', 'stat_drastic_rose', 'stat_fell', 'stat_sharp_fell', 'stat_drastic_fell', 'stat_wont_up', 'stat_wont_down']
for lang, filename, labels, prefixes in [
    ('ko', 'kor', ['공격', '방어', '특수공격', '특수방어', '스피드', '명중률', '회피율'], ['', '야생 ', '상대 ']),
    ('en', 'eng', ['Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed', 'accuracy', 'evasiveness'], ['', 'The wild ', 'The opposing ']),
]:
    def normalize(line):
        line = line.replace('[VAR 0102(0000)]', 'NAME').replace('[VAR BD06(0000)]', '')
        line = line.replace('\\n', '\n').replace('\\r', '')
        return ' '.join(line.split()) if lang == 'en' else line
    lines = {normalize(line) for line in (source / 'common' / f'common_{filename}.txt').read_text().splitlines()}
    count = 0
    for key in keys:
        row = re.search(r'"' + key + r'": \{([^\n]+)', s).group(1)
        template = json.loads(re.search('"' + lang + r'": ("(?:[^"\\]|\\.)*")', row).group(1))
        for prefix in prefixes:
            for label in labels:
                subject = prefix + 'NAME' + ('의\n' if lang == 'ko' else '’s ') + label
                text = template % subject
                if lang == 'ko':
                    final = (ord(label[-1]) - 0xac00) % 28 != 0
                    text = text.replace('{이/가}', '이' if final else '가').replace('{은/는}', '은' if final else '는')
                assert normalize(text) in lines, (lang, key, text)
                count += 1
    print(lang, count, 'matched; English layout/control tags normalized' if lang == 'en' else 'matched including line breaks')
