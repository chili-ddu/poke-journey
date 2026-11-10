"""Assemble native minimum-window captures without resizing the game window."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/lapras_riding'
LABELS = ['아래', '오른쪽 아래', '오른쪽', '오른쪽 위', '위', '왼쪽 위', '왼쪽', '왼쪽 아래']

def main():
    font = ImageFont.truetype(str(ROOT / 'assets/fonts/Galmuri11.ttf'), 16)
    frames = []
    for frame in range(4):
        sheet = Image.new('RGB', (768, 384), (34, 49, 58))
        draw = ImageDraw.Draw(sheet)
        for row, label in enumerate(LABELS):
            image = Image.open(OUT / f'{row}_{frame}.png').convert('RGB')
            image = image.crop((144, 38, 240, 134)).resize((192, 192), Image.Resampling.NEAREST)
            x, y = row % 4 * 192, row // 4 * 192
            sheet.paste(image, (x, y))
            draw.text((x + 9, y + 9), label, font=font, fill=(29, 74, 124))
            draw.text((x + 8, y + 8), label, font=font, fill='white')
        frames.append(sheet)
    frames[0].save(OUT / 'eight_directions.png')
    frames[0].save(OUT / 'eight_directions.gif', save_all=True, append_images=frames[1:],
                   duration=[167, 200, 167, 200], loop=0, optimize=False)

if __name__ == '__main__':
    main()
