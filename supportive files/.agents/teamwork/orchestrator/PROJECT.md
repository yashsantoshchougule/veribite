# Project: Page 1 Onboarding Mockup Generation

## Architecture & Design Guidelines
- **Platform**: Mobile (Android / Flutter Material 3 Design Guidelines)
- **Aspect Ratio**: 9:16 mobile portrait (e.g. 1080x1920 or native 9:16)
- **Color Theme**: Emerald Green seed `#0F9D58` / Primary `#006C4C`, Primary Container `#8CF7C8`, Surface `#FBFDF9`, Surface Container Low `#F5F7F3`, Outline `#717973`
- **Typography Scale**: Material 3 typography tokens (DisplaySmall, HeadlineMedium, TitleMedium, BodyLarge, LabelLarge)
- **Output Target**: `c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg`

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Material 3 Mobile Layout | 9:16 mobile canvas with status bar, app bar ("Safety Profile Setup"), hero card, form controls, bottom action zone | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Adult / Child Mode Toggle | Segmented button indicating Adult (65kg) active and Child (20kg) inactive | M1 | ORIGINAL_REQUEST §R2 |
| 3 | Interactive Weight Slider | 15–120 kg slider with boundary labels and 65 kg badge readout | M1 | ORIGINAL_REQUEST §R2 |
| 4 | 5-Language Selector Chips | Choice chips for English, Hindi (हिंदी), Marathi (मराठी), Tamil (தமிழ்), Telugu (తెలుగు) | M1 | ORIGINAL_REQUEST §R2 |
| 5 | Dual Prominent CTAs | Primary "Save & Open Dashboard" (filled green) and Secondary "Instant Scan Now" (outlined) | M1 | ORIGINAL_REQUEST §R2 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | UI Asset Generation & Verification | Generate `01_onboarding_v2_refined.jpg` adhering to all M3 specs and execute multi-agent verification | Survey complete | IN_PROGRESS |

## Interface Contracts & Asset Requirements
- **File Name**: `01_onboarding_v2_refined.jpg`
- **Location**: Project workspace root `c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg`
- **Aspect Ratio**: Exactly 9:16
- **Content Verification**:
  - Visible Adult (65kg) / Child (20kg) toggle
  - Visible 15–120 kg weight slider
  - Visible 5 language chips (English, Hindi, Marathi, Tamil, Telugu)
  - Visible Primary CTA ("Save & Open Dashboard") and Secondary CTA ("Instant Scan Now")
