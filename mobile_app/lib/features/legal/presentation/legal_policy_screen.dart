import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../onboarding/presentation/widgets/watermark_painter.dart';

/// Active tab on the Legal & Privacy Policy Screen
enum LegalTab {
  terms,
  privacy,
}

/// Dedicated, comprehensive Legal & Privacy Command Center for VeriBite.
/// Provides tailored Terms & Conditions and Privacy Policy covering food scanning,
/// toxicology disclaimers, allergen limitations, and camera/biometric data protection.
class LegalPolicyScreen extends StatefulWidget {
  final LegalTab initialTab;

  const LegalPolicyScreen({
    super.key,
    this.initialTab = LegalTab.terms,
  });

  @override
  State<LegalPolicyScreen> createState() => _LegalPolicyScreenState();
}

class _LegalPolicyScreenState extends State<LegalPolicyScreen> {
  late LegalTab _activeTab;
  final ScrollController _scrollController = ScrollController();

  // GlobalKeys for quick jumping to sections
  final GlobalKey _termsMedicalKey = GlobalKey();
  final GlobalKey _termsCeilingsKey = GlobalKey();
  final GlobalKey _termsAllergensKey = GlobalKey();
  final GlobalKey _termsFairUseKey = GlobalKey();
  final GlobalKey _termsLiabilityKey = GlobalKey();

