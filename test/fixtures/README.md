# Repository test fixtures

These small inputs keep tests independent of the ignored `docs/` and
`third_party/` directories. Game runtime assets remain under `assets/`.

- `seafoam_puzzle_solutions.json`: the existing 31-push solutions for the
  four Seafoam boards, copied unchanged from the local review input.
  Regenerate with `python3 tools/seafoam_puzzle_solutions.py`; the tool also
  writes the local review copy under `docs/seafoam_puzzle/`.
- `frlg_cut_tree_objects.json`: all 49 Cut tree object records from 21
  [pret/pokefirered](https://github.com/pret/pokefirered) map JSON files in the
  local source snapshot. Each entry records the original source path and
  SHA-256 of that complete source file. The regression test compares these
  original object coordinates against `assets/data/field_cut_trees.json`.
  Retain the original source attribution and asset usage conditions.
