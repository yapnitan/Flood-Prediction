import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../constants/asset_categories.dart';

/// Gemini's best-effort read of an asset-loss evidence photo. Every field is
/// a suggestion the resident can override on the form. The loss amount is
/// deliberately NOT estimated here — the resident always enters that.
class AssetAiSuggestion {
  const AssetAiSuggestion({
    this.category,
    this.assetName,
    this.condition,
    this.quantity,
    this.description,
    this.note,
  });

  final String? category;
  final String? assetName;

  /// A key from [assetConditions] (e.g. `severely_damaged`), already mapped
  /// back from whatever label the model returned.
  final String? condition;
  final int? quantity;
  final String? description;

  /// Model's note about anything uncertain — shown to the user, not stored.
  final String? note;
}

/// Vision-assisted prefill for the "Report Asset Loss" wizard. Sends the
/// evidence photo to Google's Gemini API (`generateContent` over raw HTTP —
/// there is no official Dart SDK) and asks it to identify the item, count how
/// many are shown, judge the flood-damage condition, and describe it. The
/// resident then enters the loss amount and can edit every AI-filled field.
///
/// The API key lives in `.env` as `GEMINI_API_KEY` (gitignored). Get one for
/// free at https://aistudio.google.com/apikey. It ships in the app binary —
/// acceptable for this coursework build; a production app would proxy the
/// call through a server so the key stays secret.
class AssetAiService {
  AssetAiService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  /// Vision-capable and cheap; swap to `gemini-3.6-pro` for a harder read.
  /// (Older 2.x models are no longer offered to new API keys.)
  static const _model = 'gemini-3.6-flash';

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const _maxPhotos = 3;

  String? get _apiKey {
    try {
      final key = dotenv.maybeGet('GEMINI_API_KEY')?.trim();
      return (key == null || key.isEmpty) ? null : key;
    } catch (_) {
      // dotenv not initialised (e.g. widget tests) — treat as unconfigured.
      return null;
    }
  }

  /// Whether an API key is present — the wizard hides the AI button when not.
  bool get isConfigured => _apiKey != null;

  /// Returns null on any failure (no key, network error, unparseable reply) —
  /// the caller falls back to manual entry.
  Future<AssetAiSuggestion?> analysePhotos(List<XFile> photos) async {
    final key = _apiKey;
    if (key == null || photos.isEmpty) return null;

    try {
      final parts = <Map<String, dynamic>>[];
      for (final photo in photos.take(_maxPhotos)) {
        final bytes = await photo.readAsBytes();
        parts.add({
          'inline_data': {
            'mime_type': _mediaType(photo),
            'data': base64Encode(bytes),
          },
        });
      }
      parts.add({
        'text': 'Identify this flood-damaged item and fill in the '
            'asset-loss report. Do not estimate a monetary value.',
      });

      final requestBody = jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': _systemPrompt},
          ],
        },
        'contents': [
          {'role': 'user', 'parts': parts},
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
          'responseSchema': _responseSchema,
        },
      });

      final response = await _http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': key,
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        debugPrint('AssetAiService HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>? ?? const [];
      if (candidates.isEmpty) {
        debugPrint('AssetAiService: no candidates — ${response.body}');
        return null;
      }

      final content = (candidates.first as Map<String, dynamic>)['content']
          as Map<String, dynamic>?;
      final contentParts = content?['parts'] as List<dynamic>? ?? const [];
      final text = contentParts
          .whereType<Map<String, dynamic>>()
          // Skip the model's internal "thought" parts — only the answer text.
          .where((p) => p['thought'] != true)
          .map((p) => p['text'] as String?)
          .whereType<String>()
          .join()
          .trim();
      if (text.isEmpty) return null;

      final parsed = jsonDecode(text);
      if (parsed is! Map<String, dynamic>) return null;
      return _parse(parsed);
    } catch (error) {
      debugPrint('AssetAiService.analysePhotos error: $error');
      return null;
    }
  }

  AssetAiSuggestion _parse(Map<String, dynamic> input) {
    final rawQty = input['quantity'];
    final note = (input['confidence_note'] as String?)?.trim();

    return AssetAiSuggestion(
      category: _matchCategory(input['asset_category'] as String?),
      assetName: (input['asset_name'] as String?)?.trim(),
      condition: _matchCondition(input['condition'] as String?),
      quantity: rawQty is num ? rawQty.toInt() : int.tryParse('$rawQty'),
      description: (input['description'] as String?)?.trim(),
      note: (note == null || note.isEmpty) ? null : note,
    );
  }

  static String? _matchCategory(String? raw) {
    if (raw == null) return null;
    final lower = raw.trim().toLowerCase();
    for (final category in assetCategories) {
      if (category.toLowerCase() == lower) return category;
    }
    return null;
  }

  static String? _matchCondition(String? raw) {
    if (raw == null) return null;
    final lower = raw.trim().toLowerCase();
    // Accept either the internal key or the display label.
    if (assetConditions.contains(lower)) return lower;
    for (final entry in assetConditionLabels.entries) {
      if (entry.value.toLowerCase() == lower) return entry.key;
    }
    return null;
  }

  static String _mediaType(XFile photo) {
    final name = photo.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  /// Gemini structured-output schema (a subset of OpenAPI 3.0). No monetary
  /// value field — the resident enters the loss amount themselves.
  static final Map<String, dynamic> _responseSchema = {
    'type': 'object',
    'properties': {
      'asset_category': {
        'type': 'string',
        'enum': assetCategories,
        'description': 'The closest category for this item.',
      },
      'asset_name': {
        'type': 'string',
        'description': 'Short name of the item, e.g. "Refrigerator", "Sofa".',
      },
      'condition': {
        'type': 'string',
        'enum': [...assetConditionLabels.values],
        'description': 'Flood-damage severity visible in the photo.',
      },
      'quantity': {
        'type': 'integer',
        'description': 'How many of this item are visibly damaged '
            '(1 if only one is shown).',
      },
      'description': {
        'type': 'string',
        'description': 'One or two sentences describing the item and the '
            'damage seen in the photo.',
      },
      'confidence_note': {
        'type': 'string',
        'description': 'Short note on anything uncertain (blurry photo, '
            'unsure of the item, etc.). Empty string if confident.',
      },
    },
    'required': [
      'asset_category',
      'asset_name',
      'condition',
      'quantity',
      'description',
    ],
    'propertyOrdering': [
      'asset_category',
      'asset_name',
      'condition',
      'quantity',
      'description',
      'confidence_note',
    ],
  };

  static const _systemPrompt =
      'You help Malaysian flood victims file asset-loss claims. From the '
      'evidence photo(s) of a flood-damaged household item, identify the '
      'item, count how many damaged units are shown, and judge how badly the '
      'flood damaged it. Base every field on what the photo shows. Do NOT '
      'estimate any monetary value — the resident enters that. If the photo '
      'is unclear, still give your best guess and say so in confidence_note. '
      'Respond only with the JSON object described by the schema.';
}
