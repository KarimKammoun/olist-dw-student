"""Olist raw schema ERD in the style of the reference diagram (light-blue headers, crow's foot)."""
import cairosvg

W, H = 1530, 1500
TW, HEAD, ROW = 430, 56, 40
FONT = "Liberation Sans, DejaVu Sans, Arial, sans-serif"
INK, GREY, LINE = "#1d1d1f", "#6b7280", "#2b2b2b"
HEAD_BG, STRIPE, BORDER = "#b3e0f5", "#eff0f2", "#555555"
PK_BG, FK_BG = "#f6d36b", "#9cc7ef"

# name: (x, y, badge, [(tag, column, type)])
TABLES = {
    "payments": (50, 140, "JSON · 103,886 rows", [
        ("PK FK", "order_id", "char(32)"), ("PK", "payment_sequential", "int"),
        ("", "payment_type", "varchar(20)"), ("", "payment_installments", "int"),
        ("", "payment_value", "decimal(12,2)")]),
    "orders": (50, 620, "JSONL · 99,441 rows", [
        ("PK", "order_id", "char(32)"), ("FK", "customer_id", "char(32)"),
        ("", "order_status", "varchar(20)"), ("", "order_purchase_timestamp", "datetime2"),
        ("", "order_approved_at", "datetime2"), ("", "order_delivered_carrier_date", "datetime2"),
        ("", "order_delivered_customer_date", "datetime2"), ("", "order_estimated_delivery_date", "datetime2")]),
    "customers": (50, 1080, "Parquet · 99,441 rows", [
        ("PK", "customer_id", "char(32)"), ("", "customer_unique_id", "char(32)"),
        ("", "customer_zip_code_prefix", "char(5)"), ("", "customer_city", "nvarchar(60)"),
        ("", "customer_state", "char(2)")]),
    "products": (545, 130, "CSV · 32,951 rows", [
        ("PK", "product_id", "char(32)"), ("FK", "product_category_name", "nvarchar(60)"),
        ("", "product_name_lenght", "int"), ("", "product_description_lenght", "int"),
        ("", "product_photos_qty", "int"), ("", "product_weight_g", "int"),
        ("", "product_length_cm", "int"), ("", "product_height_cm", "int"), ("", "product_width_cm", "int")]),
    "order_items": (545, 620, "Parquet · 112,650 rows", [
        ("PK FK", "order_id", "char(32)"), ("PK", "order_item_id", "int"),
        ("FK", "product_id", "char(32)"), ("FK", "seller_id", "char(32)"),
        ("", "shipping_limit_date", "datetime2"), ("", "price", "decimal(12,2)"),
        ("", "freight_value", "decimal(12,2)")]),
    "reviews": (545, 1030, "JSON · 99,224 rows", [
        ("PK", "review_id", "char(32)"), ("PK FK", "order_id", "char(32)"),
        ("", "review_score", "int"), ("", "review_comment_title", "nvarchar(100)"),
        ("", "review_comment_message", "nvarchar(max)"), ("", "review_creation_date", "datetime2"),
        ("", "review_answer_timestamp", "datetime2")]),
    "category_translation": (1040, 170, "CSV · 71 rows", [
        ("PK", "product_category_name", "nvarchar(60)"), ("", "product_category_name_english", "nvarchar(60)")]),
    "sellers": (1040, 620, "CSV · 3,095 rows", [
        ("PK", "seller_id", "char(32)"), ("", "seller_zip_code_prefix", "char(5)"),
        ("", "seller_city", "nvarchar(60)"), ("", "seller_state", "char(2)")]),
    "geolocation": (1040, 1030, "Parquet · 1,000,163 rows", [
        ("", "geolocation_zip_code_prefix", "char(5)"), ("", "geolocation_lat", "float"),
        ("", "geolocation_lng", "float"), ("", "geolocation_city", "nvarchar(60)"),
        ("", "geolocation_state", "char(2)")]),
}


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def row_y(table, i):
    return TABLES[table][1] + HEAD + ROW * i + ROW / 2


