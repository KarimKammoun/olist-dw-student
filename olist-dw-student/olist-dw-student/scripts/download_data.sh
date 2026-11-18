#!/usr/bin/env bash
# Only needed if you use the original Kaggle CSVs instead of the files supplied by your instructor.
# Downloads the Olist dataset with the Kaggle CLI into include/data/olist/
# Needs: pip install kaggle  +  ~/.kaggle/kaggle.json (Kaggle > Settings > API > Create New Token)
set -euo pipefail
DEST="$(cd "$(dirname "$0")/.." && pwd)/include/data/olist"
mkdir -p "$DEST"
kaggle datasets download -d olistbr/brazilian-ecommerce -p "$DEST" --unzip
echo "Files in $DEST:"
ls -1 "$DEST"/*.csv
COUNT=$(ls -1 "$DEST"/*.csv | wc -l)
[ "$COUNT" -eq 9 ] && echo "OK: 9 CSV files" || { echo "Expected 9 CSV files, found $COUNT"; exit 1; }
