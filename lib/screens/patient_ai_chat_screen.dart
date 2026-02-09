import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../services/medical_ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Premium Patient AI Chat Screen
/// Modern messaging interface with premium styling
class PatientAIChatScreen extends StatefulWidget {
  const PatientAIChatScreen({super.key});

  @override
  State<PatientAIChatScreen> createState() => _PatientAIChatScreenState();
}

class _PatientAIChatScreenState extends State<PatientAIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;
  String _recordsContext = ''; // Changed from _medicalSummary
  int _recordCount = 0;
  String? _patientName;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load patient name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final profile = data['profile'] as Map<String, dynamic>?;
        _patientName = profile?['name'] ?? data['name'] ?? 'Patient';
      }

      // Load conversation history (last 15 messages)
      final historySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('patientChatHistory')
          .orderBy('timestamp', descending: true)
          .limit(15)
          .get();

      final historyMessages = historySnapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
          .toList()
          .reversed
          .toList();

      // Auto-delete messages older than 30 days
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final oldMessages = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('patientChatHistory')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in oldMessages.docs) {
        batch.delete(doc.reference);
      }
      if (oldMessages.docs.isNotEmpty) {
        await batch.commit();
      }

      // Load and process medical records using new service
      _recordsContext = await MedicalAIService.fetchPatientRecordsContext(user.uid);

      // Get actual record count
      if (_recordsContext != 'NO_RECORDS_FOUND' && 
          _recordsContext != 'TIMEOUT_ERROR' && 
          _recordsContext != 'FETCH_ERROR') {
        // Extract count from context string
        final match = RegExp(r'\((\d+) total records').firstMatch(_recordsContext);
        _recordCount = match != null ? int.parse(match.group(1)!) : 0;
      } else {
        _recordCount = 0;
      }

      setState(() {
        _messages.addAll(historyMessages);
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final userMessage = _messageController.text.trim();
    if (userMessage.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSending = true;
      _messageController.clear();
    });

    // Add user message to UI
    final userChatMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: userMessage,
      timestamp: DateTime.now(),
      recordsAnalyzed: _recordCount,
    );

    setState(() {
      _messages.add(userChatMessage);
    });
    _scrollToBottom();

    try {
      // Build conversation history for context
      final history = _messages
          .where((m) => !m.content.startsWith('Error:'))
          .map((m) => {
                'role': m.role == 'user' ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      // Build system prompt with empathetic patient personality
      final systemPrompt = MedicalAIService.buildPatientSystemPrompt(
        patientName: _patientName ?? 'there',
        recordsContext: _recordsContext,
      );

      // Call Gemini API with new service
      final aiResponse = await MedicalAIService.sendMessage(
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        conversationHistory: history,
      );
      
      // Create AI message
      final aiChatMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'model',
        content: aiResponse,
        timestamp: DateTime.now(),
        recordsAnalyzed: _recordCount,
      );

      // Save both messages to Firestore
      final chatHistoryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('patientChatHistory');

      await chatHistoryRef.add(userChatMessage.toMap());
      await chatHistoryRef.add(aiChatMessage.toMap());

      // Add AI message to UI
      setState(() {
        _messages.add(aiChatMessage);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      
      String errorCode = 'UNKNOWN_ERROR';
      if (e.toString().contains('Exception:')) {
        errorCode = e.toString().replaceAll('Exception:', '').trim();
      }

      // Show user-friendly error
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'model',
          content: MedicalAIService.getUserFriendlyError(errorCode),
          timestamp: DateTime.now(),
          recordsAnalyzed: _recordCount,
        ));
        _isSending = false;
      });
      _scrollToBottom();
    }
  }



  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Text('Clear Chat History', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Text(
          'This will delete all your conversation history. Your medical records will not be affected.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              try {
                final snapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('patientChatHistory')
                    .get();

                final batch = FirebaseFirestore.instance.batch();
                for (var doc in snapshot.docs) {
                  batch.delete(doc.reference);
                }
                await batch.commit();

                setState(() {
                  _messages.clear();
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check, color: AppColors.white),
                          const SizedBox(width: 12),
                          Text('Chat history cleared', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white)),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing history: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Clear',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medical Assistant',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  if (_recordCount > 0)
                    Text(
                      '$_recordCount ${_recordCount == 1 ? 'record' : 'records'} analyzed',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white.withOpacity(0.9),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: AppColors.white),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text('Clear History', style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'clear') _clearHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Analyzing your medical records...',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index])
                              .animate()
                              .fadeIn(delay: (50 * index).ms);
                        },
                      ),
          ),

          // Typing indicator
          if (_isSending)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI is analyzing...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowSoft,
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTextStyles.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Ask about your health...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.mediumGray.withOpacity(0.6),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.softGray),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.softGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: AppColors.offWhite,
                    ),
                    enabled: !_isSending,
                    maxLines: null,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: _isSending ? null : AppColors.primaryGradient,
                    color: _isSending ? AppColors.mediumGray : null,
                    shape: BoxShape.circle,
                    boxShadow: _isSending
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: const Icon(Icons.send, color: AppColors.white),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology,
                size: 64,
                color: AppColors.white,
              ),
            ).animate().scale(delay: 100.ms, curve: Curves.elasticOut),

            const SizedBox(height: 24),

            Text(
              'Hi ${_patientName ?? 'there'}! 👋',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 12),

            Text(
              'I\'m your AI medical assistant. Ask me anything about your health records!',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _recordCount > 0 ? AppColors.successLight : AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _recordCount > 0 ? Icons.check_circle : Icons.info_outline,
                    color: _recordCount > 0 ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _recordCount == 0
                        ? 'No medical records yet'
                        : '$_recordCount ${_recordCount == 1 ? 'document' : 'documents'} ready',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: _recordCount > 0 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

            if (_recordCount > 0) ...[
              const SizedBox(height: 32),

              Text(
                'Try asking:',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.mediumGray,
                ),
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 12),

              _SuggestedQuestion(
                question: 'What are my latest test results?',
                onTap: () {
                  _messageController.text = 'What are my latest test results?';
                  _sendMessage();
                },
              ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2, end: 0),

              const SizedBox(height: 8),

              _SuggestedQuestion(
                question: 'Summarize my medical history',
                onTap: () {
                  _messageController.text = 'Summarize my medical history';
                  _sendMessage();
                },
              ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.2, end: 0),
            ],
          ],
        ),
      ),
    );
  }

  // Build custom message bubble with markdown and copy functionality
  Widget _buildMessageBubble(ChatMessage message) {
    final isError = message.content.startsWith('Error:') || 
                    message.content.contains('having trouble') ||
                    message.content.contains('couldn\'t');
    
    return Align(
      alignment: message.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: message.role == 'user'
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isError
                    ? Colors.red[50]
                    : message.role == 'user'
                        ? AppColors.primary
                        : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: message.role == 'user'
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: message.role == 'user'
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                border: isError
                    ? Border.all(color: Colors.red[300]!)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isError)
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
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: message.role == 'user' ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.4,
                      ),
                      strong: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: message.role == 'user' ? Colors.white : Colors.black87,
                      ),
                      listBullet: TextStyle(
                        color: message.role == 'user' ? Colors.white70 : Colors.black54,
                      ),
                      code: TextStyle(
                        backgroundColor: message.role == 'user'
                            ? Colors.white.withOpacity(0.2)
                            : Colors.grey[200],
                        color: message.role == 'user' ? Colors.white : Colors.black87,
                        fontFamily: 'monospace',
                      ),
                      em: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: message.role == 'user' ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (message.role != 'user' && !isError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: message.content));
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
    );
  }
}

/// Suggested Question Chip
class _SuggestedQuestion extends StatelessWidget {
  final String question;
  final VoidCallback onTap;

  const _SuggestedQuestion({
    required this.question,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                question,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
