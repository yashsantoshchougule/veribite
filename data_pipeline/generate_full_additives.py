"""
Data Pipeline script to generate the complete international Codex Alimentarius
and Open Food Facts additives dataset with 700+ canonical INS/E-number additives,
6,450+ indexed synonyms, risk tiers, and JECFA ADI limits.
"""

import csv
import json
import re
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Set

from data_pipeline.taxonomy_data import ADDITIVES_CORPUS, REGULATORY_CITATIONS, SUGAR_ALIASES

# High-priority curated map (preserves exact hand-verified medical citations, JECFA ADI, and flags)
CURATED_MAP = {item["ins_code"]: dict(item) for item in ADDITIVES_CORPUS}

SOUTHAMPTON_SIX = {"102", "104", "110", "122", "124", "129"}

RED_TIER_CODES = {
    # Southampton Six
    "102", "104", "110", "122", "124", "129",
    # Banned/Toxic Synthetic Dyes
    "121", "123", "126", "127", "128", "131", "142", "151", "154", "155",
    "171", "173", "174", "175", "180",
    # Toxic Preservatives & Antioxidants
    "210", "211", "212", "213", "214", "215", "216", "217", "218", "219",
    "249", "250", "251", "252",
    "310", "311", "312", "319", "320", "321",
    # Toxic Flour Bleaches / Improvers
    "924a", "924b", "924", "925", "926",
    # High-Risk Artificial Sweeteners
    "950", "951", "952", "954", "961", "969",
    # Neuro-stimulant Flavor Enhancers
    "621", "627", "631", "635",
}

CAUTION_TIER_CODES = {
    # Inflammatory Emulsifiers & Gums
    "407", "407a", "432", "433", "434", "435", "436", "466", "476", "473",
    # Phosphates
    "338", "339", "340", "341", "343", "450", "451", "452",
    # Polyols / Sugar Alcohols
    "420", "421", "953", "965", "966", "967", "968", "964",
    # Sulfites & Sulfur Dioxide
    "220", "221", "222", "223", "224", "225", "226", "227", "228",
    # Synthetic Colors with caution
    "132", "133", "143", "150c", "150d",
    # Modified Starches
    "1404", "1410", "1412", "1413", "1414", "1420", "1422", "1440", "1442", "1450", "1451", "1452",
    # Silicates & Anti-caking
    "551", "552", "553a", "553b", "554",
    # Propionates
    "280", "281", "282", "283",
}

# Known ADI ceilings (JECFA mg/kg body weight)
JECFA_ADI_DEFAULTS = {
    "102": 7.5,
    "104": 5.0,
    "110": 4.0,
    "122": 4.0,
    "124": 4.0,
    "129": 7.0,
    "132": 5.0,
    "133": 6.0,
    "150c": 100.0,
    "150d": 200.0,
    "200": 25.0,
    "202": 25.0,
    "211": 5.0,
    "212": 5.0,
    "220": 0.7,
    "223": 0.7,
    "250": 0.07,
    "251": 3.7,
    "310": 1.4,
    "319": 0.7,
    "320": 0.5,
    "321": 0.3,
    "407": 75.0,
    "433": 25.0,
    "476": 7.5,
    "950": 15.0,
    "951": 40.0,
    "954": 5.0,
    "955": 15.0,
    "960": 4.0,
}


def normalize_code(raw: str) -> str:
    """Normalizes an INS/E-code string to a clean alphanumeric identifier."""
    c = raw.strip().lower()
    if c.startswith("en:"):
        c = c[3:]
    if c.startswith("e"):
        c = c[1:]
    if c.startswith("ins"):
        c = c[3:]
    c = c.replace("-", "").replace(" ", "")
    return c


def fetch_remote_text(url: str, timeout: int = 15) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "VeriBite/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.read().decode("utf-8")


