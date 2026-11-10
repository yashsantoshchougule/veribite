import 'package:flutter/material.dart';
import '../../../../core/config/ai_provider_config.dart';
import '../../../../core/network/backend_endpoint_resolver.dart';
import '../../../../core/theme/app_colors.dart';

/// In-App Modal Bottom Sheet for Backend & Vision Proxy Configuration
/// Allows setting custom LAN IP (e.g. http://192.168.1.15:8000) or Cloudflare Tunnel,
/// testing live connectivity with latency in ms, and inspecting active route status.
class BackendSettingsSheet extends StatefulWidget {
  final BackendEndpointResolver? resolver;

  const BackendSettingsSheet({
    super.key,
    this.resolver,
  });

  static Future<void> show(BuildContext context, {BackendEndpointResolver? resolver}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: BackendSettingsSheet(resolver: resolver),
      ),
    );
  }

  @override
  State<BackendSettingsSheet> createState() => _BackendSettingsSheetState();
}

class _BackendSettingsSheetState extends State<BackendSettingsSheet> {
  late final BackendEndpointResolver _resolver;
  final TextEditingController _urlController = TextEditingController();

  bool _isLoading = true;
  bool _isTesting = false;
  int? _testLatencyMs;
  String? _testErrorMessage;
  String? _activeEndpoint;

  @override
  void initState() {
    super.initState();
    _resolver = widget.resolver ?? BackendEndpointResolver.instance;
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final customUrl = await _resolver.getCustomBackendUrl();
    final active = await _resolver.resolveActiveBackendUrl();

    if (mounted) {
      setState(() {
        if (customUrl != null) {
          _urlController.text = customUrl;
        }
        _activeEndpoint = active;
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    final urlToTest = _urlController.text.trim();
    if (urlToTest.isEmpty) {
      setState(() {
        _testErrorMessage = 'Please enter a valid HTTP/HTTPS URL to test.';
        _testLatencyMs = null;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testLatencyMs = null;
      _testErrorMessage = null;
    });

    final latency = await _resolver.testEndpoint(urlToTest);

    if (mounted) {
      setState(() {
        _isTesting = false;
        if (latency >= 0) {
          _testLatencyMs = latency;
          _testErrorMessage = null;
        } else {
          _testLatencyMs = null;
          _testErrorMessage = 'Could not connect to $urlToTest/health (timeout or connection refused).';
        }
      });
    }
  }

  Future<void> _saveConfig() async {
    final text = _urlController.text.trim();
    await _resolver.setCustomBackendUrl(text.isEmpty ? null : text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text.isEmpty
                ? 'Reset backend to Automatic Resolution.'
                : 'Custom Backend URL saved: $text',
          ),
          backgroundColor: AppColors.primaryObsidian,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _applyPreset(String url) {
    setState(() {
      _urlController.text = url;
      _testLatencyMs = null;
      _testErrorMessage = null;
    });
    if (url.isNotEmpty) {
      _testConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvasCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title & icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentBronze.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.dns_rounded, color: AppColors.accentBronze, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backend & Vision Proxy Settings',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textObsidian,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        '5G Mobile Data, Wi-Fi LAN & Cloud Tunnel Resolver',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMutedMocha,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textObsidian),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Active Route Banner Card
            _buildActiveRouteCard(),
            const SizedBox(height: 16),

            // Custom Backend URL Input
            const Text(
              'Custom FastAPI Backend URL',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textObsidian,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'e.g. http://192.168.1.10:8000',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMutedMocha),
                filled: true,
                fillColor: AppColors.cardSurface,
                prefixIcon: const Icon(Icons.link_rounded, color: AppColors.accentBronze, size: 20),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _urlController.clear()),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.accentBronze, width: 1.8),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            // Quick Preset Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildPresetChip('Auto Detect', ''),
                _buildPresetChip('USB Loopback', 'http://127.0.0.1:8000'),
                _buildPresetChip('Emulator', 'http://10.0.2.2:8000'),
              ],
            ),
            const SizedBox(height: 14),

            // Test Ping Feedback
            if (_testLatencyMs != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.safetyGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.safetyGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.safetyGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reachable! Ping latency: ${_testLatencyMs}ms',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.safetyGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_testErrorMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.safetyRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.safetyRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.safetyRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testErrorMessage!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.safetyRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Action Buttons: Test Connection & Save
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBronze),
                          )
                        : const Icon(Icons.network_ping_rounded, size: 18),
                    label: const Text('Test Ping'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textObsidian,
                      side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveConfig,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save & Apply'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryObsidian,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Multi-Provider AI Pool Status Card
            _buildAiPoolStatusCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRouteCard() {
    final routeDesc = _resolver.activeRouteDescription;
    final isOnlineProxy = _activeEndpoint != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOnlineProxy ? Icons.wifi_tethering_rounded : Icons.offline_bolt_rounded,
                size: 18,
                color: isOnlineProxy ? AppColors.safetyGreen : AppColors.safetyAmber,
              ),
              const SizedBox(width: 8),
              const Text(
                'Active Vision & Scan Route',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textObsidian,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isOnlineProxy ? AppColors.safetyGreen : AppColors.safetyAmber).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOnlineProxy ? 'ONLINE PROXY' : 'OFFLINE-FIRST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isOnlineProxy ? AppColors.safetyGreen : AppColors.safetyAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            routeDesc,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textObsidian,
            ),
          ),
          if (_activeEndpoint != null) ...[
            const SizedBox(height: 4),
            Text(
              'Target: $_activeEndpoint/api/v1/scan/vision',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMutedMocha,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String url) {
    final isSelected = _urlController.text.trim() == url;
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textObsidian,
      ),
      backgroundColor: isSelected ? AppColors.primaryObsidian : AppColors.stepPillBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(
        color: isSelected ? AppColors.primaryObsidian : AppColors.stepPillBorder,
        width: 1.0,
      ),
      onPressed: () => _applyPreset(url),
    );
  }

