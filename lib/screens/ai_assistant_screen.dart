import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../widgets/sheild_brand_text.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const String _geminiKey = 'AQ.Ab8RN6KIkNYK4qRJhYAdZhX17SID0veme3vptk6M49hKBBfYQw';
  static const String _groqKey = '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';
  static const String _cohereKey = 'cVAqw8o6IIQaJ1J2km6zUwxn1xLsYhTnHJVTFVcX';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();

  bool _isLoading = false;
  bool _isDisposed = false;
  int _activeRaceId = 0;

  // In-memory chat session that persists across screen navigation until the app process closes.
  static final List<Map<String, dynamic>> _persistedMessages = [
    {
      'role': 'model',
      'text': 'Hello! I am the **SHEild AI Assistant**.\n\nHow can I help you today with safety advice, emergency guidance, or questions?',
    }
  ];

  List<Map<String, dynamic>> get _messages => _persistedMessages;

  final String systemPrompt = 'You are the SHEild AI Assistant, an empathetic, smart, and reliable personal safety and emergency advisor.\n\n'
      'CRITICAL INSTRUCTION ON APP FEATURES (STRICT):\n'
      '- Do NOT force, plug, or mention SHEild app features into every response. Do NOT add unnecessary advertisements, reminders, or plugs for app features.\n'
      '- Mention or explain SHEild app features ONLY when:\n'
      '  1. The user explicitly asks about the app, its tools, or how to use a feature.\n'
      '  2. The user is in an active, immediate personal danger emergency where triggering SOS or Fake Call is directly and urgently relevant.\n'
      '- For all other queries (such as first aid, medical advice, safety precautions, night safety, travel advice, emergency phone numbers, or health questions), answer their question directly, clearly, and concisely without mentioning the app.\n\n'
      'STYLE & TONE:\n'
      '- Be direct, helpful, and calm.\n'
      '- Format clearly with Markdown: use bold text for key terms and bullet points for sequential steps.\n'
      '- In medical emergencies, always remind them to call local emergency services (like 911 / 112) immediately alongside step-by-step first-aid.\n'
      '- If the user asks about completely unrelated topics (like math equations, coding, sports, or politics), politely decline: "I am a dedicated safety assistant. I can only help you with safety, emergency guidance, or using the SHEild app."\n\n'
      'SHEILD APP REFERENCE (Consult ONLY when asked about the app):\n'
      '- SOS Button: Large red button on Home Dashboard. Has a 10-second countdown (or "SEND NOW"). When fired, sends an SMS with live Google Maps location to emergency contacts, triggers a loud siren alarm, and alerts the Admin Web Dashboard.\n'
      '- Background Protection Toggle: Switch on Home screen to monitor safety and location even when app is closed.\n'
      '- Quick Features Grid: "Fencing" (Geo and Route perimeters), "Fake Call" (simulates an incoming call to leave uncomfortable situations), and "Emergency" (direct police/fire contacts).\n'
      '- Profile & Contacts: Manage emergency contacts and personal details (Name, Blood Group) in Profile.';

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      if (mounted) setState(() {});
    });
    // Restore scroll position to the bottom if returning to an existing chat session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _clearChat() {
    setState(() {
      _persistedMessages.clear();
      _persistedMessages.add({
        'role': 'model',
        'text': 'Hello! I am the **SHEild AI Assistant**.\n\nHow can I help you today with safety advice, emergency guidance, or questions?',
      });
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _activeRaceId++;
    _textController.dispose();
    _textFieldFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Gemini implementation (gemini-3.6-flash verified active)
  Future<String> _askGemini(String message) async {
    final model = GenerativeModel(
      model: 'gemini-3.6-flash',
      apiKey: _geminiKey,
      systemInstruction: Content.system(systemPrompt),
    );
    final history = _messages.skip(1).map((m) {
      return m['role'] == 'user'
          ? Content.text(m['text'] as String)
          : Content.model([TextPart(m['text'] as String)]);
    }).toList();

    final chat = model.startChat(history: history);
    final response = await chat.sendMessage(Content.text(message));
    if (response.text == null || response.text!.isEmpty) {
      throw Exception('Empty Gemini response');
    }
    return response.text!;
  }

  // Groq implementation (openai/gpt-oss-20b verified active)
  Future<String> _askGroq(String message) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final List<Map<String, String>> history = [
      {'role': 'system', 'content': systemPrompt},
    ];

    for (var i = 1; i < _messages.length; i++) {
      history.add({
        'role': _messages[i]['role'] == 'user' ? 'user' : 'assistant',
        'content': _messages[i]['text'] as String,
      });
    }
    history.add({'role': 'user', 'content': message});

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_groqKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'openai/gpt-oss-20b',
        'messages': history,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Groq error: ${response.statusCode}');
  }

  // Cohere implementation (command-r-08-2024 verified active)
  Future<String> _askCohere(String message) async {
    final url = Uri.parse('https://api.cohere.com/v1/chat');

    final List<Map<String, String>> history = [];
    for (var i = 1; i < _messages.length; i++) {
      history.add({
        'role': _messages[i]['role'] == 'user' ? 'USER' : 'CHATBOT',
        'message': _messages[i]['text'] as String,
      });
    }

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_cohereKey',
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'model': 'command-r-08-2024',
        'message': message,
        'preamble': systemPrompt,
        'chat_history': history,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['text'] as String;
    }
    throw Exception('Cohere error: ${response.statusCode}');
  }

  /// Races all 3 AI APIs in parallel with continuous retry until one responds
  /// or until the user navigates away from the screen.
  Future<String> _raceApisWithContinuousRetry(String message, int raceId) {
    final completer = Completer<String>();

    Future<void> runProvider(String name, Future<String> Function() call) async {
      int attempt = 0;
      while (!completer.isCompleted && !_isDisposed && mounted && raceId == _activeRaceId) {
        attempt++;
        try {
          debugPrint('[$name] Starting race attempt #$attempt...');
          final response = await call().timeout(const Duration(seconds: 12));
          if (!completer.isCompleted && !_isDisposed && mounted && raceId == _activeRaceId) {
            debugPrint('[$name] WON THE RACE on attempt #$attempt!');
            completer.complete(response);
            return;
          }
        } catch (e) {
          debugPrint('[$name] Attempt #$attempt error: $e');
        }

        if (completer.isCompleted || _isDisposed || !mounted || raceId != _activeRaceId) {
          return;
        }

        // Small delay before retrying this provider
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    // Launch all three providers in their own continuous retry loop
    runProvider('Gemini', () => _askGemini(message));
    runProvider('Groq', () => _askGroq(message));
    runProvider('Cohere', () => _askCohere(message));

    return completer.future;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) return;

    final raceId = ++_activeRaceId;

    setState(() {
      _messages.add({'role': 'user', 'text': cleanMessage});
      _isLoading = true;
    });

    _textController.clear();
    _textFieldFocus.requestFocus();
    _scrollToBottom();

    try {
      final result = await _raceApisWithContinuousRetry(cleanMessage, raceId);

      if (mounted && raceId == _activeRaceId) {
        setState(() {
          _messages.add({'role': 'model', 'text': result});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Race cancelled or ended: $e');
      if (mounted && raceId == _activeRaceId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _textController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
        ),
        title: Row(
          children: [
            const SheildBrandText(
              suffix: 'AI',
              fontSize: 19,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF1A73E8), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Multi-AI',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A73E8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 22),
              tooltip: 'New Chat',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      'Start new chat?',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
                    ),
                    content: Text(
                      'This will clear your current conversation in this session.',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _clearChat();
                        },
                        child: Text(
                          'Clear',
                          style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Subtle Floating Disclaimer Capsule ─────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.iAmAnAiNotADoctorCallEmergency ??
                        'I am an AI, not a doctor. Call emergency services immediately for severe medical emergencies.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF92400E),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Conversation List ──────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['role'] == 'user';

                if (isUser) {
                  // User Message: Sleek, softly tinted pill bubble on the right
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.82,
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F9),
                        borderRadius: BorderRadius.circular(22).copyWith(
                          bottomRight: const Radius.circular(4),
                        ),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        message['text'] as String,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1E293B),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    ),
                  );
                }

                // AI Message: Open, breathable layout with Gemini Sparkle and rich Markdown
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Sparkle Icon and Model Label
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1A73E8), Color(0xFF4285F4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 10),
                          const SheildBrandText(
                            suffix: 'AI',
                            suffixColor: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Breathable Markdown Formatted Response
                      Padding(
                        padding: const EdgeInsets.only(left: 36, right: 8),
                        child: MarkdownBody(
                          data: message['text'] as String,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: GoogleFonts.inter(
                              fontSize: 15,
                              height: 1.6,
                              color: const Color(0xFF1E293B),
                            ),
                            strong: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            h1: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            h2: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            h3: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                            listBullet: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A73E8),
                            ),
                            code: GoogleFonts.robotoMono(
                              fontSize: 13,
                              backgroundColor: const Color(0xFFF1F5F9),
                              color: const Color(0xFF0F172A),
                            ),
                            blockSpacing: 10.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Shimmering "AI Racing / Thinking" Indicator ────────────────
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF1A73E8), size: 14),
                  ),
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context)?.aiNetworksRacing ?? 'AI networks racing...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

          // ── Floating Pill Input Bar (Gemini Mobile Style) ──────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _textFieldFocus,
                      minLines: 1,
                      maxLines: 4,
                      style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Ask SHEild AI for advice or app help...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: hasText ? () => _sendMessage(_textController.text) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: hasText ? const Color(0xFF1A73E8) : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: hasText ? Colors.white : const Color(0xFF94A3B8),
                        size: 20,
                      ),
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
}