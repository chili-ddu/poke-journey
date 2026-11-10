"""Build only the HGSS Pallet Town comparison sample, leaving Johto intact."""
import hgss_maps as hg

if __name__ == '__main__':
    headers, _ = hg.headers()
    ids = [i for i, h in headers.items() if h['constant'] == 'MAP_PALLET' or h['constant'].startswith('MAP_PALLET_TOWN_')]
    hg.prepare(header_ids=ids, destination=hg.ROOT / 'assets/maps/hgss_pallet_sample')