  Widget _buildAiPoolStatusCard() {
    final geminiReady = AiProviderConfig.isGeminiConfigured;
    final groqReady = AiProviderConfig.isGroqConfigured;
    final openRouterReady = AiProviderConfig.isOpenRouterConfigured;
    final activeCooldowns = AiProviderConfig.activeCooldownCount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_rounded, size: 18, color: AppColors.accentBronze),
                  SizedBox(width: 8),
                  Text(
                    'Multi-Provider AI Pool (4-Tier)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textObsidian,
                    ),
                  ),
                ],
              ),
              if (activeCooldowns > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.safetyAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$activeCooldowns on cooldown',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.safetyAmber,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.safetyGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'All Ready',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.safetyGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildProviderTierRow(
            tier: 'Tier 1',
            name: 'Google Gemini',
            subtitle: '${AiProviderConfig.geminiApiKeys.length} keys in pool • gemini-2.5-flash / 2.0-flash-lite',
            isActive: geminiReady,
            chipColor: AppColors.safetyGreen,
          ),
          const Divider(height: 12, thickness: 0.5, color: AppColors.cardBorder),
          _buildProviderTierRow(
            tier: 'Tier 2',
            name: 'Groq Cloud LPU',
            subtitle: '${AiProviderConfig.groqApiKeys.length} keys in pool • Qwen 3.8 (Vision) / Llama 3.3 70B (Chat)',
            isActive: groqReady,
            chipColor: AppColors.safetyGreen,
          ),
          const Divider(height: 12, thickness: 0.5, color: AppColors.cardBorder),
          _buildProviderTierRow(
            tier: 'Tier 3',
            name: 'OpenRouter & Proxy',
            subtitle: '${AiProviderConfig.openRouterApiKeys.length} keys in pool • Spillover Gateway + FastAPI',
            isActive: openRouterReady,
            chipColor: AppColors.accentBronze,
          ),
          const Divider(height: 12, thickness: 0.5, color: AppColors.cardBorder),
          _buildProviderTierRow(
            tier: 'Tier 4',
            name: 'On-Device Edge OCR',
            subtitle: 'ML Kit + Local Regex Engine (Zero Net)',
            isActive: true,
            chipColor: AppColors.safetyGreen,
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _showKeysManagementModal(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.stepPillBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.stepPillBorder, width: 0.8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.key_rounded, size: 14, color: AppColors.accentBronze),
                  SizedBox(width: 6),
                  Text(
                    'Inspect & Manage 11 Active AI Keys',
                    style: TextStyle(
                      fontSize: 11.5,
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

  Widget _buildProviderTierRow({
    required String tier,
    required String name,
    required String subtitle,
    required bool isActive,
    required Color chipColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.stepPillBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tier,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textMutedMocha,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textObsidian,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMutedMocha,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? chipColor : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  void _showKeysManagementModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.canvasCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.vpn_key_rounded, size: 20, color: AppColors.accentBronze),
                  SizedBox(width: 8),
                  Text(
                    'Active AI Provider Keys (11 Total)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textObsidian,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Keys are distributed across independent project quotas for round-robin rotation & automatic failover.',
                style: TextStyle(fontSize: 12, color: AppColors.textMutedMocha),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    _buildProviderKeyGroup('Google Gemini (Pool A - 5 Keys)', AiProviderConfig.geminiApiKeys),
                    const SizedBox(height: 12),
                    _buildProviderKeyGroup('Groq Cloud LPU (Pool B - 3 Keys)', AiProviderConfig.groqApiKeys),
                    const SizedBox(height: 12),
                    _buildProviderKeyGroup('OpenRouter Gateway (Pool C - 3 Keys)', AiProviderConfig.openRouterApiKeys),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryObsidian,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProviderKeyGroup(String title, List<String> keys) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textObsidian,
            ),
          ),
          const SizedBox(height: 8),
          if (keys.isEmpty)
            const Text(
              'No keys configured',
              style: TextStyle(fontSize: 11, color: AppColors.textMutedMocha),
            )
          else
            ...keys.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final key = entry.value;
              final masked = AiProviderConfig.maskKeyForDisplay(key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.stepPillBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$idx',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMutedMocha,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        masked,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: AppColors.textObsidian,
                        ),
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.safetyGreen),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