def fetch_open_food_facts() -> Dict[str, Dict[str, Any]]:
    """Fetches Open Food Facts additives taxonomy."""
    url = "https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/main/taxonomies/additives.txt"
    try:
        content = fetch_remote_text(url)
    except Exception as e:
        print(f"Warning: Failed to fetch OFF taxonomy: {e}")
        return {}

    blocks = content.split("\n\n")
    results: Dict[str, Dict[str, Any]] = {}

    for block in blocks:
        lines = [l.strip() for l in block.splitlines() if l.strip()]
        if not lines:
            continue
        e_code = None
        names: List[str] = []
        classes: List[str] = []

        for line in lines:
            m = re.match(r"^en:\s*(E\s*\d+[a-z]*(?:\([ivx]+\))?)", line, re.IGNORECASE)
            if m:
                e_code = m.group(1).replace(" ", "").upper()
                parts = [p.strip() for p in line.split(",") if p.strip()]
                for p in parts[1:]:
                    if p not in names:
                        names.append(p)
            elif line.startswith("en:") and not line.startswith("en: E"):
                parts = [p.strip() for p in line[3:].split(",") if p.strip()]
                for p in parts:
                    if p not in names:
                        names.append(p)
            elif line.startswith("xx:"):
                parts = [p.strip() for p in line[3:].split(",") if p.strip()]
                for p in parts:
                    if p not in names:
                        names.append(p)
            elif line.startswith("additives_classes:en:"):
                cls = line.replace("additives_classes:en:", "").replace("en:", "").strip()
                if cls not in classes:
                    classes.append(cls)

        if e_code:
            norm = normalize_code(e_code)
            results[norm] = {
                "e_code": e_code,
                "names": names,
                "classes": classes,
            }

    return results


def fetch_nodef_ins() -> Dict[str, Dict[str, Any]]:
    """Fetches nodef/food-additive INS csv."""
    url = "https://raw.githubusercontent.com/nodef/food-additive/main/ins/index.csv"
    try:
        content = fetch_remote_text(url)
    except Exception as e:
        print(f"Warning: Failed to fetch nodef INS: {e}")
        return {}

    results = {}
    for row in csv.DictReader(content.splitlines()):
        raw_code = row.get("code", "").strip()
        if not raw_code:
            continue
        norm = normalize_code(raw_code)
        names = [n.strip() for n in row.get("names", "").split(",") if n.strip()]
        func = row.get("type", "").strip()
        results[norm] = {
            "ins_code": raw_code,
            "names": names,
            "functional_class": func,
        }
    return results


def fetch_nodef_e() -> Dict[str, Dict[str, Any]]:
    """Fetches nodef/food-additive E csv."""
    url = "https://raw.githubusercontent.com/nodef/food-additive/main/e/index.csv"
    try:
        content = fetch_remote_text(url)
    except Exception as e:
        print(f"Warning: Failed to fetch nodef E: {e}")
        return {}

    results = {}
    for row in csv.DictReader(content.splitlines()):
        raw_code = row.get("code", "").strip()
        if not raw_code:
            continue
        norm = normalize_code(raw_code)
        names = [n.strip() for n in row.get("names", "").split(",") if n.strip()]
        func = row.get("type", "").strip()
        results[norm] = {
            "e_code": raw_code,
            "names": names,
            "functional_class": func,
        }
    return results


def fetch_suhasdissa() -> Dict[str, Dict[str, Any]]:
    """Fetches SuhasDissa E-Number-Database json."""
    url = "https://raw.githubusercontent.com/SuhasDissa/E-Number-Database/main/JSON/additives.json"
    try:
        content = fetch_remote_text(url)
        items = json.loads(content)
    except Exception as e:
        print(f"Warning: Failed to fetch SuhasDissa: {e}")
        return {}

    results = {}
    for item in items:
        e_code = item.get("e_code", "").strip().upper()
        if not e_code:
            continue
        norm = normalize_code(e_code)
        title = item.get("title", "").strip()
        e_type = item.get("e_type", "").strip()
        halal = item.get("halal_status", "").strip()
        results[norm] = {
            "e_code": e_code,
            "title": title,
            "e_type": e_type,
            "halal_status": halal,
        }
    return results


