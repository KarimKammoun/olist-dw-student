"""
Convert the Kaggle Olist archive into the mixed-format raw files used in the labs.

Run from the repo root (Windows PowerShell):
    python -m venv .venv-data
    .venv-data\\Scripts\\activate
    pip install pandas pyarrow
    python scripts\\convert_formats.py
    # the source can be the unzipped folder OR the zip file:
    python scripts\\convert_formats.py --src "C:\\Users\\mjha\\Downloads\\archive"
    python scripts\\convert_formats.py --src "C:\\Users\\mjha\\Downloads\\archive.zip"

Output: include/data/olist/  (git-ignored)
"""
from __future__ import annotations

import argparse
import io
import zipfile
from pathlib import Path

import pandas as pd

# Tried in this order when --src is not given
DEFAULT_SOURCES = [
    r"C:\Users\mjha\Downloads\archive",       # unzipped folder
    r"C:\Users\mjha\Downloads\archive.zip",   # original zip
]
REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = REPO_ROOT / "include" / "data" / "olist"

# csv file in the archive -> (target format, columns parsed as dates for Parquet)
PLAN: dict[str, tuple[str, list[str]]] = {
    "olist_orders_dataset.csv":              ("jsonl", []),
    "olist_order_reviews_dataset.csv":       ("json", []),
    "olist_order_payments_dataset.csv":      ("json", []),
    "olist_order_items_dataset.csv":         ("parquet", ["shipping_limit_date"]),
    "olist_geolocation_dataset.csv":         ("parquet", []),
    "olist_customers_dataset.csv":           ("parquet", []),   # zip becomes int: leading zeros lost on purpose
    "olist_products_dataset.csv":            ("csv", []),
    "olist_sellers_dataset.csv":             ("csv", []),
    "product_category_name_translation.csv": ("csv", []),
}


def human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.0f} {unit}"
        n /= 1024
    return f"{n:.1f} TB"


def find_csvs(src: Path) -> dict[str, callable]:
    """Map csv file name -> function returning its bytes, from a folder (any depth) or a zip."""
    if src.is_dir():
        return {p.name: p.read_bytes for p in src.rglob("*.csv")}
    if src.suffix.lower() == ".zip" and src.exists():
        zf = zipfile.ZipFile(src)
        return {Path(m).name: (lambda m=m: zf.read(m))
                for m in zf.namelist() if m.lower().endswith(".csv")}
    raise SystemExit(f"Source not found (expected a folder or a .zip): {src}")


def convert(src: Path, out_dir: Path, all_csv: bool) -> None:
    files = find_csvs(src)
    missing = sorted(set(PLAN) - set(files))
    if missing:
        raise SystemExit(f"Not found in {src}: {missing}")
    print(f"Source: {src}\n")
    out_dir.mkdir(parents=True, exist_ok=True)
    if out_dir.resolve() == src.resolve():
        raise SystemExit("Output folder must differ from the source folder.")

    # remove outputs of a previous run so the DAG never sees two files for one table
    for old in out_dir.iterdir():
        if old.suffix.lower() in {".csv", ".json", ".jsonl", ".parquet"}:
            old.unlink()

    print(f"{'file':<45}{'format':<9}{'rows':>11}{'csv size':>11}{'new size':>11}")
    for name, (fmt, date_cols) in PLAN.items():
        raw = files[name]()
        fmt = "csv" if all_csv else fmt
        target = out_dir / (Path(name).stem + "." + fmt)

        if fmt == "csv":
            target.write_bytes(raw)                       # untouched copy
            rows = sum(1 for _ in io.BytesIO(raw)) - 1
        elif fmt in ("json", "jsonl"):
            # no date parsing: dates stay as the original text (pandas would write epoch ms)
            df = pd.read_csv(io.BytesIO(raw), encoding="utf-8-sig")
            df.to_json(target, orient="records", lines=(fmt == "jsonl"), force_ascii=False)
            rows = len(df)
        else:  # parquet: let pandas infer real types
            df = pd.read_csv(io.BytesIO(raw), encoding="utf-8-sig", parse_dates=date_cols or None)
            df.to_parquet(target, index=False)
            rows = len(df)

        print(f"{target.name:<45}{fmt:<9}{rows:>11,}{human(len(raw)):>11}{human(target.stat().st_size):>11}")

    print(f"\nDone. Files written to {out_dir}")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--src", help="unzipped Kaggle folder or archive.zip (default: Downloads\\archive)")
    p.add_argument("--out", default=str(DEFAULT_OUT), help="output folder")
    p.add_argument("--all-csv", action="store_true", help="just copy the original CSVs")
    a = p.parse_args()
    if a.src:
        source = Path(a.src)
    else:
        source = next((Path(c) for c in DEFAULT_SOURCES if Path(c).exists()), None)
        if source is None:
            raise SystemExit("No source found. Pass --src with the unzipped folder or the zip file.")
    convert(source, Path(a.out), a.all_csv)
