from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / "web" / "public"
OUT = PUBLIC / "fitcountable-social-card.png"

W, H = 1200, 630


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Avenir Next.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size=size, index=1 if bold else 0)
        except Exception:
            continue
    return ImageFont.load_default()


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def paste_rounded(base: Image.Image, img: Image.Image, xy: tuple[int, int], radius: int) -> None:
    mask = rounded_mask(img.size, radius)
    base.paste(img, xy, mask)


def add_shadow(base: Image.Image, box: tuple[int, int, int, int], radius: int, opacity: int = 70, blur: int = 36) -> None:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle(box, radius=radius, fill=(0, 0, 0, opacity))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(layer)


def draw_wrapped(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], max_width: int, font_obj, fill, line_gap: int) -> int:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = f"{current} {word}".strip()
        if draw.textbbox((0, 0), trial, font=font_obj)[2] <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)

    x, y = xy
    for line in lines:
        draw.text((x, y), line, font=font_obj, fill=fill)
        y += font_obj.size + line_gap
    return y


def make_phone(screen_path: Path, size: tuple[int, int]) -> Image.Image:
    phone = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(phone)
    d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=56, fill=(13, 24, 21, 255))
    d.rounded_rectangle((8, 8, size[0] - 9, size[1] - 9), radius=50, fill=(237, 248, 244, 255))

    screen = Image.open(screen_path).convert("RGBA")
    screen.thumbnail((size[0] - 20, size[1] - 20))
    sx = (size[0] - screen.width) // 2
    sy = (size[1] - screen.height) // 2
    paste_rounded(phone, screen, (sx, sy), 42)

    d.rounded_rectangle((size[0] // 2 - 58, 24, size[0] // 2 + 58, 54), radius=16, fill=(18, 22, 21, 255))
    return phone


def main() -> None:
    img = Image.new("RGBA", (W, H), (8, 18, 15, 255))
    d = ImageDraw.Draw(img)

    for y in range(H):
        t = y / H
        r = int(8 + 8 * t)
        g = int(18 + 20 * t)
        b = int(15 + 18 * t)
        d.line((0, y, W, y), fill=(r, g, b, 255))

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((680, -230, 1350, 470), fill=(65, 211, 125, 48))
    gd.ellipse((-160, 250, 530, 850), fill=(30, 127, 255, 32))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(62)))

    mascot = Image.open(PUBLIC / "fitcountable-mascot.png").convert("RGBA").resize((108, 108))
    paste_rounded(img, mascot, (74, 70), 28)

    d.text((206, 78), "Fitcountable", font=font(48, True), fill=(246, 255, 250, 255))
    d.text((208, 134), "AI-native fitness accountability", font=font(25), fill=(130, 241, 174, 255))

    headline = "Log workouts and meals by saying what happened."
    y = draw_wrapped(d, headline, (74, 230), 610, font(68, True), (246, 255, 250, 255), 6)
    draw_wrapped(
        d,
        "Voice-first tracking for food, workouts, and proof.",
        (78, y + 20),
        560,
        font(27),
        (177, 193, 187, 255),
        4,
    )

    chips = [("Review before save", 74), ("Private by default", 292), ("Consistency", 506)]
    for label, x in chips:
        d.rounded_rectangle((x, 550, x + 190, 598), radius=24, fill=(9, 31, 25, 220), outline=(126, 236, 167, 120), width=1)
        d.ellipse((x + 20, 567, x + 32, 579), fill=(126, 236, 167, 255))
        d.text((x + 44, 562), label, font=font(18, True), fill=(235, 255, 244, 255))

    add_shadow(img, (760, 88, 1058, 604), 62, opacity=95, blur=42)
    phone = make_phone(PUBLIC / "app-today.png", (300, 520))
    img.alpha_composite(phone, (760, 70))

    card = Image.new("RGBA", (360, 112), (237, 250, 244, 238))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((0, 0, 360, 112), radius=28, fill=(237, 250, 244, 238))
    cd.text((28, 24), "Speak it. Review it. Save it.", font=font(25, True), fill=(8, 18, 15, 255))
    cd.text((28, 62), "Food, workouts, proof, and progress.", font=font(19), fill=(86, 103, 97, 255))
    add_shadow(img, (724, 478, 1084, 590), 28, opacity=55, blur=26)
    img.alpha_composite(card, (724, 458))

    img.convert("RGB").save(OUT, quality=94, optimize=True)
    print(OUT)


if __name__ == "__main__":
    main()