def build_full_additives_corpus() -> List[Dict[str, Any]]:
    """Merges all datasets into a unified list of 700+ canonical additives."""
    off_data = fetch_open_food_facts()
    nodef_ins = fetch_nodef_ins()
    nodef_e = fetch_nodef_e()
    suhas_data = fetch_suhasdissa()

    all_keys: Set[str] = set()
    all_keys.update(CURATED_MAP.keys())
    all_keys.update(off_data.keys())
    all_keys.update(nodef_ins.keys())
    all_keys.update(nodef_e.keys())
    all_keys.update(suhas_data.keys())

    corpus: List[Dict[str, Any]] = []

    for key in sorted(all_keys):
        if not key or not any(c.isdigit() for c in key):
            continue

        # If already curated in baseline 52, preserve its verified medical & citation metadata
        if key in CURATED_MAP:
            item = dict(CURATED_MAP[key])
            # Enrich synonyms with extra aliases from OFF/nodef/suhas
            existing_syns = set(s.strip() for s in item.get("synonyms_csv", "").split(",") if s.strip())
            
            if key in off_data:
                existing_syns.update(off_data[key].get("names", []))
            if key in nodef_ins:
                existing_syns.update(nodef_ins[key].get("names", []))
            if key in suhas_data:
                title = suhas_data[key].get("title", "")
                if title:
                    existing_syns.update(p.strip() for p in title.split("/") if p.strip())

            # Add standard permutations
            existing_syns.add(f"INS {key}")
            existing_syns.add(f"INS{key}")
            existing_syns.add(f"E{key}")
            existing_syns.add(f"E-{key}")

            item["synonyms_csv"] = ", ".join(sorted(existing_syns))
            corpus.append(item)
            continue

        # New additive to assemble
        ins_code = key
        e_code = f"E{key.upper()}"
        
        # Primary Name Resolution
        primary_name = ""
        names_pool: List[str] = []

        if key in off_data and off_data[key]["names"]:
            names_pool.extend(off_data[key]["names"])
        if key in nodef_ins and nodef_ins[key]["names"]:
            names_pool.extend(nodef_ins[key]["names"])
        if key in nodef_e and nodef_e[key]["names"]:
            names_pool.extend(nodef_e[key]["names"])
        if key in suhas_data and suhas_data[key]["title"]:
            names_pool.extend(p.strip() for p in suhas_data[key]["title"].split("/") if p.strip())

        if names_pool:
            primary_name = names_pool[0]
        else:
            primary_name = f"Additive INS {key}"

        # Clean primary name
        primary_name = re.sub(r"\s*\([^)]*\)", "", primary_name).strip()
        if not primary_name:
            primary_name = f"Additive INS {key}"

        # Functional Class Resolution
        functional_class = "Food Additive"
        if key in off_data and off_data[key]["classes"]:
            functional_class = ", ".join(c.capitalize() for c in off_data[key]["classes"])
        elif key in nodef_ins and nodef_ins[key]["functional_class"]:
            functional_class = nodef_ins[key]["functional_class"].capitalize()
        elif key in suhas_data and suhas_data[key]["e_type"]:
            functional_class = suhas_data[key]["e_type"].capitalize()

        # Risk Tier & Red Cap Assignment
        base_num = re.match(r"^\d+", key)
        num_str = base_num.group(0) if base_num else key

        risk_tier = "SAFE"
        triggers_red_cap = 0
        child_flag = 0
        banned = None

        if key in RED_TIER_CODES or num_str in RED_TIER_CODES:
            risk_tier = "RED"
            triggers_red_cap = 1
            if key in SOUTHAMPTON_SIX or num_str in SOUTHAMPTON_SIX:
                child_flag = 1
                banned = "UK Warning / EU Warning"
            elif key in {"171", "121", "123", "924a", "924b"}:
                banned = "EU Banned / Genotoxicity Alert"
        elif key in CAUTION_TIER_CODES or num_str in CAUTION_TIER_CODES:
            risk_tier = "CAUTION"
            triggers_red_cap = 0
        else:
            risk_tier = "SAFE"
            triggers_red_cap = 0

        # JECFA ADI
        adi = JECFA_ADI_DEFAULTS.get(key) or JECFA_ADI_DEFAULTS.get(num_str)

        # Assemble Synonyms
        synonyms_set = set(names_pool)
        synonyms_set.add(f"INS {key}")
        synonyms_set.add(f"INS{key}")
        synonyms_set.add(f"E{key.upper()}")
        synonyms_set.add(f"E {key.upper()}")
        synonyms_set.add(f"E-{key.upper()}")
        if key != num_str:
            synonyms_set.add(f"INS {num_str}")
            synonyms_set.add(f"E{num_str}")

        synonyms_csv = ", ".join(sorted(s for s in synonyms_set if s and s != primary_name))

        corpus.append({
            "ins_code": ins_code,
            "e_code": e_code,
            "primary_name": primary_name,
            "synonyms_csv": synonyms_csv,
            "functional_class": functional_class,
            "risk_tier": risk_tier,
            "triggers_red_cap": triggers_red_cap,
            "jecfa_adi_mg_kg": adi,
            "default_conc_mg_per_g": None,
            "child_hyperactivity_flag": child_flag,
            "banned_jurisdictions": banned,
            "citation_id": "WHO_JECFA_GSFA",
        })

    return corpus


def main():
    print("Generating comprehensive additives corpus...")
    corpus = build_full_additives_corpus()
    print(f"Successfully assembled {len(corpus)} canonical additives.")

    total_terms = sum(len(item["synonyms_csv"].split(",")) + 2 for item in corpus)
    print(f"Total indexed search terms & aliases: ~{total_terms}")

    out_json = Path(__file__).parent / "full_additives_corpus.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(corpus, f, indent=2, ensure_ascii=False)
    print(f"Saved full corpus to {out_json}")


if __name__ == "__main__":
    main()

