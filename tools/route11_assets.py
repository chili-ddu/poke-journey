"""Fetch missing Route 11/Diglett's Cave wild and original trainer-party sheets."""
import kanto_wild_assets

def main():
    original = kanto_wild_assets.DEXES
    try:
        kanto_wild_assets.DEXES = [20, 33, 37, 50, 51, 58, 82, 96]
        kanto_wild_assets.main()
    finally:
        kanto_wild_assets.DEXES = original

if __name__ == '__main__':main()
