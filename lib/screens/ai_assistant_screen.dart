import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/sheild_brand_text.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({Key? key}) : super(key: key);

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

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'model',
      'text': 'Hello! I am the Sheild AI Assistant. How can I help you with the app or provide emergency safety advice today?',
    }
  ];

  final String systemPrompt = 'You are the official Sheild AI Assistant. '
    'Your ONLY purpose is to explain how the Sheild app works and provide emergency, safety, and first-aid advice. '
    'Here is the complete manual on how the Sheild app works so you can answer user questions: '
    '- On the Home Dashboard, there is a giant red SOS button. Pressing it starts a 10-second countdown. '
    '- If not cancelled, the SOS sends an SMS with the user\'s live Google Maps location to their emergency contacts, plays a loud siren alarm, and alerts the Admin Web Dashboard. '
    '- There is a "SEND NOW" button to skip the countdown. '
    '- Background Protection Toggle: A switch on the home screen that allows the app to keep tracking location and monitoring safety even when the app is closed. '
    '- Quick Features Grid includes "Fencing", "Fake Call", and "Emergency". '
    '- "Fencing" allows users to set up Geo and Route perimeters for safety. '
    '- "Fake Call" simulates a ringing incoming phone call to help users safely excuse themselves from uncomfortable situations. '
    '- "Emergency" provides quick access to local police and fire department services. '
    '- Users can manage their Emergency Contacts and Personal Profile (Name, Blood Group) in the Profile tab. '
    'If the user asks about math, coding, politics, or anything unrelated to personal safety or this app, '
    'you MUST politely refuse to answer and state: "I am a dedicated safety assistant. I can only help you with emergencies or the Sheild app." '
    'Always remind users in medical emergencies to immediately call 911 or local emergency services before attempting first aid.';

  // Gemini implementation
  Future<String> _askGemini(String message) async {
    final model = GenerativeModel(
      model: 'gemini-3.6-flash',
      apiKey: _geminiKey,
      systemInstruction: Content.system(systemPrompt),
    );
    final history = _messages.skip(1).map((m) {
      return m['role'] == 'user' ? Content.text(m['text']) : Content.model([TextPart(m['text'])]);
    }).toList();
    
    final chat = model.startChat(history: history);
    
    final response = await chat.sendMessage(Content.text(message));
    if (response.text == null || response.text!.isEmpty) throw Exception('Empty Gemini response');
    return response.text!;
  }

  // Groq implementation
  Future<String> _askGroq(String message) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    
    final List<Map<String, String>> history = [
      {'role': 'system', 'content': systemPrompt},
    ];
    
    for (var i = 1; i < _messages.length; i++) {
      history.add({
        'role': _messages[i]['role'] == 'user' ? 'user' : 'assistant',
        'content': _messages[i]['text'],
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
        'model': 'llama3-8b-8192',
        'messages': history,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    }
    throw Exception('Groq error: ${response.statusCode}');
  }

  // Cohere implementation
  Future<String> _askCohere(String message) async {
    final url = Uri.parse('https://api.cohere.ai/v1/chat');
    
    final List<Map<String, String>> history = [];
    for (var i = 1; i < _messages.length; i++) {
      history.add({
        'role': _messages[i]['role'] == 'user' ? 'USER' : 'CHATBOT',
        'message': _messages[i]['text'],
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
        'model': 'command-r-plus',
        'message': message,
        'preamble': systemPrompt,
        'chat_history': history,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['text'];
    }
    throw Exception('Cohere error: ${response.statusCode}');
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
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': message});
      _isLoading = true;
    });
    
    _textController.clear();
    _textFieldFocus.requestFocus();
    _scrollToBottom();

    try {
      final result = await _raceApis(message);

      if (mounted) {
        setState(() {
          _messages.add({'role': 'model', 'text': result});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All AI networks failed. Please check internet connection.')),
        );
      }
    }
  }

  Future<String> _raceApis(String message) {
    final completer = Completer<String>();
    int failures = 0;
    
    void checkFailure(dynamic error) {
      failures++;
      debugPrint('API Race Error: $error');
      if (failures == 3 && !completer.isCompleted) {
        completer.completeError('All 3 AI APIs failed to respond.');
      }
    }

    _askGemini(message).then((val) {
      if (!completer.isCompleted) completer.complete(val);
    }).catchError(checkFailure);

    _askGroq(message).then((val) {
      if (!completer.isCompleted) completer.complete(val);
    }).catchError(checkFailure);

    _askCohere(message).then((val) {
      if (!completer.isCompleted) completer.complete(val);
    }).catchError(checkFailure);

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const SheildBrandText(
          suffix: 'AI Assistant',
          suffixColor: Colors.black87,
          fontSize: 18,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.orange[100],
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange[900], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'I am an AI, not a doctor. Call emergency services immediately for severe medical emergencies.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.orange[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['role'] == 'user';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isUser) ...[
                        CircleAvatar(
                          backgroundColor: Colors.blue[800],
                          child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blue[800] : Colors.white,
                            borderRadius: BorderRadius.circular(20).copyWith(
                              bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
                              bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            message['text'],
                            style: GoogleFonts.inter(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          child: const Icon(Icons.person, color: Colors.grey, size: 20),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('AI networks racing...', style: GoogleFonts.inter(color: Colors.grey)),
                ],
              ),
            ),
            
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _textFieldFocus,
                      decoration: InputDecoration(
                        hintText: 'Ask for first-aid or help...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[800],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: () => _sendMessage(_textController.text),
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

