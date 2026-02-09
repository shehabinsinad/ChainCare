import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized Medical AI Service
/// 
/// Handles all AI chatbot functionality for both doctor and patient assistants
/// with distinct personalities, proper error handling, and intelligent record management.
class MedicalAIService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';

  /// Fetch and format patient records for AI context
  /// 
  /// Intelligently fetches ALL available records, then selects most relevant
  /// if count exceeds 100. No hard limits that cause RangeError.
  static Future<String> fetchPatientRecordsContext(String patientId) async {
    try {
      debugPrint('📊 Fetching records for patient: $patientId');

      // Fetch ALL available records (no arbitrary limit)
      final recordsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('records')
          .orderBy('timestamp', descending: true) // Most recent first
          .get()
          .timeout(const Duration(seconds: 10));

      if (recordsSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No records found for patient $patientId');
        return 'NO_RECORDS_FOUND';
      }

      final recordCount = recordsSnapshot.docs.length;
      debugPrint('✅ Fetched $recordCount records');

      // Convert to list
      final records = recordsSnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();

      // If too many records, intelligently limit
      final recordsToAnalyze = recordCount > 100 
          ? _selectRelevantRecords(records, 50) 
          : records;

      // Format for AI
      return _formatRecordsForAI(recordsToAnalyze, recordCount);

    } on TimeoutException {
      debugPrint('❌ Timeout fetching records');
      return 'TIMEOUT_ERROR';
    } catch (e) {
      debugPrint('❌ Error fetching records: $e');
      return 'FETCH_ERROR';
    }
  }

  /// Select most relevant records when there are too many
  /// 
  /// Strategy: Ensure variety (labs, prescriptions, imaging, notes)
  /// while prioritizing most recent data
  static List<Map<String, dynamic>> _selectRelevantRecords(
    List<Map<String, dynamic>> allRecords,
    int maxCount,
  ) {
    // Group by diagnosis/type
    final labTests = allRecords.where((r) {
      final diagnosis = (r['diagnosis'] ?? '').toString().toLowerCase();
      return diagnosis.contains('lab') || 
             diagnosis.contains('test') || 
             diagnosis.contains('blood');
    }).take(15).toList();
    
    final prescriptions = allRecords.where((r) {
      final diagnosis = (r['diagnosis'] ?? '').toString().toLowerCase();
      return diagnosis.contains('prescription') || 
             diagnosis.contains('medication') ||
             (r['prescriptions'] ?? '').toString().isNotEmpty;
    }).take(15).toList();
    
    final imaging = allRecords.where((r) {
      final diagnosis = (r['diagnosis'] ?? '').toString().toLowerCase();
      return diagnosis.contains('imaging') || 
             diagnosis.contains('x-ray') ||
             diagnosis.contains('mri') ||
             diagnosis.contains('ct');
    }).take(10).toList();
    
    final notes = allRecords.where((r) {
      final diagnosis = (r['diagnosis'] ?? '').toString().toLowerCase();
      return diagnosis.contains('note') || 
             diagnosis.contains('visit') ||
             diagnosis.contains('clinical');
    }).take(10).toList();

    final selected = [...labTests, ...prescriptions, ...imaging, ...notes];
    
    // Sort by date again (most recent first)
    selected.sort((a, b) {
      final aDate = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final bDate = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return selected.take(maxCount).toList();
  }

  /// Format records into readable context for AI
  static String _formatRecordsForAI(
    List<Map<String, dynamic>> records,
    int totalCount,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('PATIENT MEDICAL HISTORY ($totalCount total records available):');
    buffer.writeln();

    // Group by type for organized presentation
    final labTests = <Map<String, dynamic>>[];
    final prescriptions = <Map<String, dynamic>>[];
    final imaging = <Map<String, dynamic>>[];
    final notes = <Map<String, dynamic>>[];
    final other = <Map<String, dynamic>>[];

    for (var record in records) {
      final diagnosis = (record['diagnosis'] ?? '').toString().toLowerCase();
      
      if (diagnosis.contains('lab') || diagnosis.contains('test') || diagnosis.contains('blood')) {
        labTests.add(record);
      } else if (diagnosis.contains('prescription') || diagnosis.contains('medication')) {
        prescriptions.add(record);
      } else if (diagnosis.contains('imaging') || diagnosis.contains('x-ray') || diagnosis.contains('mri')) {
        imaging.add(record);
      } else if (diagnosis.contains('note') || diagnosis.contains('visit')) {
        notes.add(record);
      } else {
        other.add(record);
      }
    }

    // Format each category
    if (labTests.isNotEmpty) {
      buffer.writeln('═══ LAB TESTS (${labTests.length}) ═══');
      for (var i = 0; i < labTests.length; i++) {
        buffer.write(_formatSingleRecord(labTests[i], i + 1));
      }
      buffer.writeln();
    }

    if (prescriptions.isNotEmpty) {
      buffer.writeln('═══ PRESCRIPTIONS (${prescriptions.length}) ═══');
      for (var i = 0; i < prescriptions.length; i++) {
        buffer.write(_formatSingleRecord(prescriptions[i], i + 1));
      }
      buffer.writeln();
    }

    if (imaging.isNotEmpty) {
      buffer.writeln('═══ IMAGING STUDIES (${imaging.length}) ═══');
      for (var i = 0; i < imaging.length; i++) {
        buffer.write(_formatSingleRecord(imaging[i], i + 1));
      }
      buffer.writeln();
    }

    if (notes.isNotEmpty) {
      buffer.writeln('═══ CLINICAL NOTES (${notes.length}) ═══');
      for (var i = 0; i < notes.length; i++) {
        buffer.write(_formatSingleRecord(notes[i], i + 1));
      }
      buffer.writeln();
    }

    if (other.isNotEmpty) {
      buffer.writeln('═══ OTHER RECORDS (${other.length}) ═══');
      for (var i = 0; i < other.length; i++) {
        buffer.write(_formatSingleRecord(other[i], i + 1));
      }
      buffer.writeln();
    }

    if (totalCount > records.length) {
      buffer.writeln('───────────────────────────────────────');
      buffer.writeln('NOTE: Showing ${records.length} most relevant of $totalCount total records.');
      buffer.writeln('Focus on these records unless specifically asked about older data.');
    }

    return buffer.toString();
  }

  /// Format a single record entry
  static String _formatSingleRecord(Map<String, dynamic> record, int index) {
    final date = (record['timestamp'] as Timestamp?)?.toDate();
    final dateStr = date != null 
        ? DateFormat('MMM dd, yyyy').format(date) 
        : 'Date unknown';
    
    final diagnosis = record['diagnosis'] ?? 'Medical Record';
    final doctorName = record['doctorName'] ?? 'Unknown';
    final notes = record['notes'] ?? '';
    final prescriptions = record['prescriptions'] ?? '';
    final extractedText = record['extractedText'] ?? '';
    
    final buffer = StringBuffer();
    buffer.writeln('Record #$index - $dateStr');
    buffer.writeln('Type: $diagnosis');
    buffer.writeln('Doctor: Dr. $doctorName');
    
    if (prescriptions.isNotEmpty) {
      buffer.writeln('Medications: $prescriptions');
    }
    
    if (notes.isNotEmpty) {
      buffer.writeln('Notes: $notes');
    }
    
    if (extractedText.isNotEmpty && !extractedText.startsWith('[')) {
      // Truncate very long text safely
      final maxLength = 500;
      final truncatedText = extractedText.length > maxLength 
          ? '${extractedText.substring(0, maxLength)}... [truncated]'
          : extractedText;
      buffer.writeln('Content: $truncatedText');
    }
    
    buffer.writeln('───────────────────────────────────────');
    
    return buffer.toString();
  }

  /// Build system prompt for Doctor Clinical Assistant
  /// 
  /// Professional, analytical, data-driven personality
  static String buildDoctorSystemPrompt({
    required String doctorName,
    required String patientName,
    required String recordsContext,
  }) {
    if (recordsContext == 'NO_RECORDS_FOUND') {
      return '''
You are a Clinical Research Assistant for Dr. $doctorName.

SITUATION: Patient $patientName has no medical records uploaded to the system yet.

YOUR RESPONSE:
Politely inform the doctor that no records are available for analysis. Suggest:
1. Checking if records were uploaded to the correct patient profile
2. Uploading records if they haven't been added yet
3. Verifying the patient identity

Be professional and helpful.
''';
    }

    if (recordsContext == 'TIMEOUT_ERROR' || recordsContext == 'FETCH_ERROR') {
      return '''
You are a Clinical Research Assistant for Dr. $doctorName.

SITUATION: There was a technical error loading patient $patientName's records.

YOUR RESPONSE:
Apologize for the technical difficulty and suggest:
1. Trying again in a moment
2. Checking internet connection
3. Contacting support if the issue persists

Be professional and reassuring.
''';
    }

    return '''
You are a Clinical Research Assistant helping Dr. $doctorName with patient $patientName.

YOUR ROLE:
- Analyze medical records and provide clinical insights
- Think like a medical researcher, not a chatbot
- Be precise, data-driven, and professional
- Flag important patterns, trends, and anomalies
- Cite specific records with dates when making claims

AVAILABLE MEDICAL DATA:
$recordsContext

COMMUNICATION GUIDELINES:

1. ACCURACY IS PARAMOUNT:
   - Never invent or hallucinate data
   - If information is missing, explicitly state: "This information is not documented in the available records"
   - Always cite sources: "According to Record #3 from Dec 15..." 
   - Use specific values, dates, and measurements
   - If asked about something not in the records, say so clearly

2. CLINICAL THINKING:
   - Identify trends: "Patient's BP increased from 120/80 (Jan 1, Record #1) to 135/90 (Jan 15, Record #3)"
   - Cross-reference data: "Patient is on lisinopril (Record #2) but BP remains elevated"
   - Flag gaps: "No recent kidney function tests. Last creatinine was 6 months ago (Record #5)"
   - Suggest relevant follow-ups when appropriate
   - Think about clinical correlations

3. PROFESSIONAL TONE:
   - Use medical terminology (doctor understands it)
   - Be concise - doctors are busy
   - Structure: Key finding first, supporting details second
   - Example: "Mild anemia detected (Hgb 12.5, Record #2, Dec 15). Appears chronic based on previous CBC from Record #5"
   - Avoid unnecessary pleasantries

4. WHAT NOT TO DO:
   - ❌ Don't make treatment recommendations (you support, doctor decides)
   - ❌ Don't make diagnoses
   - ❌ Don't be overly verbose
   - ❌ Don't apologize excessively
   - ❌ Don't say "I'm just an AI" (doctor knows this)
   - ❌ Don't refuse to answer clinical questions (you're a tool)

5. HANDLING INSUFFICIENT DATA:
   If asked about something not in records:
   
   "I don't see [specific information] in the available records. The most recent relevant data I have is [cite what exists with record number]. 
   
   To answer your question fully, you might need:
   • [Specific test/information needed]
   • [Alternative source]
   
   Would you like me to analyze what data is available?"

6. EMERGENCY INDICATORS:
   If you notice critical values, flag them clearly:
   "⚠️ ALERT: [Finding] detected in Record #X from [date]. [Specific abnormal value]. This may require urgent attention."
   
   However, if doctor is asking about HISTORY (e.g., "Does patient have stroke?" or "Is there chest pain?"), they mean documented history, NOT current emergency.

7. PATTERN RECOGNITION:
   When you see trends across multiple records:
   "TREND ANALYSIS:
   • [Specific metric]: [value 1 (Record #X)] → [value 2 (Record #Y)] → [value 3 (Record #Z)]
   • Direction: [Improving/Worsening/Stable]
   • Clinical significance: [Brief interpretation]
   • Time span: [Duration between first and last]"

REMEMBER: You're a research assistant providing data analysis, not making clinical decisions. Be helpful, precise, and always cite your sources with record numbers and dates.

PRIVACY NOTE: This is a temporary session not stored in patient records.
''';
  }

  /// Build system prompt for Patient Medical Assistant
  /// 
  /// Empathetic, educational, supportive personality
  static String buildPatientSystemPrompt({
    required String patientName,
    required String recordsContext,
  }) {
    if (recordsContext == 'NO_RECORDS_FOUND') {
      return '''
You are a Medical Assistant helping $patientName understand their medical records.

SITUATION: No medical records have been uploaded yet.

YOUR RESPONSE:
Warmly explain that you're here to help once they upload their medical records. Suggest:
1. Uploading lab results, prescriptions, or doctor's notes
2. Starting with their most recent medical documents
3. You'll be ready to explain everything in simple terms once files are uploaded

Be encouraging and friendly. Let them know you're excited to help them understand their health information!
''';
    }

    if (recordsContext == 'TIMEOUT_ERROR' || recordsContext == 'FETCH_ERROR') {
      return '''
You are a Medical Assistant helping $patientName.

SITUATION: There was a technical problem loading the medical records.

YOUR RESPONSE:
Apologize warmly and suggest:
1. Trying again in just a moment
2. Making sure they have a good internet connection
3. Reaching out to support if it keeps happening

Be reassuring and empathetic. Let them know their records are safe, just temporarily unavailable.
''';
    }

    return '''
You are a Medical Assistant helping $patientName understand their medical records.

YOUR ROLE:
- Translate medical jargon into simple, clear language
- Help patients understand their health information
- Be empathetic, warm, and encouraging
- Empower patients to ask informed questions to their doctors
- Flag urgent symptoms that need immediate medical attention

AVAILABLE MEDICAL RECORDS:
$recordsContext

COMMUNICATION GUIDELINES:

1. EXPLAIN LIKE A CARING TEACHER:
   - Break down complex terms into simple concepts
   - Use analogies: "Your hemoglobin is like delivery trucks carrying oxygen throughout your body"
   - Define before using medical terms: "Hemoglobin (the protein in red blood cells that carries oxygen)"
   - Check understanding: "Does that make sense? I'm happy to explain it differently if needed!"
   - Build on what they already know

2. BE GENUINELY EMPATHETIC:
   - Acknowledge feelings: "I understand health information can feel overwhelming"
   - Provide context: "Many people have similar results and manage them well"
   - Celebrate progress: "Your levels have improved since last time - that's wonderful progress!"
   - Never dismiss concerns: "That's a really good question. Let me explain..."
   - Validate emotions: "It's completely normal to feel concerned about this"

3. BALANCE HONESTY WITH REASSURANCE:
   ✅ Good: "Your test shows mild anemia. This is common and usually very treatable. Your doctor can help figure out the cause - often it's something simple like diet or iron levels."
   
   ❌ Too dismissive: "Everything is fine, don't worry!"
   ❌ Too scary: "This could be very serious!"
   
   The goal: Inform honestly while providing appropriate comfort and context.

4. USE SIMPLE, FRIENDLY LANGUAGE:
   Instead of: "Your serum creatinine indicates decreased glomerular filtration rate"
   Say: "Your kidney function test shows your kidneys might not be filtering waste as efficiently as they should. Think of it like a water filter that's getting a bit clogged - it still works, but not at full capacity."

5. FLAG EMERGENCIES CLEARLY:
   If patient mentions concerning symptoms, respond immediately:
   
   "⚠️ IMPORTANT: [Symptom like chest pain] can be a sign of something serious that needs quick attention.
   
   Please do one of these RIGHT NOW:
   • Call 112 (National Emergency Number - India)
   • Call 102 (Ambulance - India)  
   • Go to the nearest hospital emergency department
   • Call your doctor's emergency line if you have one
   
   Don't wait - it's always better to check and be safe!
   
   (If you're traveling outside India, please call your local emergency number)"
   
   Emergency red flags that need immediate medical attention:
   - Chest pain, severe shortness of breath, rapid heartbeat
   - Severe bleeding, major injury
   - Sudden severe headache, confusion, vision problems
   - Signs of stroke: Face drooping, Arm weakness, Speech difficulty
   - Thoughts of self-harm
   - Severe allergic reactions

6. WHAT NOT TO DO:
   - ❌ Don't diagnose conditions ("You have diabetes")
   - ❌ Don't recommend specific medications or treatments
   - ❌ Don't contradict their doctor's advice
   - ❌ Don't use medical jargon without explaining it
   - ❌ Don't minimize their concerns ("It's nothing")
   - ❌ Don't make promises ("You'll be fine")
   - ❌ Don't give exact prognoses

7. WHEN INFORMATION IS MISSING:
   "I don't see [specific information] in your uploaded records right now. This could mean:
   
   • It might be in a different document you haven't uploaded yet
   • Your doctor may have it but it's not in this particular report
   • It might be something they'll check at your next appointment
   
   If you're curious about this, it would be a great question to ask your doctor! Would you like me to help you understand anything else from your current records?"

8. ENCOURAGE DOCTOR-PATIENT COMMUNICATION:
   "That's an excellent question to bring up with your doctor! They can:
   • Explain how this specifically applies to your situation
   • Order any follow-up tests if needed
   • Adjust your treatment plan if necessary
   • Answer questions about your unique health history
   
   Doctors really appreciate when patients ask informed questions! Would you like help understanding anything else that might be useful to discuss with them?"

9. STRUCTURE YOUR RESPONSES:
   For complex explanations, use this format:
   
   **Simple answer first** (1-2 sentences)
   **What it means for you** (practical implications)
   **Why it matters** (health context)
   **Next steps** (what they should do)
   **Follow-up offer** (ask if they want more details)

10. USE ENCOURAGING LANGUAGE:
    - "Great question!"
    - "I'm glad you're taking an active role in understanding your health"
    - "You're doing the right thing by learning about this"
    - "It's smart that you're asking about this"
    - "Your doctor will be impressed that you're so informed!"

REMEMBER: You're like a knowledgeable, caring friend helping someone understand confusing medical information. Be warm, clear, honest, and always prioritize their safety and understanding. Never talk down to them, but never assume they know medical terms. Your goal is to empower them to be active participants in their own healthcare!
''';
  }

  /// Send message to Gemini API
  static Future<String> sendMessage({
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> conversationHistory,
  }) async {
    try {
      debugPrint('💬 Sending message to Gemini API');
      debugPrint('📝 Message: ${userMessage.substring(0, userMessage.length.clamp(0, 50))}...');

      // Build conversation context
      final messages = <Map<String, dynamic>>[];
      
      // Add conversation history (last 10 exchanges for context)
      final recentHistory = conversationHistory.length > 20
          ? conversationHistory.sublist(conversationHistory.length - 20)
          : conversationHistory;
      
      for (var msg in recentHistory) {
        messages.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg['content']}
          ]
        });
      }
      
      // Add new user message
      messages.add({
        'role': 'user',
        'parts': [
          {'text': userMessage}
        ]
      });

      // Make API call
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': messages,
          'systemInstruction': {
            'parts': [
              {'text': systemPrompt}
            ]
          },
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 2048,
            'topP': 0.95,
            'topK': 40,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_NONE'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_NONE' // Medical info can be flagged as "dangerous"
            },
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 429) {
        throw Exception('QUOTA_EXCEEDED');
      }

      if (response.statusCode != 200) {
        debugPrint('❌ API Error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        throw Exception('API_ERROR_${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
        debugPrint('❌ No candidates in response');
        throw Exception('NO_RESPONSE');
      }

      final candidate = data['candidates'][0];
      
      // Check if response was blocked
      if (candidate['finishReason'] == 'SAFETY') {
        throw Exception('SAFETY_BLOCKED');
      }

      final text = candidate['content']['parts'][0]['text'] as String;
      debugPrint('✅ Received response: ${text.substring(0, text.length.clamp(0, 50))}...');
      
      return text.trim();

    } on SocketException {
      debugPrint('❌ Network error');
      throw Exception('NETWORK_ERROR');
    } on TimeoutException {
      debugPrint('❌ Request timeout');
      throw Exception('TIMEOUT');
    } on FormatException {
      debugPrint('❌ JSON parse error');
      throw Exception('PARSE_ERROR');
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      if (e.toString().contains('QUOTA_EXCEEDED')) {
        throw Exception('QUOTA_EXCEEDED');
      }
      if (e.toString().contains('SAFETY_BLOCKED')) {
        throw Exception('SAFETY_BLOCKED');
      }
      throw Exception('UNKNOWN_ERROR');
    }
  }

  /// Get user-friendly error message
  static String getUserFriendlyError(String errorCode) {
    switch (errorCode) {
      case 'NETWORK_ERROR':
        return "I'm having trouble connecting. Please check your internet connection and try again.";
      
      case 'TIMEOUT':
        return "The request is taking longer than expected. Please try asking a simpler question or try again in a moment.";
      
      case 'PARSE_ERROR':
        return "I received an unexpected response. Please try rephrasing your question.";
      
      case 'QUOTA_EXCEEDED':
        return "The AI service is currently at capacity. Please try again in a few minutes. If this persists, contact support.";
      
      case 'SAFETY_BLOCKED':
        return "I couldn't generate a response due to safety filters. Please try rephrasing your question in a different way.";
      
      case 'NO_RESPONSE':
        return "I wasn't able to generate a response. Please try asking your question differently.";
      
      case 'NO_RECORDS_FOUND':
        return "No medical records have been uploaded yet. Please upload some records first, and I'll be happy to help explain them!";
      
      case 'FETCH_ERROR':
      case 'TIMEOUT_ERROR':
        return "There was an error loading the medical records. Please try again. If the problem continues, contact support.";
      
      default:
        return "I'm having trouble processing your request right now. Please try again, and if the problem persists, contact support.";
    }
  }
}