  final GlobalKey _privacyZeroTrackKey = GlobalKey();
  final GlobalKey _privacyDataKey = GlobalKey();
  final GlobalKey _privacyCameraKey = GlobalKey();
  final GlobalKey _privacyRightsKey = GlobalKey();
  final GlobalKey _privacyContactKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      body: CustomPaint(
        painter: const WatermarkPainter(),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Header Bar
              _buildTopBar(),

              // 2. Segmented Pill Tab Switcher
              _buildSegmentedTabSwitcher(),

              // 3. Quick-Jump Section Navigation Chips
              _buildQuickJumpChips(),

              const Divider(height: 1, color: AppColors.cardBorder),

              // 4. Scrollable Policy Content
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      physics: const ClampingScrollPhysics(),
                      child: _activeTab == LegalTab.terms
                          ? _buildTermsContent()
                          : _buildPrivacyContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Top Navigation Bar ---
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textObsidian),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Legal & Policies',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textObsidian,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Text(
                  'VeriBite Standards • Effective Nov 2026',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMutedMocha,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.safetyGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, size: 13, color: AppColors.safetyGreen),
                SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.safetyGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Segmented Dual-Pill Switcher ---
  Widget _buildSegmentedTabSwitcher() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1424).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabPill(
              title: 'Terms & Conditions',
              icon: Icons.article_outlined,
              isSelected: _activeTab == LegalTab.terms,
              onTap: () {
                setState(() => _activeTab = LegalTab.terms);
                _scrollController.jumpTo(0);
              },
            ),
          ),
          Expanded(
            child: _buildTabPill(
              title: 'Privacy Policy',
              icon: Icons.shield_outlined,
              isSelected: _activeTab == LegalTab.privacy,
              onTap: () {
                setState(() => _activeTab = LegalTab.privacy);
                _scrollController.jumpTo(0);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryObsidian : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : AppColors.textMutedMocha,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textMutedMocha,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Quick-Jump Section Chips ---
  Widget _buildQuickJumpChips() {
    final chips = _activeTab == LegalTab.terms
        ? [
            _QuickChip('Medical Disclaimer', () => _scrollToKey(_termsMedicalKey)),
            _QuickChip('Safe Ceilings', () => _scrollToKey(_termsCeilingsKey)),
            _QuickChip('Allergen Liability', () => _scrollToKey(_termsAllergensKey)),
            _QuickChip('Fair Use & Brands', () => _scrollToKey(_termsFairUseKey)),
            _QuickChip('Liability Limits', () => _scrollToKey(_termsLiabilityKey)),
          ]
        : [
            _QuickChip('Zero Tracking', () => _scrollToKey(_privacyZeroTrackKey)),
            _QuickChip('Data Collected', () => _scrollToKey(_privacyDataKey)),
            _QuickChip('Camera & OCR', () => _scrollToKey(_privacyCameraKey)),
            _QuickChip('Your Rights', () => _scrollToKey(_privacyRightsKey)),
            _QuickChip('Data Erasure', () => _scrollToKey(_privacyContactKey)),
          ];

    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = chips[index];
          return ActionChip(
            label: Text(item.label),
            labelStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textObsidian,
            ),
            backgroundColor: AppColors.cardSurface,
            side: const BorderSide(color: AppColors.cardBorder, width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: item.onTap,
          );
        },
      ),
    );
  }

  // =========================================================================
  // TERMS & CONDITIONS CONTENT
  // =========================================================================
  Widget _buildTermsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroSummaryCard(
          title: 'VeriBite Terms of Service',
          subtitle: 'Please review our conditions of use. By accessing or using VeriBite, you agree to these legal standards.',
          icon: Icons.gavel_rounded,
          color: AppColors.accentBronze,
        ),

        const SizedBox(height: 18),

        // 1. Acceptance
        _buildSectionHeader('1. Acceptance & Educational Scope'),
        _buildParagraph(
          'VeriBite provides smart optical decoding, additive risk analysis, and safe consumption ceiling estimates for consumer transparency and nutritional education. By creating an account, scanning barcodes, or accessing our services, you agree to be bound by these Terms of Service and all applicable international food labeling laws.',
        ),

        const SizedBox(height: 16),

        // 2. Medical & Health Disclaimer (Critical Callout)
        Container(
          key: _termsMedicalKey,
          child: _buildCalloutAlert(
            title: 'CRITICAL MEDICAL & NUTRITIONAL DISCLAIMER',
            message:
                'VeriBite is NOT a certified medical device and does NOT provide medical advice, diagnosis, or treatment.\n\n'
                '• All calculated safety metrics (including WHO 25g daily free sugar limits, Type-2 diabetic 10g ceilings, and sodium caps) are mathematical estimates based on published international standards (WHO, ICMR, EFSA, FSSAI) and user-provided biometrics.\n\n'
                '• Never disregard professional medical advice or delay seeking medical care based on information provided by this application. If you have diabetes, severe allergies, kidney disease, or are pregnant, consult a qualified physician or clinical dietitian.',
            icon: Icons.medical_services_outlined,
            isWarning: true,
          ),
        ),

        const SizedBox(height: 16),

        // 3. Safe Ceilings & Guardrails
        Container(key: _termsCeilingsKey),
        _buildSectionHeader('2. Safe Consumption Ceilings & Guardrails'),
        _buildParagraph(
          'VeriBite implements mathematical safe consumption algorithms scaled to body weight and selected life stages:\n\n'
          '• Adult Standard: 25.0g daily free sugar ceiling (World Health Organization guideline).\n'
          '• Diabetic Guard: Strict 10.0g daily ceiling to prevent glycemic spikes.\n'
          '• Child Guard (<18 yrs): 15.0g daily ceiling and automated flagging of Southampton artificial food dyes (INS 102 Tartrazine, 104 Quinoline Yellow, 110 Sunset Yellow, 122 Azorubine, 124 Ponceau 4R, 129 Allura Red AC) associated with childhood hyperactivity.\n'
          '• Single-Snack Ceiling: Applies the WHO 20% cap (maximum 5g free sugar per snack packet).',
        ),

        const SizedBox(height: 16),

        // 4. Allergen & Formula Changes
        Container(key: _termsAllergensKey),
        _buildSectionHeader('3. Formulation Updates & Allergen Limitations'),
        _buildParagraph(
          '• Factory Recipe Changes: Food manufacturers frequently modify formulations, chemical additives, and packaging weights without notifying third-party barcode registries. While VeriBite utilizes on-device OCR and offline verification, slight latency may exist between a manufacturer\'s factory update and database reflection.\n\n'
          '• Cross-Contamination Notice: VeriBite decodes declared on-label ingredients. It CANNOT detect airborne facility cross-contamination or undeclared trace allergens. Always review the physical packaging label if you suffer from life-threatening anaphylaxis or severe food allergies.',
        ),

        const SizedBox(height: 16),

        // 5. Intellectual Property & Fair Use
        Container(key: _termsFairUseKey),
        _buildSectionHeader('4. Intellectual Property & Nominative Fair Use'),
        _buildParagraph(
          'All third-party product brand names, trademarks, packaging artwork, and logos (e.g. Britannia, Quaker, Thums Up, Lay\'s, Maggi) referenced in the application are the property of their respective trademark owners. VeriBite references these trademarks strictly under nominative fair use for public health transparency, product identification, and consumer education.\n\n'
          'The VeriBite software, toxicology database schema, scoring algorithms, and user interface are protected under intellectual property and copyright law.',
        ),

        const SizedBox(height: 16),

        // 6. Acceptable Use
        _buildSectionHeader('5. Acceptable Use & Anti-Abuse'),
        _buildParagraph(
          'You agree not to:\n'
          '• Use automated scrapers, bots, or extraction scripts to harvest the offline or cloud database.\n'
          '• Decompile, reverse engineer, or attempt to extract the source code of the scoring engine.\n'
          '• Overload, compromise, or disrupt the Supabase cloud infrastructure or authentication endpoints.',
        ),

        const SizedBox(height: 16),

        // 7. Limitation of Liability
        Container(key: _termsLiabilityKey),
        _buildSectionHeader('6. Limitation of Liability & Governing Law'),
        _buildParagraph(
          'To the fullest extent permitted by applicable law, VeriBite, its creators, and affiliates shall not be liable for any direct, indirect, incidental, or consequential damages resulting from your dietary choices, consumption of scanned products, or reliance on information presented within the app.\n\n'
          'These terms are governed by the laws of India, including the Information Technology Act 2000 and the Consumer Protection Act 2019.',
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // =========================================================================
  // PRIVACY POLICY CONTENT
  // =========================================================================
  Widget _buildPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroSummaryCard(
          title: 'VeriBite Privacy Policy',
          subtitle: 'Your health data is private, isolated, and strictly protected. We never sell your personal information.',
          icon: Icons.lock_outline_rounded,
          color: AppColors.safetyGreen,
        ),

        const SizedBox(height: 18),

        // 1. Zero-Tracking Pledge (Callout Alert)
        Container(
          key: _privacyZeroTrackKey,
          child: _buildCalloutAlert(
            title: 'OUR ZERO-TRACKING & ZERO-AD PLEDGE',
            message:
                '• VeriBite does NOT sell, rent, or trade your personal health biometrics, scan history, or profile metrics to advertising networks, insurance providers, or data brokers.\n\n'
                '• Zero third-party behavioral analytics, ad SDKs, or surveillance cookies are integrated into VeriBite. Your health limits remain strictly your own.',
            icon: Icons.shield_rounded,
            isWarning: false,
          ),
        ),

        const SizedBox(height: 16),

        // 2. Information Collected
        Container(key: _privacyDataKey),
        _buildSectionHeader('1. Information We Collect & Why'),
        _buildParagraph(
          'We collect only the minimal data required to calculate your safe food portions:\n\n'
          '• Account Credentials: Full name, username, and email address (collected via email registration or Google OAuth) to secure your account across devices.\n\n'
          '• Health Biometrics (Voluntary & Isolated): Body weight (kg), life stage (Adult / Child), medical guardrail flags (Diabetic, Hypertensive, Pregnancy Safe), monitored allergens watchlist, and regional voice read-out language preference. This data is stored in isolated user profile tables protected by Supabase Row Level Security (RLS).\n\n'
          '• Scan History: Barcodes and timestamps of foods you scan, used exclusively to compute your live daily sugar and chemical additive budget meters.',
        ),

        const SizedBox(height: 16),

        // 3. Camera & On-Device OCR
        Container(key: _privacyCameraKey),
        _buildSectionHeader('2. Camera Permissions & Optical Processing'),
        _buildParagraph(
          '• Real-Time Viewfinder: Camera access is utilized exclusively while the scanner is active to lock onto barcodes and read backside nutrition tables.\n\n'
          '• On-Device ML Processing: Whenever possible, ingredient text recognition is executed 100% offline on your device via Google ML Kit Text Recognition. Raw camera footage is never recorded, saved to device galleries, or transmitted to surveillance servers.\n\n'
          '• Cloud Vision (Tier 3 Fallback): In rare instances where severe package curvature or glare requires cloud vision verification (Gemini 2.5 Flash), cropped text frames are sent over encrypted TLS strictly for text extraction and immediately discarded.',
        ),

        const SizedBox(height: 16),

        // 4. Data Storage & Offline Engine
        _buildSectionHeader('3. Storage Security & Offline Database'),
        _buildParagraph(
          '• Offline SQLite Engine: Over 6,450+ chemical INS / E-numbers and 56+ hidden split sugar aliases are stored locally on your device in an embedded SQLite database (`toxicology_master.db`). This allows instant ingredient lookups without pinging external servers for every additive.\n\n'
          '• Cloud Security: Cloud user data is hosted on Supabase PostgreSQL with TLS 1.3 encryption in transit and database encryption at rest.',
        ),

        const SizedBox(height: 16),

        // 5. User Rights (DPDP, GDPR, CCPA)
        Container(key: _privacyRightsKey),
        _buildSectionHeader('4. Your Rights & Data Ownership (DPDP Act / GDPR)'),
        _buildParagraph(
          'Under the Digital Personal Data Protection Act 2023 (India) and global data protection standards (GDPR, CCPA), you maintain full rights over your data:\n\n'
          '• Right to Access & Review: You can inspect all stored biometrics, guardrails, and preferences on the Profile screen.\n'
          '• Right to Rectification: You can update your weight, medical guardrails, or dietary preferences at any time.\n'
          '• Right to Erasure (Total Account Deletion): You have the absolute right to permanently delete your account, wipe all scan history, and purge all biometrics from our cloud database.',
        ),

        const SizedBox(height: 16),

        // 6. Children's Privacy
        _buildSectionHeader('5. Children\'s Privacy'),
        _buildParagraph(
          'VeriBite does not knowingly collect personal information directly from children under 13 without verifiable parental consent. The Child life stage mode is configured and controlled by parents or legal guardians to protect family members from synthetic Southampton hyperactivity dyes.',
        ),

        const SizedBox(height: 16),

        // 7. Contact & Grievance Officer
        Container(key: _privacyContactKey),
        _buildSectionHeader('6. Grievance Redressal & Contact'),
        _buildParagraph(
          'For questions regarding these policies, data erasure requests, or privacy concerns, contact our Grievance Officer:\n\n'
          '• Email: privacy@veribite.app\n'
          '• Subject: Data Privacy & Erasure Request\n'
          '• Response Time: Within 48 business hours.',
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // --- Reusable Visual Helpers ---
  Widget _buildHeroSummaryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryObsidian,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1424).withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Color(0xFFC7BEB3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalloutAlert({
    required String title,
    required String message,
    required IconData icon,
    required bool isWarning,
  }) {
    final bgColor = isWarning ? const Color(0xFFFDF4E7) : const Color(0xFFEDF7ED);
    final borderColor = isWarning ? const Color(0xFFF3C78E) : const Color(0xFFB7E1CD);
    final accentColor = isWarning ? const Color(0xFFB06000) : AppColors.safetyGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textObsidian,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textObsidian,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.5,
        color: Color(0xFF4A4238),
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _QuickChip {
  final String label;
  final VoidCallback onTap;

  _QuickChip(this.label, this.onTap);
}

