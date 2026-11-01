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

ADDITIVES_CORPUS = [
    # Southampton Six Azo Dyes (RED Tier, triggers_red_cap=1, child_hyperactivity_flag=1)
    {
        "ins_code": "102", "e_code": "E102", "primary_name": "Tartrazine",
        "synonyms_csv": "FD&C Yellow No. 5, CI 19140, Acid Yellow 23",
        "functional_class": "Colour", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 7.5, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 1, "banned_jurisdictions": "Norway, Austria (formerly)",
        "citation_id": "JECFA_TARTRAZINE_2016"
    },
    {
        "ins_code": "104", "e_code": "E104", "primary_name": "Quinoline Yellow",
        "synonyms_csv": "Food Yellow 13, CI 47005",
        "functional_class": "Colour", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 0.5, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 1, "banned_jurisdictions": "US, Japan, Norway, Australia",
        "citation_id": "EFSA_SOUTHAMPTON_2008"
    },
    {
        "ins_code": "110", "e_code": "E110", "primary_name": "Sunset Yellow FCF",
        "synonyms_csv": "FD&C Yellow No. 6, Orange Yellow S, CI 15985",
        "functional_class": "Colour", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 4.0, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 1, "banned_jurisdictions": "Norway, Finland",
        "citation_id": "JECFA_SUNSET_YELLOW_2011"
    },
    {
        "ins_code": "122", "e_code": "E122", "primary_name": "Azorubine (Carmoisine)",
        "synonyms_csv": "Carmoisine, Food Red 3, CI 14720",
        "functional_class": "Colour", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 4.0, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 1, "banned_jurisdictions": "US, Canada, Japan, Norway",
        "citation_id": "EFSA_SOUTHAMPTON_2008"
    },
    {
        "ins_code": "124", "e_code": "E124", "primary_name": "Ponceau 4R",
        "synonyms_csv": "Cochineal Red A, Food Red 7, CI 16255",
        "functional_class": "Colour", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 4.0, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 1, "banned_jurisdictions": "US, Norway",
        "citation_id": "EFSA_SOUTHAMPTON_2008"
    },
    {
        "ins_code": "129", "e_code": "E129", "primary_name": "Allura Red AC",
        "synonyms_csv": "FD&C Red No. 40, Food Red 17, CI 16035",
        "functional_class": "Colour", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 7.0, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 1, "banned_jurisdictions": "Denmark, Belgium, France, Switzerland",
        "citation_id": "EFSA_SOUTHAMPTON_2008"
    },

    # Other Red-Tier Additives & Severe Preservatives (triggers_red_cap=1)
    {
        "ins_code": "127", "e_code": "E127", "primary_name": "Erythrosine",
        "synonyms_csv": "FD&C Red No. 3, CI 45430",
        "functional_class": "Colour", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 0.1, "default_conc_mg_per_g": 0.05,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "Partial EU restrictions",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "133", "e_code": "E133", "primary_name": "Brilliant Blue FCF",
        "synonyms_csv": "FD&C Blue No. 1, Acid Blue 9, CI 42090",
        "functional_class": "Colour", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 6.0, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "150d", "e_code": "E150d", "primary_name": "Sulphite Ammonia Caramel (Caramel IV)",
        "synonyms_csv": "Caramel IV, 4-MEI Caramel Colour",
        "functional_class": "Colour", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 200.0, "default_conc_mg_per_g": 2.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "320", "e_code": "E320", "primary_name": "Butylated Hydroxyanisole (BHA)",
        "synonyms_csv": "BHA, tert-butyl-4-hydroxyanisole",
        "functional_class": "Antioxidant", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 0.5, "default_conc_mg_per_g": 0.2,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "Japan",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "321", "e_code": "E321", "primary_name": "Butylated Hydroxytoluene (BHT)",
        "synonyms_csv": "BHT, 2,6-di-tert-butyl-4-methylphenol",
        "functional_class": "Antioxidant", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 0.3, "default_conc_mg_per_g": 0.2,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "Japan, Australia",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "249", "e_code": "E249", "primary_name": "Potassium Nitrite",
        "synonyms_csv": "Nitrite of potassium",
        "functional_class": "Preservative", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 0.07, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "250", "e_code": "E250", "primary_name": "Sodium Nitrite",
        "synonyms_csv": "Nitrite of sodium",
        "functional_class": "Preservative", "risk_tier": "RED", "triggers_red_cap": 1,
        "jecfa_adi_mg_kg": 0.07, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },

    # Caution-Tier Additives (Preservatives, Sweeteners, Flavour Enhancers)
    {
        "ins_code": "211", "e_code": "E211", "primary_name": "Sodium Benzoate",
        "synonyms_csv": "Benzoate of soda",
        "functional_class": "Preservative", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 5.0, "default_conc_mg_per_g": 0.5,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "JECFA_SODIUM_BENZOATE_2021"
    },
    {
        "ins_code": "202", "e_code": "E202", "primary_name": "Potassium Sorbate",
        "synonyms_csv": "Sorbate of potassium",
        "functional_class": "Preservative", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 25.0, "default_conc_mg_per_g": 1.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "222", "e_code": "E222", "primary_name": "Sodium Hydrogen Sulphite (Sodium Bisulphite)",
        "synonyms_csv": "Sodium bisulphite",
        "functional_class": "Preservative", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 0.7, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "223", "e_code": "E223", "primary_name": "Sodium Metabisulphite",
        "synonyms_csv": "Sodium pyrosulphite",
        "functional_class": "Preservative", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 0.7, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "282", "e_code": "E282", "primary_name": "Calcium Propionate",
        "synonyms_csv": "Propionate of calcium",
        "functional_class": "Preservative", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 2.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "621", "e_code": "E621", "primary_name": "Monosodium Glutamate (MSG)",
        "synonyms_csv": "MSG, Sodium glutamate, Ajinomoto",
        "functional_class": "Flavour Enhancer", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "627", "e_code": "E627", "primary_name": "Disodium Guanylate",
        "synonyms_csv": "Sodium guanylate, GMP",
        "functional_class": "Flavour Enhancer", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 0.5,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "631", "e_code": "E631", "primary_name": "Disodium Inosinate",
        "synonyms_csv": "Sodium inosinate, IMP",
        "functional_class": "Flavour Enhancer", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 0.5,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "635", "e_code": "E635", "primary_name": "Disodium 5'-Ribonucleotides",
        "synonyms_csv": "Sodium 5'-ribonucleotide",
        "functional_class": "Flavour Enhancer", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 0.5,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "950", "e_code": "E950", "primary_name": "Acesulfame Potassium (Ace-K)",
        "synonyms_csv": "Acesulfame K, Potassium acesulfame",
        "functional_class": "Sweetener", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 15.0, "default_conc_mg_per_g": 0.3,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "951", "e_code": "E951", "primary_name": "Aspartame",
        "synonyms_csv": "NutraSweet, Equal",
        "functional_class": "Sweetener", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 40.0, "default_conc_mg_per_g": 0.6,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "955", "e_code": "E955", "primary_name": "Sucralose",
        "synonyms_csv": "Splenda, Trichlorosucrose",
        "functional_class": "Sweetener", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 15.0, "default_conc_mg_per_g": 0.3,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "960", "e_code": "E960", "primary_name": "Steviol Glycosides (Stevia)",
        "synonyms_csv": "Stevia extract, Reb-A",
        "functional_class": "Sweetener", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 4.0, "default_conc_mg_per_g": 0.2,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },

    # Safe-Tier Additives (GMP Safe / Leavening / Emulsifiers / Acidity Regulators)
    {
        "ins_code": "330", "e_code": "E330", "primary_name": "Citric Acid",
        "synonyms_csv": "2-hydroxypropane-1,2,3-tricarboxylic acid",
        "functional_class": "Acidity Regulator", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "300", "e_code": "E300", "primary_name": "Ascorbic Acid (Vitamin C)",
        "synonyms_csv": "Vitamin C, L-ascorbic acid",
        "functional_class": "Antioxidant", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 2.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "322", "e_code": "E322", "primary_name": "Lecithins (Soy/Sunflower)",
        "synonyms_csv": "Soy lecithin, Phosphatidylcholine, INS 322(i)",
        "functional_class": "Emulsifier", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "412", "e_code": "E412", "primary_name": "Guar Gum",
        "synonyms_csv": "Cyamopsis tetragonoloba gum",
        "functional_class": "Thickener", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "415", "e_code": "E415", "primary_name": "Xanthan Gum",
        "synonyms_csv": "Corn sugar gum",
        "functional_class": "Thickener", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "440", "e_code": "E440", "primary_name": "Pectins",
        "synonyms_csv": "Pectin, INS 440i",
        "functional_class": "Gelling Agent", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "500", "e_code": "E500", "primary_name": "Sodium Carbonates",
        "synonyms_csv": "Baking soda, Sodium bicarbonate, INS 500(i), INS 500(ii)",
        "functional_class": "Raising Agent", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "500ii", "e_code": "E500ii", "primary_name": "Sodium Hydrogen Carbonate (Baking Soda)",
        "synonyms_csv": "Sodium bicarbonate, Baking soda, INS 500ii",
        "functional_class": "Raising Agent", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "503", "e_code": "E503", "primary_name": "Ammonium Carbonates",
        "synonyms_csv": "Bakers ammonia, INS 503(i), INS 503(ii)",
        "functional_class": "Raising Agent", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "503ii", "e_code": "E503ii", "primary_name": "Ammonium Hydrogen Carbonate",
        "synonyms_csv": "Ammonium bicarbonate, INS 503ii",
        "functional_class": "Raising Agent", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "450", "e_code": "E450", "primary_name": "Diphosphates",
        "synonyms_csv": "Sodium acid pyrophosphate, SAPP, INS 450(i)",
        "functional_class": "Raising Agent", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 70.0, "default_conc_mg_per_g": 3.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "471", "e_code": "E471", "primary_name": "Mono- and Diglycerides of Fatty Acids",
        "synonyms_csv": "Glyceryl monostearate, GMS",
        "functional_class": "Emulsifier", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "472e", "e_code": "E472e", "primary_name": "DATEM (Diacetyl Tartaric Acid Esters of Mono- and Diglycerides)",
        "synonyms_csv": "DATEM, Dough conditioner",
        "functional_class": "Emulsifier", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 50.0, "default_conc_mg_per_g": 3.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "160a", "e_code": "E160a", "primary_name": "Carotenes (Beta-Carotene)",
        "synonyms_csv": "Beta-carotene, Provitamin A",
        "functional_class": "Colour", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 5.0, "default_conc_mg_per_g": 0.1,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "1400", "e_code": "E1400", "primary_name": "Dextrins, Roasted Starch",
        "synonyms_csv": "White dextrin, Yellow dextrin",
        "functional_class": "Thickener", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 10.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "1422", "e_code": "E1422", "primary_name": "Acetylated Distarch Adipate",
        "synonyms_csv": "Modified starch",
        "functional_class": "Stabilizer", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 10.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "508", "e_code": "E508", "primary_name": "Potassium Chloride",
        "synonyms_csv": "Potassium salt, Salt substitute",
        "functional_class": "Flavour Enhancer", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "170", "e_code": "E170", "primary_name": "Calcium Carbonates",
        "synonyms_csv": "Calcium carbonate, Chalk, INS 170(i)",
        "functional_class": "Acidity Regulator", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "296", "e_code": "E296", "primary_name": "Malic Acid",
        "synonyms_csv": "DL-malic acid",
        "functional_class": "Acidity Regulator", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "334", "e_code": "E334", "primary_name": "Tartaric Acid",
        "synonyms_csv": "L(+)-tartaric acid",
        "functional_class": "Acidity Regulator", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 30.0, "default_conc_mg_per_g": 3.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "331", "e_code": "E331", "primary_name": "Sodium Citrates",
        "synonyms_csv": "Trisodium citrate, INS 331(iii)",
        "functional_class": "Acidity Regulator", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "339", "e_code": "E339", "primary_name": "Sodium Phosphates",
        "synonyms_csv": "Monosodium phosphate, Disodium phosphate",
        "functional_class": "Acidity Regulator", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 70.0, "default_conc_mg_per_g": 3.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "407", "e_code": "E407", "primary_name": "Carrageenan",
        "synonyms_csv": "Irish moss gelose",
        "functional_class": "Gelling Agent", "risk_tier": "CAUTION", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 3.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "466", "e_code": "E466", "primary_name": "Sodium Carboxy Methyl Cellulose",
        "synonyms_csv": "CMC, Cellulose gum",
        "functional_class": "Thickener", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 5.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "903", "e_code": "E903", "primary_name": "Carnauba Wax",
        "synonyms_csv": "Brazil wax",
        "functional_class": "Glazing Agent", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": 7.0, "default_conc_mg_per_g": 0.5,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    },
    {
        "ins_code": "904", "e_code": "E904", "primary_name": "Shellac",
        "synonyms_csv": "Confectioners glaze",
        "functional_class": "Glazing Agent", "risk_tier": "SAFE", "triggers_red_cap": 0,
        "jecfa_adi_mg_kg": None, "default_conc_mg_per_g": 1.0,
        "child_hyperactivity_flag": 0, "banned_jurisdictions": "",
        "citation_id": "FSSAI_LABELLING_2020"
    }
]
