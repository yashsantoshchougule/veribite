import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/health_intelligence/domain/health_intelligence_model.dart';

void main() {
  group('HealthIntelligence Model Tests', () {
    test('serializes and deserializes Hamdard Safi herbal intelligence correctly', () {
      const safiIntelligence = HealthIntelligence(
        domain: ProductCategoryDomain.ayurvedicHerbalTonic,
        extendedNutrients: ExtendedNutrients(
          addedSugarsG: 22.0,
          totalFatG: 0.0,
          proteinG: 0.2,
          carbsG: 24.0,
          caffeineMg: 0.0,
          glycemicLoadEstimate: 'High (Invert Sugar Base)',
        ),
        bioactiveCompounds: [
          BioactiveCompound(
            name: 'Senna (Cassia angustifolia / Sennosides A & B)',
            botanicalOrChemicalName: 'Cassia angustifolia',
            functionCategory: 'Stimulant Laxative',
            riskLevel: 'caution_chronic_use',
            physiologicalEffect:
                'Stimulates enteric nerves to induce rapid colonic peristalsis. Chronic daily use causes laxative dependence, hypokalemia, and melanosis coli.',
            triggersChronicUseWarning: true,
          ),
          BioactiveCompound(
            name: 'Turbud (Operculina turpethum)',
            botanicalOrChemicalName: 'Operculina turpethum',
            functionCategory: 'Drastic Purgative Herb',
            riskLevel: 'moderate',
            physiologicalEffect: 'Traditional purgative resin increasing intestinal motility and fluid secretion.',
          ),
          BioactiveCompound(
            name: 'Neem (Azadirachta indica)',
            botanicalOrChemicalName: 'Azadirachta indica',
            functionCategory: 'Bitter Antimicrobial Botanical',
            riskLevel: 'low',
            physiologicalEffect: 'Bitter glycosides with traditional antimicrobial properties.',
          ),
        ],
        organImpact: OrganAndSystemImpact(
          gutAndDigestion:
              'Potent stimulant laxative effect; induces watery bowel movements and alters colonic smooth muscle tone.',
          liverAndMetabolism: 'Processes complex bitter phytocompounds; potential hepatic strain with excessive intake.',
          kidneyAndElectrolytes:
              'Fluid excretion risks potassium depletion and dehydration if taken continuously without electrolyte replenishment.',
          cardiovascularAndNervous: 'Secondary risk of arrhythmia if severe potassium depletion occurs from chronic purging.',
        ),
        contraindications: ContraindicationsAndWarnings(
          pregnancyBreastfeeding: 'STRICT CONTRAINDICATION: Senna induces uterine contractions and may trigger miscarriage.',
          children: 'Not recommended for children under 12 years without pediatric oversight.',
          diabetics: 'Formulated in a heavy sucrose/invert sugar syrup base (adds hidden liquid sugar).',
          sensitiveGutIbs: 'May cause severe abdominal cramping, spasms, and diarrhea.',
          chronicUseDuration: 'Strict maximum: 7-14 consecutive days. Never consume as a daily lifestyle drink.',
        ),
        claimsVsReality: [
          ClaimVsClinicalReality(
            claim: 'Purifies blood and clears skin from inside',
            reality:
                'Traditional Unani concept; modern medicine demonstrates no blood-purifying mechanism. Any skin improvement is secondary to bowel regulation.',
            evidenceLevel: 'misleading_marketing',
          ),
          ClaimVsClinicalReality(
            claim: 'Helps with weight loss and belly reduction',
            reality: 'Immediate scale drop is strictly water, stool, and electrolyte loss from Senna laxation, NOT body fat reduction.',
            evidenceLevel: 'misleading_marketing',
          ),
        ],
        internetGroundedSources: [
          'ncbi.nlm.nih.gov/pmc/articles/PMC6152709',
          'ayush.gov.in/safety-guidelines',
          'who.int/monographs/senna-leaf',
        ],
        safetyAdvisories: [
          'Chronic Laxative Dependence Warning: Limit usage to short episodic bouts (max 10-14 days).',
          'Avoid during pregnancy or if taking cardiac glycosides/diuretics.',
        ],
        isGrounded: true,
        clinicalSummary:
            'Hamdard Safi is a potent Senna-dominant stimulant laxative formulated in sugar syrup. Unsuitable for chronic daily wellness.',
      );

      final jsonMap = safiIntelligence.toJson();
      final serialized = jsonEncode(jsonMap);
      final deserialized = HealthIntelligence.fromJsonString(serialized);

      expect(deserialized, isNotNull);
      expect(deserialized!.domain, ProductCategoryDomain.ayurvedicHerbalTonic);
      expect(deserialized.hasBioactiveRisk, isTrue);
      expect(deserialized.isNonStandardFood, isTrue);
      expect(deserialized.bioactiveCompounds.length, 3);
      expect(deserialized.bioactiveCompounds.first.triggersChronicUseWarning, isTrue);
      expect(deserialized.contraindications.pregnancyBreastfeeding, contains('STRICT CONTRAINDICATION'));
      expect(deserialized.claimsVsReality.length, 2);
      expect(deserialized.internetGroundedSources.length, 3);
    });

    test('default HealthIntelligence represents standard food safely', () {
      const standard = HealthIntelligence();
      expect(standard.domain, ProductCategoryDomain.standardFood);
      expect(standard.hasBioactiveRisk, isFalse);
      expect(standard.isNonStandardFood, isFalse);
      expect(standard.bioactiveCompounds, isEmpty);
      expect(standard.organImpact.hasAnyImpact, isFalse);
      expect(standard.contraindications.hasAnyWarning, isFalse);
    });
  });
}
