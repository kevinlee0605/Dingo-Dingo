from pathlib import Path
import sys

from PIL import Image


root = Path(sys.argv[1])
for path in sorted(root.glob("*.png")):
    with Image.open(path) as image:
        alpha = image.getchannel("A") if "A" in image.getbands() else None
        bbox = alpha.getbbox() if alpha else None
        print(f"{path.name}\t{image.width}x{image.height}\t{image.mode}\tbbox={bbox}")
