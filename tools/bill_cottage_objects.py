"""Keep Bill's linked separator equipment intact when lifting native room artwork."""

def specifications():
    objects = []
    def add(id, rect, **kwargs):
        objects.append(dict(id=id, kind='card', rect=rect, donor=[7,7], **kwargs))
    # One connected silhouette keeps the cable, chambers and control panels aligned.
    add('cell_separator', [16,8,224,64], wall=34, z1=4)
    add('left_storage', [0,32,16,156], z1=9.75)
    add('right_storage', [224,32,240,124], z1=7.75)
    add('left_plants', [16,132,48,160], z1=10)
    add('right_plants', [208,132,240,160], z1=10)
    add('separator_pc', [64,78,96,104], z1=6.5)
    return objects
