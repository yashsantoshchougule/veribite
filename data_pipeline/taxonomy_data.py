"""Authoritative taxonomy definitions for 60 canonical hidden sweetener aliases,
authoritative regulatory citations, and primary food additives.
"""

SUGAR_ALIASES = [
    # Group A — Industrial Syrups & Concentrates (14)
    {"canonical_name": "Liquid Glucose", "category": "Group A", "glycemic_index": 100},
    {"canonical_name": "Corn Syrup", "category": "Group A", "glycemic_index": 90},
    {"canonical_name": "High-Fructose Corn Syrup (HFCS)", "category": "Group A", "glycemic_index": 87},
    {"canonical_name": "Invert Sugar Syrup", "category": "Group A", "glycemic_index": 65},
    {"canonical_name": "Golden Syrup", "category": "Group A", "glycemic_index": 60},
    {"canonical_name": "Malt Syrup", "category": "Group A", "glycemic_index": 89},
    {"canonical_name": "Brown Rice Syrup", "category": "Group A", "glycemic_index": 98},
    {"canonical_name": "Agave Nectar", "category": "Group A", "glycemic_index": 30},
    {"canonical_name": "Maple Syrup", "category": "Group A", "glycemic_index": 54},
    {"canonical_name": "Sorghum Syrup", "category": "Group A", "glycemic_index": 65},
    {"canonical_name": "Refiners Syrup", "category": "Group A", "glycemic_index": 70},
    {"canonical_name": "Carob Syrup", "category": "Group A", "glycemic_index": 40},
    {"canonical_name": "Tapioca Syrup", "category": "Group A", "glycemic_index": 70},
    {"canonical_name": "Glucose-Fructose Syrup", "category": "Group A", "glycemic_index": 85},

    # Group B — Starch & Malt Hydrolysates (11)
    {"canonical_name": "Maltodextrin", "category": "Group B", "glycemic_index": 110},
    {"canonical_name": "Dextrin", "category": "Group B", "glycemic_index": 95},
    {"canonical_name": "Dextri-Maltose", "category": "Group B", "glycemic_index": 105},
    {"canonical_name": "Barley Malt Extract", "category": "Group B", "glycemic_index": 80},
    {"canonical_name": "Malted Barley Flour", "category": "Group B", "glycemic_index": 70},
    {"canonical_name": "Hydrolyzed Corn Starch", "category": "Group B", "glycemic_index": 95},
    {"canonical_name": "Modified Food Starch (Sweetener grade)", "category": "Group B", "glycemic_index": 85},
    {"canonical_name": "Dextrose Monohydrate", "category": "Group B", "glycemic_index": 100},
    {"canonical_name": "Anhydrous Dextrose", "category": "Group B", "glycemic_index": 100},
    {"canonical_name": "Maltose", "category": "Group B", "glycemic_index": 105},
    {"canonical_name": "Isomaltose", "category": "Group B", "glycemic_index": 60},

    # Group C — Crystalline & Refined Mono/Disaccharides (13)
    {"canonical_name": "Sugar", "category": "Group C", "glycemic_index": 65},
    {"canonical_name": "Sucrose", "category": "Group C", "glycemic_index": 65},
    {"canonical_name": "Crystalline Fructose", "category": "Group C", "glycemic_index": 25},
    {"canonical_name": "Galactose", "category": "Group C", "glycemic_index": 25},
    {"canonical_name": "Lactose", "category": "Group C", "glycemic_index": 46},
    {"canonical_name": "Trehalose", "category": "Group C", "glycemic_index": 70},
    {"canonical_name": "Castor Sugar", "category": "Group C", "glycemic_index": 65},
    {"canonical_name": "Icing Sugar", "category": "Group C", "glycemic_index": 68},
    {"canonical_name": "Confectioners Sugar", "category": "Group C", "glycemic_index": 68},
    {"canonical_name": "Demerara Sugar", "category": "Group C", "glycemic_index": 65},
    {"canonical_name": "Turbinado Sugar", "category": "Group C", "glycemic_index": 65},
    {"canonical_name": "Muscovado Sugar", "category": "Group C", "glycemic_index": 65},
    {"canonical_name": "Caramelized Sugar", "category": "Group C", "glycemic_index": 60},
    {"canonical_name": "Burnt Sugar", "category": "Group C", "glycemic_index": 60},

    # Group D — Indian Regional & Unrefined Sweeteners (12)
    {"canonical_name": "Jaggery (Gur)", "category": "Group D", "glycemic_index": 84},
    {"canonical_name": "Jaggery Solids", "category": "Group D", "glycemic_index": 84},
    {"canonical_name": "Khandsari (Khand)", "category": "Group D", "glycemic_index": 80},
    {"canonical_name": "Bura Sugar", "category": "Group D", "glycemic_index": 78},
    {"canonical_name": "Mishri (Rock Sugar)", "category": "Group D", "glycemic_index": 75},
    {"canonical_name": "Palm Jaggery (Karupatti)", "category": "Group D", "glycemic_index": 50},
    {"canonical_name": "Coconut Sugar", "category": "Group D", "glycemic_index": 54},
    {"canonical_name": "Date Palm Syrup", "category": "Group D", "glycemic_index": 55},
    {"canonical_name": "Cane Juice Solids", "category": "Group D", "glycemic_index": 70},
    {"canonical_name": "Evaporated Cane Juice", "category": "Group D", "glycemic_index": 65},
    {"canonical_name": "Dehydrated Cane Juice", "category": "Group D", "glycemic_index": 65},
    {"canonical_name": "Honey", "category": "Group D", "glycemic_index": 61},

    # Group E — Fruit Concentrates & Sugar Alcohols / Non-Nutritive Flagged (10)
    {"canonical_name": "Deionized Fruit Juice Concentrate", "category": "Group E", "glycemic_index": 70},
    {"canonical_name": "Apple/Pear/Grape Juice Concentrate", "category": "Group E", "glycemic_index": 65},
    {"canonical_name": "Sorbitol (INS 420)", "category": "Group E", "glycemic_index": 9},
    {"canonical_name": "Mannitol (INS 421)", "category": "Group E", "glycemic_index": 2},
    {"canonical_name": "Xylitol (INS 967)", "category": "Group E", "glycemic_index": 12},
    {"canonical_name": "Erythritol (INS 968)", "category": "Group E", "glycemic_index": 1},
    {"canonical_name": "Maltitol (INS 965)", "category": "Group E", "glycemic_index": 35},
    {"canonical_name": "Isomalt (INS 953)", "category": "Group E", "glycemic_index": 9},
    {"canonical_name": "Sucralose (INS 955)", "category": "Group E", "glycemic_index": 0},
    {"canonical_name": "Acesulfame Potassium (INS 950)", "category": "Group E", "glycemic_index": 0},
]