out = []
add = out.append
add(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="{FONT}">')
add(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
add(f'<text x="{W/2}" y="62" text-anchor="middle" font-size="40" font-weight="700" letter-spacing="3" fill="{INK}">OLIST DATABASE SCHEMA</text>')
add(f'<text x="{W/2}" y="96" text-anchor="middle" font-size="17" fill="{GREY}">OlistDW · raw layer · 9 tables loaded by Airflow from the course files</text>')

# ---------- connectors (drawn first, under the tables) ----------
def path(points, dashed=False):
    d = "M" + " L".join(f"{x},{y}" for x, y in points)
    dash = ' stroke-dasharray="9 7"' if dashed else ""
    add(f'<path d="{d}" fill="none" stroke="{LINE}" stroke-width="2.2"{dash}/>')


def end_h(x, y, side, kind):
    """Marker at a table edge. side=+1: table is to the right of x; -1: table to the left."""
    if kind == "many":
        tip = x - side * 26
        for dy in (-11, 0, 11):
            add(f'<line x1="{tip}" y1="{y}" x2="{x}" y2="{y+dy}" stroke="{LINE}" stroke-width="2.2"/>')
        bx = x - side * 34
    else:
        bx = x - side * 14
        add(f'<line x1="{bx}" y1="{y-11}" x2="{bx}" y2="{y+11}" stroke="{LINE}" stroke-width="2.2"/>')
        bx = x - side * 24
    add(f'<line x1="{bx}" y1="{y-11}" x2="{bx}" y2="{y+11}" stroke="{LINE}" stroke-width="2.2"/>')


def end_v(x, y, side, kind):
    """Vertical version. side=+1: table is below y; -1: table above."""
    if kind == "many":
        tip = y - side * 26
        for dx in (-11, 0, 11):
            add(f'<line x1="{x}" y1="{tip}" x2="{x+dx}" y2="{y}" stroke="{LINE}" stroke-width="2.2"/>')
        by = y - side * 34
    else:
        by = y - side * 14
        add(f'<line x1="{x-11}" y1="{by}" x2="{x+11}" y2="{by}" stroke="{LINE}" stroke-width="2.2"/>')
        by = y - side * 24
    add(f'<line x1="{x-11}" y1="{by}" x2="{x+11}" y2="{by}" stroke="{LINE}" stroke-width="2.2"/>')


ox, oy = 480, row_y("orders", 0)
# orders 1 — N order_items (order_id)
path([(ox, oy), (545, oy)]); end_h(ox, oy, -1, "one"); end_h(545, oy, +1, "many")
# orders 1 — N payments (order_id), routed on the left
py = row_y("payments", 0)
path([(50, oy), (22, oy), (22, py), (50, py)]); end_h(50, oy, +1, "one"); end_h(50, py, +1, "many")
# orders 1 — N reviews (order_id), branch in the A-B gap
ry = row_y("reviews", 1)
path([(512, oy), (512, ry), (545, ry)]); end_h(545, ry, +1, "many")
# customers 1 — 1 orders (customer_id): one customer_id per order in Olist
cy, ocy = row_y("customers", 0), row_y("orders", 1)
path([(50, cy), (34, cy), (34, ocy), (50, ocy)]); end_h(50, cy, +1, "one"); end_h(50, ocy, +1, "one")
# products 1 — N order_items (product_id), vertical
px = 760
pb = TABLES["products"][1] + HEAD + ROW * 9
path([(px, pb), (px, 620)]); end_v(px, pb, -1, "one"); end_v(px, 620, +1, "many")
add(f'<text x="{px+16}" y="{(pb+620)/2+6}" font-size="15" font-style="italic" fill="{GREY}">product_id</text>')
# sellers 1 — N order_items (seller_id)
sy, isy = row_y("sellers", 0), row_y("order_items", 3)
path([(1040, sy), (1007, sy), (1007, isy), (975, isy)]); end_h(1040, sy, +1, "one"); end_h(975, isy, -1, "many")
# category_translation 1 — N products (product_category_name)
ty = row_y("category_translation", 0)
path([(1040, ty), (975, ty)]); end_h(1040, ty, +1, "one"); end_h(975, ty, -1, "many")
# geolocation N — N sellers / customers on zip prefix (not a key): dashed
gy = row_y("geolocation", 0)
szy = row_y("sellers", 1)
path([(1470, szy), (1502, szy), (1502, gy), (1470, gy)], dashed=True)
end_h(1470, szy, -1, "many"); end_h(1470, gy, -1, "many")
czy = row_y("customers", 2)
path([(480, czy), (496, czy), (496, 1415), (1007, 1415), (1007, gy), (1040, gy)], dashed=True)
end_h(480, czy, -1, "many"); end_h(1040, gy, +1, "many")

# ---------- tables ----------
for name, (x, y, badge, cols) in TABLES.items():
    h = HEAD + ROW * len(cols)
    add(f'<g>')
    add(f'<rect x="{x}" y="{y}" width="{TW}" height="{h}" rx="9" fill="#ffffff" stroke="{BORDER}" stroke-width="1.6"/>')
    add(f'<path d="M{x},{y+HEAD} V{y+9} Q{x},{y} {x+9},{y} H{x+TW-9} Q{x+TW},{y} {x+TW},{y+9} V{y+HEAD} Z" fill="{HEAD_BG}" stroke="{BORDER}" stroke-width="1.6"/>')
    add(f'<text x="{x+16}" y="{y+36}" font-size="21" font-weight="700" fill="{INK}">{esc(name)}</text>')
    add(f'<text x="{x+TW-14}" y="{y+35}" text-anchor="end" font-size="13" fill="#2f4f66">{esc(badge)}</text>')
    for i, (tag, col, typ) in enumerate(cols):
        ry0 = y + HEAD + ROW * i
        if i % 2 == 1:
            last = i == len(cols) - 1
            add(f'<rect x="{x+1}" y="{ry0}" width="{TW-2}" height="{ROW - (2 if last else 0)}" fill="{STRIPE}"/>')
        tx = x + 12
        for part in tag.split():
            bg = PK_BG if part == "PK" else FK_BG
            add(f'<rect x="{tx}" y="{ry0+11}" width="26" height="18" rx="4" fill="{bg}"/>')
            add(f'<text x="{tx+13}" y="{ry0+25}" text-anchor="middle" font-size="11" font-weight="700" fill="{INK}">{part}</text>')
            tx += 30
        weight = ' font-weight="700"' if "PK" in tag else ""
        add(f'<text x="{x+74}" y="{ry0+26}" font-size="16"{weight} fill="{INK}">{esc(col)}</text>')
        add(f'<text x="{x+TW-14}" y="{ry0+26}" text-anchor="end" font-size="14" fill="{GREY}">{esc(typ)}</text>')
    add(f'<rect x="{x}" y="{y}" width="{TW}" height="{h}" rx="9" fill="none" stroke="{BORDER}" stroke-width="1.6"/>')
    add('</g>')

# ---------- legend ----------
lx, ly = 1040, 340
add(f'<rect x="{lx}" y="{ly}" width="{TW}" height="236" rx="9" fill="#fafafa" stroke="#c9c9c9"/>')
add(f'<text x="{lx+16}" y="{ly+30}" font-size="17" font-weight="700" fill="{INK}">Legend</text>')
items = [("PK", "primary key (bold column)"), ("FK", "foreign key")]
yy = ly + 58
for tag, txt in items:
    add(f'<rect x="{lx+16}" y="{yy-14}" width="26" height="18" rx="4" fill="{PK_BG if tag=="PK" else FK_BG}"/>')
    add(f'<text x="{lx+29}" y="{yy}" text-anchor="middle" font-size="11" font-weight="700">{tag}</text>')
    add(f'<text x="{lx+54}" y="{yy}" font-size="15" fill="{INK}">{txt}</text>')
    yy += 30
# one / many / dashed samples
def sample(y, kind, label, dashed=False):
    path([(lx + 16, y), (lx + 96, y)], dashed=dashed)
    end_h(lx + 96, y, +1, kind)
    add(f'<text x="{lx+112}" y="{y+5}" font-size="15" fill="{INK}">{label}</text>')
sample(yy + 2, "one", "exactly one"); yy += 34
sample(yy + 2, "many", "many"); yy += 34
sample(yy + 2, "many", "matched on zip prefix (not a key)", dashed=True)

# ---------- notes ----------
add(f'<text x="50" y="1468" font-size="14" fill="{GREY}">Types are the ones given in staging (raw stores every value as NVARCHAR). geolocation has no key: 19,015 distinct zip prefixes in 1,000,163 rows.</text>')
add(f'<text x="50" y="1490" font-size="14" fill="{GREY}">review_id alone repeats (814 times), so reviews is keyed on review_id + order_id. Each customer_id belongs to exactly one order; customer_unique_id identifies the person.</text>')
add('</svg>')

svg = "\n".join(out)
open("/home/claude/erd/olist_database_schema.svg", "w").write(svg)
cairosvg.svg2png(bytestring=svg.encode(), write_to="/home/claude/erd/olist_database_schema.png", output_width=W * 2)
print("ok")
