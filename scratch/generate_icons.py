import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def draw_scanora_icon(size=1024):
    # Supersample at 4x for extreme smoothness
    scale = 4
    canvas_size = size * scale
    img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = (canvas_size / 2.0, canvas_size / 2.0)
    radius = canvas_size * 0.46 # Leave a small margin for padding

    # 6 Facet Petals
    colors = [
        (249, 115, 22),  # Bright Orange #F97316
        (251, 146, 60),  # Light Amber Orange #FB923C
        (234, 88, 12),   # Deep Orange #EA580C
        (194, 65, 12),   # Crimson Coral #C2410C
        (154, 52, 18),   # Deep Rust #9A3412
        (245, 158, 11),  # Warm Amber #F59E0B
    ]

    # Create circular mask for aperture
    mask = Image.new('L', (canvas_size, canvas_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse(
        [center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius],
        fill=255
    )

    # Temporary image for the petals
    petals_img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    petals_draw = ImageDraw.Draw(petals_img)

    count = 6
    for i in range(count):
        angle = (i * 2 * math.pi / count) - (math.pi / 6)
        next_angle = angle + (2 * math.pi / count)

        p1 = center
        p2 = (
            center[0] + radius * 1.5 * math.cos(angle),
            center[1] + radius * 1.5 * math.sin(angle),
        )
        p3 = (
            center[0] + radius * 1.5 * math.cos(next_angle),
            center[1] + radius * 1.5 * math.sin(next_angle),
        )

        petals_draw.polygon([p1, p2, p3], fill=colors[i % len(colors)])

    # Inner dark aperture polygon
    inner_radius = radius * (18.0 / 65.0)
    inner_pts = []
    for i in range(count):
        ang = i * 2 * math.pi / count
        pt = (
            center[0] + inner_radius * math.cos(ang),
            center[1] + inner_radius * math.sin(ang),
        )
        inner_pts.append(pt)
    petals_draw.polygon(inner_pts, fill=(124, 45, 18)) # #7C2D12

    # Composite petals with circular mask
    img.paste(petals_img, (0, 0), mask)

    # Rounded square badge on left/center with 'S' emblem
    badge_w = (radius * 2) * 0.44
    badge_h = (radius * 2) * 0.44
    badge_cx = center[0] - ((radius * 2) * 0.12)
    badge_cy = center[1]
    corner_r = (radius * 2) * (8.0 / 130.0)

    x0 = badge_cx - (badge_w / 2.0)
    y0 = badge_cy - (badge_h / 2.0)
    x1 = badge_cx + (badge_w / 2.0)
    y1 = badge_cy + (badge_h / 2.0)

    # Shadow layer
    shadow_img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_img)
    shadow_offset = canvas_size * 0.015
    shadow_draw.rounded_rectangle(
        [x0, y0 + shadow_offset, x1, y1 + shadow_offset],
        radius=corner_r,
        fill=(0, 0, 0, 90)
    )
    blur_r = canvas_size * 0.02
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(blur_r))
    img.alpha_composite(shadow_img)

    # Badge background
    badge_img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(badge_img)
    b_draw.rounded_rectangle([x0, y0, x1, y1], radius=corner_r, fill=(234, 88, 12, 255))

    # Badge subtle gradient highlight
    highlight_img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(highlight_img)
    h_draw.rounded_rectangle([x0, y0, x1, y0 + (badge_h * 0.45)], radius=corner_r, fill=(255, 255, 255, 30))
    badge_img.alpha_composite(highlight_img)

    # Letter 'S'
    font_size = int((radius * 2) * (36.0 / 130.0))
    font = None
    for font_name in ['arialbd.ttf', 'segoeuib.ttf', 'arial.ttf']:
        font_path = os.path.join(os.environ.get('WINDIR', 'C:\\Windows'), 'Fonts', font_name)
        if os.path.exists(font_path):
            try:
                font = ImageFont.truetype(font_path, font_size)
                break
            except Exception:
                pass
    if font is None:
        font = ImageFont.load_default()

    bbox = b_draw.textbbox((0, 0), "S", font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    tx = badge_cx - (text_w / 2.0) - bbox[0]
    ty = badge_cy - (text_h / 2.0) - bbox[1]

    b_draw.text((tx, ty), "S", font=font, fill=(255, 255, 255, 255))
    img.alpha_composite(badge_img)

    # Downscale to desired size using high-quality Lanczos resampling
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

def main():
    base_dir = r"c:\Users\Jawaan Santh\Desktop\Scanora"
    
    # 1. Android Mipmaps
    android_res = os.path.join(base_dir, "android", "app", "src", "main", "res")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, dim in android_sizes.items():
        out_dir = os.path.join(android_res, folder)
        os.makedirs(out_dir, exist_ok=True)
        icon = draw_scanora_icon(dim)
        out_path = os.path.join(out_dir, "ic_launcher.png")
        icon.save(out_path, format="PNG")
        print(f"Saved Android icon: {out_path} ({dim}x{dim})")

    # 2. Web Icons
    web_dir = os.path.join(base_dir, "web")
    web_icons_dir = os.path.join(web_dir, "icons")
    os.makedirs(web_icons_dir, exist_ok=True)

    favicon = draw_scanora_icon(64)
    favicon.save(os.path.join(web_dir, "favicon.png"), format="PNG")
    print("Saved web favicon.png")

    icon192 = draw_scanora_icon(192)
    icon192.save(os.path.join(web_icons_dir, "Icon-192.png"), format="PNG")
    icon192.save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), format="PNG")

    icon512 = draw_scanora_icon(512)
    icon512.save(os.path.join(web_icons_dir, "Icon-512.png"), format="PNG")
    icon512.save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), format="PNG")
    print("Saved web icons 192 and 512")

    # 3. iOS Icons
    ios_icon_dir = os.path.join(base_dir, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_icon_dir):
        ios_1024 = draw_scanora_icon(1024)
        ios_1024.save(os.path.join(ios_icon_dir, "Icon-App-1024x1024@1x.png"), format="PNG")
        print("Saved iOS 1024 icon")

    # 4. Windows app_icon.ico
    win_res = os.path.join(base_dir, "windows", "runner", "resources")
    if os.path.exists(win_res):
        ico_img = draw_scanora_icon(256)
        ico_path = os.path.join(win_res, "app_icon.ico")
        ico_img.save(ico_path, format="ICO", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
        print(f"Saved Windows app_icon.ico: {ico_path}")

    print("All app icons successfully updated with the splash screen Scanora logo!")

if __name__ == "__main__":
    main()
