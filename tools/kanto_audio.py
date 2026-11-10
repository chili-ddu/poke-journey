"""Complete missing audio for Kanto species/moves without overwriting existing audio."""
import json,re
from pathlib import Path
import plat_sfx as sfx
import plat_fetch
from concurrent.futures import ThreadPoolExecutor
MOVES=['splash','hypnosis','peck','pound','astonish','wrap','fury_swipes','absorb','mega_drain','acid','disarming_voice','sing','supersonic']
def main():
 with ThreadPoolExecutor(max_workers=8) as pool:
  list(pool.map(lambda move:plat_fetch.fetch("res/moves/"+("hyper_voice" if move=="disarming_voice" else move)+"/anim.s",False),MOVES))
 path=sfx.ROOT/'tools/plat_move_se.json';table=json.loads(path.read_text())
 for move in MOVES:
  source='hyper_voice' if move=='disarming_voice' else move
  script=sfx.ROOT/'third_party/pokeplatinum/res/moves'/source/'anim.s'
  assert script.exists(),script
  table[move]=list(dict.fromkeys(re.findall(r'\b(SEQ_[A-Z0-9_]+)_sseq(?:_\d+)?\b',script.read_text())))
  # The cached SDAT labels this shared Teleport/Transform sound DP_W100;
  # the current decomp animation script refers to the PL_W100 symbol.
  if move=='transform' and 'SEQ_SE_PL_W100' in table[move]:table[move].append('SEQ_SE_DP_W100')
 path.write_text(json.dumps(table,ensure_ascii=False,indent=1)+'\n')
 sd=sfx.pm.Sdat(sfx.pm.SDAT);sequences=sfx.move_ses(sd)
 for move in MOVES:
  target=sfx.SE_DIR/f'mv_{move}.wav'
  if target.exists() or move=="disarming_voice":continue
  assert move in sequences,move
  assert sfx.render_se(sd,sequences[move],target),move
 sfx.cries(sd,missing_only=True)
 print('Kanto missing audio completed; existing audio preserved. Disarming Voice uses the species cry, following the Hyper Voice voice-effect pattern.')
if __name__=='__main__':main()
