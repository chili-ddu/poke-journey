"""Native lawn/path placement must survive the conversion into 3D terrain."""
import json
from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from terrain_ground import pixels, surface_palette, restore_tree_floor, tile
from north_terrain import source_cells
from terrain_topology import CITIES, topology


class TerrainGround(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.maps = {}
        for name in ['kanto_field','kanto_east']:
            directory = ROOT/'assets/maps'/name
            j = json.loads((directory/'map.json').read_text())
            raw = Image.open(directory/'bottom.png').convert('RGBA')
            floor = Image.open(directory/'elevation_floor.png').convert('RGBA')
            cards = json.loads((directory/'hd2d_cards.json').read_text())
            mids = source_cells(j,[CITIES.get(a['id'],a['id'].replace('route','Route')) for a in j['areas']])
            source_ground = [tile(raw,xy,j['pad']) for xy in mids if j['solid'][xy[1]][xy[0]]=='0' and j['grass'][xy[1]][xy[0]]=='0' and j['ledge'][xy[1]][xy[0]]=='0']
            palette = surface_palette(source_ground)
            lawn_palette = set().union(*(set(pixels(tile(raw,xy,j['pad']))) for xy,mid in mids.items() if mid in (8,9,0xd9) and j['solid'][xy[1]][xy[0]]=='0' and j['ledge'][xy[1]][xy[0]]=='0'))
            trees = {(int(c[0]),int(c[1])+y) for c in cards['cards'] if len(c)>9 and c[9]==1 for y in range(int(c[2]))}
            ledges,turns,_ = topology(j)
            cls.maps[name] = (j,raw,floor,palette,lawn_palette,trees,set(ledges)|turns)

    def test_every_solid_tree_has_lawn_underneath_instead_of_copied_road_or_props(self):
        for name,(j,raw,floor,palette,lawn,trees,banks) in self.maps.items():
            bad = []
            for x,y in trees:
                if 0<=x<j['width'] and 0<=y<j['height'] and j['solid'][y][x]=='1' and j['ledge'][y][x]=='0':
                    if not set(pixels(tile(floor,(x,y),j['pad']))) <= lawn:
                        bad.append((x,y))
            self.assertEqual(bad,[],name)

    def test_walkable_ground_under_canopies_keeps_its_native_position(self):
        for name,(j,raw,floor,palette,lawn,trees,banks) in self.maps.items():
            bad = []
            for x,y in trees:
                if not (0<=x<j['width'] and 0<=y<j['height']):continue
                if j['solid'][y][x]!='0' or j['grass'][y][x]!='0' or j['ledge'][y][x]!='0':continue
                native = tile(raw,(x,y),j['pad'])
                if set(pixels(native)) <= palette and native.tobytes()!=tile(floor,(x,y),j['pad']).tobytes():bad.append((x,y))
            self.assertEqual(bad,[],name)

    def test_every_bank_preserves_original_ground_pixels_at_the_exact_pixel_coordinates(self):
        for name,(j,raw,floor,palette,lawn,trees,banks) in self.maps.items():
            for xy in sorted(banks):
                native = tile(raw,xy,j['pad'])
                actual = tile(floor,xy,j['pad'])
                self.assertTrue(set(pixels(actual)) <= palette,(name,xy,'Old face artwork left on bank turf'))
                for y in range(16):
                    for x in range(16):
                        if native.getpixel((x,y)) in palette:
                            self.assertEqual(actual.getpixel((x,y)),native.getpixel((x,y)),(name,xy,x,y))

    def test_reported_road_bank_regression_retains_dirt_above_the_face(self):
        j,raw,floor,*_ = self.maps['kanto_field']
        native = tile(raw,(18,200),j['pad'])
        actual = tile(floor,(18,200),j['pad'])
        self.assertEqual(native.getpixel((4,2)),(238,230,139,255))
        self.assertEqual(actual.crop((0,0,16,7)).tobytes(),native.crop((0,0,16,7)).tobytes())

    def test_repair_does_not_move_a_real_path_under_a_walkable_canopy(self):
        lawn = Image.new('RGBA',(16,16),(115,205,164,255))
        path = Image.new('RGBA',(16,16),(238,230,139,255))
        raw = Image.new('RGBA',(48,16));raw.paste(lawn,(0,0));raw.paste(lawn,(16,0));raw.paste(path,(32,0))
        floor = Image.new('RGBA',raw.size);floor.paste(lawn,(0,0));floor.paste(path,(16,0));floor.paste(lawn,(32,0))
        j = {'width':3,'height':1,'pad':0,'solid':['010'],'grass':['000'],'ledge':['000'],'areas':[]}
        restore_tree_floor(j,raw,floor,{(1,0),(2,0)},{(0,0):lawn},surface_palette([lawn,path]))
        self.assertEqual(tile(floor,(1,0),0).tobytes(),lawn.tobytes())
        self.assertEqual(tile(floor,(2,0),0).tobytes(),path.tobytes())


if __name__=='__main__':unittest.main()
