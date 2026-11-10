from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]


def main():
    round=int(sys.argv[1]);folder=ROOT.parent/'pixelfx/src/fx/local-review';folder.mkdir(exist_ok=True)
    variants='abc' if round==1 else 'bc'
    for variant in variants:
        for kind in ['flight','coat']:
            id=f'ember-study-r{round}-{variant}-{kind}'
            text=(f'// Temporary ember study adapter.\n'
                  f"import {{makeEmberStudy}} from '{(ROOT/'tools/samples/ember_pixelfx_studies.mjs').as_uri()}';\n"
                  f"const s=makeEmberStudy('{variant}','{kind}',{round});export const meta=s.meta;export const draw=s.draw;\n")
            (folder/f'{id}.js').write_text(text);print('local-review/'+id)


if __name__=='__main__':main()
