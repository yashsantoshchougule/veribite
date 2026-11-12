import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/scoring/offline_additive_knowledge_base.dart';
import '../../../../core/theme/app_colors.dart';
import '../../camera/application/offline_barcode_repository.dart';
import '../../onboarding/presentation/widgets/watermark_painter.dart';
import '../../profile/domain/user_profile_model.dart';
import '../application/advisor_service.dart';
import '../application/tts_voice_service.dart';
import '../domain/advisor_chat_model.dart';
import 'widgets/advisor_message_bubble.dart';
import 'widgets/quick_prompt_carousel.dart';

/// Page 11: Personal AI Health Advisor Screen.
/// Provides conversational AI nutrition guidance grounded in verified regulatory
/// citations (WHO, EFSA, FSSAI, JECFA) via Gemini 2.5 Flash with offline fallback.
/// Styled with VeriBite's signature Warm Luxury Alabaster & Midnight Obsidian palette.
class AdvisorChatScreen extends StatefulWidget {
  final ProductAdvisorContext? initialProductContext;
  final UserProfileModel? userProfile;
  final AdvisorService? advisorService;
  final TtsVoiceService? ttsService;

  const AdvisorChatScreen({
    super.key,
    this.initialProductContext,
    this.userProfile,
    this.advisorService,
    this.ttsService,
  });

  @override
  State<AdvisorChatScreen> createState() => _AdvisorChatScreenState();
}

class _AdvisorChatScreenState extends State<AdvisorChatScreen> {
  late final AdvisorService _service;
  late final TtsVoiceService _ttsService;
  late final TextEditingController _textController;
  late final ScrollController _scrollController;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  ProductAdvisorContext? _activeProductContext;

  @override
  void initState() {
    super.initState();
    _service = widget.advisorService ?? AdvisorService();
    _ttsService = widget.ttsService ?? TtsVoiceService();
    _textController = TextEditingController();
    _scrollController = ScrollController();
    _activeProductContext = widget.initialProductContext;

    // Warm up offline additive & barcode caches asynchronously for Tier 0 <10ms instant lookups
    unawaited(OfflineAdditiveKnowledgeBase.instance.ensureInitialized());
    unawaited(OfflineBarcodeRepository.instance.ensureInitialized());

    _seedWelcomeMessage();
  }

  void _seedWelcomeMessage() {
    if (_activeProductContext != null) {
      _messages.add(
        ChatMessage.advisor(
          text: 'Hello! I am your VeriBite Personal AI Advisor, grounded in WHO, EFSA, and FSSAI scientific standards.\n\n'
              'I have loaded **${_activeProductContext!.productName}** (Health Score: ${_activeProductContext!.healthScore}/100) into our context. '
              'Ask me anything about its safe portions for your body weight, split sugars, or chemical additives.',
          source: 'gemini_3.5_flash',
          citations: ['WHO-Healthy-Diet-2023', 'FSSAI-Labelling-Regs-2020'],
        ),
      );
    } else {
      _messages.add(
        ChatMessage.advisor(
          text: 'Hello! I am your VeriBite Personal AI Advisor, grounded in WHO, EFSA, and FSSAI verified citations.\n\n'
              'Ask me anything about packaged food toxicology, chemical INS codes, hidden sugar splitting, or safe consumption ceilings for your family.',
          source: 'gemini_3.5_flash',
          citations: ['WHO-Free-Sugars-2015', 'EFSA-Compendium-2021'],
        ),
      );
    }
  }

