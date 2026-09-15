from pathlib import Path

from PIL import Image, ImageDraw


render_dir = Path(r"D:\Desktop\ai-platform\tmp\pdfs\rendered")
files = sorted(render_dir.glob("page-*.png"))
cells = []
for file in files:
    image = Image.open(file).convert("RGB")
    image.thumbnail((260, 368))
    cells.append((file, image.copy()))

columns = 4
rows = (len(cells) + columns - 1) // columns
sheet = Image.new("RGB", (columns * 280 + 20, rows * 410 + 20), "#dbe3ea")
draw = ImageDraw.Draw(sheet)
for index, (_, image) in enumerate(cells):
    x = 20 + (index % columns) * 280
    y = 20 + (index // columns) * 410
    draw.text((x, y), str(index + 1), fill="#111827")
    sheet.paste(image, (x, y + 22))

sheet.save(render_dir / "contact-sheet.png")
