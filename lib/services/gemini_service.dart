import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiCaptionSuggestions {
  const GeminiCaptionSuggestions({
    required this.casual,
    required this.creative,
    required this.engaging,
  });

  final String casual;
  final String creative;
  final String engaging;

  factory GeminiCaptionSuggestions.fromJson(Map<String, dynamic> json) {
    return GeminiCaptionSuggestions(
      casual: json['casual']?.toString() ?? '',
      creative: json['creative']?.toString() ?? '',
      engaging: json['engaging']?.toString() ?? '',
    );
  }
}

class GeminiService {
  static const String _apiKeyPrefsKey = 'gemini_api_key';
  static const String _apiUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-3.5-flash:generateContent';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPrefsKey);
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefsKey, key.trim());
  }

  Future<GeminiCaptionSuggestions> generateSuggestions({
    required String apiKey,
    String? imageBase64,
    String? imageMime,
    String? videoPath,
    String? videoMime,
    String? fallbackTitle,
  }) async {
    final cleanKey = apiKey.trim();
    final isNvidia = cleanKey.startsWith('nvapi-');

    // System prompt directing the AI to return caption suggestions
    const prompt = 'You are the creative AI assistant for KatsKlub, a modern, premium pet and social community app.\n'
        'Based on the attached media (image or video) and description, generate three different post caption suggestions.\n'
        'Ensure the suggestions are high quality, engaging, and match a modern social vibe.\n'
        'Return the results strictly as a JSON object with this exact structure:\n'
        '{\n'
        '  "casual": "A friendly, simple, relaxed caption",\n'
        '  "creative": "An aesthetic, poetic, or clever caption",\n'
        '  "engaging": "A caption that ends with a question to invite comments"\n'
        '}\n'
        'Do not add any explanations, markdown headers, or other text outside the JSON. Return ONLY the JSON object. Do not include hashtags unless highly relevant.';

    if (isNvidia) {
      final List<Map<String, dynamic>> userContent = [];
      userContent.add({
        'type': 'text',
        'text': prompt,
      });

      if (imageBase64 != null && imageMime != null) {
        String base64Data = imageBase64;
        if (imageBase64.contains(',')) {
          base64Data = imageBase64.split(',')[1];
        }
        userContent.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:$imageMime;base64,$base64Data',
          }
        });
      } else if (videoPath != null) {
        userContent.add({
          'type': 'text',
          'text': 'Note: A video was attached. The video file name is "${fallbackTitle ?? 'video.mp4'}".',
        });
      }

      final requestBody = {
        'model': 'meta/llama-3.2-11b-vision-instruct',
        'messages': [
          {
            'role': 'user',
            'content': userContent,
          }
        ],
        'temperature': 0.2,
        'max_tokens': 1024,
        'response_format': { 'type': 'json_object' },
      };

      final response = await http.post(
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cleanKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw HttpException(
          'NVIDIA API request failed with status: ${response.statusCode}\nBody: ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const FormatException('No suggestions returned from NVIDIA API.');
      }
      final message = choices[0]['message'];
      final String rawText = message?['content'] ?? '';
      final cleanedJson = _cleanJson(rawText);

      try {
        final Map<String, dynamic> jsonMap = jsonDecode(cleanedJson);
        return GeminiCaptionSuggestions.fromJson(jsonMap);
      } catch (e) {
        return GeminiCaptionSuggestions(
          casual: rawText.length > 100 ? rawText.substring(0, 100) : rawText,
          creative: 'Failed to parse suggestions. Raw content: $rawText',
          engaging: '',
        );
      }
    } else {
      final List<Map<String, dynamic>> parts = [];
      parts.add({'text': prompt});

      if (imageBase64 != null && imageMime != null) {
        String base64Data = imageBase64;
        if (imageBase64.contains(',')) {
          base64Data = imageBase64.split(',')[1];
        }
        parts.add({
          'inlineData': {
            'mimeType': imageMime,
            'data': base64Data,
          }
        });
      } else if (videoPath != null && videoMime != null) {
        final file = File(videoPath);
        if (await file.exists()) {
          final length = await file.length();
          if (length <= 15 * 1024 * 1024) {
            final bytes = await file.readAsBytes();
            final base64Video = base64Encode(bytes);
            parts.add({
              'inlineData': {
                'mimeType': videoMime,
                'data': base64Video,
              }
            });
          } else {
            parts.add({
              'text': 'Note: A video was attached but is too large for inline analysis (>15MB). '
                  'The video file name is "${fallbackTitle ?? 'video.mp4'}".'
            });
          }
        }
      }

      final requestBody = {
        'contents': [
          {
            'parts': parts,
          }
        ]
      };

      final response = await http.post(
        Uri.parse('$_apiUrl?key=$cleanKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw HttpException(
          'Gemini API request failed with status: ${response.statusCode}\nBody: ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('No suggestions returned from Gemini.');
      }

      final content = candidates[0]['content'];
      final textParts = content?['parts'] as List?;
      if (textParts == null || textParts.isEmpty) {
        throw const FormatException('Empty content returned from Gemini.');
      }

      final String rawText = textParts[0]['text'] ?? '';
      final cleanedJson = _cleanJson(rawText);

      try {
        final Map<String, dynamic> jsonMap = jsonDecode(cleanedJson);
        return GeminiCaptionSuggestions.fromJson(jsonMap);
      } catch (e) {
        return GeminiCaptionSuggestions(
          casual: rawText.length > 100 ? rawText.substring(0, 100) : rawText,
          creative: 'Failed to parse suggestions. Raw content: $rawText',
          engaging: '',
        );
      }
    }
  }

  String _cleanJson(String rawText) {
    var cleaned = rawText.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
      if (cleaned.startsWith('json')) {
        cleaned = cleaned.substring(4);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
    }
    return cleaned.trim();
  }
}
