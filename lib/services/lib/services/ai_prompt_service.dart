import 'dart:convert';
import 'package:http/http.dart' as http;

class AiPromptService {
  /// Gọi backend của bạn, KHÔNG gọi trực tiếp OpenAI từ app Flutter.
  /// Backend sẽ giữ OPENAI_API_KEY an toàn.
  static Future<List<String>> generateSuggestions({
    required Uri endpoint,
    required String languageCode,
    required String categoryKey,
    required String question,
    required String firstName,
    String? relationshipGoal,
    String? occupation,
    String? religion,
  }) async {
    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'languageCode': languageCode,
        'categoryKey': categoryKey,
        'question': question,
        'firstName': firstName,
        'relationshipGoal': relationshipGoal,
        'occupation': occupation,
        'religion': religion,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to generate AI suggestions: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = (data['suggestions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return suggestions;
  }
}
