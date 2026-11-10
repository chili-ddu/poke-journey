"""Install local review adapters in sibling checkout for its actual CLI tools."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
LIB=ROOT.parent/'pixelfx'


def main():
    stage=int(sys.argv[1]);folder=LIB/'src/fx/local-review';folder.mkdir(exist_ok=True)
    items=[(f'charmander-source-r1-{v}',1,v,'idle') for v in 'abc'] if stage==1 else [
        (f'charmander-source-r{stage}',stage,'b','idle')]
    if stage==3:
        items.extend([('charmander-source-r3-walk',3,'b','walk'),
            ('charmander-source-r3-original-idle',3,'original','idle'),
            ('charmander-source-r3-original-walk',3,'original','walk')])
    for name,s,v,action in items:
        text=(f"// Local supplied-art review; not an upstream pixelfx effect.\n"
              f"import {{makeStudy}} from '{(ROOT/'tools/samples/charmander_skill_study.mjs').as_uri()}';\n"
              f"const study=makeStudy({s},'{v}','{action}');\n"
              'export const meta=study.meta;\nexport const draw=study.draw;\n')
        (folder/f'{name}.js').write_text(text)
    print('\n'.join('local-review/'+n for n,*_ in items))


if __name__=='__main__':main()
