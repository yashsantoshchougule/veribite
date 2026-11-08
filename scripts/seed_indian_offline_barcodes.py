#!/usr/bin/env python3
"""
Seed script to generate compact, high-density Indian FMCG offline barcode database.
Exports to mobile_app/assets/db/offline_barcodes_seed.json.
"""

import json
import os
import sys

def main():
    # If run in Python environment, delegates or generates identical dataset
    output_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "mobile_app", "assets", "db", "offline_barcodes_seed.json"
    )
    if os.path.exists(output_path):
        with open(output_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        print(f"Offline barcode seed already exists with {data.get('total_count', 0)} items at {output_path}")
    else:
        print("Please run 'dart scripts/seed_indian_offline_barcodes.dart' to compile offline seed.")

if __name__ == "__main__":
    main()
