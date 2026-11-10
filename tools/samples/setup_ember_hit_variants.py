from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]


def main():
    round=int(sys.argv[1]);folder=ROOT.parent/'pixelfx/src/fx/local-review';folder.mkdir(exist_ok=True)
    for style in (['wrap','sweep','low'] if round==1 else ['wrap','sweep']):
        for layer in ['front','back']:
            id=f'ember-hit-r{round}-{style}-{layer}'
            (folder/f'{id}.js').write_text(f"// Temporary ember hit adapter.\nimport {{makeHit}} from '{(ROOT/'tools/samples/ember_hit_variants.mjs').as_uri()}';\nconst s=makeHit('{style}','{layer}',{round});export const meta=s.meta;export const draw=s.draw;\n")
            print('local-review/'+id)


if __name__=='__main__':main()
