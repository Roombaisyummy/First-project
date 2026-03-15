from PIL import Image, ImageDraw

def create_icon(size, filename):
    # Create a deep blue background
    img = Image.new('RGB', (size, size), color=(20, 40, 80))
    draw = ImageDraw.Draw(img)
    
    # Draw a golden diamond shape
    padding = size // 4
    points = [
        (size // 2, padding),           # Top
        (size - padding, size // 2),    # Right
        (size // 2, size - padding),    # Bottom
        (padding, size // 2)            # Left
    ]
    draw.polygon(points, fill=(255, 215, 0), outline=(255, 255, 255))
    
    img.save(filename)

# Create standard iPhone sizes
create_icon(120, '/home/natha/GildedClient/AppIcon60x60@2x.png')
create_icon(180, '/home/natha/GildedClient/AppIcon60x60@3x.png')
