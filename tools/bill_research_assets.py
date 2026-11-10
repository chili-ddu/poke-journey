"""Fetch missing Bill research party animation sheets without overwriting existing art."""
import kanto_wild_assets

def main():
    original=kanto_wild_assets.DEXES
    try:
        kanto_wild_assets.DEXES=[64,133,134,135,136]
        kanto_wild_assets.main()
    finally:
        kanto_wild_assets.DEXES=original

if __name__=='__main__':main()
