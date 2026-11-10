"""Native foliage palette collisions must not create holes in generated tree art."""
import json
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import hd2d_cards as cards

class TreeCanopyAlpha(unittest.TestCase):
    def test_native_leaf_shading_is_opaque(self):
        tree=cards._tree_template('viridian_forest')[0]
        for point in [(6,34),(7,34),(8,34),(23,10)]:
            self.assertEqual(tree.getpixel(point),(57,148,49,255),point)
        pine=cards._tree_template('kanto_south')[0]
        self.assertEqual(pine.getpixel((5,34)),(57,90,16,255))

    def test_outside_floor_and_neighbor_grass_stay_transparent(self):
        tree=cards._tree_template('viridian_forest')[0]
        for point in [(0,0),(24,0),(0,16),(47,0),(47,63)]:
            self.assertEqual(tree.getpixel(point)[3],0,point)

    def test_restoring_tip_shading_does_not_change_matching_fingerprint(self):
        tree,tip,_,_=cards._tree_template('viridian_forest')
        self.assertEqual(tree.getpixel((23,10))[3],255)
        self.assertNotIn((23,10),{(x,y) for x,y,_ in tip})
        for x,y,color in tip:self.assertEqual(tree.getpixel((x,y)),color)

    def test_all_six_generated_atlases_use_complete_tree_columns(self):
        self.assertEqual(len(cards.TREE_DEFS),6)
        for name in cards.TREE_DEFS:
            with self.subTest(map=name):
                tree,_,width,height=cards._tree_template(name)
                expected={tree.crop((x*16,0,(x+1)*16,height*16)).tobytes() for x in range(width)}
                path=ROOT/'assets/maps'/name
                layout=json.loads((path/'hd2d_cards.json').read_text())
                atlas=Image.open(path/'hd2d_atlas.png').convert('RGBA')
                rects={(c[3],c[4],c[2]) for c in layout['cards'] if len(c)>9 and c[9]==1}
                self.assertEqual(len(rects),width)
                for x,y,h in rects:
                    self.assertEqual(h,height)
                    self.assertIn(atlas.crop((x,y,x+16,y+h*16)).tobytes(),expected)

if __name__=='__main__':unittest.main()
