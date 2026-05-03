from PIL import Image, ImageDraw

def create_pixel_png(path, size, draw_func):
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_func(draw, size)
    img.save(path)

# --- Scene: Galaxy Observatory ---

def draw_galaxy_bg(draw, size, state='normal'):
    colors = {
        'normal': (10, 6, 30, 255),
        'dim': (5, 3, 15, 255),
        'alert': (30, 6, 10, 255)
    }
    draw.rectangle([0, 0, size[0], size[1]], fill=colors.get(state, colors['normal']))
    # Stars
    star_color = (200, 200, 255, 200)
    for x, y in [(50, 30), (120, 20), (280, 40), (320, 10), (180, 50)]:
        draw.point((x, y), fill=star_color)

def draw_galaxy_floor(draw, size):
    draw.rectangle([0, 100, size[0], size[1]], fill=(20, 25, 45, 255))
    for x in range(0, size[0], 20):
        draw.line([(x, 100), (x, size[1])], fill=(40, 50, 80, 255), width=1)

# --- Pet: Nebula Bot ---

def draw_nebula_bot(draw, size, state='idle'):
    # Body (Silver)
    draw.rectangle([4, 6, 20, 24], fill=(170, 187, 203, 255), outline=(0, 0, 0, 255))
    # Face Screen
    draw.rectangle([6, 8, 18, 16], fill=(20, 20, 40, 255))
    
    # Eyes based on state
    if state == 'error':
        draw.point([(8, 10), (10, 12), (10, 10), (8, 12)], fill=(255, 50, 50, 255)) # X
        draw.point([(14, 10), (16, 12), (16, 10), (14, 12)], fill=(255, 50, 50, 255)) # X
    elif state == 'thinking':
        draw.point([(8, 12), (12, 12), (16, 12)], fill=(100, 200, 255, 255))
    elif state == 'charging':
        draw.rectangle([8, 10, 16, 14], fill=(50, 255, 100, 255))
    else: # idle
        draw.point([(9, 11), (15, 11)], fill=(0, 255, 255, 255))

# --- Accessory: Halo ---

def draw_halo(draw, size, state='normal'):
    color = (255, 255, 0, 255) if state == 'normal' else (255, 255, 150, 255)
    draw.ellipse([4, 4, 20, 12], outline=color, width=2)

# Generation
base = "PixelPets/Resources/Assets/PixelPets"

# Scenes
create_pixel_png(f"{base}/Scenes/galaxy_observatory/bg.png", (360, 140), lambda d, s: draw_galaxy_bg(d, s, 'normal'))
create_pixel_png(f"{base}/Scenes/galaxy_observatory/bg_dim.png", (360, 140), lambda d, s: draw_galaxy_bg(d, s, 'dim'))
create_pixel_png(f"{base}/Scenes/galaxy_observatory/bg_alert.png", (360, 140), lambda d, s: draw_galaxy_bg(d, s, 'alert'))
create_pixel_png(f"{base}/Scenes/galaxy_observatory/floor.png", (360, 140), draw_galaxy_floor)

# Pets
create_pixel_png(f"{base}/Pets/nebula_bot/idle.png", (24, 28), lambda d, s: draw_nebula_bot(d, s, 'idle'))
create_pixel_png(f"{base}/Pets/nebula_bot/thinking.png", (24, 28), lambda d, s: draw_nebula_bot(d, s, 'thinking'))
create_pixel_png(f"{base}/Pets/nebula_bot/charging.png", (24, 28), lambda d, s: draw_nebula_bot(d, s, 'charging'))
create_pixel_png(f"{base}/Pets/nebula_bot/error.png", (24, 28), lambda d, s: draw_nebula_bot(d, s, 'error'))

# Accessories
create_pixel_png(f"{base}/Accessories/halo/normal.png", (24, 16), lambda d, s: draw_halo(d, s, 'normal'))
create_pixel_png(f"{base}/Accessories/halo/active.png", (24, 16), lambda d, s: draw_halo(d, s, 'active'))

print("Assets generated successfully.")