REGULATORY_CITATIONS = [
    {
        "citation_id": "WHO_SUGAR_2015",
        "authority": "WHO",
        "doc_title": "Guideline: Sugars intake for adults and children (2015)",
        "verified_passage": "WHO recommends a reduced intake of free sugars throughout the lifecourse. In both adults and children, WHO recommends reducing the intake of free sugars to less than 10% of total energy intake, with a conditional recommendation below 5% (~25g/day).",
        "source_url": "https://www.who.int/publications/i/item/9789241549028"
    },
    {
        "citation_id": "FSSAI_LABELLING_2020",
        "authority": "FSSAI",
        "doc_title": "Food Safety and Standards (Labelling and Display) Regulations, 2020",
        "verified_passage": "Ingredients shall be listed in descending order of their ingoing weight (m/m) at the time of manufacture of the food. Sweeteners, flavours and colours must carry mandatory declarations.",
        "source_url": "https://www.fssai.gov.in"
    },
    {
        "citation_id": "JECFA_TARTRAZINE_2016",
        "authority": "JECFA",
        "doc_title": "Toxicological Evaluation of Certain Food Additives - Tartrazine (INS 102)",
        "verified_passage": "Acceptable Daily Intake (ADI) of 0-7.5 mg/kg bw established. Synthetic azo dyes are associated with hypersensitivity and intolerance reactions in sensitive individuals.",
        "source_url": "https://apps.who.int/food-additives-contaminants-jecfa-database/"
    },
    {
        "citation_id": "EFSA_SOUTHAMPTON_2008",
        "authority": "EFSA",
        "doc_title": "Scientific Opinion on Southampton study on food colours and hyperactivity in children",
        "verified_passage": "Mixtures of synthetic colours (Tartrazine E102, Quinoline Yellow E104, Sunset Yellow E110, Carmoisine E122, Ponceau 4R E124, Allura Red E129) combined with sodium benzoate resulted in increased hyperactivity in 3-year-old and 8/9-year-old children.",
        "source_url": "https://www.efsa.europa.eu/en/efsajournal/pub/660"
    },
    {
        "citation_id": "JECFA_SUNSET_YELLOW_2011",
        "authority": "JECFA",
        "doc_title": "Sunset Yellow FCF (INS 110) Toxicological Monograph",
        "verified_passage": "ADI of 0-4.0 mg/kg bw allocated by JECFA at its 74th meeting (2011). Maximum permitted levels in foods must strictly protect child body weight ceilings.",
        "source_url": "https://apps.who.int/food-additives-contaminants-jecfa-database/"
    },
    {
        "citation_id": "JECFA_SODIUM_BENZOATE_2021",
        "authority": "JECFA",
        "doc_title": "Benzoic acid and its salts (INS 210-213)",
        "verified_passage": "ADI of 0-5.0 mg/kg bw as benzoic acid. Can form traces of benzene in the presence of ascorbic acid (Vitamin C) under heat and light.",
        "source_url": "https://apps.who.int/food-additives-contaminants-jecfa-database/"
    }
]
