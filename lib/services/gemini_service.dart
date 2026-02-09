import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
  
  // Rate limiting
  static DateTime? _lastRequestTime;
  static const Duration _cooldownPeriod = Duration(seconds: 5);

  /// Send message to Gemini API with retry logic
  /// 
  /// [systemPrompt] includes system instructions, medical records, and conversation history
  /// [userMessage] is the user's current question
  /// 
  /// Returns AI response text or throws exception on failure
  static Future<String> sendMessage(String systemPrompt, String userMessage) async {
    // Rate limiting check
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _cooldownPeriod) {
        final waitTime = _cooldownPeriod - timeSinceLastRequest;
        throw Exception('Please wait ${waitTime.inSeconds} seconds before sending another message');
      }
    }

    // Safe dotenv access with null check
    String? apiKey;
    try {
      apiKey = dotenv.env['GEMINI_API_KEY'];
    } catch (e) {
      // dotenv not initialized
      apiKey = null;
    }
    
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here' || apiKey == 'your_api_key_here' || apiKey == 'your_actual_api_key_here') {
      throw Exception(
        'Gemini API key not configured.\n\n'
        'To use AI features:\n'
        '1. Get API key from https://makersuite.google.com/app/apikey\n'
        '2. Create .env file in project root\n'
        '3. Add: GEMINI_API_KEY=your_key_here\n'
        '4. Restart the app'
      );
    }

    // Combine system prompt and user message
    final fullPrompt = '$systemPrompt\n\nUser Question: $userMessage';

    // Retry logic with exponential backoff
    int retryCount = 0;
    const maxRetries = 3;
    const initialDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        final uri = Uri.parse('$_baseUrl?key=$apiKey');
        
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': fullPrompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.7,
              'maxOutputTokens': 2048,
            },
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          _lastRequestTime = DateTime.now();
          
          final data = jsonDecode(response.body);
          
          // Parse Gemini response
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final candidate = data['candidates'][0];
            if (candidate['content'] != null && candidate['content']['parts'] != null) {
              final parts = candidate['content']['parts'] as List;
              if (parts.isNotEmpty && parts[0]['text'] != null) {
                return parts[0]['text'] as String;
              }
            }
          }
          
          throw Exception('Unexpected API response format');
        } else if (response.statusCode == 429) {
          // Rate limit exceeded
          throw Exception('Daily limit reached. Try again tomorrow.');
        } else if (response.statusCode == 400) {
          // Bad request - likely API key issue or invalid prompt
          final errorBody = jsonDecode(response.body);
          throw Exception('API Error: ${errorBody['error']?['message'] ?? 'Invalid request'}');
        } else {
          throw Exception('API Error: ${response.statusCode}');
        }
      } catch (e) {
        if (e.toString().contains('Daily limit reached') || 
            e.toString().contains('Please wait') ||
            e.toString().contains('GEMINI_API_KEY not found')) {
          rethrow; // Don't retry these errors
        }

        retryCount++;
        if (retryCount >= maxRetries) {
          if (e.toString().contains('TimeoutException')) {
            throw Exception('Request timed out. Please check your internet connection.');
          }
          throw Exception('Unable to connect. Please check your internet connection.');
        }

        // Exponential backoff
        final delay = initialDelay * (1 << (retryCount - 1)); // 2s, 4s, 8s
        await Future.delayed(delay);
      }
    }

    throw Exception('Failed after $maxRetries retries');
  }

  /// Check if emergency keywords are present in user message
  static bool containsEmergencyKeywords(String message) {
    final msgLower = message.toLowerCase();
    const emergencyKeywords = [
      'chest pain',
      'heart attack',
      "can't breathe",
      'difficulty breathing',
      'severe bleeding',
      'suicide',
      'stroke',
      'unconscious',
      'choking',
      'seizure',
    ];

    return emergencyKeywords.any((keyword) => msgLower.contains(keyword));
  }

  /// Get emergency warning message
  static String getEmergencyWarning() {
    return '⚠️ EMERGENCY: This may require immediate medical attention. '
           'Please call emergency services (911) or visit the nearest ER immediately.\n\n';
  }
}
