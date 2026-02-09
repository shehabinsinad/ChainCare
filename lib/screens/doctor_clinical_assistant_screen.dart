import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/medical_ai_service.dart';
import '../theme/app_colors.dart';

/// Doctor Clinical Assistant Screen
/// 
/// Premium AI chat interface for doctors with professional clinical personality
class DoctorClinicalAssistantScreen extends StatefulWidget {
  final String patientId;

  const DoctorClinicalAssistantScreen({
    super.key,
    required this.patientId,
  });

  @override
  State<DoctorClinicalAssistantScreen> createState() =>
      _DoctorClinicalAssistantScreenState();
}

class _DoctorClinicalAssistantScreenState
    extends State<DoctorClinicalAssistantScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  bool _isSending = false;
  String _recordsContext = '';
  String _doctorName = '';
  String _patientName = 'Patient';
  int _recordCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);

    try {
      // Get doctor name
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doctorDoc.exists) {
          final data = doctorDoc.data()!;
          final profile = data['profile'] as Map<String, dynamic>?;
          _doctorName = profile?['name'] ?? data['name'] ?? 'Doctor';
        }
      }

      // Get patient name
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .get();
      
      if (patientDoc.exists) {
        final data = patientDoc.data()!;
        final profile = data['profile'] as Map<String, dynamic>?;
        _patientName = profile?['name'] ?? data['name'] ?? 'Patient';
      }

      // Fetch patient records using new service
      _recordsContext = await MedicalAIService.fetchPatientRecordsContext(widget.patientId);
      
      // Get actual record count
      if (_recordsContext != 'NO_RECORDS_FOUND' && 
          _recordsContext != 'TIMEOUT_ERROR' && 
          _recordsContext != 'FETCH_ERROR') {
        // Extract count from context string
        final match = RegExp(r'\((\d+) total records').firstMatch(_recordsContext);
        _recordCount = match != null ? int.parse(match.group(1)!) : 0;
        
        // Add welcome message
        _addMessage(
          ChatMessage(
            text: "I've analyzed $_recordCount ${_recordCount == 1 ? 'record' : 'records'} for patient $_patientName. I'm ready to assist with clinical questions about their medical history. What would you like to know?",
            isUser: false,
            timestamp: DateTime.now(),
          ),
          saveToHistory: false,
        );
      } else {
        // Show appropriate message for error states
        _addMessage(
          ChatMessage(
            text: MedicalAIService.getUserFriendlyError(_recordsContext),
            isUser: false,
            timestamp: DateTime.now(),
            isError: _recordsContext != 'NO_RECORDS_FOUND',
          ),
          saveToHistory: false,
        );
      }

    } catch (e) {
      debugPrint('Error initializing chat: $e');
      _addMessage(
        ChatMessage(
          text: MedicalAIService.getUserFriendlyError('FETCH_ERROR'),
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ),
        saveToHistory: false,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addMessage(ChatMessage message, {bool saveToHistory = true}) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final userMessage = text.trim();
    _messageController.clear();

    // Add user message
    _addMessage(
      ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );

    setState(() => _isSending = true);

    try {
      // Build conversation history
      final history = _messages
          .where((m) => !m.isError)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      // Build system prompt with professional doctor personality
      final systemPrompt = MedicalAIService.buildDoctorSystemPrompt(
        doctorName: _doctorName,
        patientName: _patientName,
        recordsContext: _recordsContext,
      );

      // Get AI response
      final aiResponse = await MedicalAIService.sendMessage(
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        conversationHistory: history,
      );

      // Add AI response
      _addMessage(
        ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );

    } catch (e) {
      debugPrint('Error sending message: $e');
      
      String errorCode = 'UNKNOWN_ERROR';
      if (e.toString().contains('Exception:')) {
        errorCode = e.toString().replaceAll('Exception:', '').trim();
      }

      _addMessage(
        ChatMessage(
          text: MedicalAIService.getUserFriendlyError(errorCode),
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ),
        saveToHistory: false,
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clinical Assistant'),
            if (_recordCount > 0)
              Text(
                '$_recordCount ${_recordCount == 1 ? 'record' : 'records'} analyzed',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Privacy banner
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.orange[50],
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ Temporary session - conversation not stored for patient privacy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Analyzing patient records...',
                          style: TextStyle(color: AppColors.mediumGray),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isSending) {
                            return _buildTypingIndicator();
                          }
                          return _buildMessage(_messages[index]);
                        },
                      ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask clinical question...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_isSending,
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: _isSending ? Colors.grey[300] : AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _isSending
                        ? null
                        : () => _sendMessage(_messageController.text),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: _isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey[600]!,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology, size: 64, color: Colors.blue[200]),
            const SizedBox(height: 16),
            const Text(
              'Clinical Assistant Ready',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about $_patientName\'s medical history',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSuggestedQuestions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    final questions = [
      "Summarize this patient's medical history",
      "Any concerning trends?",
      "Current medications?",
      "When was last lab work?",
      "Any drug interactions?",
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: questions
          .map((q) => InkWell(
                onTap: () => _sendMessage(q),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 6),
                      Text(
                        q,
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isError
                    ? Colors.red[50]
                    : message.isUser
                        ? AppColors.primary
                        : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: message.isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: message.isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                border: message.isError
                    ? Border.all(color: Colors.red[300]!)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
                          const SizedBox(width: 6),
                          Text(
                            'Error',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.4,
                      ),
                      strong: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: message.isUser ? Colors.white : Colors.black87,
                      ),
                      listBullet: TextStyle(
                        color: message.isUser ? Colors.white70 : Colors.black54,
                      ),
                      code: TextStyle(
                        backgroundColor: message.isUser
                            ? Colors.white.withOpacity(0.2)
                            : Colors.grey[200],
                        color: message.isUser ? Colors.white : Colors.black87,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  if (!message.isUser && !message.isError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
              child: Text(
                DateFormat('HH:mm').format(message.timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        // Animation will restart due to rebuild
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}
