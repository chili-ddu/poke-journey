"""Fill missing normal/shiny native sheets for every mainland wild species."""
import json
import kanto_wild_assets as assets

def main():
    data=json.loads((assets.ROOT/'assets/data/kanto_world_wild.json').read_text())
    assets.main([row['dex'] for row in data['species'].values()])

if __name__=='__main__':main()
