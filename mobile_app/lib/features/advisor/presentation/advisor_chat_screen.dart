import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../profile/domain/user_profile_model.dart';
import '../application/advisor_service.dart';
import '../domain/advisor_chat_model.dart';
import 'widgets/advisor_message_bubble.dart';
import 'widgets/quick_prompt_carousel.dart';

/// Page 11: Personal AI Health Advisor Screen.
/// Provides conversational AI nutrition guidance grounded in verified regulatory
/// citations (WHO, EFSA, FSSAI, JECFA) via Gemini 2.5 Flash with offline fallback.
class AdvisorChatScreen extends StatefulWidget {
  final ProductAdvisorContext? initialProductContext;
  final UserProfileModel? userProfile;
  final AdvisorService? advisorService;

  const AdvisorChatScreen({
    super.key,
    this.initialProductContext,
    this.userProfile,
    this.advisorService,
  });

  @override
  State<AdvisorChatScreen> createState() => _AdvisorChatScreenState();
}

class _AdvisorChatScreenState extends State<AdvisorChatScreen> {
  late final AdvisorService _service;
  late final TextEditingController _textController;
  late final ScrollController _scrollController;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  ProductAdvisorContext? _activeProductContext;

  @override
  void initState() {
    super.initState();
    _service = widget.advisorService ?? AdvisorService();
    _textController = TextEditingController();
    _scrollController = ScrollController();
    _activeProductContext = widget.initialProductContext;

    _seedWelcomeMessage();
  }

  void _seedWelcomeMessage() {
    if (_activeProductContext != null) {
      _messages.add(
        ChatMessage.advisor(
          text: 'Hello! I am your VeriBite Personal AI Advisor, powered by Gemini 2.5 Flash and Citation RAG.\n\n'
              'I have loaded **${_activeProductContext!.productName}** (Health Score: ${_activeProductContext!.healthScore}/100) into our context. '
              'Ask me anything about its safe portions for your body weight, split sugars, or chemical additives.',
          source: 'gemini_2.5_flash',
          citations: ['WHO-Healthy-Diet-2023', 'FSSAI-Labelling-Regs-2020'],
        ),
      );
    } else {
      _messages.add(
        ChatMessage.advisor(
          text: 'Hello! I am your VeriBite Personal AI Advisor, grounded in WHO, EFSA, and FSSAI verified citations.\n\n'
              'Ask me anything about packaged food toxicology, chemical INS codes, hidden sugar splitting, or safe consumption ceilings for your family.',
          source: 'gemini_2.5_flash',
          citations: ['WHO-Free-Sugars-2015', 'EFSA-Compendium-2021'],
        ),
      );
    }
  }

  @override
  void dispose() {
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

    final reply = await _service.askAdvisor(
      userMessage: query,
      productContext: _activeProductContext,
      userProfile: widget.userProfile,
    );

    if (mounted) {
      setState(() {
        _messages.add(reply);
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1424),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Color(0xFF0F9D58),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VeriBite AI Advisor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Gemini 2.5 Flash • Citation RAG',
                  style: TextStyle(
                    color: Color(0xFF0F9D58),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70),
            tooltip: 'Clear Chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                _seedWelcomeMessage();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Active Product Context Capsule (if loaded from scan)
            if (_activeProductContext != null) _buildProductContextCapsule(),

            // Chat Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return _buildLoadingBubble();
                  }
                  return AdvisorMessageBubble(message: _messages[index]);
                },
              ),
            ),

            // Quick Prompt Carousel
            QuickPromptCarousel(
              onPromptSelected: _handleSendMessage,
              productContext: _activeProductContext,
            ),
            const SizedBox(height: 10),

            // Bottom Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductContextCapsule() {
    final ctx = _activeProductContext!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF0F9D58)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Discussing: ${ctx.productName} (Score: ${ctx.healthScore}/100)',
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: _clearContext,
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.close_rounded, size: 16, color: Colors.white54),
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
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F9D58)),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Gemini is searching regulatory citations...',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
        color: Color(0xFF0E1424),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF121829),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ask anything about additives, sugar, or dosage...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                ),
                onSubmitted: _handleSendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF0F9D58),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: () => _handleSendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }
}

