"""Regenerate the original geometric Velora app icon (requires Pillow)."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / "App/Assets.xcassets"
target = root / "AppIcon.appiconset"
target.mkdir(parents=True, exist_ok=True)
size = 1024
image = Image.new("RGB", (size, size))
pixels = image.load()
for y in range(size):
    for x in range(size):
        glow = max(0, 1 - (((x - 512) / 730) ** 2 + ((y - 390) / 750) ** 2))
        pixels[x, y] = (int(9 + 8 * glow), int(14 + 28 * glow), int(26 + 31 * glow))
draw = ImageDraw.Draw(image)
draw.ellipse((154, 154, 870, 870), outline=(27, 69, 77), width=3)
draw.ellipse((213, 213, 811, 811), outline=(34, 88, 93), width=3)
draw.line([(310, 350), (512, 697), (727, 317)], fill=(103, 240, 204), width=69, joint="curve")
draw.ellipse((478, 663, 546, 731), fill=(103, 240, 204))
draw.ellipse((692, 282, 762, 352), fill=(103, 240, 204))
draw.ellipse((275, 315, 345, 385), fill=(103, 240, 204))
image.save(target / "AppIcon.png")
(root / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
(target / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1}
}, indent=2))
print(target / "AppIcon.png")