  @override
  void dispose() {
    _ttsService.stop();
    if (widget.ttsService == null) {
      _ttsService.dispose();
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    _textController.clear();
    final userMsg = ChatMessage.user(query);

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    _scrollToBottom();

    ChatMessage? reply;
    try {
      reply = await _service.askAdvisor(
        userMessage: query,
        productContext: _activeProductContext,
        userProfile: widget.userProfile,
      );
    } catch (e) {
      debugPrint('[AdvisorChatScreen] Error querying advisor: $e');
      reply = ChatMessage.advisor(
        text: 'A temporary connection issue occurred. Please ask your question again!',
        source: 'local_offline',
      );
    } finally {
      if (mounted) {
        setState(() {
          if (reply != null) {
            _messages.add(reply);
          }
          _isLoading = false;
        });
        _scrollToBottom();

        if (reply != null && _ttsService.autoSpeakEnabledNotifier.value) {
          await _ttsService.speak(reply.text, messageId: reply.id);
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearContext() {
    setState(() {
      _activeProductContext = null;
      _messages.add(
        ChatMessage.advisor(
          text: 'Product context cleared. You are now in general nutrition & toxicology mode. Ask any question!',
          source: 'local_offline',
        ),
      );
    });
    _scrollToBottom();
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
              // 1. Top Navigation & Identity Bar
              _buildTopBar(),

              // 2. Active Product Context Capsule (if loaded from scan)
              if (_activeProductContext != null) _buildProductContextCapsule(),

              // 3. Scrollable Chat Message List
              Expanded(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _ttsService.currentlySpeakingIdNotifier,
                  builder: (context, speakingId, _) {
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isLoading) {
                          return _buildLoadingBubble();
                        }
                        final msg = _messages[index];
                        return AdvisorMessageBubble(
                          message: msg,
                          isSpeaking: speakingId == msg.id,
                          onToggleSpeak: msg.isUser
                              ? null
                              : () => _ttsService.toggleSpeak(msg.text, messageId: msg.id),
                        );
                      },
                    );
                  },
                ),
              ),

              // 4. Quick Contextual Prompts Carousel
              QuickPromptCarousel(
                onPromptSelected: _isLoading ? (_) {} : _handleSendMessage,
                productContext: _activeProductContext,
              ),
              const SizedBox(height: 8),

              // 5. Bottom Input Bar
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 1.0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.backButtonBg,
            radius: 18,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textObsidian, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'VeriBite AI Advisor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textObsidian,
                letterSpacing: -0.2,
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _ttsService.autoSpeakEnabledNotifier,
            builder: (context, autoSpeak, _) {
              return CircleAvatar(
                backgroundColor: autoSpeak ? AppColors.safetyMintBg : AppColors.backButtonBg,
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    autoSpeak ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded,
                    color: autoSpeak ? AppColors.safetyMint : AppColors.textObsidian,
                    size: 19,
                  ),
                  tooltip: autoSpeak ? 'Auto-Voice: Enabled' : 'Auto-Voice: Disabled',
                  onPressed: () => _ttsService.toggleAutoSpeak(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.backButtonBg,
            radius: 18,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.restart_alt_rounded, color: AppColors.accentBronze, size: 19),
              tooltip: 'Reset Conversation',
              onPressed: () {
                _ttsService.stop();
                setState(() {
                  _messages.clear();
                  _seedWelcomeMessage();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductContextCapsule() {
    final ctx = _activeProductContext!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.stepPillBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stepPillBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.accentBronze),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Discussing: ${ctx.productName} (Score: ${ctx.healthScore}/100)',
              style: const TextStyle(
                color: AppColors.textObsidian,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: _clearContext,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.close_rounded, size: 16, color: AppColors.textMutedMocha),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.safetyMint),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Analyzing clinical profile & toxicology...',
              style: TextStyle(
                color: AppColors.textMutedMocha,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.stepPillBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.stepPillBorder, width: 1.0),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(
                  color: AppColors.textObsidian,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ask anything about additives, sugar, or dosage...',
                  hintStyle: TextStyle(
                    color: AppColors.textMutedMocha,
                    fontSize: 12.5,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: _isLoading ? null : _handleSendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _isLoading ? AppColors.textMutedMocha.withValues(alpha: 0.5) : AppColors.primaryObsidian,
            radius: 20,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: _isLoading ? null : () => _handleSendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }
}
