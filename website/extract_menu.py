import re
import json
from pathlib import Path

BASE = "https://softmenu.ir/"
IMAGE_DIR = Path("public/images")
IMAGE_DIR.mkdir(parents=True, exist_ok=True)

FILES = {
    "burger.html": ("burger", "برگر"),
    "sandwich.html": ("sandwich", "ساندویچ"),
    "fried.html": ("fried", "سوخاری"),
    "special.html": ("special", "ویژه"),
}


def fa_to_en(text):
    table = str.maketrans(
        "۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩",
        "01234567890123456789"
    )
    return text.translate(table)


def clean(text):
    return re.sub(r"\s+", " ", text).strip()


def extract_items(html):
    items = []

    # هر آیتم با itemsMenu مشخص می‌شود
    blocks = re.findall(
        r'<div class="itemsMenu" id="([^"]+)">(.*?)(?=<div class="col-lg-6"|</div>\s*</div>\s*</div>\s*</div>\s*</div>)',
        html,
        re.S
    )

    for item_id, block in blocks:

        # عکس
        image_match = re.search(
            r'<img[^>]+class="imgItem"[^>]+src="([^"]+)"',
            block,
            re.S
        )

        if not image_match:
            continue

        image_url = image_match.group(1).strip()

        # نام
        name_match = re.search(
            r'<p class="nameitem"[^>]*>(.*?)</p>',
            block,
            re.S
        )

        if not name_match:
            continue

        name = clean(name_match.group(1))

        # توضیح کامل
        description_match = re.search(
            r'<b[^>]+style="display:\s*none;"[^>]*id="detailsitem"[^>]*>(.*?)</b>',
            block,
            re.S
        )

        if description_match:
            description = clean(description_match.group(1))
        else:
            description_match = re.search(
                r'<b class="detailsitem"[^>]*>(.*?)</b>',
                block,
                re.S
            )
            description = clean(description_match.group(1)) if description_match else ""

        # قیمت
        price_match = re.search(
            r'<p class="priceitem"[^>]*>(.*?)</p>',
            block,
            re.S
        )

        price = 0

        if price_match:
            price_text = fa_to_en(price_match.group(1))
            number_match = re.search(r'\d+(?:[.,]\d+)?', price_text)

            if number_match:
                price = int(float(number_match.group(0).replace(",", "")))

        # نام فایل عکس
        filename = image_url.rstrip("/").split("/")[-1]

        # مسیر محلی
        local_image = f"/images/{filename}"

        items.append({
            "id": item_id,
            "name": name,
            "description": description,
            "price": price,
            "oldPrice": None,
            "image": local_image,
            "available": True,
            "_remote_image": image_url
        })

    return items


result = {
    "restaurant": {
        "name": "خانه سیب‌زمینی (سوران)",
        "description": "منوی آنلاین خانه سیب‌زمینی (سوران)",
        "logo": "/images/logo.jpg",
        "theme": {
            "background": "#000000",
            "accent": "#62FF00",
            "secondary": "#FFFC36"
        }
    },
    "categories": []
}


for filename, (category_id, category_name) in FILES.items():

    path = Path(filename)

    if not path.exists():
        print(f"❌ {filename} پیدا نشد")
        continue

    html = path.read_text(encoding="utf-8", errors="ignore")

    items = extract_items(html)

    # حذف اطلاعات موقت
    for item in items:
        item.pop("_remote_image", None)

    result["categories"].append({
        "id": category_id,
        "name": category_name,
        "items": items
    })

    print(f"✅ {category_name}: {len(items)} آیتم")


Path("src/data/menu.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

print()
print("✅ menu.json ساخته شد")
