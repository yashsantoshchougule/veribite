import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../camera/presentation/smart_camera_screen.dart';
import '../../onboarding/presentation/widgets/watermark_painter.dart';
import '../../profile/application/user_profile_service.dart';
import '../../profile/domain/user_profile_model.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../profile/presentation/user_details_screen.dart';

/// Page 4: Home Dashboard
/// Central command hub for VeriBite Safe Consumption Scanner.
class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({
    super.key,
    this.userId = 'local_user',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfileModel? _profile;
  int _currentBottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileService().getProfile(widget.userId);
    if (mounted) {
      setState(() {
        _profile = profile ?? UserProfileModel.defaults(widget.userId);
      });
    }
  }

  void _openCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SmartCameraScreen(),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userId: widget.userId,
        ),
      ),
    ).then((_) {
      _loadProfile();
    });
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
              // Top Greeting & Biometric Status Header
              _buildTopHeader(),

              // Scrollable Dashboard Body
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Hero "Point & Scan Backside Label" Card
                          _buildHeroScanCard(),

                          const SizedBox(height: 18),

                          // 2. Today's Safe Consumption Budget Meter (WHO 25g Sugar Limit)
                          _buildDailyBudgetMeter(),

                          const SizedBox(height: 18),

                          // 3. Recent Scans Carousel
                          _buildRecentScansSection(),

                          const SizedBox(height: 18),

                          // 4. Quick Health Action Shortcuts
                          _buildQuickActionsGrid(),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 5. Persistent 5-Tab Bottom Navigation Bar
              _buildBottomNavigationBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    final weight = _profile?.weightKg ?? 65.0;
    final isChild = _profile?.isChild ?? false;
    final isDiabetic = _profile?.isDiabetic ?? false;
    final isHypertensive = _profile?.isHypertensive ?? false;

    String guardrailSummary = 'Safe Baseline';
    if (isDiabetic) {
      guardrailSummary = 'Diabetic Guard Active';
    } else if (isHypertensive) {
      guardrailSummary = 'Hypertension Guard';
    } else if (isChild) {
      guardrailSummary = 'Child Guard Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryObsidian,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'VeriBite Dashboard',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textObsidian,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${weight.toStringAsFixed(0)} kg ${isChild ? "Child" : "Adult"} • $guardrailSummary',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMutedMocha,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _openProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.stepPillBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder, width: 1.0),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: AppColors.accentBronze),
                  SizedBox(width: 4),
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textObsidian,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroScanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryObsidian,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1424).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '3-TIER OPTICAL SCANNER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE6DFD5),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Point & Scan Backside Label',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Instantly decode hidden split sugars, 6,450+ chemical INS additives, and calculate exact safe gram portions.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Color(0xFFC7BEB3),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.camera_alt_rounded, size: 20, color: AppColors.primaryObsidian),
              label: const Text(
                'Open Smart Camera',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryObsidian,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.canvasCream,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBudgetMeter() {
    // Current daily consumption metrics (WHO 25g limit)
    const double consumedSugarGrams = 4.2;
    const double maxSugarGrams = 25.0;
    const double percentUsed = (consumedSugarGrams / maxSugarGrams);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 18, color: AppColors.accentBronze),
                    SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Daily Consumption Budget',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textObsidian,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.safetyGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'WHO Safe',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.safetyGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Free Sugar Ceiling',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMutedMocha,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${consumedSugarGrams.toStringAsFixed(1)}g / ${maxSugarGrams.toStringAsFixed(0)}g (${(percentUsed * 100).toStringAsFixed(0)}%)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textObsidian,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            child: LinearProgressIndicator(
              value: percentUsed,
              minHeight: 8,
              backgroundColor: AppColors.stepPillBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.safetyGreen),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: AppColors.safetyGreen),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '0 Red-tier chemical additives consumed today. All safe.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMutedMocha,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScansSection() {
    final recentProducts = [
      {
        'title': 'Britannia Bourbon',
        'score': 28,
        'tag': 'Capped 🔴',
        'safePortion': '2 Biscuits',
        'color': AppColors.safetyRed,
      },
      {
        'title': 'Real Mixed Fruit',
        'score': 38,
        'tag': 'Free Sugar 🟠',
        'safePortion': '80 ml',
        'color': AppColors.safetyAmber,
      },
      {
        'title': 'Yoga Bar Muesli',
        'score': 78,
        'tag': 'Nutri Safe 🟢',
        'safePortion': '1 Serving',
        'color': AppColors.safetyGreen,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Scans',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textObsidian,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _openCamera,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Scan New +',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentBronze,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recentProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final prod = recentProducts[index];
              return Container(
                width: 160,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (prod['color'] as Color).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${prod['score']}/100',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: prod['color'] as Color,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppColors.cardBorder,
                        ),
                      ],
                    ),
                    Text(
                      prod['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textObsidian,
                      ),
                    ),
                    Text(
                      'Max: ${prod['safePortion']}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMutedMocha,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Health Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textObsidian,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: Icons.search_rounded,
                title: 'INS Decoder',
                subtitle: '6,450+ E-numbers',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('INS Decoder: 6,450+ additives loaded offline in SQLite.'),
                      backgroundColor: AppColors.primaryObsidian,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                icon: Icons.barcode_reader,
                title: 'Barcode Lookup',
                subtitle: '0.15s instant lookup',
                onTap: _openCamera,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: Icons.child_care_rounded,
                title: 'Child Guard',
                subtitle: 'Flag Southampton dyes',
                onTap: _openProfile,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Blinkit Swaps',
                subtitle: '1-tap healthy swaps',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Healthy Swaps enabled for quick-commerce delivery.'),
                      backgroundColor: AppColors.primaryObsidian,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder, width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.stepPillBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryObsidian, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textObsidian,
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMutedMocha,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _currentBottomNavIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            // Center Scan Button opens camera
            _openCamera();
          } else if (index == 4) {
            // Profile Tab opens User Details Screen
            _openProfile();
          } else {
            setState(() {
              _currentBottomNavIndex = index;
            });
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.stepPillBg,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryObsidian),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded, color: AppColors.primaryObsidian),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded, size: 28, color: AppColors.primaryObsidian),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded, color: AppColors.primaryObsidian),
            label: 'Advisor',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryObsidian),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
